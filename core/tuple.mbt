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
) -> SchemaResult {
  match json {
    Array(elements) => {
      let errors : Array[ValidationError] = []
      if elements.length() != items.length() {
        let path = format_path(path_stack)
        errors.push(ValidationError::{
          path,
          message: "Expected tuple of length \{items.length()}",
          got: json,
        })
      } else {
        for i in 0..<items.length() {
          path_stack.push("[\{i}]")
          match parse_inner(items[i], elements[i], path_stack) {
            Err(item_errors) =>
              for e in item_errors {
                errors.push(e)
              }
            _ => ()
          }
          let _ = path_stack.pop()
        }
      }
      collect_errors(errors, path_stack, json, self.rules)
      if errors.is_empty() {
        Ok(json)
      } else {
        Err(errors)
      }
    }
    _ => {
      let path = format_path(path_stack)
      Err([ValidationError::{ path, message: type_error_msg(self), got: json }])
    }
  }
}
