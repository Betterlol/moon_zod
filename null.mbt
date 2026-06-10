///|
/// Create a schema that validates JSON null.
pub fn null() -> Schema {
  { schema_type: NullType, rules: [], description: "" }
}
