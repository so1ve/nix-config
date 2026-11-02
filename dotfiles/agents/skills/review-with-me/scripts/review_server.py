"""Local frontend and API for a review-with-me record."""

import difflib
import gzip
import hashlib
import hmac
import json
import os
import secrets
import subprocess
import sys
import tempfile
import threading
import time
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse

import review_state
import review_listener


WEB_ROOT = Path(__file__).with_name("web")
MAX_BODY = 1_000_000
MAX_FILE_BYTES = 4_000_000
WORKTREE = "WORKTREE"
WAKE_LOCK = threading.Lock()


class ReviewError(Exception):
    pass


def run_git(repo, *args, env=None):
    result = subprocess.run(
        ("git", "--no-pager", *args),
        cwd=repo,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        env={
            **os.environ,
            "GIT_OPTIONAL_LOCKS": "0",
            "LC_ALL": "C.UTF-8",
            **(env or {}),
        },
    )
    if result.returncode:
        message = result.stderr.decode("utf-8", "replace").strip()
        raise ReviewError(message or f"git {' '.join(args)} failed")
    return result.stdout


def resolve_commit(repo, ref):
    if ref == WORKTREE:
        return ref
    try:
        value = run_git(repo, "rev-parse", "--verify", f"{ref}^{{commit}}")
    except ReviewError as error:
        raise ReviewError(f"Cannot resolve Git revision {ref!r}: {error}") from error
    return value.decode("ascii").strip()


def name_status(repo, base, head, paths):
    base = resolve_commit(repo, base)
    head = resolve_commit(repo, head)
    if head == WORKTREE:
        head = worktree_tree(repo, base)
    args = [
        "--literal-pathspecs",
        "diff",
        "--name-status",
        "-z",
        "--find-renames",
        base,
        head,
    ]
    args.append("--")
    args.extend(paths)
    raw = run_git(repo, *args)
    parts = raw.split(b"\0")
    entries = []
    index = 0
    while index < len(parts):
        status = parts[index].decode("utf-8", "replace")
        index += 1
        if not status:
            continue
        code = status[0]
        if code in ("R", "C"):
            old_path = parts[index].decode("utf-8", "replace")
            path = parts[index + 1].decode("utf-8", "replace")
            index += 2
        else:
            old_path = ""
            path = parts[index].decode("utf-8", "replace")
            index += 1
        entries.append(
            {
                "path": path,
                "old_path": old_path,
                "status": "renamed" if code == "R" else {
                    "A": "added",
                    "D": "deleted",
                    "M": "modified",
                    "C": "copied",
                    "T": "type_changed",
                }.get(code, "modified"),
            }
        )
    return entries


def worktree_tree(repo, base):
    with tempfile.TemporaryDirectory(prefix="review-with-me-index-") as temporary:
        env = {"GIT_INDEX_FILE": str(Path(temporary) / "index")}
        run_git(repo, "read-tree", base, env=env)
        run_git(repo, "add", "--all", "--", ".", env=env)
        return run_git(repo, "write-tree", env=env).decode("ascii").strip()


def blob_at(repo, ref, path):
    if ref == WORKTREE:
        target = repo / path
        try:
            if target.is_symlink():
                return f"symlink -> {os.readlink(target)}\n".encode()
            if not target.is_file():
                return None
            if target.stat().st_size > MAX_FILE_BYTES:
                return b"\0"
            return target.read_bytes()
        except OSError:
            return None
    result = subprocess.run(
        ("git", "--no-pager", "cat-file", "blob", f"{ref}:{path}"),
        cwd=repo,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
        env={**os.environ, "GIT_OPTIONAL_LOCKS": "0"},
    )
    if result.returncode:
        return None
    if len(result.stdout) > MAX_FILE_BYTES:
        return b"\0"
    return result.stdout


def decode_blob(value):
    if value is None:
        return [], False, ""
    if b"\0" in value[:8192]:
        return [], True, ""
    try:
        text = value.decode("utf-8")
    except UnicodeDecodeError:
        return [], True, ""
    return text.splitlines(), False, text


def diff_file(repo, base, head, entry, paths):
    old_path = entry["old_path"] or entry["path"]
    old_bytes = blob_at(repo, base, old_path)
    new_bytes = (
        None if entry["status"] == "deleted" else blob_at(repo, head, entry["path"])
    )
    old_lines, old_binary, old_text = decode_blob(old_bytes)
    new_lines, new_binary, new_text = decode_blob(new_bytes)
    binary = old_binary or new_binary
    hunks = []
    additions = 0
    deletions = 0
    if not binary and old_lines != new_lines:
        matcher = difflib.SequenceMatcher(None, old_lines, new_lines, autojunk=False)
        for tag, old_start, old_end, new_start, new_end in matcher.get_opcodes():
            if tag == "equal":
                continue
            deletions += old_end - old_start
            additions += new_end - new_start
            hunks.append(
                {
                    "old_start": old_start + 1,
                    "old_count": old_end - old_start,
                    "new_start": new_start + 1,
                    "new_count": new_end - new_start,
                }
            )
    return {
        "path": entry["path"],
        "old_path": entry["old_path"],
        "status": entry["status"],
        "binary": binary,
        "additions": additions,
        "deletions": deletions,
        "old_total": len(old_lines),
        "new_total": len(new_lines),
        "old_text": old_text,
        "new_text": new_text,
        "hunks": hunks,
        "paths": paths,
    }


def build_diff(repo, base, head, paths):
    entries = name_status(repo, base, head, paths)
    resolved_base = resolve_commit(repo, base)
    resolved_head = resolve_commit(repo, head)
    files = [
        diff_file(repo, resolved_base, resolved_head, entry, paths)
        for entry in entries
    ]
    return {
        "base": resolved_base,
        "head": resolved_head,
        "files": files,
        "additions": sum(item["additions"] for item in files),
        "deletions": sum(item["deletions"] for item in files),
    }


def revision_for(change, revision_id=None):
    if revision_id is None:
        return change["revisions"][-1]
    revision = next(
        (item for item in change["revisions"] if item["id"] == revision_id),
        None,
    )
    if revision is None:
        raise ReviewError(f"Unknown revision: {revision_id}")
    return revision


def hunk_coordinates(hunk):
    return {
        "old_start": hunk["old_start"],
        "old_count": hunk["old_count"],
        "new_start": hunk["new_start"],
        "new_count": hunk["new_count"],
    }


def decision_index(change):
    def coordinates(hunk):
        if not hunk:
            return None
        return (
            hunk["old_start"],
            hunk["old_count"],
            hunk["new_start"],
            hunk["new_count"],
        )

    return {
        (
            decision["revision_id"],
            decision["path"],
            decision["scope"],
            coordinates(decision.get("hunk")),
        ): decision
        for decision in change.get("decisions", [])
    }


def decision_for(index, revision_id, path, scope, hunk=None):
    coordinates = (
        (
            hunk["old_start"],
            hunk["old_count"],
            hunk["new_start"],
            hunk["new_count"],
        )
        if hunk
        else None
    )
    return index.get((revision_id, path, scope, coordinates))


def review_summary_for_change(repo, change, *, revision_id=None, payload=None):
    revision = revision_for(change, revision_id)
    payload = payload or build_diff(
        repo,
        revision["base"],
        revision["head"],
        revision["paths"],
    )
    index = decision_index(change)
    files = []
    pending = 0
    pending_files = 0
    user_accepted = False
    terminal_items = 0
    excluded_items = 0
    for file in payload["files"]:
        path = file["path"]
        file_decision = decision_for(
            index, revision["id"], path, "file"
        )
        if file_decision and file_decision["status"] in (
            "accepted",
            "excluded",
        ):
            status = file_decision["status"]
            file_pending = 0
            terminal_items += 1
            excluded_items += status == "excluded"
            user_accepted = user_accepted or (
                status == "accepted" and file_decision["author"] == "user"
            )
        elif not file["hunks"]:
            status = "pending"
            file_pending = 1
            pending += file_pending
            pending_files += 1
        else:
            hunk_pending = 0
            hunk_accepted = 0
            hunk_excluded = 0
            for hunk in file["hunks"]:
                decision = decision_for(
                    index,
                    revision["id"],
                    path,
                    "hunk",
                    hunk,
                )
                if not decision or decision["status"] == "pending":
                    hunk_pending += 1
                    continue
                terminal_items += 1
                if decision["status"] == "excluded":
                    hunk_excluded += 1
                    excluded_items += 1
                else:
                    hunk_accepted += 1
                    user_accepted = user_accepted or decision["author"] == "user"
            file_pending = hunk_pending
            pending += hunk_pending
            if hunk_pending:
                pending_files += 1
            if not hunk_pending and hunk_excluded and not hunk_accepted:
                status = "excluded"
            elif not hunk_pending:
                status = "accepted"
            else:
                status = "pending"
        files.append(
            {
                "path": path,
                "old_path": file["old_path"],
                "status": status,
                "pending": file_pending,
            }
        )
    return {
        "revision_id": revision["id"],
        "pending": pending,
        "pending_files": pending_files,
        "terminal_items": terminal_items,
        "excluded_items": excluded_items,
        "user_accepted": user_accepted,
        "complete": pending == 0,
        "files": files,
    }


def review_items_for_change(repo, change, *, revision_id=None, pending_only=False):
    revision = revision_for(change, revision_id)
    payload = build_diff(
        repo,
        revision["base"],
        revision["head"],
        revision["paths"],
    )
    index = decision_index(change)
    items = []
    for file in payload["files"]:
        file_decision = decision_for(
            index, revision["id"], file["path"], "file"
        )
        if file_decision and file_decision["status"] != "pending":
            items.append(
                {
                    "path": file["path"],
                    "scope": "file",
                    "hunk": None,
                    "status": file_decision["status"],
                    "decision": file_decision,
                }
            )
            continue
        if not file["hunks"]:
            items.append(
                {
                    "path": file["path"],
                    "scope": "file",
                    "hunk": None,
                    "status": "pending",
                    "decision": file_decision,
                }
            )
            continue
        for hunk in file["hunks"]:
            decision = decision_for(
                index,
                revision["id"],
                file["path"],
                "hunk",
                hunk,
            )
            items.append(
                {
                    "path": file["path"],
                    "scope": "hunk",
                    "hunk": hunk_coordinates(hunk),
                    "status": decision["status"] if decision else "pending",
                    "decision": decision,
                }
            )
    if pending_only:
        items = [item for item in items if item["status"] == "pending"]
    return {
        "change": change["id"],
        "title": change["title"],
        "change_status": change["status"],
        "revision": revision["id"],
        "summary": review_summary_for_change(
            repo,
            change,
            revision_id=revision["id"],
            payload=payload,
        ),
        "items": items,
    }


def record_review_decision(
    repo,
    state,
    change,
    *,
    revision_id,
    path,
    scope,
    hunk,
    status,
    author,
    reason="",
):
    revision = revision_for(change, revision_id)
    payload = build_diff(
        repo,
        revision["base"],
        revision["head"],
        revision["paths"],
    )
    file = next(
        (
            item
            for item in payload["files"]
            if item["path"] == path or item["old_path"] == path
        ),
        None,
    )
    if file is None:
        raise ReviewError(f"The revision does not contain a changed file: {path}")
    if scope == "hunk":
        if hunk is None:
            raise ReviewError("A hunk decision needs coordinates")
        hunk = review_state.validate_hunk(hunk)
        if not any(item == hunk_coordinates(hunk) for item in file["hunks"]):
            raise ReviewError(
                f"The selected hunk is not present in {file['path']} "
                f"for revision {revision['id']}"
            )
    decision = review_state.set_review_decision(
        change,
        revision_id=revision["id"],
        path=file["path"],
        scope=scope,
        hunk=hunk,
        status=status,
        author=author,
        reason=reason,
    )
    summary = review_summary_for_change(
        repo,
        change,
        revision_id=revision["id"],
        payload=payload,
    )
    is_latest = revision["id"] == change["revisions"][-1]["id"]
    if change["status"] != "superseded" and is_latest:
        if status == "pending" and change["status"] == "accepted":
            change["status"] = "revisit"
        elif (
            not review_state.open_feedback(change)
            and summary["complete"]
            and summary["user_accepted"]
        ):
            change["status"] = "accepted"
        elif status != "pending" and change["status"] == "unreviewed":
            change["status"] = "reviewing"
    review_state.touch(change)
    return decision, summary


def is_review_artifact(path, state_relative):
    return (
        path == ".review"
        or path.startswith(".review/")
        or path == state_relative
        or path.startswith(state_relative + ".lock")
    )


def worktree_fingerprint(repo, coverage):
    digest = hashlib.sha256()
    for entry in sorted(coverage, key=lambda item: item["path"]):
        digest.update(entry["path"].encode())
        digest.update(b"\0")
        digest.update(entry["old_path"].encode())
        digest.update(b"\0")
        digest.update(entry["status"].encode())
        target = repo / entry["path"]
        try:
            stat = target.lstat()
        except OSError:
            continue
        digest.update(
            f"\0{stat.st_mode}:{stat.st_size}:{stat.st_mtime_ns}".encode()
        )
        if target.is_symlink():
            digest.update(b"\0")
            digest.update(os.readlink(target).encode())
    return digest.hexdigest()


def runtime_for(repo, state_path, state):
    state_relative = str(state_path)
    warnings = []
    try:
        branch = run_git(repo, "branch", "--show-current").decode().strip()
        head = run_git(repo, "rev-parse", "--short", "HEAD").decode().strip()
    except ReviewError:
        branch = ""
        head = ""
    try:
        coverage = name_status(repo, state["base"], WORKTREE, [])
        coverage = [
            entry
            for entry in coverage
            if not is_review_artifact(entry["path"], state_relative)
            and not is_review_artifact(entry["old_path"], state_relative)
        ]
    except ReviewError as error:
        coverage = []
        warnings.append(str(error))
    claimed = set()
    for change in state["changes"]:
        claimed.update(change["paths"])
    unmapped = [
        entry
        for entry in coverage
        if entry["path"] not in claimed and entry["old_path"] not in claimed
    ]
    newer = {}
    for change in state["changes"]:
        revision = change["revisions"][-1]
        if revision["head"] == WORKTREE:
            continue
        try:
            changes = name_status(
                repo, revision["head"], WORKTREE, revision["paths"]
            )
        except ReviewError as error:
            warnings.append(f"{change['id']}: {error}")
            continue
        changes = [
            entry
            for entry in changes
            if not is_review_artifact(entry["path"], state_relative)
        ]
        if changes:
            newer[change["id"]] = len(changes)
    return {
        "branch": branch,
        "head": head,
        "state_path": state_relative,
        "worktree_fingerprint": worktree_fingerprint(repo, coverage),
        "unmapped": unmapped,
        "newer_worktree": newer,
        "warnings": warnings,
    }


def index_html(token):
    source = (WEB_ROOT / "index.html").read_text(encoding="utf-8")
    return source.replace("__REVIEW_TOKEN__", token)


def file_signature(path):
    try:
        stat = path.stat()
    except FileNotFoundError:
        return "missing"
    return f"{stat.st_dev}:{stat.st_ino}:{stat.st_size}:{stat.st_mtime_ns}"


def review_event_signature(review_path):
    return "|".join(
        (
            file_signature(review_path),
            file_signature(review_listener.listener_path(review_path)),
        )
    )


def deliver_feedback(repo, review_path, note):
    events = review_state.pending_events_for_note(note)
    if not events:
        return {"state": "none", "event_ids": []}
    # Keep the "is a wake already pending?" check and the queue call in one
    # serialized section. Otherwise two concurrent annotations can both decide
    # to wake the same Agent thread.
    with WAKE_LOCK:
        listener = review_listener.load(review_path)
        if listener["status"] not in ("listening", "degraded"):
            return {
                "state": "paused" if listener["status"] == "paused" else "queued",
                "event_ids": [event["id"] for event in events],
            }
        event_ids = [event["id"] for event in events]
        with review_state.locked_state(review_path) as state:
            if review_state.has_waiting_delivery(state):
                review_state.set_delivery_states(state, event_ids, "delivered")
                already_waiting = True
            else:
                already_waiting = False
        if already_waiting:
            review_listener.delivered(review_path, event_ids[-1])
            return {"state": "delivered", "event_ids": event_ids}
        message = review_listener.wake_message(
            review_path=review_path.relative_to(repo),
            state_tool=Path(review_state.__file__).resolve(),
        )
        try:
            review_listener.queue_thread(listener["thread_id"], message, repo)
        except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
            with review_state.locked_state(review_path) as state:
                review_state.set_delivery_states(
                    state, event_ids, "failed", str(error)
                )
            review_listener.fail(review_path, str(error))
            return {
                "state": "failed",
                "event_ids": event_ids,
                "error": str(error),
            }
        with review_state.locked_state(review_path) as state:
            review_state.set_delivery_states(state, event_ids, "delivered")
        review_listener.delivered(review_path, event_ids[-1])
        return {"state": "delivered", "event_ids": event_ids}


class Handler(BaseHTTPRequestHandler):
    server_version = "ReviewWithMe/2"
    protocol_version = "HTTP/1.1"

    def log_message(self, format, *args):
        sys.stderr.write("review-server: " + format % args + "\n")

    @property
    def repo(self):
        return self.server.repo

    @property
    def review_path(self):
        return self.server.review_path

    def send_bytes(
        self,
        value,
        content_type,
        status=HTTPStatus.OK,
        content_encoding=None,
    ):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(value)))
        if content_encoding:
            self.send_header("Content-Encoding", content_encoding)
            self.send_header("Vary", "Accept-Encoding")
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        if self.close_connection:
            self.send_header("Connection", "close")
        self.send_header(
            "Content-Security-Policy",
            "default-src 'self'; img-src 'self' data:; "
            "style-src 'self' 'unsafe-inline'; "
            "script-src 'self' 'wasm-unsafe-eval'; "
            "connect-src 'self'; font-src 'self'",
        )
        self.end_headers()
        self.wfile.write(value)

    def send_json(self, value, status=HTTPStatus.OK):
        payload = json.dumps(value, ensure_ascii=False).encode()
        self.send_bytes(payload, "application/json; charset=utf-8", status)

    def send_error_json(self, message, status=HTTPStatus.BAD_REQUEST):
        self.send_json({"error": str(message)}, status)

    def send_event_stream(self):
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/event-stream; charset=utf-8")
        self.send_header("Cache-Control", "no-cache, no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.end_headers()
        last_signature = review_event_signature(self.review_path)
        last_heartbeat = time.monotonic()
        try:
            self.wfile.write(
                b"retry: 1000\nevent: ready\ndata: connected\n\n"
            )
            self.wfile.flush()
            deadline = time.monotonic() + 30
            while time.monotonic() < deadline:
                time.sleep(1)
                current_signature = review_event_signature(self.review_path)
                if current_signature != last_signature:
                    last_signature = current_signature
                    self.wfile.write(
                        b"event: state\ndata: changed\n\n"
                    )
                    self.wfile.flush()
                    last_heartbeat = time.monotonic()
                elif time.monotonic() - last_heartbeat >= 10:
                    self.wfile.write(b": keepalive\n\n")
                    self.wfile.flush()
                    last_heartbeat = time.monotonic()
        except (BrokenPipeError, ConnectionResetError, OSError):
            pass
        finally:
            self.close_connection = True

    def origin_ok(self):
        origin = self.headers.get("Origin")
        if not origin:
            return True
        host = self.headers.get("Host", "")
        return urlparse(origin).netloc == host

    def token_ok(self):
        supplied = self.headers.get("X-Review-Token", "")
        return hmac.compare_digest(supplied, self.server.token)

    def do_GET(self):
        parsed = urlparse(self.path)
        try:
            if parsed.path == "/":
                self.send_bytes(
                    index_html(self.server.token).encode(),
                    "text/html; charset=utf-8",
                )
                return
            if parsed.path.startswith("/assets/"):
                relative = unquote(parsed.path.removeprefix("/assets/"))
                target = (WEB_ROOT / "assets" / relative).resolve()
                if not target.is_relative_to((WEB_ROOT / "assets").resolve()):
                    raise ReviewError("Invalid asset path")
                content_type = {
                    ".js": "text/javascript; charset=utf-8",
                    ".css": "text/css; charset=utf-8",
                    ".json": "application/json; charset=utf-8",
                    ".woff2": "font/woff2",
                }.get(target.suffix, "application/octet-stream")
                compressed_target = Path(f"{target}.gz")
                if compressed_target.is_file():
                    value = compressed_target.read_bytes()
                    if "gzip" in self.headers.get("Accept-Encoding", ""):
                        self.send_bytes(
                            value,
                            content_type,
                            content_encoding="gzip",
                        )
                    else:
                        self.send_bytes(gzip.decompress(value), content_type)
                    return
                self.send_bytes(target.read_bytes(), content_type)
                return
            if parsed.path == "/api/events":
                self.send_event_stream()
                return
            if parsed.path == "/api/state":
                state = review_state.load(self.review_path)
                for change in state["changes"]:
                    try:
                        change["review"] = review_summary_for_change(
                            self.repo, change
                        )
                    except (OSError, ReviewError, TypeError, ValueError) as error:
                        change["review"] = {
                            "revision_id": change["revisions"][-1]["id"],
                            "pending": 0,
                            "pending_files": 0,
                            "terminal_items": 0,
                            "excluded_items": 0,
                            "user_accepted": False,
                            "complete": False,
                            "error": str(error),
                            "files": [],
                        }
                self.send_json(
                    {
                        "state": state,
                        "runtime": runtime_for(self.repo, self.review_path, state),
                        "listener": review_listener.load(self.review_path),
                    }
                )
                return
            if parsed.path == "/api/diff":
                query = parse_qs(parsed.query)
                change_id = query.get("change", [""])[0]
                state = review_state.load(self.review_path)
                change = review_state.find_change(state, change_id)
                revision_id = query.get("revision", [change["revisions"][-1]["id"]])[0]
                revision = next(
                    (
                        item
                        for item in change["revisions"]
                        if item["id"] == revision_id
                    ),
                    None,
                )
                if revision is None:
                    raise ReviewError(f"Unknown revision: {revision_id}")
                mode = query.get("mode", ["round"])[0]
                if mode == "cumulative":
                    base = change["revisions"][0]["base"]
                    head = revision["head"]
                else:
                    base = revision["base"]
                    head = revision["head"]
                paths = revision["paths"]
                payload = build_diff(self.repo, base, head, paths)
                payload.update(
                    {
                        "change": change["id"],
                        "revision": revision["id"],
                        "mode": mode,
                        "label": revision["label"],
                    }
                )
                self.send_json(payload)
                return
            self.send_error_json("Not found", HTTPStatus.NOT_FOUND)
        except (OSError, TypeError, ValueError, ReviewError) as error:
            self.send_error_json(error)

    def read_json(self):
        length = int(self.headers.get("Content-Length", "0"))
        if length < 1 or length > MAX_BODY:
            raise ReviewError("Request body is empty or too large")
        try:
            value = json.loads(self.rfile.read(length))
        except json.JSONDecodeError as error:
            raise ReviewError(f"Invalid JSON: {error}") from error
        if not isinstance(value, dict):
            raise ReviewError("Request body must be a JSON object")
        return value

    def do_POST(self):
        if not self.origin_ok():
            self.close_connection = True
            self.send_error_json("Cross-origin request rejected", HTTPStatus.FORBIDDEN)
            return
        if not self.token_ok():
            self.close_connection = True
            self.send_error_json("Invalid review token", HTTPStatus.FORBIDDEN)
            return
        parsed = urlparse(self.path)
        try:
            body = self.read_json()
            if parsed.path == "/api/annotations":
                self.add_annotation(body)
                return
            if parsed.path.startswith("/api/annotations/"):
                annotation_id = parsed.path.removeprefix("/api/annotations/")
                self.update_annotation(annotation_id, body)
                return
            if parsed.path == "/api/status":
                self.update_status(body)
                return
            if parsed.path == "/api/review-item":
                self.update_review_item(body)
                return
            if parsed.path == "/api/adopt":
                self.adopt_path(body)
                return
            if parsed.path == "/api/listener/stop":
                self.send_json(
                    {
                        "listener": review_listener.stop(
                            self.review_path,
                            body.get("reason") or "Stopped from the review UI",
                        )
                    }
                )
                return
            self.send_error_json("Not found", HTTPStatus.NOT_FOUND)
        except (OSError, TypeError, ValueError, ReviewError) as error:
            self.close_connection = True
            self.send_error_json(error)

    def add_annotation(self, body):
        body_text = review_state.require_text(body.get("body"), "Annotation body")
        if len(body_text) > 20_000:
            raise ReviewError("Annotation body is too long")
        suggestion = body.get("suggestion", "")
        if not isinstance(suggestion, str) or len(suggestion) > 50_000:
            raise ReviewError("Suggestion is invalid or too long")
        kind = body.get("kind", "change")
        if kind not in review_state.ACTIONABLE_KINDS + ("note",):
            raise ReviewError(f"Unsupported annotation kind: {kind}")
        side = body.get("side", "file")
        path = body.get("path")
        start = body.get("start")
        end = body.get("end")
        excerpt = body.get("excerpt", "")
        if not isinstance(excerpt, str) or len(excerpt) > 50_000:
            raise ReviewError("Excerpt is invalid or too long")
        with review_state.locked_state(self.review_path) as state:
            change = review_state.find_change(state, body.get("change", ""))
            note = review_state.add_annotation(
                change,
                author="user",
                kind=kind,
                body=body_text,
                revision_id=body.get("revision"),
                path=path,
                side=side,
                start=start,
                end=end,
                excerpt=excerpt,
                suggestion=suggestion,
            )
        delivery = deliver_feedback(self.repo, self.review_path, note)
        self.send_json(
            {
                "annotation": note,
                "delivery": delivery,
                "listener": review_listener.load(self.review_path),
            }
        )

    def update_annotation(self, annotation_id, body):
        action = body.get("action", "status")
        with review_state.locked_state(self.review_path) as state:
            change = review_state.find_change(state, body.get("change", ""))
            note = review_state.find_annotation(change, annotation_id)
            if action == "reply":
                text = review_state.require_text(body.get("body"), "Reply body")
                if len(text) > 20_000:
                    raise ReviewError("Reply is too long")
                review_state.reply_to_annotation(
                    change,
                    note,
                    author="user",
                    body=text,
                    resolve=bool(body.get("resolve")),
                )
            elif action == "status":
                status = body.get("status")
                if status not in review_state.ANNOTATION_STATUSES:
                    raise ReviewError(f"Unknown annotation status: {status}")
                note["status"] = status
                note["updated_at"] = review_state.now()
                if status != "open":
                    review_state.answer_deliveries(note)
                if (
                    status != "open"
                    and change["status"] not in ("accepted", "superseded")
                    and not review_state.open_feedback(change)
                ):
                    change["status"] = "reviewing"
                review_state.touch(change)
            else:
                raise ReviewError(f"Unknown annotation action: {action}")
        delivery = (
            deliver_feedback(self.repo, self.review_path, note)
            if action == "reply"
            else {"state": "none", "event_ids": []}
        )
        self.send_json(
            {
                "ok": True,
                "delivery": delivery,
                "listener": review_listener.load(self.review_path),
            }
        )

    def update_status(self, body):
        with review_state.locked_state(self.review_path) as state:
            change = review_state.find_change(state, body.get("change", ""))
            review_state.set_status(change, body.get("status", ""))
        self.send_json({"ok": True})

    def update_review_item(self, body):
        scope = body.get("scope", "file")
        if scope not in review_state.REVIEW_SCOPES:
            raise ReviewError(f"Unknown review scope: {scope}")
        status = body.get("status", "accepted")
        if status not in review_state.REVIEW_STATUSES:
            raise ReviewError(f"Unknown review item status: {status}")
        reason = body.get("reason", "")
        if not isinstance(reason, str) or len(reason) > 20_000:
            raise ReviewError("Review item reason is invalid or too long")
        path = review_state.require_text(body.get("path"), "Path")
        hunk = body.get("hunk")
        with review_state.locked_state(self.review_path) as state:
            change = review_state.find_change(state, body.get("change", ""))
            decision, summary = record_review_decision(
                self.repo,
                state,
                change,
                revision_id=body.get("revision"),
                path=path,
                scope=scope,
                hunk=hunk,
                status=status,
                author="user",
                reason=reason,
            )
        self.send_json(
            {
                "decision": decision,
                "review": summary,
                "change_status": change["status"],
            }
        )

    def adopt_path(self, body):
        path = review_state.require_text(body.get("path"), "Path")
        old_path = body.get("old_path") or ""
        normalized = str(review_state.relative_path(path))
        normalized_old = (
            str(review_state.relative_path(old_path)) if old_path else ""
        )
        with review_state.locked_state(self.review_path) as state:
            paths = review_state.normalize_paths(
                [normalized_old, normalized] if normalized_old else [normalized]
            )
            coverage = name_status(
                self.repo, state["base"], WORKTREE, paths
            )
            entry = next(
                (item for item in coverage if item["path"] == normalized),
                None,
            )
            if entry is None:
                raise ReviewError("The selected path is not a current worktree change")
            claimed = {
                item
                for change in state["changes"]
                for item in change["paths"]
            }
            if entry["path"] in claimed or entry["old_path"] in claimed:
                raise ReviewError("The selected path is already in a review unit")
            base_id = review_state.slug(normalized)
            change_id = base_id
            suffix = 2
            existing = {change["id"] for change in state["changes"]}
            while change_id in existing:
                change_id = f"{base_id}-{suffix}"
                suffix += 1
            change = review_state.add_change(
                state,
                change_id=change_id,
                title=f"未归类改动：{normalized}",
                paths=paths,
                summary="由审阅者从未归类改动中加入。",
                rationale="等待 Agent 补充改动原因。",
                head=review_state.require_worktree_snapshot(),
            )
            change["status"] = "reviewing"
        self.send_json({"change": change_id})


class ReviewHTTPServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(self, address, repo, review_path, token):
        super().__init__(address, Handler)
        self.repo = repo
        self.review_path = review_path
        self.token = token


def serve(state_path, host="127.0.0.1", port=0):
    repo = Path.cwd().resolve()
    review_path = state_path.resolve()
    if not review_path.is_relative_to(repo):
        raise ValueError("The review record must stay inside the workspace")
    review_state.prepare_state(review_path)
    listener = review_listener.load(review_path)
    if listener["status"] == "unconfigured" and listener["thread_id"]:
        listener = review_listener.configure(
            review_path, thread_id=listener["thread_id"]
        )
    token = secrets.token_urlsafe(24)
    server = ReviewHTTPServer((host, port), repo, review_path, token)
    actual_port = server.server_address[1]
    print(f"Review frontend: http://{host}:{actual_port}")
    print(f"State: {review_path.relative_to(repo)}")
    print(f"Listener: {listener['status']}")
    print("Press Ctrl+C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped review frontend.")
    finally:
        server.server_close()


if __name__ == "__main__":
    raise SystemExit("Run this frontend through review_state.py serve")
