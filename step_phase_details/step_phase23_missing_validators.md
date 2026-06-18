# Stage Summary

## 1. Stage Description

补全缺失验证器：实现 `cuid`、`datetime`、`ipv4`/`ipv6`/`ip`、`length`、`ulid` 五个字符串验证器和 `finite`、`safe` 两个数字验证器，填补与 Zod/Pydantic 的功能差距。

## 2. Stage Metadata
- STAGE_ID: phase-23
- STAGE_TYPE: feature
- BASE_COMMIT: 0d40d56dfedacc8d8d926fa8fdc84312e7902b48

## 3. New Files
None (all changes are modifications)

## 5. Modified Files

| File | Action | Description |
|---|---|---|
| `string.mbt` | modify | 新增 `cuid`/`datetime`/`ip`/`ipv4`/`ipv6`/`length`/`ulid` 七个方法 + 辅助函数 |
| `number.mbt` | modify | 新增 `finite`/`safe` 两个方法 |
| `test_string.mbt` | modify | 32 个新测试覆盖所有字符串验证器 |
| `test_number.mbt` | modify | 9 个新测试覆盖所有数字验证器 |
| `test_array.mbt` | modify | 4 个新测试覆盖 `length()` 数组行为 |

## 6. Modified File Diffs

### string.mbt (425 lines added)

```diff
diff --git a/string.mbt b/string.mbt
index 9cd5fa9..3ab02aa 100644
--- a/string.mbt
+++ b/string.mbt
@@ -404,3 +404,428 @@ pub fn Schema::uuid(self : Schema, msg? : String = "") -> Schema {
     Json::object({ "format": Json::string("uuid") }),
   )
 }
+
+///|
+/// Require the string to be a valid CUID (25 chars, starts with 'c', alphanumeric).
+pub fn Schema::cuid(self : Schema, msg? : String = "") -> Schema {
+  match inner_type(self.schema_type) {
+    StringType => ()
+    _ => abort("cuid() is only valid for string schemas")
+  }
+  let message = if msg.is_empty() { "String must be a valid CUID" } else { msg }
+  append_rule_with_annotation(
+    self, fn(json) {
+      match json {
+        String(s) => {
+          let chars = s.to_array()
+          if chars.length() != 25 { return false }
+          if chars[0] != 'c' { return false }
+          for i = 1; i < 25; i = i + 1 {
+            let c = chars[i]
+            if !((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')) { return false }
+          }
+          true
+        }
+        _ => false
+      }
+    },
+    message,
+    Json::object({ "format": Json::string("cuid") }),
+  )
+}
+
+///|
+fn is_leap_year(year : Int) -> Bool {
+  year % 400 == 0 || (year % 4 == 0 && year % 100 != 0)
+}
+
+///|
+fn is_valid_iso8601(s : String) -> Bool { ... }
+
+///|
+pub fn Schema::datetime(self : Schema, msg? : String = "") -> Schema { ... }
+
+///|
+fn is_valid_ipv4(s : String) -> Bool { ... }
+fn is_valid_ipv6(s : String) -> Bool { ... }
+
+///|
+pub fn Schema::ipv4(self : Schema, msg? : String = "") -> Schema { ... }
+pub fn Schema::ipv6(self : Schema, msg? : String = "") -> Schema { ... }
+pub fn Schema::ip(self : Schema, msg? : String = "") -> Schema { ... }
+
+///|
+fn schema_length_check(s : Schema, n : Int) -> (Json) -> Bool { ... }
+fn schema_length_msg(s : Schema, n : Int) -> String { ... }
+pub fn Schema::length(self : Schema, n : Int, msg? : String = "") -> Schema { ... }
+
+///|
+fn is_crockford_base32(c : Char) -> Bool { ... }
+pub fn Schema::ulid(self : Schema, msg? : String = "") -> Schema { ... }
```

### number.mbt (51 lines added)

```diff
diff --git a/number.mbt b/number.mbt
index c8c40c5..68d93b5 100644
--- a/number.mbt
+++ b/number.mbt
@@ -92,3 +92,54 @@ pub fn Schema::multipleOf(self : Schema, n : Int, msg? : String = "") -> Schema
     Json::object({ "multipleOf": Json::number(n.to_double()) }),
   )
 }
+
+///|
+pub fn Schema::finite(self : Schema, msg? : String = "") -> Schema {
+  // Uses !v.is_nan() && !v.is_inf() since Double has no is_finite()
+  ...
+}
+
+///|
+pub fn Schema::safe(self : Schema, msg? : String = "") -> Schema {
+  // Validates integer within ±9007199254740991
+  ...
+}
```

### test_string.mbt — 32 new tests
### test_number.mbt — 9 new tests
### test_array.mbt — 4 new tests

(Full diffs available via `git diff 0d40d56`)

## 8. ACTION_LOG

| Action | File | Reason |
|---|---|---|
| modify | `string.mbt` | Add cuid(), datetime(), ip()/ipv4()/ipv6(), length(), ulid() methods |
| modify | `number.mbt` | Add finite() (using !is_nan && !is_inf), safe() methods |
| modify | `test_string.mbt` | 32 tests covering string validators (4-6 each) |
| modify | `test_number.mbt` | 9 tests covering number validators |
| modify | `test_array.mbt` | 4 tests covering array length() |

## 9. Risks / Notes

- **Double API correction**: `Double` has no `is_finite()`, implemented as `!v.is_nan() && !v.is_inf()` instead
- **StringView issues**: `String.split()` returns `Iter[StringView]`, not `Array[String]`. All ip/datetime functions rewritten as char-by-char parsing to avoid this
- **`.substring()` deprecated**: Replaced with direct char-array slicing
- **Test count**: 206 → 251 (45 new, 100% pass)
- **No new files**: All changes in-place
