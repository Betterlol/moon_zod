///|
/// Convert a JSON Schema (draft-07) document into a moon_zod schema expression.
/// Outputs MoonBit source code that can be copy-pasted into moon_zod projects.
///
/// # Example
/// ```mbt nocheck
/// let schema = @json.parse("{\"type\":\"string\"}").unwrap()
///
/// let code = json_schema_to_moon_zod(schema)
/// // "@moon_zod.string()"
/// ```
pub fn json_schema_to_moon_zod(schema : Json) -> String {
  let defs = extract_defs(schema)
  let mut result = ""

  // Collect $defs names in insertion order
  let names : Array[String] = []
  for name, _ in defs {
    names.push(name)
  }

  // Generate let declarations for each $defs entry
  for name in names {
    match defs.get(name) {
      Some(def) => {
        if !result.is_empty() {
          result = result + "\n\n"
        }
        let code = schema_to_code(def, defs, 0)
        result = result +
          "let " +
          escape_ident(name) +
          "_schema = " +
          code +
          ".name(\"" +
          escape_mbt_string(name) +
          "\")"
      }
      None => ()
    }
  }
  if !result.is_empty() {
    result = result + "\n\n"
  }

  // Generate root schema code
  let root = schema_to_code(schema, defs, 0)
  result + root
}

///|
fn extract_defs(schema : Json) -> Map[String, Json] {
  match schema {
    Object(m) => {
      match m.get("$defs") {
        Some(Object(d)) => return d
        _ => ()
      }
      match m.get("definitions") {
        Some(Object(d)) => return d
        _ => ()
      }
      {}
    }
    _ => {}
  }
}

///|
fn schema_to_code(
  schema : Json,
  defs : Map[String, Json],
  indent : Int,
) -> String {
  match schema {
    Object(m) => {
      // 1. Check $ref
      match m.get("$ref") {
        Some(String(ref_str)) => return ref_to_code(ref_str, defs)
        _ => ()
      }

      // 2. Check enum
      match m.get("enum") {
        Some(Array(values)) => return enum_to_code(values)
        _ => ()
      }

      // 3. Type-based schema
      let has_type = m.contains("type")
      if has_type {
        let base = match m.get("type") {
          Some(String("object")) =>
            match m.get("properties") {
              Some(Object(props)) =>
                object_to_code(props, m.get("required"), defs, indent)
              _ => "@moon_zod.object({})"
            }
          Some(String("array")) => {
            let items_code = match m.get("items") {
              Some(items) => schema_to_code(items, defs, indent + 1)
              None => "@moon_zod.string()  /* TODO: specify items type */"
            }
            "@moon_zod.array(" + items_code + ")"
          }
          Some(String("string")) => "@moon_zod.string()"
          Some(String("number")) => "@moon_zod.number()"
          Some(String("integer")) => "@moon_zod.number().int()"
          Some(String("boolean")) => "@moon_zod.boolean()"
          Some(String("null")) => "@moon_zod.null()"
          _ => "@moon_zod.string()  /* TODO: unknown type */"
        }
        apply_constraints_to_code(base, m)
      } else {
        // 4. Try anyOf / allOf / oneOf
        match m.get("anyOf") {
          Some(Array(schemas)) => {
            let parts = schemas.map(fn(s) { schema_to_code(s, defs, indent) })
            "@moon_zod.union([" + join_with(parts, ", ") + "])"
          }
          _ =>
            match m.get("allOf") {
              Some(Array(schemas)) => {
                let parts = schemas.map(fn(s) {
                  schema_to_code(s, defs, indent)
                })
                "@moon_zod.intersection([" + join_with(parts, ", ") + "])"
              }
              _ =>
                match m.get("oneOf") {
                  Some(Array(schemas)) => {
                    let parts = schemas.map(fn(s) {
                      schema_to_code(s, defs, indent)
                    })
                    "@moon_zod.union([" + join_with(parts, ", ") + "])"
                  }
                  _ => "@moon_zod.string()  /* TODO: unknown schema type */"
                }
            }
        }
      }
    }
    _ => "@moon_zod.string()  /* TODO: expected object schema */"
  }
}

///|
fn ref_to_code(ref_str : String, defs : Map[String, Json]) -> String {
  let name = parse_ref_name(ref_str)
  if defs.contains(name) {
    escape_ident(name) + "_schema"
  } else {
    "@moon_zod.string()  /* TODO: unresolved $ref: " + ref_str + " */"
  }
}

///|
fn parse_ref_name(ref_str : String) -> String {
  // Handle "#/$defs/Name" or "#/definitions/Name"
  let mut last = ""
  for c in ref_str.to_array() {
    if c == '/' {
      last = ""
    } else {
      last = last + c.to_string()
    }
  }
  if last.is_empty() {
    ref_str
  } else {
    last
  }
}

///|
fn enum_to_code(values : Array[Json]) -> String {
  let string_values : Array[String] = []
  for v in values {
    match v {
      String(s) => string_values.push(s)
      _ => ()
    }
  }
  let parts : Array[String] = []
  for s in string_values {
    parts.push("\"" + escape_mbt_string(s) + "\"")
  }
  "@moon_zod.enum_values([" + join_with(parts, ", ") + "])"
}

///|
fn object_to_code(
  props : Map[String, Json],
  required_opt : Json?,
  defs : Map[String, Json],
  indent : Int,
) -> String {
  // Build required set
  let required_set : Map[String, Bool] = {}
  match required_opt {
    Some(Array(reqs)) =>
      for r in reqs {
        match r {
          String(s) => required_set.set(s, true)
          _ => ()
        }
      }
    _ => ()
  }

  if props.length() == 0 {
    return "@moon_zod.object({})"
  }

  let key_names : Array[String] = []
  for key, _ in props {
    key_names.push(key)
  }

  let mut result = "@moon_zod.object({\n"
  for i = 0; i < key_names.length(); i = i + 1 {
    if i > 0 {
      result = result + ",\n"
    }
    let key = key_names[i]
    match props.get(key) {
      Some(field_schema) => {
        let mut field_code = schema_to_code(field_schema, defs, indent + 1)
        if !required_set.contains(key) {
          field_code = field_code + ".optional()"
        }
        result = result +
          pad(indent + 1) +
          "\"" +
          escape_mbt_string(key) +
          "\": " +
          field_code
      }
      None => ()
    }
  }
  result + ",\n" + pad(indent) + "})"
}

///|
fn apply_constraints_to_code(base : String, m : Map[String, Json]) -> String {
  let mut result = base

  // String constraints
  match m.get("minLength") {
    Some(Number(v, ..)) =>
      result = result + ".min(" + format_double_simple(v) + ")"
    _ => ()
  }
  match m.get("maxLength") {
    Some(Number(v, ..)) =>
      result = result + ".max(" + format_double_simple(v) + ")"
    _ => ()
  }
  match m.get("pattern") {
    Some(String(p)) =>
      result = result + ".regex(\"" + escape_mbt_string(p) + "\")"
    _ => ()
  }
  match m.get("format") {
    Some(String("email")) => result = result + ".email()"
    Some(String("uri")) => result = result + ".url()"
    Some(String("date-time")) => result = result + ".datetime()"
    Some(String("ipv4")) => result = result + ".ipv4()"
    Some(String("ipv6")) => result = result + ".ipv6()"
    Some(String("uuid")) => result = result + ".uuid()"
    _ => ()
  }

  // Number constraints
  match m.get("minimum") {
    Some(Number(v, ..)) =>
      result = result + ".min(" + format_double_simple(v) + ")"
    _ => ()
  }
  match m.get("maximum") {
    Some(Number(v, ..)) =>
      result = result + ".max(" + format_double_simple(v) + ")"
    _ => ()
  }
  match m.get("exclusiveMinimum") {
    Some(Number(v, ..)) =>
      if v == 0.0 {
        result = result + ".positive()"
      } else {
        result = result + ".min(" + format_double_simple(v) + ")"
      }
    _ => ()
  }
  match m.get("exclusiveMaximum") {
    Some(Number(v, ..)) =>
      if v == 0.0 {
        result = result + ".negative()"
      } else {
        result = result + ".max(" + format_double_simple(v) + ")"
      }
    _ => ()
  }
  match m.get("multipleOf") {
    Some(Number(v, ..)) =>
      result = result + ".multipleOf(" + format_double_simple(v) + ")"
    _ => ()
  }

  // Array constraints
  match m.get("minItems") {
    Some(Number(v, ..)) =>
      result = result + ".min(" + format_double_simple(v) + ")"
    _ => ()
  }
  match m.get("maxItems") {
    Some(Number(v, ..)) =>
      result = result + ".max(" + format_double_simple(v) + ")"
    _ => ()
  }

  // Default value
  match m.get("default") {
    Some(val) => result = result + ".default(" + json_to_literal(val) + ")"
    _ => ()
  }

  result
}

///|
/// Convert a Json value into a MoonBit literal expression.
fn json_to_literal(val : Json) -> String {
  match val {
    String(s) => "@moon_zod.string().default(\"" + escape_mbt_string(s) + "\")"
    Number(v, ..) =>
      "@moon_zod.number().default(" + format_double_simple(v) + ")"
    True => "@moon_zod.boolean().default(true)"
    False => "@moon_zod.boolean().default(false)"
    Null => "@moon_zod.null()"
    Array(arr) => {
      let parts = arr.map(fn(v) { json_to_literal(v) })
      "@moon_zod.array(" + join_with(parts, ", ") + ")"
    }
    Object(map) => {
      let parts : Array[String] = []
      for k, v in map {
        let lit = json_to_literal(v)
        parts.push("\"" + escape_mbt_string(k) + "\": " + lit)
      }
      "@moon_zod.object({" + join_with(parts, ", ") + "})"
    }
  }
}

///|
/// Escape special characters for MoonBit string literals.
fn escape_mbt_string(s : String) -> String {
  let mut result = ""
  for c in s.to_array() {
    if c == '\\' {
      result = result + "\\\\"
    } else if c == '"' {
      result = result + "\\\""
    } else if c == '\n' {
      result = result + "\\n"
    } else if c == '\t' {
      result = result + "\\t"
    } else {
      result = result + c.to_string()
    }
  }
  result
}

///|
/// Ensure a name is a valid MoonBit identifier.
fn escape_ident(name : String) -> String {
  let arr = name.to_array()
  let mut result = ""
  for i = 0; i < arr.length(); i = i + 1 {
    let c = arr[i]
    if (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '_' {
      result = result + c.to_string()
    } else {
      result = result + "_"
    }
  }
  // Ensure not starting with digit
  if result.length() > 0 && result[0] >= '0' && result[0] <= '9' {
    result = "_" + result
  }
  result
}

///|
fn join_with(parts : Array[String], sep : String) -> String {
  if parts.is_empty() {
    return ""
  }
  let mut result = parts[0]
  for i = 1; i < parts.length(); i = i + 1 {
    result = result + sep + parts[i]
  }
  result
}

///|
/// Generate n * 2 spaces for indentation.
fn pad(level : Int) -> String {
  let mut spaces = ""
  for i = 0; i < level * 2; i = i + 1 {
    spaces = spaces + " "
  }
  spaces
}
