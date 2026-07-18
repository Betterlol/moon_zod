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
  {
    schema_type: LazyType(f),
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
  let resolved = f()
  match parse_inner(resolved, json, path_stack) {
    Err(e) => Err(e)
    Ok(v) => {
      let raw : Array[RawIssue] = []
      collect_raw_errors(raw, path_stack, json, self.rules)
      if raw.is_empty() {
        Ok(v)
      } else {
        Err(raw)
      }
    }
  }
}
