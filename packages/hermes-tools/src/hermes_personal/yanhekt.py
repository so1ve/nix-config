"""Read structured deadlines from the AITA Yanhekt course platform."""

import logging
from datetime import datetime
from itertools import count
from urllib.parse import urlencode
from zoneinfo import ZoneInfo

from requests import RequestException

from . import campus

_ZONE = ZoneInfo("Asia/Shanghai")
_DEADLINE_TYPES = {
    "work",
    "workbeta",
    "feedback",
    "exam",
    "discuss",
    "courseware",
    "video",
    "questionnaire",
}
_LOG = logging.getLogger(__name__)


class SessionExpired(RuntimeError):
    """The AITA session needs to be renewed through campus login."""


def _get(client, headers, path, **params):
    response = client.get(campus.YANHEKIT + path, headers=headers, params=params, timeout=12)
    if response.status_code == 401:
        raise SessionExpired("延河课堂会话无效，请先完成校园登录")
    response.raise_for_status()
    if response.text.lstrip().startswith("<"):
        raise SessionExpired("延河课堂会话无效，请先完成校园登录")
    return response.json()


def _courses(client, headers):
    found = []
    for page in count(1):
        body = _get(
            client,
            headers,
            "/vlabpassportapi/v1/account-profile/course",
            force_mycourse=1,
            nowpage=page,
            **{"per-page": 100},
        )
        if body.get("code") != 1000:
            raise RuntimeError("延河课堂未返回已选课程")
        result = body["params"]["result"]
        rows = result["data"]
        found.extend(rows)
        if not rows or len(found) >= result["total"]:
            return found


def _subjects(node):
    if isinstance(node, dict):
        if {"id", "sub_title", "type"} <= node.keys():
            yield node
            return
        node = node.values()
    elif not isinstance(node, list):
        return
    for child in node:
        yield from _subjects(child)


def _completed(client, headers, subject_id) -> bool | None:
    try:
        body = _get(client, headers, "/courseapi/v3/finish-sub/my-sub-status", sub_id=subject_id)
    except RequestException:
        return None
    if body.get("code") != 0:
        return None
    committed = body["data"].get("committed")
    if committed in (1, "1"):
        return True
    if committed in (0, "0"):
        return False
    return None


def calendar(*, since: datetime | None = None) -> list[dict]:
    """List upcoming deadlines for the user's latest enrolled term."""
    when = since if since is not None else datetime.now(_ZONE)
    events = {}
    errors = []
    checked = False
    with campus.session() as client:
        headers = campus.yanhekt_headers(client)
        if not headers:
            raise SessionExpired("延河课堂会话无效，请先完成校园登录")
        headers = {**headers, "Referer": campus.YANHEKIT + "/"}
        profile = _get(client, headers, "/userapi/v1/infosimple")
        if profile.get("code") != 200:
            raise SessionExpired("延河课堂会话无效，请先完成校园登录")
        account = profile["params"]["account"]
        courses = _courses(client, headers)
        term = max((row["TermName"] for row in courses), default="")
        for course in courses:
            if course["TermName"] != term:
                continue
            course_id = course["Id"]
            try:
                body = _get(
                    client,
                    headers,
                    "/courseapi/v3/multi-search/get-course-detail",
                    course_id=course_id,
                    student=account,
                )
                if body.get("code") != 0:
                    raise RuntimeError(f"延河课堂无法读取课程 {course_id}")
            except SessionExpired:
                raise
            except (RequestException, RuntimeError) as error:
                errors.append(error)
                _LOG.warning("延河课堂课程 %s 的截止时间读取失败", course_id)
                continue

            checked = True
            detail = body["data"]
            sections = detail.get("origin_sub_list") if detail.get("auto_chapter") else None
            if sections is None:
                sections = detail.get("sub_list")
            course_url = campus.YANHEKIT + "/coursedetail?" + urlencode({"course_id": course_id})
            for row in _subjects(sections):
                kind = row["type"]
                raw_due = str(row.get("deadline_at") or "")
                if (
                    kind not in _DEADLINE_TYPES
                    or row.get("show") == "no"
                    or row.get("sub_delete") in (1, "1")
                    or len(raw_due) != 10
                    or not raw_due.isascii()
                    or not raw_due.isdigit()
                ):
                    continue
                due = datetime.fromtimestamp(int(raw_due), _ZONE)
                event_id = f"yanhekt-{row['id']}"
                if due <= when or event_id in events:
                    continue
                events[event_id] = {
                    "id": event_id,
                    "source": "yanhekt",
                    "title": row["sub_title"],
                    "due": due.isoformat(),
                    "course": detail["title"],
                    "url": course_url,
                    "description": "",
                    "event_type": "close" if kind == "exam" else "due",
                    "completed": _completed(client, headers, row["id"]),
                    "visible": True,
                }
    if errors and not checked:
        raise errors[0]
    return list(events.values())
