"""BIT SSO session, cookie persistence and conversational SMS challenge."""

import fcntl
import json
import os
import re
from contextlib import contextmanager
from http.cookiejar import MozillaCookieJar
from pathlib import Path
from queue import Empty, Queue
from threading import Condition, Thread
from urllib.parse import parse_qs, unquote, urlsplit

from .config import home

YANHEKIT = "https://aita.yanhekt.cn"
LEXUE = "https://lexue.bit.edu.cn"


class VerificationRequired(RuntimeError):
    """The user must supply the code sent to the bound phone."""


class CampusBusy(RuntimeError):
    """One campus request is already using the shared session."""


def _cookies() -> Path:
    return home() / ".config/hermes-personal/campus.cookies"


def _save_cookies(client):
    targets = (_cookies(), home() / ".config/yanhekit/cookies.txt")
    for target in targets:
        target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        jar = MozillaCookieJar(target)
        for cookie in client.cookies:
            jar.set_cookie(cookie)
        jar.save(ignore_discard=True, ignore_expires=True)
        target.chmod(0o600)


@contextmanager
def session():
    lock_path = home() / ".config/hermes-personal/campus.lock"
    lock_path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with lock_path.open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise CampusBusy("校园登录正在处理，先查看现有验证状态") from error

        import requests

        cookies = MozillaCookieJar(_cookies())
        if _cookies().exists():
            cookies.load(ignore_discard=True)
        with requests.Session() as client:
            client.cookies.update(cookies)
            client.headers["User-Agent"] = "Mozilla/5.0"
            try:
                yield client
            finally:
                _save_cookies(client)


def _credentials() -> tuple[str, str]:
    path = Path(os.environ.get("BIT_CREDENTIALS", "/run/hermes/campus.json"))
    value = json.loads(path.read_text())
    return value["username"], value["password"]


def open_service(client, url, sms_callback=None):
    from bit_login.sso import BitSsoClient
    from bit_login.sso.exceptions import BitSsoError

    response = client.get(url, timeout=45)
    response.raise_for_status()
    location = urlsplit(response.url)
    if location.hostname != "sso.bit.edu.cn":
        return response

    service = parse_qs(location.query).get("service", [None])[0]
    if not service:
        raise RuntimeError("校园服务没有提供 CAS 回调地址")
    callback_host = urlsplit(service).hostname or ""
    if not callback_host.endswith((".bit.edu.cn", ".yanhekt.cn")):
        raise ValueError("校园服务的 CAS 回调域名不匹配")

    username, password = _credentials()
    try:
        result = BitSsoClient(session=client, timeout=60).login_password(
            username,
            password,
            service=service,
            sms_code_callback=sms_callback,
            trust_device=True,
        )
    except BitSsoError as error:
        raise RuntimeError("北理工自动认证失败：" + type(error).__name__) from error
    result.response.raise_for_status()
    return result.response


def _yanhekt_authenticated(client):
    token = next(
        (
            cookie.value
            for cookie in client.cookies
            if cookie.name == "_token"
            and cookie.domain.lstrip(".") in {"yanhekt.cn", "aita.yanhekt.cn"}
        ),
        "",
    )
    jwt = re.search(r"eyJ[\w-]+\.[\w-]+\.[\w-]+", unquote(token))
    if not jwt:
        return False
    response = client.get(
        YANHEKIT + "/userapi/v1/infosimple",
        headers={"Authorization": "Bearer " + jwt[0]},
        timeout=45,
    )
    if response.status_code in {401, 403}:
        return False
    response.raise_for_status()
    return response.json().get("code") == 200


class CampusLogin:
    """Keep one live CAS request open while Hermes asks for the SMS code."""

    def __init__(self):
        self.condition = Condition()
        self.state = {"status": "idle"}
        self.codes = Queue(maxsize=1)

    def status(self) -> dict:
        with self.condition:
            return dict(self.state)

    def start(self, service: str = "yanhekt") -> dict:
        assert service in {"yanhekt", "lexue"}
        with self.condition:
            if self.state["status"] in {"starting", "verification_required", "verifying"}:
                return dict(self.state)
            self.codes = Queue(maxsize=1)
            self.state = {"status": "starting", "service": service}
            Thread(target=self._login, args=(service,), daemon=True, name="campus-login").start()
            self.condition.wait_for(lambda: self.state["status"] != "starting", timeout=20)
            return dict(self.state)

    def submit(self, code: str) -> dict:
        code = code.strip()
        if not code.isascii() or not code.isdigit() or len(code) != 6:
            raise ValueError("验证码应为短信中的六位数字")
        with self.condition:
            if self.state["status"] != "verification_required":
                raise ValueError("当前没有等待验证码的登录")
            self.state = {"status": "verifying", "service": self.state["service"]}
            self.codes.put_nowait(code)
            self.condition.wait_for(lambda: self.state["status"] != "verifying", timeout=20)
            return dict(self.state)

    def _set(self, **state):
        with self.condition:
            self.state = {"service": self.state["service"], **state}
            self.condition.notify_all()

    def _verification(self, context):
        self._set(status="verification_required", masked_phone=context.masked_phone)
        try:
            return self.codes.get(timeout=300)
        except Empty as error:
            raise VerificationRequired("短信验证已超时，可以重新发起") from error

    def _login(self, service):
        try:
            with session() as client:
                if service == "lexue":
                    open_service(client, LEXUE + "/my/", sms_callback=self._verification)
                elif not _yanhekt_authenticated(client):
                    # Follow Yanhekt's sign-in entry before CAS so its callback issues _token.
                    client.get(
                        YANHEKIT + "/casapi/index.php",
                        params={
                            "r": "auth/login",
                            "auType": "",
                            "tenant_code": 21,
                            "forward": YANHEKIT + "/course",
                        },
                        allow_redirects=False,
                        timeout=45,
                    ).raise_for_status()
                    open_service(
                        client,
                        YANHEKIT
                        + "/casapi/index.php?r=auth/login&auType=cas&tenant_code=21&forward="
                        + YANHEKIT
                        + "/course",
                        sms_callback=self._verification,
                    )
                    if not _yanhekt_authenticated(client):
                        raise RuntimeError("延河课堂未接受校园登录会话，请重新认证")
        except Exception as error:  # noqa: BLE001 - the thread must always publish a terminal state
            message = (
                f"{type(error).__name__}: {error}"
                if isinstance(error, (KeyError, RuntimeError, ValueError))
                else type(error).__name__
            )
            self._set(status="error", error=message)
        else:
            self._set(status="authenticated")
