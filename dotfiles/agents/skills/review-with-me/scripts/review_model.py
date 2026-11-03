"""One persisted review, one transactional action API for the UI and agent."""

import copy
import fcntl
import json
import math
import os
import tempfile
import time
import uuid
from contextlib import contextmanager
from pathlib import Path

from review_git import blocks, capture_files, commit, comparison, path_name, repository


def text(value, label="内容"):
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{label}不能为空")
    return value.strip()


def choice(value, options):
    if value not in options:
        raise ValueError(f"无效值 {value!r}；可选值：{', '.join(options)}")
    return value


def identity():
    return uuid.uuid4().hex[:12]


def find(items, key):
    item = next((item for item in items if item["id"] == key), None)
    if item is None:
        raise ValueError(f"找不到：{key}")
    return item


def read(path):
    state = json.loads(Path(path).read_text())
    if state.get("version") != 4:
        raise ValueError(
            "这是旧版记录；请使用 import 命令导入到新的记录文件，原文件会保留"
        )
    return state


@contextmanager
def transaction(path, create=False):
    path = Path(path)
    root = Path(repository(Path.cwd()))
    if (
        path.is_absolute()
        or not path.resolve().is_relative_to(root)
        or ".git" in path.parts
    ):
        raise ValueError("审阅记录必须使用仓库内的相对路径")
    path.parent.mkdir(parents=True, exist_ok=True)
    with Path(str(path) + ".lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if create and path.exists():
            raise ValueError("记录已存在，请继续现有审阅或使用另一个路径")
        state = {} if create else read(path)
        yield state
        state["updated"] = time.time_ns()
        temp = None
        try:
            with tempfile.NamedTemporaryFile(
                "w", dir=path.parent, delete=False, encoding="utf-8"
            ) as stream:
                temp = Path(stream.name)
                json.dump(state, stream, ensure_ascii=False, allow_nan=False)
                stream.write("\n")
                stream.flush()
                os.fsync(stream.fileno())
            temp.replace(path)
        finally:
            if temp and temp.exists():
                temp.unlink()


def initialize(path, title, base, scope):
    repo = repository(Path.cwd())
    with transaction(path, create=True) as state:
        state.update(
            version=4,
            repo=repo,
            title=text(title),
            base=commit(repo, base),
            scope=[path_name(p) for p in scope],
            revisions=[],
            groups=[],
            threads=[],
            listener={"enabled": False, "thread_id": "", "error": ""},
        )
    return read(path)


def capture(state, path, action):
    include = [path_name(p) for p in action.get("include", [])]
    if state["revisions"]:
        include = list(
            set(include)
            | {
                p
                for p, f in state["revisions"][-1]["files"].items()
                if f["status"] == "context"
            }
        )
    files = capture_files(
        state["repo"],
        state["base"],
        action.get("head", "WORKTREE"),
        state["scope"],
        include,
        path,
    )
    previous = state["revisions"][-1] if state["revisions"] else None
    readable = all(
        side is None or side["text"] is not None
        for file in files.values()
        for side in (file["old"], file["new"])
    )
    if previous and readable and files == previous["files"]:
        return previous["id"]
    revision = {
        "id": f"r{len(state['revisions']) + 1}",
        "label": text(action.get("label", "当前修改")),
        "created": time.time(),
        "files": files,
        "decisions": {},
        "checks": {},
    }
    if previous:
        unchanged = set()
        for p, file in files.items():
            # Binary/oversized contents cannot establish unchanged content.
            readable = all(
                side is None or side["text"] is not None
                for side in (file["old"], file["new"])
            )
            if readable and file == previous["files"].get(p):
                unchanged.add(p)
            if p in previous["decisions"]:
                carried = carry_decision(
                    previous["files"][p], file, previous["decisions"][p]
                )
                if carried:
                    revision["decisions"][p] = carried
        for group in state["groups"]:
            if all(p in unchanged for p in group["paths"]):
                for check in group["checks"]:
                    if check["id"] in previous["checks"]:
                        revision["checks"][check["id"]] = previous["checks"][
                            check["id"]
                        ]
    state["revisions"].append(revision)
    return revision["id"]


def carry_decision(before, after, decision):
    if any(
        side and side["text"] is None
        for file in (before, after)
        for side in (file["old"], file["new"])
    ):
        return {}
    if before == after:
        return copy.deepcopy(decision)
    if (
        before["old"] != after["old"]
        or before["old_path"] != after["old_path"]
        or before["new"] is None
        or after["new"] is None
        or before["new"]["mode"] != after["new"]["mode"]
    ):
        return {}

    def signature(block, lines):
        start = block["new_start"] - 1
        return (
            block["old_start"],
            block["old_count"],
            tuple(lines[start : start + block["new_count"]]),
        )

    old_lines = before["new"]["text"].splitlines(keepends=True)
    new_lines = after["new"]["text"].splitlines(keepends=True)
    prior = {signature(block, old_lines): block for block in blocks(before)}
    result = {"status": "pending", "blocks": {}, "regions": []}
    default = {k: v for k, v in decision.items() if k not in ("blocks", "regions")}
    for block in blocks(after):
        old_block = prior.get(signature(block, new_lines))
        if old_block is None:
            continue
        result["blocks"][block["id"]] = copy.deepcopy(
            decision.get("blocks", {}).get(old_block["id"], default)
        )
        # Keep overlapping selection decisions in their original order. Only the
        # unchanged block is carried; a line shift never widens an approval.
        for region in decision.get("regions", []):
            side = region["side"]
            start = max(region["start"], old_block[f"{side}_start"])
            end = min(
                region["end"],
                old_block[f"{side}_start"] + old_block[f"{side}_count"] - 1,
            )
            if start <= end:
                offset = block[f"{side}_start"] - old_block[f"{side}_start"]
                result["regions"].append(
                    {**region, "start": start + offset, "end": end + offset}
                )
    return result if result["blocks"] or result["regions"] else {}


def targets(state, action):
    revision, _ = comparison(state, action.get("revision"))
    _, viewed_files = comparison(state, revision["id"], action.get("against", "base"))
    result = []
    values = action.get("targets", [])
    if not isinstance(values, list) or len(values) > 100:
        raise ValueError("标注目标必须是数组，最多 100 处")
    for value in values:
        if not isinstance(value, dict):
            raise TypeError("每个标注目标必须是对象")
        path = path_name(value["path"])
        if path not in viewed_files:
            raise ValueError(f"该对比中没有文件：{path}")
        side = choice(value.get("side", "new"), ["old", "new", "file"])
        target = {"path": path, "side": side}
        if side != "file":
            file_side = viewed_files[path][side]
            if not file_side or file_side["text"] is None:
                raise ValueError("该侧没有可标注的文本")
            lines = file_side["text"].splitlines()
            start, end = value.get("start"), value.get("end", value.get("start"))
            if (
                type(start) is not int
                or type(end) is not int
                or not 1 <= start <= end <= len(lines)
            ):
                raise ValueError("标注行号超出文件范围")
            quote = value.get("quote", "\n".join(lines[start - 1 : end]))
            if not isinstance(quote, str) or quote not in "\n".join(
                lines[start - 1 : end]
            ):
                raise ValueError("选中文字不在指定行内")
            target.update(start=start, end=end, quote=quote)
        if "drawing" in value:
            drawing = value["drawing"]
            if not isinstance(drawing, dict):
                raise ValueError("drawing 必须是圈画对象")
            points = drawing.get("points", [])
            if not isinstance(points, list) or not 2 <= len(points) <= 2000:
                raise ValueError("圈画需要 2 至 2000 个点")
            if any(
                not isinstance(p, list)
                or len(p) != 2
                or any(
                    type(n) not in (int, float)
                    or not math.isfinite(n)
                    or not 0 <= n <= 1
                    for n in p
                )
                for p in points
            ):
                raise ValueError("圈画坐标必须在 0 到 1 之间")
            target["drawing"] = {"points": points}
            if "width" in drawing:
                width = drawing["width"]
                if (
                    type(width) not in (int, float)
                    or not math.isfinite(width)
                    or width <= 0
                ):
                    raise ValueError("圈画宽度必须是正数")
                target["drawing"]["width"] = width
        result.append(target)
    return revision, result


def queue_message(note, body, author):
    message = {
        "id": identity(),
        "author": author,
        "body": text(body),
        "created": time.time(),
    }
    if author == "user":
        message.update(delivery="queued", error="")
    note["messages"].append(message)
    return message["id"]


def open_threads(state, revision, path):
    # Old unresolved discussions stay visible and block acceptance until answered.
    return [
        t
        for t in state["threads"]
        if t["status"] == "open"
        and t["kind"] != "note"
        and (not t["targets"] or any(a["path"] == path for a in t["targets"]))
    ]


def file_status(state, revision, path):
    decision = revision["decisions"].get(path, {})
    if open_threads(state, revision, path):
        return "feedback"
    if (
        not decision.get("blocks")
        and not decision.get("regions")
        and decision.get("status", "pending") != "pending"
    ):
        return decision["status"]
    changes = blocks(revision["files"][path])
    if changes and all(
        block_status(decision, b) in ("accepted", "excluded") for b in changes
    ):
        return (
            "accepted"
            if any(block_status(decision, b) == "accepted" for b in changes)
            else "excluded"
        )
    return "pending"


def block_status(decision, block):
    explicit = (
        decision.get("blocks", {})
        .get(block["id"], {})
        .get("status", decision.get("status", "pending"))
    )
    states = []
    for side in ("old", "new"):
        for line in range(
            block[f"{side}_start"], block[f"{side}_start"] + block[f"{side}_count"]
        ):
            covering = [
                r
                for r in decision.get("regions", [])
                if r["side"] == side and r["start"] <= line <= r["end"]
            ]
            states.append(covering[-1]["status"] if covering else explicit)
    return (
        "pending"
        if not states or "pending" in states
        else "accepted"
        if "accepted" in states
        else "excluded"
    )


def apply(state, path, action, actor="agent"):
    if not isinstance(action, dict):
        raise TypeError("操作必须是 JSON 对象")
    op = action.get("op")
    if op == "capture":
        if actor != "agent":
            raise ValueError("请让 Agent 登记修改后的版本")
        return capture(state, path, action)
    if op == "group":
        key = text(action.get("id")) if action.get("id") is not None else identity()
        group = next((g for g in state["groups"] if g["id"] == key), None)
        if group is None:
            group = {"id": key, "title": "", "summary": "", "paths": [], "checks": []}
            state["groups"].append(group)
        for field in ("title", "summary"):
            if field in action:
                group[field] = (
                    text(action[field]) if field == "title" else str(action[field])
                )
        text(group["title"], "分组名称")
        previous_paths = group["paths"]
        previous_checks = group["checks"]
        if "paths" in action:
            if not isinstance(action["paths"], list):
                raise ValueError("paths 必须是路径数组")
            group["paths"] = list(dict.fromkeys(path_name(p) for p in action["paths"]))
        if "checks" in action:
            if not isinstance(action["checks"], list) or any(
                not isinstance(c, dict) for c in action["checks"]
            ):
                raise ValueError("checks 必须是条件对象数组")
            group["checks"] = [
                {
                    "id": text(c["id"]) if c.get("id") else identity(),
                    "text": text(c["text"]),
                }
                for c in action["checks"]
            ]
        ids = [c["id"] for g in state["groups"] for c in g["checks"]]
        if len(set(ids)) != len(ids):
            raise ValueError("通过条件的 ID 必须唯一")
        if state["revisions"] and (
            previous_paths != group["paths"] or previous_checks != group["checks"]
        ):
            current_checks = state["revisions"][-1]["checks"]
            for check in previous_checks + group["checks"]:
                current_checks.pop(check["id"], None)
        return key
    if op == "ungroup":
        state["groups"].remove(find(state["groups"], action["id"]))
        return action["id"]
    if op == "comment":
        revision, anchors = targets(state, action)
        note = {
            "id": action.get("id") or identity(),
            "revision": revision["id"],
            "against": action.get("against", "base"),
            "targets": anchors,
            "kind": choice(
                action.get("kind", "question"), ["question", "change", "bug", "note"]
            ),
            "status": "open",
            "messages": [],
        }
        if any(t["id"] == note["id"] for t in state["threads"]):
            raise ValueError("标注 ID 已存在")
        queue_message(note, action["body"], actor)
        if action.get("suggestion"):
            note["suggestion"] = text(action["suggestion"])
        state["threads"].append(note)
        return note["id"]
    if op == "reply":
        note = find(state["threads"], action["id"])
        queue_message(note, action["body"], actor)
        if actor == "agent":
            # Only acknowledge messages actually read by this agent turn.
            for message in note["messages"]:
                if message.get("delivery") == "processing":
                    message["delivery"] = "answered"
        if action.get("resolve"):
            if any(
                m.get("delivery") in ("queued", "delivered", "failed")
                for m in note["messages"]
            ):
                raise ValueError("还有未读取的新反馈，请先读取再解决讨论")
            note["status"] = "resolved"
        elif actor == "user":
            note["status"] = "open"
        return note["id"]
    if op == "resolve":
        note = find(state["threads"], action["id"])
        status = choice(action["status"], ["open", "resolved", "dismissed"])
        if (
            actor == "agent"
            and status != "open"
            and note["messages"][-1]["author"] != "agent"
        ):
            raise ValueError("请先回复用户，再解决讨论")
        if (
            actor == "agent"
            and status != "open"
            and any(
                m.get("delivery") in ("queued", "delivered", "failed")
                for m in note["messages"]
            )
        ):
            raise ValueError("还有未读取的新反馈，请先读取再解决讨论")
        note["status"] = status
        return note["id"]
    if op == "decide":
        revision, files = comparison(state, action.get("revision"))
        status = choice(action["status"], ["pending", "accepted", "excluded"])
        reason = action.get("reason", "")
        if status == "excluded" or (actor == "agent" and status == "accepted"):
            text(reason, "排除原因或用户授权")
        if "targets" in action:
            if action.get("against", "base") != "base":
                raise ValueError("选区通过必须基于完整基线差异")
            _, regions = targets(state, action)
            if not regions or any(r["side"] == "file" for r in regions):
                raise ValueError("请指定代码行选区；整文件使用 path 或 paths")
            for region in regions:
                if status == "accepted" and open_threads(
                    state, revision, region["path"]
                ):
                    raise ValueError("该文件有未解决的反馈，请先处理讨论")
                decision = revision["decisions"].setdefault(
                    region["path"], {"status": "pending", "blocks": {}}
                )
                decision.setdefault("regions", []).append(
                    {
                        "side": region["side"],
                        "start": region["start"],
                        "end": region["end"],
                        "status": status,
                        "reason": reason,
                        "by": actor,
                    }
                )
            return status
        for p in action.get("paths", [action.get("path")]):
            p = path_name(p)
            if p not in files:
                raise ValueError(f"版本中没有文件：{p}")
            if status == "accepted" and open_threads(state, revision, p):
                raise ValueError("该文件有未解决的反馈，请先处理讨论")
            decision = revision["decisions"].setdefault(
                p, {"status": "pending", "blocks": {}}
            )
            result = {"status": status, "reason": reason, "by": actor}
            if "block" in action:
                block_id = str(action["block"])
                block = find(blocks(files[p]), block_id)
                # A later whole-block decision replaces earlier selections only
                # inside this block, preserving selections in neighboring code.
                regions = []
                for region in decision.get("regions", []):
                    side = region["side"]
                    start = block[f"{side}_start"]
                    end = start + block[f"{side}_count"] - 1
                    if end < start or region["end"] < start or region["start"] > end:
                        regions.append(region)
                    else:
                        if region["start"] < start:
                            regions.append({**region, "end": start - 1})
                        if region["end"] > end:
                            regions.append({**region, "start": end + 1})
                decision["regions"] = regions
                decision["blocks"][block_id] = result
            else:
                decision.update(result, blocks={}, regions=[])
        return status
    if op == "check":
        revision, _ = comparison(state, action.get("revision"))
        find([c for g in state["groups"] for c in g["checks"]], action["id"])
        status = choice(action["status"], ["pending", "passed", "failed"])
        if actor == "agent" and status == "passed":
            text(action.get("reason"), "检查结果或用户授权")
        revision["checks"][action["id"]] = {
            "status": status,
            "reason": action.get("reason", ""),
            "by": actor,
        }
        return status
    if op == "listen":
        listener = state["listener"]
        if "thread_id" in action:
            if actor != "agent":
                raise ValueError("只能由 Agent 绑定当前聊天")
            listener["thread_id"] = text(action["thread_id"])
        enabled = action.get("enabled", True)
        if type(enabled) is not bool:
            raise ValueError("enabled 必须是布尔值")
        if enabled and not listener["thread_id"]:
            raise ValueError("请让 Agent 先连接当前聊天")
        listener.update(enabled=enabled, error="")
        return listener
    if op == "retry":
        count = 0
        for note in state["threads"]:
            if action.get("id") and note["id"] != action["id"]:
                continue
            for message in note["messages"]:
                if message.get("delivery") in ("failed", "delivered", "processing"):
                    message.update(delivery="queued", error="")
                    count += 1
        return count
    raise ValueError(f"未知操作：{op}")


def mutate(path, actions, actor="agent"):
    with transaction(path) as state:
        results = [
            apply(state, path, a, actor)
            for a in (actions if isinstance(actions, list) else [actions])
        ]
    return results


def inbox(path, claim=False):
    def collect(state):
        events = []
        for note in state["threads"]:
            if note["status"] != "open":
                continue
            for message in note["messages"]:
                if message.get("delivery") not in ("queued", "delivered", "failed"):
                    continue
                events.append(
                    {
                        "thread": note["id"],
                        "revision": note["revision"],
                        "against": note["against"],
                        "targets": note["targets"],
                        "kind": note["kind"],
                        "suggestion": note.get("suggestion", ""),
                        "message": copy.deepcopy(message),
                        "conversation": copy.deepcopy(note["messages"]),
                    }
                )
                if claim:
                    message.update(delivery="processing", error="")
        return events

    if claim:
        with transaction(path) as state:
            if not state["listener"]["enabled"]:
                return []
            return collect(state)
    return collect(read(path))


def view(state, revision_id=None, against="base", with_text=False):
    result = {
        key: copy.deepcopy(value) for key, value in state.items() if key != "revisions"
    }
    result["revisions"] = [
        {k: r[k] for k in ("id", "label", "created")} for r in state["revisions"]
    ]
    if not state["revisions"]:
        result.update(files=[], revision=None, checks={})
        return result
    revision, files = comparison(state, revision_id, against)
    result.update(
        revision=revision["id"], against=against, checks=revision["checks"], files=[]
    )
    for path, file in sorted(files.items()):
        entry = copy.deepcopy(file)
        entry.update(
            blocks=blocks(file),
            decision=revision["decisions"].get(
                path, {"status": "pending", "blocks": {}}
            ),
            review_status=file_status(state, revision, path)
            if path in revision["files"]
            else "pending",
        )
        if not with_text:
            for side in ("old", "new"):
                if entry[side]:
                    entry[side].pop("text")
        result["files"].append(entry)
        for block in entry["blocks"]:
            block["review_status"] = (
                block_status(entry["decision"], block)
                if against == "base"
                else "pending"
            )
    checks = [c for g in state["groups"] for c in g["checks"]]
    result["summary"] = {
        "pending_files": sum(
            f["review_status"] in ("pending", "feedback") for f in result["files"]
        ),
        "pending_checks": sum(
            revision["checks"].get(c["id"], {}).get("status") != "passed"
            for c in checks
        ),
        "open_threads": sum(
            t["status"] == "open" and t["kind"] != "note" for t in state["threads"]
        ),
    }
    result["summary"]["complete"] = bool(result["files"]) and not any(
        result["summary"].values()
    )
    return result
