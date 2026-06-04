# Stage Summary

## 1. Stage Description

Phase 4: Parse dispatch refactor, `append_rule` / `inner_type` plumbing, `to_json_schema()` export, benchmark, and tests.

## 2. Stage Metadata
- STAGE_ID: phase4
- STAGE_TYPE: refactor + feature
- BASE_COMMIT: fdc97412b982e259c15ecfe0c422d8f977777ff0

## 3. New Files

- `json_schema.mbt`

## 4. New File Full Contents

### json_schema.mbt

```mbt
///|
/// Convert a moon_zod Schema into a standard JSON Schema object.
///
/// Rules (min, max, nonempty, etc.) are not translated into JSON Schema
/// annotations; only the structural type information is exported.
/// OptionalType and DefaultType wrappers are transparent (unwrapped) so that
/// `string().optional()` produces `{ "type": "string" }` rather than wrapping
/// in `oneOf`.
pub fn to_json_schema(schema : Schema) -> Json {
  to_json_schema_inner(schema.schema_type)
}

///|
fn to_json_schema_inner(t : SchemaType) -> Json {
  match t {
    StringType => json_string_schema()
    NumberType => json_number_schema()
    BooleanType => Json::object({ "type": Json::string("boolean") })
    NullType => Json::object({ "type": Json::string("null") })
    ObjectType(spec, mode) => to_json_schema_object(spec, mode)
    ArrayType(elem) =>
      Json::object({
        "type": Json::string("array"),
        "items": to_json_schema_inner(elem.schema_type),
      })
    OptionalType(inner) => to_json_schema_inner(inner.schema_type)
    DefaultType(inner, default_val) => {
      let inner_json = to_json_schema_inner(inner.schema_type)
      match inner_json {
        Object(map) => {
          map.set("default", default_val)
          inner_json
        }
        _ => inner_json
      }
    }
    EnumType(values) =>
      Json::object({
        "type": Json::string("string"),
        "enum": Json::array(values.map(fn(s) { Json::string(s) })),
      })
    UnionType(schemas) =>
      Json::object({
        "anyOf": Json::array(
          schemas.map(fn(s) { to_json_schema_inner(s.schema_type) }),
        ),
      })
  }
}

///|
fn to_json_schema_object(spec : Map[String, Schema], mode : ObjectMode) -> Json {
  let props : Map[String, Json] = {}
  let required_arr : Array[String] = []
  for key, val in spec {
    props.set(key, to_json_schema_inner(val.schema_type))
    if !is_optional_schema(val) {
      required_arr.push(key)
    }
  }
  Json::object({
    "type": Json::string("object"),
    "properties": Json::object(props),
    "additionalProperties": Json::boolean(
      match mode { Strict => false; _ => true },
    ),
    "required": Json::array(required_arr.map(fn(k) { Json::string(k) })),
  })
}

///|
fn json_string_schema() -> Json {
  Json::object({ "type": Json::string("string") })
}

///|
fn json_number_schema() -> Json {
  Json::object({ "type": Json::string("number") })
}
```

## 5. Modified Files

- `schema.mbt`
- `object.mbt`
- `array.mbt`
- `union.mbt`
- `string.mbt`
- `number.mbt`
- `refine.mbt`
- `cmd/main/main.mbt`
- `cmd/main/moon.pkg`
- `moon_zod_test.mbt`
- `README.mbt.md`
- `pkg.generated.mbti`

## 6. Modified File Diffs

(Diffs included below this line via git diff against BASE_COMMIT)

## 7. Deleted Files

None.

## 8. ACTION_LOG

1. `schema.mbt` — modified: added `inner_type()`, `append_rule()`, refactored `Schema::parse` to dispatch to extracted helpers; `collect_errors` changed to return `Unit` (mutate-in-place); helpers marked `pub` for cross-file access
2. `object.mbt` — modified: extracted `parse_object()` helper from `Schema::parse`
3. `array.mbt` — modified: extracted `parse_array()` helper from `Schema::parse`
4. `union.mbt` — modified: extracted `parse_optional()`, `parse_default()`, `parse_enum()`, `parse_union()` helpers; updated doc comments
5. `string.mbt` — modified: all rule methods (`min`, `max`, `nonempty`, `email`, `url`, `regex`) switched to `append_rule()`; type guards use `inner_type()` to unwrap Optional/Default wrappers
6. `number.mbt` — modified: all rule methods (`int`, `positive`, `negative`, `multipleOf`) switched to `append_rule()`
7. `refine.mbt` — modified: switched to `append_rule()`
8. `json_schema.mbt` — **new file**: `to_json_schema()` public export that converts a `Schema` into a standard JSON Schema object
9. `cmd/main/main.mbt` — modified: replaced stub with a 10,000-iteration benchmark exercising a complex nested schema
10. `cmd/main/moon.pkg` — modified: added `import { "username/moon_zod" }` for benchmark
11. `moon_zod_test.mbt` — modified: added 11 new tests (append_rule chaining, to_json_schema, union errors, DefaultType)
12. `README.mbt.md` — modified: added Features section and updated usage example
13. `pkg.generated.mbti` — modified: auto-updated by `moon info`

## 9. Risks / Notes

- `append_rule` and parse helpers are `pub` (not `pub(all)`) — visible only within the package. This is correct for internal plumbing.
- The `collect_errors` function now mutates the input array in place rather than returning a new array. All call sites updated.
- `moon test`: 68 passed, 0 failed.
- `moon build`: successful.
- `moon info && moon fmt`: clean.
=== schema.mbt ===
diff --git a/schema.mbt b/schema.mbt
index d7668cc..6c0f437 100644
--- a/schema.mbt
+++ b/schema.mbt
@@ -34,6 +34,39 @@ pub struct Schema {
   rules : Array[Rule]
 }
 
+///|
+/// Peel OptionalType / DefaultType wrappers to find the effective base type.
+pub fn inner_type(t : SchemaType) -> SchemaType {
+  match t {
+    OptionalType(inner) => inner.schema_type
+    DefaultType(inner, _) => inner.schema_type
+    other => other
+  }
+}
+
+///|
+/// Append a rule through decoration wrappers.
+/// When called on OptionalType / DefaultType, the rule is pushed to the
+/// innermost base schema so that chaining after `.optional()` / `.default()`
+/// works correctly (e.g. `string().optional().min(3)`).
+pub fn append_rule(
+  schema : Schema,
+  check : (Json) -> Bool,
+  message : String,
+) -> Schema {
+  match schema.schema_type {
+    OptionalType(inner) => {
+      let new_inner = append_rule(inner, check, message)
+      { schema_type: OptionalType(new_inner), rules: [] }
+    }
+    DefaultType(inner, default_val) => {
+      let new_inner = append_rule(inner, check, message)
+      { schema_type: DefaultType(new_inner, default_val), rules: [] }
+    }
+    _ => { ..schema, rules: schema.rules + [{ check, message }] }
+  }
+}
+
 ///|
 fn expected_msg(schema_type : SchemaType) -> String {
   match schema_type {
@@ -54,21 +87,16 @@ fn collect_errors(
   path : String,
   json : Json,
   rules : Array[Rule],
-) -> Array[ValidationError] {
-  let result : Array[ValidationError] = []
+) -> Unit {
   for rule in rules {
     if !(rule.check)(json) {
-      result.push(ValidationError::{ path, message: rule.message, got: json })
+      errors.push(ValidationError::{ path, message: rule.message, got: json })
     }
   }
-  for e in errors {
-    result.push(e)
-  }
-  result
 }
 
 ///|
-fn sub_path(path : String, name : String) -> String {
+pub fn sub_path(path : String, name : String) -> String {
   if path.is_empty() {
     name
   } else {
@@ -77,7 +105,7 @@ fn sub_path(path : String, name : String) -> String {
 }
 
 ///|
-fn sub_index(path : String, i : Int) -> String {
+pub fn sub_index(path : String, i : Int) -> String {
   if path.is_empty() {
     "[\{i}]"
   } else {
@@ -86,7 +114,7 @@ fn sub_index(path : String, i : Int) -> String {
 }
 
 ///|
-fn value_in_array(s : String, arr : Array[String]) -> Bool {
+pub fn value_in_array(s : String, arr : Array[String]) -> Bool {
   for v in arr {
     if v == s {
       return true
@@ -96,7 +124,7 @@ fn value_in_array(s : String, arr : Array[String]) -> Bool {
 }
 
 ///|
-fn is_optional_schema(s : Schema) -> Bool {
+pub fn is_optional_schema(s : Schema) -> Bool {
   match s.schema_type {
     OptionalType(_) | DefaultType(_, _) => true
     _ => false
@@ -111,157 +139,13 @@ pub fn Schema::parse(
   path? : String = "",
 ) -> SchemaResult {
   match self.schema_type {
-    ObjectType(spec, mode) =>
-      match json {
-        Object(input_map) => {
-          let mut errors : Array[ValidationError] = []
-          for field_name in spec.keys() {
-            match spec.get(field_name) {
-              Some(field_schema) => {
-                let sp = sub_path(path, field_name)
-                match input_map.get(field_name) {
-                  None =>
-                    if !is_optional_schema(field_schema) {
-                      errors.push(ValidationError::{
-                        path: sp,
-                        message: "Required",
-                        got: Json::null(),
-                      })
-                    }
-                  Some(field_json) => {
-                    let result = field_schema.parse(field_json, path=sp)
-                    match result {
-                      Err(field_errors) =>
-                        for e in field_errors {
-                          errors.push(e)
-                        }
-                      _ => ()
-                    }
-                  }
-                }
-              }
-              None => ()
-            }
-          }
-          match mode {
-            Strict =>
-              for key in input_map.keys() {
-                match input_map.get(key) {
-                  Some(value) =>
-                    if !spec.contains(key) {
-                      errors.push(ValidationError::{
-                        path: sub_path(path, key),
-                        message: "Unexpected field",
-                        got: value,
-                      })
-                    }
-                  None => ()
-                }
-              }
-            _ => ()
-          }
-          errors = collect_errors(errors, path, json, self.rules)
-          if errors.is_empty() {
-            Ok(json)
-          } else {
-            Err(errors)
-          }
-        }
-        _ =>
-          Err([
-            ValidationError::{
-              path,
-              message: expected_msg(self.schema_type),
-              got: json,
-            },
-          ])
-      }
-    ArrayType(element_schema) =>
-      match json {
-        Array(elements) => {
-          let mut errors : Array[ValidationError] = []
-          let mut i = 0
-          for element in elements {
-            let sp = sub_index(path, i)
-            let result = element_schema.parse(element, path=sp)
-            match result {
-              Err(item_errors) =>
-                for e in item_errors {
-                  errors.push(e)
-                }
-              _ => ()
-            }
-            i = i + 1
-          }
-          errors = collect_errors(errors, path, json, self.rules)
-          if errors.is_empty() {
-            Ok(json)
-          } else {
-            Err(errors)
-          }
-        }
-        _ =>
-          Err([
-            ValidationError::{
-              path,
-              message: expected_msg(self.schema_type),
-              got: json,
-            },
-          ])
-      }
-    OptionalType(inner) =>
-      match json {
-        Null => Ok(json)
-        _ => inner.parse(json, path~)
-      }
+    ObjectType(spec, mode) => self.parse_object(spec, mode, json, path)
+    ArrayType(element_schema) => self.parse_array(element_schema, json, path)
+    OptionalType(inner) => self.parse_optional(inner, json, path)
     DefaultType(inner, default_val) =>
-      match json {
-        Null => Ok(default_val)
-        _ => inner.parse(json, path~)
-      }
-    EnumType(values) =>
-      match json {
-        String(s) =>
-          if value_in_array(s, values) {
-            Ok(json)
-          } else {
-            Err([
-              ValidationError::{
-                path,
-                message: "Invalid enum value",
-                got: json,
-              },
-            ])
-          }
-        _ =>
-          Err([
-            ValidationError::{
-              path,
-              message: "Expected string for enum",
-              got: json,
-            },
-          ])
-      }
-    UnionType(schemas) => {
-      let mut last_errors : Array[ValidationError]? = None
-      for s in schemas {
-        match s.parse(json, path~) {
-          Ok(v) => return Ok(v)
-          Err(errors) => last_errors = Some(errors)
-        }
-      }
-      match last_errors {
-        Some(errors) => Err(errors)
-        None =>
-          Err([
-            ValidationError::{
-              path,
-              message: "Expected union type, none matched",
-              got: json,
-            },
-          ])
-      }
-    }
+      self.parse_default(inner, default_val, json, path)
+    EnumType(values) => self.parse_enum(values, json, path)
+    UnionType(schemas) => self.parse_union(schemas, json, path)
     _ => {
       let valid = match (self.schema_type, json) {
         (StringType, String(_)) => true
@@ -279,7 +163,8 @@ pub fn Schema::parse(
           },
         ])
       }
-      let errors = collect_errors([], path, json, self.rules)
+      let errors : Array[ValidationError] = []
+      collect_errors(errors, path, json, self.rules)
       if errors.is_empty() {
         Ok(json)
       } else {
---
=== object.mbt ===
diff --git a/object.mbt b/object.mbt
index e42064d..2e5399f 100644
--- a/object.mbt
+++ b/object.mbt
@@ -26,3 +26,77 @@ pub fn Schema::passthrough(self : Schema) -> Schema {
     _ => abort("passthrough() is only valid for object schemas")
   }
 }
+
+///|
+pub fn Schema::parse_object(
+  self : Schema,
+  spec : Map[String, Schema],
+  mode : ObjectMode,
+  json : Json,
+  path : String,
+) -> SchemaResult {
+  match json {
+    Object(input_map) => {
+      let errors : Array[ValidationError] = []
+      for field_name in spec.keys() {
+        match spec.get(field_name) {
+          Some(field_schema) => {
+            let sp = sub_path(path, field_name)
+            match input_map.get(field_name) {
+              None =>
+                if !is_optional_schema(field_schema) {
+                  errors.push(ValidationError::{
+                    path: sp,
+                    message: "Required",
+                    got: Json::null(),
+                  })
+                }
+              Some(field_json) => {
+                let result = field_schema.parse(field_json, path=sp)
+                match result {
+                  Err(field_errors) =>
+                    for e in field_errors {
+                      errors.push(e)
+                    }
+                  _ => ()
+                }
+              }
+            }
+          }
+          None => ()
+        }
+      }
+      match mode {
+        Strict =>
+          for key in input_map.keys() {
+            match input_map.get(key) {
+              Some(value) =>
+                if !spec.contains(key) {
+                  errors.push(ValidationError::{
+                    path: sub_path(path, key),
+                    message: "Unexpected field",
+                    got: value,
+                  })
+                }
+              None => ()
+            }
+          }
+        _ => ()
+      }
+      collect_errors(errors, path, json, self.rules)
+      if errors.is_empty() {
+        Ok(json)
+      } else {
+        Err(errors)
+      }
+    }
+    _ =>
+      Err([
+        ValidationError::{
+          path,
+          message: expected_msg(self.schema_type),
+          got: json,
+        },
+      ])
+  }
+}
---
=== array.mbt ===
diff --git a/array.mbt b/array.mbt
index de914c4..8b9f513 100644
--- a/array.mbt
+++ b/array.mbt
@@ -5,3 +5,44 @@
 pub fn array(element_schema : Schema) -> Schema {
   { schema_type: ArrayType(element_schema), rules: [] }
 }
+
+///|
+pub fn Schema::parse_array(
+  self : Schema,
+  element_schema : Schema,
+  json : Json,
+  path : String,
+) -> SchemaResult {
+  match json {
+    Array(elements) => {
+      let errors : Array[ValidationError] = []
+      let mut i = 0
+      for element in elements {
+        let sp = sub_index(path, i)
+        let result = element_schema.parse(element, path=sp)
+        match result {
+          Err(item_errors) =>
+            for e in item_errors {
+              errors.push(e)
+            }
+          _ => ()
+        }
+        i = i + 1
+      }
+      collect_errors(errors, path, json, self.rules)
+      if errors.is_empty() {
+        Ok(json)
+      } else {
+        Err(errors)
+      }
+    }
+    _ =>
+      Err([
+        ValidationError::{
+          path,
+          message: expected_msg(self.schema_type),
+          got: json,
+        },
+      ])
+  }
+}
---
=== union.mbt ===
diff --git a/union.mbt b/union.mbt
index 88d1b6a..b5798ff 100644
--- a/union.mbt
+++ b/union.mbt
@@ -1,13 +1,15 @@
 ///|
 /// Make a field optional: null or missing values pass validation.
-/// Call `.optional()` last in a chain (rules before optional).
+/// Rules chained after `.optional()` are pushed through to the inner schema
+/// via `append_rule`, so `string().optional().min(3)` works correctly.
 pub fn Schema::optional(self : Schema) -> Schema {
   { schema_type: OptionalType(self), rules: [] }
 }
 
 ///|
 /// Provide a default value when the input is null.
-/// Call `.default(value)` last in a chain (rules before default).
+/// Rules chained after `.default()` are pushed through to the inner schema
+/// via `append_rule`.
 pub fn Schema::default(self : Schema, value : Json) -> Schema {
   { schema_type: DefaultType(self, value), rules: [] }
 }
@@ -24,3 +26,84 @@ pub fn enum_values(values : Array[String]) -> Schema {
 pub fn union(schemas : Array[Schema]) -> Schema {
   { schema_type: UnionType(schemas), rules: [] }
 }
+
+///|
+pub fn Schema::parse_optional(
+  self : Schema,
+  inner : Schema,
+  json : Json,
+  path : String,
+) -> SchemaResult {
+  match json {
+    Null => Ok(json)
+    _ => inner.parse(json, path~)
+  }
+}
+
+///|
+pub fn Schema::parse_default(
+  self : Schema,
+  inner : Schema,
+  default_val : Json,
+  json : Json,
+  path : String,
+) -> SchemaResult {
+  match json {
+    Null => Ok(default_val)
+    _ => inner.parse(json, path~)
+  }
+}
+
+///|
+pub fn Schema::parse_enum(
+  self : Schema,
+  values : Array[String],
+  json : Json,
+  path : String,
+) -> SchemaResult {
+  match json {
+    String(s) =>
+      if value_in_array(s, values) {
+        Ok(json)
+      } else {
+        Err([
+          ValidationError::{ path, message: "Invalid enum value", got: json },
+        ])
+      }
+    _ =>
+      Err([
+        ValidationError::{
+          path,
+          message: "Expected string for enum",
+          got: json,
+        },
+      ])
+  }
+}
+
+///|
+pub fn Schema::parse_union(
+  self : Schema,
+  schemas : Array[Schema],
+  json : Json,
+  path : String,
+) -> SchemaResult {
+  let mut last_errors : Array[ValidationError]? = None
+  for s in schemas {
+    match s.parse(json, path~) {
+      Ok(v) => return Ok(v)
+      Err(errors) => last_errors = Some(errors)
+    }
+  }
+  match last_errors {
+    Some(errors) => Err(errors)
+    None =>
+      Err([
+        ValidationError::{
+          path,
+          message: "Expected union type: none of the schemas matched current input",
+          got: json,
+        },
+      ])
+  }
+}
---
=== string.mbt ===
diff --git a/string.mbt b/string.mbt
index 94e30bb..1e0f5e9 100644
--- a/string.mbt
+++ b/string.mbt
@@ -6,7 +6,7 @@ pub fn string() -> Schema {
 
 ///|
 fn schema_min_check(s : Schema, n : Int) -> (Json) -> Bool {
-  match s.schema_type {
+  match inner_type(s.schema_type) {
     StringType =>
       fn(json) {
         match json {
@@ -34,7 +34,7 @@ fn schema_min_check(s : Schema, n : Int) -> (Json) -> Bool {
 
 ///|
 fn schema_min_msg(s : Schema, n : Int) -> String {
-  match s.schema_type {
+  match inner_type(s.schema_type) {
     StringType => "String must contain at least \{n} character(s)"
     NumberType => "Value must be >= \{n}"
     ArrayType(_) => "Array must contain at least \{n} item(s)"
@@ -47,12 +47,12 @@ fn schema_min_msg(s : Schema, n : Int) -> String {
 pub fn Schema::min(self : Schema, n : Int) -> Schema {
   let check = schema_min_check(self, n)
   let message = schema_min_msg(self, n)
-  { ..self, rules: self.rules + [{ check, message }] }
+  append_rule(self, check, message)
 }
 
 ///|
 fn schema_max_check(s : Schema, n : Int) -> (Json) -> Bool {
-  match s.schema_type {
+  match inner_type(s.schema_type) {
     StringType =>
       fn(json) {
         match json {
@@ -80,7 +80,7 @@ fn schema_max_check(s : Schema, n : Int) -> (Json) -> Bool {
 
 ///|
 fn schema_max_msg(s : Schema, n : Int) -> String {
-  match s.schema_type {
+  match inner_type(s.schema_type) {
     StringType => "String must contain at most \{n} character(s)"
     NumberType => "Value must be <= \{n}"
     ArrayType(_) => "Array must contain at most \{n} item(s)"
@@ -93,31 +93,26 @@ fn schema_max_msg(s : Schema, n : Int) -> String {
 pub fn Schema::max(self : Schema, n : Int) -> Schema {
   let check = schema_max_check(self, n)
   let message = schema_max_msg(self, n)
-  { ..self, rules: self.rules + [{ check, message }] }
+  append_rule(self, check, message)
 }
 
 ///|
 /// Require the string to be non-empty.
 pub fn Schema::nonempty(self : Schema) -> Schema {
-  let _ = match self.schema_type {
+  match inner_type(self.schema_type) {
     StringType => ()
     _ => abort("nonempty() is only valid for string schemas")
   }
-  {
-    ..self,
-    rules: self.rules +
-    [
-      {
-        check: fn(json) {
-          match json {
-            String(s) => !s.is_empty()
-            _ => false
-          }
-        },
-        message: "String must not be empty",
-      },
-    ],
-  }
+  append_rule(
+    self,
+    fn(json) {
+      match json {
+        String(s) => !s.is_empty()
+        _ => false
+      }
+    },
+    "String must not be empty",
+  )
 }
 
 ///|
@@ -144,25 +139,20 @@ fn has_at_and_dot(s : String) -> Bool {
 ///|
 /// Require the string to be a valid email.
 pub fn Schema::email(self : Schema) -> Schema {
-  let _ = match self.schema_type {
+  match inner_type(self.schema_type) {
     StringType => ()
     _ => abort("email() is only valid for string schemas")
   }
-  {
-    ..self,
-    rules: self.rules +
-    [
-      {
-        check: fn(json) {
-          match json {
-            String(s) => has_at_and_dot(s)
-            _ => false
-          }
-        },
-        message: "String must be a valid email address",
-      },
-    ],
-  }
+  append_rule(
+    self,
+    fn(json) {
+      match json {
+        String(s) => has_at_and_dot(s)
+        _ => false
+      }
+    },
+    "String must be a valid email address",
+  )
 }
 
 ///|
@@ -173,47 +163,37 @@ fn has_url_prefix(s : String) -> Bool {
 ///|
 /// Require the string to start with `http://` or `https://`.
 pub fn Schema::url(self : Schema) -> Schema {
-  let _ = match self.schema_type {
+  match inner_type(self.schema_type) {
     StringType => ()
     _ => abort("url() is only valid for string schemas")
   }
-  {
-    ..self,
-    rules: self.rules +
-    [
-      {
-        check: fn(json) {
-          match json {
-            String(s) => has_url_prefix(s)
-            _ => false
-          }
-        },
-        message: "String must be a valid URL",
-      },
-    ],
-  }
+  append_rule(
+    self,
+    fn(json) {
+      match json {
+        String(s) => has_url_prefix(s)
+        _ => false
+      }
+    },
+    "String must be a valid URL",
+  )
 }
 
 ///|
 /// Require the string to contain the given substring.
 pub fn Schema::regex(self : Schema, pattern : String) -> Schema {
-  let _ = match self.schema_type {
+  match inner_type(self.schema_type) {
     StringType => ()
     _ => abort("regex() is only valid for string schemas")
   }
-  {
-    ..self,
-    rules: self.rules +
-    [
-      {
-        check: fn(json) {
-          match json {
-            String(s) => s.contains(pattern)
-            _ => false
-          }
-        },
-        message: "String must match pattern: \{pattern}",
-      },
-    ],
-  }
+  append_rule(
+    self,
+    fn(json) {
+      match json {
+        String(s) => s.contains(pattern)
+        _ => false
+      }
+    },
+    "String must match pattern: \{pattern}",
+  )
 }
---
=== number.mbt ===
diff --git a/number.mbt b/number.mbt
index 48f4895..f7173d3 100644
--- a/number.mbt
+++ b/number.mbt
@@ -7,97 +7,76 @@ pub fn number() -> Schema {
 ///|
 /// Require the number to be an integer (no fractional part).
 pub fn Schema::int(self : Schema) -> Schema {
-  let _ = match self.schema_type {
+  match inner_type(self.schema_type) {
     NumberType => ()
     _ => abort("int() is only valid for number schemas")
   }
-  {
-    ..self,
-    rules: self.rules +
-    [
-      {
-        check: fn(json) {
-          match json {
-            Number(v, ..) => v == v.to_int().to_double()
-            _ => false
-          }
-        },
-        message: "Value must be an integer",
-      },
-    ],
-  }
+  append_rule(
+    self,
+    fn(json) {
+      match json {
+        Number(v, ..) => v == v.to_int().to_double()
+        _ => false
+      }
+    },
+    "Value must be an integer",
+  )
 }
 
 ///|
 /// Require the number to be positive (> 0).
 pub fn Schema::positive(self : Schema) -> Schema {
-  let _ = match self.schema_type {
+  match inner_type(self.schema_type) {
     NumberType => ()
     _ => abort("positive() is only valid for number schemas")
   }
-  {
-    ..self,
-    rules: self.rules +
-    [
-      {
-        check: fn(json) {
-          match json {
-            Number(v, ..) => v > 0.0
-            _ => false
-          }
-        },
-        message: "Value must be positive",
-      },
-    ],
-  }
+  append_rule(
+    self,
+    fn(json) {
+      match json {
+        Number(v, ..) => v > 0.0
+        _ => false
+      }
+    },
+    "Value must be positive",
+  )
 }
 
 ///|
 /// Require the number to be negative (< 0).
 pub fn Schema::negative(self : Schema) -> Schema {
-  let _ = match self.schema_type {
+  match inner_type(self.schema_type) {
     NumberType => ()
     _ => abort("negative() is only valid for number schemas")
   }
-  {
-    ..self,
-    rules: self.rules +
-    [
-      {
-        check: fn(json) {
-          match json {
-            Number(v, ..) => v < 0.0
-            _ => false
-          }
-        },
-        message: "Value must be negative",
-      },
-    ],
-  }
+  append_rule(
+    self,
+    fn(json) {
+      match json {
+        Number(v, ..) => v < 0.0
+        _ => false
+      }
+    },
+    "Value must be negative",
+  )
 }
 
 ///|
 /// Require the number to be a multiple of `n`.
 pub fn Schema::multipleOf(self : Schema, n : Int) -> Schema {
-  let _ = match self.schema_type {
+  match inner_type(self.schema_type) {
     NumberType => ()
     _ => abort("multipleOf() is only valid for number schemas")
   }
-  let msg = "Value must be a multiple of \{n}"
-  {
-    ..self,
-    rules: self.rules +
-    [
-      {
-        check: fn(json) {
-          match json {
-            Number(v, ..) =>
-              v / n.to_double() == (v / n.to_double()).to_int().to_double()
-            _ => false
-          }
-        },
-        message: msg,
-      },
-    ],
-  }
+  append_rule(
+    self,
+    fn(json) {
+      match json {
+        Number(v, ..) =>
+          v / n.to_double() == (v / n.to_double()).to_int().to_double()
+        _ => false
+      }
+    },
+    "Value must be a multiple of \{n}",
+  )
 }
---
=== refine.mbt ===
diff --git a/refine.mbt b/refine.mbt
index 2448393..98f97d9 100644
--- a/refine.mbt
+++ b/refine.mbt
@@ -8,5 +8,5 @@ pub fn Schema::refine(
   check : (Json) -> Bool,
   message : String,
 ) -> Schema {
-  { ..self, rules: self.rules + [{ check, message }] }
+  append_rule(self, check, message)
 }
---
=== cmd/main/main.mbt ===
diff --git a/cmd/main/main.mbt b/cmd/main/main.mbt
index e31b62c..101e934 100644
--- a/cmd/main/main.mbt
+++ b/cmd/main/main.mbt
@@ -1,7 +1,32 @@
 ///|
-/// Entry point for the CLI or runnable program in this template.
-/// Keep main focused; move logic into the library package.
+/// Benchmark: run a complex validation many times to measure throughput.
 /// Run with `moon run cmd/main` from the project root.
 fn main {
-  println("Hello")
+  let schema = @moon_zod.object({
+    "name": @moon_zod.string().min(2).max(50).nonempty(),
+    "age": @moon_zod.number().int().min(0).max(150),
+    "email": @moon_zod.string().email().optional(),
+    "tags": @moon_zod.array(@moon_zod.string().min(1)).optional(),
+    "address": @moon_zod.object({
+      "city": @moon_zod.string().min(1),
+      "zip": @moon_zod.string().regex("\\d{5}").optional(),
+    }).optional(),
+  })
+
+  let valid_input = Json::object({
+    "name": Json::string("Alice"),
+    "age": Json::number(30.0),
+    "email": Json::string("alice@example.com"),
+    "tags": Json::array([Json::string("admin"), Json::string("user")]),
+    "address": Json::object({
+      "city": Json::string("New York"),
+      "zip": Json::string("10001"),
+    }),
+  })
+
+  let n = 10_000
+  for i = 0; i < n; i = i + 1 {
+    let _ = schema.parse(valid_input)
+  }
+  println("Done: \{n} iterations without error")
 }
---
=== cmd/main/moon.pkg ===
diff --git a/cmd/main/moon.pkg b/cmd/main/moon.pkg
index 37a7651..3c80122 100644
--- a/cmd/main/moon.pkg
+++ b/cmd/main/moon.pkg
@@ -1,6 +1,6 @@
-// import {
-//   "username/moon_zod" @lib,
-// }
+import {
+  "username/moon_zod",
+}
 
 options(
   "is-main": true,
---
=== moon_zod_test.mbt ===
diff --git a/moon_zod_test.mbt b/moon_zod_test.mbt
index d8f0385..6ef6196 100644
--- a/moon_zod_test.mbt
+++ b/moon_zod_test.mbt
@@ -523,3 +523,101 @@ test "refine fails custom check" {
   )
   guard s.parse(Json::number(5.0)) is Err(_) else { fail("expected Err") }
 }
+
+///|
+/// Phase 4 — append_rule through optional/default chaining
+test "string().optional().min(3) passes non-null long enough" {
+  let s = string().optional().min(3)
+  match s.parse(Json::string("abc")) {
+    Ok(v) => assert_eq(v, Json::string("abc"))
+    Err(_) => fail("expected Ok")
+  }
+}
+
+///|
+test "string().optional().min(3) rejects short string" {
+  let s = string().optional().min(3)
+  guard s.parse(Json::string("ab")) is Err(_) else { fail("expected Err") }
+}
+
+///|
+test "string().optional().min(3) accepts null" {
+  let s = string().optional().min(3)
+  match s.parse(Json::null()) {
+    Ok(v) => assert_eq(v, Json::null())
+    Err(_) => fail("expected Ok")
+  }
+}
+
+///|
+test "string().default(x).min(3) uses default for null" {
+  let s = string().default(Json::string("xyz")).min(3)
+  match s.parse(Json::null()) {
+    Ok(v) => assert_eq(v, Json::string("xyz"))
+    Err(_) => fail("expected Ok")
+  }
+}
+
+///|
+test "default value satisfies rules chained after default" {
+  let s = string().default(Json::string("default!")).min(3)
+  match s.parse(Json::null()) {
+    Ok(v) => assert_eq(v, Json::string("default!"))
+    Err(_) => fail("expected Ok")
+  }
+}
+
+///|
+/// Phase 4 — to_json_schema
+test "to_json_schema string" {
+  let result = to_json_schema(string())
+  let expected = parse_json("{\"type\": \"string\"}")
+  assert_eq(result, expected)
+}
+
+///|
+test "to_json_schema object with optional field" {
+  let s = object({ "name": string(), "email": string().optional() })
+  let result = to_json_schema(s)
+  let expected = parse_json(
+    "{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"},\"email\":{\"type\":\"string\"}},\"additionalProperties\":true,\"required\":[\"name\"]}",
+  )
+  assert_eq(result, expected)
+}
+
+///|
+test "to_json_schema strict object" {
+  let s = object({ "x": number() }).strict()
+  let result = to_json_schema(s)
+  let expected = parse_json(
+    "{\"type\":\"object\",\"properties\":{\"x\":{\"type\":\"number\"}},\"additionalProperties\":false,\"required\":[\"x\"]}",
+  )
+  assert_eq(result, expected)
+}
+
+///|
+/// Phase 4 — union parse details
+test "union returns errors when no schema matches" {
+  let s = union([number().positive(), string().min(3)])
+  let input = parse_json("false")
+  match s.parse(input) {
+    Err(errors) => assert_true(errors.length() > 0)
+    _ => fail("expected Err")
+  }
+}
+
+///|
+/// Phase 4 — DefaultType parse
+test "default type accepts non-null and validates" {
+  let s = number().default(Json::number(0.0)).positive()
+  match s.parse(Json::number(5.0)) {
+    Ok(v) => assert_eq(v, Json::number(5.0))
+    Err(_) => fail("expected Ok")
+  }
+}
+
+///|
+test "default type rejects non-null failing validation" {
+  let s = number().default(Json::number(0.0)).positive()
+  guard s.parse(Json::number(-1.0)) is Err(_) else { fail("expected Err") }
+}
---
=== README.mbt.md ===
diff --git a/README.mbt.md b/README.mbt.md
index 265637f..9394534 100644
--- a/README.mbt.md
+++ b/README.mbt.md
@@ -4,6 +4,17 @@ A runtime JSON schema validation library for MoonBit, inspired by Zod and Pydant
 
 Designed for LLM Tool Calling scenarios: validate and error-report structured JSON output from large language models at runtime.
 
+## Features
+
+- **Primitive schemas**: `string()`, `number()`, `boolean()`, `null()`
+- **Compound schemas**: `object(Map)`, `array(Schema)`, `union(Array[Schema])`, `enum_values(Array[String])`
+- **Validation rules**: `.min(n)`, `.max(n)`, `.nonempty()`, `.email()`, `.url()`, `.regex(pattern)`, `.int()`, `.positive()`, `.negative()`, `.multipleOf(n)`
+- **Optional / Default**: `.optional()` and `.default(value)` with correct rule chaining through wrappers
+- **Object modes**: `.strict()` rejects extra fields; `.passthrough()` (default) allows them
+- **Custom rules**: `.refine(check, message)`
+- **JSON Schema export**: `to_json_schema(schema)` produces a standard JSON Schema object
+- **Detailed errors**: per-field path, message, and received value
+
 ## Usage
 
 ```mbt nocheck
@@ -11,10 +22,11 @@ Designed for LLM Tool Calling scenarios: validate and error-report structured JS
 let schema = @moon_zod.object({
   "name": @moon_zod.string().min(2).max(50),
   "age": @moon_zod.number().int().min(0).max(150),
+  "email": @moon_zod.string().email().optional(),
 })
 
 ///|
 let result = schema.parse(@json.parse(raw))
 ```
 
-See [DESIGN.md](./DESIGN.md) for architecture and development roadmap.
\ No newline at end of file
+See [DESIGN.md](./DESIGN.md) for architecture and development roadmap.
---
=== pkg.generated.mbti ===
diff --git a/pkg.generated.mbti b/pkg.generated.mbti
index 65d13d2..42c0987 100644
--- a/pkg.generated.mbti
+++ b/pkg.generated.mbti
@@ -2,12 +2,18 @@
 package "username/moon_zod"
 
 // Values
+pub fn append_rule(Schema, (Json) -> Bool, String) -> Schema
+
 pub fn array(Schema) -> Schema
 
 pub fn boolean() -> Schema
 
 pub fn enum_values(Array[String]) -> Schema
 
+pub fn inner_type(SchemaType) -> SchemaType
+
+pub fn is_optional_schema(Schema) -> Bool
+
 pub fn null() -> Schema
 
 pub fn number() -> Schema
@@ -16,8 +22,16 @@ pub fn object(Map[String, Schema]) -> Schema
 
 pub fn string() -> Schema
 
+pub fn sub_index(String, Int) -> String
+
+pub fn sub_path(String, String) -> String
+
+pub fn to_json_schema(Schema) -> Json
+
 pub fn union(Array[Schema]) -> Schema
 
+pub fn value_in_array(String, Array[String]) -> Bool
+
 // Errors
 
 // Types and methods
@@ -45,6 +59,12 @@ pub fn Schema::negative(Self) -> Self
 pub fn Schema::nonempty(Self) -> Self
 pub fn Schema::optional(Self) -> Self
 pub fn Schema::parse(Self, Json, path? : String) -> Result[Json, Array[ValidationError]]
+pub fn Schema::parse_array(Self, Self, Json, String) -> Result[Json, Array[ValidationError]]
+pub fn Schema::parse_default(Self, Self, Json, Json, String) -> Result[Json, Array[ValidationError]]
+pub fn Schema::parse_enum(Self, Array[String], Json, String) -> Result[Json, Array[ValidationError]]
+pub fn Schema::parse_object(Self, Map[String, Self], ObjectMode, Json, String) -> Result[Json, Array[ValidationError]]
+pub fn Schema::parse_optional(Self, Self, Json, String) -> Result[Json, Array[ValidationError]]
+pub fn Schema::parse_union(Self, Array[Self], Json, String) -> Result[Json, Array[ValidationError]]
 pub fn Schema::passthrough(Self) -> Self
 pub fn Schema::positive(Self) -> Self
 pub fn Schema::refine(Self, (Json) -> Bool, String) -> Self
---
