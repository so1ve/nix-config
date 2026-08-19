# Repository Instructions

## Neovim-specific principles

- Make cache invalidation and event wiring precise. Listen to the actual source of
  change, not broad unrelated events, and keep refresh logic close to the cache it
  updates.
- Verify Neovim Lua changes with headless Neovim smoke tests that exercise modules the
  way the configuration uses them.
