///|
/// Create a schema that validates JSON booleans.
pub fn boolean() -> Schema {
  { schema_type: BooleanType, rules: [], description: "" }
}
