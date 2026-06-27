///|
/// Trait for rendering Schema as a String (used by prompt.mbt and moonbit_struct.mbt).
///
/// Each method corresponds to one SchemaType variant.
/// The `indent` parameter controls nesting level for formatted output.
pub(open) trait StringRenderer {
  fn render_string(Self, schema : Schema, indent : Int) -> String
  fn render_number(Self, schema : Schema, indent : Int) -> String
  fn render_boolean(Self, schema : Schema, indent : Int) -> String
  fn render_null(Self, schema : Schema, indent : Int) -> String
  fn render_object(
    Self,
    spec : Map[String, Schema],
    mode : ObjectMode,
    schema : Schema,
    indent : Int,
  ) -> String
  fn render_array(Self, elem : Schema, schema : Schema, indent : Int) -> String
  fn render_optional(Self, inner : Schema, schema : Schema, indent : Int) -> String
  fn render_default(
    Self,
    inner : Schema,
    default_val : Json,
    schema : Schema,
    indent : Int,
  ) -> String
  fn render_enum(Self, values : Array[String], schema : Schema, indent : Int) -> String
  fn render_union(Self, schemas : Array[Schema], schema : Schema, indent : Int) -> String
  fn render_intersection(
    Self,
    schemas : Array[Schema],
    schema : Schema,
    indent : Int,
  ) -> String
  fn render_transform(
    Self,
    inner : Schema,
    closure : TransformClosure,
    schema : Schema,
    indent : Int,
  ) -> String
  fn render_literal(Self, value : Json, schema : Schema, indent : Int) -> String
}

///|
/// Dispatch to the appropriate StringRenderer method based on SchemaType.
fn[R : StringRenderer] render_type(
  renderer : R,
  schema : Schema,
  indent : Int,
) -> String {
  match schema.schema_type {
    StringType => renderer.render_string(schema, indent)
    NumberType => renderer.render_number(schema, indent)
    BooleanType => renderer.render_boolean(schema, indent)
    NullType => renderer.render_null(schema, indent)
    ObjectType(spec, mode) => renderer.render_object(spec, mode, schema, indent)
    ArrayType(elem) => renderer.render_array(elem, schema, indent)
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
fn[R : StringRenderer] render_type_named(
  renderer : R,
  schema : Schema,
  indent : Int,
  named_schemas : Array[Schema],
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
