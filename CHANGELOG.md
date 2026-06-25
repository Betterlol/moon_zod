# Release History

## v0.7.0 (2026-06-26)

**JSON Schema ↔ MoonBit Code Generation + MoonBit Struct Generation + Validate CLI**

- `to_json_schema_named(Schema)` — export named schemas as separate JSON Schema with `$defs` and `$ref`
- `json_schema_to_moon_zod(Json)` — convert JSON Schema (draft-07) document to moon_zod source code string; supports `$ref`, `$defs`, `enum`, `type`, `anyOf`/`allOf`/`oneOf`, `format` validators
- `schema_to_moonbit_struct(schema)` / `_full(schema)` — generate MoonBit struct definitions from ObjectType/EnumType schema, with optional `from_json()` functions for type-safe JSON → struct conversion
- `schema_to_moonbit_struct_named(schema)` / `_full(schema)` — same as above but extracts all nested named schemas and topologically sorts them
- `cmd/gen-struct/` CLI: `moon run cmd/gen-struct -- '<json>'` — infer MoonBit struct from JSON sample
- `cmd/validate/` CLI: `moon run cmd/validate -- '<sample.json>' '<data.json>'` — infer schema from sample and validate data; supports JSON Lines batch mode
- **377 total tests**, 0 warnings, 0 external dependencies

---

## v0.6.0 (2026-06-22)

**Schema Named Export + Topological Sorting — Modular LLM Tool Schemas**

- `schema_to_prompt_named(schema: Schema) -> String` — auto-extracts named schemas and generates modular TypeScript interfaces with type name references
- **Auto-extraction**: recursive tree traversal collecting all schemas with `name` field set (no manual registration required)
- **Topological sorting**: DFS-based sort with three-state cycle detection ensures definitions precede references
- **Field reference replacement**: object fields automatically reference named schemas instead of inline expansion
- Schema struct: new `name: String` field (initialized as `""`, chainable via `.name(text)` method)
- All 15 core modules updated to propagate `name` field through wrapper types (`optional`, `default`, `transform`, etc.)
- 6 new tests covering: basic export, deep nesting, topological sort verification, optional fields
- **282 total tests (278 black-box + 4 white-box), 0 warnings, 0 external dependencies**
- Supports arbitrary nesting depth, circular reference detection, and 100+ named schemas

## v0.5.1 (2026-06-15)

**Publish fix — exclude internal/working files from mooncakes.io package**

- `moon.mod`: add `options(exclude: [...])` to prevent `prompt.md`, `step_phase_details/`, `doc/`, `bench_cross_lang/`, `AGENTS.md`, `moonbit_syntax_pitfalls.md`, and build artifacts from being published to mooncakes.io
- `moon publish` does not read `.gitignore`; it uses independent `include`/`exclude` in `moon.mod`

## v0.5.0 (2026-06-15)

**7 new validators + Enhanced email/URL + Type-level error messages**

- New string validators: `.cuid()`, `.datetime()`, `.ip()`/`.ipv4()`/`.ipv6()`, `.ulid()`, `.length(n)`
- New number validators: `.finite()`, `.safe()`
- `.url()` — full URL structure parsing (scheme://host[:port][/path][?query][#fragment])
- `.email()` — enhanced validation (quoted local parts, IP literal domains, +tag, TLD≥2)
- Type-level error messages: `required_error?` and `invalid_type_error?` parameters on all factory functions (`string()`, `number()`, `boolean()`, `null()`, `array()`, `object()`, `enum_values()`, `union()`, `intersection()`)
- IPv6 parsing fix: `::` double-colon group counting now uses `while` loop (MoonBit `for` variables are immutable)
- All error type fields correctly propagate through `.optional()` / `.default()` / `.transform()` wrappers
- 276 tests (272 black-box + 4 white-box), 0 warnings, 0 external dependencies

## v0.4.0 (2026-06-11)

**Intersection type + Custom error messages + Enhanced validators**

- `Schema::intersect(other)` / `intersection(Array[Schema])` — intersection combinator with `allOf` JSON Schema export and object field merging
- `.min(n, msg?)`, `.max(n, msg?)`, `.nonempty(msg?)`, `.email(msg?)`, `.url(msg?)`, `.regex(pattern, msg?)` — per-rule custom error messages via optional `msg?` parameter
- `.message(text)` — chainable method to override the last rule's message, penetrating OptionalType/DefaultType/TransformType wrappers
- `.startsWith(prefix, msg?)` / `.endsWith(suffix, msg?)` / `.includes(substring, msg?)` — prefix, suffix, and substring string validators
- `.uuid(msg?)` — UUID v4 format validator (character-by-character: 8-4-4-4-12, version 4, variant 8/9/a/b)
- Improved `.email()` — now rejects multiple `@`, leading/trailing dots, single-char domains
- All validators emit JSON Schema annotations (`format: "uuid"`, `pattern: "^..."`, etc.)
- 189 tests (185 black-box + 4 white-box), 0 warnings, 0 external dependencies

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

