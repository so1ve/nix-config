---
name: improve-codebase
description: Coordinate improvements across production design, code naming, test suites, and explanatory prose using the relevant specialist skills. Use when the user requests broad codebase cleanup, a full code-quality review, or improvements spanning several of these concerns. Select the needed skills, complete related migrations together, and verify the combined result. Do not use for a request confined to one concern or an ordinary narrow bug fix unless explicitly invoked.
---

# Improve Codebase

Use the specialist skills to complete a coherent codebase improvement. This skill
owns scope, coordination, and combined verification. Detailed rules belong to the
specialists below.

## Establish scope and choose skills

Read repository instructions and inspect the requested area, production entry
points, callers, tests, and existing user changes. Use confirmed runtime and
deployment facts. Identify the current behavior and external or persistence
contracts to preserve. For a review-only request, report findings without editing.
For an implementation request, complete authorized changes and affected migrations.

Choose the relevant skills from what the user requested and what the code needs:

| Skill | Use it for |
| --- | --- |
| [Refactor for Simplicity](../refactor-for-simplicity/SKILL.md) | Production responsibilities, abstraction boundaries, interfaces, state, control flow, dependencies, and unnecessary mechanisms. |
| [Clarify Code Names](../clarify-code-names/SKILL.md) | Misleading or inconsistent names, unclear API intent, and coordinated renames. |
| [Improve Test Suite](../improve-test-suite/SKILL.md) | Test value, brittle assertions, excessive mocks, repeated setup, resource isolation, and shared test support. |
| [Speak Plainly](../speak-plainly/SKILL.md) | Explanations, comments, or documentation that need clearer language. |

Before applying a selected skill, read its full `SKILL.md` at the path listed in the
session's skill catalog, along with references that skill requires for the current
work. The relative links above locate the sources in this checkout; installed skills
may have separate resolved locations. Listing a skill's name is not applying it.
Do not reproduce its rules here or assume that reading this table loads them.

For a full code-quality review, read all three code skills before deciding that a
concern needs no changes. Read Speak Plainly when prose is in scope. Change only
actual problems; a full cleanup does not require finding a defect in every category.
A single-concern request normally belongs to that specialist directly. Missing
access to a specialist does not justify claiming its review is complete; identify
the gap and finish the independent work that remains possible.

## Coordinate related changes

Briefly state the target, what must stay, and what will be removed. Choose a coherent
flow or module boundary from the actual findings. Do not create a plan file, score,
inventory, or approval process unless the task requires it.

Resolve production responsibilities and contracts before finalizing names or shared
test support that depends on them. Use naming findings to expose design problems.
Apply the selected skills together as needed rather than running separate full
refactors that repeatedly change the same code. Keep affected callers and required
behavior tests working as the implementation changes.

When cleaning up tests, remove cases and helpers that existed only for discarded
mechanisms, retain checks of required behavior, and migrate useful cases to shared
support. Update documentation and comments whose meaning changed. Apply Speak Plainly
when prose needs work, without turning a code cleanup into an unrelated rewrite.

Keep the work to current requirements. A broad cleanup does not authorize new
features, speculative infrastructure, framework changes without need, or unrelated
fixes. Address a newly found issue only within the authorized scope. Report material
work outside it without adding a placeholder implementation.

## Verify the combined result

Combine the relevant verification from the selected skills. Check behavior and
external contracts, callers using the final APIs and names, removal of old paths
and mechanism-only dependencies, and test support actually reused by retained cases.

Run the relevant checks within execution and build permissions. A passing check
does not need repeating just because another skill also requests it. Review the
combined diff once for missed migrations, regressions, unnecessary complexity, and
unrelated edits. Fix failures and repeat only affected checks. Stop when the requested
behavior and structure are in place; do not start review loops to manufacture more
improvements.

Report the concrete changes, removed mechanisms or duplication, behavior still
protected by tests, checks run, and any unverified or out-of-scope work. Do not imply
performance gains without measurement. Skill composition does not authorize commits,
publication, messaging other chats, or delegation beyond the current permissions.
