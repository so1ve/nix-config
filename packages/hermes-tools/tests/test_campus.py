import json
from http.cookiejar import MozillaCookieJar

import pytest
import requests

from hermes_personal import campus


def test_busy_session_does_not_wait(tmp_path, monkeypatch):
    monkeypatch.setenv("HERMES_HOME", str(tmp_path))
    with campus.session(), pytest.raises(campus.CampusBusy), campus.session():
        pytest.fail("session should not be re-entered")


@pytest.fixture
def yanhekt_session(tmp_path, monkeypatch):
    monkeypatch.setenv("HERMES_HOME", str(tmp_path))
    token = "eyJhbGciOiJub25lIn0.eyJzdWIiOiJ0ZXN0In0.signature"

    def get(client, url, **kwargs):
        response = requests.Response()
        response.status_code = 200
        response.url = url
        if url.endswith("/userapi/v1/infosimple"):
            accepted = kwargs["headers"]["Authorization"] == "Bearer " + token
            response._content = json.dumps({"code": 200 if accepted else 401}).encode()
        else:
            assert url == campus.YANHEKIT + "/casapi/index.php"
            assert kwargs["params"]["auType"] == ""
        return response

    monkeypatch.setattr(requests.Session, "get", get)
    return token


def test_login_exposes_verification_and_exports_native_cookie(
    tmp_path, monkeypatch, yanhekt_session
):
    with campus.session() as client:
        client.cookies.set(
            "_token", "eyJhbGciOiJub25lIn0.expired.signature", domain=".yanhekt.cn", path="/"
        )

    def authenticate(client, url, sms_callback):
        if "/course" in url:
            assert sms_callback(type("Context", (), {"masked_phone": "138****0000"})()) == "123456"
            client.cookies.set("_token", yanhekt_session, domain=".yanhekt.cn", path="/")
        return object()

    monkeypatch.setattr(campus, "open_service", authenticate)
    login = campus.CampusLogin()
    assert login.start()["status"] == "verification_required"
    assert login.submit("123456")["status"] == "authenticated"
    assert "123456" not in str(login.status())
    assert yanhekt_session not in str(login.status())
    cookies = MozillaCookieJar(tmp_path / ".config/yanhekit/cookies.txt")
    cookies.load(ignore_discard=True)
    assert next(cookie.value for cookie in cookies if cookie.name == "_token") == yanhekt_session
    assert (tmp_path / ".config/yanhekit/cookies.txt").stat().st_mode & 0o777 == 0o600


def test_login_reuses_accepted_yanhekt_cookie(monkeypatch, yanhekt_session):
    with campus.session() as client:
        client.cookies.set("_token", yanhekt_session, domain=".yanhekt.cn", path="/")

    def unexpected_login(*args, **kwargs):
        pytest.fail("an accepted Yanhekt session must not initiate another login")

    monkeypatch.setattr(campus, "open_service", unexpected_login)
    assert campus.CampusLogin().start()["status"] == "authenticated"


@pytest.mark.parametrize(
    ("service", "url"),
    [("lexue", campus.LEXUE + "/my/"), ("eclass", campus.ECLASS + "/user/courses")],
)
def test_learning_login_does_not_require_yanhekt(monkeypatch, yanhekt_session, service, url):
    def open_lexue(client, target, sms_callback):
        assert target == url
        return object()

    monkeypatch.setattr(campus, "open_service", open_lexue)
    assert campus.CampusLogin().start(service) == {
        "status": "authenticated",
        "service": service,
    }


def test_cas_success_without_accepted_yanhekt_token_is_not_authenticated(
    monkeypatch, yanhekt_session
):
    monkeypatch.setattr(campus, "open_service", lambda *args, **kwargs: object())
    result = campus.CampusLogin().start()
    assert result["status"] == "error"
    assert "延河课堂未接受" in result["error"]
