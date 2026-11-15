import json
import runpy
from pathlib import Path

import pytest

from hermes_personal import mailbox


class Mailbox:
    def __init__(self):
        self.allow_fetch = True
        self.failed_uid = None

    def __enter__(self):
        return self

    def __exit__(self, *args):
        pass

    def login(self, *args):
        pass

    def xatom(self, *args):
        pass

    def select(self, name, readonly):
        assert readonly is True
        return "OK", []

    def response(self, name):
        return name, [b"100"]

    def uid(self, operation, *args):
        if operation == "search":
            return "OK", [b"1 2 3"]
        assert self.allow_fetch, "the monitor must not fetch mail contents"
        assert operation == "fetch"
        assert args[1] == "(BODY.PEEK[]<0.65536>)"
        if args[0] == self.failed_uid:
            return "NO", []
        return "OK", [
            (args[0].encode(), b"From: teacher@example.com\r\nSubject: homework\r\n\r\nRead me")
        ]


@pytest.fixture
def inbox(tmp_path, monkeypatch):
    monkeypatch.setenv("HERMES_HOME", str(tmp_path))
    credentials = tmp_path / ".config/hermes-personal/mail"
    credentials.mkdir(parents=True)
    (credentials / "gmail").write_text("secret")
    monkeypatch.setattr(
        mailbox.config,
        "load",
        lambda: {
            "mail": [{"id": "gmail", "host": "imap.gmail.com", "address": "test@example.com"}]
        },
    )
    client = Mailbox()
    monkeypatch.setattr(mailbox.imaplib, "IMAP4_SSL", lambda *args, **kwargs: client)
    return client


def test_mail_is_read_only_and_has_stable_ids(inbox):
    result = mailbox.list_mail(limit=2)
    assert result["errors"] == []
    assert [message["id"] for message in result["messages"]] == ["gmail:100:3", "gmail:100:2"]
    assert result["messages"][0]["from"] == "teacher@example.com"
    assert result["messages"][0]["subject"] == "homework"
    assert result["messages"][0]["body"] == "Read me"


def test_monitor_outputs_only_ids_without_fetching_contents(inbox, capsys):
    inbox.allow_fetch = False
    runpy.run_path(Path(__file__).resolve().parents[1] / "scripts/mail-check.py")
    result = json.loads(capsys.readouterr().out)
    assert result == {
        "messages": [
            {"id": "gmail:100:3", "account": "gmail"},
            {"id": "gmail:100:2", "account": "gmail"},
            {"id": "gmail:100:1", "account": "gmail"},
        ],
        "errors": [],
    }


def test_failed_read_is_reported(inbox):
    inbox.failed_uid = "2"
    result = mailbox.list_mail()
    assert result["messages"] == []
    assert "邮件 2 读取失败" in result["errors"][0]


def test_missing_credential_is_reported_without_connecting(tmp_path, monkeypatch):
    monkeypatch.setenv("HERMES_HOME", str(tmp_path))
    monkeypatch.setattr(
        mailbox.config,
        "load",
        lambda: {"mail": [{"id": "gmail", "host": "imap.gmail.com", "address": "x"}]},
    )
    result = mailbox.list_mail()
    assert result["messages"] == []
    assert "尚未配置" in result["errors"][0]
