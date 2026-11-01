"""Keep a resumable, agent-maintained code review and the feedback around it."""

import argparse
import contextlib
import fcntl
import json
import os
import re
import secrets
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path


SCHEMA_VERSION = 2
STATUSES = (
    "unreviewed",
    "reviewing",
    "feedback",
    "revisit",
    "accepted",
    "superseded",
)
ANNOTATION_STATUSES = ("open", "resolved", "dismissed")
ANNOTATION_KINDS = ("question", "bug", "change", "note", "answer")
ACTIONABLE_KINDS = ("question", "bug", "change")
CHANGE_ID = re.compile(r"^[a-z0-9][a-z0-9._-]{0,79}$")
COMMIT_ID = re.compile(r"^[0-9a-f]{40,64}$")


def now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace(
        "+00:00", "Z"
    )


def relative_path(value):
    path = Path(os.path.normpath(value))
    if path.is_absolute() or ".." in path.parts:
        raise ValueError(f"Use a workspace-relative path: {value}")
    if path == Path("."):
        raise ValueError("A file path is required")
    return path


def ensure_workspace_state(path):
    path = relative_path(path)
    if not path.resolve().is_relative_to(Path.cwd().resolve()):
        raise ValueError("The review record must stay inside the workspace")
    if path.parts[:1] == (".git",):
        raise ValueError("The review record cannot be stored inside .git")
    return path


def require_text(value, name, *, allow_empty=False):
    if not isinstance(value, str):
        raise TypeError(f"{name} must be a string")
    if not allow_empty and not value.strip():
        raise ValueError(f"{name} cannot be blank")
    return value


def normalize_change_id(value):
    value = require_text(value, "Change id")
    if not CHANGE_ID.fullmatch(value):
        raise ValueError(
            "Change ids use lowercase letters, digits, '.', '_' or '-' "
            "(80 characters maximum)"
        )
    return value


def new_id(prefix):
    return f"{prefix}-{secrets.token_hex(5)}"


def normalize_paths(values):
    if not values:
        raise ValueError("At least one workspace-relative path is required")
    result = []
    for value in values:
        name = str(relative_path(value))
        if name not in result:
            result.append(name)
    return result


def slug(value):
    result = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return (result or "change")[:72]


def git_output(repo, *args, env=None):
    result = subprocess.run(
        ("git", "--no-pager", *args),
        cwd=repo,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        env=env,
    )
    if result.returncode:
        message = result.stderr.decode("utf-8", "replace").strip()
        raise ValueError(message or f"git {' '.join(args)} failed")
    return result.stdout.decode("utf-8", "replace").strip()


def resolve_git_commit(value, *, required=True):
    try:
        root = Path(git_output(Path.cwd(), "rev-parse", "--show-toplevel"))
        return git_output(root, "rev-parse", "--verify", f"{value}^{{commit}}")
    except (OSError, ValueError) as error:
        if required:
            raise ValueError(f"Cannot resolve a stable Git revision: {value}") from error
        return None


def snapshot_worktree():
    """Turn the current worktree into a stable commit without changing the index."""
    try:
        root = Path(git_output(Path.cwd(), "rev-parse", "--show-toplevel"))
    except (OSError, ValueError):
        return None
    try:
        parent = git_output(root, "rev-parse", "--verify", "HEAD")
    except ValueError:
        parent = ""
    with tempfile.TemporaryDirectory(prefix="review-with-me-index-") as temporary:
        env = {
            **os.environ,
            "GIT_INDEX_FILE": str(Path(temporary) / "index"),
            "GIT_OPTIONAL_LOCKS": "0",
            "GIT_AUTHOR_NAME": "Review With Me",
            "GIT_AUTHOR_EMAIL": "review-with-me@localhost",
            "GIT_COMMITTER_NAME": "Review With Me",
            "GIT_COMMITTER_EMAIL": "review-with-me@localhost",
        }
        git_output(root, "read-tree", "HEAD" if parent else "--empty", env=env)
        git_output(root, "add", "--all", "--", ".", env=env)
        tree = git_output(root, "write-tree", env=env)
        args = ["commit-tree", tree]
        if parent:
            args.extend(("-p", parent))
        args.extend(("-m", "Review With Me worktree snapshot"))
        commit = git_output(root, *args, env=env)
    git_output(
        root,
        "update-ref",
        f"refs/review-with-me/snapshots/{commit}",
        commit,
    )
    return commit


def require_worktree_snapshot():
    snapshot = snapshot_worktree()
    if snapshot is None:
        raise ValueError(
            "Cannot snapshot WORKTREE outside a Git repository; review changes "
            "need a stable Git revision"
        )
    return snapshot


def migrate_legacy(state):
    if "files" not in state or "changes" in state:
        return state
    base = state.get("base", "HEAD")
    changes = []
    used = set()
    for item in state["files"]:
        path = str(relative_path(item["path"]))
        change_id = slug(path)
        suffix = 2
        while change_id in used:
            change_id = f"{slug(path)}-{suffix}"
            suffix += 1
        used.add(change_id)
        legacy_status = item.get("status", "pending")
        status = {
            "pending": "unreviewed",
            "discussing": "reviewing",
            "revisit": "revisit",
            "reviewed": "accepted",
            "excluded": "superseded",
        }[legacy_status]
        annotations = []
        for note in item.get("feedback", []):
            outcome = note.get("outcome", "").strip()
            annotation_id = new_id("a")
            annotations.append(
                {
                    "id": annotation_id,
                    "author": "user",
                    "kind": "change",
                    "body": note["text"],
                    "revision_id": "r1",
                    "suggestion": "",
                    "path": path,
                    "side": "file",
                    "start_line": None,
                    "end_line": None,
                    "excerpt": "",
                    "status": "resolved" if outcome else "open",
                    "replies": (
                        [
                            {
                                "id": new_id("m"),
                                "author": "agent",
                                "body": outcome,
                                "created_at": now(),
                            }
                        ]
                        if outcome
                        else []
                    ),
                    "created_at": now(),
                    "updated_at": now(),
                }
            )
        changes.append(
            {
                "id": change_id,
                "title": path,
                "status": status,
                "summary": item.get("summary", ""),
                "rationale": "",
                "paths": [path],
                "superseded_by": "",
                "revisions": [
                    {
                        "id": "r1",
                        "label": "Legacy review",
                        "base": base,
                        "head": "WORKTREE",
                        "paths": [path],
                        "summary": item.get("summary", ""),
                        "reason": "",
                        "created_at": now(),
                    }
                ],
                "annotations": annotations,
                "created_at": now(),
                "updated_at": now(),
            }
        )
    return {
        "version": SCHEMA_VERSION,
        "goal": state["goal"],
        "scope": state["scope"],
        "base": base,
        "head": "WORKTREE",
        "overview": state.get("overview", ""),
        "created_at": now(),
        "updated_at": now(),
        "changes": changes,
    }


def migrate_annotations(state):
    if state.get("version") != SCHEMA_VERSION:
        return state
    for change in state.get("changes", []):
        revisions = change.get("revisions", [])
        revision_id = revisions[-1]["id"] if revisions else ""
        for note in change.get("annotations", []):
            note.setdefault("revision_id", revision_id)
    return state


def migrate_refs(state):
    for key in ("base",):
        value = state.get(key)
        if value and value != "WORKTREE" and not COMMIT_ID.fullmatch(value):
            resolved = resolve_git_commit(value, required=False)
            if resolved:
                state[key] = resolved
    for change in state.get("changes", []):
        for revision in change.get("revisions", []):
            for key in ("base", "head"):
                value = revision.get(key)
                if (
                    value
                    and value != "WORKTREE"
                    and not COMMIT_ID.fullmatch(value)
                ):
                    resolved = resolve_git_commit(value, required=False)
                    if resolved:
                        revision[key] = resolved
    return state


def validate_annotation(change, note, seen_ids, revision_ids):
    if not isinstance(note, dict):
        raise TypeError(f"Invalid annotation in {change['id']}")
    require_text(note.get("id"), "Annotation id")
    if note["id"] in seen_ids:
        raise ValueError(f"Duplicate annotation id: {note['id']}")
    seen_ids.add(note["id"])
    if note.get("author") not in ("user", "agent"):
        raise ValueError(f"Unknown annotation author: {note.get('author')}")
    if note.get("kind") not in ANNOTATION_KINDS:
        raise ValueError(f"Unknown annotation kind: {note.get('kind')}")
    if note.get("status") not in ANNOTATION_STATUSES:
        raise ValueError(f"Unknown annotation status: {note.get('status')}")
    require_text(note.get("body"), "Annotation body")
    require_text(note.get("suggestion", ""), "Annotation suggestion", allow_empty=True)
    require_text(note.get("excerpt", ""), "Annotation excerpt", allow_empty=True)
    if note.get("revision_id") not in revision_ids:
        raise ValueError(
            f"Annotation revision is outside change {change['id']}: "
            f"{note.get('revision_id')}"
        )
    if note.get("side") not in ("old", "new", "file"):
        raise ValueError(f"Unknown annotation side: {note.get('side')}")
    if note.get("path") is not None:
        path = str(relative_path(note["path"]))
        if path not in change["paths"]:
            raise ValueError(
                f"Annotation path is outside change {change['id']}: {path}"
            )
    if note["side"] == "file":
        if note.get("start_line") is not None or note.get("end_line") is not None:
            raise ValueError("File-level annotations cannot set line numbers")
    else:
        if note.get("path") is None:
            raise ValueError("Line annotations need a path")
        for key in ("start_line", "end_line"):
            if not isinstance(note.get(key), int) or note[key] < 1:
                raise ValueError(f"Line annotations need a positive {key}")
        if note["end_line"] < note["start_line"]:
            raise ValueError("end_line must not precede start_line")
    replies = note.get("replies", [])
    if not isinstance(replies, list):
        raise TypeError("Annotation replies must be a list")
    for reply in replies:
        if not isinstance(reply, dict):
            raise TypeError("Invalid annotation reply")
        require_text(reply.get("id"), "Reply id")
        if reply.get("author") not in ("user", "agent"):
            raise ValueError(f"Unknown reply author: {reply.get('author')}")
        require_text(reply.get("body"), "Reply body")


def validate_state(state):
    if not isinstance(state, dict):
        raise TypeError("The review record must be a JSON object")
    if state.get("version") != SCHEMA_VERSION:
        raise ValueError(f"Unsupported review record version: {state.get('version')}")
    for key in (
        "goal",
        "scope",
        "base",
        "head",
        "overview",
        "created_at",
        "updated_at",
    ):
        require_text(state.get(key), key, allow_empty=key == "overview")
    changes = state.get("changes")
    if not isinstance(changes, list):
        raise TypeError("The review record needs a 'changes' list")
    seen_changes = set()
    seen_annotations = set()
    for change in changes:
        if not isinstance(change, dict):
            raise TypeError("Each change must be an object")
        change_id = normalize_change_id(change.get("id"))
        if change_id in seen_changes:
            raise ValueError(f"Duplicate change id: {change_id}")
        seen_changes.add(change_id)
        require_text(change.get("title"), f"title for {change_id}")
        if change.get("status") not in STATUSES:
            raise ValueError(f"Unknown change status: {change.get('status')}")
        require_text(change.get("summary", ""), "Change summary", allow_empty=True)
        require_text(change.get("rationale", ""), "Change rationale", allow_empty=True)
        paths = normalize_paths(change.get("paths"))
        if paths != change.get("paths"):
            raise ValueError(f"Non-normalized paths in {change_id}")
        superseded_by = change.get("superseded_by", "")
        require_text(superseded_by, "superseded_by", allow_empty=True)
        revisions = change.get("revisions")
        if not isinstance(revisions, list) or not revisions:
            raise ValueError(f"Change {change_id} needs at least one revision")
        seen_revisions = set()
        for revision in revisions:
            if not isinstance(revision, dict):
                raise TypeError(f"Invalid revision in {change_id}")
            require_text(revision.get("id"), "Revision id")
            if revision["id"] in seen_revisions:
                raise ValueError(f"Duplicate revision id in {change_id}")
            seen_revisions.add(revision["id"])
            require_text(revision.get("label"), "Revision label")
            require_text(revision.get("base"), "Revision base")
            require_text(revision.get("head"), "Revision head")
            revision_paths = normalize_paths(revision.get("paths"))
            if revision_paths != revision.get("paths"):
                raise ValueError(f"Non-normalized revision paths in {change_id}")
            require_text(
                revision.get("summary", ""), "Revision summary", allow_empty=True
            )
            require_text(revision.get("reason", ""), "Revision reason", allow_empty=True)
            require_text(revision.get("created_at"), "Revision created_at")
        revision_ids = seen_revisions
        annotations = change.get("annotations")
        if not isinstance(annotations, list):
            raise TypeError(f"Change {change_id} needs an annotations list")
        for note in annotations:
            validate_annotation(change, note, seen_annotations, revision_ids)
    return state


def load(path):
    state = json.loads(path.read_text(encoding="utf-8"))
    state = migrate_legacy(state)
    state = migrate_annotations(state)
    state = migrate_refs(state)
    return validate_state(state)


def prepare_state(path):
    with locked_state(path):
        pass


def save(path, state):
    state["updated_at"] = now()
    validate_state(state)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=path.parent, delete=False
        ) as stream:
            temporary = Path(stream.name)
            json.dump(state, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
        temporary.replace(path)
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()


@contextlib.contextmanager
def locked_state(path, *, create=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    lock_path = path.with_name(path.name + ".lock")
    with lock_path.open("a+", encoding="utf-8") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if create:
            if path.exists():
                raise FileExistsError(f"Review record already exists: {path}")
            state = None
        else:
            state = load(path)
        yield state
        if state is not None:
            save(path, state)
        fcntl.flock(lock, fcntl.LOCK_UN)


def find_change(state, change_id):
    change_id = normalize_change_id(change_id)
    for change in state["changes"]:
        if change["id"] == change_id:
            return change
    raise ValueError(f"Unknown change: {change_id}")


def find_annotation(change, annotation_id):
    for note in change["annotations"]:
        if note["id"] == annotation_id:
            return note
    raise ValueError(f"Unknown annotation in {change['id']}: {annotation_id}")


def is_actionable(note):
    return note["author"] == "user" and note["kind"] in ACTIONABLE_KINDS


def open_feedback(change):
    return [
        note
        for note in change["annotations"]
        if is_actionable(note) and note["status"] == "open"
    ]


def change_for_annotation(state, annotation_id):
    for change in state["changes"]:
        for note in change["annotations"]:
            if note["id"] == annotation_id:
                return change, note
    raise ValueError(f"Unknown annotation: {annotation_id}")


def touch(change):
    change["updated_at"] = now()


def add_annotation(
    change,
    *,
    author,
    kind,
    body,
    revision_id=None,
    path=None,
    side="file",
    start=None,
    end=None,
    excerpt="",
    suggestion="",
    status="open",
):
    require_text(body, "Annotation body")
    if kind not in ANNOTATION_KINDS:
        raise ValueError(f"Unknown annotation kind: {kind}")
    if author not in ("user", "agent"):
        raise ValueError(f"Unknown annotation author: {author}")
    if side not in ("old", "new", "file"):
        raise ValueError(f"Unknown annotation side: {side}")
    revision_id = revision_id or change["revisions"][-1]["id"]
    if revision_id not in {item["id"] for item in change["revisions"]}:
        raise ValueError(f"Unknown revision for annotation: {revision_id}")
    if side == "file":
        if path is not None:
            path = str(relative_path(path))
            if path not in change["paths"]:
                raise ValueError(f"Annotation path is outside this change: {path}")
        start = None
        end = None
        excerpt = ""
    else:
        path = str(relative_path(path))
        if path not in change["paths"]:
            raise ValueError(f"Annotation path is outside this change: {path}")
        if not isinstance(start, int) or not isinstance(end, int):
            raise ValueError("Line annotations need integer start and end lines")
        if start < 1 or end < start:
            raise ValueError("Line annotation range is invalid")
    stamp = now()
    note = {
        "id": new_id("a"),
        "author": author,
        "kind": kind,
        "body": body,
        "revision_id": revision_id,
        "suggestion": suggestion,
        "path": path,
        "side": side,
        "start_line": start,
        "end_line": end,
        "excerpt": excerpt,
        "status": status,
        "replies": [],
        "created_at": stamp,
        "updated_at": stamp,
    }
    change["annotations"].append(note)
    if (
        author == "user"
        and kind in ACTIONABLE_KINDS
        and change["status"] != "superseded"
    ):
        change["status"] = "feedback"
    touch(change)
    return note


def reply_to_annotation(change, note, *, author, body, resolve=False):
    if author not in ("user", "agent"):
        raise ValueError(f"Unknown reply author: {author}")
    require_text(body, "Reply body")
    stamp = now()
    note["replies"].append(
        {
            "id": new_id("m"),
            "author": author,
            "body": body,
            "created_at": stamp,
        }
    )
    if resolve:
        note["status"] = "resolved"
    note["updated_at"] = stamp
    if (
        note["status"] != "open"
        and change["status"] not in ("accepted", "superseded")
        and not open_feedback(change)
    ):
        change["status"] = "reviewing"
    touch(change)


def add_change(
    state,
    *,
    change_id,
    title,
    paths,
    summary,
    rationale,
    base=None,
    head="WORKTREE",
    label="Initial implementation",
):
    change_id = normalize_change_id(change_id)
    if any(change["id"] == change_id for change in state["changes"]):
        raise ValueError(f"Change already exists: {change_id}")
    require_text(title, "Change title")
    require_text(summary, "Change summary")
    require_text(rationale, "Change rationale")
    paths = normalize_paths(paths)
    stamp = now()
    change = {
        "id": change_id,
        "title": title,
        "status": "unreviewed",
        "summary": summary,
        "rationale": rationale,
        "paths": paths,
        "superseded_by": "",
        "revisions": [
            {
                "id": "r1",
                "label": label,
                "base": base or state["base"],
                "head": head,
                "paths": paths,
                "summary": summary,
                "reason": "",
                "created_at": stamp,
            }
        ],
        "annotations": [],
        "created_at": stamp,
        "updated_at": stamp,
    }
    state["changes"].append(change)
    return change


def revise_change(change, *, head, label, summary, reason, paths=None):
    require_text(head, "Revision head")
    require_text(label, "Revision label")
    require_text(summary, "Revision summary")
    require_text(reason, "Revision reason")
    previous = change["revisions"][-1]
    if previous["head"] == "WORKTREE":
        raise ValueError(
            "The current revision depends on WORKTREE and cannot be used as a "
            "stable base. Commit or otherwise anchor it before adding a revision."
        )
    revision_paths = normalize_paths(paths or previous["paths"])
    revision = {
        "id": f"r{len(change['revisions']) + 1}",
        "label": label,
        "base": previous["head"],
        "head": head,
        "paths": revision_paths,
        "summary": summary,
        "reason": reason,
        "created_at": now(),
    }
    change["revisions"].append(revision)
    for path in revision_paths:
        if path not in change["paths"]:
            change["paths"].append(path)
    if change["status"] == "accepted":
        change["status"] = "revisit"
    touch(change)
    return revision


def set_status(change, status):
    if status not in STATUSES:
        raise ValueError(f"Unknown status: {status}")
    if status == "accepted" and open_feedback(change):
        raise ValueError("Resolve open user feedback before accepting this change")
    change["status"] = status
    touch(change)


def show(state, selected=None):
    changes = state["changes"]
    accepted = sum(change["status"] == "accepted" for change in changes)
    superseded = sum(change["status"] == "superseded" for change in changes)
    feedback = sum(len(open_feedback(change)) for change in changes)
    unreviewed = [
        change
        for change in changes
        if change["status"] in ("unreviewed", "revisit")
    ]
    remaining = [
        change
        for change in changes
        if change["status"] not in ("accepted", "superseded")
        or open_feedback(change)
    ]
    print(f"Goal: {state['goal']}\nScope: {state['scope']}")
    print(f"Compare: {state['base']} .. {state['head']}")
    print(
        f"Accepted: {accepted}/{len(changes)}; unreviewed/revisit: "
        f"{len(unreviewed)}; superseded: {superseded}; open feedback: {feedback}"
    )
    print("Complete: " + ("yes" if not remaining else "no"))
    print("Next: " + (remaining[0]["id"] if remaining else "none"))
    if state["overview"]:
        print(f"\nOverview: {state['overview']}")
    items = [selected] if selected is not None else changes
    for change in items:
        print(
            f"\n[{change['status']}] {change['id']} - {change['title']} "
            f"({', '.join(change['paths'])})"
        )
        if selected is None:
            continue
        revision = change["revisions"][-1]
        print(f"Diff: {revision['base']} .. {revision['head']} ({revision['label']})")
        if change["summary"]:
            print(f"Summary: {change['summary']}")
        if change["rationale"]:
            print(f"Why: {change['rationale']}")
        if change.get("superseded_by"):
            print(f"Superseded by: {change['superseded_by']}")
        for note in change["annotations"]:
            location = "file"
            if note["side"] != "file":
                location = (
                    f"{note['path']}:{note['start_line']}"
                    f"-{note['end_line']} ({note['side']})"
                )
            print(
                f"  [{note['status']}] {note['id']} "
                f"{note['author']}/{note['kind']} @ {note['revision_id']} "
                f"{location}"
            )
            print(f"    {note['body']}")
            if note["suggestion"]:
                print("    Suggestion: " + note["suggestion"].replace("\n", "\n      "))
            for reply in note["replies"]:
                print(f"    - {reply['author']}: {reply['body']}")


def parser():
    cli = argparse.ArgumentParser(
        description=__doc__,
        epilog=(
            "Start with 'init', add semantic review units with 'add', then run "
            "'serve'. Use 'revise' when code changes after feedback."
        ),
    )
    commands = cli.add_subparsers(dest="command", required=True)

    init = commands.add_parser("init", help="Create a review record")
    init.add_argument("--state", required=True)
    init.add_argument("--goal", required=True)
    init.add_argument("--scope", required=True)
    init.add_argument("--base", default="HEAD")
    init.add_argument("--overview", default="")

    add = commands.add_parser("add", help="Add a semantic review unit")
    add.add_argument("--state", required=True)
    add.add_argument("--id", required=True)
    add.add_argument("--title", required=True)
    add.add_argument("--paths", nargs="+", required=True)
    add.add_argument("--summary", required=True)
    add.add_argument("--rationale", required=True)
    add.add_argument("--base")
    add.add_argument("--head", default="WORKTREE")
    add.add_argument("--label", default="Initial implementation")

    update = commands.add_parser(
        "update", help="Update a review unit's title, summary, rationale, or paths"
    )
    update.add_argument("--state", required=True)
    update.add_argument("--change", required=True)
    update.add_argument("--title")
    update.add_argument("--summary")
    update.add_argument("--rationale")
    update.add_argument("--paths", nargs="+")

    revise = commands.add_parser(
        "revise", help="Append a reproducible follow-up revision"
    )
    revise.add_argument("--state", required=True)
    revise.add_argument("--change", required=True)
    revise.add_argument("--head", required=True)
    revise.add_argument("--label", required=True)
    revise.add_argument("--summary", required=True)
    revise.add_argument("--reason", required=True)
    revise.add_argument("--paths", nargs="+")

    status = commands.add_parser("status", help="Set a change's review state")
    status.add_argument("--state", required=True)
    status.add_argument("--change", required=True)
    status.add_argument("--status", choices=STATUSES, required=True)
    status.add_argument("--superseded-by", default="")

    annotate = commands.add_parser("annotate", help="Add an agent explanation")
    annotate.add_argument("--state", required=True)
    annotate.add_argument("--change", required=True)
    annotate.add_argument("--revision")
    annotate.add_argument("--kind", choices=ANNOTATION_KINDS, default="note")
    annotate.add_argument("--body", required=True)
    annotate.add_argument("--path")
    annotate.add_argument("--side", choices=("old", "new", "file"), default="file")
    annotate.add_argument("--start", type=int)
    annotate.add_argument("--end", type=int)
    annotate.add_argument("--excerpt", default="")
    annotate.add_argument("--suggestion", default="")

    respond = commands.add_parser("respond", help="Reply to review feedback")
    respond.add_argument("--state", required=True)
    respond.add_argument("--change", required=True)
    respond.add_argument("--annotation", required=True)
    respond.add_argument("--body", required=True)
    respond.add_argument("--resolve", action="store_true")

    resolve = commands.add_parser("resolve", help="Change an annotation's state")
    resolve.add_argument("--state", required=True)
    resolve.add_argument("--change", required=True)
    resolve.add_argument("--annotation", required=True)
    resolve.add_argument("--status", choices=ANNOTATION_STATUSES, required=True)

    overview = commands.add_parser("overview", help="Set the cross-change overview")
    overview.add_argument("--state", required=True)
    overview.add_argument("--text", required=True)

    show_parser = commands.add_parser("show", help="Show review progress")
    show_parser.add_argument("--state", required=True)
    show_parser.add_argument("--change")
    show_parser.add_argument("--json", action="store_true")

    inbox = commands.add_parser(
        "inbox", help="Show actionable feedback that still needs an answer"
    )
    inbox.add_argument("--state", required=True)

    serve = commands.add_parser("serve", help="Run the review frontend")
    serve.add_argument("--state", required=True)
    serve.add_argument("--host", default="127.0.0.1")
    serve.add_argument("--port", type=int, default=0)
    return cli


def run(args):
    path = ensure_workspace_state(args.state)
    if args.command == "serve":
        if not path.exists():
            raise ValueError(f"Review record does not exist: {path}")
        from review_server import serve

        serve(path, args.host, args.port)
        return
    if args.command == "show":
        state = load(path)
        if args.json:
            print(json.dumps(state, ensure_ascii=False, indent=2))
        else:
            show(state, find_change(state, args.change) if args.change else None)
        return
    if args.command == "inbox":
        state = load(path)
        pending = []
        for change in state["changes"]:
            for note in open_feedback(change):
                pending.append((change, note))
        print(f"Open actionable feedback: {len(pending)}")
        for change, note in pending:
            location = "change"
            if note["side"] != "file":
                location = (
                    f"{note['path']}:{note['start_line']}-{note['end_line']} "
                    f"({note['side']})"
                )
            elif note.get("path"):
                location = note["path"]
            print(
                f"\n{change['id']} [{change['status']}] {change['title']}\n"
                f"  {note['id']} {note['kind']} @ {note['revision_id']} {location}\n"
                f"  {note['body']}"
            )
            if note["suggestion"]:
                print("  Suggestion:")
                print("    " + note["suggestion"].replace("\n", "\n    "))
        return
    if args.command == "init":
        base = resolve_git_commit(args.base)
        with locked_state(path, create=True):
            stamp = now()
            state = {
                "version": SCHEMA_VERSION,
                "goal": args.goal,
                "scope": args.scope,
                "base": base,
                "head": "WORKTREE",
                "overview": args.overview,
                "created_at": stamp,
                "updated_at": stamp,
                "changes": [],
            }
            validate_state(state)
            save(path, state)
        show(load(path))
        return
    with locked_state(path) as state:
        if args.command == "add":
            head = args.head
            if head == "WORKTREE":
                head = require_worktree_snapshot()
            else:
                head = resolve_git_commit(head)
            add_change(
                state,
                change_id=args.id,
                title=args.title,
                paths=args.paths,
                summary=args.summary,
                rationale=args.rationale,
                base=resolve_git_commit(args.base) if args.base else None,
                head=head,
                label=args.label,
            )
            selected = find_change(state, args.id)
        elif args.command == "update":
            selected = find_change(state, args.change)
            if (
                args.title is None
                and args.summary is None
                and args.rationale is None
                and args.paths is None
            ):
                raise ValueError("Provide at least one field to update")
            if args.title is not None:
                selected["title"] = require_text(args.title, "Change title")
            if args.summary is not None:
                selected["summary"] = require_text(
                    args.summary, "Change summary", allow_empty=True
                )
            if args.rationale is not None:
                selected["rationale"] = require_text(
                    args.rationale, "Change rationale", allow_empty=True
                )
            if args.paths is not None:
                selected["paths"] = normalize_paths(args.paths)
            touch(selected)
        elif args.command == "revise":
            selected = find_change(state, args.change)
            head = args.head
            if head == "WORKTREE":
                head = require_worktree_snapshot()
            else:
                head = resolve_git_commit(head)
            revise_change(
                selected,
                head=head,
                label=args.label,
                summary=args.summary,
                reason=args.reason,
                paths=args.paths,
            )
        elif args.command == "status":
            selected = find_change(state, args.change)
            set_status(selected, args.status)
            if args.superseded_by:
                find_change(state, args.superseded_by)
                selected["superseded_by"] = args.superseded_by
        elif args.command == "annotate":
            selected = find_change(state, args.change)
            add_annotation(
                selected,
                author="agent",
                kind=args.kind,
                body=args.body,
                revision_id=args.revision,
                path=args.path,
                side=args.side,
                start=args.start,
                end=args.end,
                excerpt=args.excerpt,
                suggestion=args.suggestion,
            )
        elif args.command == "respond":
            selected = find_change(state, args.change)
            note = find_annotation(selected, args.annotation)
            reply_to_annotation(
                selected,
                note,
                author="agent",
                body=args.body,
                resolve=args.resolve,
            )
        elif args.command == "resolve":
            selected = find_change(state, args.change)
            note = find_annotation(selected, args.annotation)
            note["status"] = args.status
            note["updated_at"] = now()
            if (
                args.status != "open"
                and selected["status"] not in ("accepted", "superseded")
                and not open_feedback(selected)
            ):
                selected["status"] = "reviewing"
            touch(selected)
        elif args.command == "overview":
            state["overview"] = args.text
            selected = None
        else:
            raise ValueError(f"Unsupported command: {args.command}")
        show(state, selected)


def main():
    cli = parser()
    args = cli.parse_args()
    try:
        run(args)
    except (OSError, TypeError, ValueError) as error:
        cli.exit(1, f"Review record {args.state}: {error}\n")


if __name__ == "__main__":
    main()
