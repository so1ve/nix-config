from contextlib import nullcontext
from datetime import datetime

import pytest
from requests import HTTPError

from hermes_personal import eclass


class Client:
    def __init__(self, answers):
        self.answers = answers

    def get(self, url, **kwargs):
        return self.request(url, None, **kwargs)

    def post(self, url, *, json, **kwargs):
        return self.request(url, json, **kwargs)

    def request(self, url, body, *, headers, timeout):
        assert headers["X-Requested-With"] == "XMLHttpRequest"
        assert timeout > 0
        path = url.removeprefix(eclass.campus.ECLASS)
        status, value = self.answers[path, body["page"] if body else None]

        class Reply:
            status_code = status
            text = value if isinstance(value, str) else "{}"

            def json(self):
                return value

            def raise_for_status(self):
                if status >= 400:
                    raise HTTPError(f"HTTP {status}")

        return Reply()


@pytest.fixture
def network(monkeypatch):
    monkeypatch.setattr(eclass.campus, "ECLASS", "https://zy-eclass.bit.edu.cn", raising=False)

    def configure(answers):
        client = Client(answers)
        monkeypatch.setattr(eclass.campus, "session", lambda: nullcontext(client))

        def open_service(session, url):
            assert session is client
            assert url == eclass.campus.ECLASS + "/user/courses"

        monkeypatch.setattr(eclass.campus, "open_service", open_service)

    return configure


def test_paginates_and_normalizes_homework_and_exam_deadlines(network):
    network(
        {
            ("/api/my-courses", 1): (200, {"courses": [{"id": 2, "name": "实验"}], "pages": 2}),
            ("/api/my-courses", 2): (200, {"courses": [{"id": 3, "name": "物理"}], "pages": 2}),
            ("/api/courses/2/activities", None): (500, "unavailable"),
            ("/api/courses/2/exam-list?page=1&page_size=100", None): (200, {"exams": []}),
            ("/api/courses/3/activities", None): (
                200,
                {
                    "activities": [
                        {
                            "id": 7,
                            "type": "homework",
                            "title": "练习",
                            "end_time": "2026-11-16T15:59Z",
                        },
                        {
                            "id": 8,
                            "type": "quiz",
                            "title": "测验",
                            "visible_end_at": "2026/11/17 08:00:00",
                        },
                        {"id": 9, "type": "material", "end_time": "2026-11-17T15:59Z"},
                        {
                            "id": 10,
                            "type": "homework",
                            "title": "未发布作业",
                            "end_time": "2026-11-16T15:59Z",
                            "published": False,
                        },
                    ]
                },
            ),
            ("/api/course/3/homework/submission-status?no-intercept=true", None): (
                200,
                {
                    "homework_activities": [{"id": 7, "status_code": "submitted"}],
                },
            ),
            ("/api/activities/8", None): (200, {}),
            ("/api/courses/3/exam-list?page=1&page_size=100", None): (
                200,
                {
                    "pages": 2,
                    "exams": [
                        {
                            "id": 7,
                            "title": "考试",
                            "end_time": "2026-11-17T09:00+08:00",
                            "submission_count": 0,
                        }
                    ],
                },
            ),
            ("/api/courses/3/exam-list?page=2&page_size=100", None): (
                200,
                {
                    "pages": 2,
                    "exams": [{"id": 10, "start_time": "2026-11-17T07:00+08:00"}],
                },
            ),
        }
    )

    events = eclass.calendar(since=datetime.fromisoformat("2026-11-16T00:00+08:00"))
    assert [event["id"] for event in events] == ["eclass-7", "eclass-8", "eclass-exam-7"]
    assert [event["due"] for event in events] == [
        "2026-11-16T23:59:00+08:00",
        "2026-11-17T08:00:00+08:00",
        "2026-11-17T09:00:00+08:00",
    ]
    assert [event["completed"] for event in events] == [True, None, False]
    assert events[-1]["event_type"] == "close"
    assert events[0]["url"] == eclass.campus.ECLASS + "/course/3/learning-activity#/7"


def test_does_not_treat_an_expired_session_as_an_empty_calendar(network):
    network({("/api/my-courses", 1): (200, "<html>登录</html>")})
    with pytest.raises(eclass.SessionExpired, match="请先完成校园登录"):
        eclass.calendar()


def test_lists_published_activities_and_only_downloadable_uploads(network):
    upload = {
        "id": 11,
        "name": "回放.mp4",
        "link": "https://recording.example/video?signature=fixture",
        "size": 1234,
        "type": "video",
        "videos": [{"opaque": "kept as returned"}],
    }
    network(
        {
            ("/api/my-courses", 1): (
                200,
                {"courses": [{"id": 3, "name": "物理", "discarded": "extra"}]},
            ),
            ("/api/courses/3/activities", None): (
                200,
                {
                    "activities": [
                        {
                            "id": 7,
                            "title": "实验说明",
                            "type": "page",
                            "published": True,
                            "data": {"description": "<p>先看<strong>第一节</strong>。</p>"},
                        },
                        {
                            "id": 8,
                            "title": "实验录像",
                            "type": "material",
                            "published": True,
                            "uploads": [
                                {**upload, "allow_download": True, "deleted": False, "source": "x"},
                                {**upload, "id": 12, "allow_download": True, "deleted": True},
                                {**upload, "id": 13, "allow_download": False, "deleted": False},
                            ],
                        },
                        {"id": 9, "type": "material", "published": False},
                    ]
                },
            ),
        }
    )
    assert eclass.courses() == [{"id": "3", "name": "物理"}]
    page, material = eclass.materials("3")
    assert page["description"] == "先看 第一节 。"
    assert page["url"] == eclass.campus.ECLASS + "/course/3/learning-activity#/7"
    assert page["uploads"] == []
    assert material["uploads"] == [upload]
