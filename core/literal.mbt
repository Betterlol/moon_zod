///|
/// Create a schema that accepts a specific literal JSON value.
/// The value must match exactly (String, Number, Boolean, or Null).
///
/// # Example
/// ```mbt nocheck
/// let schema = @moon_zod.literal(Json::string("hello"))
/// schema.parse(Json::string("hello")) // Ok
/// schema.parse(Json::string("world")) // Err
/// ```
pub fn literal(
  value : Json,
  required_error? : String = "",
  invalid_type_error? : String = "",
) -> Schema {
  {
    schema_type: LiteralType(value),
    rules: [],
    description: "",
    required_error,
    invalid_type_error,
    name: "",
    brand: "",
  }
}

///|
pub fn Schema::parse_literal(
  _self : Schema,
  expected : Json,
  json : Json,
  path_stack : Array[String],
) -> SchemaResult {
  let path = format_path(path_stack)
  if json == expected {
    Ok(json)
  } else {
    let default_msg = "Expected literal value \{json_to_literal_string(expected)}, got different value"
    let message = if _self.invalid_type_error.is_empty() {
      default_msg
    } else {
      _self.invalid_type_error
    }
    Err([ValidationError::{ path, message, got: json }])
  }
}

///|
fn json_to_literal_string(json : Json) -> String {
  match json {
    String(s) => "\"" + s + "\""
    Number(v, ..) =>
      if v == v.to_int().to_double() {
        v.to_int().to_string()
      } else {
        v.to_string()
      }
    True => "true"
    False => "false"
    Null => "null"
    Array(arr) => {
      let parts = arr.map(fn(v) { json_to_literal_string(v) })
      "[" + parts.join(", ") + "]"
    }
    Object(map) => {
      let pairs : Array[String] = []
      for k, v in map {
        pairs.push("\"" + k + "\": " + json_to_literal_string(v))
      }
      "{" + pairs.join(", ") + "}"
    }
  }
}
