///|
/// Create a schema that accepts any of the given schemas (union / or).
/// Schemas are tried in order; the first match succeeds.
pub fn union(
  schemas : Array[Schema],
  required_error~ : String = "",
  invalid_type_error~ : String = "",
) -> Schema {
  {
    id: new_schema_id(),
    schema_type: UnionType(schemas.copy()),
    rules: [],
    description: "",
    required_error,
    invalid_type_error,
    name: "",
    brand: "",
  }
}

///|
pub fn Schema::parse_union(
  self : Schema,
  schemas : Array[Schema],
  json : Json,
  path_stack : Array[String],
) -> RawSchemaResult {
  parse_inner(
    { ..self, id: new_schema_id(), schema_type: UnionType(schemas.copy()), },
    json,
    path_stack,
  )
}
