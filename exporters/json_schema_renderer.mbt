///|
/// Trait for rendering @core.Schema as a Json value (JSON @core.Schema export).
///
/// Each method corresponds to one @core.SchemaType variant and returns a Json value
/// representing the JSON @core.Schema constraint.
pub(open) trait JsonSchemaRenderer {
  fn render_string(Self, schema : @core.Schema) -> Json
  fn render_number(Self, schema : @core.Schema) -> Json
  fn render_boolean(Self, schema : @core.Schema) -> Json
  fn render_null(Self, schema : @core.Schema) -> Json
  fn render_object(
    Self,
    spec : Map[String, @core.Schema],
    mode : @core.ObjectMode,
    schema : @core.Schema,
  ) -> Json
  fn render_array(Self, elem : @core.Schema, schema : @core.Schema) -> Json
  fn render_optional(Self, inner : @core.Schema, schema : @core.Schema) -> Json
  fn render_default(
    Self,
    inner : @core.Schema,
    default_val : Json,
    schema : @core.Schema,
  ) -> Json
  fn render_enum(Self, values : Array[String], schema : @core.Schema) -> Json
  fn render_union(Self, schemas : Array[@core.Schema], schema : @core.Schema) -> Json
  fn render_intersection(
    Self,
    schemas : Array[@core.Schema],
    schema : @core.Schema,
  ) -> Json
  fn render_transform(
    Self,
    inner : @core.Schema,
    closure : @core.TransformClosure,
    schema : @core.Schema,
  ) -> Json
  fn render_literal(Self, value : Json, schema : @core.Schema) -> Json
}

///|
/// Dispatch to the appropriate JsonSchemaRenderer method based on @core.SchemaType.
pub fn[R : JsonSchemaRenderer] render_json_type(
  renderer : R,
  schema : @core.Schema,
) -> Json {
  match schema.schema_type {
    StringType => renderer.render_string(schema)
    NumberType => renderer.render_number(schema)
    BooleanType => renderer.render_boolean(schema)
    NullType => renderer.render_null(schema)
    AnyType => abort("any JSON Schema export is not implemented")
    UnknownType => abort("unknown JSON Schema export is not implemented")
    ObjectType(spec, mode) => renderer.render_object(spec, mode, schema)
    ArrayType(elem) => renderer.render_array(elem, schema)
    TupleType(_) => abort("tuple JSON Schema export is not implemented")
    OptionalType(inner) => renderer.render_optional(inner, schema)
    DefaultType(inner, default_val) =>
      renderer.render_default(inner, default_val, schema)
    EnumType(values) => renderer.render_enum(values, schema)
    UnionType(schemas) => renderer.render_union(schemas, schema)
    IntersectionType(schemas) => renderer.render_intersection(schemas, schema)
    PreprocessType(_, _) =>
      abort("preprocess JSON Schema export is not implemented")
    TransformType(inner, closure) =>
      renderer.render_transform(inner, closure, schema)
    LiteralType(value) => renderer.render_literal(value, schema)
  }
}

///|
/// Named-aware version: emits a `$ref` if schema has a name in the list.
pub fn[R : JsonSchemaRenderer] render_json_type_ref(
  renderer : R,
  schema : @core.Schema,
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
