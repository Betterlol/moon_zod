///|
/// MoonBit Struct Generator — JSON payload to MoonBit struct definitions
///
/// Accepts a JSON string via CLI argument and generates MoonBit struct
/// definitions from the inferred schema.
///
/// Usage:
///   moon run cmd/gen-struct -- '<json-string>'
///   moon run cmd/gen-struct -- '{"name":"Alice","age":30}'
///   moon run cmd/gen-struct -- --help
fn main {
  let args = @env.args()
  if args.length() < 2 || args[1] == "--help" {
    println("Usage: moon run cmd/gen-struct -- '<json-string>'")
    println("")
    println("Generate MoonBit struct definitions from a JSON payload.")
    println("")
    println("Nested objects are automatically named and exported as")
    println("separate struct definitions.")
    println("")
    println("Examples:")
    println("  moon run cmd/gen-struct -- '{\"name\": \"Alice\", \"age\": 30}'")
    println(
      "  moon run cmd/gen-struct -- '{\"user\": {\"name\": \"Bob\"}, \"tags\": [\"a\"]}'",
    )
    println("  moon run cmd/gen-struct -- --help")
    return
  }

  let raw = args[1]
  let json = @json.parse(raw) catch {
    _ => {
      println("Error: invalid JSON string")
      println(
        "Note: wrap the JSON in single quotes to prevent shell interpretation.",
      )
      println("  moon run cmd/gen-struct -- '{\"key\": \"value\"}'")
      return
    }
  }

  println("── Input JSON ──")
  println(@debug.to_string(json))
  println("")

  let schema = json_infer_schema(json, "GeneratedStruct")

  println("── Generated MoonBit struct definitions ──")
  println(@moon_zod.schema_to_moonbit_struct_named(schema))
  println("")
  println("── End ──")
}

///|
/// Infer a moon_zod Schema from a JSON value.
/// Nested objects are auto-named using the provided `name_hint`.
fn json_infer_schema(json : Json, name_hint : String) -> @moon_zod.Schema {
  match json {
    String(_) => @moon_zod.string()
    Number(v, ..) =>
      // Check if it's an integer value
      if v == v.to_int().to_double() {
        @moon_zod.number().int()
      } else {
        @moon_zod.number()
      }
    True | False => @moon_zod.boolean()
    Null => @moon_zod.null()
    Array(elements) => {
      let elem_schema = if elements.length() > 0 {
        json_infer_schema(elements[0], name_hint + "Element")
      } else {
        @moon_zod.string()
      }
      @moon_zod.array(elem_schema)
    }
    Object(map) => {
      let fields : Map[String, @moon_zod.Schema] = {}
      for key, val in map {
        let field_name = auto_struct_name(key)
        let field_schema = json_infer_schema(val, field_name)
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
    "GeneratedStruct"
  } else {
    let first = result[0]
    if !((first >= 'a' && first <= 'z') || (first >= 'A' && first <= 'Z')) {
      result = "V" + result
    }
    result
  }
}
