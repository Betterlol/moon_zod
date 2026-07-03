///|
/// Create a schema that validates JSON integer values as big integers.
///
/// This is a convenience alias for `number().int()` that expresses
/// semantic intent. Useful for financial amounts, large IDs, and
/// other scenarios where the semantic type is "big integer" rather
/// than "number that is an integer".
pub fn bigint(
  required_error? : String = "",
  invalid_type_error? : String = "",
) -> Schema {
  number(required_error~, invalid_type_error~).int()
}
