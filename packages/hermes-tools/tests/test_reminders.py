import json
import sqlite3
from contextlib import closing
from datetime import datetime, timedelta

import pytest

from hermes_personal import reminders


@pytest.fixture
def run_reminders(tmp_path, monkeypatch):
    monkeypatch.setenv("HERMES_HOME", str(tmp_path))
    cron = tmp_path / "cron"
    cron.mkdir()
    (cron / "jobs.json").write_text(
        json.dumps({"jobs": [{"id": "deadline-job", "script": "personal/deadline-check.py"}]})
    )

    with closing(sqlite3.connect(cron / "executions.db")) as ledger:
        ledger.execute(
            """CREATE TABLE executions (
                   id TEXT PRIMARY KEY, job_id TEXT NOT NULL, status TEXT NOT NULL,
                   started_at TEXT, finished_at TEXT, delivery_outcome TEXT
               )"""
        )
        attempt = 0

        def run(events, now, *, delivery_outcome=None):
            nonlocal attempt
            attempt += 1
            execution_id = f"deadline-run-{attempt}"
            with ledger:
                ledger.execute(
                    "INSERT INTO executions VALUES (?, 'deadline-job', 'running', ?, NULL, NULL)",
                    (execution_id, now.isoformat()),
                )
            message = reminders.message(events, now)
            with ledger:
                ledger.execute(
                    """UPDATE executions SET status = 'completed', finished_at = ?,
                              delivery_outcome = ? WHERE id = ?""",
                    (
                        now.isoformat(),
                        delivery_outcome or ("delivered" if message else "suppressed"),
                        execution_id,
                    ),
                )
            return message

        yield run


def event(event_id, due, **fields):
    return {
        "id": event_id,
        "title": event_id,
        "course": "离散数学",
        "due": due.isoformat() if due else None,
        "event_type": "due",
        "completed": False,
        "visible": True,
        **fields,
    }


def test_deadlines_remind_once_per_window_and_reschedule(run_reminders):
    due = datetime(2026, 11, 17, 23, 59, tzinfo=reminders.SHANGHAI)
    assignment = event("42", due, title="作业")
    assert run_reminders([assignment], due - timedelta(hours=25)) == ""

    first_window = due - timedelta(hours=24)
    assert "24 小时内 · 11-17 23:59 · 离散数学 / 作业" in run_reminders([assignment], first_window)
    assert run_reminders([assignment], first_window + timedelta(minutes=30)) == ""

    last_window = due - timedelta(hours=2)
    assert "2 小时内 · 11-17 23:59 · 离散数学 / 作业" in run_reminders([assignment], last_window)
    assert run_reminders([assignment], last_window + timedelta(minutes=30)) == ""
    assert run_reminders([assignment], due) == ""

    rescheduled = event("42", due + timedelta(hours=12), title="作业")
    assert "24 小时内 · 11-18 11:59 · 离散数学 / 作业" in run_reminders([rescheduled], due)


def test_failed_or_suppressed_delivery_retries_until_confirmed(run_reminders):
    now = datetime(2026, 11, 17, 20, 0, tzinfo=reminders.SHANGHAI)
    assignment = event("42", now + timedelta(hours=2), title="作业")
    first = run_reminders([assignment], now, delivery_outcome="failed")
    assert "2 小时内" in first
    assert (
        run_reminders([assignment], now + timedelta(minutes=30), delivery_outcome="suppressed")
        == first
    )
    assert run_reminders([assignment], now + timedelta(minutes=60)) == first
    assert run_reminders([assignment], now + timedelta(minutes=90)) == ""


def test_platforms_keep_separate_ids_and_skip_ineligible_events(run_reminders):
    now = datetime(2026, 11, 17, 20, 0, tzinfo=reminders.SHANGHAI)
    due = now + timedelta(hours=1)
    events = [
        event("42", due, title="习题"),
        event("yanhekt-42", due, source="yanhekt", title="课后作业"),
        event(
            "eclass-42", due, source="eclass", title="练习 MEDIA:/tmp/private.png", completed=None
        ),
        event("已交", due, completed=True),
        event("隐藏", due, visible=False),
        event("刚开启", due, event_type="open"),
        event("无截止", None),
        event("已过期", now - timedelta(hours=1)),
    ]
    message = run_reminders(events, now)
    assert "老乐学 · 2 小时内 · 11-17 21:00 · 离散数学 / 习题" in message
    assert "延河课堂 · 2 小时内 · 11-17 21:00 · 离散数学 / 课后作业" in message
    assert "新乐学 · 2 小时内 · 11-17 21:00 · 离散数学 / 练习" in message
    assert "MEDIA：/tmp/private.png（提交状态未确认）" in message
    assert all(title not in message for title in ("已交", "隐藏", "刚开启", "无截止", "已过期"))
    assert run_reminders(events, now + timedelta(minutes=30)) == ""
