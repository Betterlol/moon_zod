///|
/// Convert a moon_zod @core.Schema into a TypeScript-interface-style prompt @core.string
/// suitable for LLM system prompts or correction feedback.
///
/// Uses StringRenderer trait with NamedPromptRenderer.

///|
/// Named prompt renderer: uses name references for named schemas.
pub struct NamedPromptRenderer {
  named_schemas : Array[@core.Schema]
}

///|
pub fn NamedPromptRenderer::NamedPromptRenderer(
  named_schemas~ : Array[@core.Schema],
) -> NamedPromptRenderer {
  { named_schemas, }
}

///|
#warnings("-unused_value")
pub impl StringRenderer for NamedPromptRenderer with fn render_string(
  self : NamedPromptRenderer,
  schema : @core.Schema,
  indent : Int,
) -> String {
  if has_name_in(schema, self.named_schemas) {
    schema.name
  } else {
    "string"
  }
}

///|
#warnings("-unused_value")
pub impl StringRenderer for NamedPromptRenderer with fn render_number(
  self : NamedPromptRenderer,
  schema : @core.Schema,
  indent : Int,
) -> String {
  if has_name_in(schema, self.named_schemas) {
    schema.name
  } else {
    "number"
  }
}

///|
#warnings("-unused_value")
pub impl StringRenderer for NamedPromptRenderer with fn render_boolean(
  self : NamedPromptRenderer,
  schema : @core.Schema,
  indent : Int,
) -> String {
  if has_name_in(schema, self.named_schemas) {
    schema.name
  } else {
    "boolean"
  }
}

///|
#warnings("-unused_value")
pub impl StringRenderer for NamedPromptRenderer with fn render_null(
  self : NamedPromptRenderer,
  schema : @core.Schema,
  indent : Int,
) -> String {
  if has_name_in(schema, self.named_schemas) {
    schema.name
  } else {
    "null"
  }
}

///|
pub impl StringRenderer for NamedPromptRenderer with fn render_optional(
  self : NamedPromptRenderer,
  inner : @core.Schema,
  _schema : @core.Schema,
  indent : Int,
) -> String {
  render_type_named(self, inner, indent, self.named_schemas) + " | null"
}

///|
pub impl StringRenderer for NamedPromptRenderer with fn render_default(
  self : NamedPromptRenderer,
  inner : @core.Schema,
  _default_val : Json,
  _schema : @core.Schema,
  indent : Int,
) -> String {
  render_type_named(self, inner, indent, self.named_schemas) + " | null"
}

///|
pub impl StringRenderer for NamedPromptRenderer with fn render_transform(
  self : NamedPromptRenderer,
  inner : @core.Schema,
  _closure : @core.TransformClosure,
  _schema : @core.Schema,
  indent : Int,
) -> String {
  render_type_named(self, inner, indent, self.named_schemas)
}

///|
pub impl StringRenderer for NamedPromptRenderer with fn render_enum(
  self : NamedPromptRenderer,
  values : Array[String],
  schema : @core.Schema,
  _indent : Int,
) -> String {
  if has_name_in(schema, self.named_schemas) {
    return schema.name
  }
  let mut result = ""
  let mut first = true
  for v in values {
    if first {
      result = "\"" + v + "\""
    } else {
      result = result + " | \"" + v + "\""
    }
    first = false
  }
  result
}

///|
pub impl StringRenderer for NamedPromptRenderer with fn render_array(
  self : NamedPromptRenderer,
  elem : @core.Schema,
  _schema : @core.Schema,
  indent : Int,
) -> String {
  render_type_named(self, elem, indent, self.named_schemas) + "[]"
}

///|
pub impl StringRenderer for NamedPromptRenderer with fn render_union(
  self : NamedPromptRenderer,
  schemas : Array[@core.Schema],
  schema : @core.Schema,
  indent : Int,
) -> String {
  if has_name_in(schema, self.named_schemas) {
    return schema.name
  }
  let mut result = ""
  let mut first = true
  for s in schemas {
    if first {
      result = render_type_named(self, s, indent, self.named_schemas)
    } else {
      result = result +
        " | " +
        render_type_named(self, s, indent, self.named_schemas)
    }
    first = false
  }
  result
}

///|
pub impl StringRenderer for NamedPromptRenderer with fn render_intersection(
  self : NamedPromptRenderer,
  schemas : Array[@core.Schema],
  schema : @core.Schema,
  indent : Int,
) -> String {
  if has_name_in(schema, self.named_schemas) {
    return schema.name
  }
  let mut result = ""
  let mut first = true
  for s in schemas {
    if first {
      result = render_type_named(self, s, indent, self.named_schemas)
    } else {
      result = result +
        " & " +
        render_type_named(self, s, indent, self.named_schemas)
    }
    first = false
  }
  result
}

///|
pub impl StringRenderer for NamedPromptRenderer with fn render_object(
  self : NamedPromptRenderer,
  spec : Map[String, @core.Schema],
  _mode : @core.ObjectMode,
  schema : @core.Schema,
  indent : Int,
) -> String {
  if has_name_in(schema, self.named_schemas) {
    return schema.name
  }
  if spec.length() == 0 {
    return "{}"
  }
  let mut result = "{\n"
  let inner_indent = indent + 1
  for key, val_schema in spec {
    let key_is_optional = @core.is_optional_schema(val_schema)
    let inner = if key_is_optional {
      @core.peel_optional(val_schema)
    } else {
      val_schema
    }

    let field_type = render_type_named(
      self,
      inner,
      inner_indent,
      self.named_schemas,
    )
    let comment = schema_comment(val_schema)
    let opt_mark = if key_is_optional { "?" } else { "" }
    let line = @core.indent_str(inner_indent) +
      key +
      opt_mark +
      ": " +
      field_type

    if comment.is_empty() {
      result = result + line + ",\n"
    } else {
      result = result + line + ",  // " + comment + "\n"
    }
  }
  result = result + @core.indent_str(indent) + "}"
  result
}

///|
pub impl StringRenderer for NamedPromptRenderer with fn render_literal(
  self : NamedPromptRenderer,
  value : Json,
  schema : @core.Schema,
  _indent : Int,
) -> String {
  if has_name_in(schema, self.named_schemas) {
    schema.name
  } else {
    json_to_ts_literal(value)
  }
}

///|
#warnings("-unused_value")
pub impl StringRenderer for NamedPromptRenderer with fn render_any(
  self : NamedPromptRenderer,
  _schema : @core.Schema,
  _indent : Int,
) -> String {
  "any"
}

///|
#warnings("-unused_value")
pub impl StringRenderer for NamedPromptRenderer with fn render_unknown(
  self : NamedPromptRenderer,
  _schema : @core.Schema,
  _indent : Int,
) -> String {
  "unknown"
}

///|
#warnings("-unused_value")
pub impl StringRenderer for NamedPromptRenderer with fn render_tuple(
  self : NamedPromptRenderer,
  items : Array[@core.Schema],
  _schema : @core.Schema,
  indent : Int,
) -> String {
  render_tuple_type(self, items, indent)
}

///|
#warnings("-unused_value")
pub impl StringRenderer for NamedPromptRenderer with fn render_preprocess(
  self : NamedPromptRenderer,
  inner : @core.Schema,
  _schema : @core.Schema,
  indent : Int,
) -> String {
  render_type(self, inner, indent)
}

///|
/// Public API: convert a schema to a TypeScript-interface-style prompt @core.string.
pub fn schema_to_prompt(schema : @core.Schema) -> String {
  schema_to_prompt_inline(schema, [])
}

///|
fn schema_to_prompt_inline(
  schema : @core.Schema,
  named_schemas : Array[@core.Schema],
) -> String {
  let renderer = NamedPromptRenderer(named_schemas~)
  let tp = render_type(renderer, schema, 0)
  let comment = schema_comment(schema)
  if comment.is_empty() {
    tp
  } else {
    tp + "  // " + comment
  }
}

///|
/// Public API: convert a schema with named sub-schemas into a prompt with
/// separate interface definitions and name-based references.
///
/// If `include_names` is None, exports all named schemas.
/// If `include_names` is Some(names), exports only the specified schema names.
/// If root schema has no name, it is assigned the name "Root".
pub fn schema_to_prompt_named(
  schema : @core.Schema,
  include_names? : Array[String]? = None,
) -> String {
  let mut schema = schema
  if schema.name.is_empty() {
    schema = schema.name("Root")
  }
  let all_named = @core.collect_named_schemas(schema)
  let selected_schemas = @core.filter_named_schemas(all_named, include_names)
  generate_prompt_with_interfaces(selected_schemas)
}

///|
/// Build the constraint comment for a schema.
/// For arrays, also merges element-level constraints.
fn schema_comment(schema : @core.Schema) -> String {
  let unwrapped = @core.unwrap_schema(schema)

  let inner = @core.constraint_comment(schema)

  let merged = match unwrapped.schema_type {
    ArrayType(elem) => {
      let ec = @core.constraint_comment(elem)
      if inner.is_empty() {
        ec
      } else if ec.is_empty() {
        inner
      } else {
        inner + ", " + ec
      }
    }
    _ => inner
  }

  let constraint_part = if merged.is_empty() { "" } else { "[" + merged + "]" }
  let desc = schema.description
  if constraint_part.is_empty() && desc.is_empty() {
    ""
  } else if constraint_part.is_empty() {
    desc
  } else if desc.is_empty() {
    constraint_part
  } else {
    constraint_part + " — " + desc
  }
}

///|
/// Convert a Json value to its TypeScript @core.literal representation.
fn json_to_ts_literal(json : Json) -> String {
  match json {
    String(s) => "\"" + s + "\""
    Number(v, ..) =>
      if v == v.to_int().to_double() {
        v.to_int().to_string()
      } else {
        v.to_string()
      }
    True => "true"
    False => "false"
    Null => "null"
    Array(arr) => {
      let parts = arr.map(fn(v) { json_to_ts_literal(v) })
      "[" + parts.join(", ") + "]"
    }
    Object(map) => {
      let pairs : Array[String] = []
      for k, v in map {
        pairs.push("\"" + k + "\": " + json_to_ts_literal(v))
      }
      "{" + pairs.join(", ") + "}"
    }
  }
}

///|
/// Generate the full prompt with interface definitions and the root schema.
fn generate_prompt_with_interfaces(
  named_schemas : Array[@core.Schema],
) -> String {
  let sorted_schemas = @core.topological_sort_schemas(named_schemas)

  let mut prompt = ""

  for schema in sorted_schemas {
    let interface_def = schema_to_interface_definition_with_names(
      schema, sorted_schemas,
    )
    if !interface_def.is_empty() {
      if !prompt.is_empty() {
        prompt = prompt + "\n\n"
      }
      prompt = prompt + interface_def
    }
  }

  prompt
}

///|
/// Generate a TypeScript interface/type definition with proper name references.
fn schema_to_interface_definition_with_names(
  schema : @core.Schema,
  named_schemas : Array[@core.Schema],
) -> String {
  if schema.name.is_empty() {
    return ""
  }

  let ref_schemas = named_schemas.filter(fn(s) { s.name != schema.name })
  let renderer = NamedPromptRenderer(named_schemas=ref_schemas)

  match schema.schema_type {
    ObjectType(spec, _) =>
      "export interface " +
      schema.name +
      " " +
      render_object_prompt(renderer, spec, ref_schemas, 0)
    EnumType(values) =>
      "type " + schema.name + " = " + enum_values_to_string(values)
    UnionType(schemas) => {
      let union_type = union_to_prompt_inline_str(
        renderer, schemas, ref_schemas, 0,
      )
      "export type " + schema.name + " = " + union_type
    }
    IntersectionType(schemas) => {
      let intersection_type = intersection_to_prompt_inline_str(
        renderer, schemas, ref_schemas, 0,
      )
      "export type " + schema.name + " = " + intersection_type
    }
    LiteralType(value) =>
      "export type " + schema.name + " = " + json_to_ts_literal(value)
    _ => schema_to_type_alias_with_names(schema, renderer)
  }
}

///|
fn schema_to_type_alias_with_names(
  schema : @core.Schema,
  renderer : NamedPromptRenderer,
) -> String {
  let rendered = render_type(renderer, schema, 0)
  let comment = schema_comment(schema)
  let base = "export type " + schema.name + " = " + rendered
  if comment.is_empty() {
    base
  } else {
    base + "  // " + comment
  }
}

///|
/// Helper: render an @core.object spec with named references.
fn render_object_prompt(
  renderer : NamedPromptRenderer,
  spec : Map[String, @core.Schema],
  named_schemas : Array[@core.Schema],
  indent : Int,
) -> String {
  if spec.length() == 0 {
    return "{}"
  }
  let mut result = "{\n"
  let inner_indent = indent + 1
  for key, val_schema in spec {
    let key_is_optional = @core.is_optional_schema(val_schema)
    let field_type = field_type_with_names(
      renderer, val_schema, inner_indent, named_schemas,
    )
    let comment = schema_comment(val_schema)
    let opt_mark = if key_is_optional { "?" } else { "" }
    let line = @core.indent_str(inner_indent) +
      key +
      opt_mark +
      ": " +
      field_type

    if comment.is_empty() {
      result = result + line + ",\n"
    } else {
      result = result + line + ",  // " + comment + "\n"
    }
  }
  result = result + @core.indent_str(indent) + "}"
  result
}

///|
fn field_type_with_names(
  renderer : NamedPromptRenderer,
  schema : @core.Schema,
  indent : Int,
  named_schemas : Array[@core.Schema],
) -> String {
  if has_name_in(schema, named_schemas) {
    schema.name
  } else if @core.is_optional_schema(schema) {
    render_type_named(
      renderer,
      @core.peel_optional(schema),
      indent,
      named_schemas,
    )
  } else {
    render_type_named(renderer, schema, indent, named_schemas)
  }
}

///|
/// Helper: render @core.union with named references.
fn union_to_prompt_inline_str(
  renderer : NamedPromptRenderer,
  schemas : Array[@core.Schema],
  named_schemas : Array[@core.Schema],
  indent : Int,
) -> String {
  let mut result = ""
  let mut first = true
  for s in schemas {
    if first {
      result = render_type_named(renderer, s, indent, named_schemas)
    } else {
      result = result +
        " | " +
        render_type_named(renderer, s, indent, named_schemas)
    }
    first = false
  }
  result
}

///|
/// Helper: render @core.intersection with named references.
fn intersection_to_prompt_inline_str(
  renderer : NamedPromptRenderer,
  schemas : Array[@core.Schema],
  named_schemas : Array[@core.Schema],
  indent : Int,
) -> String {
  let mut result = ""
  let mut first = true
  for s in schemas {
    if first {
      result = render_type_named(renderer, s, indent, named_schemas)
    } else {
      result = result +
        " & " +
        render_type_named(renderer, s, indent, named_schemas)
    }
    first = false
  }
  result
}

///|
/// Helper: render enum values as a @core.string.
fn enum_values_to_string(values : Array[String]) -> String {
  let mut result = ""
  let mut first = true
  for v in values {
    if first {
      result = "\"" + v + "\""
    } else {
      result = result + " | \"" + v + "\""
    }
    first = false
  }
  result
}

///|
fn[R : StringRenderer] render_tuple_type(
  renderer : R,
  items : Array[@core.Schema],
  indent : Int,
) -> String {
  let parts : Array[String] = []
  for item in items {
    parts.push(render_type(renderer, item, indent))
  }
  "[" + parts.join(", ") + "]"
}

///|
/// Helper: check if a schema has a name present in the named schemas list.
fn has_name_in(
  schema : @core.Schema,
  named_schemas : Array[@core.Schema],
) -> Bool {
  if schema.name.is_empty() {
    return false
  }
  for ns in named_schemas {
    if ns.name == schema.name {
      return true
    }
  }
  false
}
