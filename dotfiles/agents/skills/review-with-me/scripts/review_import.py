"""Explicitly import v3 review records; never modify their JSON or Git refs."""

import copy
import json
import time
from pathlib import Path

from review_git import at_commit, blocks, commit, repository
from review_model import transaction


def import_legacy(source, destination):
    old = json.loads(Path(source).read_text())
    if old.get("version", old.get("schema_version")) not in (2, 3):
        raise ValueError("只能导入旧版 v2/v3 审阅记录")
    repo = repository(Path.cwd())
    state = {
        "version": 4,
        "repo": repo,
        "title": old.get("goal") or "导入的审阅",
        "base": commit(repo, old["base"]),
        "scope": [],
        "revisions": [],
        "groups": [],
        "threads": [],
        "listener": {"enabled": False, "thread_id": "", "error": ""},
    }
    events = []
    mapping = {}
    for change in old.get("changes", []):
        state["groups"].append(
            {
                "id": change["id"],
                "title": change["title"],
                "summary": "\n\n".join(
                    filter(None, [change.get("summary"), change.get("rationale")])
                ),
                "paths": change["paths"],
                "checks": [],
            }
        )
        for revision in change["revisions"]:
            events.append((revision.get("created_at", ""), change, revision))
    files = {}
    for _, change, previous in sorted(events, key=lambda e: e[0]):
        head = commit(repo, previous["head"])
        base = commit(repo, previous["base"])
        for path in previous.get("paths", change["paths"]):
            before, after = at_commit(repo, base, path), at_commit(repo, head, path)
            if before is not None or after is not None:
                files[path] = {
                    "path": path,
                    "old_path": path,
                    "old": before,
                    "new": after,
                    "status": "added"
                    if before is None
                    else "deleted"
                    if after is None
                    else "modified",
                }
        revision = {
            "id": f"r{len(state['revisions']) + 1}",
            "label": f"{change['title']} · {previous['label']}",
            "created": time.time(),
            "files": copy.deepcopy(files),
            "decisions": {},
            "checks": {},
        }
        mapping[(change["id"], previous["id"])] = revision["id"]
        for decision in change.get("decisions", []):
            if (
                decision.get("revision_id") != previous["id"]
                or decision["path"] not in files
            ):
                continue
            target = revision["decisions"].setdefault(
                decision["path"], {"status": "pending", "blocks": {}}
            )
            value = {
                "status": decision["status"],
                "reason": decision.get("reason", ""),
                "by": decision.get("author", "user"),
            }
            if decision["scope"] == "file":
                target.update(value)
            else:
                block = next(
                    (
                        b
                        for b in blocks(files[decision["path"]])
                        if all(b[k] == v for k, v in decision["hunk"].items())
                    ),
                    None,
                )
                if block:
                    target["blocks"][block["id"]] = value
        state["revisions"].append(revision)
    for change in old.get("changes", []):
        for annotation in change.get("annotations", []):
            revision_id = mapping[
                (
                    change["id"],
                    annotation.get("revision_id") or change["revisions"][-1]["id"],
                )
            ]
            anchors = []
            if annotation.get("path"):
                anchor = {
                    "path": annotation["path"],
                    "side": annotation.get("side", "file"),
                }
                if anchor["side"] != "file":
                    anchor.update(
                        start=annotation["start_line"],
                        end=annotation.get("end_line") or annotation["start_line"],
                        quote=annotation.get("excerpt", ""),
                    )
                anchors.append(anchor)
            messages = [
                {
                    "id": annotation["id"],
                    "author": annotation.get("author", "user"),
                    "body": annotation["body"],
                    "created": time.time(),
                }
            ]
            messages.extend(
                {
                    "id": reply.get("id") or f"{annotation['id']}-{i}",
                    "author": reply.get("author", "agent"),
                    "body": reply["body"],
                    "created": time.time(),
                }
                for i, reply in enumerate(annotation.get("replies", []))
            )
            state["threads"].append(
                {
                    "id": f"{change['id']}-{annotation['id']}",
                    "revision": revision_id,
                    "against": "base",
                    "targets": anchors,
                    "kind": annotation.get("kind", "note"),
                    "status": annotation.get("status", "open"),
                    "messages": messages,
                    "suggestion": annotation.get("suggestion", ""),
                }
            )
    with transaction(destination, create=True) as target:
        target.update(state)
    return {
        "revisions": len(state["revisions"]),
        "threads": len(state["threads"]),
        "state": destination,
    }
