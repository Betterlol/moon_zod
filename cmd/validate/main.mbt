///|
/// MoonBit Schema Validator — Validate JSON data against a JSON Schema.
///
/// Usage:
///   moon run cmd/validate -- '<schema_file>' '<data_file>'
///   moon run cmd/validate -- --schema '<schema.json>' '<data.json>'
///   moon run cmd/validate -- --help
///
/// Examples:
///   moon run cmd/validate -- '{"name":"Alice"}' '{"name":"Bob"}'
///   moon run cmd/validate -- --schema '{"type":"string","minLength":1}' '"hello"'
fn print_help() -> Unit {
  println("MoonBit Schema Validator")
  println("")
  println("Usage:")
  println("  moon run cmd/validate -- '<sample.json>' '<data.json>'")
  println("    (infer schema from sample, validate data)")
  println("  moon run cmd/validate -- --schema '<schema.json>' '<data.json>'")
  println("    (use JSON Schema document, validate data)")
  println("  moon run cmd/validate -- --inline-schema '<schema>' '<data>'")
  println("    (inline JSON Schema string, validate data)")
  println("")
  println("Output:")
  println("  PASS: no output, exit code 0")
  println("  FAIL: error details, exit code 1")
  println("  ERROR: usage error, exit code 2")
}

///|
fn main raise {
  let args = @env.args()

  if args.length() < 2 || args[1] == "--help" {
    print_help()
    return
  }

  // Check mode: --schema or --inline-schema
  if args.length() >= 4 &&
    (args[1] == "--schema" || args[1] == "--inline-schema") {
    let schema_raw = args[2]
    let data_raw = args[3]
    let schema_json = try! @json.parse(schema_raw)
    let schema = @moon_zod.json_schema_to_schema(schema_json)
    validate(schema, data_raw)
    return
  }

  // Default mode: infer from sample
  if args.length() < 3 {
    println("Error: missing arguments")
    println("Usage: moon run cmd/validate -- '<sample.json>' '<data.json>'")
    return
  }

  let sample_raw = args[1]
  let data_raw = args[2]

  let sample_json = try! @json.parse(sample_raw)

  let schema = infer_schema(sample_json)

  validate(schema, data_raw)
}

///|
fn infer_schema(json : Json) -> @moon_zod.Schema {
  json_to_schema(json, "GeneratedStruct")
}

///|
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

///|
fn validate(schema : @moon_zod.Schema, data_raw : String) -> Unit {
  let is_jsonl = data_raw.contains("\n")

  if is_jsonl {
    validate_jsonl(schema, data_raw)
  } else {
    validate_single(schema, data_raw)
  }
}

///|
fn validate_single(schema : @moon_zod.Schema, data_raw : String) -> Unit {
  let data_json = try! @json.parse(data_raw)

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
          continue
        }
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
