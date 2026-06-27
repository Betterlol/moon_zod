///|
/// Convert a moon_zod Schema into a TypeScript-interface-style prompt string
/// suitable for LLM system prompts or correction feedback.
///
/// Uses StringRenderer trait with BasicPromptRenderer / NamedPromptRenderer.

///|
/// Basic prompt renderer: renders all types inline (no name references).
pub struct BasicPromptRenderer {}

///|
pub fn BasicPromptRenderer::BasicPromptRenderer() -> BasicPromptRenderer {
  BasicPromptRenderer::{  }
}

///|
pub impl StringRenderer for BasicPromptRenderer with fn render_string(
  self : BasicPromptRenderer,
  _schema : Schema,
  _indent : Int,
) -> String {
  "string"
}

///|
pub impl StringRenderer for BasicPromptRenderer with fn render_number(
  self : BasicPromptRenderer,
  _schema : Schema,
  _indent : Int,
) -> String {
  "number"
}

///|
pub impl StringRenderer for BasicPromptRenderer with fn render_boolean(
  self : BasicPromptRenderer,
  _schema : Schema,
  _indent : Int,
) -> String {
  "boolean"
}

///|
pub impl StringRenderer for BasicPromptRenderer with fn render_null(
  self : BasicPromptRenderer,
  _schema : Schema,
  _indent : Int,
) -> String {
  "null"
}

///|
pub impl StringRenderer for BasicPromptRenderer with fn render_optional(
  self : BasicPromptRenderer,
  inner : Schema,
  schema : Schema,
  indent : Int,
) -> String {
  render_type(self, inner, indent) + " | null"
}

///|
pub impl StringRenderer for BasicPromptRenderer with fn render_default(
  self : BasicPromptRenderer,
  inner : Schema,
  _default_val : Json,
  schema : Schema,
  indent : Int,
) -> String {
  render_type(self, inner, indent) + " | null"
}

///|
pub impl StringRenderer for BasicPromptRenderer with fn render_transform(
  self : BasicPromptRenderer,
  inner : Schema,
  _closure : TransformClosure,
  schema : Schema,
  indent : Int,
) -> String {
  render_type(self, inner, indent)
}

///|
pub impl StringRenderer for BasicPromptRenderer with fn render_enum(
  self : BasicPromptRenderer,
  values : Array[String],
  schema : Schema,
  _indent : Int,
) -> String {
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
pub impl StringRenderer for BasicPromptRenderer with fn render_array(
  self : BasicPromptRenderer,
  elem : Schema,
  schema : Schema,
  indent : Int,
) -> String {
  render_type(self, elem, indent) + "[]"
}

///|
pub impl StringRenderer for BasicPromptRenderer with fn render_union(
  self : BasicPromptRenderer,
  schemas : Array[Schema],
  schema : Schema,
  indent : Int,
) -> String {
  let mut result = ""
  let mut first = true
  for s in schemas {
    if first {
      result = render_type(self, s, indent)
    } else {
      result = result + " | " + render_type(self, s, indent)
    }
    first = false
  }
  result
}

///|
pub impl StringRenderer for BasicPromptRenderer with fn render_intersection(
  self : BasicPromptRenderer,
  schemas : Array[Schema],
  schema : Schema,
  indent : Int,
) -> String {
  let mut result = ""
  let mut first = true
  for s in schemas {
    if first {
      result = render_type(self, s, indent)
    } else {
      result = result + " & " + render_type(self, s, indent)
    }
    first = false
  }
  result
}

///|
pub impl StringRenderer for BasicPromptRenderer with fn render_object(
  self : BasicPromptRenderer,
  spec : Map[String, Schema],
  _mode : ObjectMode,
  schema : Schema,
  indent : Int,
) -> String {
  if spec.length() == 0 {
    return "{}"
  }
  let mut result = "{\n"
  let inner_indent = indent + 1
  for key, val_schema in spec {
    let key_is_optional = is_optional_schema(val_schema)
    let inner = if key_is_optional {
      peel_optional(val_schema)
    } else {
      val_schema
    }

    let field_type = render_type(self, inner, inner_indent)
    let comment = schema_comment(val_schema)
    let opt_mark = if key_is_optional { "?" } else { "" }
    let line = indent_str(inner_indent) + key + opt_mark + ": " + field_type

    if comment.is_empty() {
      result = result + line + ",\n"
    } else {
      result = result + line + ",  // " + comment + "\n"
    }
  }
  result = result + indent_str(indent) + "}"
  result
}

///|
pub impl StringRenderer for BasicPromptRenderer with fn render_literal(
  self : BasicPromptRenderer,
  value : Json,
  schema : Schema,
  _indent : Int,
) -> String {
  json_to_ts_literal(value)
}

///|
/// Named prompt renderer: uses name references for named schemas.
pub struct NamedPromptRenderer {
  named_schemas : Array[Schema]
}

///|
pub fn NamedPromptRenderer::NamedPromptRenderer(
  named_schemas~ : Array[Schema],
) -> NamedPromptRenderer {
  { named_schemas, }
}

///|
pub impl StringRenderer for NamedPromptRenderer with fn render_string(
  self : NamedPromptRenderer,
  schema : Schema,
  indent : Int,
) -> String {
  if has_name_in(schema, self.named_schemas) {
    schema.name
  } else {
    "string"
  }
}

///|
pub impl StringRenderer for NamedPromptRenderer with fn render_number(
  self : NamedPromptRenderer,
  schema : Schema,
  indent : Int,
) -> String {
  if has_name_in(schema, self.named_schemas) {
    schema.name
  } else {
    "number"
  }
}

///|
pub impl StringRenderer for NamedPromptRenderer with fn render_boolean(
  self : NamedPromptRenderer,
  schema : Schema,
  indent : Int,
) -> String {
  if has_name_in(schema, self.named_schemas) {
    schema.name
  } else {
    "boolean"
  }
}

///|
pub impl StringRenderer for NamedPromptRenderer with fn render_null(
  self : NamedPromptRenderer,
  schema : Schema,
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
  inner : Schema,
  _schema : Schema,
  indent : Int,
) -> String {
  render_type_named(self, inner, indent, self.named_schemas) + " | null"
}

///|
pub impl StringRenderer for NamedPromptRenderer with fn render_default(
  self : NamedPromptRenderer,
  inner : Schema,
  _default_val : Json,
  _schema : Schema,
  indent : Int,
) -> String {
  render_type_named(self, inner, indent, self.named_schemas) + " | null"
}

///|
pub impl StringRenderer for NamedPromptRenderer with fn render_transform(
  self : NamedPromptRenderer,
  inner : Schema,
  _closure : TransformClosure,
  _schema : Schema,
  indent : Int,
) -> String {
  render_type_named(self, inner, indent, self.named_schemas)
}

///|
pub impl StringRenderer for NamedPromptRenderer with fn render_enum(
  self : NamedPromptRenderer,
  values : Array[String],
  schema : Schema,
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
  elem : Schema,
  _schema : Schema,
  indent : Int,
) -> String {
  render_type_named(self, elem, indent, self.named_schemas) + "[]"
}

///|
pub impl StringRenderer for NamedPromptRenderer with fn render_union(
  self : NamedPromptRenderer,
  schemas : Array[Schema],
  schema : Schema,
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
  schemas : Array[Schema],
  schema : Schema,
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
  spec : Map[String, Schema],
  _mode : ObjectMode,
  schema : Schema,
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
    let key_is_optional = is_optional_schema(val_schema)
    let inner = if key_is_optional {
      peel_optional(val_schema)
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
    let line = indent_str(inner_indent) + key + opt_mark + ": " + field_type

    if comment.is_empty() {
      result = result + line + ",\n"
    } else {
      result = result + line + ",  // " + comment + "\n"
    }
  }
  result = result + indent_str(indent) + "}"
  result
}

///|
pub impl StringRenderer for NamedPromptRenderer with fn render_literal(
  self : NamedPromptRenderer,
  value : Json,
  schema : Schema,
  _indent : Int,
) -> String {
  if has_name_in(schema, self.named_schemas) {
    schema.name
  } else {
    json_to_ts_literal(value)
  }
}

///|
/// Public API: convert a schema to a TypeScript-interface-style prompt string.
pub fn schema_to_prompt(schema : Schema) -> String {
  let renderer = BasicPromptRenderer()
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
pub fn schema_to_prompt_named(
  schema : Schema,
  include_names? : Array[String]? = None,
) -> String {
  let all_named = collect_named_schemas(schema)
  let selected_schemas = filter_named_schemas(all_named, include_names)
  generate_prompt_with_interfaces(selected_schemas)
}

///|
/// Build the constraint comment for a schema.
/// For arrays, also merges element-level constraints.
fn schema_comment(schema : Schema) -> String {
  let unwrapped = unwrap_schema(schema)

  let inner = constraint_comment(schema)

  let merged = match unwrapped.schema_type {
    ArrayType(elem) => {
      let ec = constraint_comment(elem)
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
/// Convert a Json value to its TypeScript literal representation.
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
fn generate_prompt_with_interfaces(named_schemas : Array[Schema]) -> String {
  let sorted_schemas = topological_sort_schemas(named_schemas)

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
  schema : Schema,
  named_schemas : Array[Schema],
) -> String {
  if schema.name.is_empty() {
    return ""
  }

  let renderer = NamedPromptRenderer(named_schemas~)

  match schema.schema_type {
    ObjectType(spec, _) =>
      "export interface " +
      schema.name +
      " " +
      render_object_prompt(renderer, spec, named_schemas, 0)
    EnumType(values) =>
      "type " + schema.name + " = " + enum_values_to_string(values)
    UnionType(schemas) => {
      let union_type = union_to_prompt_inline_str(
        renderer, schemas, named_schemas, 0,
      )
      "export type " + schema.name + " = " + union_type
    }
    IntersectionType(schemas) => {
      let merged_spec = merge_intersection_object_specs(schemas)
      "export interface " +
      schema.name +
      " " +
      render_object_prompt(renderer, merged_spec, named_schemas, 0)
    }
    LiteralType(value) =>
      "export type " + schema.name + " = " + json_to_ts_literal(value)
    _ => ""
  }
}

///|
/// Helper: render an object spec with named references.
fn render_object_prompt(
  renderer : NamedPromptRenderer,
  spec : Map[String, Schema],
  named_schemas : Array[Schema],
  indent : Int,
) -> String {
  if spec.length() == 0 {
    return "{}"
  }
  let mut result = "{\n"
  let inner_indent = indent + 1
  for key, val_schema in spec {
    let key_is_optional = is_optional_schema(val_schema)
    let inner = if key_is_optional {
      peel_optional(val_schema)
    } else {
      val_schema
    }

    let field_type = render_type_named(
      renderer, inner, inner_indent, named_schemas,
    )
    let comment = schema_comment(val_schema)
    let opt_mark = if key_is_optional { "?" } else { "" }
    let line = indent_str(inner_indent) + key + opt_mark + ": " + field_type

    if comment.is_empty() {
      result = result + line + ",\n"
    } else {
      result = result + line + ",  // " + comment + "\n"
    }
  }
  result = result + indent_str(indent) + "}"
  result
}

///|
/// Helper: render union with named references.
fn union_to_prompt_inline_str(
  renderer : NamedPromptRenderer,
  schemas : Array[Schema],
  named_schemas : Array[Schema],
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
/// Helper: render enum values as a string.
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
/// Helper: check if a schema has a name present in the named schemas list.
fn has_name_in(schema : Schema, named_schemas : Array[Schema]) -> Bool {
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

///|
/// Merge object specs from multiple schemas in an intersection.
fn merge_intersection_object_specs(
  schemas : Array[Schema],
) -> Map[String, Schema] {
  let merged : Map[String, Schema] = {}

  for s in schemas {
    match s.schema_type {
      ObjectType(spec, _) =>
        for key, val_schema in spec {
          merged.set(key, val_schema)
        }
      IntersectionType(nested_schemas) => {
        let nested_merged = merge_intersection_object_specs(nested_schemas)
        for key, val_schema in nested_merged {
          merged.set(key, val_schema)
        }
      }
      _ => ()
    }
  }

  merged
}
