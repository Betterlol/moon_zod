# Stage Summary

## 1. Stage Description

Add `schema_to_prompt()` function that converts a moon_zod Schema into a TypeScript-interface-style human/LLM-readable prompt string. This completes the LLM Tool Calling workflow alongside existing `to_json_schema()` (machine format) and `ValidationError::to_string()` (error feedback).

## 2. Stage Metadata
- STAGE_ID: schema-to-prompt
- STAGE_TYPE: feat
- BASE_COMMIT: fe4234216f93b83973e197676d1efdd17767c44e

## 3. New Files

### prompt.mbt

///|
/// Convert a moon_zod Schema into a TypeScript-interface-style prompt string
/// suitable for LLM system prompts or correction feedback.
///
/// # Example
/// ```mbt nocheck
/// let s = object({
///   "name": string().min(2).max(50),
///   "age": number().int().min(0).max(150),
/// })
///
/// let prompt = schema_to_prompt(s)
/// // {
/// //   name: string,   // 2-50 chars
/// //   age: number,    // int, 0-150
/// // }
/// ```
pub fn schema_to_prompt(schema : Schema) -> String {
  let tp = type_to_prompt(schema, 0)
  let comment = schema_comment(schema)
  if comment.is_empty() {
    tp
  } else {
    tp + "  // " + comment
  }
}

///|
/// Recursively render the TypeScript type string (no comment).
fn type_to_prompt(schema : Schema, indent : Int) -> String {
  match schema.schema_type {
    StringType => "string"
    NumberType => "number"
    BooleanType => "boolean"
    NullType => "null"
    OptionalType(inner) => type_to_prompt(inner, indent) + " | null"
    DefaultType(inner, _) => type_to_prompt(inner, indent) + " | null"
    TransformType(inner, _) => type_to_prompt(inner, indent)
    EnumType(values) => enum_to_prompt(values)
    ArrayType(elem) => type_to_prompt(elem, indent) + "[]"
    UnionType(schemas) => union_to_prompt(schemas, indent)
    ObjectType(spec, _) => object_to_prompt(spec, indent)
  }
}

///|
/// Render an enum as "a" | "b" | "c".
fn enum_to_prompt(values : Array[String]) -> String {
  let mut result = ""
  let mut first = true
  for v in values {
    if first {
      result = "\"" + v + "\""
    } else {
      result = result + " | \"" + v + "\""
    }
    first = false
  }
  result
}

///|
/// Render a union as type1 | type2 | ...
fn union_to_prompt(schemas : Array[Schema], indent : Int) -> String {
  let mut result = ""
  let mut first = true
  for s in schemas {
    if first {
      result = type_to_prompt(s, indent)
    } else {
      result = result + " | " + type_to_prompt(s, indent)
    }
    first = false
  }
  result
}

///|
/// Render an object as multiline { ... } with 2-space indentation.
fn object_to_prompt(spec : Map[String, Schema], indent : Int) -> String {
  if spec.length() == 0 {
    return "{}"
  }
  let mut result = "{\n"
  let inner_indent = indent + 1
  for key, val_schema in spec {
    let key_is_optional = is_optional_schema(val_schema)
    let inner = if key_is_optional {
      match val_schema.schema_type {
        OptionalType(s) => s
        DefaultType(s, _) => s
        _ => val_schema
      }
    } else {
      val_schema
    }

    let field_type = type_to_prompt(inner, inner_indent)
    let comment = schema_comment(inner)
    let opt_mark = if key_is_optional { "?" } else { "" }
    let line = indent_str(inner_indent) + key + opt_mark + ": " + field_type

    if comment.is_empty() {
      result = result + line + ",\n"
    } else {
      result = result + line + ",  // " + comment + "\n"
    }
  }
  result = result + indent_str(indent) + "}"
  result
}

///|
/// Generate n * 2 spaces.
fn indent_str(n : Int) -> String {
  let mut s = ""
  for i = 0; i < n; i = i + 1 {
    s = s + "  "
  }
  s
}

///|
/// Peel OptionalType / DefaultType / TransformType wrappers to find the
/// innermost schema that carries the actual rules.
fn unwrap_schema(schema : Schema) -> Schema {
  match schema.schema_type {
    OptionalType(inner) => unwrap_schema(inner)
    DefaultType(inner, _) => unwrap_schema(inner)
    TransformType(inner, _) => unwrap_schema(inner)
    _ => schema
  }
}

///|
/// Build the constraint comment for a schema.
/// For arrays, also merges element-level constraints.
fn schema_comment(schema : Schema) -> String {
  let unwrapped = unwrap_schema(schema)
  let comment = constraint_comment(unwrapped.rules, unwrapped.schema_type)
  match unwrapped.schema_type {
    ArrayType(elem) => {
      let euw = unwrap_schema(elem)
      let ec = constraint_comment(euw.rules, euw.schema_type)
      if comment.is_empty() {
        ec
      } else if ec.is_empty() {
        comment
      } else {
        comment + ", " + ec
      }
    }
    _ => comment
  }
}

///|
/// Join constraint parts with ", ".
fn join_parts(parts : Array[String]) -> String {
  let mut result = parts[0]
  for i = 1; i < parts.length(); i = i + 1 {
    result = result + ", " + parts[i]
  }
  result
}

///|
/// Format a Double as a string, stripping ".0" for whole numbers.
fn format_double_simple(v : Double) -> String {
  if v == v.to_int().to_double() {
    v.to_int().to_string()
  } else {
    v.to_string()
  }
}

///|
fn string_constraint_comment(rules : Array[Rule]) -> String {
  let mut min_len = -1.0
  let mut max_len = -1.0
  let mut format_val = ""
  let mut pattern = ""
  let parts : Array[String] = []
  for rule in rules {
    match rule.annotation {
      Object(map) => {
        if map.contains("minLength") {
          match map.get("minLength") {
            Some(Number(v, ..)) => min_len = v
            _ => ()
          }
        }
        if map.contains("maxLength") {
          match map.get("maxLength") {
            Some(Number(v, ..)) => max_len = v
            _ => ()
          }
        }
        if map.contains("format") {
          match map.get("format") {
            Some(String(s)) => format_val = s
            _ => ()
          }
        }
        if map.contains("pattern") {
          match map.get("pattern") {
            Some(String(s)) => pattern = s
            _ => ()
          }
        }
      }
      _ => ()
    }
    match rule.annotation {
      Null =>
        if rule.message != "String must not be empty" {
          parts.push(rule.message)
        }
      _ => ()
    }
  }
  if min_len >= 0.0 && max_len >= 0.0 {
    parts.push(
      format_double_simple(min_len) +
      "-" +
      format_double_simple(max_len) +
      " chars",
    )
  } else if min_len >= 0.0 {
    parts.push("min: " + format_double_simple(min_len))
  } else if max_len >= 0.0 {
    parts.push("max: " + format_double_simple(max_len))
  }
  if format_val == "email" {
    parts.push("email")
  } else if format_val == "uri" {
    parts.push("url")
  } else if !format_val.is_empty() {
    parts.push(format_val)
  }
  if !pattern.is_empty() {
    parts.push("pattern: " + pattern)
  }
  if parts.is_empty() {
    ""
  } else {
    join_parts(parts)
  }
}

///|
fn number_constraint_comment(rules : Array[Rule]) -> String {
  let mut is_int = false
  let mut is_positive = false
  let mut is_negative = false
  let mut has_min = false
  let mut has_max = false
  let mut minimum = 0.0
  let mut maximum = 0.0
  let mut has_multiple = false
  let mut multiple_of = 0.0
  let parts : Array[String] = []
  for rule in rules {
    match rule.annotation {
      Object(map) => {
        if map.contains("type") {
          match map.get("type") {
            Some(String(s)) => if s == "integer" { is_int = true }
            _ => ()
          }
        }
        if map.contains("exclusiveMinimum") {
          match map.get("exclusiveMinimum") {
            Some(Number(v, ..)) => if v == 0.0 { is_positive = true }
            _ => ()
          }
        }
        if map.contains("exclusiveMaximum") {
          match map.get("exclusiveMaximum") {
            Some(Number(v, ..)) => if v == 0.0 { is_negative = true }
            _ => ()
          }
        }
        if map.contains("minimum") {
          match map.get("minimum") {
            Some(Number(v, ..)) => {
              has_min = true
              minimum = v
            }
            _ => ()
          }
        }
        if map.contains("maximum") {
          match map.get("maximum") {
            Some(Number(v, ..)) => {
              has_max = true
              maximum = v
            }
            _ => ()
          }
        }
        if map.contains("multipleOf") {
          match map.get("multipleOf") {
            Some(Number(v, ..)) => {
              has_multiple = true
              multiple_of = v
            }
            _ => ()
          }
        }
      }
      _ => ()
    }
    match rule.annotation {
      Null => parts.push(rule.message)
      _ => ()
    }
  }
  if is_int {
    parts.push("int")
  }
  if is_positive {
    parts.push("positive")
  }
  if is_negative {
    parts.push("negative")
  }
  if has_min && has_max {
    parts.push(
      format_double_simple(minimum) + "-" + format_double_simple(maximum),
    )
  } else if has_min {
    parts.push("min: " + format_double_simple(minimum))
  } else if has_max {
    parts.push("max: " + format_double_simple(maximum))
  }
  if has_multiple {
    parts.push("multiple of " + format_double_simple(multiple_of))
  }
  if parts.is_empty() {
    ""
  } else {
    join_parts(parts)
  }
}

///|
fn array_constraint_comment(rules : Array[Rule]) -> String {
  let mut min_items = -1.0
  let mut max_items = -1.0
  let parts : Array[String] = []
  for rule in rules {
    match rule.annotation {
      Object(map) => {
        if map.contains("minItems") {
          match map.get("minItems") {
            Some(Number(v, ..)) => min_items = v
            _ => ()
          }
        }
        if map.contains("maxItems") {
          match map.get("maxItems") {
            Some(Number(v, ..)) => max_items = v
            _ => ()
          }
        }
      }
      _ => ()
    }
    match rule.annotation {
      Null => parts.push(rule.message)
      _ => ()
    }
  }
  if min_items >= 0.0 {
    parts.push("min: " + format_double_simple(min_items) + " items")
  }
  if max_items >= 0.0 {
    parts.push("max: " + format_double_simple(max_items) + " items")
  }
  if parts.is_empty() {
    ""
  } else {
    join_parts(parts)
  }
}

///|
fn fallback_constraint_comment(rules : Array[Rule]) -> String {
  let parts : Array[String] = []
  for rule in rules {
    match rule.annotation {
      Null => parts.push(rule.message)
      _ => ()
    }
  }
  if parts.is_empty() {
    ""
  } else {
    join_parts(parts)
  }
}

///|
fn constraint_comment(rules : Array[Rule], base_type : SchemaType) -> String {
  match base_type {
    StringType => string_constraint_comment(rules)
    NumberType => number_constraint_comment(rules)
    ArrayType(_) => array_constraint_comment(rules)
    _ => fallback_constraint_comment(rules)
  }
}

## 4. Modified Files

### moon_zod_test.mbt

diff --git a/moon_zod_test.mbt b/moon_zod_test.mbt
index 20df7f9..c12c0de 100644
--- a/moon_zod_test.mbt
+++ b/moon_zod_test.mbt
@@ -884,3 +884,206 @@ test "to_json_schema ignores transform wrapper" {
   let expected = parse_json("{\"type\": \"string\"}")
   @debug.assert_eq(result, expected)
 }
+
+///|
+/// Phase 16 — schema_to_prompt TypeScript interface generation
+test "schema_to_prompt leaf types" {
+  @debug.assert_eq(schema_to_prompt(string()), "string")
+  @debug.assert_eq(schema_to_prompt(number()), "number")
+  @debug.assert_eq(schema_to_prompt(boolean()), "boolean")
+  @debug.assert_eq(schema_to_prompt(null()), "null")
+}
+
+///|
+test "schema_to_prompt optional and default" {
+  @debug.assert_eq(schema_to_prompt(string().optional()), "string | null")
+  @debug.assert_eq(
+    schema_to_prompt(string().default(Json::string("x"))),
+    "string | null",
+  )
+}
+
+///|
+test "schema_to_prompt string constraints" {
+  @debug.assert_eq(
+    schema_to_prompt(string().min(2).max(50)),
+    "string  // 2-50 chars",
+  )
+  @debug.assert_eq(schema_to_prompt(string().min(3)), "string  // min: 3")
+  @debug.assert_eq(schema_to_prompt(string().max(100)), "string  // max: 100")
+  @debug.assert_eq(schema_to_prompt(string().email()), "string  // email")
+  @debug.assert_eq(schema_to_prompt(string().url()), "string  // url")
+  @debug.assert_eq(
+    schema_to_prompt(string().regex("hello")),
+    "string  // pattern: hello",
+  )
+}
+
+///|
+test "schema_to_prompt number constraints" {
+  @debug.assert_eq(schema_to_prompt(number().int()), "number  // int")
+  @debug.assert_eq(schema_to_prompt(number().positive()), "number  // positive")
+  @debug.assert_eq(schema_to_prompt(number().negative()), "number  // negative")
+  @debug.assert_eq(
+    schema_to_prompt(number().int().min(0).max(150)),
+    "number  // int, 0-150",
+  )
+  @debug.assert_eq(schema_to_prompt(number().min(10)), "number  // min: 10")
+  @debug.assert_eq(schema_to_prompt(number().max(100)), "number  // max: 100")
+  @debug.assert_eq(
+    schema_to_prompt(number().multipleOf(5)),
+    "number  // multiple of 5",
+  )
+}
+
+///|
+test "schema_to_prompt enum" {
+  @debug.assert_eq(
+    schema_to_prompt(enum_values(["admin", "user", "viewer"])),
+    "\"admin\" | \"user\" | \"viewer\"",
+  )
+  @debug.assert_eq(schema_to_prompt(enum_values(["a"])), "\"a\"")
+}
+
+///|
+test "schema_to_prompt array" {
+  @debug.assert_eq(schema_to_prompt(array(string())), "string[]")
+  @debug.assert_eq(
+    schema_to_prompt(array(string()).min(2)),
+    "string[]  // min: 2 items",
+  )
+  @debug.assert_eq(
+    schema_to_prompt(array(string()).max(5)),
+    "string[]  // max: 5 items",
+  )
+  @debug.assert_eq(
+    schema_to_prompt(array(string()).min(1).max(10)),
+    "string[]  // min: 1 items, max: 10 items",
+  )
+  @debug.assert_eq(
+    schema_to_prompt(array(string().email())),
+    "string[]  // email",
+  )
+}
+
+///|
+test "schema_to_prompt union" {
+  @debug.assert_eq(
+    schema_to_prompt(union([string(), number()])),
+    "string | number",
+  )
+  @debug.assert_eq(
+    schema_to_prompt(union([string(), number(), boolean()])),
+    "string | number | boolean",
+  )
+}
+
+///|
+test "schema_to_prompt optional with constraints" {
+  @debug.assert_eq(
+    schema_to_prompt(string().min(3).optional()),
+    "string | null  // min: 3",
+  )
+  @debug.assert_eq(
+    schema_to_prompt(number().int().optional()),
+    "number | null  // int",
+  )
+}
+
+///|
+test "schema_to_prompt transform transparent" {
+  let s = string().transform(fn(json) { Ok(json) })
+  @debug.assert_eq(schema_to_prompt(s), "string")
+  let s2 = number().int().transform(fn(j) { Ok(j) })
+  @debug.assert_eq(schema_to_prompt(s2), "number  // int")
+}
+
+///|
+test "schema_to_prompt empty object" {
+  @debug.assert_eq(schema_to_prompt(object({})), "{}")
+}
+
+///|
+test "schema_to_prompt simple object" {
+  let s = object({
+    "name": string().min(2).max(50),
+    "age": number().int().min(0).max(150),
+  })
+  let expected = "{\n" +
+    "  name: string,  // 2-50 chars\n" +
+    "  age: number,  // int, 0-150\n" +
+    "}"
+  @debug.assert_eq(schema_to_prompt(s), expected)
+}
+
+///|
+test "schema_to_prompt object with optional fields" {
+  let s = object({
+    "name": string(),
+    "email": string().email().optional(),
+    "role": enum_values(["admin", "user"]),
+  })
+  let expected = "{\n" +
+    "  name: string,\n" +
+    "  email?: string,  // email\n" +
+    "  role: \"admin\" | \"user\",\n" +
+    "}"
+  @debug.assert_eq(schema_to_prompt(s), expected)
+}
+
+///|
+test "schema_to_prompt nested object" {
+  let s = object({
+    "profile": object({
+      "age": number().int().min(0).max(150),
+      "tags": array(string().min(1)),
+    }),
+  })
+  let expected = "{\n" +
+    "  profile: {\n" +
+    "    age: number,  // int, 0-150\n" +
+    "    tags: string[],  // min: 1\n" +
+    "  },\n" +
+    "}"
+  @debug.assert_eq(schema_to_prompt(s), expected)
+}
+
+///|
+test "schema_to_prompt nested optional object" {
+  let s = object({
+    "metadata": object({ "level": number().int().min(1).max(10) }).optional(),
+  })
+  let expected = "{\n" +
+    "  metadata?: {\n" +
+    "    level: number,  // int, 1-10\n" +
+    "  },\n" +
+    "}"
+  @debug.assert_eq(schema_to_prompt(s), expected)
+}
+
+///|
+test "schema_to_prompt refine custom message" {
+  let s = number().refine(
+    fn(json) {
+      match json {
+        Number(v, ..) => v > 10.0
+        _ => false
+      }
+    },
+    "Value must be > 10",
+  )
+  @debug.assert_eq(schema_to_prompt(s), "number  // Value must be > 10")
+}
+
+///|
+test "schema_to_prompt nonempty is filtered" {
+  // nonempty has no annotation and its message matches the built-in
+  let s = string().nonempty()
+  @debug.assert_eq(schema_to_prompt(s), "string")
+}
+
+///|
+test "schema_to_prompt default with constraints" {
+  let s = string().min(3).default(Json::string("abc"))
+  @debug.assert_eq(schema_to_prompt(s), "string | null  // min: 3")
+}

### pkg.generated.mbti

diff --git a/pkg.generated.mbti b/pkg.generated.mbti
index c92f224..a0c802c 100644
--- a/pkg.generated.mbti
+++ b/pkg.generated.mbti
@@ -24,6 +24,8 @@ pub fn number() -> Schema
 
 pub fn object(Map[String, Schema]) -> Schema
 
+pub fn schema_to_prompt(Schema) -> String
+
 pub fn string() -> Schema
 
 pub fn sub_index(String, Int) -> String

## 5. Deleted Files

None.

## 6. ACTION_LOG

| Action | File | Reason |
|--------|------|--------|
| create | `prompt.mbt` | New file: `schema_to_prompt()` public entry + 12 internal helpers (`type_to_prompt`, `object_to_prompt`, `enum_to_prompt`, `union_to_prompt`, `indent_str`, `unwrap_schema`, `schema_comment`, `constraint_comment`, `string_constraint_comment`, `number_constraint_comment`, `array_constraint_comment`, `fallback_constraint_comment`, `join_parts`, `format_double_simple`) |
| modify | `moon_zod_test.mbt` | 17 new black-box tests covering: leaf types, optional/default, string constraints (min/max/email/url/regex), number constraints (int/positive/negative/multipleOf/min+max), enum, array (with constraints + element constraints), union, optional-with-constraints, transform transparent, empty object, simple object, optional fields, nested object, nested optional object, refine custom message, nonempty filtered, default with constraints |
| modify | `pkg.generated.mbti` | Auto-generated by `moon info` — exports `pub fn schema_to_prompt(Schema) -> String` |

## 7. Risks / Notes

- `schema_to_prompt` outputs inline TypeScript interface format with `//` constraint comments, complementing `to_json_schema()` (machine format).
- Array element constraints are merged into the array's comment line for simple element types (e.g., `string[]  // email`).
- `nonempty()` message is filtered from constraints (no annotation, matches built-in string exactly).
- `TransformType` is transparent — renders as the inner type without wrapper.
- Object fields are always rendered with trailing commas for TypeScript convention.
- All constraint annotations use the existing `Rule.annotation` JSON system (Phase 15), no new annotation mechanism needed.
- Test count: 112 (95 existing + 17 new). All pass, 0 warnings.
