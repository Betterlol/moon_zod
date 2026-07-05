///|
/// Convert a moon_zod @core.Schema into a standard JSON @core.Schema @core.object.
///
/// Uses JsonSchemaRenderer trait with FullJsonRenderer / SkeletonJsonRenderer / NamedJsonRenderer.

// ── Helper functions (shared across renderers) ──

///|
fn merge_annotations(base : Json, rules : Array[@core.Rule]) -> Json {
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
fn json_string_schema() -> Json {
  Json::object({ "type": Json::string("string") })
}

///|
fn json_number_schema() -> Json {
  Json::object({ "type": Json::string("number") })
}

// ── FullJsonRenderer: full JSON @core.Schema with constraint annotations ──

///|
pub struct FullJsonRenderer {}

///|
pub fn FullJsonRenderer::FullJsonRenderer() -> FullJsonRenderer {
  FullJsonRenderer::{  }
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for FullJsonRenderer with fn render_string(
  self : FullJsonRenderer,
  schema : @core.Schema,
) -> Json {
  merge_annotations(json_string_schema(), schema.rules)
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for FullJsonRenderer with fn render_number(
  self : FullJsonRenderer,
  schema : @core.Schema,
) -> Json {
  merge_annotations(json_number_schema(), schema.rules)
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for FullJsonRenderer with fn render_boolean(
  self : FullJsonRenderer,
  schema : @core.Schema,
) -> Json {
  merge_annotations(
    Json::object({ "type": Json::string("boolean") }),
    schema.rules,
  )
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for FullJsonRenderer with fn render_null(
  self : FullJsonRenderer,
  schema : @core.Schema,
) -> Json {
  merge_annotations(
    Json::object({ "type": Json::string("null") }),
    schema.rules,
  )
}

///|
pub impl JsonSchemaRenderer for FullJsonRenderer with fn render_object(
  self : FullJsonRenderer,
  spec : Map[String, @core.Schema],
  mode : @core.ObjectMode,
  schema : @core.Schema,
) -> Json {
  let props : Map[String, Json] = {}
  let required_arr : Array[String] = []
  for key, val in spec {
    props.set(key, render_json_type(self, val))
    if !@core.is_optional_schema(val) {
      required_arr.push(key)
    }
  }
  merge_annotations(
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
    }),
    schema.rules,
  )
}

///|
pub impl JsonSchemaRenderer for FullJsonRenderer with fn render_array(
  self : FullJsonRenderer,
  elem : @core.Schema,
  schema : @core.Schema,
) -> Json {
  merge_annotations(
    Json::object({
      "type": Json::string("array"),
      "items": render_json_type(self, elem),
    }),
    schema.rules,
  )
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for FullJsonRenderer with fn render_optional(
  self : FullJsonRenderer,
  inner : @core.Schema,
  schema : @core.Schema,
) -> Json {
  render_json_type(self, inner)
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for FullJsonRenderer with fn render_default(
  self : FullJsonRenderer,
  inner : @core.Schema,
  default_val : Json,
  schema : @core.Schema,
) -> Json {
  let inner_json = render_json_type(self, inner)
  match inner_json {
    Object(map) => {
      map.set("default", default_val)
      inner_json
    }
    _ => inner_json
  }
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for FullJsonRenderer with fn render_transform(
  self : FullJsonRenderer,
  inner : @core.Schema,
  _closure : @core.TransformClosure,
  schema : @core.Schema,
) -> Json {
  render_json_type(self, inner)
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for FullJsonRenderer with fn render_enum(
  self : FullJsonRenderer,
  values : Array[String],
  schema : @core.Schema,
) -> Json {
  merge_annotations(
    Json::object({
      "type": Json::string("string"),
      "enum": Json::array(values.map(fn(s) { Json::string(s) })),
    }),
    schema.rules,
  )
}

///|
pub impl JsonSchemaRenderer for FullJsonRenderer with fn render_union(
  self : FullJsonRenderer,
  schemas : Array[@core.Schema],
  schema : @core.Schema,
) -> Json {
  merge_annotations(
    Json::object({
      "anyOf": Json::array(schemas.map(fn(s) { render_json_type(self, s) })),
    }),
    schema.rules,
  )
}

///|
pub impl JsonSchemaRenderer for FullJsonRenderer with fn render_intersection(
  self : FullJsonRenderer,
  schemas : Array[@core.Schema],
  schema : @core.Schema,
) -> Json {
  merge_annotations(
    Json::object({
      "allOf": Json::array(schemas.map(fn(s) { render_json_type(self, s) })),
    }),
    schema.rules,
  )
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for FullJsonRenderer with fn render_literal(
  self : FullJsonRenderer,
  value : Json,
  schema : @core.Schema,
) -> Json {
  merge_annotations(Json::object({ "const": value }), schema.rules)
}

// ── SkeletonJsonRenderer: lightweight export (no constraints) ──

///|
pub struct SkeletonJsonRenderer {}

///|
pub fn SkeletonJsonRenderer::SkeletonJsonRenderer() -> SkeletonJsonRenderer {
  SkeletonJsonRenderer::{  }
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for SkeletonJsonRenderer with fn render_string(
  self : SkeletonJsonRenderer,
  _schema : @core.Schema,
) -> Json {
  json_string_schema()
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for SkeletonJsonRenderer with fn render_number(
  self : SkeletonJsonRenderer,
  _schema : @core.Schema,
) -> Json {
  json_number_schema()
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for SkeletonJsonRenderer with fn render_boolean(
  self : SkeletonJsonRenderer,
  _schema : @core.Schema,
) -> Json {
  Json::object({ "type": Json::string("boolean") })
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for SkeletonJsonRenderer with fn render_null(
  self : SkeletonJsonRenderer,
  _schema : @core.Schema,
) -> Json {
  Json::object({ "type": Json::string("null") })
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for SkeletonJsonRenderer with fn render_object(
  self : SkeletonJsonRenderer,
  spec : Map[String, @core.Schema],
  mode : @core.ObjectMode,
  schema : @core.Schema,
) -> Json {
  let props : Map[String, Json] = {}
  let required_arr : Array[String] = []
  for key, val in spec {
    props.set(key, render_json_type(self, val))
    if !@core.is_optional_schema(val) {
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
#warnings("-unused_value")
pub impl JsonSchemaRenderer for SkeletonJsonRenderer with fn render_array(
  self : SkeletonJsonRenderer,
  elem : @core.Schema,
  schema : @core.Schema,
) -> Json {
  Json::object({
    "type": Json::string("array"),
    "items": render_json_type(self, elem),
  })
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for SkeletonJsonRenderer with fn render_optional(
  self : SkeletonJsonRenderer,
  inner : @core.Schema,
  schema : @core.Schema,
) -> Json {
  render_json_type(self, inner)
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for SkeletonJsonRenderer with fn render_default(
  self : SkeletonJsonRenderer,
  inner : @core.Schema,
  default_val : Json,
  schema : @core.Schema,
) -> Json {
  let inner_json = render_json_type(self, inner)
  match inner_json {
    Object(map) => {
      map.set("default", default_val)
      inner_json
    }
    _ => inner_json
  }
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for SkeletonJsonRenderer with fn render_transform(
  self : SkeletonJsonRenderer,
  inner : @core.Schema,
  _closure : @core.TransformClosure,
  schema : @core.Schema,
) -> Json {
  render_json_type(self, inner)
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for SkeletonJsonRenderer with fn render_enum(
  self : SkeletonJsonRenderer,
  values : Array[String],
  schema : @core.Schema,
) -> Json {
  Json::object({
    "type": Json::string("string"),
    "enum": Json::array(values.map(fn(s) { Json::string(s) })),
  })
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for SkeletonJsonRenderer with fn render_union(
  self : SkeletonJsonRenderer,
  schemas : Array[@core.Schema],
  schema : @core.Schema,
) -> Json {
  Json::object({
    "anyOf": Json::array(schemas.map(fn(s) { render_json_type(self, s) })),
  })
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for SkeletonJsonRenderer with fn render_intersection(
  self : SkeletonJsonRenderer,
  schemas : Array[@core.Schema],
  schema : @core.Schema,
) -> Json {
  Json::object({
    "allOf": Json::array(schemas.map(fn(s) { render_json_type(self, s) })),
  })
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for SkeletonJsonRenderer with fn render_literal(
  self : SkeletonJsonRenderer,
  value : Json,
  schema : @core.Schema,
) -> Json {
  Json::object({ "const": value })
}

// ── NamedJsonRenderer: JSON @core.Schema with $defs/$ref support ──

///|
pub struct NamedJsonRenderer {
  named_names : Array[String]
}

///|
pub fn NamedJsonRenderer::NamedJsonRenderer(
  named_names~ : Array[String],
) -> NamedJsonRenderer {
  { named_names, }
}

///|
/// The named renderer's methods call render_json_type_ref for sub-elements,
/// which emits $ref for named schemas in the named_names list.
#warnings("-unused_value")
pub impl JsonSchemaRenderer for NamedJsonRenderer with fn render_string(
  self : NamedJsonRenderer,
  schema : @core.Schema,
) -> Json {
  merge_annotations(json_string_schema(), schema.rules)
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for NamedJsonRenderer with fn render_number(
  self : NamedJsonRenderer,
  schema : @core.Schema,
) -> Json {
  merge_annotations(json_number_schema(), schema.rules)
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for NamedJsonRenderer with fn render_boolean(
  self : NamedJsonRenderer,
  schema : @core.Schema,
) -> Json {
  merge_annotations(
    Json::object({ "type": Json::string("boolean") }),
    schema.rules,
  )
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for NamedJsonRenderer with fn render_null(
  self : NamedJsonRenderer,
  schema : @core.Schema,
) -> Json {
  merge_annotations(
    Json::object({ "type": Json::string("null") }),
    schema.rules,
  )
}

///|
pub impl JsonSchemaRenderer for NamedJsonRenderer with fn render_object(
  self : NamedJsonRenderer,
  spec : Map[String, @core.Schema],
  mode : @core.ObjectMode,
  schema : @core.Schema,
) -> Json {
  let props : Map[String, Json] = {}
  let required_arr : Array[String] = []
  for key, val in spec {
    props.set(key, render_json_type_ref(self, val, self.named_names))
    if !@core.is_optional_schema(val) {
      required_arr.push(key)
    }
  }
  merge_annotations(
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
    }),
    schema.rules,
  )
}

///|
pub impl JsonSchemaRenderer for NamedJsonRenderer with fn render_array(
  self : NamedJsonRenderer,
  elem : @core.Schema,
  schema : @core.Schema,
) -> Json {
  merge_annotations(
    Json::object({
      "type": Json::string("array"),
      "items": render_json_type_ref(self, elem, self.named_names),
    }),
    schema.rules,
  )
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for NamedJsonRenderer with fn render_optional(
  self : NamedJsonRenderer,
  inner : @core.Schema,
  schema : @core.Schema,
) -> Json {
  render_json_type_ref(self, inner, self.named_names)
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for NamedJsonRenderer with fn render_default(
  self : NamedJsonRenderer,
  inner : @core.Schema,
  default_val : Json,
  schema : @core.Schema,
) -> Json {
  let inner_json = render_json_type_ref(self, inner, self.named_names)
  match inner_json {
    Object(map) => {
      map.set("default", default_val)
      inner_json
    }
    _ => inner_json
  }
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for NamedJsonRenderer with fn render_transform(
  self : NamedJsonRenderer,
  inner : @core.Schema,
  _closure : @core.TransformClosure,
  schema : @core.Schema,
) -> Json {
  render_json_type_ref(self, inner, self.named_names)
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for NamedJsonRenderer with fn render_enum(
  self : NamedJsonRenderer,
  values : Array[String],
  schema : @core.Schema,
) -> Json {
  merge_annotations(
    Json::object({
      "type": Json::string("string"),
      "enum": Json::array(values.map(fn(s) { Json::string(s) })),
    }),
    schema.rules,
  )
}

///|
pub impl JsonSchemaRenderer for NamedJsonRenderer with fn render_union(
  self : NamedJsonRenderer,
  schemas : Array[@core.Schema],
  schema : @core.Schema,
) -> Json {
  merge_annotations(
    Json::object({
      "anyOf": Json::array(
        schemas.map(fn(s) { render_json_type_ref(self, s, self.named_names) }),
      ),
    }),
    schema.rules,
  )
}

///|
pub impl JsonSchemaRenderer for NamedJsonRenderer with fn render_intersection(
  self : NamedJsonRenderer,
  schemas : Array[@core.Schema],
  schema : @core.Schema,
) -> Json {
  merge_annotations(
    Json::object({
      "allOf": Json::array(
        schemas.map(fn(s) { render_json_type_ref(self, s, self.named_names) }),
      ),
    }),
    schema.rules,
  )
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for NamedJsonRenderer with fn render_literal(
  self : NamedJsonRenderer,
  value : Json,
  schema : @core.Schema,
) -> Json {
  merge_annotations(Json::object({ "const": value }), schema.rules)
}

// ── Public API ──

///|
/// Convert a moon_zod @core.Schema into a standard JSON @core.Schema @core.object with full
/// constraint annotations (minLength, maximum, pattern, format, etc.).
pub fn to_json_schema(schema : @core.Schema) -> Json {
  render_json_type(FullJsonRenderer(), schema)
}

///|
/// Convert a moon_zod @core.Schema into a lightweight JSON @core.Schema skeleton.
/// Only structural type information is exported.
pub fn to_json_schema_skeleton(schema : @core.Schema) -> Json {
  render_json_type(SkeletonJsonRenderer(), schema)
}

///|
/// Export a JSON @core.Schema with named sub-schemas in a `$defs` section.
/// If root schema has no name, it is assigned the name "Root".
pub fn to_json_schema_named(
  schema : @core.Schema,
  include_names? : Array[String]? = None,
) -> Json {
  let mut schema = schema
  if schema.name.is_empty() {
    schema = schema.name("Root")
  }
  let all_named = @core.collect_named_schemas(schema)
  let selected_schemas = @core.filter_named_schemas(all_named, include_names)
  let named_names : Array[String] = selected_schemas.map(fn(s) { s.name })
  let sorted_schemas = @core.topological_sort_schemas(selected_schemas)

  let renderer = NamedJsonRenderer(named_names~)

  let defs_map : Map[String, Json] = {}
  for ns in sorted_schemas {
    defs_map.set(ns.name, render_json_type(renderer, ns))
  }

  let root = render_json_type_ref(renderer, schema, named_names)

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
