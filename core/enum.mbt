///|
/// Create a schema that accepts one of a fixed set of string values.
pub fn enum_values(
  values : Array[String],
  required_error~ : String = "",
  invalid_type_error~ : String = "",
) -> Schema {
  {
    id: new_schema_id(),
    schema_type: EnumType(values.copy()),
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
///
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
      { ..self, id: new_schema_id(), schema_type: EnumType(filtered), }
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
///
/// let warm = colors.extract(["red", "orange"]) // "orange" ignored, only "red" kept
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
      { ..self, id: new_schema_id(), schema_type: EnumType(filtered), }
    }
    _ => abort("extract() is only valid for enum schemas")
  }
}

///|
pub fn Schema::parse_enum(
  self : Schema,
  values : Array[String],
  json : Json,
  path_stack : Array[String],
) -> RawSchemaResult {
  parse_inner(
    { ..self, id: new_schema_id(), schema_type: EnumType(values.copy()), },
    json,
    path_stack,
  )
}
