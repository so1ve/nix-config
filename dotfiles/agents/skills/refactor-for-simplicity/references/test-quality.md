# Simplify tests

Review tests affected by the refactor or included in a requested cleanup, even when
they pass. Delete, merge, or rewrite tests that protect no current requirement.
Keep useful tests and stay within the requested scope. Test count and line coverage
alone do not show whether tests can catch regressions.

For a suspect test, ask what requirement it protects, which production API or entry
point it exercises, and what bug it could catch. Also ask whether a change that
preserves behavior would break the test. These questions guide the review; they
do not require a written record for each test.

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

## Reduce duplicate cases and test support code

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
  and runner configuration. Simplify harnesses, inheritance, builders, and parameter
  matrices that make tests hard to follow. Prefer explicit inputs and expectations.
  Keep shared setup that helps realistic tests. Do not sacrifice readability to
  remove duplication or ban useful parameterized, property-based, or fuzz tests.

## Preserve useful checks

Replace a bad test when it is the only test of a current requirement, and exercise
that requirement through the existing production API or entry point. If it protects
no requirement or duplicates adequate coverage, delete it without a replacement.
Keep coverage of security boundaries, persistent formats in use, external failures
that can occur, and compatibility commitments. Do not add cases for hypothetical
requirements, expose private code, or add abstractions just to write replacement
tests.

Do not weaken assertions, skip failing tests, or delete regression cases just to
make tests pass. Determine whether the failure is a regression, an authorized
contract change, or a test tied to obsolete internals. Fix the code or test for
that reason. Do not copy the new implementation into the expected result.

These rules draw on:

- [Google: Change-Detector Tests Considered Harmful](https://testing.googleblog.com/2015/01/testing-on-toilet-change-detector-tests.html).
- [Software Engineering at Google: Unit Testing](https://abseil.io/resources/swe-book/html/ch12.html) and [Test Doubles](https://abseil.io/resources/swe-book/html/ch13.html).
- [Microsoft: Unit testing best practices](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-best-practices).
- [Jest: Snapshot testing best practices](https://jestjs.io/docs/snapshot-testing#best-practices).
- [Martin Fowler: Test Coverage](https://martinfowler.com/bliki/TestCoverage.html).
