///|
/// Return this output default when a key is absent. Explicit null is not replaced.
/// Rules chained after `.default()` are pushed through to the inner schema
/// via `append_rule`.
pub fn Schema::default(self : Schema, value : Json) -> Schema {
  {
    id: new_schema_id(),
    schema_type: DefaultType(self, copy_json(value)),
    rules: [],
    description: self.description,
    required_error: self.required_error,
    invalid_type_error: self.invalid_type_error,
    name: self.name,
    brand: self.brand,
  }
}

///|
pub fn Schema::parse_default(
  self : Schema,
  inner : Schema,
  default_val : Json,
  json : Json,
  path_stack : Array[String],
) -> RawSchemaResult {
  parse_inner(
    {
      ..self,
      id: new_schema_id(),
      schema_type: DefaultType(inner, default_val),
    },
    json,
    path_stack,
  )
}
