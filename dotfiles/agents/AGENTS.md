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

- Use the user's confirmed deployment, lifecycle, caller, and concurrency facts.
  Question them only when code, configuration, or an explicit contract contradicts
  them. Point to the conflict. Possible future deployment changes do not expand
  the current task.
- Implement current requirements and supported inputs. Reuse the language, standard
  library, and existing framework. Check framework behavior when uncertain and add
  only what is missing. Do not invent future capabilities.
- When code or documentation shows that components are maintained together under
  one protocol, treat them as one implementation. Do not add compatibility checks
  just in case one component breaks that protocol.
- Preserve API compatibility when the repository has a stable commitment or
  separately maintained consumers. During active development without that
  commitment, or before the project is usable, change internal APIs when it
  improves the design. Update callers, tests, documentation, and configuration
  together instead of keeping shims or old internal paths. Preserve separately
  versioned protocols, persistent formats, and deployed integrations unless their
  migration is part of the task.
- Validate each constraint once at the boundary that can enforce it. Internal callers
  can rely on that check. Validate again when data enters a new trust domain or
  a state change invalidates the earlier guarantee.
- Preserve checks needed for untrusted input, secrets, authentication, external I/O,
  permissions, persistent data, memory safety, and irreversible operations.
- If an internal invariant fails, use the language's usual assertion or immediate
  failure mechanism. Do not turn it into a recoverable business error. Use types,
  ownership, and constructors to represent valid states. Do not hide I/O errors
  behind defaults or type assertions.
- Choose checks and cryptography for the data and protocol being handled. Compare
  ordinary public IDs and status values normally. Do not arbitrarily restrict
  supported inputs or normalize credentials.
- When special cases accumulate, redesign the affected module instead of adding
  more branches.
- Fix the cause at the layer that owns the behavior or invariant. Prefer a larger
  refactor that puts responsibilities at the right layer over a few lines that patch
  one case at the wrong layer. Judge the final design by responsibilities, interfaces,
  and the work needed for later changes, not diff size. In a structural refactor
  within the authorized scope, move responsibilities, migrate all affected internal
  callers, and delete old paths. Keep ordinary fixes focused on their cause; this
  does not mean changing the fewest lines. Preserve the project's style and required
  behavior. Avoid unrelated fixes, formatting changes, future features, and framework
  changes the task does not need.
- Keep modules deep: put related implementation behind a small interface. Expose
  only what production callers need. Do not expose state, settings, parameters, or
  intermediate steps just to simplify tests or wiring.
- Prefer direct, sequential code. Remove abstractions that neither simplify callers
  nor provide a stable interface or needed substitution point. Each cache, token,
  flag, wrapper, compatibility branch, and dispatch table must meet a current
  requirement. Remove speculative fallbacks, unreachable branches, and placeholders.
- Detect overengineering by tracing a supported operation from its entry point to
  its result. For each layer, state source, dependency, or coordination step, ask
  what would be lost by removing it, which current requirement or production caller
  needs that benefit, and whether a simpler design using existing facilities would
  meet the same need. Look for code needed only to operate another unnecessary
  mechanism. Future flexibility or a pattern name does not establish a requirement.
  Remove unnecessary mechanisms with the code, state, configuration, dependencies,
  and tests that exist only for them. Preserve required behavior, safety checks,
  and external or persistence contracts.
- Keep one source of truth. Store derived state only when performance, history, or
  recovery requires it.
- Do not create or retain AI-invented evidence, provenance, confidence, receipt, or
  forensics layers around ordinary business operations. Return domain results and
  errors directly. Remove proof objects and their hashes, snapshots, registries,
  ledgers, validators, storage, retention, reconciliation, and execution gates.
  Migrate their callers. Generated consumers, tests, documents, and plans do not
  justify keeping this design. Do not preserve it under a new name or replace it
  with a smaller version of the same architecture.
- Judge existing mechanisms against the original requirements. Agent-created code,
  tests, documents, and plans do not create new requirements. Remove unused files
  and dependencies with the capability they support. Preserve user changes,
  production data, and external commitments.
- Make mutation visible in APIs. Use hidden or interior mutation only when shared
  mutation is required.
- Propagate clear errors directly. Add context when it names an external operation
  or target and helps diagnose the failure. Handle or log an error where code can
  decide how to recover or report it. Do not log the same error at every layer.
  Retry only recoverable failures, with limits and defined rules for side effects
  and idempotency.
- Test behavior, contracts, security, persistence, and failures that can occur in
  the supported system. Choose tests by the behavior and regressions they can detect,
  not by file count or a goal of testing every module. A module needs no separate
  test when it has no independent behavior to protect or is adequately exercised
  through production callers. Remove redundant or low-value tests without replacing
  each one. Do not expose private code or add production APIs just for tests. Extract
  a production helper only when it improves the production design on its own.
- Assert results, errors, state, and required external actions. Do not use ordinary
  log messages, logger calls, or private call order as a substitute for behavior.
  Test logs or action counts when they have a current contract or security purpose.
  Prefer real implementations; use maintained fakes or narrow mocks at boundaries
  where real dependencies are impractical or failures need to be controlled. Do not
  mock away the behavior being tested or make doubles violate real contracts.
- Reuse the project's test framework and libraries. Consolidate repeated setup,
  resource cleanup, data preparation, fakes, and useful assertions in small shared
  test helpers or fixtures. Migrate retained tests and delete old copies. Keep cases
  independent and their important inputs and expectations visible. Do not build a
  general testing framework or hide scenarios in giant fixtures or helper layers.
- In Rust, leave implementation details private and use plain `pub` for public
  APIs. Use `pub(crate)`, `pub(super)`, or another restricted visibility only when
  a production caller needs that boundary, never just to expose code to tests.
- Test through the production API or entry point. Use a smoke or integration test
  when testing a private step would require changing the API. After a structural
  refactor, confirm that callers use the new path and old symbols, dependencies,
  and temporary bridges are gone. Passing old tests does not prove the migration
  is complete.
- Review the relevant diff once for unnecessary complexity. Check reported problems
  against code paths that can run and the user's confirmed facts. Separate defects
  from optional suggestions. A severity label alone does not establish a defect.
  Fix failures and repeat the affected checks. Stop when the acceptance criteria
  are met. Do not add governance tools, proof files, work logs, or review loops
  unless the task requires them.
</code_design_principles>
