#!/usr/bin/env python3
"""Repair managed PWA shortcuts left behind by temporary Playwright profiles."""

import json
import os
from pathlib import Path
import re
import shlex
import shutil
import stat
import sys
import tempfile


apps = json.loads(Path(sys.argv[1]).read_text())
applications = Path(sys.argv[2])
backup_root = Path(sys.argv[3])
app_ids = {app["appId"] for app in apps}
app_names = {app["custom_name"] for app in apps}
temporary_roots = {Path("/tmp")}
if os.environ.get("TMPDIR"):
    temporary_roots.add(Path(os.environ["TMPDIR"]))

# Keep token offsets so removing an argument preserves all other file contents.
token_pattern = re.compile(r'''(?:[^\s'"\\]|\\.|"(?:[^"\\]|\\.)*"|'[^']*')+''')
changes = []
for path in sorted(applications.glob("chrome-*-Default.desktop")):
    if not stat.S_ISREG(path.lstat().st_mode):
        continue
    original = path.read_bytes()
    contents = original.decode("utf-8")
    entry = re.search(r"(?ms)^\[Desktop Entry\]\r?\n(.*?)(?=^\[|\Z)", contents)
    if entry is None:
        continue
    name = re.search(r"(?m)^Name=([^\r\n]*)", entry[1])
    app_id = path.name.removeprefix("chrome-").removesuffix("-Default.desktop")
    if app_id not in app_ids and (name is None or name[1] not in app_names):
        continue
    command = re.search(r"(?m)^Exec=([^\r\n]*)", entry[1])
    if command is None:
        continue
    matches = list(token_pattern.finditer(command[1]))
    try:
        tokens = [shlex.split(match[0])[0] for match in matches]
    except (ValueError, IndexError):
        continue
    if not tokens or Path(tokens[0]).name not in {
        "chrome",
        "google-chrome",
        "google-chrome-stable",
    }:
        continue
    removals = []
    for index, token in enumerate(tokens):
        last_index = index
        if token.startswith("--user-data-dir="):
            directory = token.removeprefix("--user-data-dir=")
        elif token == "--user-data-dir" and index + 1 < len(tokens):
            last_index += 1
            directory = tokens[last_index]
        else:
            continue
        profile = Path(directory)
        if profile.parent not in temporary_roots or not profile.name.startswith(
            "playwright_chromiumdev_profile-"
        ):
            continue
        start = matches[index].start()
        while start > 0 and command[1][start - 1] in " \t":
            start -= 1
        removals.append((start, matches[last_index].end()))
    if not removals:
        continue
    if app_id not in app_ids:
        changes.append((path, None))
        continue
    repaired = command[1]
    for start, end in reversed(removals):
        repaired = repaired[:start] + repaired[end:]
    start = entry.start(1) + command.start(1)
    end = entry.start(1) + command.end(1)
    updated = contents[:start] + repaired + contents[end:]
    changes.append((path, updated.encode("utf-8")))

if changes:
    backup_root.mkdir(parents=True, exist_ok=True)
    backup = Path(tempfile.mkdtemp(prefix="playwright-shortcuts-", dir=backup_root))
    for path, _ in changes:
        shutil.copy2(path, backup / path.name)
    for path, updated in changes:
        if updated is None:
            path.unlink()
        else:
            path.write_bytes(updated)
    print(f"Repaired {len(changes)} PWA shortcuts; originals saved in {backup}")
