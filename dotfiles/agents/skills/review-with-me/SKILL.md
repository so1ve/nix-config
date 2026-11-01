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
python3 <state-tool> inbox --state .review/auth.json
```

Read open feedback before editing code. Re-read the relevant source and current
revision because an old explanation may no longer be true. Do not repeat a
previous walkthrough when the record already contains it.

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

At the start of every review turn, read `inbox`. For each feedback item:

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

## Open the frontend automatically

The Agent owns the frontend lifecycle. Never ask the user to run, restart, or
troubleshoot it. As soon as a review record is created or resumed, and again
after a batch of edits, start the server yourself in a reusable background or
long-running PTY session:

```sh
python3 <state-tool> serve --state .review/auth.json --port 0
```

Use `--port 0` so the helper chooses an available loopback port. Read the printed
`Review frontend: http://127.0.0.1:<port>` line, verify
`curl -fsS http://127.0.0.1:<port>/api/state` succeeds, then give the user the
working URL as part of the review update. Do not merely print the launch command
and stop.

On every later review turn, check the saved session or probe the URL again. If
the server exited, restart it automatically and send the new URL. Keep one
review server per record rather than leaving duplicate servers running.

The shipped React bundle is fully offline and precompressed: no npm install or
network request is needed at review time. It is under 0.5 MiB on disk. The page
embeds a random mutation token in a meta tag; do not share the URL or token.

The interface provides:

- a semantic change map with review progress and unmapped worktree changes;
- Pierre Diffs rendering, syntax highlighting, split/unified modes, context
  expansion, and previous/next hunk navigation with `K` and `J`;
- per-round and cumulative diffs across revisions;
- inline line/range annotations and file-level annotations;
- suggested code, replies, resolve, dismiss, and reopen actions;
- summaries, rationale, revision history, and warnings about newer worktree
  changes;
- compact drawers for tablet and mobile widths.

The UI is intentionally not a commit browser. If an Agent wants to show an
earlier state, it must retain the revision or snapshot that state.

## Helper reference

```sh
python3 <state-tool> show --state .review/auth.json --change auth-identity
python3 <state-tool> show --state .review/auth.json --json
python3 <state-tool> annotate --help
python3 <state-tool> revise --help
python3 <state-tool> serve --help
```

Useful mutation commands:

- `init`: create one record and fix its base commit.
- `add`: create a semantic unit and its first stable revision.
- `revise`: append a stable follow-up revision.
- `update`: change title, summary, rationale, or paths without losing history.
- `status`: set the review state, optionally recording `superseded_by`.
- `annotate`: add an agent explanation at a revision, file, or line range.
- `respond`: append an agent reply and optionally resolve an item.
- `resolve`: change an annotation between `open`, `resolved`, and `dismissed`.

The state file is schema v2. The helper migrates the old per-file `feedback`
records and missing annotation revision ids on load. The record stays local by
default; do not commit it or its snapshot refs unless the user explicitly asks.

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
