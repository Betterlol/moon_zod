///|
/// Create a schema that validates JSON null.
pub fn null(
  required_error? : String = "",
  invalid_type_error? : String = "",
) -> Schema {
  {
    schema_type: NullType,
    rules: [],
    description: "",
    required_error,
    invalid_type_error,
    name: "",
    brand: "",
  }
}
