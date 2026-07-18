///|
/// Create a schema that validates fixed-length JSON arrays.
///
/// Each item in `items` validates the array element at the same index.
pub fn tuple(
  items : Array[Schema],
  required_error? : String = "",
  invalid_type_error? : String = "",
) -> Schema {
  {
    schema_type: TupleType(items),
    rules: [],
    description: "",
    required_error,
    invalid_type_error,
    name: "",
    brand: "",
  }
}

///|
pub fn Schema::parse_tuple(
  self : Schema,
  items : Array[Schema],
  json : Json,
  path_stack : Array[String],
) -> RawSchemaResult {
  match json {
    Array(elements) => {
      let raw : Array[RawIssue] = []
      if elements.length() != items.length() {
        let path = format_path(path_stack)
        let msg = "Expected tuple of length \{items.length()}"
        raw.push(RawIssue::{
          code: IssueCode::InvalidUnion([msg]),
          path,
          message: msg,
          input: json,
        })
      } else {
        for i in 0..<items.length() {
          path_stack.push("[\{i}]")
          match parse_inner(items[i], elements[i], path_stack) {
            Err(item_raw) =>
              for e in item_raw {
                raw.push(e)
              }
            _ => ()
          }
          let _ = path_stack.pop()
        }
      }
      let path = format_path(path_stack)
      collect_raw_errors(raw, path, json, self.rules)
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
          code: IssueCode::InvalidType("tuple"),
          path,
          message,
          input: json,
        },
      ])
    }
  }
}
