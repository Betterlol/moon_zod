///|
/// Create a schema that validates JSON objects.
///
/// Each key in `spec` defines a required field and its schema.
/// By default, extra fields in the input JSON are silently stripped (Strip mode).
/// Use `.passthrough()` to allow extra fields, or `.strict()` to reject them.
pub fn object(
  spec : Map[String, Schema],
  required_error~ : String = "",
  invalid_type_error~ : String = "",
) -> Schema {
  {
    id: new_schema_id(),
    schema_type: ObjectType(spec.copy(), Strip),
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
    ObjectType(spec, _) =>
      { ..self, id: new_schema_id(), schema_type: ObjectType(spec, Strict), }
    _ => abort("strict() is only valid for object schemas")
  }
}

///|
/// Allow fields not defined in the schema spec.
pub fn Schema::passthrough(self : Schema) -> Schema {
  match self.schema_type {
    ObjectType(spec, _) =>
      {
        ..self,
        id: new_schema_id(),
        schema_type: ObjectType(spec, Passthrough),
      }
    _ => abort("passthrough() is only valid for object schemas")
  }
}

///|
/// Silently strip extra fields not defined in the schema spec.
/// This is the default mode.
pub fn Schema::strip(self : Schema) -> Schema {
  match self.schema_type {
    ObjectType(spec, _) =>
      {
        ..self,
        id: new_schema_id(),
        schema_type: ObjectType(spec.copy(), Strip),
      }
    _ => abort("strip() is only valid for object schemas")
  }
}

///|
/// Select only the specified fields from an object schema.
/// Returns a new object schema with the same mode (Strip/Passthrough/Strict).
/// Aborts if a requested key is not present in the original spec.
///
/// # Example
/// ```
/// let s = object({"a": string(), "b": number()}).pick(["a"])
/// s.parse(json)  // validates only field "a"
/// ```
pub fn Schema::pick(self : Schema, keys : Array[String]) -> Schema {
  guard self.rules.is_empty() else {
    abort(
      "pick() cannot change the shape of a refined object; compose the shape before refine()",
    )
  }
  match self.schema_type {
    ObjectType(spec, mode) => {
      let new_spec : Map[String, Schema] = Map([])
      for key in keys {
        match spec.get(key) {
          Some(s) => new_spec.set(key, s)
          None => abort("Unrecognized key: \"\{key}\"")
        }
      }
      {
        id: new_schema_id(),
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
/// Aborts if a requested key is not present in the original spec.
///
/// # Example
/// ```
/// let s = object({"a": string(), "b": number()}).omit(["b"])
/// s.parse(json)  // validates only field "a"
/// ```
pub fn Schema::omit(self : Schema, keys : Array[String]) -> Schema {
  guard self.rules.is_empty() else {
    abort(
      "omit() cannot change the shape of a refined object; compose the shape before refine()",
    )
  }
  match self.schema_type {
    ObjectType(spec, mode) => {
      for key in keys {
        if !spec.contains(key) {
          abort("Unrecognized key: \"\{key}\"")
        }
      }
      let new_spec : Map[String, Schema] = Map([])
      for key in spec.keys() {
        if !value_in_array(key, keys) {
          match spec.get(key) {
            Some(s) => new_spec.set(key, s)
            None => ()
          }
        }
      }
      {
        id: new_schema_id(),
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
  guard self.rules.is_empty() else {
    abort(
      "partial() cannot change the shape of a refined object; compose the shape before refine()",
    )
  }
  match self.schema_type {
    ObjectType(spec, mode) => {
      let new_spec : Map[String, Schema] = Map([])
      for key in spec.keys() {
        match spec.get(key) {
          Some(s) => new_spec.set(key, s.optional())
          None => ()
        }
      }
      {
        id: new_schema_id(),
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
/// Extend an object schema with additional fields.
/// Fields in `extension` override fields with the same name in the base schema.
pub fn Schema::extend_with(
  self : Schema,
  extension : Map[String, Schema],
) -> Schema {
  guard self.rules.is_empty() else {
    abort(
      "extend_with() cannot change the shape of a refined object; compose the shape before refine()",
    )
  }
  match self.schema_type {
    ObjectType(spec, mode) => {
      let new_spec : Map[String, Schema] = Map([])
      for key in spec.keys() {
        match spec.get(key) {
          Some(s) => new_spec.set(key, s)
          None => ()
        }
      }
      for key in extension.keys() {
        match extension.get(key) {
          Some(s) => new_spec.set(key, s)
          None => ()
        }
      }
      {
        id: new_schema_id(),
        schema_type: ObjectType(new_spec, mode),
        rules: self.rules,
        description: self.description,
        required_error: self.required_error,
        invalid_type_error: self.invalid_type_error,
        name: self.name,
        brand: self.brand,
      }
    }
    _ => abort("extend_with() is only valid for object schemas")
  }
}

///|
/// Merge two object schemas.
/// Fields from `other` override fields with the same name in `self`.
/// The merged schema inherits the right schema's object mode.
pub fn Schema::merge(self : Schema, other : Schema) -> Schema {
  guard self.rules.is_empty() && other.rules.is_empty() else {
    abort(
      "merge() cannot change the shape of a refined object; compose the shape before refine()",
    )
  }
  match (self.schema_type, other.schema_type) {
    (ObjectType(spec, _), ObjectType(other_spec, other_mode)) => {
      let new_spec : Map[String, Schema] = Map([])
      for key in spec.keys() {
        match spec.get(key) {
          Some(s) => new_spec.set(key, s)
          None => ()
        }
      }
      for key in other_spec.keys() {
        match other_spec.get(key) {
          Some(s) => new_spec.set(key, s)
          None => ()
        }
      }
      {
        id: new_schema_id(),
        schema_type: ObjectType(new_spec, other_mode),
        rules: self.rules,
        description: self.description,
        required_error: self.required_error,
        invalid_type_error: self.invalid_type_error,
        name: self.name,
        brand: self.brand,
      }
    }
    (_, ObjectType(_, _)) => abort("merge() is only valid for object schemas")
    _ => abort("merge() requires an object schema")
  }
}

///|
pub fn Schema::parse_object(
  self : Schema,
  spec : Map[String, Schema],
  mode : ObjectMode,
  json : Json,
  path_stack : Array[String],
) -> RawSchemaResult {
  parse_inner(
    { ..self, id: new_schema_id(), schema_type: ObjectType(spec, mode), },
    json,
    path_stack,
  )
}
