///|
/// Convert a moon_zod Schema into a TypeScript-interface-style prompt string
/// suitable for LLM system prompts or correction feedback.
///
/// # Example
/// ```mbt nocheck
/// let s = object({
///   "name": string().min(2).max(50),
///   "age": number().int().min(0).max(150),
/// })
///
/// let prompt = schema_to_prompt(s)
/// // {
/// //   name: string,   // 2-50 chars
/// //   age: number,    // int, 0-150
/// // }
/// ```
pub fn schema_to_prompt(schema : Schema) -> String {
  let tp = type_to_prompt(schema, 0)
  let comment = schema_comment(schema)
  if comment.is_empty() {
    tp
  } else {
    tp + "  // " + comment
  }
}

///|
/// Convert a schema with named sub-schemas into a prompt with separate interface definitions.
///
/// Automatically collects all schemas with non-empty names from the input schema tree
/// and generates separate TypeScript interface/type definitions for them.
/// References to named schemas are replaced with just their name.
///
/// # Example
/// ```mbt nocheck
/// let user = object({ "name": string() }).name("User")
///
/// let order = object({ "user": user }).name("Order")
///
/// let prompt = schema_to_prompt_named(order)
/// // export interface User {
/// //   name: string;
/// // }
/// // export interface Order {
/// //   user: User;
/// // }
/// ```
pub fn schema_to_prompt_named(schema : Schema) -> String {
  let named_schemas = collect_named_schemas(schema)
  generate_prompt_with_interfaces(named_schemas)
}

///|
/// Recursively render the TypeScript type string (no comment).
fn type_to_prompt(schema : Schema, indent : Int) -> String {
  match schema.schema_type {
    StringType => "string"
    NumberType => "number"
    BooleanType => "boolean"
    NullType => "null"
    OptionalType(inner) => type_to_prompt(inner, indent) + " | null"
    DefaultType(inner, _) => type_to_prompt(inner, indent) + " | null"
    TransformType(inner, _) => type_to_prompt(inner, indent)
    EnumType(values) => enum_to_prompt(values)
    ArrayType(elem) => type_to_prompt(elem, indent) + "[]"
    UnionType(schemas) => union_to_prompt(schemas, indent)
    IntersectionType(schemas) => intersection_to_prompt(schemas, indent)
    ObjectType(spec, _) => object_to_prompt(spec, indent)
    LiteralType(value) => json_to_ts_literal(value)
  }
}

///|
/// Render an enum as "a" | "b" | "c".
fn enum_to_prompt(values : Array[String]) -> String {
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
/// Render a union as type1 | type2 | ...
fn union_to_prompt(schemas : Array[Schema], indent : Int) -> String {
  let mut result = ""
  let mut first = true
  for s in schemas {
    if first {
      result = type_to_prompt(s, indent)
    } else {
      result = result + " | " + type_to_prompt(s, indent)
    }
    first = false
  }
  result
}

///|
/// Render an intersection as "A & B & C".
fn intersection_to_prompt(schemas : Array[Schema], indent : Int) -> String {
  let mut result = ""
  let mut first = true
  for s in schemas {
    if first {
      result = type_to_prompt(s, indent)
    } else {
      result = result + " & " + type_to_prompt(s, indent)
    }
    first = false
  }
  result
}

///|
/// Render an object as multiline { ... } with 2-space indentation.
fn object_to_prompt(spec : Map[String, Schema], indent : Int) -> String {
  if spec.length() == 0 {
    return "{}"
  }
  let mut result = "{\n"
  let inner_indent = indent + 1
  for key, val_schema in spec {
    let key_is_optional = is_optional_schema(val_schema)
    let inner = if key_is_optional {
      match val_schema.schema_type {
        OptionalType(s) => s
        DefaultType(s, _) => s
        _ => val_schema
      }
    } else {
      val_schema
    }

    let field_type = type_to_prompt(inner, inner_indent)
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
/// Generate n * 2 spaces.
fn indent_str(n : Int) -> String {
  let mut s = ""
  for i = 0; i < n; i = i + 1 {
    s = s + "  "
  }
  s
}

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
/// Build the constraint comment for a schema.
/// For arrays, also merges element-level constraints.
fn schema_comment(schema : Schema) -> String {
  let unwrapped = unwrap_schema(schema)
  let inner = constraint_comment(unwrapped.rules, unwrapped.schema_type)
  let merged = match unwrapped.schema_type {
    ArrayType(elem) => {
      let euw = unwrap_schema(elem)
      let ec = constraint_comment(euw.rules, euw.schema_type)
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
/// Join constraint parts with ", ".
fn join_parts(parts : Array[String]) -> String {
  let mut result = parts[0]
  for i = 1; i < parts.length(); i = i + 1 {
    result = result + ", " + parts[i]
  }
  result
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
fn string_constraint_comment(rules : Array[Rule]) -> String {
  let mut min_len = -1.0
  let mut max_len = -1.0
  let mut format_val = ""
  let mut pattern = ""
  let parts : Array[String] = []
  for rule in rules {
    match rule.annotation {
      Object(map) => {
        if map.contains("minLength") {
          match map.get("minLength") {
            Some(Number(v, ..)) => min_len = v
            _ => ()
          }
        }
        if map.contains("maxLength") {
          match map.get("maxLength") {
            Some(Number(v, ..)) => max_len = v
            _ => ()
          }
        }
        if map.contains("format") {
          match map.get("format") {
            Some(String(s)) => format_val = s
            _ => ()
          }
        }
        if map.contains("pattern") {
          match map.get("pattern") {
            Some(String(s)) => pattern = s
            _ => ()
          }
        }
      }
      _ => ()
    }
    match rule.annotation {
      Null =>
        if rule.message != "String must not be empty" {
          parts.push(rule.message)
        }
      _ => ()
    }
  }
  if min_len >= 0.0 && max_len >= 0.0 {
    parts.push(
      format_double_simple(min_len) +
      "-" +
      format_double_simple(max_len) +
      " chars",
    )
  } else if min_len >= 0.0 {
    parts.push("min: " + format_double_simple(min_len))
  } else if max_len >= 0.0 {
    parts.push("max: " + format_double_simple(max_len))
  }
  if format_val == "email" {
    parts.push("email")
  } else if format_val == "uri" {
    parts.push("url")
  } else if !format_val.is_empty() {
    parts.push(format_val)
  }
  if !pattern.is_empty() {
    parts.push("pattern: " + pattern)
  }
  if parts.is_empty() {
    ""
  } else {
    join_parts(parts)
  }
}

///|
fn number_constraint_comment(rules : Array[Rule]) -> String {
  let mut is_int = false
  let mut is_positive = false
  let mut is_negative = false
  let mut has_min = false
  let mut has_max = false
  let mut minimum = 0.0
  let mut maximum = 0.0
  let mut has_multiple = false
  let mut multiple_of = 0.0
  let parts : Array[String] = []
  for rule in rules {
    match rule.annotation {
      Object(map) => {
        if map.contains("type") {
          match map.get("type") {
            Some(String(s)) => if s == "integer" { is_int = true }
            _ => ()
          }
        }
        if map.contains("exclusiveMinimum") {
          match map.get("exclusiveMinimum") {
            Some(Number(v, ..)) => if v == 0.0 { is_positive = true }
            _ => ()
          }
        }
        if map.contains("exclusiveMaximum") {
          match map.get("exclusiveMaximum") {
            Some(Number(v, ..)) => if v == 0.0 { is_negative = true }
            _ => ()
          }
        }
        if map.contains("minimum") {
          match map.get("minimum") {
            Some(Number(v, ..)) => {
              has_min = true
              minimum = v
            }
            _ => ()
          }
        }
        if map.contains("maximum") {
          match map.get("maximum") {
            Some(Number(v, ..)) => {
              has_max = true
              maximum = v
            }
            _ => ()
          }
        }
        if map.contains("multipleOf") {
          match map.get("multipleOf") {
            Some(Number(v, ..)) => {
              has_multiple = true
              multiple_of = v
            }
            _ => ()
          }
        }
      }
      _ => ()
    }
    match rule.annotation {
      Null => parts.push(rule.message)
      _ => ()
    }
  }
  if is_int {
    parts.push("int")
  }
  if is_positive {
    parts.push("positive")
  }
  if is_negative {
    parts.push("negative")
  }
  if has_min && has_max {
    parts.push(
      format_double_simple(minimum) + "-" + format_double_simple(maximum),
    )
  } else if has_min {
    parts.push("min: " + format_double_simple(minimum))
  } else if has_max {
    parts.push("max: " + format_double_simple(maximum))
  }
  if has_multiple {
    parts.push("multiple of " + format_double_simple(multiple_of))
  }
  if parts.is_empty() {
    ""
  } else {
    join_parts(parts)
  }
}

///|
fn array_constraint_comment(rules : Array[Rule]) -> String {
  let mut min_items = -1.0
  let mut max_items = -1.0
  let parts : Array[String] = []
  for rule in rules {
    match rule.annotation {
      Object(map) => {
        if map.contains("minItems") {
          match map.get("minItems") {
            Some(Number(v, ..)) => min_items = v
            _ => ()
          }
        }
        if map.contains("maxItems") {
          match map.get("maxItems") {
            Some(Number(v, ..)) => max_items = v
            _ => ()
          }
        }
      }
      _ => ()
    }
    match rule.annotation {
      Null => parts.push(rule.message)
      _ => ()
    }
  }
  if min_items >= 0.0 {
    parts.push("min: " + format_double_simple(min_items) + " items")
  }
  if max_items >= 0.0 {
    parts.push("max: " + format_double_simple(max_items) + " items")
  }
  if parts.is_empty() {
    ""
  } else {
    join_parts(parts)
  }
}

///|
fn fallback_constraint_comment(rules : Array[Rule]) -> String {
  let parts : Array[String] = []
  for rule in rules {
    match rule.annotation {
      Null => parts.push(rule.message)
      _ => ()
    }
  }
  if parts.is_empty() {
    ""
  } else {
    join_parts(parts)
  }
}

///|
fn constraint_comment(rules : Array[Rule], base_type : SchemaType) -> String {
  match base_type {
    StringType => string_constraint_comment(rules)
    NumberType => number_constraint_comment(rules)
    ArrayType(_) => array_constraint_comment(rules)
    _ => fallback_constraint_comment(rules)
  }
}

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
  // If this schema has a name, add it (and mark as visited)
  if !schema.name.is_empty() {
    let already_visited = value_in_array(schema.name, visited)
    if !already_visited {
      visited.push(schema.name)
      result.push(schema)
    } else {
      // Already visited, skip to avoid duplicates
      return
    }
  }

  // Recursively collect from nested schemas
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
/// Ensures definitions appear before they are referenced.
fn topological_sort_schemas(named_schemas : Array[Schema]) -> Array[Schema] {
  if named_schemas.is_empty() {
    return named_schemas
  }

  // Build dependency list: Array[(name, dependencies)]
  let deps_list : Array[(String, Array[String])] = []
  for schema in named_schemas {
    let deps = find_schema_dependencies(schema, named_schemas)
    deps_list.push((schema.name, deps))
  }

  // Topological sort using DFS
  let visited_list : Array[(String, Int)] = [] // 0=unvisited, 1=visiting, 2=visited
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
  // Not found, add new entry
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
  // Avoid infinite recursion on circular references
  if value_in_array(schema.name, visited_names) {
    return
  }
  if !schema.name.is_empty() {
    visited_names.push(schema.name)
  }

  // Helper to check if a name exists in schema_map
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
        // If the field schema is named and in schema_map, it's a dependency
        if !field_schema.name.is_empty() &&
          name_exists_in_map(field_schema.name) {
          if !value_in_array(field_schema.name, deps) {
            deps.push(field_schema.name)
          }
        }
        // Also recurse to find transitive dependencies
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
  // Mark as visiting
  visited_set_status(visited, name, 1)

  // Find dependencies for this name
  let mut deps = []
  for i = 0; i < deps_list.length(); i = i + 1 {
    let (n, d) = deps_list[i]
    if n == name {
      deps = d
    }
  }

  // Visit all dependencies first
  for dep_name in deps {
    let status = visited_get_status(visited, dep_name)
    if status == 0 {
      // Unvisited, recurse
      dfs_topo_sort(dep_name, deps_list, visited, sorted, schema_map)
    }
    // Skip if status == 1 (cycle detected) or status == 2 (already visited)
  }

  // After visiting all dependencies, add this schema
  for i = 0; i < schema_map.length(); i = i + 1 {
    let schema = schema_map[i]
    if schema.name == name {
      sorted.push(schema)
    }
  }

  // Mark as visited
  visited_set_status(visited, name, 2)
}

///|
/// Generate the full prompt with interface definitions and the root schema.
fn generate_prompt_with_interfaces(named_schemas : Array[Schema]) -> String {
  // Sort schemas topologically so dependencies come before dependents
  let sorted_schemas = topological_sort_schemas(named_schemas)

  let mut prompt = ""

  // Generate interface definitions for sorted schemas
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

  match schema.schema_type {
    ObjectType(spec, _) =>
      "export interface " +
      schema.name +
      " " +
      object_to_inline_prompt(spec, 0, named_schemas)
    EnumType(values) => "type " + schema.name + " = " + enum_to_prompt(values)
    _ => ""
  }
}

///|
/// Render schema to inline type (for use in object definitions).
/// If schema has a name and is in the named list, render just the name.
fn type_to_inline_prompt(
  schema : Schema,
  indent : Int,
  named_schemas : Array[Schema],
) -> String {
  // Check if this schema is named and in our named schemas list
  if !schema.name.is_empty() {
    for ns in named_schemas {
      if ns.name == schema.name {
        return schema.name
      }
    }
  }

  match schema.schema_type {
    StringType => "string"
    NumberType => "number"
    BooleanType => "boolean"
    NullType => "null"
    OptionalType(inner) =>
      type_to_inline_prompt(inner, indent, named_schemas) + " | null"
    DefaultType(inner, _) =>
      type_to_inline_prompt(inner, indent, named_schemas) + " | null"
    TransformType(inner, _) =>
      type_to_inline_prompt(inner, indent, named_schemas)
    EnumType(values) => enum_to_prompt(values)
    ArrayType(elem) => type_to_inline_prompt(elem, indent, named_schemas) + "[]"
    UnionType(schemas) => union_to_prompt_inline(schemas, indent, named_schemas)
    IntersectionType(schemas) =>
      intersection_to_prompt_inline(schemas, indent, named_schemas)
    ObjectType(spec, _) => object_to_inline_prompt(spec, indent, named_schemas)
    LiteralType(value) => json_to_ts_literal(value)
  }
}

///|
fn union_to_prompt_inline(
  schemas : Array[Schema],
  indent : Int,
  named_schemas : Array[Schema],
) -> String {
  let mut result = ""
  let mut first = true
  for s in schemas {
    if first {
      result = type_to_inline_prompt(s, indent, named_schemas)
    } else {
      result = result + " | " + type_to_inline_prompt(s, indent, named_schemas)
    }
    first = false
  }
  result
}

///|
fn intersection_to_prompt_inline(
  schemas : Array[Schema],
  indent : Int,
  named_schemas : Array[Schema],
) -> String {
  let mut result = ""
  let mut first = true
  for s in schemas {
    if first {
      result = type_to_inline_prompt(s, indent, named_schemas)
    } else {
      result = result + " & " + type_to_inline_prompt(s, indent, named_schemas)
    }
    first = false
  }
  result
}

///|
fn object_to_inline_prompt(
  spec : Map[String, Schema],
  indent : Int,
  named_schemas : Array[Schema],
) -> String {
  if spec.length() == 0 {
    return "{}"
  }
  let mut result = "{\n"
  let inner_indent = indent + 1
  for key, val_schema in spec {
    let key_is_optional = is_optional_schema(val_schema)
    let inner = if key_is_optional {
      match val_schema.schema_type {
        OptionalType(s) => s
        DefaultType(s, _) => s
        _ => val_schema
      }
    } else {
      val_schema
    }

    let field_type = type_to_inline_prompt(inner, inner_indent, named_schemas)
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
