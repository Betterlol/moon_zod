# Release History

[![doc](https://img.shields.io/badge/branch-doc-blue)](https://github.com/Betterlol/moon_zod/tree/doc)

**To see the full details, please refer to docs in branch `doc`.**

## v0.8.2 (2026-07-12)

### Add README in exporters/ and importers/ subpackages
- `exporters/README.md` and `importers/README.md` added to document public API, file structure, and implementation details

### Schema Chainable Error Methods
- `Schema::required_error(text)` and `Schema::invalid_type_error(text)` chainable methods added to `core/schema.mbt`
- Previously only available as factory parameters (`string(required_error?, invalid_type_error?)`), now also chainable: `string().min(2).required_error("...").invalid_type_error("...")`

**479 tests** (all passing, 0 warnings)

## v0.8.1 (2026-07-07)

**Exporter Hardening — Prompt Unification, JSON Schema Fixes, Renderer Convergence (Phase 41)**

### A — Prompt Exporter Unification
- `schema_to_prompt()` no longer uses `BasicPromptRenderer`; unified behind `NamedPromptRenderer` with empty named set for full inlining
- `any/unknown/tuple/preprocess` now render safely (`any`, `unknown`, `[T...]`, transparent pass-through) instead of aborting
- Named wrapper schemas (primitive, array, optional, default, transform, tuple, any, unknown, preprocess) now emit `export type X = T` definitions
- Named object intersection outputs `export type X = A & B` when non-object branches exist; field merging no longer drops constraints
- Object field references now preserve wrapper names (e.g., `metadata?: ProductMetadata`)
- Removed `BasicPromptRenderer` from public API

### B — JSON Schema Exporter Fixes
- `any/unknown/tuple/preprocess` now export (`{}`, `prefixItems` + fixed length, transparent pass-through) instead of aborting
- `optional()` / `default()` now export nullable semantics: `anyOf: [inner, {"type": "null"}]`
- `Strip` mode now exports `additionalProperties: false` (previously `true`) — aligns with runtime hallucination defense
- Object intersection (`allOf` of multiple closed objects) merged into a single closed object to avoid unsatifiable schemas; overlapping fields use property-level `allOf` to retain constraints
- Named `$defs` entries no longer self-reference via `$ref`
- Renderer types consolidated: removed `FullJsonRenderer` and `SkeletonJsonRenderer`; single `NamedJsonRenderer` with `include_annotations` flag covers all three modes
- Schema skeleton export now properly omits constraint annotations

### C — Code Exporter Fixes
- `schema_to_moon_zod_code()` now handles `any()`, `unknown()`, `tuple()`, `preprocess()` with valid code output
- Fixed `json_to_literal` for boolean/null values (no longer uses non-existent `Json::boolean()` / `Json::null()` constructors)
- `schema_to_moonbit_struct_named()` and `schema_to_moonbit_struct_named_full()` removed from public API (deferred: moonbit_struct exporter not yet hardened to Phase 41 standard for tuple/any/unknown)

---

## v0.8.0 (2026-07-06)

**MoonBit Struct Generator Rewrite + Gen-Struct CLI + Docs Migration (Phase 40)**

### MoonBit Struct Generator Rewrite
- Complete rewrite of `schema_to_moonbit_struct()` — now emits static `Type::to_schema()` functions alongside struct/enum definitions, enabling schema-from-struct round-trips
- Dropped `from_json()` generation (`schema_to_moonbit_struct_full` no longer includes `FromJson` derive functions — use MoonBit's built-in `derive(FromJson)` instead)
- New `schema_to_moonbit_struct_full()` generates both type definitions and `Type::to_schema()` static methods
- Added keyword and reserved-name escaping for field names and type names (MoonBit `is_keyword()`, `escape_variable_name()`, `escape_type_name()`)
- Unified root name fallback with `"Root"` for unnamed schemas
- Constraint comments preserved on generated struct fields
- ~1500 line net reduction through elimination of `from_json()` code generation

### Gen-Struct CLI
- New `cmd/gen-struct/cli.sh` for file-based input: `sh cmd/gen-struct/cli.sh --schema schema.json`
- Inline mode: `moon run cmd/gen-struct -- --schema '<json>'`
- Outputs standalone struct definitions + optional `Type::to_schema()` functions
- Supports nested objects, arrays, optional fields, enums, union nullables

### Documentation & Examples
- New `examples/gen-struct/README.md` with generated struct output examples
- Major docs restructure: `README.mbt.md`/`README_zh.mbt.md` migrated to reference `docs/` directory
- `docs/API.md`, `docs/CLI.md`, `docs/INFO.md` (Chinese versions in `docs/zh/`) consolidated as single source of truth
- `EXAMPLES.md` rewritten to catalog all actual examples with output snippets

### Fixes
- `value_in_array` moved from `prompt.mbt` to `shared_utils.mbt` for cross-module reuse
- Fixed `json_to_literal()` boolean/null output to use valid MoonBit constructors
- Fixed `moon run cmd/validate` JSON Lines — shell `\n` is now correctly interpreted as real newline

**448 tests** (all passing, 0 warnings)

---

## v0.7.5 (2026-07-02)

**Code Review + Unified Export Design + CLI Polish (Phase 36)**

### Part A: Critical Bug Fixes
- Fixed `exclusiveMinimum`/`exclusiveMaximum` semantics (was incorrectly inclusive, now correctly exclusive)
- Fixed floating-point truncation in `minimum`/`maximum` constraints (`.to_int()` was losing precision)
- Extended `enum_values()` to support non-string values (numbers, booleans, null) via `union()` + `literal()` pattern
- 12 specialized tests for edge cases (`test_json_schema_fixes.mbt`)

### Part B: Unified Export Design
- All 7+ export functions (`schema_to_prompt`, `to_json_schema`, `schema_to_moonbit_struct`, etc.) now apply root schema name protection
- Unnamed schemas automatically default to `"Root"` name for export consistency
- Improved error messages in struct generation

### Part C: CLI Tool Improvements
- `cmd/json2schema`: default output is now pure copy-paste-ready moon_zod code
- `cmd/json2schema`: new `--verbose` / `-v` flag for debug output with input parsing info
- `cmd/validate`: improved error handling, exit code readiness (internal `Bool` returns for future integration)
- Better file mode support: `--schema-file`, `--sample-file`, `--from-json-schema` flags

**Exporters & Importers Functionality Freeze**: Phase 35-36 complete all code generation and import/export pipelines. Marking core libraries as production-ready.

- **426 tests** (all passing, 0 warnings)
- 0 external dependencies

---

## v0.7.4 (2026-06-29)

**Project Modularization + Code Generation Rewrite (Phase 35)**

### Phase A: Subpackage Refactoring
- Reorganized into 5 formal subpackages:
  - `core/` — Core validation (17 files, zero external deps)
  - `exporters/` — Code generation (6 files: prompt, json_schema, moonbit_struct, renderers)
  - `importers/` — JSON Schema reverse import
  - `combinators/` — Composition layer
  - `tests/` — Test suite (426 tests)
- Eliminated architecture violations: exporters no longer depends on importers
- Added `@core.` prefix for explicit intra-package references
- Unified reexporter pattern

### Phase B: Schema Exporter Rewrite
- `schema_to_moon_zod_code()` now outputs `let x = ... .name(...)` format
- Full support for `.describe()`, `.required_error()`, `.invalid_type_error()`, `.strict()`, `.passthrough()`
- Named export with `schema_to_moon_zod_code_named()` and include_names filtering
- Two-layer separation: `json_schema_to_schema` (runtime Schema objects) + code generation

### Phase C: Constraint Extractor + Trait Renderer Pattern
- New `constraint_extractor.mbt` module for unified constraint handling
- Trait-based renderers eliminate 40 scattered `SchemaType` match statements → 4 core matches + 3 traits
- 90% reduction in SchemaType pattern matching across 6 modules
- All 13 SchemaType variants fully supported in exporters/importers

**414 tests** (all passing, 0 warnings)

---

## v0.7.3 (2026-06-28)

**Selective Named Export + Filter Logic Extraction (Phase 34)**

- New `include_names?: Array[String]?` parameter on all named export functions
  - `schema_to_prompt_named(schema, include_names?)`
  - `to_json_schema_named(schema, include_names?)`
  - `schema_to_moonbit_struct_named(schema, include_names?)`
  - `schema_to_moonbit_struct_named_full(schema, include_names?)`
- `filter_named_schemas()` extracted to `shared_utils.mbt` (4 duplicate code paths eliminated)
- Supports: `None` (export all), `Some([])` (export none), `Some([...])` (selective export)

**396 tests** (all passing, 0 warnings)

---

## v0.7.2 (2026-06-27)

**Trait-Based Renderer Pattern + Schema Composition Fixes (Phase 33)**

### Phase A: Quick Fixes
- Fixed Union/Intersection/Literal in named schema exports
- Fixed `.name()` propagation in combinators
- 4 new tests for complex named exports

### Phase B: Constraint Extractor
- Unified constraint extraction logic across 3 renderer modules
- Eliminated ~150 lines of duplicate code
- New `ConstraintInfo` struct and `extract_constraints()` function

### Phase C: Trait Renderer Architecture
- New trait-based pattern: `StringRenderer`, `JsonSchemaRenderer`, `MoonBitStructRenderer`
- Shared utilities: `shared_utils.mbt` with `unwrap_schema()`, `peel_optional()`, `indent_str()`
- Rewrite of prompt, json_schema, moonbit_struct modules to use trait dispatch
- Result: 40 scattered match statements → 4 core matches + 3 traits (~90% reduction)
- New variant support requires only ~7 changes instead of ~15

**385 tests** (all passing, 0 warnings)

---

## v0.7.1 (2026-06-26)

**literal() Constant Validation + union.mbt Refactoring (Phase 32)**

- `literal(Json)` factory — validate exact constant values (string, number, boolean, null, array, object)
- Support for all JSON types via `union()` + `literal()` composition
- Refactored `union.mbt` (217 lines → 42 lines) into separate modules:
  - `optional.mbt` — optional() factory
  - `default.mbt` — default() factory
  - `enum.mbt` — enum_values() factory
  - `literal.mbt` — literal() factory
  - `union.mbt` — union() factory (core logic only)
- One-factory-per-file convention for clarity
- JSON Schema export: `literal()` → `{"const": value}`
- Prompt generation: renders literal values with proper JSON syntax
- MoonBit struct generation: `json_to_literal_code()` for code output

**381 tests** (all passing, 0 warnings)

---

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

