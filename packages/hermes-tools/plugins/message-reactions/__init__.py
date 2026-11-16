# ruff: noqa: N999
"""Let Hermes react to the Telegram message that started the current turn."""

import json


def register(ctx):
    def react(args):
        from gateway.session_context import get_session_env

        if get_session_env("HERMES_SESSION_PLATFORM") != "telegram":
            return json.dumps({"ok": False, "error": "Reactions require a Telegram conversation."})

        chat_id = get_session_env("HERMES_SESSION_CHAT_ID")
        message_id = get_session_env("HERMES_SESSION_MESSAGE_ID")
        if not chat_id or not message_id:
            return json.dumps({"ok": False, "error": "There is no current Telegram message."})

        emoji = args.get("emoji")
        if not isinstance(emoji, str) or not emoji.strip():
            return json.dumps({"ok": False, "error": "Provide a Telegram reaction emoji."})

        from hermes_cli.plugin_host import _run_on_gateway_loop

        # The tool runs off the gateway loop, but the Telegram adapter belongs to it.
        result = _run_on_gateway_loop(
            ctx.platform_actions.add_reaction("telegram", chat_id, message_id, emoji.strip())
        )
        return json.dumps(result)

    description = "React to the current Telegram message using a single emoji."
    ctx.register_tool(
        name="react_to_current_message",
        toolset="message-reactions",
        description=description,
        schema={
            "name": "react_to_current_message",
            "description": description,
            "parameters": {
                "type": "object",
                "properties": {"emoji": {"type": "string", "minLength": 1}},
                "required": ["emoji"],
                "additionalProperties": False,
            },
        },
        handler=react,
    )
