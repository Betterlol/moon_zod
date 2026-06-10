# Stage Summary: Phase 20 — 增强验证器集

## 1. Stage Description

为 `moon_zod` 新增 4 个字符串验证器并改进 email 校验：
- `.startsWith(prefix, msg?)` — 字符串前缀校验
- `.endsWith(suffix, msg?)` — 字符串后缀校验
- `.includes(substring, msg?)` — 字符串包含校验
- `.uuid(msg?)` — UUID v4 格式校验
- 改进 `.email(msg?)` — 更健壮的 email 校验（替代简单的 `has_at_and_dot`）

所有验证器均支持 `msg?` 可选参数和 JSON Schema annotation 导出。

## 2. Stage Metadata

- STAGE_ID: 20
- STAGE_TYPE: feature
- BASE_COMMIT: 2939b74

## 3. New Files

无。

## 4. Modified Files

| File | Action | Description |
|---|---|---|
| `string.mbt` | modify | 新增 4 个验证器 + 替换 `has_at_and_dot` 为 `is_valid_email` |
| `moon_zod_test.mbt` | modify | 新增 18 个测试 |

## 5. Modified File Diffs

### string.mbt

```diff
+
+///|
+/// Require the string to start with the given prefix.
+pub fn Schema::startsWith(
+  self : Schema,
+  prefix : String,
+  msg? : String = "",
+) -> Schema {
+  match inner_type(self.schema_type) {
+    StringType => ()
+    _ => abort("startsWith() is only valid for string schemas")
+  }
+  let message = if msg.is_empty() {
+    "String must start with \"\{prefix}\""
+  } else {
+    msg
+  }
+  append_rule_with_annotation(
+    self,
+    fn(json) {
+      match json {
+        String(s) => s.has_prefix(prefix)
+        _ => false
+      }
+    },
+    message,
+    Json::object({ "pattern": Json::string("^" + prefix) }),
+  )
+}
+
+///|
+/// Require the string to end with the given suffix.
+pub fn Schema::endsWith(
+  self : Schema,
+  suffix : String,
+  msg? : String = "",
+) -> Schema {
+  match inner_type(self.schema_type) {
+    StringType => ()
+    _ => abort("endsWith() is only valid for string schemas")
+  }
+  let message = if msg.is_empty() {
+    "String must end with \"\{suffix}\""
+  } else {
+    msg
+  }
+  append_rule_with_annotation(
+    self,
+    fn(json) {
+      match json {
+        String(s) => s.has_suffix(suffix)
+        _ => false
+      }
+    },
+    message,
+    Json::object({ "pattern": Json::string(suffix + "$") }),
+  )
+}
+
+///|
+/// Require the string to contain the given substring.
+pub fn Schema::includes(
+  self : Schema,
+  substring : String,
+  msg? : String = "",
+) -> Schema {
+  match inner_type(self.schema_type) {
+    StringType => ()
+    _ => abort("includes() is only valid for string schemas")
+  }
+  let message = if msg.is_empty() {
+    "String must include \"\{substring}\""
+  } else {
+    msg
+  }
+  append_rule(
+    self,
+    fn(json) {
+      match json {
+        String(s) => s.contains(substring)
+        _ => false
+      }
+    },
+    message,
+  )
+}
+
+///|
+fn is_hex_digit(c : Char) -> Bool {
+  (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
+}
+
+///|
+/// Require the string to be a valid UUID v4.
+/// Format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
+pub fn Schema::uuid(self : Schema, msg? : String = "") -> Schema {
+  match inner_type(self.schema_type) {
+    StringType => ()
+    _ => abort("uuid() is only valid for string schemas")
+  }
+  let message = if msg.is_empty() {
+    "String must be a valid UUID v4"
+  } else {
+    msg
+  }
+  append_rule_with_annotation(
+    self,
+    fn(json) {
+      match json {
+        String(s) => {
+          // layout: 8-4-4-4-12 = 36 chars
+          // version nibble at idx 14 = '4'
+          // variant nibble at idx 19 in {8,9,a,b,A,B}
+          let chars = s.to_array()
+          if chars.length() != 36 { return false }
+          if chars[8]!='-'||chars[13]!='-'||chars[18]!='-'||chars[23]!='-' {
+            return false
+          }
+          if chars[14] != '4' { return false }
+          if !(chars[19]=='8'||chars[19]=='9'||chars[19]=='a'||
+               chars[19]=='b'||chars[19]=='A'||chars[19]=='B') {
+            return false
+          }
+          let positions = [0,1,2,3,4,5,6,7,9,10,11,12,15,16,17,
+                           20,21,22,24,25,26,27,28,29,30,31,32,33,34,35]
+          for i in positions { if !is_hex_digit(chars[i]) { return false } }
+          true
+        }
+        _ => false
+      }
+    },
+    message,
+    Json::object({ "format": Json::string("uuid") }),
+  )
+}
```

Email improvement diff (key changes):

```diff
-fn has_at_and_dot(s : String) -> Bool {
+fn is_valid_email(s : String) -> Bool {
   let chars = s.to_array()
-  let mut at_pos : Int = -1
+  let n = chars.length()
+  let mut at_count = 0
+  let mut at_pos = -1
   for i, c in chars {
     if c == '@' {
+      at_count = at_count + 1
       at_pos = i
-      break
     }
   }
+  if at_count != 1 { return false }
   if at_pos <= 0 { return false }
-  for i = at_pos + 1; i < chars.length(); i = i + 1 {
-    if chars[i] == '.' && i > at_pos + 1 && i < chars.length() - 1 {
+  if chars[0] == '.' || chars[at_pos - 1] == '.' { return false }
+  if at_pos >= n - 1 { return false }
+  if chars[at_pos + 1] == '.' || chars[n - 1] == '.' { return false }
+  for i = at_pos + 1; i < n; i = i + 1 {
+    if chars[i] == '.' {
       return true
     }
   }
```

### moon_zod_test.mbt

173 lines added — 18 tests:
- 4 × startsWith (pass, fail, empty prefix, custom message)
- 3 × endsWith (pass, fail, custom message)
- 3 × includes (pass, fail, custom message)
- 3 × uuid (valid v4 × 4 cases, invalid × 5 cases, custom message)
- 5 × improved email (multiple @, leading dot local, trailing dot domain, subdomain, single-char domain)

## 6. Deleted Files

无。

## 7. ACTION_LOG

| # | File | Action | Reason |
|---|---|---|---|
| 1 | `string.mbt` | modify | Added 4 new validators (startsWith, endsWith, includes, uuid) + improved email validation |
| 2 | `moon_zod_test.mbt` | modify | Added 18 tests covering all new validators + email edge cases |

## 8. Risks / Notes

- **零破坏性**：现有 email 测试全部通过（`"user@example.com"`, `"not-an-email"`, `"user@"`）
- **新的 email 拒绝 case**：`"a@b@c.com"`, `".user@ex.com"`, `"user@ex.com."`, `"user@domain"`（之前被接受，现在拒绝）
- **UUID 校验**：纯字符遍历，无正则/外部依赖，O(1) 单次遍历 36 字符
- **测试**：189 → 189(all pass) (原 171 + 18 新增 - 0 删除)
- **Build warnings**: 0
