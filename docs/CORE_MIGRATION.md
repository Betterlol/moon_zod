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
