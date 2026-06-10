# Release History

## v0.3.0 (2026-06-10)

**schema_to_prompt() + .describe() field descriptions**

- `schema_to_prompt(Schema) -> String` — auto-generates TypeScript-interface prompt text with `//` constraint comments
- `.describe(text)` — attach human-readable descriptions to any schema, rendered by `schema_to_prompt()`
- `schema_to_prompt()` now merges constraint comments with descriptions (`// [constraints] — description`)
- `.optional()` / `.default()` / `.transform()` automatically propagate `self.description`
- `unwrap_schema()` penetrates wrapper types for correct inner type display
- 120 tests (116 black-box + 4 white-box), 0 warnings

## v0.2.2 (2026-06-08)

**Complete JSON Schema constraint export**

- `to_json_schema()` now exports full constraints (minLength, maximum, pattern, format, etc.)
- `to_json_schema_skeleton()` — lightweight structural export without constraints
- `Rule.annotation: Json` field for per-rule schema annotation metadata
- Backward-compatible: schemas without rules produce identical output
- 95 tests, 0 warnings

## v0.2.1 (2026-06-07)

**Registry publish + bench modernization**

- Fix registry username case (`Betterlol` with uppercase L)
- Migrate from manual `for` loop timing to `@bench` standard library
- 85 tests, 0 warnings

## v0.2.0 (2026-06-06)

**Data transform pipeline + path stack safety net**

- `Schema::transform(fn)` — validate then transform output (`(Json) -> Result[Json, String]`)
- `TransformClosure` wrapper for function-as-field pattern
- 4 white-box tests for path stack push/pop invariants
- `append_rule` / `inner_type` penetrate TransformType for correct chaining
- 85 tests (81 black-box + 4 white-box), 0 warnings

## v0.1.0 (2026-06-05)

**Initial release** — Core validation library feature-complete.

- Core types: `string()`, `number()`, `boolean()`, `null()`, `array()`, `object()`
- Validation rules: `.min()`, `.max()`, `.nonempty()`, `.email()`, `.url()`, `.regex()`, `.int()`, `.positive()`, `.negative()`, `.multipleOf()`
- Object modes: `Strip` (default), `Passthrough`, `Strict`
- Combinators: `.optional()`, `.default()`, `enum_values()`, `union()`, `refine()`
- Mutable path stack — zero heap allocation on success path
- `to_json_schema()` standard JSON Schema export
- LLM self-correction demo & educational agent
- Cross-language benchmark (MoonZod vs TS Zod vs Handcrafted)
- JSON-to-Schema code generator CLI (`cmd/json2schema/`)
- 74 tests, 0 warnings, 0 external dependencies

---

For detailed phase-by-phase development history, see [`step_phase_summary.md`](./step_phase_summary.md).
