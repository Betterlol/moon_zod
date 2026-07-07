///|
/// MoonBit Schema Validator — Validate JSON data against a JSON Schema.
///
/// Usage:
///   moon run cmd/validate -- '<sample-json>' '<data-json>'
///   moon run cmd/validate -- --schema '<json-schema>' '<data-json>'
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
  println("    (inline JSON Schema string, validate data)")
  println("")
  println("File input:")
  println("  sh cmd/validate/cli.sh --file <schema.json> --file <data.json>")
  println(
    "  sh cmd/validate/cli.sh --sample-file <sample.json> --file <data.json>",
  )
  println("")
  println("Output:")
  println("  PASS")
  println("  FAIL with error details")
  println("  ERROR for invalid arguments or JSON")
}

///|
fn main {
  let args = @env.args()

  if args.length() < 2 || args[1] == "--help" || args[1] == "-h" {
    print_help()
    return
  }

  // JSON Schema mode.
  if args[1] == "--schema" {
    if args.length() < 4 {
      println("ERROR: --schema requires a JSON Schema and data JSON")
      println(
        "Usage: moon run cmd/validate -- --schema '<schema.json>' '<data.json>'",
      )
      return
    }
    let schema_raw = args[2]
    let data_raw = args[3]
    let schema_json = @json.parse(schema_raw) catch {
      _ => {
        println("ERROR: invalid JSON Schema")
        return
      }
    }
    let schema = @moon_zod.json_schema_to_schema(schema_json)
    println("Schema: \{@moon_zod.schema_to_moon_zod_code(schema)}")
    let _ = validate(schema, data_raw)
    return
  }

  // Default mode: infer from sample
  if args.length() < 3 {
    println("ERROR: missing arguments")
    println("Usage: moon run cmd/validate -- '<sample.json>' '<data.json>'")
    return
  }

  let sample_raw = args[1]
  let data_raw = args[2]

  let sample_json = @json.parse(sample_raw) catch {
    _ => {
      println("ERROR: invalid sample JSON")
      return
    }
  }

  let schema = @moon_zod.json_infer_schema(sample_json)
  println("Schema: \{@moon_zod.schema_to_moon_zod_code(schema)}")
  let _ = validate(schema, data_raw)
}

///|
/// CLI 传入的 \n 是字面量反斜杠+n，替换为真正换行符以便分割。
fn normalize_sep(data : String) -> String {
  data.replace(old="\\n", new="\n")
}

///|
fn validate(schema : @moon_zod.Schema, data_raw : String) -> Bool {
  let data = normalize_sep(data_raw)

  if data.contains("\n") {
    validate_lines(schema, data)
  } else {
    validate_one(schema, data)
  }
}

///|
fn validate_one(schema : @moon_zod.Schema, data : String) -> Bool {
  let data_json = @json.parse(data) catch {
    _ => {
      println("ERROR: invalid data JSON")
      return false
    }
  }

  match schema.parse(data_json) {
    Ok(_) => {
      println("PASS")
      true
    }
    Err(errors) => {
      println("FAIL")
      for e in errors {
        println("  [\{e.path}] \{e.message} (got: \{@debug.to_string(e.got)})")
      }
      false
    }
  }
}

///|
fn validate_lines(schema : @moon_zod.Schema, data : String) -> Bool {
  let lines = data.split("\n")
  let mut pass_count = 0
  let mut fail_count = 0
  let mut line_num = 0

  for line in lines {
    line_num = line_num + 1
    let trimmed = line.trim()
    if trimmed.is_empty() {
      continue
    }
    let data_json = @json.parse(trimmed) catch {
      _ => {
        println("FAIL: line \{line_num} — invalid JSON")
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

  println("Results: \{pass_count} passed, \{fail_count} failed")
  fail_count == 0
}
