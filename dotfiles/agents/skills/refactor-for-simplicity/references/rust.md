# Rust-specific review

Apply this guide whenever Rust sources or Cargo manifests are in scope.

## Inspect

- `ensure!`, `bail!`, `if`, `match`, `let-else`, and early returns;
- `Option` and `Result` fallbacks (`unwrap_or`, `unwrap_or_else`, `is_some`,
  `is_none`, `is_ok`, `is_err`) and verbose `.expect(...)` on impossible states;
- `context()`, `with_context()`, and repeated conversions to `anyhow` or custom
  errors;
- channel sends/receives, cancellation, thread joins, poisoned locks, and
  `extern "C"` / FFI wrappers (`catch_unwind`, speculative global locks);
- `RefCell`, `Cell`, `Mutex`, `RwLock`, and other interior mutability;
- traits and single-line pass-through wrappers with one implementation or consumer;
- duplicate default definitions (e.g., manual `impl Default` repeating
  `#[serde(default = "...")]` helpers);
- unused fields, variants, methods, derives, Cargo features, and dependencies;
- visibility (`pub(crate)`, `pub(super)`, `pub(in ...)`) and production callers
  that actually need it;
- `impl` blocks separated far from their type definitions, noisy comments, and
  unintended hot-path clones or extra lookups;
- production APIs or abstractions kept only for tests.

## Rules

- **Express invariants in types**: use types, ownership, and constructors to
  represent valid lifecycle states and remove repeated checks. Preserve error
  results for real I/O failures; never introduce `unwrap()` or `unsafe` merely
  to shorten a fallible branch.
- **Fail fast without verbose paranoia**: use plain `unwrap()` when failure
  reflects an obvious invariant or impossible condition (such as clock math
  after `UNIX_EPOCH` or `i64::try_from` on current timestamps); reserve
  `expect()` for non-obvious preconditions where the message helps debugging. Do
  not turn broken invariants into recoverable business errors.
- **Keep error flow crisp**: prefer `let-else` with `bail!` for missing required
  external values. Add `context()` / `with_context()` only when it names an
  external operation or target; otherwise propagate with `?`.
- **Keep concurrency and FFI minimal**: rely on lifecycle states guaranteed by
  internal threads, tasks, channels, and types. Handle closure, cancellation,
  poisoning, global locks, or `catch_unwind` at `extern "C"` boundaries only
  when a real concurrent, unwinding, or external protocol path requires them.
- **Make mutation visible**: prefer `&mut self`. Do not use `RefCell` just to
  keep an `&self` signature; keep interior or synchronized mutability only when
  shared mutation is required.
- **Avoid duplicate definitions and thin wrappers**: eliminate small traits or
  forwarding functions with no needed substitution, and avoid repeating defaults
  across `impl Default` and field-level `#[serde(default = "...")]` functions
  when `#[serde(default)]` on the struct suffices.
- **Visibility**: leave implementation details private and use plain `pub` for
  public APIs (especially in internal workspace crates not published externally).
  Use `pub(crate)`, `pub(super)`, or `pub(in ...)` only when a production caller
  needs that boundary, never to expose code to tests.
- **Tests**: test through the existing API; keep test-only helpers inside
  `#[cfg(test)]` modules instead of changing production APIs.
- **Layout and imports**: keep `impl` blocks close to their type definitions,
  remove obvious or verbose comments, import traits normally unless a name
  conflict requires `as _`, and insert a blank line before an explicit `return`
  or implicit tail-return expression when another statement precedes it in the
  same block.

## Examples

### Impossible-state `expect()` and speculative FFI guards

```rust
// Avoid: narrating impossible invariants and guarding non-existent FFI unwinding
let secs = SystemTime::now()
    .duration_since(UNIX_EPOCH)
    .expect("system clock is before UNIX_EPOCH")
    .as_secs();
let ts = i64::try_from(secs).expect("unix timestamp exceeds i64");

let _guard = LOAD_LOCK.lock().unwrap_or_else(PoisonError::into_inner);
let _ = catch_unwind(|| tracing::debug!("loaded"));

// Prefer: plain unwrap() on obvious invariants; direct calls without speculative guards
let ts = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs() as i64;
tracing::debug!("loaded");
```

### Duplicate `serde` defaults and `impl Default`

```rust
// Avoid: maintaining the same defaults in helper functions and impl Default
#[derive(Deserialize)]
pub struct GcConfig {
    #[serde(default = "default_interval")]
    pub interval_seconds: u64,
}
impl Default for GcConfig {
    fn default() -> Self { Self { interval_seconds: default_interval() } }
}

// Prefer: one source of truth
#[derive(Deserialize)]
#[serde(default)]
pub struct GcConfig {
    pub interval_seconds: u64,
}
impl Default for GcConfig {
    fn default() -> Self { Self { interval_seconds: 3600 } }
}
```

### Thin forwarding wrappers and hot-path regressions

```rust
// Avoid: single-line pass-through wrapper with restricted visibility in an internal crate
pub(crate) fn move_column(strip: &mut Strip, dir: HorizontalDirection) -> bool {
    strip.slots.move_selected(dir.offset())
}
// Prefer: call strip.slots.move_selected(dir.offset()) directly.

// Avoid: replacing a direct lookup/borrow with extra clones or dispatch on a hot path
if let Some(window) = self.window_for_surface_tree(&resource).cloned() {
    self.request_window_scale(&window);
}
// Prefer: borrow directly or keep the direct fast path when ownership is unnecessary.
```
