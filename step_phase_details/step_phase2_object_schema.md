# Stage Summary

## 1. Stage Description

Implement Phase 2 of `moon_zod`: `ObjectType` with field-level validation, strict/passthrough modes, nested object recursion with path splicing, plus 10 passing tests.

## 2. Stage Metadata

- **STAGE_ID**: phase2
- **STAGE_TYPE**: feature-implementation
- **BASE_COMMIT**: `6466b60b4a6b331868457fd2a9d96615bef386e8`

## 3. New Files

| File | Description |
|---|---|
| `object.mbt` | `object()` factory + `.strict()` / `.passthrough()` chainable methods |

## 4. New File Full Contents

### object.mbt

```
///|
/// Create a schema that validates JSON objects.
///
/// Each key in `spec` defines a required field and its schema.
/// By default, extra fields in the input JSON are allowed (passthrough).
/// Use `.strict()` to reject extra fields.
pub fn object(spec : Map[String, Schema]) -> Schema {
  { schema_type: ObjectType(spec, Passthrough), rules: [] }
}

///|
/// Reject fields not defined in the schema spec.
pub fn Schema::strict(self : Schema) -> Schema {
  match self.schema_type {
    ObjectType(spec, _) => { ..self, schema_type: ObjectType(spec, Strict) }
    _ => abort("strict() is only valid for object schemas")
  }
}

///|
/// Allow fields not defined in the schema spec. This is the default.
pub fn Schema::passthrough(self : Schema) -> Schema {
  match self.schema_type {
    ObjectType(spec, _) =>
      { ..self, schema_type: ObjectType(spec, Passthrough) }
    _ => abort("passthrough() is only valid for object schemas")
  }
}
```

(Content generated via `cat object.mbt`)

## 5. Modified Files

| File | Change |
|---|---|
| `schema.mbt` | Add `ObjectMode` enum, `ObjectType` variant, restructure `parse()` with object branch |
| `moon_zod_test.mbt` | Add 10 object validation tests (total now 38) |
| `moon.pkg` | Add `json` core dependency for `@json.parse` usage in tests |
| `pkg.generated.mbti` | Auto-generated interface update for new public API surface |

## 6. Modified File Diffs

### schema.mbt

```diff
diff --git a/schema.mbt b/schema.mbt
index 98a592d..41a0e6c 100644
--- a/schema.mbt
+++ b/schema.mbt
@@ -1,3 +1,10 @@
+///|
+/// Object validation mode.
+pub(all) enum ObjectMode {
+  Passthrough
+  Strict
+}
+
 ///|
 /// Internal tag for runtime type dispatch.
 pub(all) enum SchemaType {
@@ -5,6 +12,7 @@ pub(all) enum SchemaType {
   NumberType
   BooleanType
   NullType
+  ObjectType(Map[String, Schema], ObjectMode)
 }
 
 ///|
@@ -28,9 +36,29 @@ fn expected_msg(schema_type : SchemaType) -> String {
     NumberType => "Expected number"
     BooleanType => "Expected boolean"
     NullType => "Expected null"
+    ObjectType(_, _) => "Expected object"
   }
 }
 
+///|
+fn collect_errors(
+  errors : Array[ValidationError],
+  path : String,
+  json : Json,
+  rules : Array[Rule],
+) -> Array[ValidationError] {
+  let result : Array[ValidationError] = []
+  for rule in rules {
+    if !(rule.check)(json) {
+      result.push(ValidationError::{ path, message: rule.message, got: json })
+    }
+  }
+  for e in errors {
+    result.push(e)
+  }
+  result
+}
+
 ///|
 /// Validate `json` against this schema.
 pub fn Schema::parse(
@@ -38,31 +66,101 @@ pub fn Schema::parse(
   json : Json,
   path? : String = "",
 ) -> SchemaResult {
-  let valid = match (self.schema_type, json) {
-    (StringType, String(_)) => true
-    (NumberType, Number(_)) => true
-    (BooleanType, True | False) => true
-    (NullType, Null) => true
-    _ => false
-  }
-  if !valid {
-    return Err([
-      ValidationError::{
-        path,
-        message: expected_msg(self.schema_type),
-        got: json,
-      },
-    ])
-  }
-  let errors : Array[ValidationError] = []
-  for rule in self.rules {
-    if !(rule.check)(json) {
-      errors.push(ValidationError::{ path, message: rule.message, got: json })
+  match self.schema_type {
+    ObjectType(spec, mode) =>
+      match json {
+        Object(input_map) => {
+          let mut errors : Array[ValidationError] = []
+          let sub = fn(name : String) -> String {
+            if path.is_empty() { name } else { "\{path}.\{name}" }
+          }
+          for field_name in spec.keys() {
+            match spec.get(field_name) {
+              Some(field_schema) => {
+                let sub_path = sub(field_name)
+                match input_map.get(field_name) {
+                  None =>
+                    errors.push(ValidationError::{
+                      path: sub_path,
+                      message: "Required",
+                      got: Json::null(),
+                    })
+                  Some(field_json) => {
+                    let result = field_schema.parse(field_json, path=sub_path)
+                    match result {
+                      Err(field_errors) =>
+                        for e in field_errors { errors.push(e) }
+                      _ => ()
+                    }
+                  }
+                }
+              }
+              None => ()
+            }
+          }
+          match mode {
+            Strict =>
+              for key in input_map.keys() {
+                match input_map.get(key) {
+                  Some(value) =>
+                    if !spec.contains(key) {
+                      let field_path = sub(key)
+                      errors.push(ValidationError::{
+                        path: field_path,
+                        message: "Unexpected field",
+                        got: value,
+                      })
+                    }
+                  None => ()
+                }
+              }
+            _ => ()
+          }
+          errors = collect_errors(errors, path, json, self.rules)
+          if errors.is_empty() { Ok(json) } else { Err(errors) }
+        }
+        _ =>
+          Err([ValidationError::{
+            path,
+            message: expected_msg(self.schema_type),
+            got: json,
+          }])
+      }
+    _ => {
+      let valid = match (self.schema_type, json) {
+        (StringType, String(_)) => true
+        (NumberType, Number(_)) => true
+        (BooleanType, True | False) => true
+        (NullType, Null) => true
+        _ => false
+      }
+      if !valid {
+        return Err([ValidationError::{
+          path,
+          message: expected_msg(self.schema_type),
+          got: json,
+        }])
+      }
+      let errors = collect_errors([], path, json, self.rules)
+      if errors.is_empty() { Ok(json) } else { Err(errors) }
     }
   }
-  if errors.is_empty() {
-    Ok(json)
-  } else {
-    Err(errors)
-  }
 }
```

### moon_zod_test.mbt

```diff
diff --git a/moon_zod_test.mbt b/moon_zod_test.mbt
index 495938a..2e3c5a4 100644
--- a/moon_zod_test.mbt
+++ b/moon_zod_test.mbt
@@ -203,6 +203,120 @@ test "null rejects string" {
   guard s.parse(Json::string("null")) is Err(_) else { fail("expected Err") }
 }
 
+///|
+fn parse_json(input : String) -> Json {
+  @json.parse(input) catch { _ => abort("bad test json: " + input) }
+}
+
+///|
+/// object() — valid cases
+test "object validates flat object" {
+  let s = object({ "name": string(), "age": number().int() })
+  let input = parse_json("{\"name\": \"Alice\", \"age\": 30}")
+  match s.parse(input) {
+    Ok(v) => assert_eq(v, input)
+    Err(_) => fail("expected Ok")
+  }
+}
+
+///|
+test "object validates nested object" {
+  let s = object({ "user": object({ "profile": object({ "name": string() }) }) })
+  let input = parse_json("{\"user\": {\"profile\": {\"name\": \"Alice\"}}}")
+  match s.parse(input) {
+    Ok(v) => assert_eq(v, input)
+    Err(_) => fail("expected Ok")
+  }
+}
+
+///|
+test "object passthrough (default) allows extra fields" {
+  let s = object({ "name": string() })
+  let input = parse_json("{\"name\": \"Alice\", \"extra\": 1}")
+  match s.parse(input) {
+    Ok(v) => assert_eq(v, input)
+    Err(_) => fail("expected Ok")
+  }
+}
+
+///|
+/// object() — error cases
+test "object rejects non-object" {
+  let s = object({ "name": string() })
+  guard s.parse(Json::string("hello")) is Err(_) else { fail("expected Err") }
+}
+
+///|
+test "object reports missing field" {
+  let s = object({ "name": string() })
+  let input = parse_json("{}")
+  match s.parse(input) {
+    Err(errors) => {
+      assert_eq(errors.length(), 1)
+      assert_eq(errors[0].path, "name")
+      assert_eq(errors[0].message, "Required")
+    }
+    _ => fail("expected Err")
+  }
+}
+
+///|
+test "nested object reports correct error path" {
+  let s = object({ "user": object({ "profile": object({ "name": string().min(10) }) }) })
+  let input = parse_json("{\"user\": {\"profile\": {\"name\": \"Bob\"}}}")
+  match s.parse(input) {
+    Err(errors) => assert_eq(errors[0].path, "user.profile.name")
+    _ => fail("expected Err")
+  }
+}
+
+///|
+test "strict mode rejects extra fields" {
+  let s = object({ "name": string() }).strict()
+  let input = parse_json("{\"name\": \"Alice\", \"extra\": 1}")
+  guard s.parse(input) is Err(_) else { fail("expected Err") }
+}
+
+///|
+test "strict mode reports extra field path" {
+  let s = object({ "name": string() }).strict()
+  let input = parse_json("{\"name\": \"Alice\", \"extra\": 1}")
+  match s.parse(input) {
+    Err(errors) => {
+      assert_eq(errors[0].path, "extra")
+      assert_eq(errors[0].message, "Unexpected field")
+    }
+    _ => fail("expected Err")
+  }
+}
+
+///|
+test "object collects multiple field errors" {
+  let s = object({ "a": string().min(5), "b": number().positive() })
+  let input = parse_json("{\"a\": \"ab\", \"b\": -1}")
+  match s.parse(input) {
+    Err(errors) => assert_eq(errors.length(), 2)
+    _ => fail("expected Err")
+  }
+}
+
+///|
+test "strict mode with nested path" {
+  let s = object({ "inner": object({ "x": number() }).strict() })
+  let input = parse_json("{\"inner\": {\"x\": 1, \"y\": 2}}")
+  match s.parse(input) {
+    Err(errors) => {
+      assert_eq(errors[0].path, "inner.y")
+      assert_eq(errors[0].message, "Unexpected field")
+    }
+    _ => fail("expected Err")
+  }
+}
+
 ///|
 /// Error messages
 test "error message includes path and expected type" {
```

### moon.pkg

```diff
diff --git a/moon.pkg b/moon.pkg
index 8b13789..f9f1d1a 100644
--- a/moon.pkg
+++ b/moon.pkg
@@ -1 +1,3 @@
-
+import {
+  "moonbitlang/core/json",
+}
```

### pkg.generated.mbti

```diff
diff --git a/pkg.generated.mbti b/pkg.generated.mbti
index 7f687b5..e98749d 100644
--- a/pkg.generated.mbti
+++ b/pkg.generated.mbti
@@ -8,11 +8,18 @@ pub fn null() -> Schema
 
 pub fn number() -> Schema
 
+pub fn object(Map[String, Schema]) -> Schema
+
 pub fn string() -> Schema
 
 // Errors
 
 // Types and methods
+pub(all) enum ObjectMode {
+  Passthrough
+  Strict
+}
+
 pub(all) struct Rule {
   check : (Json) -> Bool
   message : String
@@ -30,8 +37,10 @@ pub fn Schema::multipleOf(Self, Int) -> Self
 pub fn Schema::negative(Self) -> Self
 pub fn Schema::nonempty(Self) -> Self
 pub fn Schema::parse(Self, Json, path? : String) -> Result[Json, Array[ValidationError]]
+pub fn Schema::passthrough(Self) -> Self
 pub fn Schema::positive(Self) -> Self
 pub fn Schema::regex(Self, String) -> Self
+pub fn Schema::strict(Self) -> Self
 pub fn Schema::url(Self) -> Self
 
 pub(all) enum SchemaType {
@@ -39,6 +48,7 @@ pub(all) enum SchemaType {
   NumberType
   BooleanType
   NullType
+  ObjectType(Map[String, Schema], ObjectMode)
 }
 
 pub struct ValidationError {
```

## 7. Deleted Files

None.

## 8. ACTION_LOG

| # | File | Action | Reason |
|---|---|---|---|
| 1 | `schema.mbt` | MODIFY | Add `ObjectMode` enum, `ObjectType(Map[String, Schema], ObjectMode)` variant, `collect_errors` helper, restructure `Schema::parse` with type-dispatch for object branch (field iteration, path splicing, strict mode check) |
| 2 | `object.mbt` | CREATE | `object(spec)` factory with default `Passthrough` mode, `.strict()` and `.passthrough()` chainable configuration methods |
| 3 | `moon_zod_test.mbt` | MODIFY | Add `parse_json` helper using `@json.parse(str)`, 10 blackbox tests covering flat/nested object validation, missing field, strict mode rejection, path correctness, multiple error collection |
| 4 | `moon.pkg` | MODIFY | Add `"moonbitlang/core/json"` import to resolve `@json.parse` usage in blackbox tests |
| 5 | `pkg.generated.mbti` | MODIFY | Auto-generated by `moon info` — exposes `object()`, `ObjectMode`, `Schema::strict`, `Schema::passthrough`, `ObjectType` in public interface |

## 9. Risks / Notes

- **`Json::Object(Map)` is read-only**: Tests construct JSON objects via `@json.parse(str)` instead of `Json::Object({...})`. This is a core library constraint; the `Object` variant factory is not publicly constructable.
- **`Map` API**: MoonBit's `Map[K, V]` uses `.get(key)` (returns `V?` i.e. `Option[V]`) instead of `.lookup(key)`. `.contains(key)` and `.keys()` return `Iter[K]`.
- **No struct field expansion**: `ObjectMode` is stored inside `ObjectType(Map[String, Schema], ObjectMode)` variant rather than as a `Schema` struct field, eliminating the need to modify Phase 1 factory functions.
- **Phase 2 scope complete**: 38/38 tests pass (28 from Phase 1 + 10 new). Ready for Phase 3 (array, optional, default, union, refine).
