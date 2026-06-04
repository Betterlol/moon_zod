///|
/// Make a field optional: null or missing values pass validation.
/// Call `.optional()` last in a chain (rules before optional).
pub fn Schema::optional(self : Schema) -> Schema {
  { schema_type: OptionalType(self), rules: [] }
}

///|
/// Provide a default value when the input is null.
/// Call `.default(value)` last in a chain (rules before default).
pub fn Schema::default(self : Schema, value : Json) -> Schema {
  { schema_type: DefaultType(self, value), rules: [] }
}

///|
/// Create a schema that accepts one of a fixed set of string values.
pub fn enum_values(values : Array[String]) -> Schema {
  { schema_type: EnumType(values), rules: [] }
}

///|
/// Create a schema that accepts any of the given schemas (union / or).
/// Schemas are tried in order; the first match succeeds.
pub fn union(schemas : Array[Schema]) -> Schema {
  { schema_type: UnionType(schemas), rules: [] }
}
