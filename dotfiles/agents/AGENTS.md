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
- Enforce each constraint once, at the boundary best positioned to enforce it. Avoid
  duplicate validation across internal layers.
- Preserve checks for real boundaries, including untrusted input, secrets,
  authentication, external I/O, permissions, persistent state, memory safety, and
  irreversible operations.
- Treat violations of internally guaranteed contracts as invariant failures. Use the
  language's idiomatic fail-fast or assertion mechanism instead of inventing a
  recoverable business-error path.
- Prefer direct, sequential implementations. Avoid speculative fallbacks, unreachable
  branches, unused abstractions, placeholder APIs, and compatibility logic without a
  current consumer.
- Make mutation visible in APIs. Use hidden or interior mutation only when shared
  mutation is genuinely required.
- Add error context only when it identifies a concrete external operation or target
  and materially improves diagnosis. Otherwise propagate clear errors directly.
- Keep tests focused on observable behavior, contracts, security, persistence, and
  realistic failure modes. Do not retain production abstractions solely for tests.
- Remove clearly redundant logic when doing so preserves behavior and real boundary
  protections, but keep changes within the user's requested scope.
</code_design_principles>
