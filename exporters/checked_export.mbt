///|
/// Select the structural input contract or the parsed output contract.
pub(all) enum SchemaView {
  InputView
  OutputView
} derive(Debug)

///|
#deprecated
pub extend SchemaView with @debug.Debug::{to_repr}

///|
/// Export an explicit structural view, returning unsupported projection errors.
/// A projection describes a stage's JSON shape, not arbitrary callback behavior.
pub fn try_to_json_schema(
  schema : @core.Schema,
  view~ : SchemaView = InputView,
) -> Result[Json, String] {
  let nodes = match @core.try_schema_nodes(schema) {
    Ok(nodes) => nodes
    Err(message) => return Err(message)
  }
  if contains_lazy(schema, Map([])) {
    if view is OutputView {
      return Err(
        "Recursive output projection requires an explicit output schema",
      )
    }
    for node in nodes {
      if node.schema_type is IntersectionType(_) {
        return Err(
          "Recursive intersection input projection requires an explicit input schema",
        )
      }
      if node.schema_type is ObjectType(_, Strip) {
        return Err(
          "Recursive Strip input projection requires an explicit input schema",
        )
      }
      if (
          node.schema_type is TransformType(_, _) ||
          node.schema_type is PipeType(_, _, _)
        ) &&
        !node.rules.is_empty() {
        return Err(
          "Post-effect checks cannot be projected onto recursive raw input",
        )
      }
      if node.schema_type is PreprocessType(_, _) {
        return Err("Preprocess input shape is unknown")
      }
      if node.rules.any(fn(rule) { rule.constraint is Opaque }) {
        return Err("Opaque refinements cannot be represented in JSON Schema")
      }
    }
    return Ok(to_json_schema_named(schema))
  }
  match project_view(schema, view, 0) {
    Ok(projected) => Ok(to_json_schema(projected))
    Err(message) => Err(message)
  }
}

///|
fn project_view(
  schema : @core.Schema,
  view : SchemaView,
  depth : Int32,
) -> Result[@core.Schema, String] {
  if depth > 256 {
    return Err("Schema projection exceeded 256 levels")
  }
  if schema.rules.any(fn(rule) { rule.constraint is Opaque }) {
    return Err("Opaque refinements cannot be represented in JSON Schema")
  }
  let output = view is OutputView
  let schema_type : @core.SchemaType = match schema.schema_type {
    TransformType(inner, closure) => {
      if output {
        if closure.kind is CustomTransform {
          return Err(
            "Custom transform output is unknown; add pipe(output_schema)",
          )
        }
        let present = { ..schema, schema_type: @core.SchemaType::StringType, }
        if @core.output_is_optional(schema) {
          return Ok(present.optional())
        }
        return Ok(present)
      }
      if !schema.rules.is_empty() {
        return Err("Post-transform checks cannot be projected onto raw input")
      }
      return project_view(
        without_inherited_name(schema, inner),
        view,
        depth + 1,
      )
    }
    PreprocessType(_, inner) => {
      if !output {
        return Err("Preprocess input shape is unknown")
      }
      return match
        project_view(without_inherited_name(schema, inner), view, depth + 1) {
        Ok(inner) =>
          Ok({ ..inner, name: schema.name, rules: inner.rules + schema.rules, })
        Err(message) => Err(message)
      }
    }
    PipeType(input, _, target) => {
      if !output && !schema.rules.is_empty() {
        return Err("Pipeline output checks cannot be projected onto raw input")
      }
      let selected = if output { target } else { input }
      match project_view(selected, view, depth + 1) {
        Ok(projected) =>
          return Ok({
            ..projected,
            name: schema.name,
            rules: projected.rules + (if output { schema.rules } else { [] }),
          })
        Err(message) => return Err(message)
      }
    }
    ObjectType(fields, mode) => {
      let projected : Map[String, @core.Schema] = Map([])
      for key, child in fields {
        match project_view(child, view, depth + 1) {
          Ok(child) => projected.set(key, child)
          Err(message) => return Err(message)
        }
      }
      ObjectType(
        projected,
        if !output && mode is Strip {
          Passthrough
        } else {
          mode
        },
      )
    }
    ArrayType(inner) =>
      match project_view(inner, view, depth + 1) {
        Ok(inner) => ArrayType(inner)
        Err(message) => return Err(message)
      }
    OptionalType(inner) =>
      match
        project_view(without_inherited_name(schema, inner), view, depth + 1) {
        Ok(inner) =>
          if output && !@core.output_is_optional(schema) {
            return Ok({
              ..inner,
              name: schema.name,
              rules: inner.rules + schema.rules,
            })
          } else {
            OptionalType(inner)
          }
        Err(message) => return Err(message)
      }
    NullableType(inner) =>
      match
        project_view(without_inherited_name(schema, inner), view, depth + 1) {
        Ok(inner) => NullableType(inner)
        Err(message) => return Err(message)
      }
    DefaultType(inner, value) =>
      match
        project_view(without_inherited_name(schema, inner), view, depth + 1) {
        Ok(inner) =>
          if output {
            UnionType([inner, @core.literal(value)])
          } else {
            DefaultType(inner, value)
          }
        Err(message) => return Err(message)
      }
    PrefaultType(inner, value) =>
      match
        project_view(without_inherited_name(schema, inner), view, depth + 1) {
        Ok(inner) =>
          if output {
            return Ok({
              ..inner,
              name: schema.name,
              rules: inner.rules + schema.rules,
            })
          } else {
            PrefaultType(inner, value)
          }
        Err(message) => return Err(message)
      }
    TupleType(items) =>
      match project_many(items, view, depth) {
        Ok(items) => TupleType(items)
        Err(message) => return Err(message)
      }
    UnionType(items) =>
      match project_many(items, view, depth) {
        Ok(items) => UnionType(items)
        Err(message) => return Err(message)
      }
    IntersectionType(items) => {
      if !output &&
        items.any(fn(child) {
          @core.unwrap_schema(child).schema_type is ObjectType(_, Strict)
        }) {
        return Err(
          "Strict object intersections require a separate input contract",
        )
      }
      match project_many(items, view, depth) {
        Ok(items) => IntersectionType(items)
        Err(message) => return Err(message)
      }
    }
    DiscriminatedUnionType(tag, options) => {
      let projected : Map[String, @core.Schema] = Map([])
      for key, child in options {
        match project_view(child, view, depth + 1) {
          Ok(child) => projected.set(key, child)
          Err(message) => return Err(message)
        }
      }
      DiscriminatedUnionType(tag, projected)
    }
    LazyType(_) =>
      return Err("Use named recursive export for recursive schemas")
    other => other
  }
  Ok({ ..schema, schema_type, })
}

///|
fn project_many(
  items : Array[@core.Schema],
  view : SchemaView,
  depth : Int32,
) -> Result[Array[@core.Schema], String] {
  let projected : Array[@core.Schema] = []
  for child in items {
    match project_view(child, view, depth + 1) {
      Ok(child) => projected.push(child)
      Err(message) => return Err(message)
    }
  }
  Ok(projected)
}
