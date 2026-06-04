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
  path : String,
) -> SchemaResult {
  match json {
    Array(elements) => {
      let errors : Array[ValidationError] = []
      let mut i = 0
      for element in elements {
        let sp = sub_index(path, i)
        let result = element_schema.parse(element, path=sp)
        match result {
          Err(item_errors) =>
            for e in item_errors {
              errors.push(e)
            }
          _ => ()
        }
        i = i + 1
      }
      collect_errors(errors, path, json, self.rules)
      if errors.is_empty() {
        Ok(json)
      } else {
        Err(errors)
      }
    }
    _ =>
      Err([
        ValidationError::{
          path,
          message: expected_msg(self.schema_type),
          got: json,
        },
      ])
  }
}
