from random import randint

from hermes_cli.heartbeat import load_heartbeat, save_heartbeat

PROMPT = (
    "如果此刻想找 Ray 聊天，就直接说你想说的话。可以接着你们聊过的事，也可以开个新话题。"
    "一时没什么想说的，就只回复 [SILENT]。"
)


def handle(event_type, context):
    if context["platform"] != "telegram" or context["chat_type"] != "dm":
        return

    session_id = context["session_id"]
    state = load_heartbeat(session_id)
    if state is None or state.status != "active" or state.prompt != PROMPT:
        return

    if state.render_prompt()[:500] in context["message"]:
        state.interval_seconds = randint(15 * 60, 45 * 60)
        save_heartbeat(session_id, state)
