///|
/// Create a schema that validates JSON objects.
///
/// Each key in `spec` defines a required field and its schema.
/// By default, extra fields in the input JSON are allowed (passthrough).
/// Use `.strict()` to reject extra fields.
pub fn object(spec : Map[String, Schema]) -> Schema {
  { schema_type: ObjectType(spec, Passthrough), rules: [] }
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
/// Allow fields not defined in the schema spec. This is the default.
pub fn Schema::passthrough(self : Schema) -> Schema {
  match self.schema_type {
    ObjectType(spec, _) =>
      { ..self, schema_type: ObjectType(spec, Passthrough) }
    _ => abort("passthrough() is only valid for object schemas")
  }
}

///|
pub fn Schema::parse_object(
  self : Schema,
  spec : Map[String, Schema],
  mode : ObjectMode,
  json : Json,
  path : String,
) -> SchemaResult {
  match json {
    Object(input_map) => {
      let errors : Array[ValidationError] = []
      for field_name in spec.keys() {
        match spec.get(field_name) {
          Some(field_schema) => {
            let sp = sub_path(path, field_name)
            match input_map.get(field_name) {
              None =>
                if !is_optional_schema(field_schema) {
                  errors.push(ValidationError::{
                    path: sp,
                    message: "Required",
                    got: Json::null(),
                  })
                }
              Some(field_json) => {
                let result = field_schema.parse(field_json, path=sp)
                match result {
                  Err(field_errors) =>
                    for e in field_errors {
                      errors.push(e)
                    }
                  _ => ()
                }
              }
            }
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
                  errors.push(ValidationError::{
                    path: sub_path(path, key),
                    message: "Unexpected field",
                    got: value,
                  })
                }
              None => ()
            }
          }
        _ => ()
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
