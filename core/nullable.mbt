///|
/// Accept explicit JSON null without making an object key optional.
pub fn Schema::nullable(self : Schema) -> Schema {
  { ..self, id: new_schema_id(), schema_type: NullableType(self), rules: [], }
}

///|
/// Accept either an absent object key or explicit JSON null.
pub fn Schema::nullish(self : Schema) -> Schema {
  self.nullable().optional()
}
