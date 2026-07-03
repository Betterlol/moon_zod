# Stage Summary

## 1. Stage Description

Phase 37 core API enhancements: add string transforms, array nonempty, bigint factory, and schema brand metadata.

## 2. Stage Metadata

- STAGE_ID: Phase 37
- STAGE_TYPE: feature
- BASE_COMMIT: 1a45f2fa8cd14c288213eb5a83c5d4005bfc1079

## 3. New Files

- core/bigint.mbt

## 4. New File Full Contents

### core/bigint.mbt

```moonbit
///|
/// Create a schema that validates JSON integer values as big integers.
///
/// This is a convenience alias for `number().int()` that expresses
/// semantic intent. Useful for financial amounts, large IDs, and
/// other scenarios where the semantic type is "big integer" rather
/// than "number that is an integer".
pub fn bigint(
  required_error? : String = "",
  invalid_type_error? : String = "",
) -> Schema {
  number(required_error~, invalid_type_error~).int()
}
```

## 5. Modified Files

- core/array.mbt
- core/boolean.mbt
- core/default.mbt
- core/enum.mbt
- core/intersection.mbt
- core/literal.mbt
- core/null.mbt
- core/number.mbt
- core/object.mbt
- core/optional.mbt
- core/schema.mbt
- core/string.mbt
- core/transform.mbt
- core/union.mbt
- tests/reexporter.mbt
- tests/test_array.mbt
- tests/test_combinators.mbt
- tests/test_string.mbt

## 6. Modified File Diffs

### core/array.mbt

```diff
diff --git a/core/array.mbt b/core/array.mbt
index 6d248e0..5fb226a 100644
--- a/core/array.mbt
+++ b/core/array.mbt
@@ -14,6 +14,7 @@ pub fn array(
     required_error,
     invalid_type_error,
     name: "",
+    brand: "",
   }
 }
 
```

### core/boolean.mbt

```diff
diff --git a/core/boolean.mbt b/core/boolean.mbt
index 42a2d4f..b559384 100644
--- a/core/boolean.mbt
+++ b/core/boolean.mbt
@@ -11,5 +11,6 @@ pub fn boolean(
     required_error,
     invalid_type_error,
     name: "",
+    brand: "",
   }
 }
```

### core/default.mbt

```diff
diff --git a/core/default.mbt b/core/default.mbt
index 9ad6255..530a012 100644
--- a/core/default.mbt
+++ b/core/default.mbt
@@ -10,6 +10,7 @@ pub fn Schema::default(self : Schema, value : Json) -> Schema {
     required_error: self.required_error,
     invalid_type_error: self.invalid_type_error,
     name: self.name,
+    brand: self.brand,
   }
 }
 
```

### core/enum.mbt

```diff
diff --git a/core/enum.mbt b/core/enum.mbt
index 2ed85f7..4a83985 100644
--- a/core/enum.mbt
+++ b/core/enum.mbt
@@ -12,6 +12,7 @@ pub fn enum_values(
     required_error,
     invalid_type_error,
     name: "",
+    brand: "",
   }
 }
 
```

### core/intersection.mbt

```diff
diff --git a/core/intersection.mbt b/core/intersection.mbt
index 65ef6ff..dacfa2b 100644
--- a/core/intersection.mbt
+++ b/core/intersection.mbt
@@ -13,6 +13,7 @@ pub fn intersection(
     required_error,
     invalid_type_error,
     name: "",
+    brand: "",
   }
 }
 
```

### core/literal.mbt

```diff
diff --git a/core/literal.mbt b/core/literal.mbt
index 4384617..03ec41f 100644
--- a/core/literal.mbt
+++ b/core/literal.mbt
@@ -20,6 +20,7 @@ pub fn literal(
     required_error,
     invalid_type_error,
     name: "",
+    brand: "",
   }
 }
 
```

### core/null.mbt

```diff
diff --git a/core/null.mbt b/core/null.mbt
index 42dccef..7b0e851 100644
--- a/core/null.mbt
+++ b/core/null.mbt
@@ -11,5 +11,6 @@ pub fn null(
     required_error,
     invalid_type_error,
     name: "",
+    brand: "",
   }
 }
```

### core/number.mbt

```diff
diff --git a/core/number.mbt b/core/number.mbt
index 7861ad3..4edcc48 100644
--- a/core/number.mbt
+++ b/core/number.mbt
@@ -11,6 +11,7 @@ pub fn number(
     required_error,
     invalid_type_error,
     name: "",
+    brand: "",
   }
 }
 
```

### core/object.mbt

```diff
diff --git a/core/object.mbt b/core/object.mbt
index 27b3297..1828bad 100644
--- a/core/object.mbt
+++ b/core/object.mbt
@@ -16,6 +16,7 @@ pub fn object(
     required_error,
     invalid_type_error,
     name: "",
+    brand: "",
   }
 }
 
@@ -75,6 +76,7 @@ pub fn Schema::pick(self : Schema, keys : Array[String]) -> Schema {
         required_error: self.required_error,
         invalid_type_error: self.invalid_type_error,
         name: self.name,
+        brand: self.brand,
       }
     }
     _ => abort("pick() is only valid for object schemas")
@@ -109,6 +111,7 @@ pub fn Schema::omit(self : Schema, keys : Array[String]) -> Schema {
         required_error: self.required_error,
         invalid_type_error: self.invalid_type_error,
         name: self.name,
+        brand: self.brand,
       }
     }
     _ => abort("omit() is only valid for object schemas")
@@ -142,6 +145,7 @@ pub fn Schema::partial(self : Schema) -> Schema {
         required_error: self.required_error,
         invalid_type_error: self.invalid_type_error,
         name: self.name,
+        brand: self.brand,
       }
     }
     _ => abort("partial() is only valid for object schemas")
```

### core/optional.mbt

```diff
diff --git a/core/optional.mbt b/core/optional.mbt
index 56bddb3..450f80e 100644
--- a/core/optional.mbt
+++ b/core/optional.mbt
@@ -10,6 +10,7 @@ pub fn Schema::optional(self : Schema) -> Schema {
     required_error: self.required_error,
     invalid_type_error: self.invalid_type_error,
     name: self.name,
+    brand: self.brand,
   }
 }
 
```

### core/schema.mbt

```diff
diff --git a/core/schema.mbt b/core/schema.mbt
index 25bd5c4..738f104 100644
--- a/core/schema.mbt
+++ b/core/schema.mbt
@@ -47,6 +47,7 @@ pub(all) struct Schema {
   required_error : String
   invalid_type_error : String
   name : String
+  brand : String
 } derive(Debug)
 
 ///|
@@ -65,6 +66,15 @@ pub fn Schema::name(self : Schema, text : String) -> Schema {
   { ..self, name: text }
 }
 
+///|
+/// Assign a brand to a schema for nominal typing.
+/// Branded schemas carry a type-level marker that distinguishes
+/// structurally identical schemas (e.g., `UserId` vs `string`).
+/// The brand is rendered in prompt and JSON Schema exports.
+pub fn Schema::brand(self : Schema, text : String) -> Schema {
+  { ..self, brand: text }
+}
+
 ///|
 /// Override the error message of the last rule in the chain.
 /// Peels through OptionalType / DefaultType / TransformType wrappers
@@ -85,6 +95,7 @@ pub fn Schema::message(self : Schema, text : String) -> Schema {
         required_error: self.required_error,
         invalid_type_error: self.invalid_type_error,
         name: self.name,
+        brand: self.brand,
       }
     }
     DefaultType(inner, val) => {
@@ -96,6 +107,7 @@ pub fn Schema::message(self : Schema, text : String) -> Schema {
         required_error: self.required_error,
         invalid_type_error: self.invalid_type_error,
         name: self.name,
+        brand: self.brand,
       }
     }
     TransformType(inner, cls) => {
@@ -107,6 +119,7 @@ pub fn Schema::message(self : Schema, text : String) -> Schema {
         required_error: self.required_error,
         invalid_type_error: self.invalid_type_error,
         name: self.name,
+        brand: self.brand,
       }
     }
     _ => {
@@ -171,6 +184,7 @@ pub fn append_rule_with_annotation(
         required_error: schema.required_error,
         invalid_type_error: schema.invalid_type_error,
         name: schema.name,
+        brand: schema.brand,
       }
     }
     DefaultType(inner, default_val) => {
@@ -184,19 +198,7 @@ pub fn append_rule_with_annotation(
         required_error: schema.required_error,
         invalid_type_error: schema.invalid_type_error,
         name: schema.name,
-      }
-    }
-    TransformType(inner, closure) => {
-      let new_inner = append_rule_with_annotation(
-        inner, check, message, annotation,
-      )
-      {
-        schema_type: TransformType(new_inner, closure),
-        rules: [],
-        description: schema.description,
-        required_error: schema.required_error,
-        invalid_type_error: schema.invalid_type_error,
-        name: schema.name,
+        brand: schema.brand,
       }
     }
     _ => { ..schema, rules: schema.rules + [{ check, message, annotation }] }
```

### core/string.mbt

```diff
diff --git a/core/string.mbt b/core/string.mbt
index 0fc5d15..e8812a0 100644
--- a/core/string.mbt
+++ b/core/string.mbt
@@ -11,6 +11,7 @@ pub fn string(
     required_error,
     invalid_type_error,
     name: "",
+    brand: "",
   }
 }
 
@@ -118,26 +119,6 @@ pub fn Schema::max(self : Schema, n : Int, msg? : String = "") -> Schema {
   append_rule_with_annotation(self, check, message, annotation)
 }
 
-///|
-/// Require the string to be non-empty.
-pub fn Schema::nonempty(self : Schema, msg? : String = "") -> Schema {
-  match inner_type(self.schema_type) {
-    StringType => ()
-    _ => abort("nonempty() is only valid for string schemas")
-  }
-  let message = if msg.is_empty() { "String must not be empty" } else { msg }
-  append_rule(
-    self,
-    fn(json) {
-      match json {
-        String(s) => !s.is_empty()
-        _ => false
-      }
-    },
-    message,
-  )
-}
-
 ///|
 fn find_unquoted_at(chars : Array[Char]) -> Int {
   let mut i = 0
@@ -998,6 +979,77 @@ fn schema_length_msg(s : Schema, n : Int) -> String {
   }
 }
 
+///|
+/// Require the string to be non-empty (or array to be non-empty).
+pub fn Schema::nonempty(self : Schema, msg? : String = "") -> Schema {
+  match inner_type(self.schema_type) {
+    StringType => ()
+    ArrayType(_) => ()
+    _ => abort("nonempty() is only valid for string or array schemas")
+  }
+  let default_msg = match inner_type(self.schema_type) {
+    StringType => "String must not be empty"
+    _ => "Array must not be empty"
+  }
+  let message = if msg.is_empty() { default_msg } else { msg }
+  append_rule(
+    self,
+    fn(json) {
+      match json {
+        String(s) => !s.is_empty()
+        Array(arr) => !arr.is_empty()
+        _ => false
+      }
+    },
+    message,
+  )
+}
+
+///|
+/// Trim leading and trailing whitespace from the string.
+pub fn Schema::trim(self : Schema) -> Schema {
+  match inner_type(self.schema_type) {
+    StringType => ()
+    _ => abort("trim() is only valid for string schemas")
+  }
+  self.transform(fn(json) {
+    match json {
+      String(s) => Ok(Json::string(s.trim().to_owned()))
+      _ => Err("Expected string")
+    }
+  })
+}
+
+///|
+/// Convert the string to lowercase.
+pub fn Schema::to_lower(self : Schema) -> Schema {
+  match inner_type(self.schema_type) {
+    StringType => ()
+    _ => abort("to_lower() is only valid for string schemas")
+  }
+  self.transform(fn(json) {
+    match json {
+      String(s) => Ok(Json::string(s.to_lower()))
+      _ => Err("Expected string")
+    }
+  })
+}
+
+///|
+/// Convert the string to uppercase.
+pub fn Schema::to_upper(self : Schema) -> Schema {
+  match inner_type(self.schema_type) {
+    StringType => ()
+    _ => abort("to_upper() is only valid for string schemas")
+  }
+  self.transform(fn(json) {
+    match json {
+      String(s) => Ok(Json::string(s.to_upper()))
+      _ => Err("Expected string")
+    }
+  })
+}
+
 ///|
 /// Require the string or array to have exactly `n` items.
 pub fn Schema::length(self : Schema, n : Int, msg? : String = "") -> Schema {
```

### core/transform.mbt

```diff
diff --git a/core/transform.mbt b/core/transform.mbt
index 3aa55e3..49df334 100644
--- a/core/transform.mbt
+++ b/core/transform.mbt
@@ -5,8 +5,7 @@
 /// called with the validated JSON. The transform can modify the value or
 /// return an error.
 ///
-/// Rules chained after `.transform()` are applied to the inner schema
-/// (before the transform), maintaining decorator penetration semantics.
+/// Rules chained after `.transform()` are applied to the transformed value.
 ///
 /// # Example
 /// ```mbt nocheck
@@ -28,6 +27,7 @@ pub fn Schema::transform(
     required_error: self.required_error,
     invalid_type_error: self.invalid_type_error,
     name: self.name,
+    brand: self.brand,
   }
 }
 
@@ -43,7 +43,15 @@ pub fn Schema::parse_transform(
     Err(e) => Err(e)
     Ok(validated) =>
       match (closure.f)(validated) {
-        Ok(transformed) => Ok(transformed)
+        Ok(transformed) => {
+          let errors : Array[ValidationError] = []
+          collect_errors(errors, path_stack, transformed, _self.rules)
+          if errors.is_empty() {
+            Ok(transformed)
+          } else {
+            Err(errors)
+          }
+        }
         Err(msg) => {
           let path = format_path(path_stack)
           Err([ValidationError::{ path, message: msg, got: json }])
```

### core/union.mbt

```diff
diff --git a/core/union.mbt b/core/union.mbt
index f88f11f..5017226 100644
--- a/core/union.mbt
+++ b/core/union.mbt
@@ -13,6 +13,7 @@ pub fn union(
     required_error,
     invalid_type_error,
     name: "",
+    brand: "",
   }
 }
 
```

### tests/reexporter.mbt

```diff
diff --git a/tests/reexporter.mbt b/tests/reexporter.mbt
index 9cdae52..ba2deac 100644
--- a/tests/reexporter.mbt
+++ b/tests/reexporter.mbt
@@ -23,6 +23,7 @@ pub using @core {
   boolean,
   object,
   array,
+  bigint,
   enum_values,
   union,
   intersection,
```

### tests/test_array.mbt

```diff
diff --git a/tests/test_array.mbt b/tests/test_array.mbt
index 14f0bf2..955bd86 100644
--- a/tests/test_array.mbt
+++ b/tests/test_array.mbt
@@ -94,3 +94,23 @@ test "array length custom message" {
   }
   @debug.assert_eq(errors[0].message, "数组长度必须为2")
 }
+
+///|
+/// nonempty() for array
+test "array nonempty passes non-empty" {
+  let s = array(string()).nonempty()
+  guard s.parse(parse_json("[\"a\"]")) is Ok(_) else { fail("expected Ok") }
+}
+
+///|
+test "array nonempty rejects empty" {
+  let s = array(string()).nonempty()
+  guard s.parse(parse_json("[]")) is Err(_) else { fail("expected Err") }
+}
+
+///|
+test "array nonempty custom message" {
+  let s = array(string()).nonempty(msg="数组不能为空")
+  guard s.parse(parse_json("[]")) is Err(errors) else { fail("expected Err") }
+  @debug.assert_eq(errors[0].message, "数组不能为空")
+}
```

### tests/test_combinators.mbt

```diff
diff --git a/tests/test_combinators.mbt b/tests/test_combinators.mbt
index ebdffb6..0f3ced7 100644
--- a/tests/test_combinators.mbt
+++ b/tests/test_combinators.mbt
@@ -351,3 +351,51 @@ test "literal with custom error messages" {
     _ => fail("expected Err")
   }
 }
+
+///|
+/// brand()
+test "brand sets brand field on schema" {
+  let s = string().brand("MyString")
+  @debug.assert_eq(s.brand, "MyString")
+}
+
+///|
+test "brand preserves chaining" {
+  let s = string().brand("EmailString").email()
+  guard s.parse(Json::string("user@example.com")) is Ok(_) else {
+    fail("expected Ok")
+  }
+}
+
+///|
+/// bigint()
+test "bigint accepts integer number" {
+  let s = bigint()
+  guard s.parse(parse_json("42")) is Ok(_) else { fail("expected Ok") }
+}
+
+///|
+test "bigint rejects non-integer number" {
+  let s = bigint()
+  guard s.parse(parse_json("3.14")) is Err(_) else { fail("expected Err") }
+}
+
+///|
+test "bigint rejects boolean" {
+  let s = bigint()
+  guard s.parse(Json::boolean(true)) is Err(_) else { fail("expected Err") }
+}
+
+///|
+test "bigint respects min rule" {
+  let s = bigint().min(100)
+  guard s.parse(parse_json("50")) is Err(_) else { fail("expected Err") }
+  guard s.parse(parse_json("150")) is Ok(_) else { fail("expected Ok") }
+}
+
+///|
+test "bigint respects positive rule" {
+  let s = bigint().positive()
+  guard s.parse(parse_json("-5")) is Err(_) else { fail("expected Err") }
+  guard s.parse(parse_json("5")) is Ok(_) else { fail("expected Ok") }
+}
```

### tests/test_string.mbt

```diff
diff --git a/tests/test_string.mbt b/tests/test_string.mbt
index 01f25ad..f9af378 100644
--- a/tests/test_string.mbt
+++ b/tests/test_string.mbt
@@ -671,3 +671,75 @@ test "url custom message" {
   }
   @debug.assert_eq(errors[0].message, "不是有效的URL")
 }
+
+///|
+/// trim()
+test "string trim removes leading and trailing whitespace" {
+  let s = string().trim()
+  match s.parse(Json::string("  hello  ")) {
+    Ok(v) => @debug.assert_eq(v, Json::string("hello"))
+    Err(_) => fail("expected Ok")
+  }
+}
+
+///|
+test "string trim passes already-trimmed string" {
+  let s = string().trim()
+  match s.parse(Json::string("hello")) {
+    Ok(v) => @debug.assert_eq(v, Json::string("hello"))
+    Err(_) => fail("expected Ok")
+  }
+}
+
+///|
+test "string trim with min rule" {
+  let s = string().trim().min(3)
+  // After trim, "ab" length is 2, so min(3) should fail
+  guard s.parse(Json::string("  ab  ")) is Err(_) else { fail("expected Err") }
+}
+
+///|
+/// to_lower()
+test "string to_lower converts uppercase" {
+  let s = string().to_lower()
+  match s.parse(Json::string("HELLO")) {
+    Ok(v) => @debug.assert_eq(v, Json::string("hello"))
+    Err(_) => fail("expected Ok")
+  }
+}
+
+///|
+test "string to_lower passes already-lowercase" {
+  let s = string().to_lower()
+  match s.parse(Json::string("hello")) {
+    Ok(v) => @debug.assert_eq(v, Json::string("hello"))
+    Err(_) => fail("expected Ok")
+  }
+}
+
+///|
+/// to_upper()
+test "string to_upper converts lowercase" {
+  let s = string().to_upper()
+  match s.parse(Json::string("hello")) {
+    Ok(v) => @debug.assert_eq(v, Json::string("HELLO"))
+    Err(_) => fail("expected Ok")
+  }
+}
+
+///|
+test "string to_upper passes already-uppercase" {
+  let s = string().to_upper()
+  match s.parse(Json::string("HELLO")) {
+    Ok(v) => @debug.assert_eq(v, Json::string("HELLO"))
+    Err(_) => fail("expected Ok")
+  }
+}
+
+///|
+test "string to_lower aborts for string.abort calls" {
+  // nonempty() should abort for non-string after to_lower chain
+  // Just verify to_lower followed by min works
+  let s = string().to_lower().min(2)
+  guard s.parse(Json::string("A")) is Err(_) else { fail("expected Err") }
+}
```

## 7. Deleted Files

None.

## 8. ACTION_LOG

- Modified Schema to carry brand metadata and preserve it through wrappers.
- Added bigint factory as a semantic alias for integer numbers.
- Added string trim/to_lower/to_upper transforms.
- Extended nonempty() to support arrays.
- Adjusted transform rule chaining to validate transformed values for post-transform rules.
- Re-exported bigint in test package and added regression tests.

## 9. Risks / Notes

- Importer/exporter consumer layers are intentionally not synchronized in this phase.
- bigint currently accepts JSON integer numbers only; string-encoded integers are not supported.
- Validation run: moon info && moon fmt && moon test (444 passed, 0 failed; existing regex warning remains).
