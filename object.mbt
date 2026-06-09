///|
/// Create a schema that validates JSON objects.
///
/// Each key in `spec` defines a required field and its schema.
/// By default, extra fields in the input JSON are silently stripped (Strip mode).
/// Use `.passthrough()` to allow extra fields, or `.strict()` to reject them.
pub fn object(spec : Map[String, Schema]) -> Schema {
  { schema_type: ObjectType(spec, Strip), rules: [], description: "" }
}

///|
/// Reject fields not defined in the schema spec.
pub fn Schema::strict(self : Schema) -> Schema {
  match self.schema_type {
    ObjectType(spec, _) => { ..self, schema_type: ObjectType(spec, Strict) }
    _ => abort("strict() is only valid for object schemas")
  }
}

///|
/// Allow fields not defined in the schema spec.
pub fn Schema::passthrough(self : Schema) -> Schema {
  match self.schema_type {
    ObjectType(spec, _) =>
      { ..self, schema_type: ObjectType(spec, Passthrough) }
    _ => abort("passthrough() is only valid for object schemas")
  }
}

///|
/// Silently strip extra fields not defined in the schema spec.
/// This is the default mode.
pub fn Schema::strip(self : Schema) -> Schema {
  match self.schema_type {
    ObjectType(spec, _) => { ..self, schema_type: ObjectType(spec, Strip) }
    _ => abort("strip() is only valid for object schemas")
  }
}

///|
pub fn Schema::parse_object(
  self : Schema,
  spec : Map[String, Schema],
  mode : ObjectMode,
  json : Json,
  path_stack : Array[String],
) -> SchemaResult {
  match json {
    Object(input_map) => {
      let errors : Array[ValidationError] = []
      let parsed_fields : Map[String, Json] = {}
      for field_name in spec.keys() {
        match spec.get(field_name) {
          Some(field_schema) => {
            path_stack.push(field_name)
            match input_map.get(field_name) {
              None =>
                if !is_optional_schema(field_schema) {
                  let path = format_path(path_stack)
                  errors.push(ValidationError::{
                    path,
                    message: "Required",
                    got: Json::null(),
                  })
                }
              Some(field_json) => {
                let result = parse_inner(field_schema, field_json, path_stack)
                match result {
                  Err(field_errors) =>
                    for e in field_errors {
                      errors.push(e)
                    }
                  Ok(parsed) => parsed_fields.set(field_name, parsed)
                }
              }
            }
            let _ = path_stack.pop()
          }
          None => ()
        }
      }
      match mode {
        Strict =>
          for key in input_map.keys() {
            match input_map.get(key) {
              Some(value) =>
                if !spec.contains(key) {
                  path_stack.push(key)
                  let path = format_path(path_stack)
                  let _ = path_stack.pop()
                  errors.push(ValidationError::{
                    path,
                    message: "Unexpected field",
                    got: value,
                  })
                }
              None => ()
            }
          }
        _ => ()
      }
      collect_errors(errors, path_stack, json, self.rules)
      if errors.is_empty() {
        match mode {
          Strip => Ok(Json::object(parsed_fields))
          _ => Ok(json)
        }
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
