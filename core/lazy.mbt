///|
/// Create a schema that defers resolution to parse time.
/// Required for recursive/self-referencing schemas (trees, linked lists, etc.).
///
/// # Example
/// ```mbt nocheck
/// fn tree_schema() -> @moon_zod.Schema {
///   @moon_zod.recursive(fn() {
///     @moon_zod.object({
///       "value": @moon_zod.number(),
///       "children": @moon_zod.array(@moon_zod.recursive(tree_schema)).optional(),
///     })
///   })
/// }
/// ```
pub fn recursive(f : () -> Schema) -> Schema {
  let cached : Ref[Schema?] = Ref(None)
  let resolve = fn() {
    match cached.val {
      Some(schema) => schema
      None => {
        let schema = f()
        cached.val = Some(schema)
        schema
      }
    }
  }
  {
    id: new_schema_id(),
    schema_type: LazyType(resolve),
    rules: [],
    description: "",
    required_error: "",
    invalid_type_error: "",
    name: "",
    brand: "",
  }
}

///|
pub fn Schema::parse_lazy(
  self : Schema,
  f : () -> Schema,
  json : Json,
  path_stack : Array[String],
) -> RawSchemaResult {
  parse_inner(
    { ..self, id: new_schema_id(), schema_type: LazyType(f), },
    json,
    path_stack,
  )
}
