///|
/// Create a schema that accepts any JSON value.
pub fn any(
  required_error? : String = "",
  invalid_type_error? : String = "",
) -> Schema {
  {
    schema_type: AnyType,
    rules: [],
    description: "",
    required_error,
    invalid_type_error,
    name: "",
    brand: "",
  }
}

///|
/// Create a schema that accepts any JSON value as unknown.
///
/// Runtime behavior matches `any()`; the distinction is semantic for consumers.
pub fn unknown(
  required_error? : String = "",
  invalid_type_error? : String = "",
) -> Schema {
  {
    schema_type: UnknownType,
    rules: [],
    description: "",
    required_error,
    invalid_type_error,
    name: "",
    brand: "",
  }
}
