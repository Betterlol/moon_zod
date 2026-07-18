///|
/// Create a schema that validates JSON arrays.
///
/// Each element in the array is validated against `element_schema`.
pub fn array(
  element_schema : Schema,
  required_error? : String = "",
  invalid_type_error? : String = "",
) -> Schema {
  {
    schema_type: ArrayType(element_schema),
    rules: [],
    description: "",
    required_error,
    invalid_type_error,
    name: "",
    brand: "",
  }
}

///|
pub fn Schema::parse_array(
  self : Schema,
  element_schema : Schema,
  json : Json,
  path_stack : Array[String],
) -> RawSchemaResult {
  match json {
    Array(elements) => {
      let raw : Array[RawIssue] = []
      let mut i = 0
      for element in elements {
        path_stack.push("[\{i}]")
        let result = parse_inner(element_schema, element, path_stack)
        match result {
          Err(item_raw) =>
            for e in item_raw {
              raw.push(e)
            }
          _ => ()
        }
        let _ = path_stack.pop()
        i = i + 1
      }
      collect_raw_errors(raw, path_stack, json, self.rules)
      if raw.is_empty() {
        Ok(json)
      } else {
        Err(raw)
      }
    }
    _ => {
      let path = format_path(path_stack)
      let message = type_msg(self)
      Err([
        RawIssue::{
          code: IssueCode::InvalidType(type_origin(self.schema_type)),
          path,
          message,
          input: json,
        },
      ])
    }
  }
}
