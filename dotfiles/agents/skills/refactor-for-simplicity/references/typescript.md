# TypeScript / JavaScript review

Apply this guide whenever TypeScript, JavaScript, or Node sources are in scope.

## Inspect

- speculative runtime checks on already-typed internal values or responses from
  co-maintained services (while checking that external JSON/untrusted input is
  still validated at ingress, since TypeScript types erase at runtime);
- hand-rolled parsers, giant multi-line regexes, and custom CLI/color/arg
  helpers that duplicate modern runtime built-ins (`node:util` `parseArgs`,
  `styleText`, `fetch`, etc.) or already-installed dependencies;
- ceremonial type gymnastics (`Plugin<any, ...>`, repeated `as` casts) and
  monolithic `types.ts` dumping grounds separated from their owning logic;
- overlapping APIs or dispatch chains (`instanceof` ladders, duplicate calling
  conventions, wrappers that make callers more verbose than native APIs);
- clever rewrites that hurt readability or drop intentional fast paths;
- stale runtime idioms (e.g., Deno `mod.ts` after migrating to Node) and
  hand-written workarounds left behind after upgrading a dependency.

## Rules

- **Validate at real trust boundaries only**: validate untrusted payloads once
  at entry, then rely on the typed contract internally and across co-maintained
  components. Do not add `typeof` or URL-component checks for values your own
  code already guarantees.
- **Use built-ins and installed libraries**: prefer modern Node/Web APIs and
  mature dependencies over custom parsers, giant regexes, or ad-hoc helpers.
  When upgrading a framework or dependency, adopt its new features and delete
  the hand-written code they supersede.
- **Co-locate types and avoid type gymnastics**: keep types next to the module
  that owns them instead of accumulating a giant `types.ts`. If a generic
  signature needs `any` bridges or ugly casts to simulate "strong typing",
  simplify the API design instead.
- **Prefer readable loops and keep fast paths**: do not rewrite a clear loop
  into a clever stdlib call that adds casts or extra passes, and do not delete
  intentional hot-path optimizations (such as zero-allocation scans) just to
  save lines.
- **Keep APIs canonical and callers light**: unify overlapping error classes,
  options, and extension points. Reject abstractions that force more boilerplate
  on callers than using the platform primitive directly.
- **Remove legacy idioms**: after migrating runtimes or major versions, delete
  old entry conventions, compatibility shims, and redundant lint overrides.

## Examples

### Speculative defensive checks on a co-maintained service

```ts
// Avoid: re-validating every URL part returned by your own service
const parsed = new URL(shortUrl);
if (
  parsed.origin !== this.#origin ||
  parsed.username !== "" ||
  parsed.password !== "" ||
  parsed.search !== "" ||
  parsed.hash !== "" ||
  !SHORT_CODE_PATH.test(parsed.pathname)
) {
  throw new Error("short link service returned invalid URL");
}

// Prefer: trust the co-maintained contract; validate untrusted input at ingress
return shortUrl;
```

### Clever shortening that hurts readability

```ts
// Avoid: forcing Map.groupBy only to strip undefined and cast keys back
const buckets = Map.groupBy(items, (item) => getGroup(item) || undefined);
const ungrouped = buckets.get(undefined)?.map(mapItem) ?? [];
buckets.delete(undefined);
const keys = new Set([...titles.keys(), ...(buckets.keys() as Iterable<string>)]);

// Prefer: a direct loop with clear types and no cast
const ungrouped: R[] = [];
const buckets = new Map<string, R[]>();
for (const item of items) {
  const key = getGroup(item);
  const mapped = mapItem(item);
  if (key) {
    const list = buckets.get(key) ?? [];
    list.push(mapped);
    buckets.set(key, list);
  } else {
    ungrouped.push(mapped);
  }
}
```

### Hand-rolled parsers, `instanceof` ladders, and noisier wrappers

```ts
// Avoid: hand-rolled parsers / multi-line scraping regexes when built-ins or libs exist
export function stripJsonc(input: string): string { /* 80 lines of manual scanning */ }
const ENTRY_RE = /^(?:[ \t]+name = ("(?:[^"\\]|\\.)*");\n)?[ \t]+url = ...$/gm;

// Avoid: repetitive instanceof ladders instead of a shared base class or discriminant
if (
  err instanceof UnexpectedArgumentError ||
  err instanceof MissingRequiredArgumentError ||
  err instanceof MissingRequiredFlagError ||
  err instanceof MissingFlagValueError
) { /* ... */ }

// Avoid: wrapping platform primitives when callers become more complex
// Prefer direct process.once("SIGINT", ...) over a custom ctx.signal Promise dance
// if the abstraction adds boilerplate without solving a real problem.
```
