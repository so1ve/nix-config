"""Behavior tests use an isolated clone of existing history, never new commits."""

import http.client
import json
import os
import subprocess
import sys
import tempfile
import threading
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
from review_git import git, repository
from review_model import inbox, initialize, mutate, read, view
from review_server import Server, deliver


class ReviewFixture(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = repository(SCRIPTS)

    def setUp(self):
        self.original_cwd = Path.cwd()
        self.temporary = tempfile.TemporaryDirectory(prefix="review-with-me-test-")
        self.repo = Path(self.temporary.name)
        git(self.repo, "clone", "--shared", "--no-checkout", self.source, ".")
        git(self.repo, "checkout", "HEAD", "--", "README.md")
        os.chdir(self.repo)
        self.state = ".review/test.json"
        initialize(
            self.state,
            "测试审阅",
            "HEAD",
            ["case.py", "other.py", "README.md", "binary.dat", "link"],
        )
        Path("case.py").write_text("def greet(name):\n    return 'Hello ' + name\n")
        Path("other.py").write_text("enabled = True\n")
        self.capture()

    def tearDown(self):
        os.chdir(self.original_cwd)
        self.temporary.cleanup()

    def capture(self, **values):
        return mutate(self.state, {"op": "capture", "label": "修改", **values})[0]

    def act(self, op, actor="agent", **fields):
        return mutate(self.state, {"op": op, **fields}, actor=actor)[0]

    def note(self, **fields):
        return self.act(
            "comment",
            actor="user",
            body="为什么这样写？",
            targets=[{"path": "case.py", "side": "new", "start": 2}],
            **fields,
        )

    def listen(self):
        self.act("listen", thread_id="test-thread", enabled=True)


class ReviewTest(ReviewFixture):
    def test_legacy_import_preserves_source_comments_and_decisions(self):
        from review_import import import_legacy

        head = git(self.repo, "rev-parse", "HEAD").decode().strip()
        legacy = {
            "version": 3,
            "goal": "旧审阅",
            "base": head,
            "changes": [
                {
                    "id": "docs",
                    "title": "文档",
                    "paths": ["README.md"],
                    "revisions": [
                        {"id": "r1", "label": "原始版本", "base": head, "head": head}
                    ],
                    "annotations": [
                        {
                            "id": "a1",
                            "revision_id": "r1",
                            "path": "README.md",
                            "side": "new",
                            "start_line": 1,
                            "end_line": 1,
                            "body": "解释这里",
                            "author": "user",
                            "replies": [{"body": "这是项目简介", "author": "agent"}],
                            "status": "resolved",
                        }
                    ],
                    "decisions": [
                        {
                            "revision_id": "r1",
                            "path": "README.md",
                            "scope": "file",
                            "status": "accepted",
                            "author": "user",
                        }
                    ],
                }
            ],
        }
        Path(".review/legacy.json").write_text(json.dumps(legacy))
        source = Path(".review/legacy.json").read_bytes()
        result = import_legacy(".review/legacy.json", ".review/imported.json")
        imported = read(".review/imported.json")
        self.assertEqual(result["threads"], 1)
        self.assertEqual(imported["threads"][0]["targets"][0]["start"], 1)
        self.assertEqual(imported["threads"][0]["messages"][1]["body"], "这是项目简介")
        self.assertEqual(view(imported)["files"][0]["review_status"], "accepted")
        self.assertEqual(Path(".review/legacy.json").read_bytes(), source)
        self.assertFalse(imported["listener"]["enabled"])

    def test_arbitrary_region_decisions_do_not_approve_unselected_code(self):
        region = {"path": "case.py", "side": "new", "start": 1, "end": 1}
        self.act("decide", actor="user", targets=[region], status="accepted")

        def status():
            return next(
                f for f in view(read(self.state))["files"] if f["path"] == "case.py"
            )["review_status"]

        self.assertEqual(status(), "pending")
        self.act(
            "decide",
            actor="user",
            targets=[{**region, "start": 2, "end": 2}],
            status="accepted",
        )
        self.assertEqual(status(), "accepted")
        self.act("decide", actor="user", targets=[region], status="pending")
        self.assertEqual(status(), "pending")
        block = next(
            f for f in view(read(self.state))["files"] if f["path"] == "case.py"
        )["blocks"][0]["id"]
        self.act("decide", actor="user", path="case.py", block=block, status="accepted")
        self.assertEqual(status(), "accepted")
        self.act("decide", actor="user", targets=[region], status="pending")
        self.assertEqual(status(), "pending")

    def test_binary_same_size_changes_are_not_treated_as_same_revision(self):
        Path("binary.dat").write_bytes(b"\0abc")
        first = self.capture()
        Path("binary.dat").write_bytes(b"\0xyz")
        self.assertNotEqual(self.capture(), first)

    def test_capture_preserves_git_and_old_code_and_invalidates_changed_file_only(self):
        before_refs = git(self.repo, "show-ref")
        before_index = Path(".git/index").read_bytes()
        self.act(
            "decide", actor="user", paths=["case.py", "other.py"], status="accepted"
        )
        Path("case.py").write_text("def greet(name):\n    return f'Hi {name}'\n")
        self.assertEqual(self.capture(), "r2")
        self.assertEqual(git(self.repo, "show-ref"), before_refs)
        self.assertEqual(Path(".git/index").read_bytes(), before_index)
        state = read(self.state)
        self.assertIn("Hello", state["revisions"][0]["files"]["case.py"]["new"]["text"])
        files = {f["path"]: f for f in view(state)["files"]}
        self.assertEqual(files["case.py"]["review_status"], "pending")
        self.assertEqual(files["other.py"]["review_status"], "accepted")
        delta = view(state, "r2", "r1", with_text=True)["files"]
        self.assertEqual([f["path"] for f in delta], ["case.py"])
        self.assertIn("Hello", delta[0]["old"]["text"])
        self.assertEqual(self.capture(), "r2")

    def test_file_block_and_exclusion_decisions_and_reopening(self):
        file = next(
            f for f in view(read(self.state))["files"] if f["path"] == "case.py"
        )
        block = file["blocks"][0]["id"]
        self.act("decide", actor="user", path="case.py", block=block, status="accepted")
        self.assertEqual(
            next(f for f in view(read(self.state))["files"] if f["path"] == "case.py")[
                "review_status"
            ],
            "accepted",
        )
        self.act(
            "decide", path="case.py", status="excluded", reason="由调用路径一并解释"
        )
        self.assertEqual(
            next(f for f in view(read(self.state))["files"] if f["path"] == "case.py")[
                "review_status"
            ],
            "excluded",
        )
        self.act("decide", path="case.py", status="pending")
        with self.assertRaises(ValueError):
            self.act("decide", path="case.py", status="accepted")
        self.act(
            "decide", path="case.py", status="accepted", reason="用户要求通过此文件"
        )

    def test_capture_carries_unchanged_hunks_without_widening_review_scope(self):
        original = Path("README.md").read_text().splitlines(keepends=True)
        edited = original.copy()
        edited[2] = "approved change\n"
        edited[6] = "excluded change\n"
        edited[10] = "partly reviewed\nreopened line\n"
        edited[14] = "will change again\n"
        Path("README.md").write_text("".join(edited))
        old_revision = self.capture()
        old_file = view(read(self.state), with_text=True)["files"][0]
        self.assertEqual(old_file["path"], "README.md")
        old_blocks = old_file["blocks"]
        self.assertEqual(len(old_blocks), 4)
        self.act("decide", actor="user", path="README.md", status="accepted")
        self.act(
            "decide",
            actor="user",
            path="README.md",
            block=old_blocks[1]["id"],
            status="excluded",
            reason="不在这轮范围",
        )
        self.act(
            "decide",
            actor="user",
            targets=[
                {
                    "path": "README.md",
                    "side": "new",
                    "start": old_blocks[2]["new_start"] + 1,
                }
            ],
            status="pending",
        )
        self.act(
            "group",
            id="docs",
            title="文档",
            paths=["README.md"],
            checks=[{"id": "docs-check", "text": "内容一致"}],
        )
        self.act("check", id="docs-check", status="passed", reason="已核对")
        prior_decision = read(self.state)["revisions"][-1]["decisions"]["README.md"]

        edited[14] = "changed again\n"
        edited[17] = (
            "approved change\n"  # Same text at another base location is new work.
        )
        Path("README.md").write_text("new heading\n" + "".join(edited))
        self.capture()
        state = read(self.state)
        current = view(state)["files"][0]
        self.assertEqual(
            [b["review_status"] for b in current["blocks"]],
            ["pending", "accepted", "excluded", "pending", "pending", "pending"],
        )
        self.assertEqual(current["review_status"], "pending")
        decision = current["decision"]
        self.assertEqual(
            decision["blocks"][current["blocks"][2]["id"]]["reason"], "不在这轮范围"
        )
        self.assertEqual(
            decision["regions"],
            [
                {
                    "side": "new",
                    "start": old_blocks[2]["new_start"] + 2,
                    "end": old_blocks[2]["new_start"] + 2,
                    "status": "pending",
                    "reason": "",
                    "by": "user",
                }
            ],
        )
        self.assertEqual(
            view(state, old_revision)["files"][0]["decision"], prior_decision
        )
        self.assertNotIn("docs-check", view(state)["checks"])

    def test_capture_preserves_partial_regions_only_inside_unchanged_hunks(self):
        original = Path("README.md").read_text().splitlines(keepends=True)
        original[2] = "first new line\nsecond new line\n"
        original[10] = "another change\n"
        Path("README.md").write_text("".join(original))
        self.capture()
        block = view(read(self.state))["files"][0]["blocks"][0]
        self.act(
            "decide",
            actor="user",
            targets=[
                {
                    "path": "README.md",
                    "side": "new",
                    "start": block["new_start"],
                }
            ],
            status="accepted",
        )
        original[10] = "another revised change\n"
        Path("README.md").write_text("shift\n" + "".join(original))
        self.capture()
        current = view(read(self.state))["files"][0]
        self.assertTrue(all(b["review_status"] == "pending" for b in current["blocks"]))
        self.assertEqual(
            current["decision"]["regions"],
            [
                {
                    "side": "new",
                    "start": block["new_start"] + 1,
                    "end": block["new_start"] + 1,
                    "status": "accepted",
                    "reason": "",
                    "by": "user",
                }
            ],
        )

    def test_capture_resets_acceptance_when_file_mode_changes(self):
        self.act("decide", actor="user", path="case.py", status="accepted")
        Path("case.py").chmod(0o755)
        self.capture()
        current = next(
            f for f in view(read(self.state))["files"] if f["path"] == "case.py"
        )
        self.assertEqual(current["review_status"], "pending")

    def test_multi_target_drawing_and_exact_excerpt_survive_round_trip(self):
        target = {
            "path": "case.py",
            "side": "new",
            "start": 2,
            "end": 2,
            "quote": "name",
            "drawing": {"points": [[0.1, 0.2], [0.8, 0.9]], "width": 800},
        }
        key = self.act(
            "comment",
            actor="user",
            body="这两处一起改",
            targets=[target, {"path": "other.py", "side": "file"}],
            suggestion="return name",
        )
        note = read(self.state)["threads"][0]
        self.assertEqual(note["targets"][0], target)
        self.assertEqual(note["id"], key)
        self.assertEqual(len(note["targets"]), 2)
        for invalid in [
            {**target, "end": 90},
            {**target, "quote": "不存在"},
            {**target, "path": "../private"},
            {**target, "drawing": {"points": [[float("nan"), 0], [1, 1]]}},
        ]:
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                self.act("comment", body="wrong", targets=[invalid])
        self.assertEqual(len(read(self.state)["threads"]), 1)

    def test_feedback_workflow_claim_reply_race_and_resolution(self):
        self.listen()
        key = self.note()
        event = inbox(self.state, claim=True)[0]
        self.assertEqual(event["thread"], key)
        self.assertEqual(inbox(self.state, claim=True), [])
        self.act("reply", actor="user", id=key, body="还有这里")
        with self.assertRaises(ValueError):
            self.act("reply", id=key, body="完成", resolve=True)
        self.act("reply", id=key, body="先回答第一个问题")
        messages = read(self.state)["threads"][0]["messages"]
        self.assertEqual(messages[0]["delivery"], "answered")
        self.assertEqual(messages[1]["delivery"], "queued")
        inbox(self.state, claim=True)
        self.act("reply", id=key, body="第二处也已处理", resolve=True)
        self.act("decide", actor="user", path="case.py", status="accepted")
        self.assertEqual(inbox(self.state), [])

    def test_old_unresolved_comment_blocks_new_acceptance(self):
        self.note()
        Path("case.py").write_text("changed = True\n")
        self.capture()
        with self.assertRaisesRegex(ValueError, "未解决"):
            self.act("decide", actor="user", path="case.py", status="accepted")
        self.assertEqual(read(self.state)["threads"][0]["revision"], "r1")

    def test_batch_is_atomic_and_groups_have_independent_requirements(self):
        with self.assertRaises(ValueError):
            mutate(
                self.state,
                [
                    {
                        "op": "group",
                        "id": "auth",
                        "title": "认证",
                        "paths": ["case.py"],
                    },
                    {"op": "decide", "path": "missing", "status": "pending"},
                ],
            )
        self.assertEqual(read(self.state)["groups"], [])
        self.act(
            "group",
            id="auth",
            title="认证",
            paths=["case.py"],
            checks=[{"id": "empty", "text": "空输入保持原行为"}],
        )
        self.act(
            "check", id="empty", status="passed", reason="检查了空输入的实际返回值"
        )
        Path("case.py").write_text("changed = 2\n")
        self.capture()
        self.assertEqual(view(read(self.state))["checks"], {})
        self.assertEqual(
            read(self.state)["groups"][0]["checks"][0]["text"], "空输入保持原行为"
        )

    def test_comments_on_comparison_anchor_to_the_displayed_old_side(self):
        Path("case.py").write_text("new = 2\n")
        self.capture()
        key = self.act(
            "comment",
            actor="user",
            revision="r2",
            against="r1",
            targets=[{"path": "case.py", "side": "old", "start": 2}],
            body="这里原来做了什么",
        )
        note = next(t for t in read(self.state)["threads"] if t["id"] == key)
        self.assertIn("Hello", note["targets"][0]["quote"])
        self.assertEqual(note["against"], "r1")

    def test_paused_feedback_is_saved_and_delivered_once_on_resume(self):
        self.note()
        self.assertEqual(inbox(self.state, claim=True), [])
        with patch("review_server.run") as run:
            deliver(self.state)
            run.assert_not_called()
            self.listen()
            run.return_value = subprocess.CompletedProcess([], 0, "", "")
            deliver(self.state)
            deliver(self.state)
            self.assertEqual(run.call_count, 1)
            self.assertIn("queue", run.call_args.args[0])
            self.assertIn("test-thread", run.call_args.args[0])
        self.assertEqual(
            read(self.state)["threads"][0]["messages"][0]["delivery"], "delivered"
        )

    def test_failed_delivery_is_visible_and_retry_is_explicit(self):
        self.listen()
        key = self.note()
        with patch(
            "review_server.run",
            return_value=subprocess.CompletedProcess([], 1, "", "app unavailable"),
        ) as run:
            deliver(self.state)
            deliver(self.state)
            self.assertEqual(run.call_count, 1)
        self.assertEqual(read(self.state)["listener"]["error"], "app unavailable")
        self.act("retry", id=key)
        with patch(
            "review_server.run", return_value=subprocess.CompletedProcess([], 0, "", "")
        ):
            deliver(self.state)
        self.assertEqual(read(self.state)["listener"]["error"], "")

    def test_concurrent_cli_writes_do_not_lose_comments(self):
        processes = [
            subprocess.Popen(
                [
                    sys.executable,
                    str(SCRIPTS / "review.py"),
                    "apply",
                    "--state",
                    self.state,
                    "--json",
                    json.dumps(
                        {
                            "op": "comment",
                            "body": f"comment {i}",
                            "targets": [{"path": "case.py", "side": "file"}],
                        }
                    ),
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            for i in range(4)
        ]
        for process in processes:
            _, error = process.communicate(timeout=10)
            self.assertEqual(process.returncode, 0, error)
        self.assertEqual(len(read(self.state)["threads"]), 4)

    def test_deleted_files_context_files_symlinks_and_binary_are_reviewable(self):
        Path("README.md").unlink()
        Path("link").symlink_to("/etc/passwd")
        Path("binary.dat").write_bytes(b"\0\xff\x00")
        self.capture()
        files = {f["path"]: f for f in view(read(self.state), with_text=True)["files"]}
        self.assertEqual(files["README.md"]["status"], "deleted")
        self.assertEqual(files["link"]["new"]["text"], "/etc/passwd")
        self.assertIsNone(files["binary.dat"]["new"]["text"])
        git(self.repo, "checkout", "HEAD", "--", "README.md")
        self.capture(include=["README.md"])
        self.assertEqual(
            read(self.state)["revisions"][-1]["files"]["README.md"]["status"], "context"
        )


class HTTPTest(ReviewFixture):
    def setUp(self):
        super().setUp()
        self.server = Server(self.state)
        self.serving = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.serving.start()
        self.watching = threading.Thread(target=self.server.watch, daemon=True)
        self.watching.start()

    def tearDown(self):
        self.server.stop.set()
        with self.server.changed:
            self.server.changed.notify_all()
        self.server.shutdown()
        self.server.server_close()
        self.watching.join(timeout=2)
        super().tearDown()

    def request(self, method, path, body=None, headers=None):
        connection = http.client.HTTPConnection(
            "127.0.0.1", self.server.server_port, timeout=3
        )
        connection.request(method, path, body, headers or {})
        response = connection.getresponse()
        data = response.read()
        connection.close()
        return response.status, data

    def test_http_action_and_cross_origin_and_path_boundaries(self):
        headers = {
            "Content-Type": "application/json",
            "X-Review-Token": self.server.token,
        }
        body = json.dumps(
            {
                "op": "comment",
                "body": "来自界面",
                "targets": [{"path": "case.py", "side": "new", "start": 1}],
            }
        )
        self.assertEqual(self.request("POST", "/api/action", body, headers)[0], 200)
        self.assertEqual(
            read(self.state)["threads"][0]["messages"][0]["author"], "user"
        )
        self.assertEqual(
            self.request(
                "POST",
                "/api/action",
                body,
                {**headers, "Origin": "https://evil.example"},
            )[0],
            403,
        )
        self.assertEqual(
            self.request(
                "POST", "/api/action", body, {"Content-Type": "application/json"}
            )[0],
            403,
        )
        self.assertEqual(
            self.request("GET", "/api/state", headers={"Host": "evil.example"})[0], 403
        )
        self.assertEqual(self.request("GET", "/assets/%2e%2e/review.py")[0], 403)
        self.assertEqual(self.request("GET", "/api/file?path=case.py")[0], 200)
        self.assertEqual(self.request("GET", "/api/file?path=../../etc/passwd")[0], 400)
        self.assertEqual(
            self.request(
                "POST",
                "/api/action",
                json.dumps({"op": "listen", "thread_id": "another-chat"}),
                headers,
            )[0],
            400,
        )

    def test_sse_observes_agent_reply_without_browser_polling(self):
        connection = http.client.HTTPConnection(
            "127.0.0.1", self.server.server_port, timeout=3
        )
        connection.request("GET", "/api/events")
        response = connection.getresponse()
        self.assertEqual(response.status, 200)
        response.readline()
        response.readline()
        self.note()
        line = response.readline()
        self.assertTrue(line.startswith(b"data:"), line)
        connection.close()


if __name__ == "__main__":
    unittest.main()
