---
name: review-with-me
description: Maintain a semantic, resumable AI code review with stable revisions, agent-owned review boundaries, inline user feedback, and a local diff frontend. Use for guided walkthroughs, "带我审查", reviewing AI-generated changes, responding to review feedback, and continuing a bounded review over several rounds.
---

# Review With Me

Maintain a review the user can understand and drive. Default to Chinese. Treat
the review record as the durable product of the conversation, not as a cache
derived from commits or the working tree.

The helper is `<state-tool>` below. Replace it with the installed
`scripts/review_state.py` path. Run it from the repository being reviewed and
keep records at workspace-relative paths such as `.review/auth.json`.

## Review model

- A **change** is one semantic review unit. It is a behavior or idea the user
  can accept, question, or reject. It is not a commit, file, or fixed line
  range.
- A change owns an ordered list of **revisions**. Each revision points to
  immutable Git commits and explains what changed in that round and why.
- A change owns **annotations**: agent explanations, user questions, bugs,
  requested changes, suggestions, replies, and resolution state. Line
  annotations are bound to one revision, so later refactors cannot silently
  move old feedback onto unrelated code.
- A change also owns revision-bound **review decisions** for whole files and
  individual changed blocks. The user can accept items in the frontend, while
  the Agent can exclude low-signal support files such as fixtures or generated
  tests with a visible reason. Pending items are not inferred from commits.
- The Agent decides semantic boundaries and when a region is `unreviewed`,
  `reviewing`, `revisit`, `feedback`, or `superseded`. The frontend must not
  infer those states from commit counts.
- Only the user decides that work is `accepted`. Never mark a change accepted
  merely because tests pass, code looks correct, or the Agent finished editing.

Use these statuses:

- `unreviewed`: the user has not examined this unit yet.
- `reviewing`: it is being actively explained or discussed.
- `feedback`: actionable user feedback is open.
- `revisit`: earlier judgment no longer covers the current revision.
- `accepted`: the user explicitly accepted this unit.
- `superseded`: a later semantic unit replaced it. Preserve it for history.

## Start or resume

Read repository instructions first. Find the bounded branch, commit range,
feature, or working-tree work the user named. Do not silently widen the review.

When a record exists, run:

```sh
python3 <state-tool> show --state .review/auth.json
python3 <state-tool> listen --state .review/auth.json --action status --json
```

If the listener is `paused`, do not process review feedback or restart the
listener unless the current user request explicitly asks to resume. If it is
`listening`, claim pending feedback before editing code:

```sh
python3 <state-tool> inbox --state .review/auth.json --claim --json
```

Re-read the relevant source and current revision because an old explanation may
no longer be true. Do not repeat a previous walkthrough when the record already
contains it.

For a new record, anchor the base commit explicitly:

```sh
python3 <state-tool> init --state .review/auth.json \
  --goal 'Review the authentication rewrite' \
  --scope 'Commits from origin/main through the current worktree' \
  --base origin/main
```

`init` resolves the base to a full immutable commit. Do not use `WORKTREE` as
the base.

Build the smallest set of review units that still covers all AI changes. Group
code that supports one behavior, including its callers, configuration, and
tests. Split unrelated behavior rather than creating one unit per file. Leave
nothing hidden: paths missing from every unit appear in the UI as
“未归类改动”, and the user can adopt them, but the Agent should normally map
its own changes first.

For every unit, provide:

- a concrete title using the user's vocabulary;
- all current paths, including old paths for renames;
- what changed and who exercises it;
- why this design is needed, including a constraint, failing behavior, or
  supported caller. If intent is unknown, say so instead of inventing a reason.

```sh
python3 <state-tool> add --state .review/auth.json \
  --id auth-identity --title 'Authentication returns an identity' \
  --paths src/auth.py src/session.py tests/test_auth.py \
  --summary 'Login now carries the identity returned by authentication.' \
  --rationale 'The old boolean check discarded the user identity needed by session callers.' \
  --head WORKTREE --label 'Initial implementation'
```

`--head WORKTREE` is snapshotted immediately. The helper writes the snapshot as
a hidden ref under `refs/review-with-me/snapshots/` and does not change the Git
index, branch, or visible history. This is what preserves the first diff when
the Agent later commits or keeps editing.

After registering a unit, list its concrete file and hunk items:

```sh
python3 <state-tool> items --state .review/auth.json \
  --change auth-identity --json
```

Each item is bound to the current revision and can be `pending`, `accepted`, or
`excluded`. The frontend computes the same view directly from these decisions.

## Explain the change

Use `overview` for the cross-unit call path, not a restatement of titles:

```sh
python3 <state-tool> overview --state .review/auth.json \
  --text 'session.login -> auth.authenticate -> identity -> session response'
```

Use `update` when the summary or rationale becomes clearer:

```sh
python3 <state-tool> update --state .review/auth.json \
  --change auth-identity \
  --rationale 'Callers need the identity, so authentication cannot return a boolean.'
```

Use agent annotations for local explanations that belong beside code:

```sh
python3 <state-tool> annotate --state .review/auth.json \
  --change auth-identity --revision r1 \
  --kind note --path src/auth.py --side new --start 8 --end 14 \
  --body 'This branch preserves the caller contract while replacing the boolean result.'
```

`--side old` addresses the pre-change side, `--side new` the post-change side,
and `--side file` creates a file-level note. A file-level note may omit
`--path`; then it belongs to the whole review unit.

Read the implementation behind names before explaining it. Distinguish a
verified design reason from an inference. Do not defend generated code with
generic statements such as “better separation” unless a real caller or
constraint requires that separation.

## Reduce low-signal review noise

Tests and fixtures should support a review, not bury the production behavior.
After the semantic units are registered, inspect `items` and exclude a support
file or changed block only when its purpose is already explained by another
unit and line-by-line review would add no decision:

```sh
python3 <state-tool> item --state .review/auth.json \
  --change auth-identity --path tests/test_auth_snapshot.py \
  --scope file --status excluded \
  --reason '自动生成的行为快照测试，覆盖范围已在 auth-identity 的说明中交代。'
```

Use `--scope hunk --old-start … --old-count … --new-start … --new-count …`
for one block. Exclusion is visible and reversible in the frontend; it never
counts as user acceptance. Do not exclude production behavior, a failing test,
a test that defines the contract, or a test whose purpose is not explained
elsewhere. Prefer grouping tests with their behavior over silently hiding them.

## Continue after more AI work

When a coherent implementation batch changes an existing unit, append a
revision immediately:

```sh
python3 <state-tool> revise --state .review/auth.json \
  --change auth-identity \
  --head WORKTREE \
  --label 'Audience-aware identity' \
  --summary 'Authentication now records the token audience.' \
  --reason 'The API needs to distinguish browser and service identities.'
```

The previous revision is the new base, so the UI can show either that round or
the cumulative change. Never edit an old revision's refs or pretend a new diff
is the old one.

If the user lets the Agent make large changes before reviewing, keep working,
but register the new batch before handing control back. The UI reports worktree
files changed after the newest snapshot and warns that an unrecorded follow-up
exists. Do not leave that warning as the permanent representation of a large
refactor.

For a structural refactor:

- Preserve earlier units and their annotations.
- Create new semantic units for the resulting behavior when old boundaries no
  longer describe the code.
- Mark replaced units `superseded` and set `--superseded-by` to the new unit.
- If the behavior remains the same and only its implementation changed, append
  a revision and mark the unit `revisit` when the old acceptance no longer
  applies.
- Never delete a review record, clear feedback, or rewrite old revisions just
  to make progress look clean.

```sh
python3 <state-tool> status --state .review/auth.json \
  --change old-auth-layer --status superseded \
  --superseded-by auth-identity
```

## Respond to review feedback

At the start of every review turn initiated by the UI bridge or the fallback
heartbeat, claim `inbox`. Claiming is idempotent: each feedback event moves from
`queued`/`delivered`/`failed` to `processing` once. Do not call `--claim` again
for the same turn. For each claimed event:

1. Read its revision, path, line range, excerpt, and suggestion.
2. Inspect the current source and the code at that revision.
3. Answer the actual question or make the requested change.
4. Add a revision if the code changed.
5. Reply with the outcome, then resolve only when the item is genuinely handled.

```sh
python3 <state-tool> respond --state .review/auth.json \
  --change auth-identity --annotation a-1234567890 \
  --body 'I changed the empty-token path to return None and added the branching caller test.' \
  --resolve
```

Do not resolve a user question without an answer. Do not resolve a requested
change until the current revision contains the change or the user explicitly
agreed to defer it. A deferred decision must remain open or be recorded through
a reply that states the agreed outcome.

The frontend writes user feedback directly into the same record. It sets an
actionable item to open and moves the change to `feedback`. The helper refuses
`accepted` while actionable user feedback remains open.

User feedback carries a delivery record shown in the UI: `queued`, `delivered`,
`processing`, `answered`, or `failed`. A reply from the Agent marks the related
delivery records `answered`. If an Agent turn is interrupted after claiming,
`inbox --claim` can reclaim stale `processing` events after one hour;
`--retry-processing` forces that recovery explicitly.

File and hunk acceptance belongs to the revision that was reviewed. When code
changes materially, append a new revision; old decisions remain visible on the
old revision but do not mark the new code reviewed.

## Keep the Agent listener connected

The UI talks back to the Agent. The local review server first persists the
feedback, then enqueues a wake message for this same Codex thread with the
supported `codex queue --thread <id> --message <text>` command. A heartbeat
automation is the fallback when the app-server is restarting or a queued wake is
missed.

The Agent owns both sides. Never ask the user to start, restart, or repair the
listener. For every new or resumed review:

1. Resolve the current thread from `CODEX_THREAD_ID`, or use `list_threads` and
   select the active Codex thread whose `cwd` is this repository. Do not guess
   between multiple active threads.
2. Inspect the persisted bridge:

   ```sh
   python3 <state-tool> listen --state .review/auth.json --action status --json
   ```

3. Create or reactivate the heartbeat with the `automation_update` tool. When
   creating it, pass `mode: create`, `kind: heartbeat`, `destination: thread`,
   `targetThreadId: <current-thread>`, `status: ACTIVE`, and a stable name such
   as `Review With Me · .review/auth.json`. Use
   `rrule: FREQ=MINUTELY;INTERVAL=10`; direct feedback is delivered immediately,
   so this is only the fallback cadence. The prompt must tell the heartbeat to:

   - read `listen --action status --json` first;
   - if paused, use its stored `automation_id` with `automation_update` to pause
     that heartbeat, then stop silently;
   - run `inbox --claim --json` and stop silently when no events exist;
   - otherwise follow this skill, answer each claimed event, and stay quiet
     unless feedback was handled or the heartbeat failed.

   If the listener already records an `automation_id`, update that automation
   with `mode: update` and the same `name`, `prompt`, `rrule`, `status`,
   `targetThreadId`, and `id` instead of creating a duplicate. If the tool does
   not return an id, identify the newly created entry under
   `~/.codex/automations` by its stable name and target thread. Never invent an
   id.

4. Activate the local listener and persist the automation identity:

   ```sh
   python3 <state-tool> listen --state .review/auth.json --action resume \
     --thread-id "$CODEX_THREAD_ID" \
     --automation-id '<automation-id>' \
     --automation-name 'Review With Me · .review/auth.json'
   ```

5. Start the frontend as described below and give the user its URL.

When the reviewer presses **停止监听**, the UI sets the listener to `paused`.
This stops new UI wake messages without killing the local diff server. Do not
auto-resume after a server restart. If the user later asks to continue in the
Agent, reactivate the automation, run `listen --action resume` with its stored
thread/automation identity, then claim any feedback that accumulated while
paused.

If `automation_update` is unavailable, still configure the direct queue bridge
and state plainly that only the fallback schedule is unavailable. Never invent a
successful heartbeat. When an immediate queue attempt fails but a heartbeat is
registered, the listener becomes `degraded`; the heartbeat must claim queued or
failed events and try to restore direct delivery on a later Agent turn.

## Open the frontend automatically

The Agent owns the frontend lifecycle. Never ask the user to run, restart, or
troubleshoot it. As soon as the listener is configured, and again after a batch
of edits, start the server yourself in a reusable background or long-running PTY
session:

```sh
python3 <state-tool> serve --state .review/auth.json --port 0
```

Use `--port 0` so the helper chooses an available loopback port. Read the printed
`Review frontend: http://127.0.0.1:<port>` line, verify
`curl -fsS http://127.0.0.1:<port>/api/state` succeeds, then give the user the
working URL as part of the review update. Do not merely print the launch command
and stop.

The persistent server must be able to bind loopback and let its `codex queue`
subprocess reach the local Codex app state. If the sandbox blocks either
operation, request the needed approval and launch it yourself; do not ask the
user to run or nurse the process.

On every later review turn, check the saved session or probe the URL again. If
the server exited, restart it automatically and send the new URL. Keep one
review server per record rather than leaving duplicate servers running.
Restarting the server preserves a paused listener; agent-side resume remains an
explicit action.

The shipped React bundle is fully offline and precompressed: no npm install or
network request is needed at review time. It is under 0.5 MiB on disk. The page
embeds a random mutation token in a meta tag; do not share the URL or token.

The interface provides:

- a code-first canvas that gives the diff the full workspace width without
  requiring fullscreen, with review progress and the current semantic unit in
  one compact header;
- a semantic change map and a rationale/annotation inspector as on-demand side
  sheets, opened with `M` and `C`, so neither panel permanently narrows the
  diff; both remain usable as drawers at tablet and mobile widths;
- Pierre Diffs rendering, syntax highlighting, split/unified modes, context
  expansion, previous/next hunk navigation with `K` and `J`, and previous/next
  semantic-unit navigation in the canvas header;
- per-round and cumulative diffs across revisions;
- inline line/range annotations and file-level annotations;
- per-file and per-hunk acceptance controls, with pending files disappearing
  from the default review path and filtered items kept for review under “全部”;
- suggested code, replies, resolve, dismiss, and reopen actions;
- live Agent-listener status, immediate feedback delivery, and a stop control;
- per-message delivery state from queued through answered or failed;
- summaries, rationale, revision history, and warnings about newer worktree
  changes;

The UI is intentionally not a commit browser. If an Agent wants to show an
earlier state, it must retain the revision or snapshot that state.

## Helper reference

```sh
python3 <state-tool> show --state .review/auth.json --change auth-identity
python3 <state-tool> show --state .review/auth.json --json
python3 <state-tool> annotate --help
python3 <state-tool> items --state .review/auth.json --change auth-identity --json
python3 <state-tool> item --help
python3 <state-tool> revise --help
python3 <state-tool> serve --help
python3 <state-tool> listen --state .review/auth.json --action status --json
python3 <state-tool> inbox --state .review/auth.json --claim --json
python3 <state-tool> inbox --state .review/auth.json --claim --retry-processing --json
```

Useful mutation commands:

- `init`: create one record and fix its base commit.
- `add`: create a semantic unit and its first stable revision.
- `revise`: append a stable follow-up revision.
- `update`: change title, summary, rationale, or paths without losing history.
- `status`: set the review state, optionally recording `superseded_by`.
- `annotate`: add an agent explanation at a revision, file, or line range.
- `items`: list revision-bound files and changed blocks with their review state.
- `item`: accept, exclude, or reopen a file or changed block; exclusions need a
  reason and remain visible.
- `respond`: append an agent reply and optionally resolve an item.
- `resolve`: change an annotation between `open`, `resolved`, and `dismissed`.

The state file is schema v3. The helper migrates schema v2 records, old per-file
`feedback` records, and missing annotation revision ids on load. The record
stays local by default; do not commit it or its snapshot refs unless the user
explicitly asks.

## Maintainer checks

The frontend source is in `scripts/web-src`, and the shipped bundle is in
`scripts/web/assets`. Rebuild only after source changes:

```sh
npm --prefix scripts/web-src run build
```

Run the helper tests without a NixOS rebuild or repository-wide build:

```sh
python3 -m unittest discover -s scripts/tests -v
```

## Related work

- [xdg: review-walkthrough](https://github.com/xdg/xdg-claude/blob/main/review-walkthrough/skills/review-walkthrough/SKILL.md): interactive pacing and resumable scope.
- [Trail of Bits: audit-context-building](https://github.com/trailofbits/skills/blob/main/plugins/audit-context-building/skills/audit-context-building/SKILL.md): understanding dependencies and assumptions before judging them.
