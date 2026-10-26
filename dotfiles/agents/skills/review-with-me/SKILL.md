---
name: review-with-me
description: Guide an interactive source review file by file, trace callers and callees, explain design reasons, and retain user feedback and progress across sessions. Use for guided walkthroughs, "带我审查", and continuing a bounded review; not for a one-shot automated bug report.
---

# Review With Me

Help the user understand and question the implementation. Default to Chinese.
Explain the current file, discuss the user's feedback, and wait for them before
moving on. Reading source is not the same as completing the user's review.

## Establish the review

Read repository instructions. Use the files, directory, feature, or diff the user
specified. Ask what to review only when no bounded target can be inferred.
Identify the entry points and enumerate the exact target files. For a directory,
include its relevant source, configuration, and tests; do not silently drop small
files or awkward branches. Treat generated files and dependencies as context
unless they are requested targets. For a diff, record the comparison and revisions
in the scope description and inspect surrounding code, not just changed lines.

Briefly present the file list and an order that follows the supported operation
from entry to result. Explain cross-file relationships in a short call chain or
Mermaid diagram when it helps. Distinguish direct calls, callbacks, events,
configuration, and data dependencies. Do not invent edges from matching names.
Start the first file without another approval when the requested scope is clear;
let the user reorder, narrow, or expand it during discussion.

Save one review record in the target workspace, normally `.review/<topic>.json`.
Reuse a matching record when resuming; never overwrite another review. The record
holds the goal, scope, overview, ordered files, per-file summaries, and feedback.
Do not create copies of the source, per-function reports, or a second progress
document. Do not modify source code or repository configuration just to review it.

## Trace before explaining

Read the complete in-scope content of the current file, including error paths and
cleanup. Check for truncated output. For a large file, discuss natural sections
over several exchanges and save where to resume; keep the file unfinished until
all its requested content is covered.

Find real callers, important callees, types, configuration, and relevant tests.
Use symbol navigation or references when available, otherwise search and read the
matching code. Follow indirection such as registration, dependency injection,
macros, and event dispatch until the relevant behavior is established. Read a
dependency when an explanation relies on its contract; do not crawl unrelated
subsystems or expand the review agenda simply because a call reaches them.

Explain the parts that affect understanding or correctness:

- The file's responsibility, who enters it, its inputs, and the resulting output
  or side effect. Follow an actual supported request or operation through it.
- Why a consequential call occurs here: what its caller guarantees, what it
  requires, which owner changes state, and why ordering or lifetime matters.
- Failure propagation, cleanup, persistence, permissions, and concurrency where
  they affect this path. Read the implementation behind a reassuring function name.
- Whether a layer simplifies a real caller or makes the same task harder to
  follow. Identify requirements before treating complexity as unnecessary.

Use linked source locations and short excerpts at the point they matter. Do not
reprint whole files, narrate ordinary syntax, or merely repeat comments. Verify a
comment's claim against code. Explain a design reason supported by contracts,
tests, documentation, or history; label an inference and admit when intent is
unknown. Do not manufacture a rationale to defend generated code.

## Discuss one file at a time

For the current file, connect its role to the overall chain, explain the important
steps and their reasons, then identify concrete problems or questions. Adapt the
depth to the user's responses. Group straightforward code so the explanation is
readable; give difficult branches the detail they need.

Separate defects, design tradeoffs, and open questions. For a defect, show its
location, a reachable trigger, the observed or expected consequence, and a
possible correction. Check it against the user's confirmed deployment and caller
facts. Do not fill a quota of findings or disguise a preference as a bug.

Record the user's feedback before proceeding: their concern or correction,
the relevant file and symbol, and any answer or decision. Keep their meaning and
uncertainty; do not silently turn a suggestion into an agreed requirement. A
finding that needs discussion can use the same feedback list. An outcome may be
"keep the current design", "change this now", "defer the fix", or "out of scope";
record the actual decision rather than assuming agreement.

Finish the exchange with the file's status and room for questions. Wait for user
input. A question, a correction, or silence does not finish the file. When the
user says this file is done or asks for the next file, resolve any remaining
discussion or record their explicit deferral, then mark it reviewed and continue.
If they jump ahead, leave the earlier file for revisiting. Do not automatically
batch the remaining files, even when no defects are found.

Editing review records is part of this skill. Editing source requires the user's
request. If they request a fix, make the focused change within existing execution
permissions, explain and verify it, and return to the same review agenda. A
recorded decision to fix something later is not authorization to edit it now.

## Resume and finish

At the start of a later exchange, consult the record and relevant source again.
Give a brief progress update, pick up the unfinished section or feedback, and
avoid repeating completed explanations. Inspect working-tree changes and the
named comparison before reusing old conclusions. If code changed, reread affected
files and callers, mark affected items for revisiting, and retain earlier feedback.
Without enough history to establish what changed, say so rather than claiming the
previous review still covers the current source.

Keep the target list fixed unless the user changes the scope. Context-only files
do not count as reviewed targets. Missing access or unreadable files stay
unfinished; exclude a target only at the user's direction, with its reason.

Finish when every target is reviewed or explicitly excluded and every feedback
item has a recorded outcome. A deferred fix may remain as agreed follow-up; review
completion does not imply every defect was fixed. Summarize the actual coverage,
decisions, remaining follow-up work, and any unverified runtime claims. Do not
start another review cycle after the agreed scope is complete.

## Progress helper

Use [scripts/review_state.py](scripts/review_state.py) for the record. It uses only
Python's standard library and never reads or changes source files. Run it from
the target workspace with workspace-relative paths. Replace `<state-tool>` with
the installed script's path; keep records outside the installed skill directory.

```sh
python3 <state-tool> init --state .review/auth.json \
  --goal 'Understand authentication and question unnecessary layers' \
  --scope 'Current working-tree implementation of src/auth and its tests' \
  --files src/auth/entry.py src/auth/session.py tests/test_auth.py
python3 <state-tool> overview --state .review/auth.json \
  --text 'entry.handle -> session.load -> store.read; errors return through handle'
python3 <state-tool> file --state .review/auth.json --path src/auth/entry.py \
  --status discussing --summary 'Explained handle; still discuss the retry branch'
python3 <state-tool> feedback --state .review/auth.json --path src/auth/entry.py \
  --text 'User asks why handle retries when store.read already retries'
python3 <state-tool> decide --state .review/auth.json --path src/auth/entry.py \
  --number 1 --outcome 'Confirmed duplicate retry; user wants to defer its removal'
python3 <state-tool> file --state .review/auth.json --path src/auth/entry.py \
  --status reviewed --summary 'User finished this file; duplicate retry deferred'
python3 <state-tool> show --state .review/auth.json
python3 <state-tool> show --state .review/auth.json --path src/auth/entry.py
```

File statuses are `pending`, `discussing`, `revisit`, `reviewed`, and `excluded`.
Use `summary` for a concise explanation checkpoint and important source locations.
Use `show --path` to recover one file's discussion without loading every note.
Feedback numbers are local to each file and remain stable. A blank outcome means
unresolved discussion. The helper prevents marking such a file reviewed and
reopens a reviewed file when new feedback arrives. Exclusion requires a reason.
It reports completion from the file states and feedback outcomes, not from how
many files the AI happened to open. It cannot establish whether an explanation is
correct or the user agreed; the conversation and source determine those facts.

When the user changes the target list or order, edit the same record with normal
file tools, preserving summaries and feedback for retained files. Mark removed
targets `excluded` with the user's reason. Do not reset the record to hide unfinished
work or copy personal feedback into global instructions without being asked.

## Related work

- [xdg: review-walkthrough](https://github.com/xdg/xdg-claude/blob/main/review-walkthrough/skills/review-walkthrough/SKILL.md): interactive pacing and resumable scope.
- [Trail of Bits: audit-context-building](https://github.com/trailofbits/skills/blob/main/plugins/audit-context-building/skills/audit-context-building/SKILL.md): understanding dependencies and assumptions before judging them.
