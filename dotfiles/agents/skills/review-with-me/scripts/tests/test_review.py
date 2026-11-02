import contextlib
import concurrent.futures
import io
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock


SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))

import review_server
import review_state
import review_listener


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
        migrated = review_state.migrate_review_items(migrated)
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

    def test_v2_record_migrates_to_review_decisions(self):
        state_path = self.repo / ".review/v2.json"
        state = self.state()
        state["version"] = 2
        change = self.add_change(state)
        change.pop("decisions")
        state_path.parent.mkdir()
        state_path.write_text(
            json.dumps(state),
            encoding="utf-8",
        )

        migrated = review_state.load(state_path)

        self.assertEqual(migrated["version"], review_state.SCHEMA_VERSION)
        self.assertEqual(migrated["changes"][0]["decisions"], [])

    def test_file_acceptance_completes_the_revision(self):
        (self.repo / "file.txt").write_text(
            "first\nsecond\nthird\n",
            encoding="utf-8",
        )
        with working_directory(self.repo):
            head = review_state.require_worktree_snapshot()
        state = self.state()
        change = review_state.add_change(
            state,
            change_id="file-change",
            title="Change file",
            paths=["file.txt"],
            summary="The file changes.",
            rationale="The behavior needs review.",
            base=self.base,
            head=head,
        )

        decision, summary = review_server.record_review_decision(
            self.repo,
            state,
            change,
            revision_id="r1",
            path="file.txt",
            scope="file",
            hunk=None,
            status="accepted",
            author="user",
        )

        self.assertEqual(decision["scope"], "file")
        self.assertEqual(summary["pending"], 0)
        self.assertTrue(summary["user_accepted"])
        self.assertEqual(change["status"], "accepted")

    def test_each_hunk_can_be_accepted_without_accepting_the_file(self):
        original = "".join(f"line {index}\n" for index in range(1, 21))
        changed = original.replace("line 2\n", "line two\n").replace(
            "line 18\n", "line eighteen\n"
        )
        (self.repo / "file.txt").write_text(original, encoding="utf-8")
        git(self.repo, "add", "file.txt")
        git(self.repo, "commit", "-qm", "long file")
        base = git(self.repo, "rev-parse", "HEAD").strip()
        (self.repo / "file.txt").write_text(changed, encoding="utf-8")
        with working_directory(self.repo):
            head = review_state.require_worktree_snapshot()
        state = self.state()
        state["base"] = base
        change = review_state.add_change(
            state,
            change_id="hunk-change",
            title="Change two regions",
            paths=["file.txt"],
            summary="Two regions change.",
            rationale="Both regions need review.",
            base=base,
            head=head,
        )
        payload = review_server.build_diff(
            self.repo, base, head, ["file.txt"]
        )
        first, second = payload["files"][0]["hunks"]
        pending_items = review_server.review_items_for_change(
            self.repo, change, pending_only=True
        )["items"]
        self.assertEqual(
            [(item["scope"], item["status"]) for item in pending_items],
            [("hunk", "pending"), ("hunk", "pending")],
        )

        _, first_summary = review_server.record_review_decision(
            self.repo,
            state,
            change,
            revision_id="r1",
            path="file.txt",
            scope="hunk",
            hunk=first,
            status="accepted",
            author="user",
        )
        self.assertEqual(first_summary["pending"], 1)
        self.assertEqual(change["status"], "reviewing")
        self.assertEqual(
            len(
                review_server.review_items_for_change(
                    self.repo, change, pending_only=True
                )["items"]
            ),
            1,
        )

        _, second_summary = review_server.record_review_decision(
            self.repo,
            state,
            change,
            revision_id="r1",
            path="file.txt",
            scope="hunk",
            hunk=second,
            status="accepted",
            author="user",
        )
        self.assertEqual(second_summary["pending"], 0)
        self.assertEqual(change["status"], "accepted")

    def test_agent_excluded_test_file_stays_out_of_user_acceptance(self):
        (self.repo / "test_file.txt").write_text(
            "assert new behavior\n",
            encoding="utf-8",
        )
        with working_directory(self.repo):
            head = review_state.require_worktree_snapshot()
        state = self.state()
        change = review_state.add_change(
            state,
            change_id="test-change",
            title="Update tests",
            paths=["test_file.txt"],
            summary="The tests follow the new behavior.",
            rationale="They protect the changed contract.",
            base=self.base,
            head=head,
        )

        decision, summary = review_server.record_review_decision(
            self.repo,
            state,
            change,
            revision_id="r1",
            path="test_file.txt",
            scope="file",
            hunk=None,
            status="excluded",
            author="agent",
            reason="测试辅助改动，行为已由对应审阅单元说明。",
        )

        self.assertEqual(decision["status"], "excluded")
        self.assertEqual(summary["pending"], 0)
        self.assertFalse(summary["user_accepted"])
        self.assertNotEqual(change["status"], "accepted")

    def test_invalid_hunk_decision_is_rejected(self):
        (self.repo / "file.txt").write_text("changed\n", encoding="utf-8")
        with working_directory(self.repo):
            head = review_state.require_worktree_snapshot()
        state = self.state()
        change = review_state.add_change(
            state,
            change_id="file-change",
            title="Change file",
            paths=["file.txt"],
            summary="The file changes.",
            rationale="The behavior needs review.",
            base=self.base,
            head=head,
        )

        with self.assertRaisesRegex(review_server.ReviewError, "selected hunk"):
            review_server.record_review_decision(
                self.repo,
                state,
                change,
                revision_id="r1",
                path="file.txt",
                scope="hunk",
                hunk={
                    "old_start": 999,
                    "old_count": 1,
                    "new_start": 999,
                    "new_count": 1,
                },
                status="accepted",
                author="user",
            )

    def test_revision_refactor_does_not_reuse_old_hunk_decisions(self):
        original = "".join(f"line {index}\n" for index in range(1, 21))
        first_change = original.replace("line 2\n", "line two\n")
        (self.repo / "file.txt").write_text(original, encoding="utf-8")
        git(self.repo, "add", "file.txt")
        git(self.repo, "commit", "-qm", "long file")
        base = git(self.repo, "rev-parse", "HEAD").strip()
        (self.repo / "file.txt").write_text(first_change, encoding="utf-8")
        with working_directory(self.repo):
            first_head = review_state.require_worktree_snapshot()
        state = self.state()
        state["base"] = base
        change = review_state.add_change(
            state,
            change_id="hunk-change",
            title="Change one region",
            paths=["file.txt"],
            summary="One region changes.",
            rationale="It needs review.",
            base=base,
            head=first_head,
        )
        first_hunk = review_server.build_diff(
            self.repo, base, first_head, ["file.txt"]
        )["files"][0]["hunks"][0]
        review_server.record_review_decision(
            self.repo,
            state,
            change,
            revision_id="r1",
            path="file.txt",
            scope="hunk",
            hunk=first_hunk,
            status="accepted",
            author="user",
        )

        (self.repo / "file.txt").write_text(
            original.replace("line 2\n", "line second\n").replace(
                "line 18\n", "line eighteenth\n"
            ),
            encoding="utf-8",
        )
        with working_directory(self.repo):
            second_head = review_state.require_worktree_snapshot()
        review_state.revise_change(
            change,
            head=second_head,
            label="Structural follow-up",
            summary="The file is reorganized.",
            reason="The implementation changed after review.",
        )

        summary = review_server.review_summary_for_change(
            self.repo, change, revision_id="r2"
        )

        self.assertEqual(summary["pending"], 2)
        self.assertFalse(summary["user_accepted"])
        self.assertEqual(change["status"], "revisit")

    def test_feedback_delivery_is_claimed_once_and_answered(self):
        state = self.state()
        change = self.add_change(state)
        note = review_state.add_annotation(
            change,
            author="user",
            kind="change",
            body="Keep the fallback.",
            revision_id="r1",
            path="file.txt",
            side="new",
            start=1,
            end=1,
        )
        self.assertEqual(note["delivery"]["state"], "queued")

        claimed = review_state.claim_feedback(state)

        self.assertEqual(len(claimed), 1)
        self.assertEqual(claimed[0]["annotation"], note["id"])
        self.assertEqual(note["delivery"]["state"], "processing")
        self.assertEqual(review_state.claim_feedback(state), [])

        review_state.reply_to_annotation(
            change,
            note,
            author="agent",
            body="Kept and covered by a test.",
            resolve=True,
        )
        self.assertEqual(note["delivery"]["state"], "answered")
        self.assertEqual(review_state.claim_feedback(state), [])
        review_state.validate_state(state)

    def test_user_reply_creates_another_delivery_event(self):
        state = self.state()
        change = self.add_change(state)
        note = review_state.add_annotation(
            change,
            author="agent",
            kind="note",
            body="This follows the caller contract.",
            revision_id="r1",
            side="file",
            path="file.txt",
        )
        reply = review_state.reply_to_annotation(
            change,
            note,
            author="user",
            body="Which caller relies on it?",
        )

        self.assertEqual(reply["delivery"]["state"], "queued")
        claimed = review_state.claim_feedback(state)
        self.assertEqual(len(claimed), 1)
        self.assertEqual(claimed[0]["reply"], reply["id"])
        self.assertEqual(claimed[0]["body"], "Which caller relies on it?")

    def test_user_reply_reopens_a_resolved_note_and_blocks_acceptance(self):
        state = self.state()
        change = self.add_change(state)
        note = review_state.add_annotation(
            change,
            author="agent",
            kind="note",
            body="This follows the caller contract.",
            revision_id="r1",
            side="file",
            path="file.txt",
        )
        note["status"] = "resolved"
        review_state.set_status(change, "accepted")

        review_state.reply_to_annotation(
            change,
            note,
            author="user",
            body="Which caller relies on it?",
        )

        self.assertEqual(note["status"], "open")
        self.assertEqual(change["status"], "feedback")
        with self.assertRaisesRegex(ValueError, "Resolve open user feedback"):
            review_state.set_status(change, "accepted")

        review_state.reply_to_annotation(
            change,
            note,
            author="agent",
            body="The session response path does.",
            resolve=True,
        )
        review_state.set_status(change, "accepted")

    def test_stale_processing_event_can_be_reclaimed(self):
        state = self.state()
        change = self.add_change(state)
        note = review_state.add_annotation(
            change,
            author="user",
            kind="question",
            body="Did the turn finish?",
            revision_id="r1",
            side="file",
            path="file.txt",
        )
        review_state.claim_feedback(state)
        self.assertEqual(review_state.claim_feedback(state), [])

        note["delivery"]["claimed_at"] = "2000-01-01T00:00:00Z"

        reclaimed = review_state.claim_feedback(state)
        self.assertEqual(len(reclaimed), 1)
        self.assertEqual(reclaimed[0]["annotation"], note["id"])

    def test_paused_listener_blocks_claim_until_agent_resumes(self):
        state_path = self.repo / ".review/auth.json"
        state = self.state()
        change = self.add_change(state)
        review_state.add_annotation(
            change,
            author="user",
            kind="question",
            body="Why this route?",
            revision_id="r1",
            side="file",
            path="file.txt",
        )
        review_state.save(state_path, state)
        review_listener.configure(state_path, thread_id="thread-123")
        review_listener.stop(state_path)

        with working_directory(self.repo):
            with self.assertRaisesRegex(ValueError, "listener is paused"):
                review_state.run(
                    review_state.parser().parse_args(
                        [
                            "inbox",
                            "--state",
                            ".review/auth.json",
                            "--claim",
                            "--json",
                        ]
                    )
                )

        listener = review_listener.configure(
            state_path,
            thread_id="thread-123",
            automation_id="review-auth",
        )
        self.assertEqual(listener["status"], "listening")
        with working_directory(self.repo):
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                review_state.run(
                    review_state.parser().parse_args(
                        [
                            "inbox",
                            "--state",
                            ".review/auth.json",
                            "--claim",
                            "--json",
                        ]
                    )
                )
        self.assertEqual(len(json.loads(output.getvalue())), 1)

    def test_direct_delivery_uses_queue_and_persists_state(self):
        state_path = (self.repo / ".review/auth.json").resolve()
        state = self.state()
        change = self.add_change(state)
        note = review_state.add_annotation(
            change,
            author="user",
            kind="bug",
            body="This fails.",
            revision_id="r1",
            side="file",
            path="file.txt",
        )
        review_state.save(state_path, state)
        review_listener.configure(state_path, thread_id="thread-123")

        with mock.patch.object(review_listener, "queue_thread") as queue_thread:
            result = review_server.deliver_feedback(
                self.repo, state_path, note
            )

        self.assertEqual(result["state"], "delivered")
        queue_thread.assert_called_once()
        message = queue_thread.call_args.args[1]
        self.assertIn("inbox", message)
        self.assertIn("--claim", message)
        saved = review_state.load(state_path)
        saved_note = saved["changes"][0]["annotations"][0]
        self.assertEqual(saved_note["delivery"]["state"], "delivered")
        listener = review_listener.load(state_path)
        self.assertEqual(listener["status"], "listening")
        self.assertEqual(listener["last_event_id"], saved_note["delivery"]["id"])

    def test_paused_listener_does_not_queue_feedback(self):
        state_path = (self.repo / ".review/auth.json").resolve()
        state = self.state()
        change = self.add_change(state)
        note = review_state.add_annotation(
            change,
            author="user",
            kind="bug",
            body="This fails.",
            revision_id="r1",
            side="file",
            path="file.txt",
        )
        review_state.save(state_path, state)
        review_listener.configure(state_path, thread_id="thread-123")
        review_listener.stop(state_path)

        with mock.patch.object(review_listener, "queue_thread") as queue_thread:
            result = review_server.deliver_feedback(
                self.repo, state_path, note
            )

        self.assertEqual(result["state"], "paused")
        queue_thread.assert_not_called()
        saved = review_state.load(state_path)
        self.assertEqual(
            saved["changes"][0]["annotations"][0]["delivery"]["state"],
            "queued",
        )

    def test_inflight_delivery_cannot_resume_a_paused_listener(self):
        state_path = (self.repo / ".review/auth.json").resolve()
        state = self.state()
        change = self.add_change(state)
        note = review_state.add_annotation(
            change,
            author="user",
            kind="question",
            body="Why is this here?",
            revision_id="r1",
            side="file",
            path="file.txt",
        )
        review_state.save(state_path, state)
        review_listener.configure(state_path, thread_id="thread-123")

        def stop_while_queueing(*args, **kwargs):
            review_listener.stop(state_path)

        with mock.patch.object(
            review_listener, "queue_thread", side_effect=stop_while_queueing
        ):
            result = review_server.deliver_feedback(
                self.repo, state_path, note
            )

        self.assertEqual(result["state"], "delivered")
        self.assertEqual(review_listener.load(state_path)["status"], "paused")

    def test_queue_failure_keeps_scheduled_fallback_available(self):
        state_path = (self.repo / ".review/auth.json").resolve()
        state = self.state()
        change = self.add_change(state)
        note = review_state.add_annotation(
            change,
            author="user",
            kind="bug",
            body="This fails.",
            revision_id="r1",
            side="file",
            path="file.txt",
        )
        review_state.save(state_path, state)
        review_listener.configure(
            state_path,
            thread_id="thread-123",
            automation_id="review-auth",
        )

        with mock.patch.object(
            review_listener,
            "queue_thread",
            side_effect=RuntimeError("app-server unavailable"),
        ):
            result = review_server.deliver_feedback(
                self.repo, state_path, note
            )

        self.assertEqual(result["state"], "failed")
        listener = review_listener.load(state_path)
        self.assertEqual(listener["status"], "degraded")
        self.assertIn("app-server unavailable", listener["last_error"])

    def test_feedback_burst_reuses_one_queued_wake(self):
        state_path = (self.repo / ".review/auth.json").resolve()
        state = self.state()
        change = self.add_change(state)
        first = review_state.add_annotation(
            change,
            author="user",
            kind="change",
            body="First adjustment.",
            revision_id="r1",
            side="file",
            path="file.txt",
        )
        second = review_state.add_annotation(
            change,
            author="user",
            kind="question",
            body="Second question.",
            revision_id="r1",
            side="file",
            path="file.txt",
        )
        review_state.save(state_path, state)
        review_listener.configure(state_path, thread_id="thread-123")

        with mock.patch.object(review_listener, "queue_thread") as queue_thread:
            first_result = review_server.deliver_feedback(
                self.repo, state_path, first
            )
            second_result = review_server.deliver_feedback(
                self.repo, state_path, second
            )

        self.assertEqual(first_result["state"], "delivered")
        self.assertEqual(second_result["state"], "delivered")
        queue_thread.assert_called_once()

    def test_concurrent_feedback_reuses_one_queued_wake(self):
        state_path = (self.repo / ".review/auth.json").resolve()
        state = self.state()
        change = self.add_change(state)
        first = review_state.add_annotation(
            change,
            author="user",
            kind="change",
            body="First concurrent adjustment.",
            revision_id="r1",
            side="file",
            path="file.txt",
        )
        second = review_state.add_annotation(
            change,
            author="user",
            kind="question",
            body="Second concurrent question.",
            revision_id="r1",
            side="file",
            path="file.txt",
        )
        review_state.save(state_path, state)
        review_listener.configure(state_path, thread_id="thread-123")

        original_has_waiting = review_state.has_waiting_delivery

        def slow_waiting_check(current_state):
            result = original_has_waiting(current_state)
            time.sleep(0.1)
            return result

        with (
            mock.patch.object(review_listener, "queue_thread") as queue_thread,
            mock.patch.object(
                review_state,
                "has_waiting_delivery",
                side_effect=slow_waiting_check,
            ),
        ):
            with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
                results = list(
                    pool.map(
                        lambda note: review_server.deliver_feedback(
                            self.repo, state_path, note
                        ),
                        (first, second),
                    )
                )

        self.assertEqual([result["state"] for result in results], ["delivered", "delivered"])
        queue_thread.assert_called_once()


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
