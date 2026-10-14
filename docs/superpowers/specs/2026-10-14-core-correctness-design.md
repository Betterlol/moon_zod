# Core correctness and Zod 4 semantics

The user's core review identified silent rule bypass, lost parsed values, input
mutation, incorrect integer bounds, inconsistent effect ordering, lossy schema
metadata and incomplete graph traversal. This change fixes those findings in
separate reviewable commits and opens a pull request against main.

## Approved behavior

- `parse` always returns `Result`; runtime input errors never abort.
- Containers return parsed children in all object modes, without mutating input.
- All schema nodes execute their own post-parse refinements. Type-specific rule
  convenience methods may target wrapped schemas; generic refine stays outside.
- Intersection parses independent original inputs and recursively merges outputs;
  incompatible outputs produce a structured validation error.
- Error message changes cannot delete or move checks.
- Per the user's explicit choice, optional accepts absence only; nullable accepts
  null; nullish accepts either. Default substitutes missing output values and
  prefault parses missing input defaults. Explicit null is passed to the inner
  schema. Missing input remains distinct from present null throughout wrappers.
- Finite number and safe integer behavior follows Zod 4. Numeric bounds and
  multiple-of support floating point values, with integer compatibility helpers
  retained where possible. Bigint remains a documented JSON number alias, not
  arbitrary precision storage.
- Refinements see parsed values. Non-continuable child failures prevent parent
  callbacks; ordinary constraint failures may collect additional issues.
- Built-in constraints and transforms have inspectable metadata; exporters never
  silently replace unsupported custom effects with identity functions.
- Schema traversal covers every container and wrapper, detects unsupported
  anonymous recursive expansion, and separates names from traversal state.
- Error paths distinguish literal keys from array indices; union retains nested
  structured issues. Explicit error messages have precedence over parse error maps.

## Boundaries

The JSON-only runtime, package separation, root reexports and synchronous core
stay intact. Existing public helper functions remain available for compatibility;
internal additions use private visibility. Changes to optional/default, finite
numbers and metadata interfaces are documented as a breaking migration.
No Date/Map/Set runtime or TypeScript inference system is introduced.

## Implementation choices

Use a private missing-input parser and optional parsed output for object fields,
so no undefined sentinel can leak into Json. Keep the public raw parse helper
signatures. Centralize rule execution helpers and shared child traversal. Keep
legacy string error paths, using escaped bracket notation for special keys, and
retain nested union issues in a new structured issue payload. Constructors copy
mutable input collections. Add structured rule/effect metadata only where it
can be kept consistent with the existing annotation API.

Anonymous recursive export must return a clear unsupported-schema error rather
than recurse indefinitely; runtime recursive parsing of finite JSON remains
supported. Named recursive definitions should be emitted through references.

## Validation

Each fix first receives a meaningful failing regression. Every implementation
commit runs `moon test`, `moon info`, `moon fmt`, checks generated interface diffs
and stages only intended paths. Final validation covers default Wasm and JS,
export/import behavior, escaped paths, nested effects, callback ordering and
input immutability. A fresh reviewer audits the whole branch before the PR.
