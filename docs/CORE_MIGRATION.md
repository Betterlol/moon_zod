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

The runtime remains JSON-only. JSON transformations do not receive a JavaScript
undefined value: absent optional values propagate through transformations without
calling a Json callback. Place default/prefault before a transform when the
callback should receive a fallback. Present null is always a real Json value.

Array and tuple elements and declared object fields now retain parsed values in
all modes. Intersection no longer changes caller input and reports incompatible
outputs. Generic refinements remain attached to the layer on which they were
declared; type-specific convenience checks can still target a wrapped schema.

JSON Schema input exports no longer add null to optional/default fields. Prompt
aliases use undefined for optional values. MoonBit structs describe parsed output:
defaulted fields are required, nullable and optional fields use option types.

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

Schema has a stable id used by traversal; use factories rather than fabricating
ids. Lazy resolution is cached. Duplicate export names and anonymous recursive
expansion now fail explicitly. Public renderer implementations must implement
render_lazy(), so named recursion can use references instead of inline expansion.
