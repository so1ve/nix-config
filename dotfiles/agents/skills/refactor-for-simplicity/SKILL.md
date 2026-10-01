---
name: refactor-for-simplicity
description: Review and refactor codebases across languages toward deeper modules, smaller production interfaces, direct control flow, and fewer moving parts. Use for broad simplification, overengineering cleanup, API redesigns in actively evolving projects, removal of shallow abstractions or test-driven API distortion, cleanup of low-value or redundant tests (including source-text change detectors), and audits of speculative defenses, fallbacks, error translations, unused state, or compatibility code. Preserve intended behavior and protections required by concrete external, security, persistence, concurrency, memory-safety, or irreversible-operation constraints. Do not use for ordinary narrowly scoped fixes unless explicitly invoked. Apply the mandatory Rust-specific review whenever Rust sources or Cargo manifests are in scope.
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
- production abstractions that exist only for redundant tests;
- source-text assertions, implementation-coupled mocks, tautological expectations,
  vacuous assertions, oversized snapshots, and duplicate test scenarios.

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

## Simplify tests

Always audit tests within the requested scope, even when the suite passes. Actually
delete, consolidate, or rewrite low-value tests; do not merely flag them or leave
them in place because they are green. Do not create these patterns in replacements.
Test count and line coverage are not evidence of useful regression protection.

For each suspect test, identify the requirement it protects, the production surface
it exercises, and a plausible incorrect behavior its assertion would catch. Also
ask whether a behavior-preserving implementation change would break it. Use these
questions to inspect the test, not to impose paperwork on every existing test.

### Remove change detectors and tests without a useful oracle

- **Source-text change detectors:** tests that read production source and use
  substring matching, regexes, line comparisons, source hashes, or AST inspection
  merely to assert that a name, call, branch, annotation, or code fragment exists
  or is absent. Examples include `assert "authorize(" in source` and asserting
  that a deleted helper's name no longer appears. These prove spelling or shape,
  not that the reachable production path works. Search for stale symbols as a
  one-time refactor check; do not turn that search into a permanent regression test.
  If authorization matters, exercise an unauthorized request and assert rejection
  and absence of the protected side effect.
- **Implementation replicas and tautologies:** tests that copy the production
  algorithm to calculate the expected result, call the same implementation for
  both actual and expected values, compare a value with itself, or derive the
  expected value from the result under test. Use independently specified examples,
  reference vectors, or meaningful properties instead. Independent reference
  implementations, differential tests, and round-trip properties can be valuable;
  do not confuse them with duplicating the same logic and the same possible bug.
- **Self-fulfilling mocks:** tests that replace the behavior under test, then assert
  the mock's configured return value or invocation without exercising real
  production decisions. Also remove assertions that merely replay internal helper
  calls, incidental order or counts, or redundant reads of stubbed data. Assert
  resulting output or state; retain interaction assertions when the external
  action, non-action, count, or sequence is itself a requirement.
- **Vacuous success:** unconditional assertions, assertions on fixture setup alone,
  swallowed exceptions, or conditional assertions that allow the relevant case to
  finish without checking its outcome. A mere non-null result, successful import,
  or absence of an exception is insufficient when the claimed behavior needs a
  stronger assertion. Keep such smoke tests when startup, loading, or successful
  completion is the actual contract; assertion syntax alone does not decide value.
- **Language and dependency retests:** tests of standard-library behavior, trivial
  accessors, pass-through wrappers, or defaults with no application requirement.
  Retain small tests when they enforce a real public contract, mapping, or policy.
- **Unreachable defensive scenarios:** tests that corrupt private state, bypass
  enforced constructors or types, or make jointly maintained siblings violate
  guaranteed contracts solely to exercise speculative recovery. Remove them with
  the unnecessary branches. Preserve malformed external-input tests, realistic
  failures, and meaningful invariant, concurrency, and fault-injection tests.
- **Speculative compatibility:** tests of old API shapes, legacy aliases, fallback
  formats, deprecated modes, or hypothetical third-party consumers when there is
  no current consumer, deployed integration, persistent-data migration need, or
  established compatibility commitment. Delete them with the obsolete paths; do
  not retain shims or parallel implementations just to satisfy these tests.
- **Excessive safety testing:** repeated checks of the same constraint after its
  enforcing boundary, arbitrary combinations of invalid internal states, or
  imagined attack and failure scenarios with no reachable ingress or concrete
  threat model. Remove them; do not add production guards to make these scenarios
  recoverable. A test labeled "security", "safety", or "compatibility" earns no
  exemption: identify the actual boundary, requirement, and distinct failure it
  protects.

Source inspection is legitimate when source is the product under test (a compiler,
linter, code generator, or codemod), or a concrete architecture or security rule is
itself a maintained requirement. Text assertions on actual CLI output, serialized
formats, rendered content, or generated artifacts can also protect real contracts.
Keep those checks focused on the requirement; never substitute source matching for
behavioral validation merely because executing the production path is inconvenient.

### Reduce redundant cases and test machinery

- Consolidate cases with the same behavioral requirement and failure signal when
  extra inputs add no distinct boundary, equivalence class, or regression. Keep
  historical bug cases that remain applicable and meaningful boundary cases.
  Remove obsolete regression cases when their feature or contract is intentionally
  removed. Similar setup is not proof of redundancy; a focused unit test and an
  integration test can protect different failure modes even when they overlap in
  executed code.
- Replace broad snapshots of private objects, entire component trees, or incidental
  formatting with focused assertions when they mostly create review noise. Retain
  deterministic, reviewable golden files, visual baselines, and snapshots of real
  output or compatibility contracts. Inspect failures before updating a baseline;
  do not regenerate it simply to make the suite pass.
- Delete fixtures, mocks, helpers, dependencies, and runner configuration made
  unused by test removal, after checking their other consumers. Simplify custom
  harnesses, inheritance, builders, and parameter matrices that obscure a small
  number of behaviors. Prefer explicit inputs and expectations; retain shared
  setup that makes realistic tests clearer. Do not force DRY at the expense of
  readability or ban useful parameterized, property-based, or fuzz testing.

### Preserve protection while cleaning up

Replace a bad test only when it is the sole protection for a concrete current
requirement, and exercise that requirement through the existing production surface.
If it protects no requirement or only duplicates adequate coverage, delete it
without a one-for-one replacement. Retain necessary coverage of real security
boundaries, in-use persistent formats, realistic external failures, and established
compatibility commitments. Do not expand safety or compatibility testing to
hypothetical requirements during cleanup. Do not widen production visibility or
add abstractions solely to make a replacement test possible.

Do not weaken an assertion, skip a failing test, or delete a regression case merely
to get a green suite. Investigate whether the failure is a real regression, an
authorized contract change, or coupling to obsolete implementation details. Resolve
it accordingly; do not mechanically mirror the new implementation in the test.

These rules draw on:

- [Google: Change-Detector Tests Considered Harmful](https://testing.googleblog.com/2015/01/testing-on-toilet-change-detector-tests.html).
- [Software Engineering at Google: Unit Testing](https://abseil.io/resources/swe-book/html/ch12.html) and [Test Doubles](https://abseil.io/resources/swe-book/html/ch13.html).
- [Microsoft: Unit testing best practices](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-best-practices).
- [Jest: Snapshot testing best practices](https://jestjs.io/docs/snapshot-testing#best-practices).
- [Martin Fowler: Test Coverage](https://martinfowler.com/bliki/TestCoverage.html).

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
   - tests deleted, consolidated, or rewritten, the low-value patterns removed, and
     the meaningful behavioral protection retained or added;
   - reviewed protections retained and the concrete requirement each satisfies;
   - formatting, static-analysis, and test results, including anything not run.

Do not commit, push, publish, or communicate externally unless the user explicitly
requests that separate action.
