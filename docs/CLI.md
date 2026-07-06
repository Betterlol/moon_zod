### JSON-to-Schema Generator (CLI)

Generate `@moon_zod` schema code instantly from any JSON payload — no need to write schemas by hand for real-world API data.

```bash
moon run cmd/json2schema -- '{"hello": "world"}'
```

Output (copy-paste ready moon_zod code):

```moonbit
@moon_zod.object({
  "hello": @moon_zod.string(),
})
```

For verbose output with debug information:
```bash
moon run cmd/json2schema -- --verbose '{"hello": "world"}'
```

The generator recursively infers types (`string`, `number`, `boolean`, `null`, `array`, `object`) and safely escapes special characters in object keys. Empty arrays produce a `/* TODO: specify exact type */` comment to alert you when type inference lacked data.

---

### JSON Schema Reverse Importer (CLI)

Generate `@moon_zod` schema code from a standard **JSON Schema (draft-07)** definition — the inverse of `to_json_schema()`.

**Inline mode** (JSON Schema as command argument):
```bash
moon run cmd/json2schema -- --from-json-schema '{
  "type": "object",
  "properties": {
    "name": {"type": "string", "minLength": 2},
    "age": {"type": "integer", "minimum": 0, "maximum": 150}
  },
  "required": ["name", "age"]
}'
```

**File mode** (read JSON Schema from file):
```bash
moon run cmd/json2schema -- --from-json-schema --schema-file schema.json
```

Output:

```moonbit
@moon_zod.object({
  "name": @moon_zod.string().min(2),
  "age": @moon_zod.number().int().min(0).max(150),
})
```

**Features**:
- Converts all JSON Schema types (string, number, integer, boolean, null, array, object)
- Extracts constraints: `minLength`, `maxLength`, `minimum`, `maximum`, `exclusiveMinimum`, `exclusiveMaximum`, `multipleOf`, `pattern`, `format` (email, uri, date-time, ipv4, ipv6, uuid)
- Handles `$defs` and `$ref` references — generates separate named schema declarations
- Supports `enum`, `oneOf`, `anyOf`, `allOf`
- Fields not in `required` auto-wrapped with `.optional()`
- Outputs **copy-paste-ready MoonBit source code**
- Full support for Phase 36 semantics: `exclusiveMinimum`/`exclusiveMaximum` generate `.positive()`/`.negative()` where applicable

---

### MoonBit Struct Generator (CLI)

Generate MoonBit struct definitions from any JSON Schema — struct definitions + static `Type::to_schema()` functions.

```bash
moon run cmd/gen-struct -- --schema '{"type":"object","properties":{"name":{"type":"string"},"age":{"type":"integer"}},"required":["name","age"]}'
```

Output:

```moonbit
pub struct Root {
  name : String
  age : Int64  // int
} derive(ToJson, FromJson)

pub fn Root::to_schema() -> @moon_zod.Schema {
  let root = @moon_zod.object({
    "name": @moon_zod.string(),
    "age": @moon_zod.number().int(),
  }).name("Root")
  root
}
```

Supports nested objects, arrays, and optional fields. Nested objects are automatically named and exported as separate struct definitions.

---

### JSON Validator (CLI)

Validate JSON data against a schema inferred from a sample — no code required. Supports JSON Lines for batch validation.

```bash
# Single JSON validation
moon run cmd/validate -- '{"name":"Alice","age":30}' '{"name":"Bob","age":25}'
# PASS

# Batch validation with JSON Lines
moon run cmd/validate -- '{"name":"Alice"}' '{"name":"Bob"}\n{"name":"Eve"}\n{"age":30}'
# FAIL: line 3
#   [name] Required (got: Null)
# Results: 2 passed, 1 failed

# File mode (JSON Schema as schema source)
moon run cmd/validate -- --schema-file schema.json --sample-file data.json
```

**Error output format**: `[field_path] message (got: value)`

---