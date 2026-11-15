"""Read-only IMAP retrieval. No cursor, read flags, deletion or replies."""

import imaplib
import re
import ssl
from datetime import UTC, datetime, timedelta
from email import policy
from email.parser import BytesParser
from html import unescape

from . import config


def _text(raw: bytes) -> dict:
    message = BytesParser(policy=policy.default).parsebytes(raw)
    part = message.get_body(preferencelist=("plain", "html"))
    body = part.get_content() if part else ""
    if not isinstance(body, str):
        body = ""
    if part and part.get_content_type() == "text/html":
        body = re.sub(r"(?is)<(script|style)\b.*?</\1>", "", body)
        body = unescape(re.sub(r"<[^>]+>", " ", body))
    return {
        "from": str(message.get("From", "")),
        "subject": str(message.get("Subject", "")),
        "date": str(message.get("Date", "")),
        "body": " ".join(body.split())[:6000],
        "list_id": str(message.get("List-ID", "")),
        "github_reason": str(message.get("X-GitHub-Reason", "")),
    }


def _account(account: dict, limit: int, *, include_content: bool) -> tuple[list[dict], str | None]:
    credential = config.mail_credentials_dir() / account["id"]
    if not credential.is_file():
        return [], f"{account['id']} 尚未配置授权码"

    since = (datetime.now(UTC) - timedelta(days=7)).strftime("%d-%b-%Y")
    with imaplib.IMAP4_SSL(
        account["host"], 993, ssl_context=ssl.create_default_context(), timeout=30
    ) as mailbox:
        mailbox.login(account["address"], credential.read_text().strip())
        if account["host"] == "imap.163.com":
            mailbox.xatom("ID", '("name" "Hermes" "version" "1.0" "vendor" "personal")')
        status, _ = mailbox.select("INBOX", readonly=True)
        if status != "OK":
            raise RuntimeError(f"{account['id']} 无法只读打开收件箱")
        validity = mailbox.response("UIDVALIDITY")[1][0].decode()
        status, data = mailbox.uid("search", None, f'UNSEEN SINCE "{since}"')
        if status != "OK":
            raise RuntimeError(f"{account['id']} 邮箱搜索失败")
        uids = sorted((int(value) for value in data[0].split()), reverse=True)[:limit]
        messages = []
        for uid in uids:
            message = {"id": f"{account['id']}:{validity}:{uid}", "account": account["id"]}
            if include_content:
                status, chunks = mailbox.uid("fetch", str(uid), "(BODY.PEEK[]<0.65536>)")
                raw = next((chunk[1] for chunk in chunks or [] if isinstance(chunk, tuple)), None)
                if status != "OK" or raw is None:
                    raise RuntimeError(f"{account['id']} 邮件 {uid} 读取失败")
                message.update(_text(raw))
            messages.append(message)
        return messages, None


def list_mail(limit: int = 20, *, include_content: bool = True) -> dict:
    messages, errors = [], []
    for account in config.load().get("mail", []):
        try:
            found, error = _account(
                account, max(1, min(limit, 50)), include_content=include_content
            )
        except (OSError, imaplib.IMAP4.error, RuntimeError, ValueError) as caught:
            errors.append(f"{account['id']}: {type(caught).__name__}: {caught}")
        else:
            messages.extend(found)
            if error:
                errors.append(error)
    return {"messages": messages, "errors": errors}
