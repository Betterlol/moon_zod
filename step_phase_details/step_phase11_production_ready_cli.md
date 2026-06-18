# Stage Summary

## 1. Stage Description

Phase 11: Production-Ready CLI & Safe Code Generation — Upgrade `cmd/json2schema` from hardcoded mock to a true CLI utility that reads JSON via CLI arguments, safely escapes complex string keys, and provides graceful error handling. Adapted from file I/O to inline JSON argument due to MoonBit WASM constraints (no `@fs` module).

## 2. Stage Metadata

- **STAGE_ID**: phase11
- **STAGE_TYPE**: dx-tooling
- **BASE_COMMIT**: `545fbd5`

## 3. New Files

None.

## 4. New File Full Contents

N/A — no new files.

## 5. Modified Files

| File | Description |
|---|---|
| `cmd/json2schema/main.mbt` | CLI argument parsing via `@env.args()`, `escape_mbt_string()` for safe key escaping, `/* TODO: specify exact type */` for empty arrays, graceful `@json.parse()` error handling, removed hardcoded Chinese teaching mock |
| `cmd/json2schema/moon.pkg` | Added `"moonbitlang/core/env"` import |

## 6. Modified File Diffs

### cmd/json2schema/main.mbt

```
diff --git a/cmd/json2schema/main.mbt b/cmd/json2schema/main.mbt
index f39fedb..7e6cfaf 100644
--- a/cmd/json2schema/main.mbt
+++ b/cmd/json2schema/main.mbt
@@ -1,42 +1,48 @@
 ///|
 /// moon_zod Schema Generator — JSON to `@moon_zod` source code
 ///
-/// A zero-dependency CLI utility that traverses a JSON AST and generates
-/// the corresponding moon_zod schema expression. Designed for rapid
-/// schema prototyping from real API payloads.
+/// A zero-dependency CLI utility that accepts a JSON string via CLI
+/// argument and generates the corresponding moon_zod schema expression.
 ///
-/// Run with: moon run cmd/json2schema
+/// Since MoonBit targets WASM without filesystem I/O, pass the JSON
+/// directly as a string argument.
+///
+/// Usage: moon run cmd/json2schema -- '<json-string>'
+///        moon run cmd/json2schema -- --help
 fn main {
-  // ── Chinese teaching payload (realistic AI Agent scenario) ──────
-  let mock_input = @json.parse(
-    "{\"lesson_id\":101,\"hsk_level\":4,\"vocabulary\":[{\"hanzi\":\"你好\",\"pinyin\":\"nǐ hǎo\",\"translation\":\"hello\"},{\"hanzi\":\"老师\",\"pinyin\":\"lǎo shī\",\"translation\":\"teacher\"}],\"situational_dialogue\":{\"context\":\"At the airport\",\"speakers\":[{\"name\":\"Li Ming\",\"dialogue\":\"你好！请问机场怎么走？\"},{\"name\":\"Agent\",\"dialogue\":\"请跟我来。\"}]},\"is_published\":true}",
-  ) catch {
-    _ => abort("invalid mock JSON")
+  let args = @env.args()
+  if args.length() < 2 || args[1] == "--help" {
+    println("Usage: moon run cmd/json2schema -- '<json-string>'")
+    println("")
+    println("Generate a moon_zod schema from a JSON payload.")
+    println("")
+    println("Examples:")
+    println("  moon run cmd/json2schema -- '{\"name\": \"Alice\"}'")
+    println("  moon run cmd/json2schema -- --help")
+    return
+  }
+
+  let raw = args[1]
+  let json = @json.parse(raw) catch {
+    _ => {
+      println("Error: invalid JSON string")
+      println("Please provide valid JSON as the first argument.")
+      println("Use --help for usage information.")
+      return
+    }
   }
 
-  println(
-    "╔══════════════════════════════════════════════════════════╗",
-  )
-  println("║   moon_zod Schema Generator — Chinese Teaching Demo     ║")
-  println(
-    "╚══════════════════════════════════════════════════════════╝",
-  )
-  println("")
   println("── Input JSON ──")
-  println(mock_input)
+  println(json)
   println("")
   println("── Generated moon_zod Schema (copy-paste ready) ──")
-  println(infer_schema(mock_input, 0))
+  println(infer_schema(json, 0))
   println("")
   println("── End ──")
 }
 
 ///|
 /// Infer a moon_zod schema expression from a JSON value.
-///
-/// @param json   The JSON value to analyze.
-/// @param indent Current nesting depth (each level = 2 spaces).
-/// @returns      A `@moon_zod.*` expression string.
 fn infer_schema(json : Json, indent : Int) -> String {
   match json {
     String(_) => "@moon_zod.string()"
@@ -50,6 +56,8 @@ fn infer_schema(json : Json, indent : Int) -> String {
 
 ///|
 /// Generate an `@moon_zod.object({...})` expression from a JSON object.
+/// Object keys are safely escaped via `escape_mbt_string` to ensure the
+/// generated MoonBit string literal does not break on `"` or `\`.
 fn infer_object_schema(map : Map[String, Json], indent : Int) -> String {
   let mut result = "@moon_zod.object({\n"
   let mut first = true
@@ -61,13 +69,17 @@ fn infer_object_schema(map : Map[String, Json], indent : Int) -> String {
     match map.get(key) {
       Some(val) => {
         let field_schema = infer_schema(val, indent + 1)
-        result = result + pad(indent + 1) + "\"" + key + "\": " + field_schema
+        result = result +
+          pad(indent + 1) +
+          "\"" +
+          escape_mbt_string(key) +
+          "\": " +
+          field_schema
       }
       None => ()
     }
   }
   if first {
-    // Empty map
     "@moon_zod.object({})"
   } else {
     result = result + ",\n" + pad(indent) + "})"
@@ -78,12 +90,12 @@ fn infer_object_schema(map : Map[String, Json], indent : Int) -> String {
 ///|
 /// Generate an `@moon_zod.array(...)` expression from a JSON array.
 /// Inspects the first element to infer the element schema.
-/// Empty arrays default to `@moon_zod.array(@moon_zod.string())`.
+/// Empty arrays generate a TODO comment to alert the developer.
 fn infer_array_schema(elements : Array[Json], indent : Int) -> String {
   let inner = if elements.length() > 0 {
     infer_schema(elements[0], indent + 1)
   } else {
-    "@moon_zod.string()"
+    "@moon_zod.string() /* TODO: specify exact type */"
   }
   if has_newlines(inner) {
     "@moon_zod.array(\n" + pad(indent + 1) + inner + "\n" + pad(indent) + ")"
@@ -92,6 +104,23 @@ fn infer_array_schema(elements : Array[Json], indent : Int) -> String {
   }
 }
 
+///|
+/// Escape special characters in a string so it can be safely used as a
+/// MoonBit string literal. Escapes `"` → `\"` and `\` → `\\`.
+fn escape_mbt_string(s : String) -> String {
+  let mut result = ""
+  for c in s.to_array() {
+    if c == '\\' {
+      result = result + "\\\\"
+    } else if c == '"' {
+      result = result + "\\\""
+    } else {
+      result = result + c.to_string()
+    }
+  }
+  result
+}
+
 ///|
 /// Check if a string contains newline characters.
 fn has_newlines(s : String) -> Bool {
```

### cmd/json2schema/moon.pkg

```
diff --git a/cmd/json2schema/moon.pkg b/cmd/json2schema/moon.pkg
index 1f7c57d..8cb431d 100644
--- a/cmd/json2schema/moon.pkg
+++ b/cmd/json2schema/moon.pkg
@@ -1,5 +1,6 @@
 import {
   "moonbitlang/core/json",
+  "moonbitlang/core/env",
 }
 
 options(
```

## 7. Deleted Files

None.

## 8. ACTION_LOG

| # | File | Action | Reason |
|---|---|---|---|
| 1 | `cmd/json2schema/moon.pkg` | MODIFY | Add `"moonbitlang/core/env"` import for `@env.args()` CLI argument reading |
| 2 | `cmd/json2schema/main.mbt` | MODIFY | Replace hardcoded Chinese teaching mock with CLI argument parsing via `@env.args()`, add `escape_mbt_string()` for safe key escaping (handles `"` and `\` in JSON keys), add `/* TODO: specify exact type */` comment for empty array fallback, add graceful `@json.parse()` error handling (invalid JSON + missing args), update doc comment |

## 9. Verification

- `moon build`: 0 errors (1 pre-existing Show deprecation warning for `println(json)`)
- `moon test`: **74/74 passed** ✅
- `moon fmt`: Clean ✅
- Hand-tested with tricky keys: `{"user-name": "Alice", "path\\dir": "C:\\", "say\"hello\"": true, "empty_list": []}`
  - `"user-name"` → normal quoting ✓
  - `"path\\dir"` → `\\` properly escaped ✓
  - `"say\"hello\""` → `\"` properly escaped ✓
  - `"empty_list"` → `@moon_zod.array(@moon_zod.string() /* TODO: specify exact type */)` ✓
- Error handling tested: no args → usage guide, `--help` → usage guide, invalid JSON → clear error message
- Core engine unchanged: no modifications to `schema.mbt`, `parse` routing, or any Phase 1-9 source files

## 10. Risks / Notes

- **Zero core engine changes**: Only `cmd/json2schema/` modified. All existing code untouched.
- **WASM file I/O limitation**: MoonBit targets WASM without filesystem I/O — no `@fs` module exists. Adapted from file-reading to inline JSON CLI argument. This is a design constraint of the platform, not a limitation of this tool.
- **Single pre-existing warning**: `println(json)` triggers the same Show deprecation warning as all other examples in the project. This is project-wide.
- **Key escaping**: `escape_mbt_string()` correctly escapes `"` → `\"` and `\` → `\\` by iterating over `Array[Char]` and using `Char::to_string()` for non-special characters.
- **Array element inference**: Only inspects the first element (homogeneous arrays). Empty arrays get a `/* TODO: specify exact type */` comment.
