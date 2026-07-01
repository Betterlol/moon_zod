## API Reference

### Factory Functions

| Function | Description |
|---|---|
| `string(required_error?, invalid_type_error?)` | Validates JSON strings |
| `number(required_error?, invalid_type_error?)` | Validates JSON numbers |
| `boolean(required_error?, invalid_type_error?)` | Validates JSON booleans |
| `null(required_error?, invalid_type_error?)` | Validates JSON null |
| `array(Schema, required_error?, invalid_type_error?)` | Validates arrays, recursively checking elements |
| `object(Map[String, Schema], required_error?, invalid_type_error?)` | Validates objects. **Default: Strip mode** |
| `enum_values(Array[String], required_error?, invalid_type_error?)` | Fixed set of allowed string values (use `literal()` + `union()` for mixed types) |
| `literal(Json, required_error?, invalid_type_error?)` | **Phase 32**: Constant value validation — only accepts exact JSON match (string, number, boolean, null, array, or object) |
| `union(Array[Schema], required_error?, invalid_type_error?)` | Union type — passes if any schema matches |
| `intersection(Array[Schema], required_error?, invalid_type_error?)` | **Phase 18**: Intersection — passes if all schemas match; object fields are merged |

### Schema Methods

| Method | Applies To | Description |
|---|---|---|
| `.parse(Json, path?)` | All | Validate, returns `Ok(Json)` or `Err(Array[ValidationError])` |
| `.min(n[, msg])` | string / number / array | Minimum length / value |
| `.max(n[, msg])` | string / number / array | Maximum length / value |
| `.length(n[, msg])` | string / array | Exact length |
| `.nonempty([msg])` | string | String must not be empty |
| `.email([msg])` | string | Full email validation (quoted local, IP literal, +tag, TLD≥2, single @) |
| `.url([msg])` | string | Full URL structure: `scheme://host[:port][/path][?query][#fragment]` |
| `.regex(pattern[, msg])` | string | Must contain `pattern` as substring |
| `.startsWith(prefix[, msg])` | string | Must start with `prefix` |
| `.endsWith(suffix[, msg])` | string | Must end with `suffix` |
| `.includes(substring[, msg])` | string | Must contain `substring` |
| `.uuid([msg])` | string | Must be a valid UUID v4 |
| `.cuid([msg])` | string | Must be a valid CUID (c + base36 hash) |
| `.datetime([msg])` | string | Must be ISO 8601 datetime (date + T + time ± offset/Z) |
| `.ip([msg])` | string | Must be a valid IPv4 or IPv6 address |
| `.ipv4([msg])` | string | Must be a valid IPv4 address |
| `.ipv6([msg])` | string | Must be a valid IPv6 address (full/shorthand, :: support) |
| `.ulid([msg])` | string | Must be a valid ULID (26-char Crockford base32) |
| `.int([msg])` | number | Must be integer (no fractional part) |
| `.positive([msg])` | number | Must be > 0 |
| `.negative([msg])` | number | Must be < 0 |
| `.multipleOf(n[, msg])` | number | Must be multiple of `n` |
| `.finite([msg])` | number | Must be finite (not NaN, not ±Infinity) |
| `.safe([msg])` | number | Must be a safe integer (not NaN, not ±Infinity, no fractional part) |
| `.optional()` | Any | Null or missing values skip validation |
| `.default(value)` | Any | Replace null with default value |
| `.strict()` | object | Reject undefined fields |
| `.passthrough()` | object | Keep undefined fields as-is |
| `.strip()` | object | Silently remove undefined fields (default) |
| `.describe(text)` | Any | **Phase 17**: Attach description rendered by `schema_to_prompt()` for LLM prompts |
| `.message(text)` | Any | **Phase 19**: Override the last rule's error message |
| `.name(text)` | Any | **Phase 25**: Assign a name for schema exports and code generation |
| `.intersect(other)` | Any | **Phase 18**: Intersection: input must match both schemas; object fields are merged |
| `.pick(keys)` | object | **Phase 21**: Select only specified fields |
| `.omit(keys)` | object | **Phase 21**: Remove specified fields |
| `.partial()` | object | **Phase 21**: Make all fields optional |
| `.refine(check, msg)` | Any | Custom validation predicate |
| `.transform(fn)` | Any | **Phase 13**: Validate then transform output via `(Json) -> Result[Json, String]` |

### Standalone Functions

| Function | Description |
|---|---|
| `schema_to_prompt(Schema)` | **Phase 16**: Generate TypeScript-interface prompt string for LLM (with constraint comments) — inline expansion |
| `schema_to_prompt_named(Schema, include_names?)` | **Phase 25, 34**: Generate modular TypeScript interfaces from named schemas with topological sorting and type name references |
| `to_json_schema(Schema)` | **Phase 15**: Export standard JSON Schema object with full constraint annotations |
| `to_json_schema_skeleton(Schema)` | **Phase 15**: Export lightweight JSON Schema skeleton (structure only, no constraints) |
| `to_json_schema_named(Schema, include_names?)` | **Phase 26, 34**: Export named schemas as separate JSON Schema definitions with `$defs` and `$ref` |
| `json_schema_to_moon_zod(Json)` | **Phase 27, 36**: Reverse-generate moon_zod schema source code from a JSON Schema object; supports `$defs`, `$ref`, constraints, format validation |
| `schema_to_moonbit_struct(Schema)` | **Phase 28**: Generate MoonBit struct definition (type name, fields, constraints) from ObjectType/EnumType |
| `schema_to_moonbit_struct_full(Schema)` | **Phase 29**: Generate struct definition + `from_json()` function for type-safe JSON → struct conversion |
| `schema_to_moonbit_struct_named(Schema, include_names?)` | **Phase 31**: Same as `schema_to_moonbit_struct()` but extracts and topologically sorts all nested named schemas |
| `schema_to_moonbit_struct_named_full(Schema, include_names?)` | **Phase 31**: Same as `schema_to_moonbit_struct_full()` but extracts all nested named schemas |
| `schema_to_moon_zod_code(Schema)` | Generate moon_zod schema source code from a Schema |
| `schema_to_moon_zod_code_named(Schema, include_names?)` | Generate moon_zod schema source code with named `$defs` and `$ref` references |
| `json_schema_to_schema(Json)` | Reverse-parse a JSON Schema object into a moon_zod Schema |
| `json_infer_schema(Json)` | Infer a moon_zod Schema from a sample JSON value |
| `append_rule(Schema, (Json) -> Bool, String)` | Append a raw validation rule to a schema |
| `append_rule_with_annotation(Schema, (Json) -> Bool, String, Json)` | Append a validation rule with an annotation payload |
| `format_path(Array[String])` | Join path stack to dot-notation string |
| `ValidationError::to_string()` | Format error as `[path] message (got: value)` |

### Core Types

```mbt nocheck
///|
pub struct ValidationError {
  path : String
  message : String
  got : Json
}

///|
pub type SchemaResult = Result[Json, Array[ValidationError]]

///|
pub enum ObjectMode {
  Passthrough
  Strict
  Strip
}
```

---