///|
/// Trait for rendering @core.Schema as a String (used by prompt.mbt and moonbit_struct.mbt).
///
/// Each method corresponds to one @core.SchemaType variant.
/// The `indent` parameter controls nesting level for formatted output.
pub(open) trait StringRenderer {
  fn render_string(Self, schema : @core.Schema, indent : Int) -> String
  fn render_number(Self, schema : @core.Schema, indent : Int) -> String
  fn render_boolean(Self, schema : @core.Schema, indent : Int) -> String
  fn render_null(Self, schema : @core.Schema, indent : Int) -> String
  fn render_object(
    Self,
    spec : Map[String, @core.Schema],
    mode : @core.ObjectMode,
    schema : @core.Schema,
    indent : Int,
  ) -> String
  fn render_array(
    Self,
    elem : @core.Schema,
    schema : @core.Schema,
    indent : Int,
  ) -> String
  fn render_optional(
    Self,
    inner : @core.Schema,
    schema : @core.Schema,
    indent : Int,
  ) -> String
  fn render_default(
    Self,
    inner : @core.Schema,
    default_val : Json,
    schema : @core.Schema,
    indent : Int,
  ) -> String
  fn render_enum(
    Self,
    values : Array[String],
    schema : @core.Schema,
    indent : Int,
  ) -> String
  fn render_union(
    Self,
    schemas : Array[@core.Schema],
    schema : @core.Schema,
    indent : Int,
  ) -> String
  fn render_intersection(
    Self,
    schemas : Array[@core.Schema],
    schema : @core.Schema,
    indent : Int,
  ) -> String
  fn render_transform(
    Self,
    inner : @core.Schema,
    closure : @core.TransformClosure,
    schema : @core.Schema,
    indent : Int,
  ) -> String
  fn render_literal(Self, value : Json, schema : @core.Schema, indent : Int) -> String
}

///|
/// Dispatch to the appropriate StringRenderer method based on @core.SchemaType.
pub fn[R : StringRenderer] render_type(
  renderer : R,
  schema : @core.Schema,
  indent : Int,
) -> String {
  match schema.schema_type {
    StringType => renderer.render_string(schema, indent)
    NumberType => renderer.render_number(schema, indent)
    BooleanType => renderer.render_boolean(schema, indent)
    NullType => renderer.render_null(schema, indent)
    ObjectType(spec, mode) => renderer.render_object(spec, mode, schema, indent)
    ArrayType(elem) => renderer.render_array(elem, schema, indent)
    TupleType(_) => abort("tuple prompt export is not implemented")
    OptionalType(inner) => renderer.render_optional(inner, schema, indent)
    DefaultType(inner, default_val) =>
      renderer.render_default(inner, default_val, schema, indent)
    EnumType(values) => renderer.render_enum(values, schema, indent)
    UnionType(schemas) => renderer.render_union(schemas, schema, indent)
    IntersectionType(schemas) =>
      renderer.render_intersection(schemas, schema, indent)
    TransformType(inner, closure) =>
      renderer.render_transform(inner, closure, schema, indent)
    LiteralType(value) => renderer.render_literal(value, schema, indent)
  }
}

///|
/// Named-aware version: renders a name reference if the schema has a name
/// present in the named schemas list, otherwise dispatches normally.
pub fn[R : StringRenderer] render_type_named(
  renderer : R,
  schema : @core.Schema,
  indent : Int,
  named_schemas : Array[@core.Schema],
) -> String {
  if !schema.name.is_empty() {
    for ns in named_schemas {
      if ns.name == schema.name {
        return schema.name
      }
    }
  }
  render_type(renderer, schema, indent)
}
