# Repository Instructions

## Code writing principles

- Prefer the correct shape over incremental patches. When code starts accumulating special cases, rewrite the local module into a simpler design instead of layering more conditions on top.
- Keep modules deep: small public interface, cohesive implementation hidden behind it. Avoid exposing internal state, knobs, or parameters unless callers actually need them.
- Delete shallow abstractions. Do not keep one-line wrappers, pass-through helpers, redundant state objects, or named concepts that do not reduce caller complexity.
- Use the fewest moving parts that preserve the behavior. Extra caches, tokens, flags, compatibility branches, and broad match tables must correspond to a real requirement, not a hypothetical one.
- Avoid defensive programming inside trusted code paths. Validate at external boundaries; do not add fallback logic for states the current contracts make impossible.
- Make invalidation and event wiring precise. Listen to the real source of change, not broad unrelated events, and keep refresh logic close to the cache it updates.
- Preserve existing style and behavior while refactoring. Do not mix bug fixes with unrelated cleanup, formatting churn, or speculative feature work.
- Verify changes through their real surface, not only by reading the source. For Neovim Lua, prefer headless Neovim smoke tests that exercise the module the way the config uses it.
