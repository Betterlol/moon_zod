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

  if args.length() < 2 || has_flag(args, "--help") || has_flag(args, "-h") {
    print_help()
    return
  }

  let verbose = has_flag(args, "--verbose") || has_flag(args, "-v")
  let from_json_schema = has_flag(args, "--from-json-schema")

  if from_json_schema {
    match last_value_arg(args) {
      None => {
        println("Error: missing JSON Schema argument")
        println(
          "Usage: moon run cmd/json2schema -- --from-json-schema '<json-schema>'",
        )
        return
      }
      Some(raw) => {
        let json = @json.parse(raw) catch {
          _ => {
            println("Error: invalid JSON Schema")
            println("Use --help for usage information.")
            return
          }
        }
        let code = @moon_zod.json_schema_to_moon_zod(json)
        print_result(json, code, verbose, "Input JSON Schema")
        return
      }
    }
  }

  match last_value_arg(args) {
    None => {
      println("Error: missing JSON argument")
      return
    }
    Some(raw) => {
      let json = @json.parse(raw) catch {
        _ => {
          println("Error: invalid JSON")
          println(
            "Note: wrap JSON in single quotes to prevent shell interpretation.",
          )
          println("Use --help for usage information.")
          return
        }
      }
      let schema = @moon_zod.json_infer_schema(json)
      let code = @moon_zod.schema_to_moon_zod_code(schema)
      print_result(json, code, verbose, "Input JSON")
    }
  }
}

///|
fn print_help() -> Unit {
  println("Usage:")
  println("  moon run cmd/json2schema -- '<json>'")
  println("  moon run cmd/json2schema -- --from-json-schema '<json-schema>'")
  println("  moon run cmd/json2schema -- --verbose '<json>'")
  println("  sh cmd/json2schema/cli.sh --file <path>")
  println("  sh cmd/json2schema/cli.sh --from-json-schema --file <path>")
  println("")
  println("Default output is copy-paste ready moon_zod code.")
  println("Use --verbose to also print the parsed input.")
}

///|
fn has_flag(args : Array[String], flag : String) -> Bool {
  for arg in args {
    if arg == flag {
      return true
    }
  }
  false
}

///|
fn last_value_arg(args : Array[String]) -> String? {
  let mut result : String? = None
  for i = 1; i < args.length(); i = i + 1 {
    let arg = args[i]
    if arg.has_prefix("-") {
      ()
    } else {
      result = Some(arg)
    }
  }
  result
}

///|
fn print_result(
  json : Json,
  code : String,
  verbose : Bool,
  input_label : String,
) -> Unit {
  if verbose {
    println("── " + input_label + " ──")
    println(@debug.to_string(json))
    println("")
    println("── Generated moon_zod Schema ──")
  }
  println(code)
}
