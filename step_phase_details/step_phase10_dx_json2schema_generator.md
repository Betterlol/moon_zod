# Stage Summary

## 1. Stage Description

Phase 10: Developer Experience (DX) & Code Generation — Build a zero-dependency CLI utility that reads a raw JSON object and automatically generates the corresponding `@moon_zod.object({...})` source code. Demonstrate with an AI Chinese Teaching Platform payload.

## 2. Stage Metadata

- **STAGE_ID**: phase10
- **STAGE_TYPE**: dx-tooling
- **BASE_COMMIT**: `b5a2d1edd6a757a6d92bc2c695bbe2eaa46a6169`

## 3. New Files

| File | Description |
|---|---|
| `cmd/json2schema/moon.pkg` | Executable package declaration (is-main, imports moonbitlang/core/json) |
| `cmd/json2schema/main.mbt` | JSON-to-Schema generator: recursive AST traversal producing idiomatic `@moon_zod` source code |

## 4. New File Full Contents

### cmd/json2schema/moon.pkg

```
import {
  "moonbitlang/core/json",
}

options(
  "is-main": true,
)
```

### cmd/json2schema/main.mbt

```
///|
/// moon_zod Schema Generator — JSON to `@moon_zod` source code
///
/// A zero-dependency CLI utility that traverses a JSON AST and generates
/// the corresponding moon_zod schema expression. Designed for rapid
/// schema prototyping from real API payloads.
///
/// Run with: moon run cmd/json2schema
fn main {
  // ── Chinese teaching payload (realistic AI Agent scenario) ──────
  let mock_input = @json.parse(
    "{\"lesson_id\":101,\"hsk_level\":4,\"vocabulary\":[{\"hanzi\":\"你好\",\"pinyin\":\"nǐ hǎo\",\"translation\":\"hello\"},{\"hanzi\":\"老师\",\"pinyin\":\"lǎo shī\",\"translation\":\"teacher\"}],\"situational_dialogue\":{\"context\":\"At the airport\",\"speakers\":[{\"name\":\"Li Ming\",\"dialogue\":\"你好！请问机场怎么走？\"},{\"name\":\"Agent\",\"dialogue\":\"请跟我来。\"}]},\"is_published\":true}",
  ) catch {
    _ => abort("invalid mock JSON")
  }

  println(
    "╔══════════════════════════════════════════════════════════╗",
  )
  println("║   moon_zod Schema Generator — Chinese Teaching Demo     ║")
  println(
    "╚══════════════════════════════════════════════════════════╝",
  )
  println("")
  println("── Input JSON ──")
  println(mock_input)
  println("")
  println("── Generated moon_zod Schema (copy-paste ready) ──")
  println(infer_schema(mock_input, 0))
  println("")
  println("── End ──")
}

///|
/// Infer a moon_zod schema expression from a JSON value.
///
/// @param json   The JSON value to analyze.
/// @param indent Current nesting depth (each level = 2 spaces).
/// @returns      A `@moon_zod.*` expression string.
fn infer_schema(json : Json, indent : Int) -> String {
  match json {
    String(_) => "@moon_zod.string()"
    Number(_) => "@moon_zod.number()"
    True | False => "@moon_zod.boolean()"
    Null => "@moon_zod.null()"
    Array(elements) => infer_array_schema(elements, indent)
    Object(map) => infer_object_schema(map, indent)
  }
}

///|
/// Generate an `@moon_zod.object({...})` expression from a JSON object.
fn infer_object_schema(map : Map[String, Json], indent : Int) -> String {
  let mut result = "@moon_zod.object({\n"
  let mut first = true
  for key in map.keys() {
    if !first {
      result = result + ",\n"
    }
    first = false
    match map.get(key) {
      Some(val) => {
        let field_schema = infer_schema(val, indent + 1)
        result = result + pad(indent + 1) + "\"" + key + "\": " + field_schema
      }
      None => ()
    }
  }
  if first {
    // Empty map
    "@moon_zod.object({})"
  } else {
    result = result + ",\n" + pad(indent) + "})"
    result
  }
}

///|
/// Generate an `@moon_zod.array(...)` expression from a JSON array.
/// Inspects the first element to infer the element schema.
/// Empty arrays default to `@moon_zod.array(@moon_zod.string())`.
fn infer_array_schema(elements : Array[Json], indent : Int) -> String {
  let inner = if elements.length() > 0 {
    infer_schema(elements[0], indent + 1)
  } else {
    "@moon_zod.string()"
  }
  if has_newlines(inner) {
    "@moon_zod.array(\n" + pad(indent + 1) + inner + "\n" + pad(indent) + ")"
  } else {
    "@moon_zod.array(" + inner + ")"
  }
}

///|
/// Check if a string contains newline characters.
fn has_newlines(s : String) -> Bool {
  for c in s.to_array() {
    if c == '\n' {
      return true
    }
  }
  false
}

///|
/// Generate an indentation string for a given nesting level.
/// Each level produces 2 spaces.
fn pad(level : Int) -> String {
  let mut spaces = ""
  for i = 0; i < level * 2; i = i + 1 {
    spaces = spaces + " "
  }
  spaces
}
```

## 5. Modified Files

None.

## 6. Modified File Diffs

N/A — no modified files.

## 7. Deleted Files

None.

## 8. ACTION_LOG

| # | File | Action | Reason |
|---|---|---|---|
| 1 | `cmd/json2schema/moon.pkg` | CREATE | Executable package declaration for the JSON-to-Schema code generator; imports `moonbitlang/core/json` for `@json.parse`; is-main |
| 2 | `cmd/json2schema/main.mbt` | CREATE | Recursive schema inference engine: `infer_schema()` maps each JSON type to the equivalent `@moon_zod.*()` factory, `infer_object_schema()` formats object fields with proper indentation and trailing commas, `infer_array_schema()` inspects first element for array type inference (defaults to `@moon_zod.string()` for empty arrays), `has_newlines()` controls single-vs-multi-line array formatting, `pad()` produces 2-space-per-level indentation |

## 9. Verification

- `moon build`: 0 errors (1 pre-existing-style Show deprecation warning for `println(mock_input)`)
- `moon test`: **74/74 passed** ✅
- `moon fmt`: Clean ✅
- `moon run cmd/json2schema`: Generated output is beautifully formatted, syntactically valid MoonBit `@moon_zod` code
- Core engine unchanged: no modifications to `schema.mbt`, `parse` routing, or any Phase 1-9 source files

## 10. Risks / Notes

- **Zero core engine changes**: Only net-new `cmd/json2schema/` directory added. All existing code untouched.
- **Zero external dependencies**: Uses only `moonbitlang/core/json` (part of standard library).
- **Limitation — array element inference**: The generator inspects only the first array element; heterogeneous arrays will produce a schema matching only the first element's type. This matches the common use case of homogeneous JSON arrays.
- **Limitation — key escaping**: String keys with characters that need MoonBit string escaping (e.g., embedded `"` or `\`) are not specially handled. For typical API JSON keys this is fine.
- **Empty map handling**: `@moon_zod.object({})` is produced for empty JSON objects, which matches MoonBit Map literal syntax.
- **Single warning**: `println(mock_input)` triggers the same Show deprecation warning as all other examples in the project (using Debug trait instead). This is a project-wide pre-existing pattern.
