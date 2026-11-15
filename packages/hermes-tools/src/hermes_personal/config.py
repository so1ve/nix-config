import json
import os
from pathlib import Path


def home() -> Path:
    return Path(os.environ.get("HERMES_HOME", "/opt/data"))


def config_path() -> Path:
    configured = os.environ.get("HERMES_PERSONAL_CONFIG")
    return Path(configured) if configured else home() / ".config/hermes-personal/config.json"


def mail_credentials_dir() -> Path:
    return home() / ".config/hermes-personal/mail"


def load() -> dict:
    return json.loads(config_path().read_text())
