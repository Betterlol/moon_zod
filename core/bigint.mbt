///|
/// Create a schema that validates JSON integer values as big integers.
///
/// This is a JSON number().int() alias, limited to the safe Double integer range.
/// It is not arbitrary precision BigInt storage. Use a validated decimal string
/// or a dedicated numeric type for large IDs and exact financial amounts.
pub fn bigint(
  required_error~ : String = "",
  invalid_type_error~ : String = "",
) -> Schema {
  number(required_error~, invalid_type_error~).int()
}
