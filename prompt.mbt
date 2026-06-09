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
    let comment = schema_comment(val_schema)
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
  let inner = constraint_comment(unwrapped.rules, unwrapped.schema_type)
  let merged = match unwrapped.schema_type {
    ArrayType(elem) => {
      let euw = unwrap_schema(elem)
      let ec = constraint_comment(euw.rules, euw.schema_type)
      if inner.is_empty() {
        ec
      } else if ec.is_empty() {
        inner
      } else {
        inner + ", " + ec
      }
    }
    _ => inner
  }
  let constraint_part = if merged.is_empty() {
    ""
  } else {
    "[" + merged + "]"
  }
  let desc = schema.description
  if constraint_part.is_empty() && desc.is_empty() {
    ""
  } else if constraint_part.is_empty() {
    desc
  } else if desc.is_empty() {
    constraint_part
  } else {
    constraint_part + " — " + desc
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
