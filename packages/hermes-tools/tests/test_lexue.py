from contextlib import contextmanager
from types import SimpleNamespace

import pytest

from hermes_personal import lexue


class Client:
    def post(self, url, *, params, json, **kwargs):
        assert params["sesskey"] == "private"
        result = []
        for call in json:
            if call["methodname"] == "core_calendar_get_calendar_monthly_view":
                assert call["args"]["courseid"] == 42
                data = {
                    "weeks": [
                        {
                            "days": [
                                {
                                    "events": [
                                        {
                                            "id": 1,
                                            "name": "Quiz",
                                            "timestart": 2000000000,
                                            "eventtype": "close",
                                            "url": "https://lexue.bit.edu.cn/mod/quiz/view.php?id=55",
                                        }
                                    ]
                                }
                            ]
                        }
                    ]
                }
            else:
                assert call["args"]["id"] == 55
                data = "<p>not submitted</p>"
            result.append({"data": data})
        return SimpleNamespace(raise_for_status=lambda: None, json=lambda: result)


def test_calendar_keeps_unknown_completion_unknown(monkeypatch):
    @contextmanager
    def authenticated():
        yield Client(), "private"

    monkeypatch.setattr(lexue, "authenticated", authenticated)
    events = lexue.calendar(2026, 11, 42)
    assert events[0]["completed"] is None
    assert "private" not in str(events)


def test_invalid_month_is_rejected():
    with pytest.raises(ValueError):
        lexue.calendar(year=2026)
