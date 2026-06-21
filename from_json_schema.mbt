///|
/// Convert a JSON Schema (draft-07) document into a moon_zod schema expression.
/// Outputs MoonBit source code that can be copy-pasted into moon_zod projects.
///
/// # Example
/// ```mbt nocheck
/// let schema = @json.parse("{\"type\":\"string\"}").unwrap()
///
/// let code = json_schema_to_moon_zod(schema)
/// // "@moon_zod.string()"
/// ```
pub fn json_schema_to_moon_zod(schema : Json) -> String {
  let defs = extract_defs(schema)
  let mut result = ""

  if defs.length() > 0 {
    // Collect all $defs names
    let all_names : Array[String] = []
    for name, _ in defs {
      all_names.push(name)
    }

    // Build dependency list: (name, refs_to_other_defs)
    let deps_list : Array[(String, Array[String])] = []
    for name in all_names {
      match defs.get(name) {
        Some(def) => deps_list.push((name, find_defs_deps(def, all_names)))
        None => ()
      }
    }

    // Topological sort with cycle detection
    let sorted_cycle = topo_sort_defs(deps_list)
    // (sorted, cycle_names)

    // Generate code in sorted order
    for entry in sorted_cycle {
      let (name, in_cycle) = entry
      match defs.get(name) {
        Some(def) => {
          if !result.is_empty() {
            result = result + "\n\n"
          }
          let code = schema_to_code(def, defs, 0)
          let cycle_comment = if in_cycle {
            "  /* TODO: circular reference — manual fix needed */"
          } else {
            ""
          }
          result = result +
            "let " +
            escape_ident(name) +
            "_schema = " +
            code +
            ".name(\"" +
            escape_mbt_string(name) +
            "\")" +
            cycle_comment
        }
        None => ()
      }
    }
    result = result + "\n\n"
  }

  // Generate root schema code
  let root = schema_to_code(schema, defs, 0)
  result + root
}

///|
/// Scan a JSON value for $ref references to other $defs entries.
fn find_defs_deps(val : Json, defs_names : Array[String]) -> Array[String] {
  let deps : Array[String] = []
  collect_refs(val, defs_names, deps)
  // Deduplicate
  let unique : Array[String] = []
  for d in deps {
    if !value_in_array(d, unique) {
      unique.push(d)
    }
  }
  unique
}

///|
fn collect_refs(
  val : Json,
  defs_names : Array[String],
  deps : Array[String],
) -> Unit {
  match val {
    Object(m) => {
      match m.get("$ref") {
        Some(String(ref_str)) => {
          let name = parse_ref_name(ref_str)
          if value_in_array(name, defs_names) {
            deps.push(name)
          }
        }
        _ => ()
      }
      for _, v in m {
        collect_refs(v, defs_names, deps)
      }
    }
    Array(arr) =>
      for v in arr {
        collect_refs(v, defs_names, deps)
      }
    _ => ()
  }
}

///|
/// Topological sort for $defs names with cycle detection.
/// Returns Array[(name, in_cycle)].
fn topo_sort_defs(
  deps_list : Array[(String, Array[String])],
) -> Array[(String, Bool)] {
  let visited : Array[(String, Int)] = [] // 0=unvisited, 1=visiting, 2=done
  let sorted : Array[String] = []
  let in_cycle_arr : Array[String] = []

  for i = 0; i < deps_list.length(); i = i + 1 {
    let (name, _) = deps_list[i]
    if visited_get(visited, name) == 0 {
      let path : Array[String] = []
      dfs_sort(name, deps_list, visited, sorted, in_cycle_arr, path)
    }
  }

  // Build result: mark each name with cycle status
  let result : Array[(String, Bool)] = []
  for name in sorted {
    result.push((name, value_in_array(name, in_cycle_arr)))
  }
  result
}

///|
fn visited_get(list : Array[(String, Int)], name : String) -> Int {
  for i = 0; i < list.length(); i = i + 1 {
    let (n, s) = list[i]
    if n == name {
      return s
    }
  }
  0
}

///|
fn visited_set(
  list : Array[(String, Int)],
  name : String,
  status : Int,
) -> Unit {
  for i = 0; i < list.length(); i = i + 1 {
    let (n, _) = list[i]
    if n == name {
      list[i] = (name, status)
      return
    }
  }
  list.push((name, status))
}

///|
fn find_deps_for_name(
  name : String,
  list : Array[(String, Array[String])],
) -> Array[String] {
  for i = 0; i < list.length(); i = i + 1 {
    let (n, deps) = list[i]
    if n == name {
      return deps
    }
  }
  []
}

///|
fn dfs_sort(
  name : String,
  deps_list : Array[(String, Array[String])],
  visited : Array[(String, Int)],
  sorted : Array[String],
  in_cycle : Array[String],
  path : Array[String],
) -> Unit {
  visited_set(visited, name, 1)
  path.push(name)

  let deps = find_deps_for_name(name, deps_list)
  for dep in deps {
    let status = visited_get(visited, dep)
    if status == 0 {
      dfs_sort(dep, deps_list, visited, sorted, in_cycle, path)
    } else if status == 1 {
      // Cycle detected — mark all nodes from dep onwards in path
      let mut capture = false
      for p in path {
        if p == dep {
          capture = true
        }
        if capture && !value_in_array(p, in_cycle) {
          in_cycle.push(p)
        }
      }
    }
  }

  // Pop from path
  let _ = path.remove(path.length() - 1)
  visited_set(visited, name, 2)
  sorted.push(name)
}

///|
fn extract_defs(schema : Json) -> Map[String, Json] {
  match schema {
    Object(m) => {
      match m.get("$defs") {
        Some(Object(d)) => return d
        _ => ()
      }
      match m.get("definitions") {
        Some(Object(d)) => return d
        _ => ()
      }
      {}
    }
    _ => {}
  }
}

///|
fn schema_to_code(
  schema : Json,
  defs : Map[String, Json],
  indent : Int,
) -> String {
  match schema {
    Object(m) => {
      // 1. Check $ref
      match m.get("$ref") {
        Some(String(ref_str)) => return ref_to_code(ref_str, defs)
        _ => ()
      }

      // 2. Check enum
      match m.get("enum") {
        Some(Array(values)) => return enum_to_code(values)
        _ => ()
      }

      // 3. Type-based schema
      let has_type = m.contains("type")
      if has_type {
        let base = match m.get("type") {
          Some(String("object")) =>
            match m.get("properties") {
              Some(Object(props)) =>
                object_to_code(props, m.get("required"), defs, indent)
              _ => "@moon_zod.object({})"
            }
          Some(String("array")) => {
            let items_code = match m.get("items") {
              Some(items) => schema_to_code(items, defs, indent + 1)
              None => "@moon_zod.string()  /* TODO: specify items type */"
            }
            "@moon_zod.array(" + items_code + ")"
          }
          Some(String("string")) => "@moon_zod.string()"
          Some(String("number")) => "@moon_zod.number()"
          Some(String("integer")) => "@moon_zod.number().int()"
          Some(String("boolean")) => "@moon_zod.boolean()"
          Some(String("null")) => "@moon_zod.null()"
          _ => "@moon_zod.string()  /* TODO: unknown type */"
        }
        apply_constraints_to_code(base, m)
      } else {
        // 4. Try anyOf / allOf / oneOf
        match m.get("anyOf") {
          Some(Array(schemas)) => {
            let parts = schemas.map(fn(s) { schema_to_code(s, defs, indent) })
            "@moon_zod.union([" + join_with(parts, ", ") + "])"
          }
          _ =>
            match m.get("allOf") {
              Some(Array(schemas)) => {
                let parts = schemas.map(fn(s) {
                  schema_to_code(s, defs, indent)
                })
                "@moon_zod.intersection([" + join_with(parts, ", ") + "])"
              }
              _ =>
                match m.get("oneOf") {
                  Some(Array(schemas)) => {
                    let parts = schemas.map(fn(s) {
                      schema_to_code(s, defs, indent)
                    })
                    "@moon_zod.union([" + join_with(parts, ", ") + "])"
                  }
                  _ => "@moon_zod.string()  /* TODO: unknown schema type */"
                }
            }
        }
      }
    }
    _ => "@moon_zod.string()  /* TODO: expected object schema */"
  }
}

///|
fn ref_to_code(ref_str : String, defs : Map[String, Json]) -> String {
  let name = parse_ref_name(ref_str)
  if defs.contains(name) {
    escape_ident(name) + "_schema"
  } else {
    "@moon_zod.string()  /* TODO: unresolved $ref: " + ref_str + " */"
  }
}

///|
fn parse_ref_name(ref_str : String) -> String {
  // Handle "#/$defs/Name" or "#/definitions/Name"
  let mut last = ""
  for c in ref_str.to_array() {
    if c == '/' {
      last = ""
    } else {
      last = last + c.to_string()
    }
  }
  if last.is_empty() {
    ref_str
  } else {
    last
  }
}

///|
fn enum_to_code(values : Array[Json]) -> String {
  let string_values : Array[String] = []
  for v in values {
    match v {
      String(s) => string_values.push(s)
      _ => ()
    }
  }
  let parts : Array[String] = []
  for s in string_values {
    parts.push("\"" + escape_mbt_string(s) + "\"")
  }
  "@moon_zod.enum_values([" + join_with(parts, ", ") + "])"
}

///|
fn object_to_code(
  props : Map[String, Json],
  required_opt : Json?,
  defs : Map[String, Json],
  indent : Int,
) -> String {
  // Build required set
  let required_set : Map[String, Bool] = {}
  match required_opt {
    Some(Array(reqs)) =>
      for r in reqs {
        match r {
          String(s) => required_set.set(s, true)
          _ => ()
        }
      }
    _ => ()
  }

  if props.length() == 0 {
    return "@moon_zod.object({})"
  }

  let key_names : Array[String] = []
  for key, _ in props {
    key_names.push(key)
  }

  let mut result = "@moon_zod.object({\n"
  for i = 0; i < key_names.length(); i = i + 1 {
    if i > 0 {
      result = result + ",\n"
    }
    let key = key_names[i]
    match props.get(key) {
      Some(field_schema) => {
        let mut field_code = schema_to_code(field_schema, defs, indent + 1)
        if !required_set.contains(key) {
          field_code = field_code + ".optional()"
        }
        result = result +
          pad(indent + 1) +
          "\"" +
          escape_mbt_string(key) +
          "\": " +
          field_code
      }
      None => ()
    }
  }
  result + ",\n" + pad(indent) + "})"
}

///|
fn apply_constraints_to_code(base : String, m : Map[String, Json]) -> String {
  let mut result = base

  // String constraints
  match m.get("minLength") {
    Some(Number(v, ..)) =>
      result = result + ".min(" + format_double_simple(v) + ")"
    _ => ()
  }
  match m.get("maxLength") {
    Some(Number(v, ..)) =>
      result = result + ".max(" + format_double_simple(v) + ")"
    _ => ()
  }
  match m.get("pattern") {
    Some(String(p)) =>
      result = result + ".regex(\"" + escape_mbt_string(p) + "\")"
    _ => ()
  }
  match m.get("format") {
    Some(String("email")) => result = result + ".email()"
    Some(String("uri")) => result = result + ".url()"
    Some(String("date-time")) => result = result + ".datetime()"
    Some(String("ipv4")) => result = result + ".ipv4()"
    Some(String("ipv6")) => result = result + ".ipv6()"
    Some(String("uuid")) => result = result + ".uuid()"
    _ => ()
  }

  // Number constraints
  match m.get("minimum") {
    Some(Number(v, ..)) =>
      result = result + ".min(" + format_double_simple(v) + ")"
    _ => ()
  }
  match m.get("maximum") {
    Some(Number(v, ..)) =>
      result = result + ".max(" + format_double_simple(v) + ")"
    _ => ()
  }
  match m.get("exclusiveMinimum") {
    Some(Number(v, ..)) =>
      if v == 0.0 {
        result = result + ".positive()"
      } else {
        result = result + ".min(" + format_double_simple(v) + ")"
      }
    _ => ()
  }
  match m.get("exclusiveMaximum") {
    Some(Number(v, ..)) =>
      if v == 0.0 {
        result = result + ".negative()"
      } else {
        result = result + ".max(" + format_double_simple(v) + ")"
      }
    _ => ()
  }
  match m.get("multipleOf") {
    Some(Number(v, ..)) =>
      result = result + ".multipleOf(" + format_double_simple(v) + ")"
    _ => ()
  }

  // Array constraints
  match m.get("minItems") {
    Some(Number(v, ..)) =>
      result = result + ".min(" + format_double_simple(v) + ")"
    _ => ()
  }
  match m.get("maxItems") {
    Some(Number(v, ..)) =>
      result = result + ".max(" + format_double_simple(v) + ")"
    _ => ()
  }

  // Default value
  match m.get("default") {
    Some(val) => result = result + ".default(" + json_to_literal(val) + ")"
    _ => ()
  }

  result
}

///|
/// Convert a Json value into a MoonBit Json constructor expression.
fn json_to_literal(val : Json) -> String {
  match val {
    String(s) => "Json::string(\"" + escape_mbt_string(s) + "\")"
    Number(v, ..) => "Json::number(" + format_double_simple(v) + ")"
    True => "Json::true()"
    False => "Json::false()"
    Null => "Json::null()"
    Array(arr) => {
      let parts = arr.map(fn(v) { json_to_literal(v) })
      "Json::array([" + join_with(parts, ", ") + "])"
    }
    Object(map) => {
      let parts : Array[String] = []
      for k, v in map {
        let lit = json_to_literal(v)
        parts.push("\"" + escape_mbt_string(k) + "\": " + lit)
      }
      "Json::object({" + join_with(parts, ", ") + "})"
    }
  }
}

///|
/// Escape special characters for MoonBit string literals.
fn escape_mbt_string(s : String) -> String {
  let mut result = ""
  for c in s.to_array() {
    if c == '\\' {
      result = result + "\\\\"
    } else if c == '"' {
      result = result + "\\\""
    } else if c == '\n' {
      result = result + "\\n"
    } else if c == '\t' {
      result = result + "\\t"
    } else {
      result = result + c.to_string()
    }
  }
  result
}

///|
/// Ensure a name is a valid MoonBit identifier.
fn escape_ident(name : String) -> String {
  let arr = name.to_array()
  let mut result = ""
  for i = 0; i < arr.length(); i = i + 1 {
    let c = arr[i]
    if (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '_' {
      result = result + c.to_string()
    } else {
      result = result + "_"
    }
  }
  // Ensure not starting with digit
  if result.length() > 0 && result[0] >= '0' && result[0] <= '9' {
    result = "_" + result
  }
  result
}

///|
fn join_with(parts : Array[String], sep : String) -> String {
  if parts.is_empty() {
    return ""
  }
  let mut result = parts[0]
  for i = 1; i < parts.length(); i = i + 1 {
    result = result + sep + parts[i]
  }
  result
}

///|
/// Generate n * 2 spaces for indentation.
fn pad(level : Int) -> String {
  let mut spaces = ""
  for i = 0; i < level * 2; i = i + 1 {
    spaces = spaces + " "
  }
  spaces
}
