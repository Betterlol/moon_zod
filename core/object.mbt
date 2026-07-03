///|
/// Create a schema that validates JSON objects.
///
/// Each key in `spec` defines a required field and its schema.
/// By default, extra fields in the input JSON are silently stripped (Strip mode).
/// Use `.passthrough()` to allow extra fields, or `.strict()` to reject them.
pub fn object(
  spec : Map[String, Schema],
  required_error? : String = "",
  invalid_type_error? : String = "",
) -> Schema {
  {
    schema_type: ObjectType(spec, Strip),
    rules: [],
    description: "",
    required_error,
    invalid_type_error,
    name: "",
    brand: "",
  }
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
/// Select only the specified fields from an object schema.
/// Returns a new object schema with the same mode (Strip/Passthrough/Strict).
/// Keys not present in the original spec are silently ignored.
///
/// # Example
/// ```
/// let s = object({"a": string(), "b": number()}).pick(["a"])
/// s.parse(json)  // validates only field "a"
/// ```
pub fn Schema::pick(self : Schema, keys : Array[String]) -> Schema {
  match self.schema_type {
    ObjectType(spec, mode) => {
      let new_spec : Map[String, Schema] = {}
      for key in keys {
        match spec.get(key) {
          Some(s) => new_spec.set(key, s)
          None => ()
        }
      }
      {
        schema_type: ObjectType(new_spec, mode),
        rules: self.rules,
        description: self.description,
        required_error: self.required_error,
        invalid_type_error: self.invalid_type_error,
        name: self.name,
        brand: self.brand,
      }
    }
    _ => abort("pick() is only valid for object schemas")
  }
}

///|
/// Omit the specified fields from an object schema.
/// Returns a new object schema with the same mode (Strip/Passthrough/Strict).
///
/// # Example
/// ```
/// let s = object({"a": string(), "b": number()}).omit(["b"])
/// s.parse(json)  // validates only field "a"
/// ```
pub fn Schema::omit(self : Schema, keys : Array[String]) -> Schema {
  match self.schema_type {
    ObjectType(spec, mode) => {
      let new_spec : Map[String, Schema] = {}
      for key in spec.keys() {
        if !value_in_array(key, keys) {
          match spec.get(key) {
            Some(s) => new_spec.set(key, s)
            None => ()
          }
        }
      }
      {
        schema_type: ObjectType(new_spec, mode),
        rules: self.rules,
        description: self.description,
        required_error: self.required_error,
        invalid_type_error: self.invalid_type_error,
        name: self.name,
        brand: self.brand,
      }
    }
    _ => abort("omit() is only valid for object schemas")
  }
}

///|
/// Make all fields of an object schema optional.
/// Useful for partial updates (e.g., PATCH operations).
/// Existing optional fields remain optional.
///
/// # Example
/// ```
/// let s = object({"name": string(), "age": number()}).partial()
/// s.parse(json)  // all fields are now optional
/// ```
pub fn Schema::partial(self : Schema) -> Schema {
  match self.schema_type {
    ObjectType(spec, mode) => {
      let new_spec : Map[String, Schema] = {}
      for key in spec.keys() {
        match spec.get(key) {
          Some(s) => new_spec.set(key, s.optional())
          None => ()
        }
      }
      {
        schema_type: ObjectType(new_spec, mode),
        rules: self.rules,
        description: self.description,
        required_error: self.required_error,
        invalid_type_error: self.invalid_type_error,
        name: self.name,
        brand: self.brand,
      }
    }
    _ => abort("partial() is only valid for object schemas")
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
                  let req_msg = if !field_schema.required_error.is_empty() {
                    field_schema.required_error
                  } else {
                    "Required"
                  }
                  errors.push(ValidationError::{
                    path,
                    message: req_msg,
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
      Err([ValidationError::{ path, message: type_error_msg(self), got: json }])
    }
  }
}
