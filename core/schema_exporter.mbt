///|
/// **Schema → moon_zod source code**
///
/// Convert Schema objects to moon_zod method chain source code.
/// Supports inline expansion and named schema references.

///|
/// Generate moon_zod source code from a Schema object (inline expansion).
///
/// # Example
/// ```mbt nocheck
/// let schema = @moon_zod.string().min(3).describe("username")
///
/// let code = schema_to_moon_zod_code(schema)
/// // "@moon_zod.string().min(3).describe(\"username\")"
/// ```
pub fn schema_to_moon_zod_code(schema : Schema) -> String {
  let schema_name = if schema.name.is_empty() { "Root" } else { schema.name }
  let code = schema_to_moon_zod_code_inline(schema, None)
  let result = "let " +
    escape_variable_name(schema_name) +
    " = " +
    code +
    ".name(" +
    escape_mbt_string(schema_name) +
    ")"
  result
}

///|
/// Generate code with optional support for named schema references.
///
/// If `include_names` is None, renders all schemas inline.
/// If `include_names` is Some(names), replaces references to named schemas with variable names.
///
/// For use with `schema_to_moon_zod_code_named()` which produces separate definitions.
pub fn schema_to_moon_zod_code_with_names(
  schema : Schema,
  include_names : Array[String]?,
) -> String {
  schema_to_moon_zod_code_inline(schema, include_names)
}

///|
/// Generate separate named schema definitions and return as newline-separated list.
///
/// # Example
/// ```
/// let named_list = schema_to_moon_zod_code_named(root_schema, None)
/// // Returns:
/// // "User: @moon_zod.object({ ... }).name(\"User\")\n
/// //  Profile: @moon_zod.object({ ... }).name(\"Profile\")"
/// ```
pub fn schema_to_moon_zod_code_named(
  schema : Schema,
  include_names? : Array[String]? = None,
) -> String {
  let mut schema = schema
  if schema.name.is_empty() {
    schema = schema.name("Root")
  }
  let all_named = collect_named_schemas(schema)
  let selected = filter_named_schemas(all_named, include_names)
  let sorted = topological_sort_schemas(selected)

  let defined_names = selected.map(fn(x) { x.name })
  let mut result = ""
  for s in sorted {
    if !s.name.is_empty() {
      let self_names = defined_names.filter(fn(n) { n != s.name })
      let code = schema_to_moon_zod_code_inline(s, Some(self_names))
      if !result.is_empty() {
        result = result + "\n"
      }
      let line = "let " +
        escape_variable_name(s.name) +
        " = " +
        code +
        ".name(\"" +
        escape_mbt_string(s.name) +
        "\")"
      result = result + line
    }
  }
  result
}

///|
/// Internal: Generate code with optional named schema reference support.
fn schema_to_moon_zod_code_inline(
  schema : Schema,
  include_names : Array[String]?,
) -> String {
  let defined_names = match include_names {
    None => []
    Some(names) => names
  }

  // If this schema has a name and it's in the defined_names list, use reference
  if !schema.name.is_empty() && value_in_array(schema.name, defined_names) {
    return escape_variable_name(schema.name)
  }

  let base = schema_type_to_code(schema.schema_type, defined_names)
  let mut result = apply_rules_to_code(base, schema)

  // Apply description if present
  if !schema.description.is_empty() {
    result = result +
      ".describe(\"" +
      escape_mbt_string(schema.description) +
      "\")"
  }

  // Apply type-level error messages if present
  if !schema.required_error.is_empty() {
    result = result +
      ".required_error(\"" +
      escape_mbt_string(schema.required_error) +
      "\")"
  }
  if !schema.invalid_type_error.is_empty() {
    result = result +
      ".invalid_type_error(\"" +
      escape_mbt_string(schema.invalid_type_error) +
      "\")"
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
    ObjectType(fields, mode) => {
      let base = if fields.length() == 0 {
        "@moon_zod.object({})"
      } else {
        let parts : Array[String] = []
        for key, field_schema in fields {
          let field_code = schema_to_moon_zod_code_inline(
            field_schema,
            Some(defined_names),
          )
          parts.push("\"" + escape_mbt_string(key) + "\": " + field_code)
        }
        "@moon_zod.object({ " + join_with(parts, ", ") + " })"
      }

      // Apply object mode if not default Strip
      match mode {
        Strip => base
        Passthrough => base + ".passthrough()"
        Strict => base + ".strict()"
      }
    }
    ArrayType(elem) => {
      let elem_code = schema_to_moon_zod_code_inline(elem, Some(defined_names))
      "@moon_zod.array(" + elem_code + ")"
    }
    OptionalType(inner) =>
      schema_to_moon_zod_code_inline(inner, Some(defined_names)) + ".optional()"
    DefaultType(inner, default_val) =>
      schema_to_moon_zod_code_inline(inner, Some(defined_names)) +
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
        parts.push(schema_to_moon_zod_code_inline(s, Some(defined_names)))
      }
      "@moon_zod.union([" + join_with(parts, ", ") + "])"
    }
    IntersectionType(schemas) => {
      let parts : Array[String] = []
      for s in schemas {
        parts.push(schema_to_moon_zod_code_inline(s, Some(defined_names)))
      }
      "@moon_zod.intersection([" + join_with(parts, ", ") + "])"
    }
    LiteralType(val) => "@moon_zod.literal(" + json_to_literal(val) + ")"
    TransformType(inner, _) =>
      schema_to_moon_zod_code_inline(inner, Some(defined_names)) +
      ".transform(fn(x) { x })"
  }
}

///|
/// Apply rules as method chain.
/// Note: Only outputs constraint annotations, not rule messages,
/// since rule.message may be auto-generated defaults.
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
