///|
/// Convert JSON Schema (draft-07) documents to moon_zod Schema objects.
///
/// Two functions:
/// 1. json_schema_to_schema() - Parse JSON Schema → Schema object (runtime-ready)
/// 2. json_schema_to_moon_zod() - Parse JSON Schema → moon_zod source code (uses layer 2)

///|
/// **Layer 1 (Bottom): JSON Schema → Schema object**
///
/// Parses a JSON Schema (draft-07) document into a runtime Schema object.
/// Handles $defs, $ref, enum, type constraints, and all JSON Schema keywords.
pub fn json_schema_to_schema(schema : Json) -> Schema {
  let defs_json = extract_defs(schema)
  let defs_cache : Map[String, Schema] = {}
  let visiting : Array[String] = []

  // First pass: Process all $defs to build cache
  // This ensures all named schemas are available for $ref resolution
  for def_name, _ in defs_json {
    if !defs_cache.contains(def_name) {
      process_json_def(def_name, defs_json, defs_cache, visiting)
    }
  }

  json_to_schema_impl(schema, defs_json, defs_cache, visiting)
}

///|
/// Recursively process a single $def with cycle detection.
fn process_json_def(
  name : String,
  defs_json : Map[String, Json],
  cache : Map[String, Schema],
  visiting : Array[String],
) -> Unit {
  if cache.contains(name) {
    return
  }
  if value_in_array(name, visiting) {
    // Cycle: use null schema as placeholder
    cache.set(name, null().name(name))
    return
  }

  visiting.push(name)
  match defs_json.get(name) {
    Some(def) => {
      let schema = json_to_schema_impl(def, defs_json, cache, visiting)
      cache.set(name, schema.name(name))
    }
    None => ()
  }
  // Remove from visiting
  for i = 0; i < visiting.length(); i = i + 1 {
    if visiting[i] == name {
      let _ = visiting.remove(i)
      break
    }
  }
}

///|
/// Convert JSON Schema document to Schema object.
fn json_to_schema_impl(
  json : Json,
  defs_json : Map[String, Json],
  defs_cache : Map[String, Schema],
  visiting : Array[String],
) -> Schema {
  match json {
    Object(m) => {
      // 1. Check $ref
      match m.get("$ref") {
        Some(String(ref_str)) => {
          let ref_name = parse_ref_name(ref_str)
          match defs_cache.get(ref_name) {
            Some(s) => return s
            None =>
              // Ref not yet processed, check for forward ref or cycle
              match defs_json.get(ref_name) {
                Some(def) => {
                  // Check if this would create a cycle
                  if value_in_array(ref_name, visiting) {
                    // Cycle detected
                    return null().name(ref_name)
                  }
                  // Process the forward ref
                  process_json_def(ref_name, defs_json, defs_cache, visiting)
                  match defs_cache.get(ref_name) {
                    Some(s) => return s
                    None => return string()
                  }
                }
                None => return string()
              }
          }
        }
        _ => ()
      }

      // 2. Check const (for literal values)
      match m.get("const") {
        Some(val) => return literal(val)
        _ => ()
      }

      // 3. Check enum
      match m.get("enum") {
        Some(Array(values)) => {
          let strs : Array[String] = []
          for v in values {
            match v {
              String(s) => strs.push(s)
              _ => ()
            }
          }
          return enum_values(strs)
        }
        _ => ()
      }

      // 4. Type-based schema
      if m.contains("type") {
        let base = match m.get("type") {
          Some(String("object")) =>
            match m.get("properties") {
              Some(Object(props)) => {
                let fields : Map[String, Schema] = {}
                let required_set = parse_required(m.get("required"))
                for key, field_json in props {
                  let mut field = json_to_schema_impl(
                    field_json, defs_json, defs_cache, visiting,
                  )
                  if !required_set.contains(key) {
                    field = field.optional()
                  }
                  fields.set(key, field)
                }
                object(fields)
              }
              _ => object({})
            }
          Some(String("array")) => {
            let elem = match m.get("items") {
              Some(items) =>
                json_to_schema_impl(items, defs_json, defs_cache, visiting)
              None => string()
            }
            array(elem)
          }
          Some(String("string")) => string()
          Some(String("number")) => number()
          Some(String("integer")) => number().int()
          Some(String("boolean")) => boolean()
          Some(String("null")) => null()
          _ => string()
        }
        return apply_json_schema_constraints(base, m)
      }

      // 5. anyOf / allOf / oneOf
      match m.get("anyOf") {
        Some(Array(schemas)) => {
          let parts = schemas.map(fn(s) {
            json_to_schema_impl(s, defs_json, defs_cache, visiting)
          })
          return union(parts)
        }
        _ => ()
      }
      match m.get("allOf") {
        Some(Array(schemas)) => {
          let parts = schemas.map(fn(s) {
            json_to_schema_impl(s, defs_json, defs_cache, visiting)
          })
          return intersection(parts)
        }
        _ => ()
      }
      match m.get("oneOf") {
        Some(Array(schemas)) => {
          let parts = schemas.map(fn(s) {
            json_to_schema_impl(s, defs_json, defs_cache, visiting)
          })
          return union(parts)
        }
        _ => ()
      }

      string()
    }
    _ => string()
  }
}

///|
/// Parse the "required" array from JSON Schema object.
fn parse_required(required_json : Json?) -> Map[String, Bool] {
  let set : Map[String, Bool] = {}
  match required_json {
    Some(Array(reqs)) =>
      for r in reqs {
        match r {
          String(s) => set.set(s, true)
          _ => ()
        }
      }
    _ => ()
  }
  set
}

///|
/// Apply JSON Schema constraint keywords to a Schema.
fn apply_json_schema_constraints(
  schema : Schema,
  m : Map[String, Json],
) -> Schema {
  let mut result = schema

  // String/Array length constraints
  match m.get("minLength") {
    Some(Number(v, ..)) => result = result.min(v.to_int())
    _ => ()
  }
  match m.get("maxLength") {
    Some(Number(v, ..)) => result = result.max(v.to_int())
    _ => ()
  }
  match m.get("pattern") {
    Some(String(p)) => result = result.regex(p)
    _ => ()
  }
  match m.get("format") {
    Some(String("email")) => result = result.email()
    Some(String("uri")) => result = result.url()
    Some(String("date-time")) => result = result.datetime()
    Some(String("ipv4")) => result = result.ipv4()
    Some(String("ipv6")) => result = result.ipv6()
    Some(String("uuid")) => result = result.uuid()
    _ => ()
  }

  // Number constraints
  match m.get("minimum") {
    Some(Number(v, ..)) => result = result.min(v.to_int())
    _ => ()
  }
  match m.get("maximum") {
    Some(Number(v, ..)) => result = result.max(v.to_int())
    _ => ()
  }
  match m.get("exclusiveMinimum") {
    Some(Number(v, ..)) =>
      if v == 0.0 {
        result = result.positive()
      } else {
        result = result.min(v.to_int())
      }
    _ => ()
  }
  match m.get("exclusiveMaximum") {
    Some(Number(v, ..)) =>
      if v == 0.0 {
        result = result.negative()
      } else {
        result = result.max(v.to_int())
      }
    _ => ()
  }
  match m.get("multipleOf") {
    Some(Number(v, ..)) => result = result.multipleOf(v.to_int())
    _ => ()
  }

  // Array constraints
  match m.get("minItems") {
    Some(Number(v, ..)) => result = result.min(v.to_int())
    _ => ()
  }
  match m.get("maxItems") {
    Some(Number(v, ..)) => result = result.max(v.to_int())
    _ => ()
  }

  // Default value
  match m.get("default") {
    Some(val) => result = result.default(val)
    _ => ()
  }

  result
}

///|
/// **Layer 3 (Top): JSON Schema → moon_zod source code**
///
/// Generates MoonBit source code by:
/// 1. Converting JSON Schema to Schema objects (Layer 1)
/// 2. Converting Schema objects to code (Layer 2 in exporters/prompt.mbt)
///
/// # Example
/// ```mbt nocheck
/// let schema = @json.parse("{\"type\":\"string\",\"minLength\":3}").unwrap()
///
/// let code = json_schema_to_moon_zod(schema)
/// // "@moon_zod.string().min(3)"
/// ```
pub fn json_schema_to_moon_zod(schema : Json) -> String {
  let schema_obj = json_schema_to_schema(schema)
  let named_defs = schema_to_moon_zod_code_named(schema_obj)
  named_defs
}

// ─── Utility functions ───

///|
/// Extract $defs or definitions from JSON Schema.
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
/// Parse a $ref string to extract the definition name.
fn parse_ref_name(ref_str : String) -> String {
  let arr = ref_str.to_array()
  let mut last = ""
  for c in arr {
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
/// Check if a schema has circular self-reference.
fn has_circular_ref(schema : Schema) -> Bool {
  let visited : Array[String] = []
  check_circular(schema, schema.name, visited)
}

///|
fn check_circular(
  schema : Schema,
  target : String,
  visited : Array[String],
) -> Bool {
  match schema.schema_type {
    ObjectType(fields, _) => {
      for _key, field in fields {
        if check_circular(field, target, visited) {
          return true
        }
      }
      false
    }
    ArrayType(elem) => check_circular(elem, target, visited)
    OptionalType(inner) | DefaultType(inner, _) | TransformType(inner, _) =>
      check_circular(inner, target, visited)
    UnionType(schemas) | IntersectionType(schemas) => {
      for s in schemas {
        if check_circular(s, target, visited) {
          return true
        }
      }
      false
    }
    _ =>
      if !schema.name.is_empty() && schema.name == target {
        true
      } else {
        false
      }
  }
}

///|
fn join_lines(lines : Array[String]) -> String {
  if lines.is_empty() {
    return ""
  }
  let mut result = lines[0]
  for i = 1; i < lines.length(); i = i + 1 {
    result = result + "\n" + lines[i]
  }
  result
}
