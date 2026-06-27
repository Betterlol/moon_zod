///|
/// Shared utility functions for Schema rendering and code generation.
///
/// This module contains utility functions shared across prompt.mbt,
/// json_schema.mbt, moonbit_struct.mbt, and constraint_extractor.mbt.

///|
/// Peel OptionalType / DefaultType / TransformType wrappers to find the
/// innermost schema that carries the actual rules.
fn unwrap_schema(schema : Schema) -> Schema {
  match schema.schema_type {
    OptionalType(inner) => unwrap_schema(inner)
    DefaultType(inner, _) => unwrap_schema(inner)
    TransformType(inner, _) => unwrap_schema(inner)
    _ => schema
  }
}

///|
/// Peel OptionalType / DefaultType wrappers to check optionality.
fn peel_optional(schema : Schema) -> Schema {
  match schema.schema_type {
    OptionalType(s) | DefaultType(s, _) => s
    _ => schema
  }
}

///|
/// Generate n * 2 spaces.
fn indent_str(n : Int) -> String {
  let mut s = ""
  for i = 0; i < n; i = i + 1 {
    s = s + "  "
  }
  s
}

///|
/// Format a Double as a string, stripping ".0" for whole numbers.
fn format_double_simple(v : Double) -> String {
  if v == v.to_int().to_double() {
    v.to_int().to_string()
  } else {
    v.to_string()
  }
}

///|
/// Join constraint parts with ", ".
fn join_parts(parts : Array[String]) -> String {
  let mut result = parts[0]
  for i = 1; i < parts.length(); i = i + 1 {
    result = result + ", " + parts[i]
  }
  result
}

// ── Named schema collection and topological sort ──

///|
/// Collect all named schemas from the input schema tree.
fn collect_named_schemas(schema : Schema) -> Array[Schema] {
  let visited : Array[String] = []
  let result : Array[Schema] = []
  collect_named_schemas_impl(schema, visited, result)
  result
}

///|
fn collect_named_schemas_impl(
  schema : Schema,
  visited : Array[String],
  result : Array[Schema],
) -> Unit {
  if !schema.name.is_empty() {
    let already_visited = value_in_array(schema.name, visited)
    if !already_visited {
      visited.push(schema.name)
      result.push(schema)
    } else {
      return
    }
  }

  match schema.schema_type {
    ObjectType(fields, _) =>
      for _key, field_schema in fields {
        collect_named_schemas_impl(field_schema, visited, result)
      }
    ArrayType(elem) => collect_named_schemas_impl(elem, visited, result)
    OptionalType(inner) => collect_named_schemas_impl(inner, visited, result)
    DefaultType(inner, _) => collect_named_schemas_impl(inner, visited, result)
    TransformType(inner, _) =>
      collect_named_schemas_impl(inner, visited, result)
    UnionType(schemas) =>
      for s in schemas {
        collect_named_schemas_impl(s, visited, result)
      }
    IntersectionType(schemas) =>
      for s in schemas {
        collect_named_schemas_impl(s, visited, result)
      }
    _ => ()
  }
}

///|
/// Topologically sort named schemas so dependents come before dependees.
fn topological_sort_schemas(named_schemas : Array[Schema]) -> Array[Schema] {
  if named_schemas.is_empty() {
    return named_schemas
  }

  let deps_list : Array[(String, Array[String])] = []
  for schema in named_schemas {
    let deps = find_schema_dependencies(schema, named_schemas)
    deps_list.push((schema.name, deps))
  }

  let visited_list : Array[(String, Int)] = []
  let sorted : Array[Schema] = []

  for schema in named_schemas {
    if !visited_contains(visited_list, schema.name) {
      dfs_topo_sort(schema.name, deps_list, visited_list, sorted, named_schemas)
    }
  }

  sorted
}

///|
/// Helper: check if a name is in visited list
fn visited_contains(visited_list : Array[(String, Int)], name : String) -> Bool {
  for i = 0; i < visited_list.length(); i = i + 1 {
    let (n, _status) = visited_list[i]
    if n == name {
      return true
    }
  }
  false
}

///|
/// Helper: get status from visited list (0 = unvisited by default)
fn visited_get_status(
  visited_list : Array[(String, Int)],
  name : String,
) -> Int {
  for i = 0; i < visited_list.length(); i = i + 1 {
    let (n, status) = visited_list[i]
    if n == name {
      return status
    }
  }
  0
}

///|
/// Helper: set status in visited list
fn visited_set_status(
  visited_list : Array[(String, Int)],
  name : String,
  status : Int,
) -> Unit {
  for i = 0; i < visited_list.length(); i = i + 1 {
    let (n, _) = visited_list[i]
    if n == name {
      visited_list[i] = (name, status)
      return
    }
  }
  visited_list.push((name, status))
}

///|
/// Find all named schema dependencies within a schema.
fn find_schema_dependencies(
  schema : Schema,
  schema_map : Array[Schema],
) -> Array[String] {
  let deps : Array[String] = []
  let visited_names : Array[String] = []
  find_schema_dependencies_impl(schema, schema_map, deps, visited_names)
  deps
}

///|
fn find_schema_dependencies_impl(
  schema : Schema,
  schema_map : Array[Schema],
  deps : Array[String],
  visited_names : Array[String],
) -> Unit {
  if value_in_array(schema.name, visited_names) {
    return
  }
  if !schema.name.is_empty() {
    visited_names.push(schema.name)
  }

  let name_exists_in_map = fn(name : String) {
    for s in schema_map {
      if s.name == name {
        return true
      }
    }
    false
  }

  match schema.schema_type {
    ObjectType(fields, _) =>
      for _key, field_schema in fields {
        if !field_schema.name.is_empty() &&
          name_exists_in_map(field_schema.name) {
          if !value_in_array(field_schema.name, deps) {
            deps.push(field_schema.name)
          }
        }
        find_schema_dependencies_impl(
          field_schema, schema_map, deps, visited_names,
        )
      }
    ArrayType(elem) => {
      if !elem.name.is_empty() && name_exists_in_map(elem.name) {
        if !value_in_array(elem.name, deps) {
          deps.push(elem.name)
        }
      }
      find_schema_dependencies_impl(elem, schema_map, deps, visited_names)
    }
    OptionalType(inner) =>
      find_schema_dependencies_impl(inner, schema_map, deps, visited_names)
    DefaultType(inner, _) =>
      find_schema_dependencies_impl(inner, schema_map, deps, visited_names)
    TransformType(inner, _) =>
      find_schema_dependencies_impl(inner, schema_map, deps, visited_names)
    UnionType(schemas) =>
      for s in schemas {
        if !s.name.is_empty() && name_exists_in_map(s.name) {
          if !value_in_array(s.name, deps) {
            deps.push(s.name)
          }
        }
        find_schema_dependencies_impl(s, schema_map, deps, visited_names)
      }
    IntersectionType(schemas) =>
      for s in schemas {
        if !s.name.is_empty() && name_exists_in_map(s.name) {
          if !value_in_array(s.name, deps) {
            deps.push(s.name)
          }
        }
        find_schema_dependencies_impl(s, schema_map, deps, visited_names)
      }
    _ => ()
  }
}

///|
/// DFS for topological sorting. Adds schemas to sorted list in dependency order.
fn dfs_topo_sort(
  name : String,
  deps_list : Array[(String, Array[String])],
  visited : Array[(String, Int)],
  sorted : Array[Schema],
  schema_map : Array[Schema],
) -> Unit {
  visited_set_status(visited, name, 1)

  let mut deps = []
  for i = 0; i < deps_list.length(); i = i + 1 {
    let (n, d) = deps_list[i]
    if n == name {
      deps = d
    }
  }

  for dep_name in deps {
    let status = visited_get_status(visited, dep_name)
    if status == 0 {
      dfs_topo_sort(dep_name, deps_list, visited, sorted, schema_map)
    }
  }

  for i = 0; i < schema_map.length(); i = i + 1 {
    let schema = schema_map[i]
    if schema.name == name {
      sorted.push(schema)
    }
  }

  visited_set_status(visited, name, 2)
}

///|
/// Filter named schemas based on `include_names` optional parameter.
/// If `include_names` is `None`, returns all schemas.
/// If `Some(names)`, returns only schemas whose names are in the list.
fn filter_named_schemas(
  all_named : Array[Schema],
  include_names : Array[String]?,
) -> Array[Schema] {
  match include_names {
    None => all_named
    Some(names) => {
      let filtered : Array[Schema] = []
      for ns in all_named {
        for name in names {
          if ns.name == name {
            filtered.push(ns)
            break
          }
        }
      }
      filtered
    }
  }
}
