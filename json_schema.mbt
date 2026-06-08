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
