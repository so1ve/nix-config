# Design and simplify the test suite

Review tests affected by the refactor or included in a requested cleanup, even when
they pass. Delete, merge, or rewrite tests that protect no current requirement.
Keep useful tests and stay within the requested scope. Test count and line coverage
alone do not show whether tests can catch regressions.

For a suspect test, ask what requirement it protects, which production API or entry
point it exercises, and what bug it could catch. Also ask whether a change that
preserves behavior would break the test. These questions guide the review; they
do not require a written record for each test.

## Choose which behavior needs tests

Do not generate a test for every file, module, class, method, branch, or line. A
module needs no separate test when it has no independent behavior worth protecting
or its behavior is adequately exercised through a production caller. Trivial
forwarding, accessors, and library calls often fall into this group. Deleting such
tests does not require writing replacements or moving every case to an integration
test.

Keep checks of domain decisions, public contracts, security boundaries, persistence,
concurrency, and failures that can occur in the supported system. Use the production
API that exercises the relevant behavior. One test can exercise several cooperating
modules; a focused unit test is useful when it isolates a meaningful rule or failure.
Choose by what can break and how the test detects it, without imposing a fixed mix
of unit and integration tests.

Use coverage to find code whose behavior might lack a useful check. Do not fill
every uncovered line, restore a test count, or add tests for a reversible, low-impact
change with no meaningful regression to detect. Honor an existing required check,
but do not invent coverage targets or treat a higher percentage as proof of quality.

See [Google: Test Behaviors, Not Methods](https://abseil.io/resources/swe-book/html/ch12.html)
and [Martin Fowler: Test Coverage](https://martinfowler.com/bliki/TestCoverage.html).

## Assert results instead of diagnostic logs

Check returned values, reported errors, resulting state, and required external
actions. A log saying "saved" does not show that the record was saved. An error log
does not show that an operation failed correctly or avoided a forbidden side effect.
Observe the behavior through the appropriate API or resource.

Remove assertions about ordinary log messages, log levels, logger calls, private
helper calls, and incidental call order. They often break when code is reorganized
while missing a defect in the result. Capturing logs to diagnose a failed test is
useful; making their wording the success condition usually is not.

Keep checks when logging itself has a current contract, such as a required structured
output consumed externally or exclusion of credentials from logs. Keep assertions
about action counts or order when those are required behavior, such as preventing
a second charge. These exceptions do not justify AI-invented proof or receipt layers.

This applies behavior-based testing to log assertions; see
[Kent C. Dodds: Testing Implementation Details](https://kentcdodds.com/blog/testing-implementation-details)
and [Google: Change-Detector Tests Considered Harmful](https://testing.googleblog.com/2015/01/testing-on-toilet-change-detector-tests.html).

## Use real code and limit test doubles

Keep the behavior being tested and its ordinary collaborators running. Prefer real
implementations when they are practical and deterministic. Do not mock every imported
module, internal method, value object, or step in a call chain merely to isolate a
class. A test that programs all decisions into mocks can pass while the production
operation is broken.

When a real dependency is impractical, reuse a maintained fake if one is available.
Use a narrow stub or mock for a needed external boundary, controllable time, or a
failure that can occur. Do not replace the code being tested. Do not use loose casts,
partial objects, or impossible return values to make a mock fit the interface. A
test double must respect the dependency's relevant contract.

A fake in-memory map does not establish database transaction, query, or restart
behavior. Test those contracts with the appropriate implementation when they are
in scope. Do not build a second database or service inside the test suite to avoid
using an existing test facility. Keep setup local and controlled; tests should not
depend on production accounts or data.

When many tests need intricate mocks of the same internals, inspect the production
responsibilities and interfaces as well as the tests. Fix misplaced responsibilities
at their owner when that change is in scope. Do not add injection points, public
helpers, flags, or alternate production paths just to accommodate the mocks.

See [Google: Increase Test Fidelity by Avoiding Mocks](https://testing.googleblog.com/2024/02/increase-test-fidelity-by-avoiding-mocks.html)
and [Software Engineering at Google: Test Doubles](https://abseil.io/resources/swe-book/html/ch13.html).

## Reuse test support across the retained suite

Inspect the project's runner, fixtures, libraries, and existing helpers before adding
test support. Reuse them. If retained tests repeat application startup, client setup,
authentication, data creation, resource management, or the same dependency fake,
consolidate that work in small shared test helpers or framework fixtures. Do not keep
separate copies just because each test currently passes.

Give shared support a clear job and a small interface:

- Create only the state the scenario needs. Use fresh mutable data for each test;
  share expensive resources only when the suite can keep cases independent.
- Own temporary resources and clean them up on success, assertion failure, and
  partial setup failure. Avoid test order dependencies and collisions between
  concurrently running cases.
- Reuse a fake across tests that need the same dependency behavior. Check meaningful
  fake behavior against the real contract where needed, without recursively testing
  trivial helpers or retesting the test framework.
- Share repeated domain assertions when they clarify the contract and give useful
  failures. Leave the case's important inputs, action, and expected result visible.
  Do not calculate expected results with the production algorithm.
- Use the runner's parameterized cases when several independent inputs and expected
  outputs test the same behavior. Keep distinct behavior and regression cases clear.

Migrate the affected retained tests to that support and delete their old setup and
mock copies. Remove unused fixtures and dependencies after checking their callers.
A larger change that fixes shared setup is preferable to adding another local
workaround in each test.

Do not turn reuse into a custom testing framework, universal scenario DSL, inheritance
tree, giant fixture, or builder with switches for every case. Share repeated mechanics
that current tests need. Keep scenario-specific decisions in the scenario. A mature
suite uses reliable support and readable cases; it does not require a large harness.

The original [Refactoring Test Code](https://www.researchgate.net/publication/2534882_Refactoring_Test_Code)
paper describes duplicate test code, oversized fixtures, and tests with unclear
failures. [Google: Tests Too DRY? Make Them DAMP!](https://testing.googleblog.com/2019/12/testing-on-toilet-tests-too-dry-make.html)
explains why shared mechanics should leave a case understandable. For framework
support, see [pytest: fixtures and safe teardown](https://docs.pytest.org/en/stable/how-to/fixtures.html)
and [xUnit: parameterized tests](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-csharp-with-xunit).
Use the equivalent facilities in the project's existing framework.

## Tests to remove or rewrite

- **Source-text checks:** tests that search production source for names, calls,
  branches, annotations, or code fragments using strings, regexes, hashes, or ASTs.
  For example, `assert "authorize(" in source` does not show that authorization
  works. Test an unauthorized request and check that it is rejected without the
  protected side effect. Search for old names once during a refactor rather than
  adding a permanent test for their absence.
- **Tests that repeat the implementation:** tests that copy the production algorithm,
  call it for both actual and expected results, compare a value with itself, or
  derive the expected value from the result being tested. Use independent examples,
  reference vectors, or properties. Independent reference implementations,
  differential tests, and round-trip properties can catch bugs. A copied algorithm
  can repeat the same bug.
- **Mocks that replace the code being tested:** tests that check a mock's configured
  result or calls without exercising the production decision. Also remove assertions
  about private helper calls, incidental order or counts, and repeated reads of
  stubbed data. Check the output or resulting state. Keep interaction assertions
  when an external action, its absence, count, or order is itself required behavior.
- **Tests that do not check the result:** unconditional assertions, checks of fixture
  setup alone, swallowed exceptions, or conditional assertions that let a case
  finish unchecked. A non-null value, successful import, or lack of an exception
  is too weak when the test claims to check more. Keep smoke tests when startup,
  loading, or successful completion is the requirement.
- **Tests of libraries and forwarding code:** tests of standard-library behavior,
  trivial accessors, wrappers, or defaults that enforce no application requirement.
  Keep small tests that check a public contract, mapping, or policy.
- **Impossible internal inputs:** tests that corrupt private state, bypass enforced
  constructors or types, or make components maintained together break guaranteed
  contracts just to exercise speculative recovery. Remove them with those recovery
  branches. Keep tests of malformed external input, failures that can occur, and
  meaningful invariant, concurrency, and fault-injection tests.
- **Unused compatibility:** tests of old API shapes, aliases, fallback formats, or
  modes with no current consumer, deployed integration, data migration need, or
  compatibility commitment. Remove them with the old paths. Do not retain parallel
  implementations just to satisfy these tests.
- **Repeated or hypothetical safety cases:** repeated checks after the enforcing
  boundary, arbitrary combinations of invalid internal states, or attack scenarios
  with no entry point or applicable threat model. Remove them. Do not add production
  guards to support those scenarios. A "security", "safety", or "compatibility" label
  does not establish a requirement. Identify the boundary and the failure being tested.

Source checks are appropriate when source is the product, as in a compiler, linter,
code generator, or codemod, or when they enforce a maintained architecture or
security rule. Text assertions can also check CLI output, serialized formats,
rendered content, and generated files. Keep them tied to those requirements.
Do not substitute source matching for behavior tests just because running the code
is inconvenient.

## Reduce duplicate cases and noisy assertions

- Merge cases that check the same behavior and catch the same failure when extra
  inputs add no boundary, equivalence class, or regression case. Keep applicable
  historical bug cases and meaningful boundary cases. Remove regression cases for
  intentionally removed features or contracts. Similar setup or code coverage does
  not make tests redundant. Unit and integration tests may catch different failures.
- Replace snapshots of private objects, entire component trees, or incidental
  formatting with focused assertions when they mainly create review noise. Keep
  deterministic, reviewable golden files, visual baselines, and snapshots of output
  or compatibility contracts. Investigate failures before updating a baseline.
  Do not regenerate it merely to make tests pass.
- After checking other callers, delete unused fixtures, mocks, helpers, dependencies,
  and runner configuration. Simplify parameter matrices that repeat the same check
  without protecting additional behavior. Do not sacrifice readability to remove
  duplication or ban useful parameterized, property-based, or fuzz tests.

## Preserve useful checks

Replace a bad test when it is the only test of a current requirement, and exercise
that requirement through the existing production API or entry point. If it protects
no requirement or duplicates adequate coverage, delete it without a replacement.
Keep coverage of security boundaries, persistent formats in use, external failures
that can occur, and compatibility commitments. Do not add cases for hypothetical
requirements, expose private code, or add abstractions just to write replacement
tests.

After changing the suite, check that retained tests exercise production behavior,
shared setup is actually reused, resources are cleaned up, and old copies are gone.
Run the relevant tests within execution and build permissions. Check isolation or
parallel execution when the change affects shared resources or test ordering. Do
not add review reports, per-module coverage inventories, or a new test framework
as a condition for completing the cleanup.

Do not weaken assertions, skip failing tests, or delete regression cases just to
make tests pass. Determine whether the failure is a regression, an authorized
contract change, or a test tied to obsolete internals. Fix the code or test for
that reason. Do not copy the new implementation into the expected result.

Further guidance for the removal and assertion checks above:

- [Google: Change-Detector Tests Considered Harmful](https://testing.googleblog.com/2015/01/testing-on-toilet-change-detector-tests.html).
- [Software Engineering at Google: Unit Testing](https://abseil.io/resources/swe-book/html/ch12.html) and [Test Doubles](https://abseil.io/resources/swe-book/html/ch13.html).
- [Microsoft: Unit testing best practices](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-best-practices).
- [Jest: Snapshot testing best practices](https://jestjs.io/docs/snapshot-testing#best-practices).
