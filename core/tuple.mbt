///|
/// Create a schema that validates fixed-length JSON arrays.
///
/// Each item in `items` validates the array element at the same index.
pub fn tuple(
  items : Array[Schema],
  required_error~ : String = "",
  invalid_type_error~ : String = "",
) -> Schema {
  {
    schema_type: TupleType(items),
    rules: [],
    description: "",
    required_error,
    invalid_type_error,
    name: "",
    brand: "",
  }
}

///|
pub fn Schema::parse_tuple(
  self : Schema,
  items : Array[Schema],
  json : Json,
  path_stack : Array[String],
) -> RawSchemaResult {
  parse_inner({ ..self, schema_type: TupleType(items), }, json, path_stack)
}
