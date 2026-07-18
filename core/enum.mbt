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
    brand: "",
  }
}

///|
/// Exclude specific values from an enum schema.
/// Returns a new schema with the remaining values.
/// Aborts if called on a non-enum schema.
///
/// # Example
/// ```mbt nocheck
/// let colors = enum_values(["red", "green", "blue"])
/// let no_green = colors.exclude(["green"])
/// // now accepts only "red" and "blue"
/// ```
pub fn Schema::exclude(self : Schema, values : Array[String]) -> Schema {
  match self.schema_type {
    EnumType(existing) => {
      let filtered : Array[String] = []
      for v in existing {
        if !value_in_array(v, values) {
          filtered.push(v)
        }
      }
      { ..self, schema_type: EnumType(filtered) }
    }
    _ => abort("exclude() is only valid for enum schemas")
  }
}

///|
/// Extract specific values from an enum schema.
/// Returns a new schema that only accepts the specified values.
/// Aborts if called on a non-enum schema.
///
/// # Example
/// ```mbt nocheck
/// let colors = enum_values(["red", "green", "blue"])
/// let warm = colors.extract(["red", "orange"])  // "orange" ignored, only "red" kept
/// // now accepts only "red"
/// ```
pub fn Schema::extract(self : Schema, values : Array[String]) -> Schema {
  match self.schema_type {
    EnumType(existing) => {
      let filtered : Array[String] = []
      for v in existing {
        if value_in_array(v, values) {
          filtered.push(v)
        }
      }
      { ..self, schema_type: EnumType(filtered) }
    }
    _ => abort("extract() is only valid for enum schemas")
  }
}

///|
pub fn Schema::parse_enum(
  _self : Schema,
  values : Array[String],
  json : Json,
  path_stack : Array[String],
) -> RawSchemaResult {
  let path = format_path(path_stack)
  match json {
    String(s) =>
      if value_in_array(s, values) {
        Ok(json)
      } else {
        Err([
          RawIssue::{
            code: IssueCode::InvalidValue(values.map(fn(v) { Json::string(v) })),
            path,
            message: "Invalid enum value",
            input: json,
          },
        ])
      }
    _ =>
      Err([
        RawIssue::{
          code: IssueCode::InvalidType("string"),
          path,
          message: "Expected string for enum",
          input: json,
        },
      ])
  }
}
