"""Read courses, materials, assignments and exams from BIT's new Eclass platform."""

import logging
from contextlib import contextmanager
from datetime import datetime
from itertools import count
from urllib.parse import quote
from zoneinfo import ZoneInfo

from bs4 import BeautifulSoup
from requests import RequestException

from . import campus

_ZONE = ZoneInfo("Asia/Shanghai")
_PAGE_SIZE = 100
_HEADERS = {"Accept": "application/json", "X-Requested-With": "XMLHttpRequest"}
_LOG = logging.getLogger(__name__)


class SessionExpired(RuntimeError):
    """The new Eclass session needs to be renewed through campus login."""


def _api(client, path: str, *, body: dict | None = None) -> dict:
    url = campus.ECLASS + path
    if body is None:
        response = client.get(url, headers=_HEADERS, timeout=45)
    else:
        response = client.post(url, json=body, headers=_HEADERS, timeout=45)
    if response.status_code == 401:
        raise SessionExpired("新乐学会话无效，请先完成校园登录")
    response.raise_for_status()
    if response.text.lstrip().startswith("<"):
        raise SessionExpired("新乐学会话无效，请先完成校园登录")
    return response.json()


def _courses(client):
    for page in count(1):
        response = _api(
            client,
            "/api/my-courses",
            body={"page": page, "page_size": _PAGE_SIZE, "fields": "id,name", "conditions": {}},
        )
        rows = response["courses"]
        yield from rows
        pages = response.get("pages")
        if not rows or (page >= pages if pages is not None else len(rows) < _PAGE_SIZE):
            return


@contextmanager
def _authenticated():
    with campus.session() as client:
        campus.open_service(client, campus.ECLASS + "/user/courses")
        yield client


def courses() -> list[dict]:
    """List the IDs and names of the user's Eclass courses."""
    with _authenticated() as client:
        return [{"id": str(row["id"]), "name": row["name"]} for row in _courses(client)]


def materials(course_id: str) -> list[dict]:
    """List published activities and metadata for uploads available to download."""
    course_id = quote(course_id, safe="")
    with _authenticated() as client:
        response = _api(client, f"/api/courses/{course_id}/activities")

    activities = []
    for row in response["activities"]:
        if row.get("published") is not True:
            continue
        activity_id = str(row["id"])
        uploads = [
            {key: upload.get(key) for key in ("id", "name", "link", "size", "type", "videos")}
            for upload in (row.get("uploads") or [])
            if upload.get("allow_download") is True and upload.get("deleted") is False
        ]
        activity = {
            "id": activity_id,
            "title": row["title"],
            "type": row["type"],
            "url": f"{campus.ECLASS}/course/{course_id}/learning-activity#/"
            + quote(activity_id, safe=""),
            "uploads": uploads,
        }
        if row["type"] == "page":
            body = (row.get("data") or {}).get("description") or ""
            activity["description"] = BeautifulSoup(body, "html.parser").get_text(" ", strip=True)
        activities.append(activity)
    return activities


def _date(value: str | None) -> datetime | None:
    if value is None or value.strip() in {"", "null"}:
        return None
    timestamp = datetime.fromisoformat(value.replace("/", "-"))
    return timestamp.astimezone(_ZONE) if timestamp.tzinfo else timestamp.replace(tzinfo=_ZONE)


def _activity_statuses(client, course_id: str) -> dict:
    try:
        response = _api(
            client, f"/api/course/{course_id}/homework/submission-status?no-intercept=true"
        )
        return {
            str(row["id"]): row.get("status_code") == "submitted"
            for row in response["homework_activities"]
        }
    except RequestException:
        # Older server builds expose completion only through individual activities.
        return {}


def _event(
    row: dict, course: str, due: datetime, activity_url: str, *, exam: bool, done: bool | None
):
    return {
        "id": f"eclass-exam-{row['id']}" if exam else f"eclass-{row['id']}",
        "source": "eclass",
        "title": row.get("title") or ("未命名测试" if exam else "未命名作业"),
        "due": due.isoformat(),
        "course": course,
        "url": campus.ECLASS + activity_url,
        "description": "",
        "event_type": "close" if exam else "due",
        "completed": done,
        "visible": True,
    }


def _activities(client, course_id: str, course: str, since: datetime):
    response = _api(client, f"/api/courses/{course_id}/activities")
    due_activities = []
    for row in response["activities"]:
        if row["type"] == "material" or row.get("published") is False:
            continue
        due = _date(row.get("end_time")) or _date(row.get("visible_end_at"))
        if due is not None and due > since:
            due_activities.append((row, due))

    statuses = (
        _activity_statuses(client, course_id)
        if any(row["type"] == "homework" for row, _ in due_activities)
        else {}
    )
    for row, due in due_activities:
        activity_id = str(row["id"])
        status = statuses.get(activity_id)
        if activity_id not in statuses:
            try:
                detail = _api(client, f"/api/activities/{quote(activity_id, safe='')}")
                count = detail.get("user_submit_count")
                status = int(count) > 0 if count is not None else None
            except RequestException:
                status = None
        url = f"/course/{course_id}/learning-activity#/{quote(activity_id, safe='')}"
        yield _event(row, course, due, url, exam=False, done=status)


def _exams(client, course_id: str, course: str, since: datetime):
    for page in count(1):
        response = _api(
            client, f"/api/courses/{course_id}/exam-list?page={page}&page_size={_PAGE_SIZE}"
        )
        rows = response["exams"]
        for row in rows:
            due = _date(row.get("end_time"))
            if due is not None and due > since:
                submissions = row.get("submission_count")
                status = int(submissions) > 0 if submissions is not None else None
                yield _event(row, course, due, f"/course/{course_id}/exam", exam=True, done=status)
        pages = response.get("pages")
        if not rows or (page >= pages if pages is not None else len(rows) < _PAGE_SIZE):
            return


def calendar(*, since: datetime | None = None) -> list[dict]:
    """List upcoming Eclass deadlines with their submission status."""
    when = since if since is not None else datetime.now(_ZONE)
    events = {}
    failures = []
    with _authenticated() as client:
        for course in _courses(client):
            course_id = quote(str(course["id"]), safe="")
            for fetch in (_activities, _exams):
                try:
                    for event in fetch(client, course_id, course["name"], when):
                        events[event["id"]] = event
                except RequestException as error:
                    failures.append(error)
                    _LOG.warning("新乐学课程 %s 的截止时间读取失败：%s", course_id, error)
    if not events and failures:
        raise failures[0]
    return list(events.values())
