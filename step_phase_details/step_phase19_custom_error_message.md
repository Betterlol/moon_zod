# Stage Summary: Phase 19 — 自定义错误消息 (.message)

## 1. Stage Description

实现两种自定义错误消息机制：
1. **per-rule `msg?` 参数**：每个规则方法接受可选的 `msg?: String` 参数，非空时取代默认错误消息
2. **链式 `.message()` 方法**：覆盖链中最后一条规则的消息，支持 OptionalType/DefaultType/TransformType 穿透

## 2. Stage Metadata

- STAGE_ID: 19
- STAGE_TYPE: feature
- BASE_COMMIT: 41170f0a9d47c920ddeeeccde2cd39707174a916

## 3. New Files

无。仅修改已有文件。

## 4. Modified Files

| File | Action | Description |
|---|---|---|
| `string.mbt` | modify | `min`, `max`, `nonempty`, `email`, `url`, `regex` 添加 `msg?` 参数 |
| `number.mbt` | modify | `int`, `positive`, `negative`, `multipleOf` 添加 `msg?` 参数 |
| `schema.mbt` | modify | 新增 `Schema::message()` 方法（含装饰器穿透） |
| `moon_zod_test.mbt` | modify | 新增 22 个测试（14 per-rule msg? + 8 .message() 方法） |
| `pkg.generated.mbti` | modify | API 接口自动更新 |

## 5. Modified File Diffs

### string.mbt

```diff
@@ -44,9 +44,9 @@ fn schema_min_msg(s : Schema, n : Int) -> String {
 
 ///|
 /// Require the string length to be at least `n`.
-pub fn Schema::min(self : Schema, n : Int) -> Schema {
+pub fn Schema::min(self : Schema, n : Int, msg? : String = "") -> Schema {
   let check = schema_min_check(self, n)
-  let message = schema_min_msg(self, n)
+  let message = if msg.is_empty() { schema_min_msg(self, n) } else { msg }
   let annotation = match inner_type(self.schema_type) {
     StringType => Json::object({ "minLength": Json::number(n.to_double()) })
     NumberType => Json::object({ "minimum": Json::number(n.to_double()) })
@@ -96,9 +96,9 @@ fn schema_max_msg(s : Schema, n : Int) -> String {
 
 ///|
 /// Require the string length to be at most `n`.
-pub fn Schema::max(self : Schema, n : Int) -> Schema {
+pub fn Schema::max(self : Schema, n : Int, msg? : String = "") -> Schema {
   let check = schema_max_check(self, n)
-  let message = schema_max_msg(self, n)
+  let message = if msg.is_empty() { schema_max_msg(self, n) } else { msg }
   let annotation = match inner_type(self.schema_type) {
     StringType => Json::object({ "maxLength": Json::number(n.to_double()) })
     NumberType => Json::object({ "maximum": Json::number(n.to_double()) })
@@ -110,11 +110,12 @@ pub fn Schema::max(self : Schema, n : Int) -> Schema {
 
 ///|
 /// Require the string to be non-empty.
-pub fn Schema::nonempty(self : Schema) -> Schema {
+pub fn Schema::nonempty(self : Schema, msg? : String = "") -> Schema {
   match inner_type(self.schema_type) {
     StringType => ()
     _ => abort("nonempty() is only valid for string schemas")
   }
+  let message = if msg.is_empty() { "String must not be empty" } else { msg }
   append_rule(
     self,
     fn(json) {
@@ -123,7 +124,7 @@ pub fn Schema::nonempty(self : Schema) -> Schema {
         _ => false
       }
     },
-    "String must not be empty",
+    message,
   )
 }
 
@@ -150,11 +151,16 @@ fn has_at_and_dot(s : String) -> Bool {
 
 ///|
 /// Require the string to be a valid email.
-pub fn Schema::email(self : Schema) -> Schema {
+pub fn Schema::email(self : Schema, msg? : String = "") -> Schema {
   match inner_type(self.schema_type) {
     StringType => ()
     _ => abort("email() is only valid for string schemas")
   }
+  let message = if msg.is_empty() {
+    "String must be a valid email address"
+  } else {
+    msg
+  }
   append_rule_with_annotation(
     self,
     fn(json) {
@@ -163,7 +169,7 @@ pub fn Schema::email(self : Schema) -> Schema {
         _ => false
       }
     },
-    "String must be a valid email address",
+    message,
     Json::object({ "format": Json::string("email") }),
   )
 }
@@ -175,11 +181,12 @@ fn has_url_prefix(s : String) -> Bool {
 
 ///|
 /// Require the string to start with `http://` or `https://`.
-pub fn Schema::url(self : Schema) -> Schema {
+pub fn Schema::url(self : Schema, msg? : String = "") -> Schema {
   match inner_type(self.schema_type) {
     StringType => ()
     _ => abort("url() is only valid for string schemas")
   }
+  let message = if msg.is_empty() { "String must be a valid URL" } else { msg }
   append_rule_with_annotation(
     self,
     fn(json) {
@@ -188,18 +195,27 @@ pub fn Schema::url(self : Schema) -> Schema {
         _ => false
       }
     },
-    "String must be a valid URL",
+    message,
     Json::object({ "format": Json::string("uri") }),
   )
 }
 
 ///|
 /// Require the string to contain the given substring.
-pub fn Schema::regex(self : Schema, pattern : String) -> Schema {
+pub fn Schema::regex(
+  self : Schema,
+  pattern : String,
+  msg? : String = "",
+) -> Schema {
   match inner_type(self.schema_type) {
     StringType => ()
     _ => abort("regex() is only valid for string schemas")
   }
+  let message = if msg.is_empty() {
+    "String must match pattern: \{pattern}"
+  } else {
+    msg
+  }
   append_rule_with_annotation(
     self,
     fn(json) {
@@ -208,7 +224,7 @@ pub fn Schema::regex(self : Schema, pattern : String) -> Schema {
         _ => false
       }
     },
-    "String must match pattern: \{pattern}",
+    message,
     Json::object({ "pattern": Json::string(pattern) }),
   )
 }
```

### number.mbt

```diff
@@ -6,11 +6,12 @@ pub fn number() -> Schema {
 
 ///|
 /// Require the number to be an integer (no fractional part).
-pub fn Schema::int(self : Schema) -> Schema {
+pub fn Schema::int(self : Schema, msg? : String = "") -> Schema {
   match inner_type(self.schema_type) {
     NumberType => ()
     _ => abort("int() is only valid for number schemas")
   }
+  let message = if msg.is_empty() { "Value must be an integer" } else { msg }
   append_rule_with_annotation(
     self,
     fn(json) {
@@ -19,18 +20,19 @@ pub fn Schema::int(self : Schema) -> Schema {
         _ => false
       }
     },
-    "Value must be an integer",
+    message,
     Json::object({ "type": Json::string("integer") }),
   )
 }
 
 ///|
 /// Require the number to be positive (> 0).
-pub fn Schema::positive(self : Schema) -> Schema {
+pub fn Schema::positive(self : Schema, msg? : String = "") -> Schema {
   match inner_type(self.schema_type) {
     NumberType => ()
     _ => abort("positive() is only valid for number schemas")
   }
+  let message = if msg.is_empty() { "Value must be positive" } else { msg }
   append_rule_with_annotation(
     self,
     fn(json) {
@@ -39,18 +41,19 @@ pub fn Schema::positive(self : Schema) -> Schema {
         _ => false
       }
     },
-    "Value must be positive",
+    message,
     Json::object({ "exclusiveMinimum": Json::number(0.0) }),
   )
 }
 
 ///|
 /// Require the number to be negative (< 0).
-pub fn Schema::negative(self : Schema) -> Schema {
+pub fn Schema::negative(self : Schema, msg? : String = "") -> Schema {
   match inner_type(self.schema_type) {
     NumberType => ()
     _ => abort("negative() is only valid for number schemas")
   }
+  let message = if msg.is_empty() { "Value must be negative" } else { msg }
   append_rule_with_annotation(
     self,
     fn(json) {
@@ -59,18 +62,23 @@ pub fn Schema::negative(self : Schema) -> Schema {
         _ => false
       }
     },
-    "Value must be negative",
+    message,
     Json::object({ "exclusiveMaximum": Json::number(0.0) }),
   )
 }
 
 ///|
 /// Require the number to be a multiple of `n`.
-pub fn Schema::multipleOf(self : Schema, n : Int) -> Schema {
+pub fn Schema::multipleOf(self : Schema, n : Int, msg? : String = "") -> Schema {
   match inner_type(self.schema_type) {
     NumberType => ()
     _ => abort("multipleOf() is only valid for number schemas")
   }
+  let message = if msg.is_empty() {
+    "Value must be a multiple of \{n}"
+  } else {
+    msg
+  }
   append_rule_with_annotation(
     self,
     fn(json) {
@@ -80,7 +88,7 @@ pub fn Schema::multipleOf(self : Schema, n : Int) -> Schema {
         _ => false
       }
     },
-    "Value must be a multiple of \{n}",
+    message,
     Json::object({ "multipleOf": Json::number(n.to_double()) }),
   )
 }
```

### schema.mbt

```diff
@@ -53,6 +53,59 @@ pub fn Schema::describe(self : Schema, text : String) -> Schema {
   { ..self, description: text }
 }
 
+///|
+/// Override the error message of the last rule in the chain.
+/// Peels through OptionalType / DefaultType / TransformType wrappers
+/// to find the base schema with the rules array.
+///
+/// # Example
+/// ```
+/// string().min(2).message("姓名至少需要 2 个字符")
+/// ```
+pub fn Schema::message(self : Schema, text : String) -> Schema {
+  match self.schema_type {
+    OptionalType(inner) => {
+      let new_inner = inner.message(text)
+      {
+        schema_type: OptionalType(new_inner),
+        rules: [],
+        description: self.description,
+      }
+    }
+    DefaultType(inner, val) => {
+      let new_inner = inner.message(text)
+      {
+        schema_type: DefaultType(new_inner, val),
+        rules: [],
+        description: self.description,
+      }
+    }
+    TransformType(inner, cls) => {
+      let new_inner = inner.message(text)
+      {
+        schema_type: TransformType(new_inner, cls),
+        rules: [],
+        description: self.description,
+      }
+    }
+    _ => {
+      let n = self.rules.length()
+      if n == 0 {
+        abort("message() must follow a rule method")
+      }
+      let new_rules : Array[Rule] = []
+      for i = 0; i < n; i = i + 1 {
+        if i == n - 1 {
+          new_rules.push({ ..self.rules[i], message: text })
+        } else {
+          new_rules.push(self.rules[i])
+        }
+      }
+      { ..self, rules: new_rules }
+    }
+  }
+}
+
 ///|
 /// Peel OptionalType / DefaultType wrappers to find the effective base type.
 pub fn inner_type(t : SchemaType) -> SchemaType {
```

### pkg.generated.mbti

```diff
@@ -64,14 +64,15 @@ pub struct Schema {
 }
 pub fn Schema::default(Self, Json) -> Self
 pub fn Schema::describe(Self, String) -> Self
-pub fn Schema::email(Self) -> Self
-pub fn Schema::int(Self) -> Self
+pub fn Schema::email(Self, msg? : String) -> Self
+pub fn Schema::int(Self, msg? : String) -> Self
 pub fn Schema::intersect(Self, Self) -> Self
-pub fn Schema::max(Self, Int) -> Self
-pub fn Schema::min(Self, Int) -> Self
-pub fn Schema::multipleOf(Self, Int) -> Self
-pub fn Schema::negative(Self) -> Self
-pub fn Schema::nonempty(Self) -> Self
+pub fn Schema::max(Self, Int, msg? : String) -> Self
+pub fn Schema::message(Self, String) -> Self
+pub fn Schema::min(Self, Int, msg? : String) -> Self
+pub fn Schema::multipleOf(Self, Int, msg? : String) -> Self
+pub fn Schema::negative(Self, msg? : String) -> Self
+pub fn Schema::nonempty(Self, msg? : String) -> Self
 pub fn Schema::optional(Self) -> Self
 pub fn Schema::parse(Self, Json, path? : String) -> Result[Json, Array[ValidationError]]
 [...]
 pub fn Schema::passthrough(Self) -> Self
-pub fn Schema::positive(Self) -> Self
+pub fn Schema::positive(Self, msg? : String) -> Self
 pub fn Schema::refine(Self, (Json) -> Bool, String) -> Self
-pub fn Schema::regex(Self, String) -> Self
+pub fn Schema::regex(Self, String, msg? : String) -> Self
 pub fn Schema::strict(Self) -> Self
 pub fn Schema::strip(Self) -> Self
 pub fn Schema::transform(Self, (Json) -> Result[Json, String]) -> Self
-pub fn Schema::url(Self) -> Self
+pub fn Schema::url(Self, msg? : String) -> Self
```

### moon_zod_test.mbt

189 lines added — 22 new tests covering:
- Per-rule `msg?` parameter on all 10 string/number rule methods
- `.message()` method with basic, multi-rule, optional/default/transform chains
- Object field nesting
- Backward compatibility (no msg → default message unchanged)

## 6. Deleted Files

无。

## 7. ACTION_LOG

| # | File | Action | Reason |
|---|---|---|---|
| 1 | `string.mbt` | modify | Added `msg?` param to `min`, `max`, `nonempty`, `email`, `url`, `regex` with `if msg.is_empty()` fallback |
| 2 | `number.mbt` | modify | Added `msg?` param to `int`, `positive`, `negative`, `multipleOf` with `if msg.is_empty()` fallback |
| 3 | `schema.mbt` | modify | Added `Schema::message()` method that peels through OptionalType/DefaultType/TransformType wrappers to replace last rule's message |
| 4 | `moon_zod_test.mbt` | modify | 22 tests for both `msg?` param (14) and `.message()` method (8) |
| 5 | `pkg.generated.mbti` | modify | Auto-updated by `moon info` |

## 8. Risks / Notes

- **零破坏性**：`msg?` 默认 `""`，不传时行为不变。现有 149 测试零回归。
- **`.message()` safety**: 无 rules 时 `abort("message() must follow a rule method")`
- Test count: 149 → 171 (+22)
- Build warnings: 0
- 未修改：`Schema` 结构体、`Rule` 结构体、`collect_errors`、`append_rule`、`refine()`
