"""Migrate personal tool data and reconcile native Hermes cron jobs."""

import json
import shutil
import subprocess
import sys
from pathlib import Path

from .config import home, mail_credentials_dir

LEGACY_JOBS = {
    "Hermes · 晚间问候",
    "个人助理 · 晚间问候",
    "个人助理 · 邮件子 Agent 分拣",
    "个人助理 · 离散数学课后整理",
    "个人助理 · 课程更新",
    "个人助理 · 乐学截止同步",
    "个人助理 · 作业提醒与通知投递",
    "个人助理 · 普通邮件晚间摘要",
}

MAIL_PROMPT = "请子 Agent 查看本次变化的邮件，找出需要 Ray 留意的事项。"
LEXUE_PROMPT = "请子 Agent 比较本次和上次的乐学日历，找出新增、变更或取消的截止事项。"


def migrate_credentials():
    destination = mail_credentials_dir()
    destination.mkdir(parents=True, exist_ok=True, mode=0o700)
    for account in ("gmail", "163"):
        old = home() / "assistant/credentials" / account
        new = destination / account
        if old.is_file() and not new.exists():
            shutil.copyfile(old, new)
            new.chmod(0o600)
    old_cookies = home() / "assistant/campus.cookies"
    if old_cookies.is_file():
        for target in (
            home() / ".config/hermes-personal/campus.cookies",
            home() / ".config/yanhekit/cookies.txt",
        ):
            if not target.exists():
                target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
                shutil.copyfile(old_cookies, target)
                target.chmod(0o600)


def _jobs() -> list[dict]:
    path = home() / "cron/jobs.json"
    return json.loads(path.read_text()).get("jobs", []) if path.exists() else []


def remove_legacy_runtime():
    shutil.rmtree(home() / "scripts/personal-assistant", ignore_errors=True)
    shutil.rmtree(home() / "assistant/venv", ignore_errors=True)


def _remove_legacy_jobs():
    for job in _jobs():
        if job.get("name") in LEGACY_JOBS:
            subprocess.run(["hermes", "cron", "remove", job["id"]], check=True)


def _apply_job(name, schedule, prompt, *, monitor, interpreter):
    current = next((job for job in _jobs() if job.get("name") == name), None)
    options = [
        "--name",
        name,
        "--deliver",
        "local",
        "--failure-deliver",
        "local",
        "--timezone",
        "Asia/Shanghai",
        "--workdir",
        "/opt/data",
        "--skill",
        "personal-assistant",
        "--monitor-script",
        str(monitor),
        "--interpreter",
        str(interpreter),
        "--continuity",
        "--catch-up",
        "off",
    ]
    if current:
        subprocess.run(
            [
                "hermes",
                "cron",
                "edit",
                current["id"],
                "--schedule",
                schedule,
                "--prompt",
                prompt,
                *options,
            ],
            check=True,
        )
    else:
        subprocess.run(
            ["hermes", "cron", "create", schedule, prompt, *options],
            check=True,
        )


def register_jobs():
    _remove_legacy_jobs()
    _apply_job(
        "Hermes · 邮件",
        "*/10 * * * *",
        MAIL_PROMPT,
        monitor="personal/mail-check.py",
        interpreter=sys.executable,
    )
    _apply_job(
        "Hermes · 乐学",
        "*/30 * * * *",
        LEXUE_PROMPT,
        monitor="personal/lexue-check.py",
        interpreter=sys.executable,
    )


def main():
    migrate_credentials()
    remove_legacy_runtime()
    register_jobs()


if __name__ == "__main__":
    main()
