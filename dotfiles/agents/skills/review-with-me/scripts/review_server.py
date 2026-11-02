"""Loopback UI, live updates, and immediate delivery to the bound Codex chat."""

import fcntl
import gzip
import hmac
import json
import mimetypes
import os
import secrets
import shlex
import shutil
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from subprocess import run
from urllib.parse import parse_qs, unquote, urlparse

from review_model import mutate, read, transaction, view

WEB = Path(__file__).with_name("web")


def deliver(path):
    state = read(path)
    listener = state["listener"]
    if not listener["enabled"]:
        return
    waiting = [
        m["id"]
        for t in state["threads"]
        if t["status"] == "open"
        for m in t["messages"]
        if m.get("delivery") == "queued"
    ]
    if not waiting:
        return
    cli = os.environ.get("CODEX_CLI_PATH") or shutil.which("codex")
    command = f"python3 {shlex.quote(str(Path(__file__).with_name('review.py').resolve()))} inbox --state {shlex.quote(str(path))} --claim"
    message = (
        f"[Review With Me] 新的审阅反馈已保存，仓库：{state['repo']}。\n"
        f"请从该仓库运行 {command}。\n"
        "先检查监听状态；已暂停则停止。仅处理本次认领的消息，读取标注版本与当前源码，"
        "回复问题或完成修改；修改后 capture 新版本，再 reply。不要把用户的通过范围扩大。"
    )
    error = ""
    try:
        if not cli:
            raise OSError("找不到 codex 命令，请让 Agent 检查本地连接")
        result = run(
            [cli, "queue", "--thread", listener["thread_id"], "--message", message],
            cwd=state["repo"],
            capture_output=True,
            text=True,
            timeout=20,
            check=False,
        )
        if result.returncode:
            error = (result.stderr or result.stdout).strip() or "Codex 未接受反馈"
    except (OSError, subprocess.TimeoutExpired) as exc:
        error = str(exc)
    with transaction(path) as current:
        current["listener"]["error"] = error
        for note in current["threads"]:
            for item in note["messages"]:
                if item["id"] in waiting and item.get("delivery") == "queued":
                    item.update(
                        delivery="failed" if error else "delivered", error=error
                    )


class Server(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, path, port=0):
        super().__init__(("127.0.0.1", port), Handler)
        self.path = path
        self.token = secrets.token_urlsafe(32)
        self.url = f"http://127.0.0.1:{self.server_port}"
        self.stop = threading.Event()
        self.changed = threading.Condition()
        self.sequence = 0

    def watch(self):
        signature = None
        while not self.stop.wait(0.2):
            try:
                current = Path(self.path).stat().st_mtime_ns
                if current != signature:
                    signature = current
                    with self.changed:
                        self.sequence += 1
                        self.changed.notify_all()
            except OSError:
                # The next request reports the concrete read failure to the client.
                with self.changed:
                    self.sequence += 1
                    self.changed.notify_all()

    def delivery_loop(self):
        while not self.stop.is_set():
            try:
                deliver(self.path)
            except (OSError, ValueError) as exc:
                print(f"Feedback delivery: {exc}", flush=True)
            with self.changed:
                self.changed.wait(timeout=1)


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *_):
        pass

    def boundary(self, mutation=False):
        hosts = {
            f"127.0.0.1:{self.server.server_port}",
            f"localhost:{self.server.server_port}",
        }
        if self.headers.get("Host") not in hosts:
            raise PermissionError("不允许从该主机访问")
        origin = self.headers.get("Origin")
        if origin and origin not in {f"http://{host}" for host in hosts}:
            raise PermissionError("不允许跨站访问")
        if mutation and not hmac.compare_digest(
            self.headers.get("X-Review-Token", ""), self.server.token
        ):
            raise PermissionError("页面会话已过期，请刷新后重试")

    def send_headers(self, status, kind, length=None, encoding=None):
        self.send_response(status)
        for key, value in {
            "Content-Type": kind,
            "Cache-Control": "no-store",
            "X-Content-Type-Options": "nosniff",
            "Referrer-Policy": "no-referrer",
            "X-Frame-Options": "DENY",
            "Content-Security-Policy": "default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'; frame-ancestors 'none'",
        }.items():
            self.send_header(key, value)
        if length is not None:
            self.send_header("Content-Length", str(length))
        if encoding:
            self.send_header("Content-Encoding", encoding)
            self.send_header("Vary", "Accept-Encoding")
        self.end_headers()

    def send(
        self, data, kind="application/json; charset=utf-8", status=200, encoding=None
    ):
        if not isinstance(data, bytes):
            data = json.dumps(data, ensure_ascii=False).encode()
        self.send_headers(status, kind, len(data), encoding)
        self.wfile.write(data)

    def failure(self, exc):
        self.close_connection = True
        self.send(
            {"error": str(exc)}, status=403 if isinstance(exc, PermissionError) else 400
        )

    def do_GET(self):
        try:
            self.boundary()
            url = urlparse(self.path)
            query = parse_qs(url.query)
            if url.path == "/":
                self.send(
                    (WEB / "index.html")
                    .read_text()
                    .replace("__REVIEW_TOKEN__", self.server.token)
                    .encode(),
                    "text/html; charset=utf-8",
                )
            elif url.path.startswith("/assets/"):
                name = unquote(url.path.removeprefix("/"))
                file = WEB / name
                if not file.resolve().is_relative_to((WEB / "assets").resolve()):
                    raise PermissionError("无效资源路径")
                kind = mimetypes.guess_type(str(file))[0] or "application/octet-stream"
                compressed = Path(str(file) + ".gz")
                if compressed.is_file():
                    data = compressed.read_bytes()
                    use_gzip = "gzip" in self.headers.get("Accept-Encoding", "")
                    self.send(
                        data if use_gzip else gzip.decompress(data),
                        kind,
                        encoding="gzip" if use_gzip else None,
                    )
                else:
                    self.send(file.read_bytes(), kind)
            elif url.path == "/api/state":
                self.send(
                    view(
                        read(self.server.path),
                        query.get("revision", [None])[0],
                        query.get("against", ["base"])[0],
                    )
                )
            elif url.path == "/api/file":
                data = view(
                    read(self.server.path),
                    query.get("revision", [None])[0],
                    query.get("against", ["base"])[0],
                    with_text=True,
                )
                file = next(
                    (
                        f
                        for f in data["files"]
                        if f["path"] == query.get("path", [None])[0]
                    ),
                    None,
                )
                if file is None:
                    raise ValueError("找不到文件")
                self.send(file)
            elif url.path == "/api/events":
                self.events()
            else:
                self.send({"error": "找不到页面"}, status=404)
        except (ValueError, OSError, KeyError, TypeError) as exc:
            self.failure(exc)

    def events(self):
        self.send_headers(200, "text/event-stream")
        sequence = -1
        try:
            while not self.server.stop.is_set():
                with self.server.changed:
                    if sequence == self.server.sequence:
                        self.server.changed.wait(timeout=15)
                    sequence = self.server.sequence
                self.wfile.write(f"data: {sequence}\n\n".encode())
                self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            pass
        finally:
            self.close_connection = True

    def do_POST(self):
        try:
            self.boundary(mutation=True)
            if self.path != "/api/action":
                raise ValueError("未知操作地址")
            if self.headers.get("Content-Type", "").split(";")[0] != "application/json":
                raise ValueError("需要 JSON 请求")
            length = int(self.headers.get("Content-Length", "0"))
            if not 0 < length <= 2_000_000:
                raise ValueError("请求为空或超过 2 MB")
            action = json.loads(self.rfile.read(length))
            results = mutate(self.server.path, action, actor="user")
            with self.server.changed:
                self.server.sequence += 1
                self.server.changed.notify_all()
            self.send({"results": results})
        except (ValueError, OSError, KeyError, TypeError) as exc:
            self.failure(exc)


def serve(path, port=0):
    read(path)
    with Path(str(path) + ".server.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            lock.seek(0)
            print(lock.read().strip(), flush=True)
            return
        server = Server(path, port)
        lock.seek(0)
        lock.truncate()
        lock.write(server.url + "\n")
        lock.flush()
        threading.Thread(target=server.watch, daemon=True).start()
        threading.Thread(target=server.delivery_loop, daemon=True).start()
        print(f"Review frontend: {server.url}", flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass
        finally:
            server.stop.set()
            with server.changed:
                server.changed.notify_all()
            server.server_close()
