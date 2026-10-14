# Core semantics migration

This branch follows Zod 4 for missing keys, explicit null and default values.

| Old usage | New behavior / migration |
| --- | --- |
| `string().optional()` accepting null | Use `.nullish()` for missing or null; optional now permits missing only. |
| Required field accepting null | Use `.nullable()`; the key remains required. |
| `.default(value)` replacing null | Defaults fill missing keys only. Explicit null is validated by the inner schema. |
| A missing defaulted key staying absent | The parsed object now contains the default value. |
| Fallback requiring validation/transformation | Use `.prefault(value)` for an input fallback; `.default(value)` is an output fallback. |
| Parsing an absent root value | Use `.parse_missing()`, whose success value is `Json?`. `None` means absence. |

The runtime remains JSON-only. JSON transformations and refinements do not receive a JavaScript
undefined value: absent optional values propagate without calling a Json callback. Place default/prefault before a transform when the
callback should receive a fallback. Present null is always a real Json value.

Array and tuple elements and declared object fields now retain parsed values in
all modes. Intersection no longer changes caller input and reports incompatible
outputs. Generic refinements remain attached to the layer on which they were
declared; type-specific convenience checks can still target a wrapped schema.

JSON Schema input exports no longer add null to optional/default fields. Prompt
aliases use undefined for optional values. MoonBit structs describe parsed output:
defaulted fields are required; missing fields use Option, while nullable values
use JsonNullable (see the codec note below).

`Schema::brand()` is export metadata; it does not create a nominal MoonBit type.
`bigint()` remains an integer JSON-number alias, with Double precision limitations,
and must not be used for arbitrary precision IDs or money storage.

Built-in rules now expose a structured Constraint and explicit-message origin.
TransformClosure carries TransformKind instead of the old is_builtin flag.
ConstraintInfo min_value/max_value are optional bounds; negative values are no
longer sentinels. Repeated patterns/formats/multiples are retained as arrays.
Public helper functions remain available; new parser helpers stay private.

Use try_schema_to_moon_zod_code() when a schema may contain opaque callbacks.
Built-in operations roundtrip as their original methods; legacy source export
functions now fail explicitly on custom transforms/preprocessors/refinements.
Named recursive source uses schema functions and lazy references.

try_to_json_schema(view=InputView/OutputView) exports a structural stage contract.
Input Strip objects allow extra fields because parsing removes those fields;
output Strip objects are closed. Unknown custom transform output and untyped
preprocess input return errors; pipe(output_schema) supplies a known output.
The legacy to_json_schema() remains a closed generation contract for LLM use.
It must not be interpreted as an exact predicate for every effectful raw input.
Recursive output projections require an explicit output schema.
Recursive Strip/intersection input projections and post-effect recursive input checks also
return errors rather than exporting an inaccurate contract. Use an explicit
structural input schema for those cases.

Schema has a stable id used by traversal; use factories rather than fabricating
ids. Lazy resolution is cached. Duplicate export names and anonymous recursive
expansion now fail explicitly. Public renderer implementations must implement
render_lazy(), so named recursion can use references instead of inline expansion.

`ValidationError` and `RawIssue` add `path_segments: Array[PathSegment]`.
`RawIssue` also records `explicit_message`. Code constructing these records must
provide those fields. Prefer factories and parser results over manual records.
`IssueCode::InvalidUnion` now contains `Array[Array[RawIssue]]`, including every
issue from every aborted branch, rather than one message string per branch.
Nested union issues are localized by the same error map as the outer issue.
Explicit Schema/rule messages win over a parse error map; `Some("")` is a real
empty message, while `None` delegates to the default message.

`number()` rejects NaN and infinity. `int()` and `safe()` require an integer
within ±(2^53−1). Numeric bounds, gt/lt and multipleOf accept Int, Int64 or Double;
string/array length bounds must remain nonnegative integers. Multiple-of uses
decimal representations rather than a broad floating-point tolerance:
`0.3` is a multiple of `0.1`, whereas `0.30000000000000004` is not.

Email validation rejects spaces, consecutive dots and malformed domain labels.
UUID accepts RFC versions 1–8 plus nil/max values. Datetime requires a complete
date and time, with UTC `Z` by default; pass `offset=true`, `allow_local=true` or
`precision` explicitly. URI validation supports absolute schemes, IPv6 authorities
and bounded numeric ports; it is a portable validator, not WHATWG normalization.

Object pick/omit/partial/extend_with/merge now reject objects carrying refinements.
Build the final shape first, then refine it, or validate separate shapes through
intersection. This prevents a refinement from accessing removed or changed fields.
Discriminated unions require object branches; a missing tag is injected as a
literal field, while a declared tag must match its branch key. Parsed tags survive
Strip and Strict modes.

JSON Schema imports now honor additionalProperties=false by rejecting extras.
Use `.strip()` explicitly after importing when your caller needs cleanup instead.
Typed allOf annotation fragments retain repeated constraints instead of dropping
them. The importer remains a partial draft-07 implementation; this change does not
add general recursive $ref import or every JSON Schema keyword.

The old zero-allocation claim and performance comparisons do not describe this
parser. Parsed containers are rebuilt and branch inputs are isolated. Historical
benchmark results remain labeled as historical and require remeasurement.

Strict object intersection input views return Err: the legacy exporter merges
object fields for generation, which cannot describe independent Strict branch
checks. Use separate structural contracts when these branches must be retained.

Union selection now follows Zod 4: exactly one continuable failing branch can
report its own issues; multiple such branches produce complete InvalidUnion
payloads. Input failures before a transform/pipe prevent output refinements from
observing a value for a stage that never ran.

## Follow-up composition corrections

Checked OutputView recursively merges object fields, array elements and tuple
positions for intersections. Overlapping missing values or conditional/mixed
structural shapes return Err when a faithful merge contract cannot be constructed.
The legacy generation renderer is not used as the output merge algorithm.

Source bounds outside Int32 retain an explicit Double literal, such as
9007199254740991.0, including min/max/gt/lt/multipleOf arguments. Pipeline output
defaults/prefaults survive optional and partial when the input can propagate
absence. Unreachable output defaults do not prevent outer optional from accepting
absence.

Tuple outputs omit trailing absent positions. A missing position before a later
present/defaulted value cannot be represented by JSON; parsing returns a Custom
issue at that position rather than inserting null. A present null remains valid
only when that position's schema permits null.

Generated nullable types now use `@moon_zod.JsonNullable[T]`, whose cases are
`JsonNull` and `JsonValue(T)` and whose ToJson/FromJson codecs use inline null-or-value
JSON. This is intentional: MoonBit's standard Option uses singleton-array encoding
outside direct struct fields. For example, an array of nullable strings generates
`Array[@moon_zod.JsonNullable[String]]`, not `Array[String]` or `Array[String?]`.
Missing object fields add an outer `?`; nullish strings therefore generate
`@moon_zod.JsonNullable[String]?`, preserving missing versus present null. Import
the root moon_zod package to compile these generated types. Raw Json fallbacks
inside arrays remain valid type expressions without inline comments.

URI checks reject raw whitespace/control/non-ASCII characters and malformed %HH
escapes in path, query, fragment, userinfo and opaque scheme payloads. Encode
non-ASCII data as percent-encoded bytes. This remains an ASCII URI subset and
performs no WHATWG normalization. See RFC 3986 sections 2.1 and 3.2–3.5.

Cross-feature checks now compile large numeric bounds, decode/re-encode generated
nullable structs, and independently validate successful outputs against checked
OutputView using JSON Schema draft 2020-12. Old throughput figures in both README
languages and their source fragments are explicitly historical.
