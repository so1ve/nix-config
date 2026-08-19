---
name: refactor-for-simplicity
description: Review and refactor codebases across languages toward simpler, deeper modules with smaller production interfaces, cohesive implementations, direct control flow, and fewer moving parts. Use for broad simplification, overengineering cleanup, API-shape improvements, clean breaking API redesigns in actively evolving or not-yet-usable projects, removal of shallow abstractions or test-driven API distortion, and audits of redundant defensive logic, speculative fallbacks, low-value error translations, unused state, or compatibility code. Preserve intended behavior and protections required by concrete external, security, persistence, concurrency, memory-safety, or irreversible-operation constraints. Do not use for ordinary narrowly scoped fixes unless explicitly invoked. Apply the mandatory Rust-specific review whenever Rust sources or Cargo manifests are in scope.
---

# Refactor for Simplicity

## Goal

Refactor the requested code toward the simplest cohesive design that preserves
intended behavior. Favor deep modules, small production interfaces, direct control
flow, and few moving parts. Delete code that is clearly unnecessary instead of
replacing it with another abstraction. Keep changes within the requested scope and
preserve unrelated user changes.

Security, persistence, external I/O, compatibility, and other necessary protections
constrain the refactor; they do not justify speculative complexity inside trusted
paths.

## Understand the design and constraints

Before editing:

1. Read active repository instructions and relevant architecture, protocol, schema,
   and API definitions.
2. Trace production entry points, callers, and data and control flow to identify the
   module's actual responsibilities and required sequencing.
3. Determine the project's lifecycle and compatibility commitments, including whether
   it is actively evolving, usable or released, and consumed outside jointly
   maintained code.
4. Distinguish jointly maintained internal contracts from untrusted ingress, public
   APIs, separately versioned components, persistent formats, operating-system
   protocols, and third-party services.
5. Trace producers and consumers before deleting validation or an apparently unused
   API. Account for serialization, reflection, generated code, plugin registration,
   and documented public consumers when the project uses them.

For jointly maintained components, trust the defined protocol, status mapping, and
type contract. A compatible third-party implementation is responsible for satisfying
that protocol. Keep decoding of external data, but do not add post-decode field
discriminators, duplicate status checks, or fallback branches solely in case a sibling
component violates the shared contract.

## Separate requirements from speculation

Retain logic required by concrete external or safety constraints:

- secrets, keys, credentials, authentication, and authorization;
- decoding, authentication, integrity, and versioning of untrusted ciphertext or
  external data;
- file permissions, destructive overwrites, and irreversible operations;
- realistic filesystem, network, process, device, and platform-protocol failures;
- public APIs with an established compatibility commitment and separately versioned
  compatibility surfaces;
- memory safety, concurrency safety, persistent state, transactions, migrations, and
  data integrity;
- retries with a defined transient failure model, idempotency policy, and useful
  limit or backoff.

Remove logic that has no current requirement:

- deliberately nonsensical inputs with no realistic producer;
- internally generated data unexpectedly violating enforced invariants;
- another jointly maintained component violating the shared protocol;
- unreachable branches kept only for hypothetical future changes;
- speculative compatibility, degradation, warning, or retry paths with no current
  consumer or failure model;
- prechecks that downstream operations already perform naturally, unless the precheck
  improves safety, atomicity, or diagnosis;
- redundant database writes, cache updates, or state assignments with no observable
  effect;
- placeholder variants, empty modules or interfaces, and unused extension points.

When the classification is unclear, trace the real data and control flow. Do not keep
or delete a check based only on its syntax.

## Audit systematically

Inspect production code, tests, manifests, and call sites for:

- `if`, `match` or `switch`, `let-else`, guard clauses, and early returns;
- optional and result fallbacks, presence or success predicates, broad catches, and
  default values;
- error wrapping, context addition, repeated translation, and recovery branches;
- retry, warning, fallback, compatibility, and degradation logic;
- internal channel closure, task cancellation, thread exit, and join handling;
- duplicate protocol, schema, discriminator, and status validation;
- repeated or no-op state writes, caches, tokens, flags, broad dispatch tables, event
  subscriptions, and invalidation paths;
- unused fields, methods, variants, derives, dependencies, feature flags, wrappers,
  traits, and interfaces;
- production abstractions that exist only for redundant tests.

Use language-appropriate searches to build an inventory, then inspect each use in
context. Do not limit the review to one macro, helper, or error type.

## Refactor directly

- Enforce each constraint once, at the boundary best positioned to enforce it.
- Treat a failure of an internally guaranteed state as an invariant violation. Use
  the language's idiomatic fail-fast or assertion mechanism instead of inventing a
  recoverable business error.
- Prefer a bounded local redesign when the current structure causes special cases to
  accumulate. Do not preserve a poor shape merely to minimize the diff.
- When repository evidence shows active development without a stable compatibility
  commitment, or the project is not yet usable, prefer clean breaking API changes
  when they improve the design. Update all jointly maintained callers, tests,
  documentation, and configuration atomically instead of adding adapters, deprecation
  shims, or legacy paths. Preserve separately versioned protocols, persistent formats,
  and deployed integrations unless their migration is in scope.
- Keep modules deep: expose the smallest interface callers actually need and hide a
  cohesive implementation behind it. Do not expose internal state, knobs, parameters,
  or intermediate steps for testing or wiring convenience.
- Delete shallow abstractions that neither reduce caller complexity nor represent a
  stable interface or substitution point, including one-line wrappers, pass-through
  helpers, redundant state objects, and single-implementation interfaces. Inline
  single-use local logic when that makes the containing flow clearer.
- Use the fewest moving parts that preserve behavior. Every cache, token, flag,
  compatibility branch, and broad dispatch table must serve a current requirement.
- Remove unused fields, methods, variants, derives, dependencies, wrappers, and state
  writes together with obsolete tests.
- For cached or event-driven state, subscribe to the actual source of change and keep
  invalidation or refresh logic next to the state it maintains. Do not use broad,
  unrelated events as proxy invalidation signals.
- Make mutation visible in the API. Do not hide ordinary exclusive mutation behind
  shared or interior mutability.
- Propagate already clear errors directly. Add context only when it names a concrete
  external operation or target and materially improves diagnosis.
- Do not distort production APIs or implementation structure to support tests. Do not
  change production visibility, add test-only production entry points, or extract a
  single-use step from a cohesive one-pass implementation solely so a unit test can
  call it directly. Test through the existing production API. Extract a helper only
  when it is a sound production abstraction independent of testing; keep genuinely
  test-only helpers in test code.
- Keep tests for observable behavior, protocol semantics, security properties,
  persistence, and realistic failure modes. Remove tests of deleted defensive
  branches, meaningless wrappers, and language or standard-library behavior.

## Rust-specific review

Apply this section whenever Rust sources or Cargo manifests are in scope.

Explicitly inspect:

- `ensure!`, `bail!`, `if`, `match`, `let-else`, and early-return branches;
- `Option` and `Result` fallbacks, including `unwrap_or`, `unwrap_or_else`,
  `is_some`, `is_none`, `is_ok`, and `is_err`;
- `context()` and `with_context()` calls and repeated conversions into `anyhow` or
  custom error types;
- channel sends and receives, task cancellation, thread joins, and poisoned-state
  handling;
- `RefCell`, `Cell`, `Mutex`, `RwLock`, and other interior mutability;
- traits and wrapper types with one implementation or consumer;
- unused fields, variants, methods, derives, Cargo features, and dependencies;
- item visibility, especially `pub(crate)`, `pub(super)`, and `pub(in ...)`, and the
  concrete production call sites that require it;
- production APIs or abstractions retained only for tests.

Apply these Rust rules:

- Prefer `unwrap()` or a specific `expect()` when failure means a genuine internal
  invariant was violated. Do not translate that state into a recoverable business
  error.
- For a genuinely missing required external value, prefer clear `let-else` control
  flow with `bail!`.
- Add `context()` or `with_context()` only when it identifies a concrete external
  operation or target. Otherwise propagate with `?`.
- Treat lifecycle states guaranteed by internal threads, tasks, channels, and types as
  invariants. Preserve recoverable handling when closure, cancellation, or poisoning
  is part of a public or external protocol.
- Prefer `&mut self` when an operation mutates an object. Do not use `RefCell` merely
  to retain an `&self` signature. Keep interior or synchronized mutability only when
  shared mutation is genuinely required.
- Remove fine-grained traits with one implementation and no real substitution need.
- Keep implementation details private with no visibility modifier and use plain `pub`
  for intentional public APIs. Use `pub(crate)`, `pub(super)`, or `pub(in ...)` only
  when a concrete production consumer requires that exact internal boundary, never as
  a habitual compromise or merely to expose an item to tests.
- Do not reshape production APIs solely for tests. Do not extract a one-call helper
  from a cohesive flow merely so a unit test can invoke it directly. Exercise the
  behavior through the existing production API; keep genuinely test-only helpers
  inside `#[cfg(test)]` modules.
- Import a trait normally when no name conflict exists; do not use `as _`
  unnecessarily.
- Before every explicit `return` or implicit tail-return expression, insert a blank
  line when another statement exists at the same block level. A block containing only
  its return expression needs no additional blank line.

## Verify and report

1. Re-search changed symbols and removed patterns to catch stale consumers and tests.
2. Verify changed behavior through the actual production surface as callers use it.
   Prefer realistic smoke or integration tests over direct tests of internal steps
   when the latter would require reshaping the production API.
3. Run the repository's formatter, static analysis, and relevant tests, subject to
   active execution and build constraints. Prefer established project commands. If a
   required command is not permitted, provide the exact command for the user instead
   of claiming it passed.
4. Review the final diff for behavior changes, weakened boundaries, unrelated edits,
   and newly unused code.
5. Report separately:
   - unnecessary logic removed;
   - reviewed protections retained and the concrete requirement each satisfies;
   - formatting, static-analysis, and test results, including anything not run.

Do not commit, push, publish, or communicate externally unless the user explicitly
requests that separate action.
