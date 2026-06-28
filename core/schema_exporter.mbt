///|
/// **Schema → moon_zod source code**
///
/// Convert Schema objects to moon_zod method chain source code.
/// This is the unified code generation layer used by multiple exporters.

///|
/// Generate moon_zod source code from a Schema object.
///
/// # Example
/// ```mbt nocheck
/// let schema = @moon_zod.string().min(3)
///
/// let code = schema_to_moon_zod_code(schema)
/// // "@moon_zod.string().min(3)"
/// ```
pub fn schema_to_moon_zod_code(schema : Schema) -> String {
  schema_to_moon_zod_code_with_refs(schema, [])
}

///|
/// Generate code with support for a set of defined named schemas.
/// When a schema's name is in defined_names, outputs reference instead of inline code.
pub fn schema_to_moon_zod_code_with_names(
  schema : Schema,
  defined_names : Array[String],
) -> String {
  schema_to_moon_zod_code_with_refs(schema, defined_names)
}

///|
/// Generate code with support for named schema references.
/// When a schema's name is in defined_names, outputs reference instead of inline code.
fn schema_to_moon_zod_code_with_refs(
  schema : Schema,
  defined_names : Array[String],
) -> String {
  // If this schema has a name and it's defined, use reference
  if !schema.name.is_empty() && value_in_array(schema.name, defined_names) {
    return escape_ident(schema.name) + "_schema"
  }

  let base = schema_type_to_code(schema.schema_type, defined_names)
  let mut result = apply_rules_to_code(base, schema)

  // If schema has a name but it's not in defined_names, append .named()
  if !schema.name.is_empty() && !value_in_array(schema.name, defined_names) {
    result = result + ".named('" + escape_mbt_string(schema.name) + "')"
  }

  result
}

///|
/// Generate base type constructor code.
fn schema_type_to_code(
  schema_type : SchemaType,
  defined_names : Array[String],
) -> String {
  match schema_type {
    StringType => "@moon_zod.string()"
    NumberType => "@moon_zod.number()"
    BooleanType => "@moon_zod.boolean()"
    NullType => "@moon_zod.null()"
    ObjectType(fields, _mode) => {
      if fields.length() == 0 {
        return "@moon_zod.object({})"
      }
      let parts : Array[String] = []
      for key, field_schema in fields {
        let field_code = schema_to_moon_zod_code_with_refs(
          field_schema, defined_names,
        )
        parts.push("\"" + escape_mbt_string(key) + "\": " + field_code)
      }
      "@moon_zod.object({ " + join_with(parts, ", ") + " })"
    }
    ArrayType(elem) => {
      let elem_code = schema_to_moon_zod_code_with_refs(elem, defined_names)
      "@moon_zod.array(" + elem_code + ")"
    }
    OptionalType(inner) =>
      schema_to_moon_zod_code_with_refs(inner, defined_names) + ".optional()"
    DefaultType(inner, default_val) =>
      schema_to_moon_zod_code_with_refs(inner, defined_names) +
      ".default(" +
      json_to_literal(default_val) +
      ")"
    EnumType(values) => {
      let parts : Array[String] = []
      for v in values {
        parts.push("\"" + escape_mbt_string(v) + "\"")
      }
      "@moon_zod.enum_values([" + join_with(parts, ", ") + "])"
    }
    UnionType(schemas) => {
      let parts : Array[String] = []
      for s in schemas {
        parts.push(schema_to_moon_zod_code_with_refs(s, defined_names))
      }
      "@moon_zod.union([" + join_with(parts, ", ") + "])"
    }
    IntersectionType(schemas) => {
      let parts : Array[String] = []
      for s in schemas {
        parts.push(schema_to_moon_zod_code_with_refs(s, defined_names))
      }
      "@moon_zod.intersection([" + join_with(parts, ", ") + "])"
    }
    LiteralType(val) => "@moon_zod.literal(" + json_to_literal(val) + ")"
    TransformType(inner, _) =>
      schema_to_moon_zod_code_with_refs(inner, defined_names) +
      ".transform(fn(x) { x })"
  }
}

///|
/// Apply rules as method chain.
fn apply_rules_to_code(base : String, schema : Schema) -> String {
  let mut result = base
  let mut has_int_type = false

  for rule in schema.rules {
    match rule.annotation {
      Object(map) => {
        if map.contains("type") {
          match map.get("type") {
            Some(String("integer")) => has_int_type = true
            _ => ()
          }
        }

        // String constraints
        if map.contains("minLength") {
          match map.get("minLength") {
            Some(Number(v, ..)) =>
              result = result + ".min(" + format_double_simple(v) + ")"
            _ => ()
          }
        }
        if map.contains("maxLength") {
          match map.get("maxLength") {
            Some(Number(v, ..)) =>
              result = result + ".max(" + format_double_simple(v) + ")"
            _ => ()
          }
        }
        if map.contains("pattern") {
          match map.get("pattern") {
            Some(String(p)) =>
              result = result + ".regex(\"" + escape_mbt_string(p) + "\")"
            _ => ()
          }
        }
        if map.contains("format") {
          match map.get("format") {
            Some(String("email")) => result = result + ".email()"
            Some(String("uri")) => result = result + ".url()"
            Some(String("date-time")) => result = result + ".datetime()"
            Some(String("ipv4")) => result = result + ".ipv4()"
            Some(String("ipv6")) => result = result + ".ipv6()"
            Some(String("uuid")) => result = result + ".uuid()"
            _ => ()
          }
        }

        // Number constraints
        if map.contains("minimum") {
          match map.get("minimum") {
            Some(Number(v, ..)) =>
              result = result + ".min(" + format_double_simple(v) + ")"
            _ => ()
          }
        }
        if map.contains("maximum") {
          match map.get("maximum") {
            Some(Number(v, ..)) =>
              result = result + ".max(" + format_double_simple(v) + ")"
            _ => ()
          }
        }
        if map.contains("exclusiveMinimum") {
          match map.get("exclusiveMinimum") {
            Some(Number(v, ..)) =>
              if v == 0.0 {
                result = result + ".positive()"
              } else {
                result = result + ".min(" + format_double_simple(v) + ")"
              }
            _ => ()
          }
        }
        if map.contains("exclusiveMaximum") {
          match map.get("exclusiveMaximum") {
            Some(Number(v, ..)) =>
              if v == 0.0 {
                result = result + ".negative()"
              } else {
                result = result + ".max(" + format_double_simple(v) + ")"
              }
            _ => ()
          }
        }
        if map.contains("multipleOf") {
          match map.get("multipleOf") {
            Some(Number(v, ..)) =>
              result = result + ".multipleOf(" + format_double_simple(v) + ")"
            _ => ()
          }
        }

        // Array constraints
        if map.contains("minItems") {
          match map.get("minItems") {
            Some(Number(v, ..)) =>
              result = result + ".min(" + format_double_simple(v) + ")"
            _ => ()
          }
        }
        if map.contains("maxItems") {
          match map.get("maxItems") {
            Some(Number(v, ..)) =>
              result = result + ".max(" + format_double_simple(v) + ")"
            _ => ()
          }
        }
      }
      _ => ()
    }
  }

  if has_int_type {
    result = result + ".int()"
  }

  result
}

///|
/// Convert a Json value to moon_zod literal expression.
fn json_to_literal(val : Json) -> String {
  match val {
    String(s) => "Json::string(\"" + escape_mbt_string(s) + "\")"
    Number(v, ..) => "Json::number(" + format_double_simple(v) + ")"
    True => "Json::true()"
    False => "Json::false()"
    Null => "Json::null()"
    Array(arr) => {
      let parts = arr.map(fn(v) { json_to_literal(v) })
      "Json::array([" + join_with(parts, ", ") + "])"
    }
    Object(map) => {
      let parts : Array[String] = []
      for k, v in map {
        let lit = json_to_literal(v)
        parts.push("\"" + escape_mbt_string(k) + "\": " + lit)
      }
      "Json::object({" + join_with(parts, ", ") + "})"
    }
  }
}

///|
pub fn escape_mbt_string(s : String) -> String {
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
pub fn escape_ident(name : String) -> String {
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
