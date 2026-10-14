///|
/// Create a schema that dispatches to one of several options based on a
/// discriminator field value. Unlike `union()`, this directly selects the
/// matching schema in O(1) instead of trying each branch in order.
///
/// # Example
/// ```mbt nocheck
/// let pet = @moon_zod.discriminated_union("type", {
///   "dog": @moon_zod.object({ "bark": @moon_zod.boolean() }),
///   "cat": @moon_zod.object({ "meow": @moon_zod.boolean() }),
/// })
/// ```
pub fn discriminated_union(
  discriminator : String,
  options : Map[String, Schema],
) -> Schema {
  {
    schema_type: DiscriminatedUnionType(discriminator, options),
    rules: [],
    description: "",
    required_error: "",
    invalid_type_error: "",
    name: "",
    brand: "",
  }
}

///|
pub fn Schema::parse_discriminated_union(
  self : Schema,
  discriminator : String,
  options : Map[String, Schema],
  json : Json,
  path_stack : Array[String],
) -> RawSchemaResult {
  parse_inner(
    { ..self, schema_type: DiscriminatedUnionType(discriminator, options), },
    json,
    path_stack,
  )
}
