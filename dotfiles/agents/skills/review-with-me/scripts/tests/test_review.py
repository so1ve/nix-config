import contextlib
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace


SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))

import review_server
import review_state


@contextlib.contextmanager
def working_directory(path):
    previous = Path.cwd()
    os.chdir(path)
    try:
        yield
    finally:
        os.chdir(previous)


def git(repo, *args):
    result = subprocess.run(
        ("git", "--no-pager", *args),
        cwd=repo,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=True,
    )
    return result.stdout


class GitRepositoryTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.repo = Path(temporary.name)
        git(self.repo, "init", "-q")
        git(self.repo, "config", "user.name", "Review Tests")
        git(self.repo, "config", "user.email", "review@example.test")
        git(self.repo, "config", "commit.gpgsign", "false")
        self.write("modified.txt", "one\n")
        self.write("deleted.txt", "gone\n")
        self.write(
            "old_name.txt",
            "".join(f"line {index}\n" for index in range(20)),
        )
        self.write_bytes("binary.bin", b"\x00\x01baseline")
        git(self.repo, "add", ".")
        git(self.repo, "commit", "-qm", "baseline")
        self.base = git(self.repo, "rev-parse", "HEAD").strip()

    def write(self, name, text):
        target = self.repo / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")

    def write_bytes(self, name, value):
        target = self.repo / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(value)

    def test_worktree_snapshot_is_stable_and_leaves_index_alone(self):
        self.write("modified.txt", "two\n")
        self.write("fresh.txt", "new\n")
        index_before = git(self.repo, "diff", "--cached", "--name-status")

        with working_directory(self.repo):
            commit = review_state.snapshot_worktree()

        self.assertRegex(commit, r"^[0-9a-f]{40,64}$")
        self.assertIn(
            commit,
            git(
                self.repo,
                "show-ref",
                "--verify",
                f"refs/review-with-me/snapshots/{commit}",
            ),
        )
        self.assertEqual(
            git(self.repo, "diff", "--cached", "--name-status"), index_before
        )
        payload = review_server.build_diff(
            self.repo,
            self.base,
            commit,
            ["modified.txt", "fresh.txt"],
        )
        files = {item["path"]: item for item in payload["files"]}
        self.assertEqual(files["modified.txt"]["status"], "modified")
        self.assertEqual(files["modified.txt"]["old_text"], "one\n")
        self.assertEqual(files["modified.txt"]["new_text"], "two\n")
        self.assertEqual(files["fresh.txt"]["status"], "added")
        self.assertEqual(files["fresh.txt"]["new_text"], "new\n")

    def test_worktree_snapshot_requires_git(self):
        with tempfile.TemporaryDirectory() as temporary:
            with working_directory(Path(temporary)):
                with self.assertRaisesRegex(ValueError, "Cannot snapshot"):
                    review_state.require_worktree_snapshot()

    def test_cli_records_fixed_base_and_revision_snapshots(self):
        state_path = Path(".review/review.json")
        with working_directory(self.repo):
            with contextlib.redirect_stdout(io.StringIO()):
                review_state.run(
                    review_state.parser().parse_args(
                        [
                            "init",
                            "--state",
                            str(state_path),
                            "--goal",
                            "Review snapshots",
                            "--scope",
                            "Working tree",
                            "--base",
                            "HEAD",
                        ]
                    )
                )
            self.write("modified.txt", "two\n")
            with contextlib.redirect_stdout(io.StringIO()):
                review_state.run(
                    review_state.parser().parse_args(
                        [
                            "add",
                            "--state",
                            str(state_path),
                            "--id",
                            "modified-file",
                            "--title",
                            "Modify one file",
                            "--paths",
                            "modified.txt",
                            "--summary",
                            "A file changes.",
                            "--rationale",
                            "The test needs a stable snapshot.",
                            "--head",
                            "WORKTREE",
                        ]
                    )
                )
                review_state.run(
                    review_state.parser().parse_args(
                        [
                            "update",
                            "--state",
                            str(state_path),
                            "--change",
                            "modified-file",
                            "--summary",
                            "The first snapshot is stable.",
                        ]
                    )
                )
            state = review_state.load(state_path)
            first_head = state["changes"][0]["revisions"][0]["head"]
            self.assertEqual(state["base"], self.base)
            self.assertRegex(first_head, r"^[0-9a-f]{40,64}$")
            self.assertEqual(
                state["changes"][0]["summary"],
                "The first snapshot is stable.",
            )

            self.write("modified.txt", "three\n")
            with contextlib.redirect_stdout(io.StringIO()):
                review_state.run(
                    review_state.parser().parse_args(
                        [
                            "revise",
                            "--state",
                            str(state_path),
                            "--change",
                            "modified-file",
                            "--head",
                            "WORKTREE",
                            "--label",
                            "Follow-up",
                            "--summary",
                            "The file changes again.",
                            "--reason",
                            "The second review round is independent.",
                        ]
                    )
                )
            revised = review_state.load(state_path)
            second = revised["changes"][0]["revisions"][1]
            self.assertEqual(second["base"], first_head)
            self.assertRegex(second["head"], r"^[0-9a-f]{40,64}$")

    def test_server_diff_covers_worktree_file_states(self):
        self.write("modified.txt", "two\n")
        (self.repo / "deleted.txt").unlink()
        (self.repo / "old_name.txt").rename(self.repo / "new_name.txt")
        self.write("fresh.txt", "new\n")
        self.write_bytes("binary.bin", b"\x00\x02changed")
        index_before = git(self.repo, "diff", "--cached", "--name-status")

        payload = review_server.build_diff(
            self.repo, self.base, "WORKTREE", []
        )
        files = {item["path"]: item for item in payload["files"]}

        self.assertEqual(files["modified.txt"]["status"], "modified")
        self.assertEqual(files["deleted.txt"]["status"], "deleted")
        self.assertEqual(files["new_name.txt"]["status"], "renamed")
        self.assertEqual(files["new_name.txt"]["old_path"], "old_name.txt")
        self.assertEqual(files["fresh.txt"]["status"], "added")
        self.assertTrue(files["binary.bin"]["binary"])
        self.assertEqual(files["binary.bin"]["old_text"], "")
        self.assertEqual(files["binary.bin"]["new_text"], "")
        self.assertEqual(
            git(self.repo, "diff", "--cached", "--name-status"),
            index_before,
        )

    def test_runtime_fingerprint_tracks_worktree_content(self):
        self.write("modified.txt", "two\n")
        state = {
            "base": self.base,
            "changes": [],
        }
        first = review_server.runtime_for(
            self.repo, Path(".review/review.json"), state
        )
        self.write("modified.txt", "three\n")
        second = review_server.runtime_for(
            self.repo, Path(".review/review.json"), state
        )
        self.assertNotEqual(
            first["worktree_fingerprint"], second["worktree_fingerprint"]
        )


class ReviewStateTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.repo = Path(temporary.name)
        git(self.repo, "init", "-q")
        git(self.repo, "config", "user.name", "Review Tests")
        git(self.repo, "config", "user.email", "review@example.test")
        git(self.repo, "config", "commit.gpgsign", "false")
        (self.repo / "file.txt").write_text("first\n", encoding="utf-8")
        git(self.repo, "add", "file.txt")
        git(self.repo, "commit", "-qm", "baseline")
        self.base = git(self.repo, "rev-parse", "HEAD").strip()

    def state(self):
        stamp = review_state.now()
        return {
            "version": review_state.SCHEMA_VERSION,
            "goal": "Review behavior",
            "scope": "One change",
            "base": self.base,
            "head": "WORKTREE",
            "overview": "",
            "created_at": stamp,
            "updated_at": stamp,
            "changes": [],
        }

    def add_change(self, state):
        return review_state.add_change(
            state,
            change_id="file-change",
            title="Change file",
            paths=["file.txt"],
            summary="The file changes.",
            rationale="The behavior needs review.",
            base=self.base,
            head=self.base,
        )

    def test_user_feedback_blocks_acceptance_until_resolved(self):
        state = self.state()
        change = self.add_change(state)
        note = review_state.add_annotation(
            change,
            author="user",
            kind="bug",
            body="This case is wrong.",
            revision_id="r1",
            path="file.txt",
            side="new",
            start=1,
            end=1,
        )
        self.assertEqual(change["status"], "feedback")
        with self.assertRaisesRegex(ValueError, "Resolve open user feedback"):
            review_state.set_status(change, "accepted")

        review_state.reply_to_annotation(
            change,
            note,
            author="agent",
            body="Fixed in the next revision.",
            resolve=True,
        )
        self.assertEqual(note["status"], "resolved")
        review_state.set_status(change, "accepted")
        self.assertEqual(change["status"], "accepted")

    def test_agent_notes_do_not_block_acceptance(self):
        state = self.state()
        change = self.add_change(state)
        review_state.add_annotation(
            change,
            author="agent",
            kind="note",
            body="This is why the change exists.",
            revision_id="r1",
            side="file",
            path="file.txt",
        )
        review_state.set_status(change, "accepted")
        self.assertEqual(change["status"], "accepted")

    def test_annotations_are_bound_to_existing_revisions(self):
        state = self.state()
        change = self.add_change(state)
        with self.assertRaisesRegex(ValueError, "Unknown revision"):
            review_state.add_annotation(
                change,
                author="user",
                kind="question",
                body="Which revision?",
                revision_id="missing",
                side="file",
            )
        note = review_state.add_annotation(
            change,
            author="agent",
            kind="note",
            body="This belongs to the first revision.",
            revision_id="r1",
            side="file",
            path="file.txt",
        )
        self.assertEqual(note["revision_id"], "r1")
        review_state.validate_state(state)

    def test_unanchored_legacy_worktree_cannot_become_a_revision_base(self):
        state = self.state()
        change = self.add_change(state)
        change["revisions"][0]["head"] = "WORKTREE"
        with self.assertRaisesRegex(ValueError, "depends on WORKTREE"):
            review_state.revise_change(
                change,
                head=self.base,
                label="Unsafe follow-up",
                summary="This should not be accepted.",
                reason="The original comparison cannot be reproduced.",
            )

    def test_legacy_feedback_migrates_to_semantic_changes(self):
        legacy = {
            "goal": "Legacy review",
            "scope": "One file",
            "base": self.base,
            "overview": "A path",
            "files": [
                {
                    "path": "file.txt",
                    "status": "discussing",
                    "summary": "The file was explained.",
                    "feedback": [
                        {
                            "text": "Why this branch?",
                            "outcome": "The branch validates input.",
                        }
                    ],
                }
            ],
        }
        migrated = review_state.migrate_annotations(
            review_state.migrate_legacy(legacy)
        )
        review_state.validate_state(migrated)
        change = migrated["changes"][0]
        self.assertEqual(change["status"], "reviewing")
        self.assertEqual(change["annotations"][0]["revision_id"], "r1")
        self.assertEqual(change["annotations"][0]["status"], "resolved")

    def test_prepare_state_persists_stable_legacy_annotations(self):
        state_path = self.repo / ".review/auth.json"
        legacy = {
            "goal": "Legacy review",
            "scope": "One file",
            "base": self.base,
            "overview": "",
            "files": [
                {
                    "path": "file.txt",
                    "status": "discussing",
                    "summary": "The file was explained.",
                    "feedback": [{"text": "Why?", "outcome": ""}],
                }
            ],
        }
        state_path.parent.mkdir()
        state_path.write_text(
            json.dumps(legacy),
            encoding="utf-8",
        )

        review_state.prepare_state(state_path)
        first = review_state.load(state_path)
        second = review_state.load(state_path)

        self.assertEqual(first["version"], review_state.SCHEMA_VERSION)
        self.assertEqual(
            first["changes"][0]["annotations"][0]["id"],
            second["changes"][0]["annotations"][0]["id"],
        )


class WebBoundaryTest(unittest.TestCase):
    def test_index_replaces_token_and_uses_bundled_entrypoints(self):
        source = (review_server.WEB_ROOT / "index.html").read_text(
            encoding="utf-8"
        )
        self.assertIn("__REVIEW_TOKEN__", source)
        html = review_server.index_html("temporary-token")
        self.assertIn('content="temporary-token"', html)
        self.assertIn('src="/assets/review.js"', html)
        self.assertIn('href="/assets/review.css"', html)

    def test_mutation_token_and_origin_checks(self):
        handler = object.__new__(review_server.Handler)
        handler.server = SimpleNamespace(token="secret")
        handler.headers = {
            "X-Review-Token": "secret",
            "Host": "127.0.0.1:8765",
            "Origin": "http://127.0.0.1:8765",
        }
        self.assertTrue(handler.token_ok())
        self.assertTrue(handler.origin_ok())
        handler.headers["X-Review-Token"] = "wrong"
        handler.headers["Origin"] = "https://example.com"
        self.assertFalse(handler.token_ok())
        self.assertFalse(handler.origin_ok())

    def test_assets_are_shipped_and_served_as_gzip(self):
        assets = review_server.WEB_ROOT / "assets"
        self.assertTrue((assets / "review.js.gz").is_file())
        self.assertTrue((assets / "review.css.gz").is_file())
        self.assertFalse((assets / "review.js").exists())
        self.assertFalse((assets / "review.css").exists())

        handler = object.__new__(review_server.Handler)
        handler.path = "/assets/review.js"
        handler.headers = {"Accept-Encoding": "gzip"}
        handler.close_connection = False
        handler.wfile = io.BytesIO()
        handler.server = SimpleNamespace(
            repo=Path.cwd(),
            review_path=review_server.WEB_ROOT / "index.html",
            token="secret",
        )
        statuses = []
        headers = {}
        handler.send_response = statuses.append
        handler.send_header = headers.__setitem__
        handler.end_headers = lambda: None

        handler.do_GET()

        self.assertEqual(statuses, [review_server.HTTPStatus.OK])
        self.assertEqual(headers["Content-Encoding"], "gzip")
        self.assertEqual(
            headers["Content-Type"],
            "text/javascript; charset=utf-8",
        )
        self.assertIn(
            "'wasm-unsafe-eval'",
            headers["Content-Security-Policy"],
        )
        self.assertEqual(handler.wfile.getvalue()[:2], b"\x1f\x8b")


if __name__ == "__main__":
    unittest.main()
