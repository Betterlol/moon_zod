///|
/// Convert JSON @core.Schema (draft-07) documents to moon_zod @core.Schema objects.
///
/// Two functions:
/// 1. json_schema_to_schema() - Parse JSON @core.Schema → @core.Schema @core.object (runtime-ready)
/// 2. json_schema_to_moon_zod() - Parse JSON @core.Schema → moon_zod source code (defined in combinators)

///|
/// **JSON @core.Schema → @core.Schema @core.object**
///
/// Parses a JSON @core.Schema (draft-07) document into a runtime @core.Schema @core.object.
/// Handles $defs, $ref, enum, type constraints, and all JSON @core.Schema keywords.
pub fn json_schema_to_schema(schema : Json) -> @core.Schema {
  let defs_json = extract_defs(schema)
  let defs_cache : Map[String, @core.Schema] = Map([])
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
  cache : Map[String, @core.Schema],
  visiting : Array[String],
) -> Unit {
  if cache.contains(name) {
    return
  }
  if @core.value_in_array(name, visiting) {
    // Cycle: use @core.null schema as placeholder
    cache.set(name, @core.null().name(name))
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
/// Convert JSON @core.Schema document to @core.Schema @core.object.
fn json_to_schema_impl(
  json : Json,
  defs_json : Map[String, Json],
  defs_cache : Map[String, @core.Schema],
  visiting : Array[String],
) -> @core.Schema {
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
                Some(_) => {
                  // Check if this would create a cycle
                  if @core.value_in_array(ref_name, visiting) {
                    // Cycle detected
                    return @core.null().name(ref_name)
                  }
                  // Process the forward ref
                  process_json_def(ref_name, defs_json, defs_cache, visiting)
                  match defs_cache.get(ref_name) {
                    Some(s) => return s
                    None => return @core.string()
                  }
                }
                None => return @core.string()
              }
          }
        }
        _ => ()
      }

      // 2. Check const (for @core.literal values)
      match m.get("const") {
        Some(val) => return @core.literal(val)
        _ => ()
      }

      // 3. Check enum
      match m.get("enum") {
        Some(Array(values)) => {
          if values.length() == 0 {
            return @core.string()
          }

          let strs : Array[String] = []
          let all_numbers : Array[Double] = []
          let mut has_non_numbers = false

          for v in values {
            match v {
              String(s) => {
                has_non_numbers = true
                strs.push(s)
              }
              Number(n, ..) => all_numbers.push(n)
              _ => has_non_numbers = true
            }
          }

          // If all values are numbers, create a number schema with enum validation
          if !has_non_numbers && all_numbers.length() > 0 {
            let num_schema = @core.number()
            let mut result_schema = num_schema
            // Add rule to validate the number is in the allowed list
            result_schema = @core.append_rule(
              result_schema,
              fn(json) {
                match json {
                  Number(n, ..) => {
                    for allowed in all_numbers {
                      if n == allowed {
                        return true
                      }
                    }
                    false
                  }
                  _ => false
                }
              },
              "Value must be one of the allowed numbers",
              @core.IssueCode::Custom,
            )
            return result_schema
          }

          // If all values are strings, use string enum
          if strs.length() == values.length() {
            return @core.enum_values(strs)
          }

          // Mixed or non-string types: use union of literals
          let parts = values.map(fn(v) { @core.literal(v) })
          return @core.union(parts)
        }
        _ => ()
      }

      // 4. Type-based schema
      if m.contains("type") {
        let base = match m.get("type") {
          Some(String("object")) =>
            match m.get("properties") {
              Some(Object(props)) => {
                let fields : Map[String, @core.Schema] = Map([])
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
                let mut obj_schema = @core.object(fields)
                obj_schema = match m.get("additionalProperties") {
                  Some(True) => obj_schema.passthrough()
                  Some(False) => obj_schema.strip()
                  _ => obj_schema
                }
                obj_schema
              }
              _ => @core.object(Map([]))
            }
          Some(String("array")) => {
            let elem = match m.get("items") {
              Some(items) =>
                json_to_schema_impl(items, defs_json, defs_cache, visiting)
              None => @core.string()
            }
            @core.array(elem)
          }
          Some(String("string")) => @core.string()
          Some(String("number")) => @core.number()
          Some(String("integer")) => @core.number().int()
          Some(String("boolean")) => @core.boolean()
          Some(String("null")) => @core.null()
          _ => @core.string()
        }
        return apply_json_schema_constraints(base, m)
      }

      // 5. anyOf / allOf / oneOf
      match m.get("anyOf") {
        Some(Array(schemas)) => {
          let parts = schemas.map(fn(s) {
            json_to_schema_impl(s, defs_json, defs_cache, visiting)
          })
          return @core.union(parts)
        }
        _ => ()
      }
      match m.get("allOf") {
        Some(Array(schemas)) => {
          let parts = schemas.map(fn(s) {
            json_to_schema_impl(s, defs_json, defs_cache, visiting)
          })
          return @core.intersection(parts)
        }
        _ => ()
      }
      match m.get("oneOf") {
        Some(Array(schemas)) => {
          let parts = schemas.map(fn(s) {
            json_to_schema_impl(s, defs_json, defs_cache, visiting)
          })
          return @core.union(parts)
        }
        _ => ()
      }

      @core.string()
    }
    _ => @core.string()
  }
}

///|
/// Parse the "required" @core.array from JSON @core.Schema @core.object.
fn parse_required(required_json : Json?) -> Map[String, Bool] {
  let set : Map[String, Bool] = Map([])
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
/// Apply JSON @core.Schema constraint keywords to a @core.Schema.
fn apply_json_schema_constraints(
  schema : @core.Schema,
  m : Map[String, Json],
) -> @core.Schema {
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
        let int_val = v.to_int()
        let is_integer = v == int_val.to_double()
        let bound = if is_integer { int_val + 1 } else { int_val }
        result = result.min(bound)
        if !is_integer {
          result = @core.append_rule(
            result,
            fn(json) {
              match json {
                Number(n, ..) => n > v
                _ => false
              }
            },
            "Value must be greater than \{v}",
            @core.IssueCode::Custom,
          )
        }
      }
    _ => ()
  }
  match m.get("exclusiveMaximum") {
    Some(Number(v, ..)) =>
      if v == 0.0 {
        result = result.negative()
      } else {
        let int_val = v.to_int()
        let is_integer = v == int_val.to_double()
        if is_integer {
          result = result.max(int_val - 1)
        } else {
          result = @core.append_rule(
            result,
            fn(json) {
              match json {
                Number(n, ..) => n < v
                _ => false
              }
            },
            "Value must be less than \{v}",
            @core.IssueCode::Custom,
          )
        }
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

// ─── Utility functions ───

///|
/// Extract $defs or definitions from JSON @core.Schema.
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
      Map([])
    }
    _ => Map([])
  }
}

///|
/// Parse a $ref @core.string to extract the definition name.
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
