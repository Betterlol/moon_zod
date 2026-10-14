///|
let schema_counter : Ref[Int32] = Ref(0)

///|
fn new_schema_id() -> Int32 {
  schema_counter.val = schema_counter.val + 1
  schema_counter.val
}

///|
/// Return every immediate child, including tuples, pipelines and lazy nodes.
pub fn schema_children(schema : Schema) -> Array[Schema] {
  match schema.schema_type {
    ObjectType(fields, _) => fields.values().collect()
    ArrayType(inner)
    | OptionalType(inner)
    | NullableType(inner)
    | DefaultType(inner, _)
    | PrefaultType(inner, _)
    | PreprocessType(_, inner)
    | TransformType(inner, _) => [inner]
    TupleType(items) | UnionType(items) | IntersectionType(items) =>
      items.copy()
    DiscriminatedUnionType(_, options) => options.values().collect()
    PipeType(input, _, output) => [input, output]
    LazyType(resolve) => [resolve()]
    _ => []
  }
}

///|
/// Collect named nodes with checked duplicate-name and recursive-expansion errors.
pub fn try_collect_named_schemas(
  schema : Schema,
) -> Result[Array[Schema], String] {
  let names : Map[String, Schema] = Map([])
  let nodes : Map[Int32, Bool] = Map([])
  let result : Array[Schema] = []
  match walk_named(schema, "", false, 0, names, nodes, result, []) {
    Ok(_) => Ok(result)
    Err(message) => Err(message)
  }
}

///|
fn walk_named(
  schema : Schema,
  ignore_name : String,
  lazy_reference : Bool,
  depth : Int32,
  names : Map[String, Schema],
  nodes : Map[Int32, Bool],
  result : Array[Schema],
  all_nodes : Array[Schema],
) -> Result[Unit, String] {
  if depth > 256 {
    return Err(
      "Schema traversal exceeded 256 levels; name recursive definitions to export references",
    )
  }
  if !schema.name.is_empty() && schema.name != ignore_name {
    match names.get(schema.name) {
      Some(previous) => {
        if previous.id == schema.id &&
          lazy_reference &&
          schema.schema_type is LazyType(_) {
          return Err("Recursive definition must resolve to a concrete schema")
        }
        if previous.id != schema.id &&
          !(lazy_reference && nodes.get(previous.id) is Some(true)) {
          return Err("Different schemas share the export name: " + schema.name)
        }
        return Ok(())
      }
      None => {
        names.set(schema.name, schema)
        result.push(schema)
      }
    }
  }
  match nodes.get(schema.id) {
    Some(true) =>
      return Err("Anonymous recursive cycle requires a named definition")
    Some(false) => return Ok(())
    None => ()
  }
  nodes.set(schema.id, true)
  all_nodes.push(schema)
  let transparent = match schema.schema_type {
    OptionalType(_)
    | NullableType(_)
    | DefaultType(_, _)
    | PrefaultType(_, _)
    | TransformType(_, _)
    | PreprocessType(_, _) => true
    _ => false
  }
  let lazy_reference = schema.schema_type is LazyType(_)
  for index, child in schema_children(schema) {
    let inherited_input = schema.schema_type is PipeType(_, _, _) && index == 0
    let ignored = if transparent || inherited_input { schema.name } else { "" }
    match
      walk_named(
        child,
        ignored,
        lazy_reference,
        depth + 1,
        names,
        nodes,
        result,
        all_nodes,
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  nodes.set(schema.id, false)
  Ok(())
}

///|
fn gather_dependencies(
  schema : Schema,
  available : Array[Schema],
  deps : Array[String],
  nodes : Map[Int32, Bool],
  depth : Int32,
) -> Unit {
  if depth > 256 {
    abort("Anonymous recursive schema cannot be topologically sorted")
  }
  if nodes.contains(schema.id) {
    return
  }
  nodes.set(schema.id, true)
  let transparent = match schema.schema_type {
    OptionalType(_)
    | NullableType(_)
    | DefaultType(_, _)
    | PrefaultType(_, _)
    | TransformType(_, _)
    | PreprocessType(_, _) => true
    _ => false
  }
  for index, child in schema_children(schema) {
    let inherited_input = schema.schema_type is PipeType(_, _, _) && index == 0
    if !child.name.is_empty() &&
      !((transparent || inherited_input) && child.name == schema.name) &&
      available.any(fn(node) { node.name == child.name }) {
      if !deps.contains(child.name) {
        deps.push(child.name)
      }
    } else {
      gather_dependencies(child, available, deps, nodes, depth + 1)
    }
  }
}

///|
/// Checked complete graph traversal for exporters and other schema consumers.
pub fn try_schema_nodes(schema : Schema) -> Result[Array[Schema], String] {
  let result : Array[Schema] = []
  match walk_named(schema, "", false, 0, Map([]), Map([]), [], result) {
    Ok(_) => Ok(result)
    Err(message) => Err(message)
  }
}

///|
/// Whether a successful parse of a missing field can leave that field absent.
pub fn output_is_optional(schema : Schema) -> Bool {
  output_optional_impl(schema, Map([]), 0)
}

///|
fn output_optional_impl(
  schema : Schema,
  visited : Map[Int32, Bool],
  depth : Int32,
) -> Bool {
  if depth > 256 || visited.contains(schema.id) {
    return false
  }
  visited.set(schema.id, true)
  match schema.schema_type {
    OptionalType(inner) =>
      !missing_default_impl(inner, visited.copy(), depth + 1) ||
      output_optional_impl(inner, visited, depth + 1)
    NullableType(inner) | TransformType(inner, _) | PreprocessType(_, inner) =>
      output_optional_impl(inner, visited, depth + 1)
    LazyType(resolve) => output_optional_impl(resolve(), visited, depth + 1)
    DefaultType(_, _) | PrefaultType(_, _) => false
    PipeType(input, _, output) =>
      output_optional_impl(input, visited.copy(), depth + 1) &&
      output_optional_impl(output, visited, depth + 1)
    UnionType(branches) =>
      branches.any(fn(child) {
        output_optional_impl(child, visited.copy(), depth + 1)
      })
    IntersectionType(branches) =>
      branches.all(fn(child) {
        output_optional_impl(child, visited.copy(), depth + 1)
      })
    _ => false
  }
}
