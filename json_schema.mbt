///|
/// Convert a moon_zod Schema into a standard JSON Schema object.
///
/// Rules (min, max, nonempty, etc.) are not translated into JSON Schema
/// annotations; only the structural type information is exported.
/// OptionalType and DefaultType wrappers are transparent (unwrapped) so that
/// `string().optional()` produces `{ "type": "string" }` rather than wrapping
/// in `oneOf`.
pub fn to_json_schema(schema : Schema) -> Json {
  to_json_schema_inner(schema.schema_type)
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
