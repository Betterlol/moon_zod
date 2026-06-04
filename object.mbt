///|
/// Create a schema that validates JSON objects.
///
/// Each key in `spec` defines a required field and its schema.
/// By default, extra fields in the input JSON are allowed (passthrough).
/// Use `.strict()` to reject extra fields.
pub fn object(spec : Map[String, Schema]) -> Schema {
  { schema_type: ObjectType(spec, Passthrough), rules: [] }
}

///|
/// Reject fields not defined in the schema spec.
pub fn Schema::strict(self : Schema) -> Schema {
  match self.schema_type {
    ObjectType(spec, _) => { ..self, schema_type: ObjectType(spec, Strict) }
    _ => abort("strict() is only valid for object schemas")
  }
}

///|
/// Allow fields not defined in the schema spec. This is the default.
pub fn Schema::passthrough(self : Schema) -> Schema {
  match self.schema_type {
    ObjectType(spec, _) =>
      { ..self, schema_type: ObjectType(spec, Passthrough) }
    _ => abort("passthrough() is only valid for object schemas")
  }
}
