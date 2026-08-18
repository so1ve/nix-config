---
name: refactor-contract-boundaries
description: Review and refactor codebases across languages by trusting jointly maintained internal contracts, removing redundant defensive checks, speculative fallbacks, low-value error translations, unused abstractions, and dead state while preserving security, external I/O, persistence, permissions, memory-safety, and irreversible-operation boundaries. Use for broad simplification, defensive-code audits, contract-boundary refactors, or cleanup of overengineered code; do not use for ordinary narrowly scoped fixes unless explicitly invoked. Apply the mandatory Rust-specific review whenever Rust sources or Cargo manifests are in scope.
---

# Refactor Contract Boundaries

## Goal

Simplify the requested code without weakening real boundaries or changing intended
behavior. Treat jointly maintained components as one implementation when repository
evidence establishes shared ownership and a shared contract. Do not assume that
co-location alone proves an internal contract.

Delete code that is clearly unnecessary instead of replacing it with another
abstraction. Keep changes within the requested scope and preserve unrelated user
changes.

## Establish the contract map

Before editing:

1. Read active repository instructions and relevant architecture, protocol, schema,
   and API definitions.
2. Identify which clients, servers, protocol types, and internal modules are
   maintained and released together.
3. Identify actual external surfaces, including untrusted ingress, public library
   APIs, separately versioned components, persistent formats, operating-system
   protocols, and third-party services.
4. Trace producers and consumers before deleting validation or an apparently unused
   API. Account for serialization, reflection, generated code, plugin registration,
   and documented public consumers when the project uses them.

For jointly maintained components, trust the defined protocol, status mapping, and
type contract. A compatible third-party implementation is responsible for satisfying
that protocol. Keep decoding of external data, but do not add post-decode field
discriminators, duplicate status checks, or fallback branches solely in case a sibling
component violates the shared contract.

## Classify every safeguard

Retain logic that protects a real boundary:

- secrets, keys, credentials, authentication, and authorization;
- decoding, authentication, integrity, and versioning of untrusted ciphertext or
  external data;
- file permissions, destructive overwrites, and irreversible operations;
- realistic filesystem, network, process, device, and platform-protocol failures;
- public or separately versioned compatibility surfaces;
- memory safety, concurrency safety, persistent state, transactions, migrations, and
  data integrity;
- retries with a defined transient failure model, idempotency policy, and useful
  limit or backoff.

Remove logic that only protects against an imaginary boundary:

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
- repeated or no-op state writes;
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
- Inline simple conversions, calculations, and local logic used only once.
- Remove single-implementation interfaces or traits when there is no real substitution
  requirement or stable external boundary.
- Remove unused fields, methods, variants, derives, dependencies, wrappers, and state
  writes together with obsolete tests.
- Make mutation visible in the API. Do not hide ordinary exclusive mutation behind
  shared or interior mutability.
- Propagate already clear errors directly. Add context only when it names a concrete
  external operation or target and materially improves diagnosis.
- Do not distort production APIs to support tests. Keep test-only helpers in test code.
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
- Do not reshape production APIs solely for tests. Put test-only helpers inside test
  modules.
- Import a trait normally when no name conflict exists; do not use `as _`
  unnecessarily.
- Before every explicit `return` or implicit tail-return expression, insert a blank
  line when another statement exists at the same block level. A block containing only
  its return expression needs no additional blank line.

## Verify and report

1. Re-search changed symbols and removed patterns to catch stale consumers and tests.
2. Run the repository's formatter, static analysis, and relevant tests, subject to
   active execution and build constraints. Prefer established project commands. If a
   required command is not permitted, provide the exact command for the user instead
   of claiming it passed.
3. Review the final diff for behavior changes, weakened boundaries, unrelated edits,
   and newly unused code.
4. Report separately:
   - unnecessary logic removed;
   - reviewed checks retained and the real boundary each protects;
   - formatting, static-analysis, and test results, including anything not run.

Do not commit, push, publish, or communicate externally unless the user explicitly
requests that separate action.
