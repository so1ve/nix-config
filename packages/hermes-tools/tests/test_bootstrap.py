import json
from unittest.mock import patch

from hermes_personal import bootstrap


def test_native_create_uses_positional_schedule_and_prompt(monkeypatch):
    monkeypatch.setattr(bootstrap, "_jobs", list)
    with patch("hermes_personal.bootstrap.subprocess.run") as run:
        bootstrap._apply_job(
            "Hermes · 邮件",
            "*/10 * * * *",
            "prompt",
            monitor="/opt/data/scripts/personal/mail-check.py",
            interpreter="/opt/data/.local/share/hermes-personal/bin/python",
        )
    command = run.call_args.args[0]
    assert command[:5] == ["hermes", "cron", "create", "*/10 * * * *", "prompt"]
    assert "--monitor-script" in command
    assert "--continuity" in command
    assert "--schedule" not in command
    assert "--prompt" not in command
    assert run.call_args.kwargs["check"] is True


def test_existing_job_is_edited_in_place(monkeypatch):
    monkeypatch.setattr(bootstrap, "_jobs", lambda: [{"id": "abc", "name": "Hermes · 邮件"}])
    with patch("hermes_personal.bootstrap.subprocess.run") as run:
        bootstrap._apply_job(
            "Hermes · 邮件",
            "*/10 * * * *",
            "prompt",
            monitor="/opt/data/scripts/personal/mail-check.py",
            interpreter="/opt/data/.local/share/hermes-personal/bin/python",
        )
    command = run.call_args.args[0]
    assert command[:4] == ["hermes", "cron", "edit", "abc"]
    assert command[4:8] == ["--schedule", "*/10 * * * *", "--prompt", "prompt"]


def test_register_jobs_removes_fixed_greetings(tmp_path, monkeypatch):
    monkeypatch.setenv("HERMES_HOME", str(tmp_path))
    jobs = [
        {"id": "old", "name": "个人助理 · 晚间问候"},
        {"id": "current", "name": "Hermes · 晚间问候"},
        {"id": "custom", "name": "Ray 的提醒"},
    ]
    (tmp_path / "cron").mkdir()
    (tmp_path / "cron/jobs.json").write_text(json.dumps({"jobs": jobs}))

    with patch("hermes_personal.bootstrap.subprocess.run") as run:
        bootstrap.register_jobs()

    commands = [call.args[0] for call in run.call_args_list]
    assert [command[3] for command in commands if command[2] == "remove"] == ["old", "current"]
    created = [
        command[command.index("--name") + 1] for command in commands if command[2] == "create"
    ]
    assert created == ["Hermes · 邮件", "Hermes · 乐学"]


def test_old_credentials_and_cookies_are_migrated_once(tmp_path, monkeypatch):
    monkeypatch.setenv("HERMES_HOME", str(tmp_path))
    old_credentials = tmp_path / "assistant/credentials"
    old_credentials.mkdir(parents=True)
    (old_credentials / "gmail").write_text("mail-secret")
    (tmp_path / "assistant/campus.cookies").write_text("cookie-data")

    bootstrap.migrate_credentials()

    assert (tmp_path / ".config/hermes-personal/mail/gmail").read_text() == "mail-secret"
    assert (tmp_path / ".config/hermes-personal/campus.cookies").read_text() == "cookie-data"
    assert (tmp_path / ".config/yanhekit/cookies.txt").read_text() == "cookie-data"

    (tmp_path / ".config/yanhekit/cookies.txt").write_text("renewed")
    bootstrap.migrate_credentials()
    assert (tmp_path / ".config/yanhekit/cookies.txt").read_text() == "renewed"
