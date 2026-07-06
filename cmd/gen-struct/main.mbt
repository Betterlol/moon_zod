///|
/// MoonBit Struct Generator — JSON Schema to MoonBit struct definitions
///
/// Accepts a JSON Schema via the `--schema` flag and generates MoonBit
/// struct definitions from it.
///
/// Usage:
///   moon run cmd/gen-struct -- --schema '<json-schema>'
///   moon run cmd/gen-struct -- --help
///
/// Examples:
///   moon run cmd/gen-struct -- --schema '{"type":"object","properties":{"name":{"type":"string"}}}'
///   moon run cmd/gen-struct -- --schema '{"$defs":{"User":{"type":"object","properties":{"name":{"type":"string"}}}},"$ref":"#/$defs/User"}'
fn main {
  let args = @env.args()
  if args.length() < 2 || args[1] == "--help" {
    println("Usage: moon run cmd/gen-struct -- --schema '<json-schema>'")
    println("")
    println("Generate MoonBit struct definitions from a JSON Schema document.")
    println("Nested JSON Schema objects are emitted as standalone structs.")
    println("")
    println("Examples:")
    println(
      "  moon run cmd/gen-struct -- --schema '{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"}}}'",
    )
    println("  moon run cmd/gen-struct -- --help")
    return
  }

  if args.length() < 3 || args[1] != "--schema" {
    println("Error: use --schema flag to provide a JSON Schema")
    println("  moon run cmd/gen-struct -- --schema '<json-schema>'")
    return
  }

  let raw = args[2]
  let schema_json = @json.parse(raw) catch {
    _ => {
      println("Error: invalid JSON Schema")
      return
    }
  }

  let schema = @moon_zod.json_schema_to_schema(schema_json)

  println("── Generated MoonBit struct definitions ──")
  println(@moon_zod.schema_to_moonbit_struct_full(schema))
  println("")
  println("── End ──")
}
