///|
/// Make a field optional: null or missing values pass validation.
/// Rules chained after `.optional()` are pushed through to the inner schema
/// via `append_rule`, so `string().optional().min(3)` works correctly.
pub fn Schema::optional(self : Schema) -> Schema {
  {
    schema_type: OptionalType(self),
    rules: [],
    description: self.description,
    required_error: self.required_error,
    invalid_type_error: self.invalid_type_error,
    name: self.name,
  }
}

///|
/// Provide a default value when the input is null.
/// Rules chained after `.default()` are pushed through to the inner schema
/// via `append_rule`.
pub fn Schema::default(self : Schema, value : Json) -> Schema {
  {
    schema_type: DefaultType(self, value),
    rules: [],
    description: self.description,
    required_error: self.required_error,
    invalid_type_error: self.invalid_type_error,
    name: self.name,
  }
}

///|
/// Create a schema that accepts one of a fixed set of string values.
pub fn enum_values(
  values : Array[String],
  required_error? : String = "",
  invalid_type_error? : String = "",
) -> Schema {
  {
    schema_type: EnumType(values),
    rules: [],
    description: "",
    required_error,
    invalid_type_error,
    name: "",
  }
}

///|
/// Create a schema that accepts any of the given schemas (union / or).
/// Schemas are tried in order; the first match succeeds.
pub fn union(
  schemas : Array[Schema],
  required_error? : String = "",
  invalid_type_error? : String = "",
) -> Schema {
  {
    schema_type: UnionType(schemas),
    rules: [],
    description: "",
    required_error,
    invalid_type_error,
    name: "",
  }
}

///|
/// Create a schema that accepts a specific literal JSON value.
/// The value must match exactly (String, Number, Boolean, or Null).
///
/// # Example
/// ```mbt nocheck
/// let schema = @moon_zod.literal(Json::string("hello"))
/// schema.parse(Json::string("hello")) // Ok
/// schema.parse(Json::string("world")) // Err
/// ```
pub fn literal(
  value : Json,
  required_error? : String = "",
  invalid_type_error? : String = "",
) -> Schema {
  {
    schema_type: LiteralType(value),
    rules: [],
    description: "",
    required_error,
    invalid_type_error,
    name: "",
  }
}

///|
pub fn Schema::parse_optional(
  _self : Schema,
  inner : Schema,
  json : Json,
  path_stack : Array[String],
) -> SchemaResult {
  match json {
    Null => Ok(json)
    _ => parse_inner(inner, json, path_stack)
  }
}

///|
pub fn Schema::parse_default(
  _self : Schema,
  inner : Schema,
  default_val : Json,
  json : Json,
  path_stack : Array[String],
) -> SchemaResult {
  match json {
    Null => Ok(default_val)
    _ => parse_inner(inner, json, path_stack)
  }
}

///|
pub fn Schema::parse_enum(
  _self : Schema,
  values : Array[String],
  json : Json,
  path_stack : Array[String],
) -> SchemaResult {
  let path = format_path(path_stack)
  match json {
    String(s) =>
      if value_in_array(s, values) {
        Ok(json)
      } else {
        Err([
          ValidationError::{ path, message: "Invalid enum value", got: json },
        ])
      }
    _ =>
      Err([
        ValidationError::{
          path,
          message: "Expected string for enum",
          got: json,
        },
      ])
  }
}

///|
pub fn Schema::parse_literal(
  _self : Schema,
  expected : Json,
  json : Json,
  path_stack : Array[String],
) -> SchemaResult {
  let path = format_path(path_stack)
  if json == expected {
    Ok(json)
  } else {
    let default_msg = "Expected literal value \{json_to_literal_string(expected)}, got different value"
    let message = if _self.invalid_type_error.is_empty() {
      default_msg
    } else {
      _self.invalid_type_error
    }
    Err([ValidationError::{ path, message, got: json }])
  }
}

///|
fn json_to_literal_string(json : Json) -> String {
  match json {
    String(s) => "\"" + s + "\""
    Number(v, ..) =>
      if v == v.to_int().to_double() {
        v.to_int().to_string()
      } else {
        v.to_string()
      }
    True => "true"
    False => "false"
    Null => "null"
    Array(arr) => {
      let parts = arr.map(fn(v) { json_to_literal_string(v) })
      "[" + parts.join(", ") + "]"
    }
    Object(map) => {
      let pairs : Array[String] = []
      for k, v in map {
        pairs.push("\"" + k + "\": " + json_to_literal_string(v))
      }
      "{" + pairs.join(", ") + "}"
    }
  }
}

///|
pub fn Schema::parse_union(
  _self : Schema,
  schemas : Array[Schema],
  json : Json,
  path_stack : Array[String],
) -> SchemaResult {
  let all_branch_errors : Array[String] = []
  for s in schemas {
    match parse_inner(s, json, path_stack) {
      Ok(v) => return Ok(v)
      Err(errors) =>
        if errors.length() > 0 {
          all_branch_errors.push(errors[0].message)
        }
    }
  }
  let path = format_path(path_stack)
  let branches = all_branch_errors.join(", ")
  let message = "Expected union type, but all branches failed. Branches: [" +
    branches +
    "]"
  Err([ValidationError::{ path, message, got: json }])
}
