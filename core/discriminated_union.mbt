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
  _self : Schema,
  discriminator : String,
  options : Map[String, Schema],
  json : Json,
  path_stack : Array[String],
) -> RawSchemaResult {
  match json {
    Object(map) => {
      // Stack-allocate the discriminator path
      path_stack.push(discriminator)
      let disc_path = format_path(path_stack)
      let _ = path_stack.pop()
      match map.get(discriminator) {
        None =>
          Err([
            RawIssue::{
              code: IssueCode::MissingRequired(discriminator),
              path: disc_path,
              message: "Required",
              input: json,
            },
          ])
        Some(String(disc_value)) => {
          let valid_keys : Array[Json] = []
          for k in options.keys() {
            valid_keys.push(Json::string(k))
          }
          match options.get(disc_value) {
            Some(schema) => parse_inner(schema, json, path_stack)
            None =>
              Err([
                RawIssue::{
                  code: IssueCode::InvalidValue(valid_keys),
                  path: disc_path,
                  message: "Invalid discriminator value",
                  input: json,
                },
              ])
          }
        }
        Some(_) =>
          Err([
            RawIssue::{
              code: IssueCode::InvalidType("string"),
              path: disc_path,
              message: "Discriminator field must be a string",
              input: json,
            },
          ])
      }
    }
    _ => {
      let path = format_path(path_stack)
      Err([
        RawIssue::{
          code: IssueCode::InvalidType("object"),
          path,
          message: "Expected object for discriminated union",
          input: json,
        },
      ])
    }
  }
}
