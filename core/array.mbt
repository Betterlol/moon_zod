///|
/// Create a schema that validates JSON arrays.
///
/// Each element in the array is validated against `element_schema`.
pub fn array(
  element_schema : Schema,
  required_error~ : String = "",
  invalid_type_error~ : String = "",
) -> Schema {
  {
    id: new_schema_id(),
    schema_type: ArrayType(element_schema),
    rules: [],
    description: "",
    required_error,
    invalid_type_error,
    name: "",
    brand: "",
  }
}

///|
pub fn Schema::parse_array(
  self : Schema,
  element_schema : Schema,
  json : Json,
  path_stack : Array[String],
) -> RawSchemaResult {
  parse_inner(
    { ..self, id: new_schema_id(), schema_type: ArrayType(element_schema), },
    json,
    path_stack,
  )
}
