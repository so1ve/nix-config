"""Prepare deadline notifications for Hermes' native script-only cron delivery."""

import json
import re
import sqlite3
from contextlib import closing
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from . import config

SHANGHAI = ZoneInfo("Asia/Shanghai")


def message(events: list[dict], now: datetime) -> str:
    reminders = {}
    for event in events:
        if (
            event["event_type"] not in {"due", "close"}
            or not event["visible"]
            or event["completed"] is True
            or not event["due"]
        ):
            continue
        due = datetime.fromisoformat(event["due"])
        remaining = due - now
        if timedelta(0) < remaining <= timedelta(hours=24):
            hours = 2 if remaining <= timedelta(hours=2) else 24
            reminders[event["id"], int(due.timestamp()), hours] = event

    profile = config.home()
    jobs = json.loads((profile / "cron/jobs.json").read_text())["jobs"]
    (job_id,) = [job["id"] for job in jobs if job.get("script") == "personal/deadline-check.py"]
    history_path = (profile / "cron/executions.db").as_uri() + "?mode=ro"
    with closing(sqlite3.connect(history_path, uri=True)) as history:
        executions = history.execute(
            "SELECT id, status, delivery_outcome FROM executions WHERE job_id = ?", (job_id,)
        ).fetchall()
    (running,) = [row[0] for row in executions if row[1] == "running"]
    delivered = [row[0] for row in executions if row[1:] == ("completed", "delivered")]
    state = profile / ".local/state/hermes-personal/reminders.sqlite3"
    if not reminders and not state.exists():
        return ""
    state.parent.mkdir(parents=True, exist_ok=True)
    with closing(sqlite3.connect(state)) as db, db:
        db.execute("""CREATE TABLE IF NOT EXISTS sent (
                event_id TEXT NOT NULL, due INTEGER NOT NULL, hours INTEGER NOT NULL,
                execution TEXT,
                PRIMARY KEY (event_id, due, hours)
            )""")
        db.execute("DELETE FROM sent WHERE due <= ?", (int(now.timestamp()),))
        db.executemany(
            "UPDATE sent SET execution = NULL WHERE execution = ?", [(x,) for x in delivered]
        )
        pending = [
            key
            for key in sorted(reminders, key=lambda key: key[1])
            if db.execute(
                "SELECT 1 FROM sent WHERE event_id = ? AND due = ? AND hours = ? AND execution IS NULL",
                key,
            ).fetchone()
            is None
        ]
        lines = ["课程截止提醒"] if pending else []
        for key in pending:
            _, due, hours = key
            event = reminders[key]
            deadline = datetime.fromtimestamp(due, SHANGHAI).strftime("%m-%d %H:%M")
            course = _label(event["course"], 40)
            title = _label(event["title"], 96)
            activity = f"{course} / {title}" if course else title
            status = "（提交状态未确认）" if event["completed"] is None else ""
            source = {"eclass": "新乐学", "yanhekt": "延河课堂"}.get(event.get("source"), "老乐学")
            lines.append(f"• {source} · {hours} 小时内 · {deadline} · {activity}{status}")
        db.executemany(
            "INSERT OR REPLACE INTO sent VALUES (?, ?, ?, ?)", [(*key, running) for key in pending]
        )
    return "\n".join(lines)


def _label(value: str, length: int) -> str:
    # Hermes interprets MEDIA: as an attachment directive. Calendar titles are plain text.
    text = " ".join(value.split())
    return re.sub(r"media:", "MEDIA：", text, flags=re.IGNORECASE)[:length]
