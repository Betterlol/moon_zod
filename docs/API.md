## API Reference

### Factory Functions

| Function | Description |
|---|---|---|
| `string(required_error?, invalid_type_error?)` | Validates JSON strings |
| `number(required_error?, invalid_type_error?)` | Validates JSON numbers |
| `boolean(required_error?, invalid_type_error?)` | Validates JSON booleans |
| `null(required_error?, invalid_type_error?)` | Validates JSON null |
| `array(Schema, required_error?, invalid_type_error?)` | Validates arrays, recursively checking elements |
| `object(Map[String, Schema], required_error?, invalid_type_error?)` | Validates objects. **Default: Strip mode** |
| `enum_values(Array[String], required_error?, invalid_type_error?)` | Fixed set of allowed string values |
| `union(Array[Schema], required_error?, invalid_type_error?)` | Union type — passes if any schema matches |
| `intersection(Array[Schema], required_error?, invalid_type_error?)` | Intersection — passes if all schemas match; object fields are merged |

### Schema Methods

| Method | Applies To | Description |
|---|---|---|
| `.parse(Json, path?)` | All | Validate, returns `Ok(Json)` or `Err(Array[ValidationError])` |
| `.min(n[, msg])` | string / number / array | Minimum length / value |
| `.max(n[, msg])` | string / number / array | Maximum length / value |
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
| `.length(n[, msg])` | string / array | Must have exact length `n` |
| `.finite([msg])` | number | Must be finite (not NaN, not ±Infinity) |
| `.safe([msg])` | number | Must be a safe integer (not NaN, not ±Infinity, no fractional part) |
| `.optional()` | Any | Null or missing values skip validation |
| `.default(value)` | Any | Replace null with default value |
| `.strict()` | object | Reject undefined fields |
| `.passthrough()` | object | Keep undefined fields as-is |
| `.strip()` | object | Silently remove undefined fields (default) |
| `.describe(text)` | Any | Attach description rendered by `schema_to_prompt()` for LLM prompts |
| `.message(text)` | Any | Override the last rule's error message |
| `.intersect(other)` | Any | Intersection: input must match both schemas; object fields are merged |
| `.pick(keys)` | object | Select only specified fields |
| `.omit(keys)` | object | Remove specified fields |
| `.partial()` | object | Make all fields optional |
| `.refine(check, msg)` | Any | Custom validation predicate |
| `.transform(fn)` | Any | Validate then transform output via `(Json) -> Result[Json, String]` |

### Standalone Functions

| Function | Description |
|---|---|
| `schema_to_prompt(Schema)` | Generate TypeScript-interface prompt string for LLM (with constraint comments) — inline expansion |
| `schema_to_prompt_named(Schema)` | Generate modular TypeScript interfaces from named schemas with topological sorting and type name references — for complex, nested LLM tool schemas |
| `to_json_schema(Schema)` | Export standard JSON Schema object with full constraint annotations |
| `to_json_schema_skeleton(Schema)` | Export lightweight JSON Schema skeleton (structure only, no constraints) |
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