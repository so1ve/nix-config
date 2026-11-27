---
name: refactor-for-simplicity
description: Review and refactor production architecture and code to simplify responsibilities, interfaces, control flow, state, and dependencies. Use for structural simplification, overengineering cleanup, migrations, or production design reviews. Remove mechanisms unsupported by current requirements, migrate affected callers, and preserve required behavior and external contracts. Do not use for standalone naming reviews, test-suite cleanup, or ordinary narrowly scoped fixes unless explicitly invoked.
---

# Refactor for Simplicity

Make the requested code easier to understand and change. Favor fewer concepts,
state sources, and branches that a maintainer has to follow. Choose the right
responsibilities and interfaces before minimizing the diff, while preserving
required behavior, performance, and unrelated user changes.

This skill owns production design, code structure, and required caller
migrations. Route adjacent concerns to their specialist skills when in scope
(read their full instructions from the skill catalog before applying them):
[Clarify Code Names](../clarify-code-names/SKILL.md) for naming reviews,
[Improve Test Suite](../improve-test-suite/SKILL.md) for test-suite cleanup,
[Design UI](../design-ui/SKILL.md) for visual/UX polish, and
[Speak Plainly](../speak-plainly/SKILL.md) for prose or README rewrites.
Ordinary caller, name, comment, and test updates needed to finish a production
refactor remain part of this skill.

## 1. Define scope and guardrails

Read repository instructions and trace the relevant production entry points,
callers, state owners, dependencies, and tests. Use the user's confirmed
deployment, lifecycle, caller, and concurrency facts; question them only when
code, configuration, or an explicit contract contradicts them, and point to the
conflict. Future deployment changes are not current requirements.

Briefly state:

- **Must stay**: behavior, supported inputs, error handling, performance
  characteristics, public protocols, compatibility commitments, and persistent
  data.
- **Must change**: responsibilities, interfaces, data flow, and dependencies.
- **Must go**: obsolete paths, speculative checks, wrappers, and legacy debt.
- **Done when**: callers use the new structure, old paths are gone, and relevant
  behavior checks pass.

For a general simplification request, choose a concrete target from the request
and code, state it briefly, and proceed with authorized edits. For review-only
requests, report findings without editing. Keep a narrow bug fix focused on its
cause, even if that touches multiple lines. Create plan files, inventories,
scores, approval tables, or proof records only when the task requires them.

Hold three hard guardrails while shrinking code:

- **No readability regressions**: cut real complexity, not clarity. Only shorten
  expressions when the result is at least as readable as the original.
- **No silent performance regressions**: preserve intentional fast paths and
  optimizations; watch for extra allocations, clones, lookups, or dispatch
  overhead on hot paths.
- **No blind flattening**: keep module or file boundaries that genuinely make
  the domain easier to navigate.

## 2. Diagnose what to cut or redesign

Trace a supported operation end to end—from production entry point to result,
state changes, and failures—including mechanisms the user did not name. Inspect
each layer through five lenses:

### Unnecessary mechanisms and overengineering

For each layer, state source, dependency, or coordination step, ask:

1. Which current behavior, contract, or supported failure would break without
   it, and which caller or boundary needs it?
2. Could direct code, a domain type, or the existing runtime/framework satisfy
   the same need with fewer concepts?
3. What configuration, coordination, storage, deployment, or recovery cost does
   it impose, and does a current benefit justify that cost?
4. Does its supporting code solve a domain problem, or only a problem created by
   another unnecessary mechanism?

Compare callers and implementations together, including everything required to
run them. Future flexibility, pattern names ("decoupled", "scalable", "robust"),
or the mere existence of callers and passing tests do not justify a mechanism.
Agent-created code, tests, documents, and plans do not create product
requirements—judge them against the original task.

Read [Overengineering examples](references/overengineering.md) when reviewing
architecture or questionable mechanisms. Treat matches as candidates to inspect,
not automatic deletions.

Never create or retain **AI-invented evidence, provenance, confidence, receipt,
or forensics layers** around ordinary business operations (proof wrappers plus
their hashes, snapshots, registries, ledgers, validators, storage, retention,
reconciliation, or execution gates). Return domain results and errors directly,
migrate callers, delete the entire chain and its mechanism-only tests/docs, and
do not rename or shrink it into a smaller proof framework.

### Trust boundaries and defensive bloat

- Validate raw input once where it enters the system; internal callers trust the
  resulting type or contract. Re-validate only at a new trust boundary or after
  a state change invalidates the check. (A TypeScript annotation does not
  validate external JSON.)
- Treat components maintained together under one protocol as one implementation.
  Decode external wire data, but do not invent defensive checks or recovery
  paths for your own component breaking a contract it enforces.
- Preserve checks for secrets, authentication, permissions, untrusted input,
  external I/O, memory safety, concurrency, persistence, and irreversible
  operations. Choose cryptography for the protocol; compare ordinary public IDs
  and status values normally. Do not narrow supported inputs, trim credentials,
  hide errors, or return fake success.
- Fail fast on broken internal invariants with the language's normal assertion
  or panic mechanism instead of turning them into recoverable business errors or
  writing speculative guards for impossible states.
- Propagate clear errors directly; handle or log where code can decide how to
  recover or report. Add context only when it names an external operation or
  target. Retry only recoverable failures, with bounded limits and explicit
  side-effect/idempotency rules.
- Keep one source of truth. Keep caches or derived state only when measured
  performance, history, or recovery requires them.

### Built-ins, dependencies, and hand-rolled code

- Prefer language/runtime built-ins, standard library features, and existing
  frameworks over custom helpers (for example, modern runtime arg/color/fetch
  APIs instead of hand-rolled equivalents). Check library behavior when
  uncertain and add only what is missing.
- Replace fragile hand-rolled parsers, giant regexes, and ad-hoc utilities with
  structured or mature library solutions when the capability warrants it.
- After upgrading a dependency or runtime, actually adopt its new capabilities
  and delete the hand-written workarounds and old runtime idioms they replace.

### Interfaces and API coherence

- Provide one canonical way to perform each task. Eliminate overlapping
  concepts, duplicate invocation styles, and parallel extension mechanisms.
- Prefer orthogonal, composable primitives over accumulating mode flags,
  hardcoded special cases, or long `instanceof`/tag dispatch chains.
- Reject abstractions that make production callers more verbose, force
  ceremonial type gymnastics, or obscure mutation. Keep abstractions that name a
  real domain concept, manage resource lifetimes, hide real complexity, or
  provide a needed substitution point.

### Module boundaries and reading flow

- Keep modules deep: put related implementation behind a small interface and
  expose only what production callers need.
- Split oversized catch-all files (such as monolithic `types.ts` dumping grounds
  or multi-responsibility handlers/components) so definitions live with the
  logic that owns them.
- Merge pointless fragments, unused sub-packages, and single-line pass-through
  wrappers; eliminate multi-hop indirection across modules.
- Keep code easy to scan: co-locate implementations near their types, avoid
  duplicate default/schema definitions, keep sensible blank-line separation, and
  remove obvious or noisy comments.

## 3. Execute the refactor

- **Fix at the owning layer**: locate responsibility by data ownership, the
  boundary that can enforce the invariant, and production callers' contracts.
  Prefer a larger structural refactor at the right layer over a small workaround
  (caller guards, mode flags, wrappers, or error suppression) at the wrong
  layer. Judge the result by what a maintainer must understand and change next.
- **Make clean breaks, not legacy debt**: within authorized scope, change
  internal modules, types, signatures, and directories together—implementation,
  entry points, co-maintained callers, config, docs, and tests. Preserve
  compatibility only for real external consumers, separately versioned
  protocols, persistent formats, and active deployment transitions. Never keep
  aliases, adapters, fallback shims, old runtime idioms, commented-out code, or
  deletion placeholders just to avoid updating internal callers.
- **Trace before deleting**: check serialization, reflection, generated code,
  plugin registration, and documented public consumers before removing an API or
  check. Preserve user edits, production data, and deployed migration history.
- **Keep tests aligned without polluting production APIs**: update affected
  behavior tests through production entry points and delete tests/fixtures that
  existed only for discarded mechanisms. Do not expose private helpers or alter
  production APIs just for tests.
- **Language guides**: load the matching reference when those sources are in
  scope:
  - Rust / Cargo: [Rust-specific review](references/rust.md)
  - TypeScript / JavaScript / Node: [TypeScript-specific review](references/typescript.md)

## 4. Verify and report

1. **Behavior and performance**: run relevant existing tests, add a test only
   for a meaningful gap in required behavior (through the production API; smoke
   or integration tests for private steps), and sanity-check hot-path overhead
   if control flow or data representation changed.
2. **Complete migration**: search for old symbols, dependencies, aliases, shims,
   and duplicate paths, and inspect matches to confirm nothing obsolete remains.
   (Do not turn this one-time check into a source-text regression test.)
3. **Checks**: run the project's formatter, static analysis, and relevant tests
   within execution and build permissions. If a required command is not allowed,
   give the user the exact command and note it was not run.
4. **Single diff self-review**: inspect the diff once for regressions, weakened
   boundary checks, readability/performance regressions, remaining defensive
   bloat, missed callers, and unrelated edits. Verify that the changed rule sits
   at the right layer and that removed mechanisms were deleted rather than
   renamed or re-wrapped.

Check reported issues against reachable code paths and confirmed facts—a
severity label does not establish a defect. Fix real failures and repeat only
affected checks. Stop once the required behavior and structure are in place; do
not invent review loops. If the code needs no change, say so.

Report concisely: what changed, what old paths/mechanisms were removed, why any
remaining complexity is necessary, which behavior checks ran (or remained
untested), and how modified tests still protect behavior. Never commit, push,
publish, or communicate externally without an explicit request.
