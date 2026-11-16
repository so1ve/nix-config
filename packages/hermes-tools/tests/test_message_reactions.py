import asyncio
import json
import runpy
import sys
from pathlib import Path
from types import SimpleNamespace

import pytest


@pytest.fixture
def reaction_tool(monkeypatch):
    session = {
        "HERMES_SESSION_PLATFORM": "telegram",
        "HERMES_SESSION_CHAT_ID": "123",
        "HERMES_SESSION_MESSAGE_ID": "456",
    }
    monkeypatch.setitem(
        sys.modules,
        "gateway.session_context",
        SimpleNamespace(get_session_env=lambda key: session.get(key, "")),
    )
    monkeypatch.setitem(
        sys.modules,
        "hermes_cli.plugin_host",
        SimpleNamespace(_run_on_gateway_loop=asyncio.run),
    )
    calls = []
    result = {"ok": True, "action": "add_reaction"}

    async def add_reaction(*args):
        calls.append(args)
        return result

    registered = {}
    ctx = SimpleNamespace(
        platform_actions=SimpleNamespace(add_reaction=add_reaction),
        register_tool=lambda **tool: registered.update(tool),
    )
    plugin = Path(__file__).resolve().parents[1] / "plugins/message-reactions/__init__.py"
    runpy.run_path(plugin)["register"](ctx)
    return registered, session, calls, result


def test_reaction_uses_bound_message_and_preserves_platform_error(reaction_tool):
    tool, session, calls, result = reaction_tool
    assert set(tool["schema"]["parameters"]["properties"]) == {"emoji"}
    handler = tool["handler"]
    assert json.loads(handler({"emoji": "👍"}))["ok"] is True
    assert calls == [("telegram", "123", "456", "👍")]

    session["HERMES_SESSION_MESSAGE_ID"] = "457"
    result.clear()
    result.update(ok=False, error="action_failed", detail="Telegram rejected this reaction")
    assert json.loads(handler({"emoji": "❤️"})) == result
    assert calls[-1] == ("telegram", "123", "457", "❤️")


@pytest.mark.parametrize(
    ("field", "value", "emoji"),
    [
        ("HERMES_SESSION_PLATFORM", "onebot", "👍"),
        ("HERMES_SESSION_CHAT_ID", "", "👍"),
        ("HERMES_SESSION_MESSAGE_ID", "", "👍"),
        ("HERMES_SESSION_PLATFORM", "telegram", "  "),
    ],
)
def test_unavailable_reaction_does_not_call_platform(reaction_tool, field, value, emoji):
    tool, session, calls, _ = reaction_tool
    session[field] = value
    result = json.loads(tool["handler"]({"emoji": emoji}))
    assert result["ok"] is False and result["error"]
    assert calls == []
