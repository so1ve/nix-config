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

- NEVER build or compile a program locally unless the user explicitly approves
  that specific build in the current conversation context.
- An implementation request is not build approval. By default, stop before the
  build, give the user the exact command, and ask them to run it and share the
  result.
- This includes build-capable checks and tests. In particular, do not run
  `nix build`, a `nix flake check` that realizes derivations, `cargo build`,
  `cargo check`, `cargo test`, `rustc`, or equivalent build commands without
  that explicit approval.
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
</tool_selection>
</global_operating_constraints>
