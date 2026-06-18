# Stage Summary

## 1. Stage Description

Implement Phase 3 of `moon_zod`: advanced features and combinators — array validation, optional fields, default values, enums, unions, and custom refine rules. Plus 19 passing tests (total 57).

## 2. Stage Metadata

- **STAGE_ID**: phase3
- **STAGE_TYPE**: feature-implementation
- **BASE_COMMIT**: `bf6b00a8f8555912e57f0f2cac139c38a5c39c6a`

## 3. New Files

| File | Description |
|---|---|
| `array.mbt` | `array(element_schema)` factory for array validation |
| `union.mbt` | `.optional()`, `.default(value)`, `enum_values(values)`, `union(schemas)` |
| `refine.mbt` | `.refine(check, message)` custom rule injection |

## 4. New File Full Contents

### array.mbt

```
///|
/// Create a schema that validates JSON arrays.
///
/// Each element in the array is validated against `element_schema`.
pub fn array(element_schema : Schema) -> Schema {
  { schema_type: ArrayType(element_schema), rules: [] }
}
```

### union.mbt

```
///|
/// Make a field optional: null or missing values pass validation.
/// Call `.optional()` last in a chain (rules before optional).
pub fn Schema::optional(self : Schema) -> Schema {
  { schema_type: OptionalType(self), rules: [] }
}

///|
/// Provide a default value when the input is null.
/// Call `.default(value)` last in a chain (rules before default).
pub fn Schema::default(self : Schema, value : Json) -> Schema {
  { schema_type: DefaultType(self, value), rules: [] }
}

///|
/// Create a schema that accepts one of a fixed set of string values.
pub fn enum_values(values : Array[String]) -> Schema {
  { schema_type: EnumType(values), rules: [] }
}

///|
/// Create a schema that accepts any of the given schemas (union / or).
/// Schemas are tried in order; the first match succeeds.
pub fn union(schemas : Array[Schema]) -> Schema {
  { schema_type: UnionType(schemas), rules: [] }
}
```

### refine.mbt

```
///|
/// Add a custom validation rule.
///
/// `check` is a predicate on the JSON value; `message` is the error message
/// shown when the predicate returns `false`.
pub fn Schema::refine(
  self : Schema,
  check : (Json) -> Bool,
  message : String,
) -> Schema {
  { ..self, rules: self.rules + [{ check, message }] }
}
```

## 5. Modified Files

| File | Change |
|---|---|
| `schema.mbt` | Add 5 `SchemaType` variants + `ArrayType`/`OptionalType`/`DefaultType`/`EnumType`/`UnionType` parse arms + ObjectType optional/default linkage |
| `string.mbt` | Add `ArrayType` support to `schema_min_check/msg` and `schema_max_check/msg` |
| `moon_zod_test.mbt` | Add 19 Phase 3 tests (total now 57) |
| `pkg.generated.mbti` | Auto-generated interface update |

## 6. Modified File Diffs

### schema.mbt

```diff
diff --git a/schema.mbt b/schema.mbt
index 41a0e6c..d7668cc 100644
--- a/schema.mbt
+++ b/schema.mbt
@@ -13,6 +13,11 @@ pub(all) enum SchemaType {
   BooleanType
   NullType
   ObjectType(Map[String, Schema], ObjectMode)
+  ArrayType(Schema)
+  OptionalType(Schema)
+  DefaultType(Schema, Json)
+  EnumType(Array[String])
+  UnionType(Array[Schema])
 }
 
 ///|
@@ -37,6 +42,9 @@ fn expected_msg(schema_type : SchemaType) -> String {
     BooleanType => "Expected boolean"
     NullType => "Expected null"
     ObjectType(_, _) => "Expected object"
+    ArrayType(_) => "Expected array"
+    EnumType(_) => "Invalid enum value"
+    _ => "Validation failed"
   }
 }
 
@@ -59,6 +67,42 @@ fn collect_errors(
   result
 }
 
+///|
+fn sub_path(path : String, name : String) -> String {
+  if path.is_empty() { name } else { "\{path}.\{name}" }
+}
+
+///|
+fn sub_index(path : String, i : Int) -> String {
+  if path.is_empty() { "[\{i}]" } else { "\{path}[\{i}]" }
+}
+
+///|
+fn value_in_array(s : String, arr : Array[String]) -> Bool {
+  for v in arr {
+    if v == s { return true }
+  }
+  false
+}
+
+///|
+fn is_optional_schema(s : Schema) -> Bool {
+  match s.schema_type {
+    OptionalType(_) | DefaultType(_, _) => true
+    _ => false
+  }
+}
+
 ///|
 /// Validate `json` against this schema.
 pub fn Schema::parse(
@@ -71,26 +115,21 @@ pub fn Schema::parse(
       match json {
         Object(input_map) => {
           let mut errors : Array[ValidationError] = []
-          let sub = fn(name : String) -> String { ... }
           for field_name in spec.keys() {
             match spec.get(field_name) {
               Some(field_schema) => {
-                let sub_path = sub(field_name)
+                let sp = sub_path(path, field_name)
                 match input_map.get(field_name) {
                   None =>
-                    errors.push(ValidationError::{
-                      path: sub_path,
-                      message: "Required",
-                      got: Json::null(),
-                    })
+                    if !is_optional_schema(field_schema) {
+                      errors.push(ValidationError::{
+                        path: sp,
+                        message: "Required",
+                        got: Json::null(),
+                      })
+                    }
                   Some(field_json) => {
-                    let result = field_schema.parse(field_json, path=sub_path)
+                    let result = field_schema.parse(field_json, path=sp)
                     match result { ... }
                   }
                 }
@@ -110,9 +149,8 @@ pub fn Schema::parse(
                 match input_map.get(key) {
                   Some(value) =>
                     if !spec.contains(key) {
-                      let field_path = sub(key)
                       errors.push(ValidationError::{
-                        path: field_path,
+                        path: sub_path(path, key),
                         message: "Unexpected field",
                         got: value,
                       })
@@ -138,6 +176,92 @@ pub fn Schema::parse(
             },
           ])
       }
+    ArrayType(element_schema) =>
+      match json {
+        Array(elements) => {
+          let mut errors : Array[ValidationError] = []
+          let mut i = 0
+          for element in elements {
+            let sp = sub_index(path, i)
+            let result = element_schema.parse(element, path=sp)
+            match result {
+              Err(item_errors) => for e in item_errors { errors.push(e) }
+              _ => ()
+            }
+            i = i + 1
+          }
+          errors = collect_errors(errors, path, json, self.rules)
+          if errors.is_empty() { Ok(json) } else { Err(errors) }
+        }
+        _ => Err([ValidationError::{
+          path,
+          message: expected_msg(self.schema_type),
+          got: json,
+        }])
+      }
+    OptionalType(inner) =>
+      match json {
+        Null => Ok(json)
+        _ => inner.parse(json, path~)
+      }
+    DefaultType(inner, default_val) =>
+      match json {
+        Null => Ok(default_val)
+        _ => inner.parse(json, path~)
+      }
+    EnumType(values) =>
+      match json {
+        String(s) =>
+          if value_in_array(s, values) { Ok(json) }
+          else { Err([ValidationError::{ path, message: "Invalid enum value", got: json }]) }
+        _ => Err([ValidationError::{ path, message: "Expected string for enum", got: json }])
+      }
+    UnionType(schemas) => {
+      let mut last_errors : Array[ValidationError]? = None
+      for s in schemas {
+        match s.parse(json, path~) {
+          Ok(v) => return Ok(v)
+          Err(errors) => last_errors = Some(errors)
+        }
+      }
+      match last_errors {
+        Some(errors) => Err(errors)
+        None => Err([ValidationError::{ path, message: "Expected union type, none matched", got: json }])
+      }
+    }
     _ => {
       let valid = match (self.schema_type, json) { ... }
       if !valid { return Err([...]) }
       let errors = collect_errors([], path, json, self.rules)
       if errors.is_empty() { Ok(json) } else { Err(errors) }
     }
   }
 }
```

### string.mbt

```diff
--- a/string.mbt
+++ b/string.mbt
@@ -21,6 +21,13 @@ fn schema_min_check(s : Schema, n : Int) -> (Json) -> Bool {
           _ => false
         }
       }
+    ArrayType(_) =>
+      fn(json) {
+        match json {
+          Array(arr) => arr.length() >= n
+          _ => false
+        }
+      }
     _ => fn(_) { false }
   }
 }
@@ -30,7 +37,8 @@ fn schema_min_msg(s : Schema, n : Int) -> String {
   match s.schema_type {
     StringType => "String must contain at least \{n} character(s)"
     NumberType => "Value must be >= \{n}"
-    _ => abort("min() is only valid for string or number schemas")
+    ArrayType(_) => "Array must contain at least \{n} item(s)"
+    _ => abort("min() is only valid for string, number, or array schemas")
   }
 }
 ...same pattern for schema_max_check and schema_max_msg...
```

### moon_zod_test.mbt

(19 new tests added — see full diff in `git diff bf6b00a -- moon_zod_test.mbt`)

### pkg.generated.mbti

(14 lines added — `array()`, `enum_values()`, `union()`, `Schema::default`, `Schema::optional`, `Schema::refine`, and 5 new `SchemaType` variants)

## 7. Deleted Files

None.

## 8. ACTION_LOG

| # | File | Action | Reason |
|---|---|---|---|
| 1 | `schema.mbt` | MODIFY | Add 5 `SchemaType` variants + refactor parse with `ArrayType`/`OptionalType`/`DefaultType`/`EnumType`/`UnionType` arms + ObjectType missing-field optional/default linkage |
| 2 | `string.mbt` | MODIFY | Add `ArrayType` branches to `schema_min_check/msg` and `schema_max_check/msg` |
| 3 | `array.mbt` | CREATE | `array(element_schema)` factory |
| 4 | `union.mbt` | CREATE | `.optional()`, `.default(value)`, `enum_values(values)`, `union(schemas)` |
| 5 | `refine.mbt` | CREATE | `.refine(check, message)` — push a custom rule |
| 6 | `moon_zod_test.mbt` | MODIFY | 19 tests covering array, optional, default, enum, union, refine |
| 7 | `pkg.generated.mbti` | MODIFY | Auto-generated by `moon info` |

## 9. Risks / Notes

- **`.optional()`/`.default()` should be called last**: These decorators delegate to the inner schema, so rules chained after them (e.g., `string().optional().min(3)`) would be lost. This matches Zod convention where `.optional()` terminates the chain.
- **No `Json::Object`/`Json::Array` construction**: Tests use `@json.parse(str)` since these JSON enum variants are read-only.
- **`path~` syntax**: MoonBit `moon fmt` auto-converts `path=path` to `path~` (label shorthand). This is valid MoonBit syntax.
- **Phase 3 scope**: 57/57 tests pass. JSON Schema export (`to_json_schema()`) deferred to Phase 4.
- **Backward compatible**: All new types added via `SchemaType` variants only; `Schema` struct fields unchanged.
