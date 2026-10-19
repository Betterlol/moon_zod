///|
/// Create a schema that requires all given schemas to match (intersection / and).
/// For objects, fields from all schemas are merged into one.
pub fn intersection(
  schemas : Array[Schema],
  required_error~ : String = "",
  invalid_type_error~ : String = "",
) -> Schema {
  {
    id: new_schema_id(),
    schema_type: IntersectionType(schemas.copy()),
    rules: [],
    description: "",
    required_error,
    invalid_type_error,
    name: "",
    brand: "",
  }
}

///|
/// Combine two schemas with intersection (both must match).
/// Equivalent to `intersection([self, other])`.
pub fn Schema::intersect(self : Schema, other : Schema) -> Schema {
  intersection([self, other])
}

///|
pub fn Schema::parse_intersection(
  self : Schema,
  schemas : Array[Schema],
  json : Json,
  path_stack : Array[String],
) -> RawSchemaResult {
  parse_inner(
    {
      ..self,
      id: new_schema_id(),
      schema_type: IntersectionType(schemas.copy()),
    },
    json,
    path_stack,
  )
}
