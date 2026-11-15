from contextlib import nullcontext
from datetime import datetime, timedelta
from types import SimpleNamespace

import pytest

from hermes_personal import yanhekt


def test_reads_latest_term_deadlines_and_confirms_only_explicit_submission(monkeypatch):
    since = datetime.fromisoformat("2026-11-16T12:00:00+08:00")
    due = since + timedelta(hours=8)
    time = str(int(due.timestamp()))
    work = {"id": 2, "sub_title": "新作业", "type": "work", "deadline_at": time, "show": "yes"}
    answers = {
        "/userapi/v1/infosimple": {"code": 200, "params": {"account": "fixture"}},
        "/vlabpassportapi/v1/account-profile/course": {
            "code": 1000,
            "params": {
                "result": {
                    "data": [
                        {"Id": 8, "TermName": "2025-2026-2"},
                        {"Id": 9, "TermName": "2026-2027-1"},
                    ],
                    "total": 2,
                }
            },
        },
        "/courseapi/v3/multi-search/get-course-detail": {
            "code": 0,
            "data": {
                "title": "实验",
                "auto_chapter": True,
                "origin_sub_list": {
                    "week": [
                        work,
                        {**work, "id": 3, "sub_title": "考试", "type": "exam", "finished": 1},
                        {**work, "id": 4, "show": "no"},
                        {**work, "id": 5, "sub_delete": "1"},
                        {**work, "id": 6, "deadline_at": "0"},
                        {**work, "id": 7, "type": "course_live"},
                    ]
                },
            },
        },
    }

    def get(url, *, headers, params, timeout):
        assert headers["Authorization"] == "Bearer fixture"
        assert timeout > 0
        path = url.removeprefix(yanhekt.campus.YANHEKIT)
        if path == "/courseapi/v3/multi-search/get-course-detail":
            assert params == {"course_id": 9, "student": "fixture"}
        if path == "/courseapi/v3/finish-sub/my-sub-status":
            body = {
                "code": 0,
                "data": {2: {"committed": "1"}, 3: {"finished": 1}}[params["sub_id"]],
            }
        else:
            body = answers[path]
        return SimpleNamespace(
            status_code=200, text="{}", raise_for_status=lambda: None, json=lambda: body
        )

    monkeypatch.setattr(yanhekt.campus, "session", lambda: nullcontext(SimpleNamespace(get=get)))
    monkeypatch.setattr(
        yanhekt.campus, "yanhekt_headers", lambda _: {"Authorization": "Bearer fixture"}
    )
    events = yanhekt.calendar(since=since)
    assert [(row["id"], row["source"], row["event_type"], row["completed"]) for row in events] == [
        ("yanhekt-2", "yanhekt", "due", True),
        ("yanhekt-3", "yanhekt", "close", None),
    ]
    assert all(row["due"] == due.isoformat() for row in events)


def test_missing_session_requires_login(monkeypatch):
    monkeypatch.setattr(yanhekt.campus, "session", lambda: nullcontext(None))
    monkeypatch.setattr(yanhekt.campus, "yanhekt_headers", lambda _: {})
    with pytest.raises(yanhekt.SessionExpired, match="请先完成校园登录"):
        yanhekt.calendar()
