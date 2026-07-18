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
) -> RawSchemaResult {
  let path = format_path(path_stack)
  match json {
    String(s) =>
      if value_in_array(s, values) {
        Ok(json)
      } else {
        Err([
          RawIssue::{
            code: IssueCode::InvalidValue(values.map(fn(v) { Json::string(v) })),
            path,
            message: "Invalid enum value",
            input: json,
          },
        ])
      }
    _ =>
      Err([
        RawIssue::{
          code: IssueCode::InvalidType("string"),
          path,
          message: "Expected string for enum",
          input: json,
        },
      ])
  }
}
