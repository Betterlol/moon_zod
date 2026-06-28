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
