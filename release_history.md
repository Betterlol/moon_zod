# Release History

## v0.2.2 (2026-06-08)

### Features
- **Full constraint JSON Schema export**: `to_json_schema()` now exports constraint annotations (minLength, maxLength, maximum, minimum, pattern, format, exclusiveMinimum, exclusiveMaximum, multipleOf, etc.)
- **Skeleton export**: `to_json_schema_skeleton()` added for lightweight structural-only JSON Schema output (previous `to_json_schema` behavior)

### Improvements
- `string().min(n)` / `max(n)` → emits `minLength` / `maxLength` (or `minimum`/`maximum`/`minItems`/`maxItems` for numbers/arrays)
- `string().email()` → emits `format: "email"`
- `string().url()` → emits `format: "uri"`
- `string().regex(p)` → emits `pattern: p`
- `number().int()` → emits `type: "integer"` (overrides base `type: "number"`)
- `number().positive()` → emits `exclusiveMinimum: 0`
- `number().negative()` → emits `exclusiveMaximum: 0`
- `number().multipleOf(n)` → emits `multipleOf: n`
- Benchmark suite migrated from manual for-loop timing to `@bench` library (calibrated ns/op metrics)

### Internal
- Added `annotation: Json` field to `Rule` struct
- Added `append_rule_with_annotation()` for rule methods to carry JSON Schema constraint metadata
- 95 tests (85 existing + 8 new constraint export tests), zero warnings

## v0.2.1 (2026-06-07)

### Fixes
- Rename module from `username/moon_zod` to `Betterlol/moon_zod` for registry publish
- Fix registry username case: `betterlol` → `Betterlol` (uppercase L)

### Internal
- Updated all `moon.pkg` import paths and `moon.mod` metadata
