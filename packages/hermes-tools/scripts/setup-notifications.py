"""Install the added notification jobs once, using Hermes' native cron commands."""

import json
import os
import subprocess
from pathlib import Path

profile = Path(os.environ["HERMES_HOME"])
installed = profile / ".local/state/hermes-personal/course-notifications-installed"
if not installed.exists():
    defaults = json.loads(Path("/etc/hermes/personal-cron.json").read_text())["jobs"]
    existing = json.loads((profile / "cron/jobs.json").read_text())["jobs"]
    names = {job["name"] for job in existing}
    for job in defaults:
        if job["name"] not in {"Hermes · 截止提醒", "Hermes · 课程"} or job["name"] in names:
            continue
        command = [
            "hermes",
            "cron",
            "create",
            job["schedule"]["expr"],
            job["prompt"],
            "--name",
            job["name"],
            "--deliver",
            job["deliver"],
            "--failure-deliver",
            job["failure_deliver"],
            "--interpreter",
            job["interpreter"],
            "--timezone",
            job["timezone"],
            "--workdir",
            job["workdir"],
            "--catch-up",
            "off",
        ]
        if job.get("no_agent"):
            command.extend(["--script", job["script"], "--no-agent"])
        else:
            command.extend(["--monitor-script", job["monitor_script"], "--continuity"])
            for skill in job["skills"]:
                command.extend(["--skill", skill])
        subprocess.run(command, check=True)
    installed.parent.mkdir(parents=True, exist_ok=True)
    installed.touch(mode=0o600)
