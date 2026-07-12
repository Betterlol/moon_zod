## API Reference

### Factory Functions

| Function | Description |
|---|---|
| `string(required_error?, invalid_type_error?)` | Validates JSON strings |
| `number(required_error?, invalid_type_error?)` | Validates JSON numbers |
| `boolean(required_error?, invalid_type_error?)` | Validates JSON booleans |
| `null(required_error?, invalid_type_error?)` | Validates JSON null |
| `array(Schema, required_error?, invalid_type_error?)` | Validates arrays, recursively checking elements |
| `tuple([Schema...], required_error?, invalid_type_error?)` | **Phase 38**: Fixed-length array — validates each element by position |
| `object(Map[String, Schema], required_error?, invalid_type_error?)` | Validates objects. **Default: Strip mode** |
| `enum_values(Array[String], required_error?, invalid_type_error?)` | Fixed set of allowed string values |
| `literal(Json, required_error?, invalid_type_error?)` | **Phase 32**: Constant value validation — only accepts exact JSON match |
| `bigint(required_error?, invalid_type_error?)` | **Phase 37**: Semantic alias for `number().int()` — expresses big integer intent, need to truly implement |
| `any(required_error?, invalid_type_error?)` | **Phase 39**: Accepts any JSON value (pass-through) |
| `unknown(required_error?, invalid_type_error?)` | **Phase 39**: Accepts any JSON value as unknown (semantic marker) |
| `preprocess((Json) -> Result[Json, String], Schema, required_error?, invalid_type_error?)` | **Phase 39**: Transform raw input first, then validate against inner schema |
| `union(Array[Schema], required_error?, invalid_type_error?)` | Union type — passes if any schema matches |
| `intersection(Array[Schema], required_error?, invalid_type_error?)` | **Phase 18**: Intersection — passes if all schemas match; object fields are merged |

### Schema Methods

| Method | Applies To | Description |
|---|---|---|
| `.parse(Json, path?)` | All | Validate, returns `Ok(Json)` or `Err(Array[ValidationError])` |
| `.min(n[, msg])` | string / number / array | Minimum length / value |
| `.max(n[, msg])` | string / number / array | Maximum length / value |
| `.length(n[, msg])` | string / array / tuple | Exact length |
| `.nonempty([msg])` | string / array / tuple | Must not be empty |
| `.email([msg])` | string | Full email validation |
| `.url([msg])` | string | Full URL structure |
| `.regex(pattern[, msg])` | string | Must match the regular expression `pattern` |
| `.startsWith(prefix[, msg])` | string | Must start with `prefix` |
| `.endsWith(suffix[, msg])` | string | Must end with `suffix` |
| `.includes(substring[, msg])` | string | Must contain `substring` |
| `.trim()` | string | **Phase 37**: Remove leading/trailing whitespace |
| `.to_lower()` | string | **Phase 37**: Convert to lowercase |
| `.to_upper()` | string | **Phase 37**: Convert to uppercase |
| `.uuid([msg])` | string | Must be a valid UUID v4 |
| `.cuid([msg])` | string | Must be a valid CUID |
| `.datetime([msg])` | string | Must be ISO 8601 datetime |
| `.ip([msg])` | string | Must be valid IPv4 or IPv6 |
| `.ipv4([msg])` | string | Must be valid IPv4 |
| `.ipv6([msg])` | string | Must be valid IPv6 |
| `.ulid([msg])` | string | Must be valid ULID |
| `.int([msg])` | number | Must be integer |
| `.positive([msg])` | number | Must be > 0 |
| `.negative([msg])` | number | Must be < 0 |
| `.multipleOf(n[, msg])` | number | Must be multiple of `n` |
| `.finite([msg])` | number | Must be finite |
| `.safe([msg])` | number | Must be a safe integer |
| `.optional()` | any | Null or missing values skip validation |
| `.default(value)` | any | Replace null with default |
| `.strict()` | object | Reject undefined fields |
| `.passthrough()` | object | Keep undefined fields as-is |
| `.strip()` | object | Silently remove undefined fields (default) |
| `.pick(keys)` | object | **Phase 21**: Select only specified fields |
| `.omit(keys)` | object | **Phase 21**: Remove specified fields |
| `.partial()` | object | **Phase 21**: Make all fields optional |
| `.extend_with(Map[String, Schema])` | object | **Phase 38**: Add or override fields from a Map |
| `.merge(Schema)` | object | **Phase 38**: Merge with another object schema (right side overrides) |
| `.describe(text)` | any | **Phase 17**: Attach description for LLM prompts |
| `.name(text)` | any | **Phase 25**: Assign a name for schema exports |
| `.brand(text)` | any | **Phase 37**: Assign a brand marker for nominal typing |
| `.required_error(text)` | any | Override the error message when a required field is missing |
| `.invalid_type_error(text)` | any | Override the error message when the input type does not match |
| `.message(text)` | any | **Phase 19**: Override the last rule's error message |
| `.intersect(other)` | any | **Phase 18**: Intersection — input must match both schemas |
| `.refine(check, msg)` | any | Custom validation predicate |
| `.transform(fn)` | any | **Phase 13**: Validate then transform output |

### Standalone Functions

| Function | Description |
|---|---|
| `schema_to_prompt(Schema)` | **Phase 16**: Generate TypeScript-interface prompt string for LLM — inline expansion |
| `schema_to_prompt_named(Schema, include_names?)` | **Phase 25, 34**: Generate modular TypeScript interfaces from named schemas |
| `to_json_schema(Schema)` | **Phase 15**: Export standard JSON Schema with full constraint annotations |
| `to_json_schema_skeleton(Schema)` | **Phase 15**: Export lightweight JSON Schema skeleton (structure only) |
| `to_json_schema_named(Schema, include_names?)` | **Phase 26, 34**: Export named schemas as `$defs` with `$ref` |
| `json_schema_to_moon_zod(Json)` | **Phase 27, 36**: Reverse-generate moon_zod code from JSON Schema |
| `json_schema_to_prompt(Json)` | **Phase 41**: Convert JSON Schema to TypeScript-interface prompt string |
| `schema_to_moonbit_struct(Schema)` | Generate MoonBit struct/enum definitions for every object/enum schema |
| `schema_to_moonbit_struct_full(Schema)` | Generate definitions plus static `Type::to_schema()` functions |
| `schema_to_moon_zod_code(Schema)` | Generate moon_zod schema source code |
| `schema_to_moon_zod_code_named(Schema, include_names?)` | Generate moon_zod code with `$defs` and `$ref` |
| `json_schema_to_schema(Json)` | Reverse-parse JSON Schema into a moon_zod Schema |
| `json_infer_schema(Json)` | Infer a moon_zod Schema from a sample JSON value |
| `append_rule(Schema, (Json) -> Bool, String)` | Append a raw validation rule |
| `append_rule_with_annotation(Schema, (Json) -> Bool, String, Json)` | Append a rule with annotation payload |
| `format_path(Array[String])` | Join path stack to dot-notation string |
| `ValidationError::to_string()` | Format error as `[path] message (got: value)` |

### Core Types

```moonbit nocheck
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
