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
  let checked : Map[String, Schema] = Map([])
  if options.is_empty() {
    abort("discriminated_union() requires at least one option")
  }
  for tag, option in options {
    guard option.schema_type is ObjectType(fields, _) else {
      abort("discriminated_union() options must be object schemas")
    }
    match fields.get(discriminator) {
      None =>
        checked.set(
          tag,
          option.extend_with(Map([(discriminator, literal(Json::string(tag)))])),
        )
      Some(field) => {
        guard field.schema_type is LiteralType(String(value)) && value == tag else {
          abort(
            "discriminator fields must be literals matching their option keys",
          )
        }
        checked.set(tag, option)
      }
    }
  }

  {
    id: new_schema_id(),
    schema_type: DiscriminatedUnionType(discriminator, checked),
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
    {
      ..self,
      id: new_schema_id(),
      schema_type: DiscriminatedUnionType(discriminator, options),
    },
    json,
    path_stack,
  )
}
