---
name: clarify-code-names
description: Review and improve names in existing code by checking domain meaning, actual call sites, inputs, results, side effects, lifecycle, units, and language conventions. Use for naming reviews, misleading API names, inconsistent terminology, unclear variables or collections, and coordinated renames. Distinguish a bad name from misplaced responsibility, preserve behavior and external contracts, and migrate affected references. Do not use for unrelated structural refactoring or cosmetic mass renaming.
---

# Clarify Code Names

Make names help readers understand what a value represents, what an operation does,
and how it relates to nearby code. A name need not explain the implementation, but
it must not create a false expectation.

## Establish meaning before choosing words

Read repository instructions and the affected definitions, types, documentation,
and actual production uses. Follow the project's language, casing, established domain
terms, and framework conventions. Use the user's confirmed caller and runtime facts.
Do not infer behavior, ownership, timing, or cost from a name alone.

For a suspect name, establish what it actually represents or does, then read it in
a representative call or expression. Check whether a reader could predict the main
action, affected object, and result. Look at related interfaces to understand their
vocabulary. Do not generate new names from the declaration in isolation.

For a review-only request, report the misleading use, actual behavior, and a concrete
improvement without editing. For a rename request, complete the related migration.
Prioritize names that can cause incorrect use or obscure a change. Do not rename
clear code just to increase the number of improvements.

## Name values by role and representation

Choose detail that the surrounding code and type do not already provide:

| Distinction | Useful names when that distinction exists |
| --- | --- |
| Roles of otherwise similar values | `source_account`, `destination_account` |
| Requested and observed values | `requested_size`, `actual_size` |
| Successive states | `previous_selection`, `current_selection` |
| A duration, instant, or count | `retry_delay_ms`, `retry_at`, `retry_count` |
| Objects, identifiers, or callbacks | `users`, `user_ids`, `completion_callbacks` |
| A relationship needed by callers | `users_by_id`, `group_for_item(item)` |
| Representations present in the flow | `encoded_payload`, `decoded_payload` |

Use units when they can be confused. Do not call a byte count `size` when nearby
code also handles element counts. Do not use a duration name for a deadline. Explain
the clock or inclusive/exclusive endpoint when correct use depends on it and the
type or name leaves it unclear. A duration type may already make a unit suffix
unnecessary; do not label an arbitrary duration object as milliseconds.

Name collections by what they contain. A collection of callbacks associated with
frames is not a collection of frames. Include a key relationship or ordering role
when it matters to use, as in `users_by_id` or `undo_stack`. Avoid encoding the
concrete container, such as `user_hash_map`, when it adds no useful meaning.

Distinguish an ID from an object, handle, or state when those representations already
exist and callers can confuse them. A `TaskId` should not unexpectedly run work or
own its resources. Check whether the type's name or responsibility is wrong. Do not
introduce `TaskId`, `TaskHandle`, and `TaskState` as a mandatory set. A `Handle` suffix
does not specify lifetime or copying cost; read the type and contract.

Boolean names should make conditions readable and express the actual question:
`is_expired`, `has_children`, or `can_retry`. Permission to retry does not mean a retry
was scheduled or completed. Prefer an affirmative state when it simplifies use, but
update all reads and writes together if changing polarity. Preserve the meaning of
external options such as `disable_cache` even if an internal name is affirmative.

## Make operations match their contract

Check the verb, object, inputs, result, and important side effects together:

| Misleading use | What to establish before changing it |
| --- | --- |
| `update(user, value)` | Which property changes? `change_password(user, new_password)` is clear if that is the actual action. |
| `find_user(email)` creates a missing user | Is creation intended? If so, express it, for example `find_or_create_user`. If not, fix the defect within scope; renaming does not make the behavior correct. |
| `is_valid()` saves state or sends a message | Determine whether judgment and mutation belong together. Use an accurate action name or separate responsibilities when authorized. |
| `take_item(item_id)` removes and returns a group | Identify the actual operation and object. It may need a group operation rather than a longer item name. |
| `rectangle_from_request(x, y, width, height)` | Name the coordinates and dimensions actually accepted. Their origin at one caller does not make the function a request parser. |

Input and return types need not match. Looking up an object by ID, or removing a
map entry by key and returning its value, is ordinary behavior. Describe the real
relationship instead of enforcing a superficial type-matching rule.

Make observable creation, mutation, deletion, transfer, or external effects clear
enough for correct use. Do not hide creation behind a query or a destructive action
behind a predicate. Names need not enumerate incidental logging, cache access, or
every internal step. Use API documentation for necessary conditions, failure behavior,
ownership, or effects that do not fit naturally in a name.

## Distinguish progress and lifecycle

Check what has happened when an operation returns or a state becomes true:

- Registering a handler stores behavior for later; handling a request acts on the
  current request. Do not use near-synonyms to hide a required order between steps.
- Requesting cancellation, accepting the request, and completing cancellation can
  be different events. `close_requested` must not imply `is_closed`.
- Scheduling work is different from executing it. If an API returns an accepted
  job ID, do not imply that the result is finished. Name existing behavior without
  introducing a queue or status system merely to fit the terminology.
- Follow the language's asynchronous conventions. Do not add an invented suffix
  to every asynchronous function or try to put the entire protocol in its name.
  Document when effects occur and what callers must await when that matters.

## Use context and vocabulary consistently

A short name can be precise in a small scope. `value` may be enough in a tiny
conversion; `users.find(id)` already identifies the collection. Add words when
context is insufficient, and remove words that repeat the receiver, type, or obvious
operation. Familiar domain abbreviations and mathematical names can be clearer
than expanded phrases. Follow the project's naming language.

Use one stable term for the same concept across related interfaces. Distinct terms
should express a distinction callers need. For example, a project may distinguish
detaching a child from destroying it, but this is not a universal definition of
`remove`, `delete`, `erase`, or `destroy`. Check the library's contract. The same word
can have clear meanings in separate domains without requiring a global vocabulary.

Respect language and framework conventions. Preserve meaningful distinctions such
as Rust's `as_`, `to_`, and `into_` conversions. Do not impose another language's getter,
constructor, casing, or asynchronous naming scheme merely for visual consistency.

`Manager`, `Helper`, `Util`, `Data`, `Info`, and `Impl` are not forbidden suffixes.
Ask whether the whole name identifies the actual responsibility. Replacing
`OrderManager` with `OrderRepository` is wrong if the object coordinates a workflow
rather than storing orders. A suffix change does not fix a collection of unrelated
responsibilities.

Avoid development-history labels such as `new_parser`, `parser_v2`, or
`temporary_handler` when they conceal the actual distinction. Preserve names for
supported versions and real transitions. Language constructors such as `new()` are
not instances of this problem. Names like `streaming_parser` help only when they
describe the implementation that actually exists. Do not claim an optimization or
guarantee in a name without establishing it.

## Separate naming problems from design problems

When a name must list unrelated actions, an object mixes identity and control, or
two types repeatedly convert without a clear distinction, inspect responsibilities
and boundaries. A longer name, a new suffix, or another wrapper may leave the problem
intact. Do not make an unnecessary mechanism seem justified by giving it better words.

For an operation with a coherent, intended contract, a rename and necessary API
documentation can be sufficient. If the behavior contradicts the requirement,
renaming it is not a repair. Identify the defect. When production redesign is in
scope, read and apply [Refactor for Simplicity](../refactor-for-simplicity/SKILL.md)
at its path in the session's skill catalog. Within a naming-only request, improve
names for the intended existing behavior and report structural work that remains
outside scope. Do not silently change business behavior or invent types for naming.

## Migrate and verify a rename

Use symbol-aware rename tools where available. Inspect the affected references,
including imports, exports, constructors, patterns, callbacks, tests, examples,
documentation, reflection, registration, and generated code. Similar text does not
necessarily refer to the same symbol; avoid blind replacement across a repository.
Follow the generator workflow rather than editing generated output alone.

Check whether a code name also determines a JSON field, database column, command-line
option, environment variable, route, plugin key, or other external or persistent
name. Preserve those contracts unless their migration is explicitly part of the
task. Use the existing framework's explicit mapping when it is needed to rename
an internal symbol while keeping its external representation. Do not keep internal
aliases or old call paths merely to avoid migrating maintained callers.

Read the updated call sites again. Check that the chosen names describe the same
behavior, remain consistent across related uses, and have not introduced an inverted
condition or changed external representation. Search once for old references and
inspect remaining matches; legitimate external names and unrelated uses may remain.

Run relevant formatting, static analysis, and existing behavior tests within execution
and build permissions. Add a behavior test only for a meaningful gap, not to assert
that a new identifier occurs in source. Do not create naming checkers, inventories,
or permanent absence tests for the rename. Report representative changes with their
reasons, relevant verification, and any behavior or compatibility issue left open.

## References

- [Swift: API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/): clarity at use sites, useful words, and established terminology. Apply these ideas with the project's language conventions.
- [Rust: Naming](https://rust-lang.github.io/api-guidelines/naming.html): Rust-specific conversion and naming conventions.
- [Rust: HashMap::remove](https://doc.rust-lang.org/std/collections/struct.HashMap.html#method.remove): an example of accepting a key and returning the corresponding value.
