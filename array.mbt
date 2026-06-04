///|
/// Create a schema that validates JSON arrays.
///
/// Each element in the array is validated against `element_schema`.
pub fn array(element_schema : Schema) -> Schema {
  { schema_type: ArrayType(element_schema), rules: [] }
}
