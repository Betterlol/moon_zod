///|
/// moon_zod Schema Generator — JSON to `@moon_zod` source code
///
/// Accepts a JSON string via CLI argument and generates the
/// corresponding moon_zod schema expression.
///
/// Usage:
///   moon run cmd/json2schema -- '<json-string>'
///   sh cmd/json2schema/cli.sh --file <path>
///   moon run cmd/json2schema -- --help
fn main {
  let args = @env.args()
  if args.length() < 2 || args[1] == "--help" {
    println("Usage: moon run cmd/json2schema -- '<json-string>'")
    println(
      "       moon run cmd/json2schema -- --from-json-schema '<json-schema>'",
    )
    println("       sh cmd/json2schema/cli.sh --file <path>")
    println("")
    println("Generate a moon_zod schema from a JSON payload or JSON Schema.")
    println("")
    println("Modes:")
    println("  (default)           Infer schema from a JSON data instance")
    println(
      "  --from-json-schema  Convert a JSON Schema document to moon_zod code",
    )
    println("")
    println("Examples:")
    println("  moon run cmd/json2schema -- '{\"name\": \"Alice\"}'")
    println(
      "  moon run cmd/json2schema -- --from-json-schema '{\"type\":\"string\"}'",
    )
    println("  moon run cmd/json2schema -- --help")
    println("")
    println("File input:")
    println("  sh cmd/json2schema/cli.sh --file data.json")
    let shell_example = "  moon run cmd/json2schema -- \"$(cat data.json)\""
    println(shell_example)
    return
  }

  if args[1] == "--from-json-schema" {
    if args.length() < 3 {
      println("Error: missing JSON Schema argument")
      println(
        "Usage: moon run cmd/json2schema -- --from-json-schema '<json-schema>'",
      )
      return
    }
    let raw = args[2]
    let json = @json.parse(raw) catch {
      _ => {
        println("Error: invalid JSON string")
        println(
          "Usage: moon run cmd/json2schema -- --from-json-schema '<json-schema>'",
        )
        return
      }
    }
    println("── Input JSON Schema ──")
    println(@debug.to_string(json))
    println("")
    println("── Generated moon_zod Schema (copy-paste ready) ──")
    println(@moon_zod.json_schema_to_moon_zod(json))
    println("")
    println("── End ──")
    return
  }

  let raw = args[1]
  let json = @json.parse(raw) catch {
    _ => {
      println("Error: invalid JSON string")
      println(
        "Note: wrap the JSON in single quotes to prevent shell interpretation.",
      )
      println("  moon run cmd/json2schema -- '{\"key\": \"value\"}'")
      println("Use --help for usage information.")
      return
    }
  }

  println("── Input JSON ──")
  println(@debug.to_string(json))
  println("")
  println("── Generated moon_zod Schema (copy-paste ready) ──")
  println(infer_schema(json, 0))
  println("")
  println("── End ──")
}

///|
/// Infer a moon_zod schema expression from a JSON value.
fn infer_schema(json : Json, indent : Int) -> String {
  match json {
    String(_) => "@moon_zod.string()"
    Number(_) => "@moon_zod.number()"
    True | False => "@moon_zod.boolean()"
    Null => "@moon_zod.null()"
    Array(elements) => infer_array_schema(elements, indent)
    Object(map) => infer_object_schema(map, indent)
  }
}

///|
/// Generate an `@moon_zod.object({...})` expression from a JSON object.
/// Object keys are safely escaped via `escape_mbt_string` to ensure the
/// generated MoonBit string literal does not break on `"` or `\`.
fn infer_object_schema(map : Map[String, Json], indent : Int) -> String {
  let mut result = "@moon_zod.object({\n"
  let mut first = true
  for key in map.keys() {
    if !first {
      result = result + ",\n"
    }
    first = false
    match map.get(key) {
      Some(val) => {
        let field_schema = infer_schema(val, indent + 1)
        result = result +
          pad(indent + 1) +
          "\"" +
          escape_mbt_string(key) +
          "\": " +
          field_schema
      }
      None => ()
    }
  }
  if first {
    "@moon_zod.object({})"
  } else {
    result = result + ",\n" + pad(indent) + "})"
    result
  }
}

///|
/// Generate an `@moon_zod.array(...)` expression from a JSON array.
/// Inspects the first element to infer the element schema.
/// Empty arrays generate a TODO comment to alert the developer.
fn infer_array_schema(elements : Array[Json], indent : Int) -> String {
  let inner = if elements.length() > 0 {
    infer_schema(elements[0], indent + 1)
  } else {
    "@moon_zod.string() /* TODO: specify exact type */"
  }
  if has_newlines(inner) {
    "@moon_zod.array(\n" + pad(indent + 1) + inner + "\n" + pad(indent) + ")"
  } else {
    "@moon_zod.array(" + inner + ")"
  }
}

///|
/// Escape special characters in a string so it can be safely used as a
/// MoonBit string literal. Escapes `"` → `\"` and `\` → `\\`.
fn escape_mbt_string(s : String) -> String {
  let mut result = ""
  for c in s.to_array() {
    if c == '\\' {
      result = result + "\\\\"
    } else if c == '"' {
      result = result + "\\\""
    } else {
      result = result + c.to_string()
    }
  }
  result
}

///|
/// Check if a string contains newline characters.
fn has_newlines(s : String) -> Bool {
  for c in s.to_array() {
    if c == '\n' {
      return true
    }
  }
  false
}

///|
/// Generate an indentation string for a given nesting level.
/// Each level produces 2 spaces.
fn pad(level : Int) -> String {
  let mut spaces = ""
  for i = 0; i < level * 2; i = i + 1 {
    spaces = spaces + " "
  }
  spaces
}
