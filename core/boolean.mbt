///|
/// Create a schema that validates JSON booleans.
pub fn boolean(
  required_error? : String = "",
  invalid_type_error? : String = "",
) -> Schema {
  {
    schema_type: BooleanType,
    rules: [],
    description: "",
    required_error,
    invalid_type_error,
    name: "",
    brand: "",
  }
}
