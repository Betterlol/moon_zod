### JSON-to-Schema Generator (CLI)

Generate `@moon_zod` schema code instantly from any JSON payload — no need to write schemas by hand for real-world API data.

```bash
moon run cmd/json2schema -- '{"hello": "world"}'
```

Output:

```
── Input JSON ──
Object({hello: String(world)})

── Generated moon_zod Schema (copy-paste ready) ──
@moon_zod.object({
  "hello": @moon_zod.string(),
})

── End ──
```

The generator recursively infers types (`string`, `number`, `boolean`, `null`, `array`, `object`) and safely escapes special characters in object keys. Empty arrays produce a `/* TODO: specify exact type */` comment to alert you when type inference lacked data.

---

### MoonBit Struct Generator (CLI)

Generate MoonBit struct definitions from any JSON sample — struct definitions + `from_json()` functions for type-safe conversion.

```bash
moon run cmd/gen-struct -- '{"name":"Alice","age":30}'
```

Output:

```moonbit
pub struct InferredSchema {
  name : String
  age : Int64
}

pub fn inferred_schema_from_json(json : Json) -> Result[InferredSchema, Array[ValidationError]] {
  match json {
    Object(map) => {
      let name = match map.get("name") {
        Some(String(s)) => s
        Some(got) => return Err([ValidationError::{ path: "name", message: "expected string", got }])
        None => return Err([ValidationError::{ path: "name", message: "required", got: Null }])
      }
      let age = match map.get("age") {
        Some(Number(v, ..)) => v.to_int()
        Some(got) => return Err([ValidationError::{ path: "age", message: "expected integer", got }])
        None => return Err([ValidationError::{ path: "age", message: "required", got: Null }])
      }
      Ok({ name:, age: })
    }
    _ => Err([ValidationError::{ path: "", message: "expected object", got: json }])
  }
}
```

Supports nested objects, arrays, optional fields, and named schema exports via `--named` flag.

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
```

**Error output format**: `[field_path] message (got: value)`

---