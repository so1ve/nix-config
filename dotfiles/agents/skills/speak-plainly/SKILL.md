---
name: speak-plainly
description: Write or edit explanations, reports, review comments, documentation, and code comments in plain, concrete language. Use when asked to speak plainly, remove AI writing habits, cut filler, or improve clarity without losing necessary detail.
---

# Speak Plainly

**Every sentence should help the reader understand, decide, or act. When they have
enough information, stop.**

Correct information can still be unnecessary.

## Write for the reader

Lead with the answer, result, or action. Add the reasons, conditions, and examples
the reader needs to use it. Match their knowledge: explain unfamiliar concepts,
keep precise terms and consistent names, and skip basics they already understand.

When rewriting, preserve facts, causality, conditions, real risks, operation order,
evidence, and uncertainty. Respect the requested language, tone, and format, and
leave required verbatim text unchanged. Do not invent facts, verification results,
or design reasons. If missing information prevents an answer, name the gap.

## Edit for information value

- **Fix the organization first.** Remove irrelevant passages and group related
  points. Rewrite a tangled explanation around the reader's question before
  polishing individual sentences.
- **Cut empty additions.** Delete repeated conclusions, writing announcements,
  off-topic background, and assurances unrelated to the user's concern. Inspect
  trailing clauses and parentheses: keep them only when they add useful
  information.
- **Name the actor and action.** Replace abstract noun chains and self-praise with
  concrete changes. Write "Consolidated four checks into one method" instead of
  "Significantly improved maintainability."
- **Use contrasts to clarify.** Correct an actual misconception, distinguish
  easily confused concepts, or compare concrete options. Delete negative asides
  about interpretations or uses the reader has no reason to consider.
- **State uncertainty precisely.** Separate observations, inferences, and unknowns.
  Write "Allocations decreased; runtime has not been measured" instead of claiming
  a speedup or stacking vague qualifiers.
- **Choose a useful structure.** Use paragraphs for connected explanations, tables
  for comparisons, and lists for steps or parallel items. Give complex reasoning
  enough room; avoid arbitrary item counts and headings for every sentence.
  Retain the object and outcome: "Renamed it to `DependencyGraph`; the library
  check passed" conveys more than "Changed. Passed."

Judge these choices in context. Long sentences, semicolons, technical terms, and
repetition can help; an independently read section may need to repeat a prerequisite.
Preserve useful transitions and natural courtesy. Do not manufacture a human voice
through slang, exaggeration, or deliberate mistakes.

## Code comments and API documentation

Read the code and calling contract before editing comments. Keep code behavior
unchanged when only comments are in scope. If a claim cannot be verified, identify
the gap rather than inventing a rationale or deleting a possible contract.

- **Implementation comments explain what the code cannot readily express:**
  reasons, invariants, ordering requirements, and non-obvious tradeoffs. For example,
  "Equal results can still have different dependencies; update dependencies before
  returning" explains why `finish()` precedes an early return. Explain complex
  mechanisms when useful; omit narration of ordinary syntax and visible operations.
  If nothing needs explaining, leave the code uncommented.
- **API documentation tells callers how to use the interface.** Describe purpose
  and observable behavior, including relevant units, special values, ownership,
  timing, failures, and preconditions. Omit prose that merely restates the signature.
- **Unsafe documentation states the actual safety obligations.** An unsafe API's
  `# Safety` section states what callers must guarantee. A call site's `SAFETY`
  comment explains why those conditions hold there. Include the type, validity,
  lifetime, alignment, aliasing, or exclusive-access facts the operation needs.
  Delete "the borrow covers only `mem::replace`" when it merely narrates visible
  code; keep a scope argument when it establishes a required safety condition.
- **Explain shared reasons where they are maintained.** Keep each call site's
  local conditions and evidence. Deduplication must not erase a distinct safety
  argument.

## Review and deliver

Ask: **What would the reader lose if this sentence disappeared?** Delete it when
nothing useful would be lost. Check that the result still answers the question,
supports its claims, and preserves the conditions and connections needed to act.

Deliver the answer or rewrite. In work reports, include relevant verification and
unfinished work. Explain edits separately only when they affect meaning or require
a decision. Keep the editing checklist, operation-by-operation narration, repeated
summaries, ceremonial conclusions, and routine offers out of the response.

## References

- [Google: Voice and tone](https://developers.google.com/style/tone),
  [Short sentences](https://developers.google.com/tech-writing/one/short-sentences),
  and [Microsoft: Simple words, concise sentences](https://learn.microsoft.com/en-us/style-guide/word-choice/use-simple-words-concise-sentences).
- [Google: Code review comments](https://google.github.io/eng-practices/review/reviewer/looking-for.html#comments)
  and [Linux: Commenting](https://www.kernel.org/doc/html/latest/process/coding-style.html#commenting).
- [Wikipedia: Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing).
