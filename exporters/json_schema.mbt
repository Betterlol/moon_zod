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

///|
fn object_allows_additional_properties(mode : @core.ObjectMode) -> Bool {
  match mode {
    Passthrough => true
    Strict | Strip => false
  }
}

///|
fn maybe_merge_annotations(
  base : Json,
  rules : Array[@core.Rule],
  include_annotations : Bool,
) -> Json {
  if include_annotations {
    merge_annotations(base, rules)
  } else {
    base
  }
}

///|
fn nullable_schema(inner_json : Json) -> Json {
  Json::object({
    "anyOf": Json::array([
      inner_json,
      Json::object({ "type": Json::string("null") }),
    ]),
  })
}

///|
fn add_default(schema_json : Json, default_val : Json) -> Json {
  match schema_json {
    Object(map) => {
      map.set("default", default_val)
      schema_json
    }
    _ => schema_json
  }
}

///|
fn[R : JsonSchemaRenderer] render_json_child(
  renderer : R,
  schema : @core.Schema,
  named_names : Array[String],
) -> Json {
  if named_names.is_empty() {
    render_json_type(renderer, schema)
  } else {
    render_json_type_ref(renderer, schema, named_names)
  }
}

///|
fn[R : JsonSchemaRenderer] render_object_schema(
  renderer : R,
  spec : Map[String, @core.Schema],
  mode : @core.ObjectMode,
  schema : @core.Schema,
  named_names : Array[String],
  include_annotations : Bool,
) -> Json {
  let props : Map[String, Json] = Map([])
  let required_arr : Array[String] = []
  for key, val in spec {
    props.set(key, render_json_child(renderer, val, named_names))
    if !@core.is_optional_schema(val) {
      required_arr.push(key)
    }
  }
  maybe_merge_annotations(
    Json::object({
      "type": Json::string("object"),
      "properties": Json::object(props),
      "additionalProperties": Json::boolean(
        object_allows_additional_properties(mode),
      ),
      "required": Json::array(required_arr.map(fn(k) { Json::string(k) })),
    }),
    schema.rules,
    include_annotations,
  )
}

///|
fn[R : JsonSchemaRenderer] render_array_schema(
  renderer : R,
  elem : @core.Schema,
  schema : @core.Schema,
  named_names : Array[String],
  include_annotations : Bool,
) -> Json {
  maybe_merge_annotations(
    Json::object({
      "type": Json::string("array"),
      "items": render_json_child(renderer, elem, named_names),
    }),
    schema.rules,
    include_annotations,
  )
}

///|
fn[R : JsonSchemaRenderer] render_union_schema(
  renderer : R,
  schemas : Array[@core.Schema],
  schema : @core.Schema,
  named_names : Array[String],
  include_annotations : Bool,
) -> Json {
  maybe_merge_annotations(
    Json::object({
      "anyOf": Json::array(
        schemas.map(fn(s) { render_json_child(renderer, s, named_names) }),
      ),
    }),
    schema.rules,
    include_annotations,
  )
}

///|
fn[R : JsonSchemaRenderer] render_intersection_schema(
  renderer : R,
  schemas : Array[@core.Schema],
  schema : @core.Schema,
  named_names : Array[String],
  include_annotations : Bool,
) -> Json {
  if can_merge_object_intersection(schemas) {
    return maybe_merge_annotations(
      render_merged_object_intersection_schema(renderer, schemas, named_names),
      schema.rules,
      include_annotations,
    )
  }
  maybe_merge_annotations(
    Json::object({
      "allOf": Json::array(
        schemas.map(fn(s) { render_json_child(renderer, s, named_names) }),
      ),
    }),
    schema.rules,
    include_annotations,
  )
}

///|
fn[R : JsonSchemaRenderer] render_json_tuple_type(
  renderer : R,
  items : Array[@core.Schema],
) -> Json {
  Json::object({
    "type": Json::string("array"),
    "prefixItems": Json::array(
      items.map(fn(item) { render_json_type(renderer, item) }),
    ),
    "minItems": Json::number(items.length().to_double()),
    "maxItems": Json::number(items.length().to_double()),
  })
}

///|
fn can_merge_object_intersection(schemas : Array[@core.Schema]) -> Bool {
  for schema in schemas {
    match schema.schema_type {
      ObjectType(_, _) => ()
      IntersectionType(nested) =>
        if !can_merge_object_intersection(nested) {
          return false
        }
      _ => return false
    }
  }
  true
}

///|
fn[R : JsonSchemaRenderer] render_merged_object_intersection_schema(
  renderer : R,
  schemas : Array[@core.Schema],
  named_names : Array[String],
) -> Json {
  let props : Map[String, Json] = Map([])
  let required_arr : Array[String] = []
  collect_object_intersection_parts(
    renderer, schemas, named_names, props, required_arr,
  )
  Json::object({
    "type": Json::string("object"),
    "properties": Json::object(props),
    "additionalProperties": Json::boolean(
      object_intersection_allows_additional_properties(schemas),
    ),
    "required": Json::array(required_arr.map(fn(k) { Json::string(k) })),
  })
}

///|
fn[R : JsonSchemaRenderer] collect_object_intersection_parts(
  renderer : R,
  schemas : Array[@core.Schema],
  named_names : Array[String],
  props : Map[String, Json],
  required_arr : Array[String],
) -> Unit {
  for schema in schemas {
    match schema.schema_type {
      ObjectType(spec, _) =>
        for key, val in spec {
          let rendered = render_json_child(renderer, val, named_names)
          match props.get(key) {
            Some(existing) =>
              props.set(key, combine_property_schema(existing, rendered))
            None => props.set(key, rendered)
          }
          if !@core.is_optional_schema(val) &&
            !@core.value_in_array(key, required_arr) {
            required_arr.push(key)
          }
        }
      IntersectionType(nested) =>
        collect_object_intersection_parts(
          renderer, nested, named_names, props, required_arr,
        )
      _ => ()
    }
  }
}

///|
fn combine_property_schema(left : Json, right : Json) -> Json {
  if left == right {
    left
  } else {
    Json::object({ "allOf": Json::array([left, right]) })
  }
}

///|
fn object_intersection_allows_additional_properties(
  schemas : Array[@core.Schema],
) -> Bool {
  if object_intersection_has_strict(schemas) {
    false
  } else {
    object_intersection_has_passthrough(schemas)
  }
}

///|
fn object_intersection_has_strict(schemas : Array[@core.Schema]) -> Bool {
  for schema in schemas {
    match schema.schema_type {
      ObjectType(_, Strict) => return true
      IntersectionType(nested) =>
        if object_intersection_has_strict(nested) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn object_intersection_has_passthrough(schemas : Array[@core.Schema]) -> Bool {
  for schema in schemas {
    match schema.schema_type {
      ObjectType(_, Passthrough) => return true
      IntersectionType(nested) =>
        if object_intersection_has_passthrough(nested) {
          return true
        }
      _ => ()
    }
  }
  false
}

// ── NamedJsonRenderer: shared JSON Schema renderer ──

///|
pub struct NamedJsonRenderer {
  named_names : Array[String]
  include_annotations : Bool
}

///|
pub fn NamedJsonRenderer::NamedJsonRenderer(
  named_names~ : Array[String],
  include_annotations? : Bool = true,
) -> NamedJsonRenderer {
  { named_names, include_annotations }
}

///|
/// The named renderer's methods call render_json_type_ref for sub-elements,
/// which emits $ref for named schemas in the named_names list.
#warnings("-unused_value")
pub impl JsonSchemaRenderer for NamedJsonRenderer with fn render_string(
  self : NamedJsonRenderer,
  schema : @core.Schema,
) -> Json {
  maybe_merge_annotations(
    json_string_schema(),
    schema.rules,
    self.include_annotations,
  )
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for NamedJsonRenderer with fn render_number(
  self : NamedJsonRenderer,
  schema : @core.Schema,
) -> Json {
  maybe_merge_annotations(
    json_number_schema(),
    schema.rules,
    self.include_annotations,
  )
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for NamedJsonRenderer with fn render_boolean(
  self : NamedJsonRenderer,
  schema : @core.Schema,
) -> Json {
  maybe_merge_annotations(
    Json::object({ "type": Json::string("boolean") }),
    schema.rules,
    self.include_annotations,
  )
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for NamedJsonRenderer with fn render_null(
  self : NamedJsonRenderer,
  schema : @core.Schema,
) -> Json {
  maybe_merge_annotations(
    Json::object({ "type": Json::string("null") }),
    schema.rules,
    self.include_annotations,
  )
}

///|
pub impl JsonSchemaRenderer for NamedJsonRenderer with fn render_object(
  self : NamedJsonRenderer,
  spec : Map[String, @core.Schema],
  mode : @core.ObjectMode,
  schema : @core.Schema,
) -> Json {
  render_object_schema(
    self,
    spec,
    mode,
    schema,
    self.named_names,
    self.include_annotations,
  )
}

///|
pub impl JsonSchemaRenderer for NamedJsonRenderer with fn render_array(
  self : NamedJsonRenderer,
  elem : @core.Schema,
  schema : @core.Schema,
) -> Json {
  render_array_schema(
    self,
    elem,
    schema,
    self.named_names,
    self.include_annotations,
  )
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for NamedJsonRenderer with fn render_optional(
  self : NamedJsonRenderer,
  inner : @core.Schema,
  schema : @core.Schema,
) -> Json {
  nullable_schema(render_json_type_ref(self, inner, self.named_names))
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for NamedJsonRenderer with fn render_default(
  self : NamedJsonRenderer,
  inner : @core.Schema,
  default_val : Json,
  schema : @core.Schema,
) -> Json {
  add_default(
    nullable_schema(render_json_type_ref(self, inner, self.named_names)),
    default_val,
  )
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
  maybe_merge_annotations(
    Json::object({
      "type": Json::string("string"),
      "enum": Json::array(values.map(fn(s) { Json::string(s) })),
    }),
    schema.rules,
    self.include_annotations,
  )
}

///|
pub impl JsonSchemaRenderer for NamedJsonRenderer with fn render_union(
  self : NamedJsonRenderer,
  schemas : Array[@core.Schema],
  schema : @core.Schema,
) -> Json {
  render_union_schema(
    self,
    schemas,
    schema,
    self.named_names,
    self.include_annotations,
  )
}

///|
pub impl JsonSchemaRenderer for NamedJsonRenderer with fn render_intersection(
  self : NamedJsonRenderer,
  schemas : Array[@core.Schema],
  schema : @core.Schema,
) -> Json {
  render_intersection_schema(
    self,
    schemas,
    schema,
    self.named_names,
    self.include_annotations,
  )
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for NamedJsonRenderer with fn render_literal(
  self : NamedJsonRenderer,
  value : Json,
  schema : @core.Schema,
) -> Json {
  maybe_merge_annotations(
    Json::object({ "const": value }),
    schema.rules,
    self.include_annotations,
  )
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for NamedJsonRenderer with fn render_any(
  self : NamedJsonRenderer,
  _schema : @core.Schema,
) -> Json {
  Json::empty_object()
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for NamedJsonRenderer with fn render_unknown(
  self : NamedJsonRenderer,
  _schema : @core.Schema,
) -> Json {
  Json::empty_object()
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for NamedJsonRenderer with fn render_tuple(
  self : NamedJsonRenderer,
  items : Array[@core.Schema],
  _schema : @core.Schema,
) -> Json {
  render_json_tuple_type(self, items)
}

///|
#warnings("-unused_value")
pub impl JsonSchemaRenderer for NamedJsonRenderer with fn render_preprocess(
  self : NamedJsonRenderer,
  inner : @core.Schema,
  _schema : @core.Schema,
) -> Json {
  render_json_type(self, inner)
}

// ── Public API ──

///|
/// Convert a moon_zod @core.Schema into a standard JSON @core.Schema @core.object with full
/// constraint annotations (minLength, maximum, pattern, format, etc.).
pub fn to_json_schema(schema : @core.Schema) -> Json {
  render_json_type(NamedJsonRenderer(named_names=[]), schema)
}

///|
/// Convert a moon_zod @core.Schema into a lightweight JSON @core.Schema skeleton.
/// Only structural type information is exported.
pub fn to_json_schema_skeleton(schema : @core.Schema) -> Json {
  render_json_type(
    NamedJsonRenderer(named_names=[], include_annotations=false),
    schema,
  )
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

  let defs_map : Map[String, Json] = Map([])
  for ns in sorted_schemas {
    let ref_names = named_names.filter(fn(n) { n != ns.name })
    let renderer = NamedJsonRenderer(named_names=ref_names)
    defs_map.set(ns.name, render_json_type(renderer, ns))
  }

  let renderer = NamedJsonRenderer(named_names~)
  let root = render_json_type_ref(renderer, schema, named_names)

  let result_map : Map[String, Json] = Map([])
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
