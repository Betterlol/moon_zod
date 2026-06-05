///|
/// Create a schema that validates JSON arrays.
///
/// Each element in the array is validated against `element_schema`.
pub fn array(element_schema : Schema) -> Schema {
  { schema_type: ArrayType(element_schema), rules: [] }
}

///|
pub fn Schema::parse_array(
  self : Schema,
  element_schema : Schema,
  json : Json,
  path_stack : Array[String],
) -> SchemaResult {
  match json {
    Array(elements) => {
      let errors : Array[ValidationError] = []
      let mut i = 0
      for element in elements {
        path_stack.push("[\{i}]")
        let result = parse_inner(element_schema, element, path_stack)
        match result {
          Err(item_errors) =>
            for e in item_errors {
              errors.push(e)
            }
          _ => ()
        }
        let _ = path_stack.pop()
        i = i + 1
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
      Err([
        ValidationError::{
          path,
          message: expected_msg(self.schema_type),
          got: json,
        },
      ])
    }
  }
}
