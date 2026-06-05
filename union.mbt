///|
/// Make a field optional: null or missing values pass validation.
/// Rules chained after `.optional()` are pushed through to the inner schema
/// via `append_rule`, so `string().optional().min(3)` works correctly.
pub fn Schema::optional(self : Schema) -> Schema {
  { schema_type: OptionalType(self), rules: [] }
}

///|
/// Provide a default value when the input is null.
/// Rules chained after `.default()` are pushed through to the inner schema
/// via `append_rule`.
pub fn Schema::default(self : Schema, value : Json) -> Schema {
  { schema_type: DefaultType(self, value), rules: [] }
}

///|
/// Create a schema that accepts one of a fixed set of string values.
pub fn enum_values(values : Array[String]) -> Schema {
  { schema_type: EnumType(values), rules: [] }
}

///|
/// Create a schema that accepts any of the given schemas (union / or).
/// Schemas are tried in order; the first match succeeds.
pub fn union(schemas : Array[Schema]) -> Schema {
  { schema_type: UnionType(schemas), rules: [] }
}

///|
pub fn Schema::parse_optional(
  self : Schema,
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
  self : Schema,
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
  self : Schema,
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
pub fn Schema::parse_union(
  self : Schema,
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
