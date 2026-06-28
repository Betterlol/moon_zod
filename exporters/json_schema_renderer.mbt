///|
/// Trait for rendering Schema as a Json value (JSON Schema export).
///
/// Each method corresponds to one SchemaType variant and returns a Json value
/// representing the JSON Schema constraint.
pub(open) trait JsonSchemaRenderer {
  fn render_string(Self, schema : Schema) -> Json
  fn render_number(Self, schema : Schema) -> Json
  fn render_boolean(Self, schema : Schema) -> Json
  fn render_null(Self, schema : Schema) -> Json
  fn render_object(
    Self,
    spec : Map[String, Schema],
    mode : ObjectMode,
    schema : Schema,
  ) -> Json
  fn render_array(Self, elem : Schema, schema : Schema) -> Json
  fn render_optional(Self, inner : Schema, schema : Schema) -> Json
  fn render_default(Self, inner : Schema, default_val : Json, schema : Schema) -> Json
  fn render_enum(Self, values : Array[String], schema : Schema) -> Json
  fn render_union(Self, schemas : Array[Schema], schema : Schema) -> Json
  fn render_intersection(Self, schemas : Array[Schema], schema : Schema) -> Json
  fn render_transform(
    Self,
    inner : Schema,
    closure : TransformClosure,
    schema : Schema,
  ) -> Json
  fn render_literal(Self, value : Json, schema : Schema) -> Json
}

///|
/// Dispatch to the appropriate JsonSchemaRenderer method based on SchemaType.
pub fn[R : JsonSchemaRenderer] render_json_type(
  renderer : R,
  schema : Schema,
) -> Json {
  match schema.schema_type {
    StringType => renderer.render_string(schema)
    NumberType => renderer.render_number(schema)
    BooleanType => renderer.render_boolean(schema)
    NullType => renderer.render_null(schema)
    ObjectType(spec, mode) => renderer.render_object(spec, mode, schema)
    ArrayType(elem) => renderer.render_array(elem, schema)
    OptionalType(inner) => renderer.render_optional(inner, schema)
    DefaultType(inner, default_val) =>
      renderer.render_default(inner, default_val, schema)
    EnumType(values) => renderer.render_enum(values, schema)
    UnionType(schemas) => renderer.render_union(schemas, schema)
    IntersectionType(schemas) => renderer.render_intersection(schemas, schema)
    TransformType(inner, closure) =>
      renderer.render_transform(inner, closure, schema)
    LiteralType(value) => renderer.render_literal(value, schema)
  }
}

///|
/// Named-aware version: emits a `$ref` if schema has a name in the list.
pub fn[R : JsonSchemaRenderer] render_json_type_ref(
  renderer : R,
  schema : Schema,
  named_names : Array[String],
) -> Json {
  if !schema.name.is_empty() {
    for n in named_names {
      if n == schema.name {
        return Json::object({ "$ref": Json::string("#/$defs/" + schema.name) })
      }
    }
  }
  render_json_type(renderer, schema)
}
