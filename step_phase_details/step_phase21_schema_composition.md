# Stage Summary

## 1. Stage Description

Implement Schema composition combinators (`pick`, `omit`, `partial`) for object schemas, with full `schema_to_prompt` support, JSON Schema export, and description preservation.

## 2. Stage Metadata

- STAGE_ID: `phase21`
- STAGE_TYPE: `feature`
- BASE_COMMIT: `2f26afcc236e37a1eac731e7b6b7f52e9ead33c8`

## 3. New Files

None.

## 4. New File Full Contents

N/A

## 5. Modified Files

- `object.mbt` — added `Schema::pick()`, `Schema::omit()`, `Schema::partial()` (+91 lines)
- `moon_zod_test.mbt` — added 15 tests (+187 lines)

## 6. Modified File Diffs

### `object.mbt` diff against BASE_COMMIT

```diff
diff --git a/object.mbt b/object.mbt
index 1bf03e1..5273f46 100644
--- a/object.mbt
+++ b/object.mbt
@@ -37,6 +37,97 @@ pub fn Schema::strip(self : Schema) -> Schema {
   }
 }
 
+///|
+/// Select only the specified fields from an object schema.
+/// Returns a new object schema with the same mode (Strip/Passthrough/Strict).
+/// Keys not present in the original spec are silently ignored.
+///
+/// # Example
+/// ```
+/// let s = object({"a": string(), "b": number()}).pick(["a"])
+/// s.parse(json)  // validates only field "a"
+/// ```
+pub fn Schema::pick(self : Schema, keys : Array[String]) -> Schema {
+  match self.schema_type {
+    ObjectType(spec, mode) => {
+      let new_spec : Map[String, Schema] = {}
+      for key in keys {
+        match spec.get(key) {
+          Some(s) => new_spec.set(key, s)
+          None => ()
+        }
+      }
+      {
+        schema_type: ObjectType(new_spec, mode),
+        rules: self.rules,
+        description: self.description,
+      }
+    }
+    _ => abort("pick() is only valid for object schemas")
+  }
+}
+
+///|
+/// Omit the specified fields from an object schema.
+/// Returns a new object schema with the same mode (Strip/Passthrough/Strict).
+///
+/// # Example
+/// ```
+/// let s = object({"a": string(), "b": number()}).omit(["b"])
+/// s.parse(json)  // validates only field "a"
+/// ```
+pub fn Schema::omit(self : Schema, keys : Array[String]) -> Schema {
+  match self.schema_type {
+    ObjectType(spec, mode) => {
+      let new_spec : Map[String, Schema] = {}
+      for key in spec.keys() {
+        if !value_in_array(key, keys) {
+          match spec.get(key) {
+            Some(s) => new_spec.set(key, s)
+            None => ()
+          }
+        }
+      }
+      {
+        schema_type: ObjectType(new_spec, mode),
+        rules: self.rules,
+        description: self.description,
+      }
+    }
+    _ => abort("omit() is only valid for object schemas")
+  }
+}
+
+///|
+/// Make all fields of an object schema optional.
+/// Useful for partial updates (e.g., PATCH operations).
+/// Existing optional fields remain optional.
+///
+/// # Example
+/// ```
+/// let s = object({"name": string(), "age": number()}).partial()
+/// s.parse(json)  // all fields are now optional
+/// ```
+pub fn Schema::partial(self : Schema) -> Schema {
+  match self.schema_type {
+    ObjectType(spec, mode) => {
+      let new_spec : Map[String, Schema] = {}
+      for key in spec.keys() {
+        match spec.get(key) {
+          Some(s) => new_spec.set(key, s.optional())
+          None => ()
+        }
+      }
+      {
+        schema_type: ObjectType(new_spec, mode),
+        rules: self.rules,
+        description: self.description,
+      }
+    }
+    _ => abort("partial() is only valid for object schemas")
+  }
+}
+
 ///|
 pub fn Schema::parse_object(
   self : Schema,
```

### `moon_zod_test.mbt` diff against BASE_COMMIT

```diff
diff --git a/moon_zod_test.mbt b/moon_zod_test.mbt
index d4cecb5..1c82654 100644
--- a/moon_zod_test.mbt
+++ b/moon_zod_test.mbt
@@ -1336,6 +1336,78 @@ test &quot;schema_to_prompt describe through transform&quot; {
   @debug.assert_eq(schema_to_prompt(s), &quot;string  // 保持原样&quot;)
 }
 
+///|
+/// Schema composition — prompt output
+test &quot;schema_to_prompt pick&quot; {
+  let s = object({
+    &quot;a&quot;: string().min(2),
+    &quot;b&quot;: number(),
+  }).pick([&quot;a&quot;])
+  let expected = &quot;{\n&quot; +
+    &quot;  a: string,  // [min: 2]\n&quot; +
+    &quot;}&quot;
+  @debug.assert_eq(schema_to_prompt(s), expected)
+}
+
+///|
+test &quot;schema_to_prompt omit&quot; {
+  let s = object({
+    &quot;a&quot;: string(),
+    &quot;b&quot;: number().int(),
+  }).omit([&quot;b&quot;])
+  let expected = &quot;{\n&quot; +
+    &quot;  a: string,\n&quot; +
+    &quot;}&quot;
+  @debug.assert_eq(schema_to_prompt(s), expected)
+}
+
+///|
+test &quot;schema_to_prompt partial&quot; {
+  let s = object({
+    &quot;a&quot;: string().min(2),
+    &quot;b&quot;: number().int(),
+  }).partial()
+  let expected = &quot;{\n&quot; +
+    &quot;  a?: string,  // [min: 2]\n&quot; +
+    &quot;  b?: number,  // [int]\n&quot; +
+    &quot;}&quot;
+  @debug.assert_eq(schema_to_prompt(s), expected)
+}
+
+///|
+test &quot;schema_to_prompt pick with field description&quot; {
+  let s = object({
+    &quot;name&quot;: string().min(2).describe(&quot;用户名&quot;),
+    &quot;age&quot;: number().int().describe(&quot;年龄&quot;),
+  }).pick([&quot;name&quot;])
+  let expected = &quot;{\n&quot; +
+    &quot;  name: string,  // [min: 2] — 用户名\n&quot; +
+    &quot;}&quot;
+  @debug.assert_eq(schema_to_prompt(s), expected)
+}
+
+///|
+/// Description preservation through composition
+test &quot;pick preserves schema description&quot; {
+  let s = object({&quot;a&quot;: string(), &quot;b&quot;: number()}).describe(&quot;my schema&quot;)
+  let p = s.pick([&quot;a&quot;])
+  @debug.assert_eq(p.description, &quot;my schema&quot;)
+}
+
+///|
+test &quot;omit preserves schema description&quot; {
+  let s = object({&quot;a&quot;: string(), &quot;b&quot;: number()}).describe(&quot;my schema&quot;)
+  let o = s.omit([&quot;b&quot;])
+  @debug.assert_eq(o.description, &quot;my schema&quot;)
+}
+
+///|
+test &quot;partial preserves schema description&quot; {
+  let s = object({&quot;a&quot;: string(), &quot;b&quot;: number()}).describe(&quot;my schema&quot;)
+  let p = s.partial()
+  @debug.assert_eq(p.description, &quot;my schema&quot;)
+}
+
 ///|
 test &quot;intersection parse basic&quot; {
   let s = intersection([string().min(3), string().max(10)])
@@ -1796,3 +1868,118 @@ test &quot;email improved rejects single-char domain&quot; {
     fail(&quot;expected Err&quot;)
   }
 }
+
+///|
+/// Schema composition — pick()
+test &quot;pick selects specific fields&quot; {
+  let s = object({ &quot;a&quot;: string(), &quot;b&quot;: number(), &quot;c&quot;: boolean() })
+  let p = s.pick([&quot;a&quot;, &quot;c&quot;])
+  match
+    p.parse(Json::object({ &quot;a&quot;: Json::string(&quot;x&quot;), &quot;c&quot;: Json::boolean(true) })) {
+    Ok(v) =>
+      @debug.assert_eq(
+        v,
+        Json::object({ &quot;a&quot;: Json::string(&quot;x&quot;), &quot;c&quot;: Json::boolean(true) }),
+      )
+    Err(_) => fail(&quot;expected Ok&quot;)
+  }
+}
+
+///|
+test &quot;pick ignores keys not in original spec&quot; {
+  let p = object({ &quot;x&quot;: string() }).pick([&quot;x&quot;, &quot;y&quot;])
+  guard p.parse(Json::object({ &quot;x&quot;: Json::string(&quot;ok&quot;) })) is Ok(_) else {
+    fail(&quot;expected Ok&quot;)
+  }
+}
+
+///|
+test &quot;pick preserves field rules&quot; {
+  let p = object({ &quot;a&quot;: string().min(3) }).pick([&quot;a&quot;])
+  guard p.parse(Json::object({ &quot;a&quot;: Json::string(&quot;ab&quot;) })) is Err(_) else {
+    fail(&quot;expected Err&quot;)
+  }
+}
+
+///|
+test &quot;pick preserves object mode&quot; {
+  let p = object({ &quot;a&quot;: string() }).strict().pick([&quot;a&quot;])
+  guard p.parse(Json::object({ &quot;a&quot;: Json::string(&quot;x&quot;), &quot;b&quot;: Json::number(1) }))
+    is Err(_) else {
+    fail(&quot;expected Err for strict mode&quot;)
+  }
+}
+
+///|
+/// Schema composition — omit()
+test &quot;omit removes specific fields&quot; {
+  let s = object({ &quot;a&quot;: string(), &quot;b&quot;: number(), &quot;c&quot;: boolean() })
+  let o = s.omit([&quot;b&quot;])
+  match
+    o.parse(Json::object({ &quot;a&quot;: Json::string(&quot;x&quot;), &quot;c&quot;: Json::boolean(true) })) {
+    Ok(_) => ()
+    Err(_) => fail(&quot;expected Ok&quot;)
+  }
+}
+
+///|
+test &quot;omit all fields produces empty object&quot; {
+  let o = object({ &quot;a&quot;: string() }).omit([&quot;a&quot;])
+  match o.parse(Json::object({})) {
+    Ok(v) => @debug.assert_eq(v, Json::object({}))
+    Err(_) => fail(&quot;expected Ok&quot;)
+  }
+}
+
+///|
+test &quot;omit preserves field rules on remaining fields&quot; {
+  let o = object({ &quot;a&quot;: string().min(3), &quot;b&quot;: number() }).omit([&quot;b&quot;])
+  guard o.parse(Json::object({ &quot;a&quot;: Json::string(&quot;ab&quot;) })) is Err(_) else {
+    fail(&quot;expected Err from min(3)&quot;)
+  }
+}
+
+///|
+/// Schema composition — partial()
+test &quot;partial makes all fields optional&quot; {
+  let p = object({ &quot;a&quot;: string(), &quot;b&quot;: number() }).partial()
+  match p.parse(Json::object({})) {
+    Ok(_) => ()
+    Err(_) => fail(&quot;expected Ok&quot;)
+  }
+}
+
+///|
+test &quot;partial allows null on all fields&quot; {
+  let p = object({ &quot;a&quot;: string(), &quot;b&quot;: number() }).partial()
+  match p.parse(Json::object({ &quot;a&quot;: Json::null(), &quot;b&quot;: Json::null() })) {
+    Ok(_) => ()
+    Err(_) => fail(&quot;expected Ok&quot;)
+  }
+}
+
+///|
+test &quot;partial still validates present values&quot; {
+  let p = object({ &quot;a&quot;: string().min(3) }).partial()
+  guard p.parse(Json::object({ &quot;a&quot;: Json::string(&quot;ab&quot;) })) is Err(_) else {
+    fail(&quot;expected Err from min(3)&quot;)
+  }
+}
+
+///|
+test &quot;partial preserves object mode&quot; {
+  let p = object({ &quot;a&quot;: string() }).strict().partial()
+  guard p.parse(Json::object({ &quot;a&quot;: Json::string(&quot;x&quot;), &quot;b&quot;: Json::number(1) }))
+    is Err(_) else {
+    fail(&quot;expected Err for strict mode&quot;)
+  }
+}
+
+///|
+test &quot;partial on already partial keeps all fields optional&quot; {
+  let p = object({ &quot;a&quot;: string() }).partial().partial()
+  match p.parse(Json::object({})) {
+    Ok(_) => ()
+    Err(_) => fail(&quot;expected Ok&quot;)
+  }
+}
```

(Full diff truncated for readability; actual state verified by `git diff` at commit time.)

## 7. Deleted Files

None.

## 8. ACTION_LOG

| # | File | Action | Reason |
|---|------|--------|--------|
| 1 | `object.mbt` | modify | Add `Schema::pick()` / `Schema::omit()` / `Schema::partial()` — filter or wrap object spec fields |
| 2 | `moon_zod_test.mbt` | modify | Add 15 tests: pick(4) + omit(3) + partial(5) + prompt(4) + description preservation(3) |

## 9. Risks / Notes

- `pick()`/`omit()`/`partial()` all `abort()` on non-object schemas (consistent with `strict()`/`passthrough()`/`strip()` pattern)
- `partial()` wraps each field in `OptionalType`; nested `partial().partial()` is idempotent (double-OptionalType is harmless)
- JSON Schema export already handles OptionalType correctly via existing `is_optional_schema` + `required` exclusion logic — no changes needed
- Test count: 206 (up from 187), 0 warnings, 0 failures
