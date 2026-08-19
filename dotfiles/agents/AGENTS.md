<global_operating_constraints>
# Global operating constraints

These constraints are mandatory. A normal request to inspect, edit, fix,
implement, clean up, or finish work does not override them.

<file_editing>
## File editing and paths

- By default, NEVER use an absolute path as the target of an edit, write, or
  patch operation. Use a path relative to the current workspace or repository
  root instead.
- Paths under `/tmp` and the exact path `/dev/null` are always exceptions.
- An absolute path outside the current workspace is also allowed, but only when
  the user explicitly asks to edit that external file or location and there is
  no better, equally quick relative-path or built-in-tool method. Limit the edit
  to the exact external target the user authorized.
- This restriction applies to mutations, including paths passed to editing tools.
  It does not prohibit reading or citing an absolute path.
- If an editing method appears to require an absolute path inside the workspace,
  choose a relative-path or workspace-relative method instead. Do not fall back
  to the absolute path, because doing so breaks permission-system auto-review
  and forces the user to decide manually.
</file_editing>

<external_actions>
## Git history and external publication

- NEVER create or amend a commit, push a branch, open or update a pull request,
  create an issue, or send a pull-request/issue comment or review unless the
  user explicitly requests that specific action.
- Editing or preparing a change does not authorize committing, publishing, or
  communicating with third parties.
- Read-only Git and forge inspection is allowed when it is relevant.
</external_actions>

<formatting_issues>
## Formatting Issues

- NEVER run `cargo fmt --check`, or `prettier . --check`, or `eslint .` and manually
  fixing styling issues. Just run `cargo fmt`, `prettier . --write` and `eslint . --fix`
  after check commands reported issues.
</formatting_issues>

<nixos_rebuilds>
## NixOS rebuilds

- NEVER run or attempt a NixOS rebuild, switch, test, boot, activation, or an
  equivalent operation. This includes `nixos-rebuild`, `nh os`, and direct
  system activation commands.
- When applying a change requires a NixOS rebuild, give the user the command
  and ask them to run it themselves.
</nixos_rebuilds>

<local_builds>
## Local builds

- NEVER build or compile a program locally unless it's required to check your
  changes or the user explicitly approves that specific build in the current
  conversation context.
- An implementation request is not build approval. By default, stop before the
  build, give the user the exact command, and ask them to run it and share the
  result.
- Running necessary commands, like `check`, `build` after implementation is ALLOWED,
  but never run them too frequently. Neccesary builds, like `just write-flake`, are
  always required.
- Before running an unfamiliar validation command, determine whether it may
  compile software or realize build derivations. If it may, treat it as a build.
</local_builds>

<tool_selection>
## Tool selection

- Whenever a specialized built-in tool can perform an operation, ALWAYS use it
  instead of a shell command. Prefer built-in read, search, edit, and patch
  capabilities over shell equivalents.
- Use the shell only when no available built-in tool can perform the operation
  or when the shell is materially required by the task.
- If ffgrep/fffind tools are available, prefer them over `grep` and `find` for
  searching and listing files.
</tool_selection>
</global_operating_constraints>

<code_design_principles>
# Code design principles

- Treat components as one implementation when repository evidence establishes that
  they are maintained together under a shared protocol. Do not add compatibility
  defenses solely in case a sibling component violates that contract.
- Treat API compatibility as a requirement only when repository evidence shows a
  stable compatibility commitment or separately maintained consumers. During active
  development without that commitment, or while the project is not yet usable, make
  clean breaking API changes when they improve the design. Update all jointly
  maintained callers, tests, documentation, and configuration in the same change
  instead of adding shims or legacy paths. Preserve separately versioned protocols,
  persistent formats, and deployed integrations unless their migration is in scope.
- Enforce each constraint once, at the boundary best positioned to enforce it. Avoid
  duplicate validation across internal layers.
- Preserve checks required by concrete external or safety constraints, including
  untrusted input, secrets, authentication, external I/O, permissions, persistent
  state, memory safety, and irreversible operations.
- Treat violations of internally guaranteed contracts as invariant failures. Use the
  language's idiomatic fail-fast or assertion mechanism instead of inventing a
  recoverable business-error path.
- Prefer the correct shape over incremental patches. When special cases accumulate,
  redesign the bounded local module into a simpler cohesive structure instead of
  layering more conditions on top.
- Preserve established style and observable behavior while refactoring. Keep changes
  within the requested scope; do not mix a refactor with unrelated bug fixes,
  formatting churn, or speculative features.
- Keep modules deep: expose the smallest interface callers actually need and hide a
  cohesive implementation behind it. Do not expose internal state, knobs, parameters,
  or intermediate steps for testing or wiring convenience.
- Prefer direct, sequential implementations with the fewest moving parts. Delete
  shallow abstractions that neither reduce caller complexity nor represent a stable
  interface or substitution point. Every cache, token, flag, wrapper, compatibility
  branch, and broad dispatch table must serve a current requirement; remove
  speculative fallbacks, unreachable branches, and placeholder APIs.
- Make mutation visible in APIs. Use hidden or interior mutation only when shared
  mutation is genuinely required.
- Add error context only when it identifies a concrete external operation or target
  and materially improves diagnosis. Otherwise propagate clear errors directly.
- Keep tests focused on observable behavior, contracts, security, persistence, and
  realistic failure modes. Do not change production visibility, add test-only
  production entry points, or extract a single-use step from a cohesive one-pass
  implementation solely so a unit test can call it directly. Test through the
  existing production API; extract a helper only when it is a sound production
  abstraction independent of testing.
- In Rust, keep implementation details private with no visibility modifier and use
  plain `pub` for intentional public APIs. Use `pub(crate)`, `pub(super)`, or other
  restricted visibility only when a concrete production consumer requires that exact
  internal boundary, never as a habitual compromise or merely to expose an item to
  tests.
- Verify changes through the actual production surface as callers use it, not only by
  inspecting source or testing internal steps. Prefer realistic smoke or integration
  tests when direct unit tests would require reshaping the production API.
</code_design_principles>
