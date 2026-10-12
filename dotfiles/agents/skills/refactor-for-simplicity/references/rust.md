# Rust-specific review

Apply this guide whenever Rust sources or Cargo manifests are in scope.

Inspect:

- `ensure!`, `bail!`, `if`, `match`, `let-else`, and early returns;
- `Option` and `Result` fallbacks, including `unwrap_or`, `unwrap_or_else`,
  `is_some`, `is_none`, `is_ok`, and `is_err`;
- `context()`, `with_context()`, and repeated conversions to `anyhow` or custom errors;
- channel sends and receives, cancellation, thread joins, and poisoned state;
- `RefCell`, `Cell`, `Mutex`, `RwLock`, and other interior mutability;
- traits and wrappers with one implementation or consumer;
- unused fields, variants, methods, derives, Cargo features, and dependencies;
- visibility such as `pub(crate)`, `pub(super)`, and `pub(in ...)`, and the production
  callers that need it;
- production APIs or abstractions kept only for tests.

Apply these rules:

- Use types, ownership, and constructors to express valid lifecycle states and
  remove repeated checks. A valid connection can still fail during I/O, so preserve
  its error result. Do not replace branches with `unwrap()` or `unsafe` just to
  shorten the code.
- Prefer `unwrap()` or a specific `expect()` when failure means an internal invariant
  was broken. Do not turn that failure into a recoverable business error.
- When a required external value is missing, prefer clear `let-else` control flow
  with `bail!`.
- Add `context()` or `with_context()` only when it names an external operation or
  target. Otherwise propagate the error with `?`.
- Rely on lifecycle states guaranteed by internal threads, tasks, channels, and
  types. Handle closure, cancellation, or poisoning as recoverable when a public
  or external protocol defines it that way.
- Prefer `&mut self` for mutation. Do not use `RefCell` just to keep an `&self`
  signature. Keep interior or synchronized mutability only when shared mutation
  is required.
- Remove small traits with one implementation and no needed substitution.
- Leave implementation details private and use plain `pub` for public APIs.
  Use `pub(crate)`, `pub(super)`, or `pub(in ...)` only when a production caller
  needs that boundary, never just to expose code to tests.
- Do not change production APIs just for tests or extract a helper merely to test
  a private step. Test through the existing API. Keep test-only helpers inside
  `#[cfg(test)]` modules.
- Import a trait normally when there is no name conflict. Do not use `as _`
  unnecessarily.
- Insert a blank line before an explicit `return` or implicit tail-return expression
  when another statement appears at the same block level. A block containing only
  its return expression needs no extra blank line.
