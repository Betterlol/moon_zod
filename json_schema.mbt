///|
/// Convert a moon_zod Schema into a standard JSON Schema object with full
/// constraint annotations (minLength, maximum, pattern, format, etc.).
pub fn to_json_schema(schema : Schema) -> Json {
  to_json_schema_full(schema)
}

///|
/// Convert a moon_zod Schema into a lightweight JSON Schema skeleton.
/// Only structural type information is exported; rules (min, max, email, etc.)
/// are not translated into JSON Schema annotations.
pub fn to_json_schema_skeleton(schema : Schema) -> Json {
  to_json_schema_inner(schema.schema_type)
}

///|
fn merge_annotations(base : Json, rules : Array[Rule]) -> Json {
  match base {
    Object(map) => {
      for rule in rules {
        match rule.annotation {
          Object(ann_map) =>
            for k, v in ann_map {
              map.set(k, v)
            }
          _ => ()
        }
      }
      base
    }
    _ => base
  }
}

///|
fn to_json_schema_full(schema : Schema) -> Json {
  let base = match schema.schema_type {
    StringType => json_string_schema()
    NumberType => json_number_schema()
    BooleanType => Json::object({ "type": Json::string("boolean") })
    NullType => Json::object({ "type": Json::string("null") })
    ObjectType(spec, mode) => to_json_schema_full_object(spec, mode)
    ArrayType(elem) =>
      Json::object({
        "type": Json::string("array"),
        "items": to_json_schema_full(elem),
      })
    OptionalType(inner) => to_json_schema_full(inner)
    TransformType(inner, _) => to_json_schema_full(inner)
    DefaultType(inner, default_val) => {
      let inner_json = to_json_schema_full(inner)
      match inner_json {
        Object(map) => {
          map.set("default", default_val)
          inner_json
        }
        _ => inner_json
      }
    }
    EnumType(values) =>
      Json::object({
        "type": Json::string("string"),
        "enum": Json::array(values.map(fn(s) { Json::string(s) })),
      })
    UnionType(schemas) =>
      Json::object({
        "anyOf": Json::array(schemas.map(fn(s) { to_json_schema_full(s) })),
      })
    IntersectionType(schemas) =>
      Json::object({
        "allOf": Json::array(schemas.map(fn(s) { to_json_schema_full(s) })),
      })
    LiteralType(value) => Json::object({ "const": value })
  }
  merge_annotations(base, schema.rules)
}

///|
fn to_json_schema_full_object(
  spec : Map[String, Schema],
  mode : ObjectMode,
) -> Json {
  let props : Map[String, Json] = {}
  let required_arr : Array[String] = []
  for key, val in spec {
    props.set(key, to_json_schema_full(val))
    if !is_optional_schema(val) {
      required_arr.push(key)
    }
  }
  Json::object({
    "type": Json::string("object"),
    "properties": Json::object(props),
    "additionalProperties": Json::boolean(
      match mode {
        Strict => false
        _ => true
      },
    ),
    "required": Json::array(required_arr.map(fn(k) { Json::string(k) })),
  })
}

///|
fn to_json_schema_inner(t : SchemaType) -> Json {
  match t {
    StringType => json_string_schema()
    NumberType => json_number_schema()
    BooleanType => Json::object({ "type": Json::string("boolean") })
    NullType => Json::object({ "type": Json::string("null") })
    ObjectType(spec, mode) => to_json_schema_object(spec, mode)
    ArrayType(elem) =>
      Json::object({
        "type": Json::string("array"),
        "items": to_json_schema_inner(elem.schema_type),
      })
    OptionalType(inner) => to_json_schema_inner(inner.schema_type)
    TransformType(inner, _) => to_json_schema_inner(inner.schema_type)
    DefaultType(inner, default_val) => {
      let inner_json = to_json_schema_inner(inner.schema_type)
      match inner_json {
        Object(map) => {
          map.set("default", default_val)
          inner_json
        }
        _ => inner_json
      }
    }
    EnumType(values) =>
      Json::object({
        "type": Json::string("string"),
        "enum": Json::array(values.map(fn(s) { Json::string(s) })),
      })
    UnionType(schemas) =>
      Json::object({
        "anyOf": Json::array(
          schemas.map(fn(s) { to_json_schema_inner(s.schema_type) }),
        ),
      })
    IntersectionType(schemas) =>
      Json::object({
        "allOf": Json::array(
          schemas.map(fn(s) { to_json_schema_inner(s.schema_type) }),
        ),
      })
    LiteralType(value) => Json::object({ "const": value })
  }
}

///|
fn to_json_schema_object(spec : Map[String, Schema], mode : ObjectMode) -> Json {
  let props : Map[String, Json] = {}
  let required_arr : Array[String] = []
  for key, val in spec {
    props.set(key, to_json_schema_inner(val.schema_type))
    if !is_optional_schema(val) {
      required_arr.push(key)
    }
  }
  Json::object({
    "type": Json::string("object"),
    "properties": Json::object(props),
    "additionalProperties": Json::boolean(
      match mode {
        Strict => false
        _ => true
      },
    ),
    "required": Json::array(required_arr.map(fn(k) { Json::string(k) })),
  })
}

///|
fn json_string_schema() -> Json {
  Json::object({ "type": Json::string("string") })
}

///|
fn json_number_schema() -> Json {
  Json::object({ "type": Json::string("number") })
}

///|
/// Export a JSON Schema with named sub-schemas in a `$defs` section.
/// Named schemas are extracted as separate `$defs` entries, and fields that
/// reference named schemas use `$ref` instead of inline expansion.
///
/// # Example
/// ```mbt nocheck
/// let address = object({ "street": string() }).name("Address")
///
/// let user = object({ "name": string(), "address": address }).name("User")
///
/// let json = to_json_schema_named(user)
/// // {
/// //   "$ref": "#/$defs/User",
/// //   "$defs": {
/// //     "Address": { "type": "object", ... },
/// //     "User": { "type": "object", "properties": { "address": { "$ref": "#/$defs/Address" } }, ... }
/// //   }
/// // }
/// ```
pub fn to_json_schema_named(schema : Schema) -> Json {
  let named_schemas = collect_named_schemas(schema)
  let named_names : Array[String] = named_schemas.map(fn(s) { s.name })

  // Sort topologically so dependencies precede dependents
  let sorted_schemas = topological_sort_schemas(named_schemas)

  // Build $defs with ref-aware conversion
  let defs_map : Map[String, Json] = {}
  for ns in sorted_schemas {
    defs_map.set(ns.name, to_json_schema_named_full(ns, named_names))
  }

  // Root: uses to_json_schema_ref so if root is named, it yields $ref
  let root = to_json_schema_ref(schema, named_names)

  // Assemble final document
  let result_map : Map[String, Json] = {}
  match root {
    Object(m) =>
      for k, v in m {
        result_map.set(k, v)
      }
    _ => ()
  }
  result_map.set("$defs", Json::object(defs_map))
  Json::object(result_map)
}

///|
/// Convert to JSON Schema with `$ref` replacement for named sub-schemas.
/// Used for sub-element positions (object fields, array items, etc.).
fn to_json_schema_ref(schema : Schema, named_names : Array[String]) -> Json {
  if !schema.name.is_empty() && value_in_array(schema.name, named_names) {
    return Json::object({ "$ref": Json::string("#/$defs/" + schema.name) })
  }
  to_json_schema_named_full(schema, named_names)
}

///|
/// Like `to_json_schema_full` but replaces named sub-schemas with `$ref`.
/// Does NOT `$ref` the schema itself — only sub-elements.
fn to_json_schema_named_full(
  schema : Schema,
  named_names : Array[String],
) -> Json {
  let base = match schema.schema_type {
    StringType => json_string_schema()
    NumberType => json_number_schema()
    BooleanType => Json::object({ "type": Json::string("boolean") })
    NullType => Json::object({ "type": Json::string("null") })
    ObjectType(spec, mode) => to_json_schema_ref_object(spec, mode, named_names)
    ArrayType(elem) =>
      Json::object({
        "type": Json::string("array"),
        "items": to_json_schema_ref(elem, named_names),
      })
    OptionalType(inner) => to_json_schema_named_full(inner, named_names)
    TransformType(inner, _) => to_json_schema_named_full(inner, named_names)
    DefaultType(inner, default_val) => {
      let inner_json = to_json_schema_named_full(inner, named_names)
      match inner_json {
        Object(map) => {
          map.set("default", default_val)
          inner_json
        }
        _ => inner_json
      }
    }
    EnumType(values) =>
      Json::object({
        "type": Json::string("string"),
        "enum": Json::array(values.map(fn(s) { Json::string(s) })),
      })
    UnionType(schemas) =>
      Json::object({
        "anyOf": Json::array(
          schemas.map(fn(s) { to_json_schema_ref(s, named_names) }),
        ),
      })
    IntersectionType(schemas) =>
      Json::object({
        "allOf": Json::array(
          schemas.map(fn(s) { to_json_schema_ref(s, named_names) }),
        ),
      })
    LiteralType(value) => Json::object({ "const": value })
  }
  merge_annotations(base, schema.rules)
}

///|
fn to_json_schema_ref_object(
  spec : Map[String, Schema],
  mode : ObjectMode,
  named_names : Array[String],
) -> Json {
  let props : Map[String, Json] = {}
  let required_arr : Array[String] = []
  for key, val in spec {
    props.set(key, to_json_schema_ref(val, named_names))
    if !is_optional_schema(val) {
      required_arr.push(key)
    }
  }
  Json::object({
    "type": Json::string("object"),
    "properties": Json::object(props),
    "additionalProperties": Json::boolean(
      match mode {
        Strict => false
        _ => true
      },
    ),
    "required": Json::array(required_arr.map(fn(k) { Json::string(k) })),
  })
}
