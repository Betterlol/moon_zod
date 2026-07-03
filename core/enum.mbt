///|
/// Create a schema that accepts one of a fixed set of string values.
pub fn enum_values(
  values : Array[String],
  required_error? : String = "",
  invalid_type_error? : String = "",
) -> Schema {
  {
    schema_type: EnumType(values),
    rules: [],
    description: "",
    required_error,
    invalid_type_error,
    name: "",
    brand: "",
  }
}

///|
pub fn Schema::parse_enum(
  _self : Schema,
  values : Array[String],
  json : Json,
  path_stack : Array[String],
) -> SchemaResult {
  let path = format_path(path_stack)
  match json {
    String(s) =>
      if value_in_array(s, values) {
        Ok(json)
      } else {
        Err([
          ValidationError::{ path, message: "Invalid enum value", got: json },
        ])
      }
    _ =>
      Err([
        ValidationError::{
          path,
          message: "Expected string for enum",
          got: json,
        },
      ])
  }
}
