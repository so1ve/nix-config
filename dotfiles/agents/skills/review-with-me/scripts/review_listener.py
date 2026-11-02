"""Persistent bridge state for waking the reviewing Codex thread."""

import fcntl
import json
import os
import re
import shutil
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path


SCHEMA_VERSION = 1
STATUSES = (
    "unconfigured",
    "listening",
    "degraded",
    "paused",
    "error",
)
THREAD_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{0,199}$")


def now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace(
        "+00:00", "Z"
    )


def listener_path(state_path):
    return state_path.with_suffix(".listener.json")


def lock_path(state_path):
    return state_path.with_suffix(".listener.lock")


def empty():
    thread_id = os.environ.get("CODEX_THREAD_ID", "").strip()
    return {
        "version": SCHEMA_VERSION,
        "status": "unconfigured",
        "thread_id": thread_id,
        "transport": "codex-queue",
        "automation_id": "",
        "automation_name": "",
        "last_event_id": "",
        "last_delivery_at": "",
        "last_claim_at": "",
        "stop_reason": "",
        "last_error": "",
        "created_at": "",
        "updated_at": "",
    }


def validate(listener):
    if not isinstance(listener, dict):
        raise TypeError("The listener state must be a JSON object")
    if listener.get("version") != SCHEMA_VERSION:
        raise ValueError(f"Unsupported listener version: {listener.get('version')}")
    if listener.get("status") not in STATUSES:
        raise ValueError(f"Unknown listener status: {listener.get('status')}")
    for key in (
        "thread_id",
        "transport",
        "automation_id",
        "automation_name",
        "last_event_id",
        "last_delivery_at",
        "last_claim_at",
        "stop_reason",
        "last_error",
        "created_at",
        "updated_at",
    ):
        if not isinstance(listener.get(key, ""), str):
            raise TypeError(f"Listener field {key} must be a string")
    return listener


def load(state_path):
    path = listener_path(state_path)
    if not path.exists():
        return empty()
    return validate(json.loads(path.read_text(encoding="utf-8")))


def save(state_path, listener):
    path = listener_path(state_path)
    validate(listener)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=path.parent, delete=False
        ) as stream:
            temporary = Path(stream.name)
            json.dump(listener, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
        temporary.replace(path)
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()


class locked:
    def __init__(self, state_path):
        self.state_path = state_path
        self.path = lock_path(state_path)
        self.stream = None
        self.listener = None

    def __enter__(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.stream = self.path.open("a+", encoding="utf-8")
        fcntl.flock(self.stream, fcntl.LOCK_EX)
        self.listener = load(self.state_path)
        return self.listener

    def __exit__(self, exc_type, exc_value, traceback):
        if exc_type is None:
            stamp = now()
            self.listener["updated_at"] = stamp
            if not self.listener["created_at"]:
                self.listener["created_at"] = stamp
            save(self.state_path, self.listener)
        fcntl.flock(self.stream, fcntl.LOCK_UN)
        self.stream.close()


def configure(state_path, *, thread_id, automation_id="", automation_name=""):
    thread_id = thread_id.strip()
    if not THREAD_ID.fullmatch(thread_id):
        raise ValueError("A valid Codex thread id is required")
    with locked(state_path) as listener:
        listener["status"] = "listening"
        listener["thread_id"] = thread_id
        if automation_id:
            listener["automation_id"] = automation_id.strip()
        if automation_name:
            listener["automation_name"] = automation_name.strip()
        listener["stop_reason"] = ""
        listener["last_error"] = ""
    return load(state_path)


def stop(state_path, reason="Paused from the review UI"):
    with locked(state_path) as listener:
        listener["status"] = "paused"
        listener["stop_reason"] = reason
        listener["last_error"] = ""
    return load(state_path)


def fail(state_path, message):
    with locked(state_path) as listener:
        if listener["status"] != "paused":
            listener["status"] = (
                "degraded" if listener["automation_id"] else "error"
            )
            listener["last_error"] = message
    return load(state_path)


def delivered(state_path, event_id):
    with locked(state_path) as listener:
        if listener["status"] != "paused":
            listener["status"] = "listening"
            listener["last_event_id"] = event_id
            listener["last_delivery_at"] = now()
            listener["last_error"] = ""
    return load(state_path)


def claimed(state_path):
    with locked(state_path) as listener:
        listener["last_claim_at"] = now()
    return load(state_path)


def wake_message(*, review_path, state_tool):
    return (
        "[Review With Me] 新的审阅反馈已保存。\n"
        f"状态文件：{review_path}\n"
        "请先运行："
        f'python3 "{state_tool}" inbox --state "{review_path}" --claim --json\n'
        "只处理本次认领的事件。先阅读对应修订和当前源码，完成修改、追加修订并回复。"
        "如果监听状态是 paused，不要开始新工作，保留事件给恢复后的下一轮。"
    )


def queue_thread(thread_id, message, cwd):
    cli = os.environ.get("CODEX_CLI_PATH", "").strip()
    if not cli:
        cli = shutil.which("codex") or ""
    if not cli:
        raise RuntimeError("找不到 Codex CLI，无法唤醒当前会话")
    result = subprocess.run(
        [cli, "queue", "--thread", thread_id, "--message", message],
        cwd=cwd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=20,
        env={**os.environ, "GIT_OPTIONAL_LOCKS": "0"},
    )
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip()
        raise RuntimeError(detail or "Codex 没有接受唤醒消息")

