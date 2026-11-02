///|
/// Parse this input fallback when a key is absent. Explicit null is not replaced.
/// Unlike default(), the fallback runs through inner validation and transforms.
pub fn Schema::prefault(self : Schema, value : Json) -> Schema {
  {
    ..self,
    id: new_schema_id(),
    schema_type: PrefaultType(self, copy_json(value)),
    rules: [],
  }
}
