///|
/// MoonBit Struct Validator — Validate JSON against a schema inferred from sample data.
///
/// Usage:
///   moon run cmd/validate -- '<sample.json>' '<data.json>'
///   moon run cmd/validate -- '<sample.json>' '<data.jsonl>'  # JSON Lines
///   moon run cmd/validate -- --help
///
/// Examples:
///   moon run cmd/validate -- '{"name":"Alice"}' '{"name":"Bob"}'
///   moon run cmd/validate -- '{"name":"Alice"}' '{"name":"Bob"}\n{"name":"Eve"}'
fn main {
  let args = @env.args()
  if args.length() < 2 || args[1] == "--help" {
    println("MoonBit Struct Validator")
    println("")
    println("Usage:")
    println("  moon run cmd/validate -- '<sample.json>' '<data.json>'")
    println(
      "  moon run cmd/validate -- '<sample.json>' '<data.jsonl>'  # JSON Lines",
    )
    println("  moon run cmd/validate -- --help")
    println("")
    println("Modes:")
    println("  (default)  Infer schema from sample JSON, validate data JSON")
    println("")
    println("Output:")
    println("  PASS: no output, exit code 0")
    println("  FAIL: error details, exit code 1")
    println("  ERROR: usage error, exit code 2")
    return
  }

  if args.length() < 3 {
    println("Error: missing arguments")
    println("Usage: moon run cmd/validate -- '<sample.json>' '<data.json>'")
    return
  }

  let sample_raw = args[1]
  let data_raw = args[2]

  let sample_json = @json.parse(sample_raw) catch {
    _ => {
      println("Error: invalid JSON in sample")
      return
    }
  }

  let schema = json_to_schema(sample_json, "InferredSchema")

  // Check if data looks like JSON Lines (contains newlines)
  let is_jsonl = data_raw.contains("\n")

  if is_jsonl {
    validate_jsonl(schema, data_raw)
  } else {
    validate_single(schema, data_raw)
  }
}

///|
fn validate_single(schema : @moon_zod.Schema, data_raw : String) -> Unit {
  let data_json = @json.parse(data_raw) catch {
    _ => {
      println("Error: invalid JSON in data")
      return
    }
  }

  match schema.parse(data_json) {
    Ok(_) => println("PASS")
    Err(errors) => {
      println("FAIL")
      for e in errors {
        println("  [\{e.path}] \{e.message} (got: \{@debug.to_string(e.got)})")
      }
    }
  }
}

///|
fn validate_jsonl(schema : @moon_zod.Schema, data_raw : String) -> Unit {
  let lines = data_raw.split("\n")
  let mut pass_count = 0
  let mut fail_count = 0
  let mut line_num = 0

  for line in lines {
    line_num = line_num + 1
    let trimmed = line.trim()
    if trimmed.is_empty() {
      // Skip empty lines
    } else {
      let data_json = @json.parse(trimmed) catch {
        _ => {
          println("FAIL: line \{line_num} - invalid JSON")
          fail_count = fail_count + 1
          Json::null()
        }
      }
      // Skip if JSON parse failed (caught above)
      if data_json is Null && fail_count > 0 {
        continue
      }
      match schema.parse(data_json) {
        Ok(_) => pass_count = pass_count + 1
        Err(errors) => {
          println("FAIL: line \{line_num}")
          for e in errors {
            println(
              "  [\{e.path}] \{e.message} (got: \{@debug.to_string(e.got)})",
            )
          }
          fail_count = fail_count + 1
        }
      }
    }
  }

  println("Results: \{pass_count} passed, \{fail_count} failed")
}

///|
/// Infer a moon_zod Schema from a JSON value.
fn json_to_schema(json : Json, name_hint : String) -> @moon_zod.Schema {
  match json {
    String(_) => @moon_zod.string()
    Number(v, ..) =>
      if v == v.to_int().to_double() {
        @moon_zod.number().int()
      } else {
        @moon_zod.number()
      }
    True | False => @moon_zod.boolean()
    Null => @moon_zod.null()
    Array(elements) => {
      let elem_schema = if elements.length() > 0 {
        json_to_schema(elements[0], name_hint + "Element")
      } else {
        @moon_zod.string()
      }
      @moon_zod.array(elem_schema)
    }
    Object(map) => {
      let fields : Map[String, @moon_zod.Schema] = {}
      for key, val in map {
        let field_name = auto_struct_name(key)
        let field_schema = json_to_schema(val, field_name)
        fields.set(key, field_schema)
      }
      @moon_zod.object(fields).name(name_hint)
    }
  }
}

///|
/// Convert a JSON key to a PascalCase struct name.
fn auto_struct_name(key : String) -> String {
  let arr = key.to_array()
  let mut result = ""
  let mut capitalize_next = true
  for i = 0; i < arr.length(); i = i + 1 {
    let c = arr[i]
    if (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') {
      if capitalize_next {
        if c >= 'a' && c <= 'z' {
          let code = c.to_int()
          let upper = (code - 32).to_char()
          match upper {
            Some(ch) => result = result + ch.to_string()
            None => result = result + c.to_string()
          }
        } else {
          result = result + c.to_string()
        }
        capitalize_next = false
      } else {
        result = result + c.to_string()
      }
    } else if c == '_' || c == '-' || c == ' ' {
      capitalize_next = true
    }
  }

  if result.is_empty() {
    result = "Field"
  } else {
    let first = result[0]
    if !((first >= 'a' && first <= 'z') || (first >= 'A' && first <= 'Z')) {
      result = "F" + result
    }
  }

  result
}
