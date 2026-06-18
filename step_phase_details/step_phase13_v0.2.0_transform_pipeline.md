# Stage Summary

## 1. Stage Description

Upgrade moon_zod from v0.1.0 to v0.2.0 with two core additions:

**Phase 1 — Path Stack White-box Testing:** Create an automated safety net validating that the shared mutable `path_stack` always returns to length 0 after parsing, on both success and error paths.

**Phase 2 — `.transform()` Data Pipeline:** Add the `Schema::transform()` method that allows a Schema to mutate JSON output after validation, evolving moon_zod from a strict validator into a data transformation pipeline.

## 2. Stage Metadata
- STAGE_ID: v0.2.0-transform
- STAGE_TYPE: feature
- BASE_COMMIT: e2c3aa5564444f939a6836a3b424da5118d6ff34

## 3. New Files

### transform.mbt

```
///|
/// Apply a transformation function to the validated JSON value.
///
/// The schema is first validated normally. If validation succeeds, `f` is
/// called with the validated JSON. The transform can modify the value or
/// return an error.
///
/// Rules chained after `.transform()` are applied to the inner schema
/// (before the transform), maintaining decorator penetration semantics.
///
/// # Example
/// ```mbt nocheck
/// let s = string().transform(fn(json) {
///   match json {
///     String(s) => Ok(Json::string(s + "!"))
///     _ => Err("expected string")
///   }
/// })
/// ```
pub fn Schema::transform(
  self : Schema,
  f : (Json) -> Result[Json, String],
) -> Schema {
  { schema_type: TransformType(self, TransformClosure::{ f, }), rules: [] }
}

///|
pub fn Schema::parse_transform(
  _self : Schema,
  inner : Schema,
  closure : TransformClosure,
  json : Json,
  path_stack : Array[String],
) -> SchemaResult {
  match parse_inner(inner, json, path_stack) {
    Err(e) => Err(e)
    Ok(validated) =>
      match (closure.f)(validated) {
        Ok(transformed) => Ok(transformed)
        Err(msg) => {
          let path = format_path(path_stack)
          Err([ValidationError::{ path, message: msg, got: json }])
        }
      }
  }
}
```

### moon_zod_wbtest.mbt

```mbt
///|
/// Parse a JSON string, aborting on malformed test input.
fn parse_json(input : String) -> Json {
  @json.parse(input) catch {
    _ => abort("bad test json: " + input)
  }
}

///|
/// White-box tests for the mutable path_stack invariant.
///
/// The path_stack is a shared mutable Array[String] passed through
/// parse_inner -> parse_object / parse_array / etc. Each helper must
/// push before descending and pop after returning -- even on error paths.
///
/// These tests directly call `parse_inner` (package-private, fn) to
/// inspect the stack after parsing completes, verifying the invariant
/// that the stack is clean (length == 0) after both success and error.

///|
test "path_stack returns to length 0 after deep nested parse success" {
  let s = object({
    "a": object({ "b": array(object({ "c": number().positive() })) }),
  })
  let json = parse_json("{\"a\": {\"b\": [{\"c\": 1}, {\"c\": 2}]}}")
  let stack : Array[String] = []
  match parse_inner(s, json, stack) {
    Ok(_) => @debug.assert_eq(stack.length(), 0)
    Err(_) => fail("expected parse to succeed")
  }
}

///|
test "path_stack returns to length 0 after parse error" {
  let s = object({
    "a": object({ "b": array(object({ "c": number().positive() })) }),
  })
  let json = parse_json("{\"a\": {\"b\": [{\"c\": 1}, {\"c\": -1}]}}")
  let stack : Array[String] = []
  match parse_inner(s, json, stack) {
    Err(_) => @debug.assert_eq(stack.length(), 0)
    Ok(_) => fail("expected parse to fail")
  }
}

///|
test "path_stack returns to length 0 after strict mode error" {
  let s = object({ "x": number() }).strict()
  let json = parse_json("{\"x\": 1, \"y\": 2}")
  let stack : Array[String] = []
  match parse_inner(s, json, stack) {
    Err(_) => @debug.assert_eq(stack.length(), 0)
    Ok(_) => fail("expected parse to fail")
  }
}

///|
test "path_stack returns to length 0 after type error in array" {
  let s = array(number())
  let json = parse_json("[\"hello\"]")
  let stack : Array[String] = []
  match parse_inner(s, json, stack) {
    Err(_) => @debug.assert_eq(stack.length(), 0)
    Ok(_) => fail("expected parse to fail")
  }
}
```

## 4. Modified File Diffs

### schema.mbt

```diff
diff --git a/schema.mbt b/schema.mbt
index b1ab13a..4cb5e8d 100644
--- a/schema.mbt
+++ b/schema.mbt
@@ -19,6 +19,13 @@ pub(all) enum SchemaType {
   DefaultType(Schema, Json)
   EnumType(Array[String])
   UnionType(Array[Schema])
+  TransformType(Schema, TransformClosure)
+}
+
+///|
+/// Internal wrapper for a transform function stored in TransformType.
+pub(all) struct TransformClosure {
+  f : (Json) -> Result[Json, String]
 }
 
 ///|
@@ -41,6 +48,7 @@ pub fn inner_type(t : SchemaType) -> SchemaType {
   match t {
     OptionalType(inner) => inner.schema_type
     DefaultType(inner, _) => inner.schema_type
+    TransformType(inner, _) => inner.schema_type
     other => other
   }
 }
@@ -61,6 +69,10 @@ pub fn append_rule(
       let new_inner = append_rule(inner, check, message)
       { schema_type: DefaultType(new_inner, default_val), rules: [] }
     }
+    TransformType(inner, closure) => {
+      let new_inner = append_rule(inner, check, message)
+      { schema_type: TransformType(new_inner, closure), rules: [] }
+    }
     _ => { ..schema, rules: schema.rules + [{ check, message }] }
   }
 }
@@ -75,6 +87,7 @@ fn expected_msg(schema_type : SchemaType) -> String {
     ObjectType(_, _) => "Expected object"
     ArrayType(_) => "Expected array"
     EnumType(_) => "Invalid enum value"
+    TransformType(_, _) => "Validation failed"
     _ => "Validation failed"
   }
 }
@@ -166,6 +179,8 @@ fn parse_inner(
       schema.parse_default(inner, default_val, json, path_stack)
     EnumType(values) => schema.parse_enum(values, json, path_stack)
     UnionType(schemas) => schema.parse_union(schemas, json, path_stack)
+    TransformType(inner, closure) =>
+      schema.parse_transform(inner, closure, json, path_stack)
     _ => {
       let valid = match (schema.schema_type, json) {
         (StringType, String(_)) => true
```

### json_schema.mbt

```diff
diff --git a/json_schema.mbt b/json_schema.mbt
index 2663b7d..b2682c3 100644
--- a/json_schema.mbt
+++ b/json_schema.mbt
@@ -24,6 +24,7 @@ fn to_json_schema_inner(t : SchemaType) -> Json {
         "items": to_json_schema_inner(elem.schema_type),
       })
     OptionalType(inner) => to_json_schema_inner(inner.schema_type)
+    TransformType(inner, _) => to_json_schema_inner(inner.schema_type)
     DefaultType(inner, default_val) => {
       let inner_json = to_json_schema_inner(inner.schema_type)
       match inner_json {
```

### moon_zod_test.mbt (transform black-box tests)

```diff
diff --git a/moon_zod_test.mbt b/moon_zod_test.mbt
index 07aa058..a59c1d3 100644
--- a/moon_zod_test.mbt
+++ b/moon_zod_test.mbt
@@ -687,3 +687,107 @@ test "union aggregates all branch errors" {
     _ => fail("expected Err")
   }
 }
+
+///|
+/// Phase 2 — Transform Data Pipeline
+test "transform appends suffix to string" { ... }
+test "transform passes through already-valid value" { ... }
+test "transform returns error for invalid transform result" { ... }
+test "transform validates before transforming" { ... }
+test "transform with optional accepts null" { ... }
+test "transform error message includes path" { ... }
+test "to_json_schema ignores transform wrapper" { ... }
```

(Full test content omitted for brevity — see `git diff` on file for complete content.)

### pkg.generated.mbti (auto-generated)

```diff
+pub fn Schema::parse_transform(Self, Self, TransformClosure, Json, Array[String]) -> Result[Json, Array[ValidationError]]
+pub fn Schema::transform(Self, (Json) -> Result[Json, String]) -> Self
+  TransformType(Schema, TransformClosure)
+pub(all) struct TransformClosure {
+  f : (Json) -> Result[Json, String]
+}
```

## 5. Deleted Files

None.

## 6. ACTION_LOG

| Action | File | Reason |
|--------|------|--------|
| modify | `schema.mbt` | Add TransformType enum variant, TransformClosure struct, update inner_type/append_rule/expected_msg/parse_inner |
| create | `transform.mbt` | New file with Schema::transform() and Schema::parse_transform() |
| modify | `json_schema.mbt` | Add TransformType transparent pass-through in to_json_schema_inner |
| create | `moon_zod_wbtest.mbt` | White-box tests: 4 path stack invariant tests |
| modify | `moon_zod_test.mbt` | Black-box tests: 7 transform data pipeline tests |
| modify | `pkg.generated.mbti` | Auto-generated by moon info |

## 7. Risks / Notes

- TransformClosure struct uses a function field `f: (Json) -> Result[Json, String]`. MoonBit requires `(closure.f)(args)` syntax for calling struct field functions.
- TransformType decorator penetration in append_rule: rules chained after `.transform()` are applied to the inner schema (pre-transform validation), matching the existing OptionalType/DefaultType pattern.
- to_json_schema transparently passes through TransformType to the inner schema type, since transforms are arbitrary runtime functions with no JSON Schema representation.
- Path stack white-box tests use `parse_inner` (package-private `fn`), accessible via the `_wbtest.mbt` naming convention which compiles as part of the main package.
- Test count: 85 (74 original + 4 white-box + 7 transform), 0 warnings.
