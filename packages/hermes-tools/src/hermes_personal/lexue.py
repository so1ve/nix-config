"""Read Lexue's authenticated Moodle calendar without subscription tokens."""

import re
from contextlib import contextmanager
from datetime import datetime
from urllib.parse import parse_qs, urlsplit
from zoneinfo import ZoneInfo

from bs4 import BeautifulSoup

from . import campus


def _ajax(client, sesskey, calls):
    response = client.post(
        campus.LEXUE + "/lib/ajax/service.php",
        params={"sesskey": sesskey},
        json=[
            {"index": index, "methodname": method, "args": arguments}
            for index, (method, arguments) in enumerate(calls)
        ],
        headers={"X-Requested-With": "XMLHttpRequest"},
        timeout=45,
    )
    response.raise_for_status()
    results = response.json()
    if not isinstance(results, list) or len(results) != len(calls):
        raise RuntimeError("乐学 AJAX 返回格式异常")
    for (method, _), row in zip(calls, results):
        if row.get("error"):
            code = row.get("exception", {}).get("errorcode", "unknown")
            raise RuntimeError(f"乐学 {method} 失败：{code}")
    return [row["data"] for row in results]


@contextmanager
def authenticated():
    with campus.session() as client:
        page = campus.open_service(client, campus.LEXUE + "/my/")
        match = re.search(r"""["']sesskey["']\s*:\s*["']([^"']+)""", page.text)
        if match is None:
            raise RuntimeError("乐学会话无效，请先完成校园登录")
        yield client, match[1]


def courses(keyword: str = "") -> list[dict]:
    with authenticated() as (client, sesskey):
        courses, offset = [], 0
        while True:
            data = _ajax(
                client,
                sesskey,
                [
                    (
                        "core_course_get_enrolled_courses_by_timeline_classification",
                        {"classification": "all", "limit": 50, "offset": offset},
                    )
                ],
            )[0]
            courses.extend(
                {key: row.get(key) for key in ("id", "fullname", "viewurl")}
                for row in data["courses"]
                if keyword.casefold() in row["fullname"].casefold()
            )
            next_offset = data["nextoffset"]
            if not data["courses"] or next_offset <= offset:
                return courses
            offset = next_offset


def _completed(fragment: str) -> bool | None:
    soup = BeautifulSoup(fragment, "html.parser")
    if soup.select_one('[data-toggletype="manual:undo"], .submissionstatussubmitted'):
        return True
    conditions = soup.select('[data-region="completionrequirements"] [role="listitem"]')
    if not conditions:
        return None
    return all("badge-success" in item.get("class", []) for item in conditions)


def calendar(year: int | None = None, month: int | None = None, course_id: int = 0) -> list[dict]:
    if (year is None) != (month is None):
        raise ValueError("查询月份时必须同时提供 year 和 month")
    with authenticated() as (client, sesskey):
        if year is None:
            data = _ajax(
                client,
                sesskey,
                [("core_calendar_get_calendar_upcoming_view", {"courseid": course_id})],
            )[0]
            events = data["events"]
        else:
            data = _ajax(
                client,
                sesskey,
                [
                    (
                        "core_calendar_get_calendar_monthly_view",
                        {
                            "year": year,
                            "month": month,
                            "courseid": course_id,
                            "includenavigation": False,
                        },
                    )
                ],
            )[0]
            events = [
                event
                for week in data["weeks"]
                for day in week["days"]
                for event in day.get("events", [])
            ]

        events = list({event["id"]: event for event in events}.values())
        modules = {}
        for event in events:
            url = urlsplit(event.get("url") or "")
            if url.hostname == "lexue.bit.edu.cn" and url.path.startswith("/mod/"):
                module_id = parse_qs(url.query).get("id", [""])[0]
                if module_id.isdigit():
                    modules[event["id"]] = int(module_id)

        ids = sorted(set(modules.values()))
        fragments = (
            _ajax(client, sesskey, [("core_course_get_module", {"id": value}) for value in ids])
            if ids
            else []
        )
        completed = {value: _completed(fragment) for value, fragment in zip(ids, fragments)}
        return [
            {
                "id": str(event["id"]),
                "title": event["name"],
                "due": datetime.fromtimestamp(
                    event["timestart"], ZoneInfo("Asia/Shanghai")
                ).isoformat()
                if event.get("timestart")
                else None,
                "course": (event.get("course") or {}).get("fullname", ""),
                "url": event.get("url", ""),
                "description": BeautifulSoup(event.get("description", ""), "html.parser").get_text(
                    " ", strip=True
                ),
                "event_type": event.get("eventtype", ""),
                "completed": completed.get(modules.get(event["id"])),
                "visible": event.get("visible", True),
            }
            for event in events
        ]
