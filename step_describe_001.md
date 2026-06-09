# Stage Summary

## 1. Stage Description

Add `.describe(text)` method to Schema and render descriptions in `schema_to_prompt()` output.

This enables schema authors to attach human-readable field descriptions that appear alongside type constraints in LLM prompts, making `schema_to_prompt()` output semantically richer for LLM tool-calling scenarios.

## 2. Stage Metadata

- STAGE_ID: describe-001
- STAGE_TYPE: feature
- BASE_COMMIT: 7d6524e

## 3. New Files

None.

## 4. Modified Files

12 files modified:

| File | Change |
|---|---|
| `schema.mbt` | Added `description: String` field to Schema struct; added `pub fn Schema::describe()`; added `description: ""` to 3 `append_rule_with_annotation` wrapper branches |
| `string.mbt` | Added `description: ""` to `string()` factory |
| `number.mbt` | Added `description: ""` to `number()` factory |
| `boolean.mbt` | Added `description: ""` to `boolean()` factory |
| `null.mbt` | Added `description: ""` to `null()` factory |
| `array.mbt` | Added `description: ""` to `array()` factory |
| `object.mbt` | Added `description: ""` to `object()` factory |
| `union.mbt` | Added `description: self.description` to `optional()` and `default()`; added `description: ""` to `enum_values()` and `union()` |
| `transform.mbt` | Added `description: self.description` to `transform()` |
| `prompt.mbt` | Updated `schema_comment()` to render description alongside constraints; `object_to_prompt` passes `val_schema` instead of `inner` to preserve descriptions on optional fields |
| `moon_zod_test.mbt` | Added 8 tests covering describe+constraints, describe alone, optional, object fields, nested objects, transform |
| `README.mbt.md` | Added `.describe()` to API reference table; updated test counts (112→120) |

## 5. Modified File Diffs

### schema.mbt

```diff
diff --git a/schema.mbt b/schema.mbt
index 6c87782..a6297a8 100644
--- a/schema.mbt
+++ b/schema.mbt
@@ -41,6 +41,15 @@ pub(all) struct Rule {
 pub struct Schema {
   schema_type : SchemaType
   rules : Array[Rule]
+  description : String
+}
+
+///|
+/// Attach a human-readable description to a schema.
+/// The description is rendered by `schema_to_prompt()` alongside type and constraints,
+/// helping LLMs understand the semantic meaning of each field.
+pub fn Schema::describe(self : Schema, text : String) -> Schema {
+  { ..self, description: text }
 }
 
 ///|
@@ -79,19 +88,19 @@ pub fn append_rule_with_annotation(
       let new_inner = append_rule_with_annotation(
         inner, check, message, annotation,
       )
-      { schema_type: OptionalType(new_inner), rules: [] }
+      { schema_type: OptionalType(new_inner), rules: [], description: "" }
     }
     DefaultType(inner, default_val) => {
       let new_inner = append_rule_with_annotation(
         inner, check, message, annotation,
       )
-      { schema_type: DefaultType(new_inner, default_val), rules: [] }
+      { schema_type: DefaultType(new_inner, default_val), rules: [], description: "" }
     }
     TransformType(inner, closure) => {
       let new_inner = append_rule_with_annotation(
         inner, check, message, annotation,
       )
-      { schema_type: TransformType(new_inner, closure), rules: [] }
+      { schema_type: TransformType(new_inner, closure), rules: [], description: "" }
     }
     _ => { ..schema, rules: schema.rules + [{ check, message, annotation }] }
   }
```

### string.mbt

```diff
diff --git a/string.mbt b/string.mbt
index f178eca..17a0dda 100644
--- a/string.mbt
+++ b/string.mbt
@@ -1,7 +1,7 @@
 ///|
 /// Create a schema that validates JSON strings.
 pub fn string() -> Schema {
-  { schema_type: StringType, rules: [] }
+  { schema_type: StringType, rules: [], description: "" }
 }
```

### number.mbt

```diff
diff --git a/number.mbt b/number.mbt
index 35f7f38..aa7b180 100644
--- a/number.mbt
+++ b/number.mbt
@@ -1,7 +1,7 @@
 ///|
 /// Create a schema that validates JSON numbers.
 pub fn number() -> Schema {
-  { schema_type: NumberType, rules: [] }
+  { schema_type: NumberType, rules: [], description: "" }
 }
```

### boolean.mbt

```diff
diff --git a/boolean.mbt b/boolean.mbt
index 111e962..7c657f4 100644
--- a/boolean.mbt
+++ b/boolean.mbt
@@ -1,5 +1,5 @@
 ///|
 /// Create a schema that validates JSON booleans.
 pub fn boolean() -> Schema {
-  { schema_type: BooleanType, rules: [] }
+  { schema_type: BooleanType, rules: [], description: "" }
 }
```

### null.mbt

```diff
diff --git a/null.mbt b/null.mbt
index a380118..70051d7 100644
--- a/null.mbt
+++ b/null.mbt
@@ -1,5 +1,5 @@
 ///|
 /// Create a schema that validates JSON null.
 pub fn null() -> Schema {
-  { schema_type: NullType, rules: [] }
+  { schema_type: NullType, rules: [], description: "" }
 }
```

### array.mbt

```diff
diff --git a/array.mbt b/array.mbt
index 5d69257..8be5e46 100644
--- a/array.mbt
+++ b/array.mbt
@@ -3,7 +3,7 @@
 ///
 /// Each element in the array is validated against `element_schema`.
 pub fn array(element_schema : Schema) -> Schema {
-  { schema_type: ArrayType(element_schema), rules: [] }
+  { schema_type: ArrayType(element_schema), rules: [], description: "" }
 }
```

### object.mbt

```diff
diff --git a/object.mbt b/object.mbt
index 674a98c..1bf03e1 100644
--- a/object.mbt
+++ b/object.mbt
@@ -5,7 +5,7 @@
 /// By default, extra fields in the input JSON are silently stripped (Strip mode).
 /// Use `.passthrough()` to allow extra fields, or `.strict()` to reject them.
 pub fn object(spec : Map[String, Schema]) -> Schema {
-  { schema_type: ObjectType(spec, Strip), rules: [] }
+  { schema_type: ObjectType(spec, Strip), rules: [], description: "" }
 }
```

### union.mbt

```diff
diff --git a/union.mbt b/union.mbt
index 93d9fe2..46b4d05 100644
--- a/union.mbt
+++ b/union.mbt
@@ -3,7 +3,7 @@
 /// Rules chained after `.optional()` are pushed through to the inner schema
 /// via `append_rule`, so `string().optional().min(3)` works correctly.
 pub fn Schema::optional(self : Schema) -> Schema {
-  { schema_type: OptionalType(self), rules: [] }
+  { schema_type: OptionalType(self), rules: [], description: self.description }
 }
 
 ///|
@@ -11,20 +11,20 @@ pub fn Schema::optional(self : Schema) -> Schema {
 /// Rules chained after `.default()` are pushed through to the inner schema
 /// via `append_rule`.
 pub fn Schema::default(self : Schema, value : Json) -> Schema {
-  { schema_type: DefaultType(self, value), rules: [] }
+  { schema_type: DefaultType(self, value), rules: [], description: self.description }
 }
 
 ///|
 /// Create a schema that accepts one of a fixed set of string values.
 pub fn enum_values(values : Array[String]) -> Schema {
-  { schema_type: EnumType(values), rules: [] }
+  { schema_type: EnumType(values), rules: [], description: "" }
 }
 
 ///|
 /// Create a schema that accepts any of the given schemas (union / or).
 /// Schemas are tried in order; the first match succeeds.
 pub fn union(schemas : Array[Schema]) -> Schema {
-  { schema_type: UnionType(schemas), rules: [] }
+  { schema_type: UnionType(schemas), rules: [], description: "" }
 }
```

### transform.mbt

```diff
diff --git a/transform.mbt b/transform.mbt
index 1869623..c495a31 100644
--- a/transform.mbt
+++ b/transform.mbt
@@ -21,7 +21,11 @@ pub fn Schema::transform(
   self : Schema,
   f : (Json) -> Result[Json, String],
 ) -> Schema {
-  { schema_type: TransformType(self, TransformClosure::{ f, }), rules: [] }
+  {
+    schema_type: TransformType(self, TransformClosure::{ f, }),
+    rules: [],
+    description: self.description,
+  }
 }
```

### prompt.mbt

```diff
diff --git a/prompt.mbt b/prompt.mbt
index 7bd6d0b..b5dcf6f 100644
--- a/prompt.mbt
+++ b/prompt.mbt
@@ -96,7 +96,7 @@ fn object_to_prompt(spec : Map[String, Schema], indent : Int) -> String {
     }
 
     let field_type = type_to_prompt(inner, inner_indent)
-    let comment = schema_comment(inner)
+    let comment = schema_comment(val_schema)
     let opt_mark = if key_is_optional { "?" } else { "" }
     let line = indent_str(inner_indent) + key + opt_mark + ": " + field_type
 
@@ -152,11 +152,21 @@ fn schema_comment(schema : Schema) -> String {
     }
     _ => inner
   }
-  if merged.is_empty() {
+  let constraint_part = if merged.is_empty() {
     ""
   } else {
     "[" + merged + "]"
   }
+  let desc = schema.description
+  if constraint_part.is_empty() && desc.is_empty() {
+    ""
+  } else if constraint_part.is_empty() {
+    desc
+  } else if desc.is_empty() {
+    constraint_part
+  } else {
+    constraint_part + " — " + desc
+  }
 }
```

### moon_zod_test.mbt

```diff
diff --git a/moon_zod_test.mbt b/moon_zod_test.mbt
index 1669f38..f715635 100644
--- a/moon_zod_test.mbt
+++ b/moon_zod_test.mbt
@@ -1087,3 +1087,82 @@ test "schema_to_prompt default with constraints" {
   let s = string().min(3).default(Json::string("abc"))
   @debug.assert_eq(schema_to_prompt(s), "string | null  // [min: 3]")
 }
+
+///|
+test "schema_to_prompt describe alone" {
+  @debug.assert_eq(
+    schema_to_prompt(string().describe("用户名")),
+    "string  // 用户名",
+  )
+}
+
+///|
+test "schema_to_prompt describe with constraints" {
+  @debug.assert_eq(
+    schema_to_prompt(string().min(3).max(50).describe("用户名")),
+    "string  // [3-50 chars] — 用户名",
+  )
+}
+
+///|
+test "schema_to_prompt describe on optional" {
+  @debug.assert_eq(
+    schema_to_prompt(string().min(3).optional().describe("昵称")),
+    "string | null  // [min: 3] — 昵称",
+  )
+}
+
+///|
+test "schema_to_prompt describe alone on optional" {
+  @debug.assert_eq(
+    schema_to_prompt(string().optional().describe("备注")),
+    "string | null  // 备注",
+  )
+}
+
+///|
+test "schema_to_prompt describe on object fields" {
+  let s = object({
+    "name": string().min(2).max(50).describe("产品名称"),
+    "price": number().positive().describe("产品价格"),
+    "url": string().url().describe("产品链接"),
+  })
+  let expected = "{\n" +
+    "  name: string,  // [2-50 chars] — 产品名称\n" +
+    "  price: number,  // [positive] — 产品价格\n" +
+    "  url: string,  // [url] — 产品链接\n" +
    "}"
+  @debug.assert_eq(schema_to_prompt(s), expected)
+}
+
+///|
+test "schema_to_prompt describe on optional object field" {
+  let s = object({
+    "email": string().email().optional().describe("用户邮箱"),
+  })
+  let expected = "{\n" +
+    "  email?: string,  // [email] — 用户邮箱\n" +
+    "}"
+  @debug.assert_eq(schema_to_prompt(s), expected)
+}
+
+///|
+test "schema_to_prompt describe on nested object field" {
+  let s = object({
+    "profile": object({
+      "bio": string().min(10).max(500).describe("个人简介"),
+    }).describe("用户资料"),
+  })
+  let expected = "{\n" +
+    "  profile: {\n" +
+    "    bio: string,  // [10-500 chars] — 个人简介\n" +
+    "  },  // 用户资料\n" +
+    "}"
+  @debug.assert_eq(schema_to_prompt(s), expected)
+}
+
+///|
+test "schema_to_prompt describe through transform" {
+  let s = string().describe("保持原样").transform(fn(j) { Ok(j) })
+  @debug.assert_eq(schema_to_prompt(s), "string  // 保持原样")
+}
```

### README.mbt.md

```diff
diff --git a/README.mbt.md b/README.mbt.md
index 791ba0e..f1d83eb 100644
--- a/README.mbt.md
+++ b/README.mbt.md
@@ -241,6 +241,7 @@ cd bench_cross_lang && node bench.js  # Cross-language comparison
 | `.strict()` | object | Reject undefined fields |
 | `.passthrough()` | object | Keep undefined fields as-is |
 | `.strip()` | object | Silently remove undefined fields (default) |
+| `.describe(text)` | Any | Attach description rendered by `schema_to_prompt()` for LLM prompts |
 | `.refine(check, msg)` | Any | Custom validation predicate |
 | `.transform(fn)` | Any | Validate then transform output via `(Json) -> Result[Json, String]` |
 
@@ -297,7 +298,7 @@ moon_zod/
 ├── cmd/main/           # Benchmark
 ├── examples/llm_agent/ # LLM self-correction demo
 ├── examples/real_llm_agent/ # Real LLM Agent — full pipeline demo
-├── moon_zod_test.mbt   # Black-box tests (108)
+├── moon_zod_test.mbt   # Black-box tests (116)
 └── moon_zod_wbtest.mbt # White-box tests (4)
 ```
 
@@ -306,7 +307,7 @@ moon_zod/
 ## Development
 
 ```bash
-moon test                # Run all tests (112 total)
+moon test                # Run all tests (120 total)
 moon build               # Build the library
 moon run cmd/main        # Run benchmark
 moon run cmd/json2schema -- '{"hello":"world"}'  # Generate schema from JSON
```

## 6. ACTION_LOG

1. `schema.mbt:41-51` — Added `description: String` field to Schema struct
2. `schema.mbt:47-51` — Added `pub fn Schema::describe()` method
3. `schema.mbt:91,97,103` — Added `description: ""` to `append_rule_with_annotation` wrapper branches
4. `string.mbt:4` — Added `description: ""` to `string()`
5. `number.mbt:4` — Added `description: ""` to `number()`
6. `boolean.mbt:4` — Added `description: ""` to `boolean()`
7. `null.mbt:4` — Added `description: ""` to `null()`
8. `array.mbt:6` — Added `description: ""` to `array()`
9. `object.mbt:8` — Added `description: ""` to `object()`
10. `union.mbt:6` — Added `description: self.description` to `optional()`
11. `union.mbt:14` — Added `description: self.description` to `default()`
12. `union.mbt:20` — Added `description: ""` to `enum_values()`
13. `union.mbt:27` — Added `description: ""` to `union()`
14. `transform.mbt:24-28` — Added `description: self.description` to `transform()`
15. `prompt.mbt:99` — Changed `schema_comment(inner)` to `schema_comment(val_schema)` for description preservation on optional fields
16. `prompt.mbt:155-170` — Updated `schema_comment` to combine constraint_part and description with " — " separator
17. `moon_zod_test.mbt:1091-1171` — Added 8 tests for `.describe()` coverage
18. `README.mbt.md:244` — Added `.describe()` to API reference table
19. `README.mbt.md:301,310` — Updated test counts 112→120

## 7. Risks / Notes

- `optional()` and `default()` propagate `self.description` to the wrapper, so `describe()` called before optional works (`string().describe("x").optional()` → wrapper has description "x")
- `transform()` also propagates description
- `append_rule_with_annotation` wrapper branches set `description: ""` (empty), which is correct since rules are metadata, not field-level descriptions
- `.describe()` at end of chain always works since `{ ..self, description: text }` preserves the full schema state
- No impact on parsing behavior — description is purely metadata for `schema_to_prompt()`
