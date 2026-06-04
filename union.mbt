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
  path : String,
) -> SchemaResult {
  match json {
    Null => Ok(json)
    _ => inner.parse(json, path~)
  }
}

///|
pub fn Schema::parse_default(
  self : Schema,
  inner : Schema,
  default_val : Json,
  json : Json,
  path : String,
) -> SchemaResult {
  match json {
    Null => Ok(default_val)
    _ => inner.parse(json, path~)
  }
}

///|
pub fn Schema::parse_enum(
  self : Schema,
  values : Array[String],
  json : Json,
  path : String,
) -> SchemaResult {
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
  path : String,
) -> SchemaResult {
  let mut last_errors : Array[ValidationError]? = None
  for s in schemas {
    match s.parse(json, path~) {
      Ok(v) => return Ok(v)
      Err(errors) => last_errors = Some(errors)
    }
  }
  match last_errors {
    Some(errors) => Err(errors)
    None =>
      Err([
        ValidationError::{
          path,
          message: "Expected union type: none of the schemas matched current input",
          got: json,
        },
      ])
  }
}
