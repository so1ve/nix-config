---
name: refactor-for-simplicity
description: Review and refactor production architecture and code to simplify responsibilities, interfaces, control flow, state, and dependencies. Use for structural simplification, overengineering cleanup, migrations, or production design reviews. Remove mechanisms unsupported by current requirements, migrate affected callers, and preserve required behavior and external contracts. Do not use for standalone naming reviews, test-suite cleanup, or ordinary narrowly scoped fixes unless explicitly invoked.
---

# Refactor for Simplicity

Make the requested code easier to understand and change. Preserve required behavior
and unrelated user changes. Favor fewer concepts, state sources, and branches that
a maintainer has to follow. Choose the right responsibilities and interfaces before
minimizing the diff.

This skill owns production design and its required caller migrations. Use
[Clarify Code Names](../clarify-code-names/SKILL.md) for a naming review and
[Improve Test Suite](../improve-test-suite/SKILL.md) for test-suite cleanup when
those tasks are in scope. Read their full instructions from the session's skill
catalog when applying them. Ordinary caller, name, and test updates needed to
complete a production refactor remain part of this skill.

## Define the change

Read repository instructions. Trace the relevant production entry points, callers,
state owners, dependencies, and tests. Investigate the dependencies that can affect
the requested change.

Use the user's confirmed deployment, lifecycle, caller, and concurrency facts.
Question them only when code, configuration, or an explicit contract contradicts
them. Point to the conflict. Future deployment changes are not current requirements.

Briefly state:

- What must stay: behavior, supported inputs, error handling, public protocols,
  compatibility commitments, and persistent data.
- What must change: responsibilities, data flow, dependencies, and internal interfaces.
- What must go: old paths, repeated checks, unnecessary state, and wrappers that
  obstruct the proposed design.
- When the work is done: callers use the new implementation, old paths are removed,
  and relevant behavior checks pass.

When the user asks generally for simplification, choose a target from the request
and code, state it briefly, and proceed with authorized edits. For a review-only
request, report findings without editing. Keep a narrow bug fix focused on its cause,
even when that takes more than a few lines. Create plan files, inventories, approval
tables, or proof records only if the task requires them.

## Detect overengineering

Trace a supported operation from its production entry point to its result, including
state changes and failures. Inspect the whole affected path, including mechanisms
the user did not name. For each layer, state source, dependency, or coordination
step, ask:

- Which current behavior, contract, or supported failure would be mishandled if it
  were removed? Identify the caller or boundary that needs it.
- Could direct code, a domain type, or the existing runtime or framework meet the
  same requirement with fewer concepts and responsibilities?
- What must maintainers configure, coordinate, store, deploy, or recover because
  of it? What current benefit justifies that work?
- Is its supporting code solving a domain problem, or only a problem created by
  another unnecessary mechanism?

Compare callers and implementations together, including everything needed to run
them. If an abstraction hides complexity, check how it simplifies current callers.
A short wrapper can still require a large subsystem. Future flexibility and labels
such as "decoupled", "scalable", or "robust" do not establish a requirement. A
mechanism's existence, callers, or passing tests do not establish that it belongs
in the design.

Read [Overengineering examples](references/overengineering.md) when reviewing
architecture or unnecessary mechanisms. Use the examples to recognize similar
structures under other names. A search match is a candidate to inspect, not a
reason to delete code. Explain findings briefly in terms of the current requirement,
the added work, and the simpler design. Do not create scores or proof records.

## Choose what to keep

- Reuse checks and guarantees provided by types, constructors, parsers, the standard
  library, and existing frameworks. Check library behavior when uncertain and add
  only what is missing.
- Validate raw input once where it enters the system. Internal callers can trust the
  resulting type or contract. Validate again at a new trust boundary or when a
  state change invalidates an earlier check. A TypeScript annotation does not
  validate external JSON.
- Treat components maintained together under one contract as one implementation.
  Decode external data, but do not invent recovery paths for a component breaking
  a guarantee the shared implementation enforces.
- Preserve checks for secrets, authentication, permissions, untrusted data, memory
  safety, concurrency, persistence, and irreversible operations. Choose cryptography
  for the protocol and data being handled. Compare ordinary public IDs and status
  values normally.
- Preserve supported inputs and error handling. Do not make optional fields
  mandatory, reject allowed extensions, trim credentials, hide errors, or return
  fake success.
- Propagate clear errors. Handle, translate, or log them where code can decide how
  to recover or report them. Add context when it identifies the external operation
  or target and helps diagnose the failure. Retry only recoverable failures, with
  limits and defined rules for side effects.
- Keep one source of truth. Keep caches or derived state only when performance,
  history, or recovery requires them.
- Keep abstractions that name a useful domain concept, manage a resource lifetime,
  hide complex code, or support a needed substitution. One caller or implementation
  alone does not make an abstraction useless. Remove forwarding layers, unused
  extension points, and settings with no current purpose.

Agent-created code, tests, documents, and plans do not create product requirements.
Judge them against the original task.

## Remove invented evidence layers

Do not create or retain AI-invented evidence, provenance, confidence, receipt, or
forensics layers around ordinary business operations. Remove them during an
authorized simplification. Existing consumers do not make this design acceptable.

Look for a business operation whose result is wrapped in a proof or evidence object.
That wrapper then requires hashes, snapshots, registries, ledgers, validators,
storage, versioning, retention, reconciliation, or execution gates. Follow the whole
chain, even when the names differ.

Return the domain result or error directly. Migrate callers to that API and remove
the proof wrappers and the code that supports them. Delete tests and documents
whose only purpose is keeping this architecture in place. Implement required
business checks and records at the operation or input boundary that needs them,
using domain types or existing framework facilities.

Agent-created callers, fixtures, validators, tests, plans, and documents do not
justify keeping these layers. Do not rename them as audit or integrity infrastructure
or replace them with a smaller proof framework.

## Refactor the code

Find the layer that should own the behavior or invariant being changed. Use data
ownership, the boundary that can enforce the rule, and production callers' contracts
to locate it. If the current structure puts responsibility in the wrong place, move
it and change the interface. Do not add caller-specific guards, mode flags, wrappers,
or error suppression just to make one case pass while leaving that design error.

Prefer a larger refactor at the right layer over a small workaround at the wrong
layer. Judge the result by what a maintainer must understand and change next time.
Keep rules with their owners, hide implementation details from callers, and remove
the need to repeat fixes across callers. Improve future maintenance by correcting
today's structure, while keeping the work to current requirements.

Choose the simplest final structure within scope. An authorized structural refactor
can change internal modules, types, signatures, and directories. Move responsibilities
and dependencies. Renaming code or adding wrappers alone does not do that. Change
frameworks only when the target design requires it.

Update each complete flow together: implementation, production entry points,
callers maintained with it, configuration, documentation, and affected tests.
Preserve compatibility for external consumers, separately versioned protocols,
persistent formats, and deployment transitions. Do not keep aliases, adapters, or
parallel implementations just to avoid updating internal callers.

Trace producers and consumers before deleting a check or API. Check serialization,
reflection, generated code, plugin registration, and documented public consumers
when the project uses them. Preserve user edits, production data, and deployed
migration history.

Remove old implementations and unused fixtures, dependencies, and configuration.
Do not leave commented-out code, deletion placeholders, or backup copies without
a current purpose. Keep a temporary bridge only for a required transition, and
remove it when that transition ends.

Update affected behavior tests through the production API. Do not expose helpers
or change production APIs just for tests. Use Improve Test Suite when the request
also includes reorganizing the suite or shared test support.

Whenever Rust sources or Cargo manifests are in scope, read and apply
[Rust-specific review](references/rust.md).

## Verify the result

Check behavior and the new structure:

1. Use relevant existing tests and add a test only for a meaningful gap in required
   behavior. Test through the production API or entry point. Use a smoke or integration
   test when testing private steps would require changing the API. A private module
   exercised through its callers need not have a separate test suite.
2. Confirm that entry points and callers use the new implementation. Search for old
   symbols, dependencies, aliases, and duplicate paths, then inspect the matches.
   This one-time search does not need to become a source-text regression test.
3. Run the project's formatter, static analysis, and relevant tests within execution
   and build permissions. If a required command is not allowed, give the user the
   exact command and state that it was not run.
4. Review the relevant diff once for regressions, weakened checks, unnecessary code,
   missed callers, and unrelated edits. Check that the changed rule belongs at that
   layer and that callers no longer compensate for the old design. A passing test
   for one case does not establish that the cause was fixed. Confirm that invented
   evidence layers were removed, not renamed or wrapped again.

Check reported problems against code paths that can run and the user's confirmed
facts. A severity label does not prove a defect. Fix failures and repeat affected
checks. Optional suggestions and hypothetical scenarios do not require more review
rounds. Stop when the required behavior and structure are in place. If the code
needs no change, say so.

Report what changed, which old paths were removed, why any necessary complexity
remains, and what was verified or left untested. When tests change, explain which
behavior they still protect. Reading source alone does not prove runtime behavior.
Do not commit, push, publish, or communicate externally without an explicit request.
