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
        println("Error: invalid JSON Schema")
        println("raw: \{raw}")
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
  println("── Generated moon_zod Schema ──")
  let schema = @moon_zod.json_infer_schema(json)
  println(@moon_zod.schema_to_moon_zod_code(schema))
  println("")
  println("── End ──")
}
