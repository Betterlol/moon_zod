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
