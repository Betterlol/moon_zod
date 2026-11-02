///|
/// CLI that exercises moon_zod schemas.
///
/// The schema definitions are shared in examples/shared_schemas/.
///
/// Usage:
///   moon run moon_zod/examples/real_llm_agent -- <name> schema|prompt|validate [json]
///
/// Schemas: product, movie
fn main {
  let args = @env.args()
  if args.length() < 3 {
    println(
      "Usage: moon run moon_zod/examples/real_llm_agent -- <schema_name> [schema|prompt|validate] [json]",
    )
    println("")
    println("Schemas: product, movie")
    println("")
    println("Examples:")
    println(
      "  Output JSON Schema:  moon run moon_zod/examples/real_llm_agent -- product schema",
    )
    println(
      "  Output TS Prompt:    moon run moon_zod/examples/real_llm_agent -- product prompt",
    )
    println(
      "  Validate JSON:       moon run moon_zod/examples/real_llm_agent -- product validate '<json>'",
    )
    return
  }

  let schema_name = args[1]
  let command = args[2]

  let schema = match @shared_schemas.get_schema(schema_name) {
    Ok(s) => s
    Err(msg) => {
      println("ERR")
      println("1")
      println(msg)
      return
    }
  }

  match command {
    "schema" => {
      let schema_json = @moon_zod.to_json_schema(schema)
      println(schema_json.stringify(indent=2))
    }
    "prompt" => println(@moon_zod.schema_to_prompt(schema))
    "validate" => {
      if args.length() < 4 {
        println("ERR")
        println("1")
        println("[(root)] No JSON input provided")
        return
      }
      let json_str = args[3]
      let json = @json.parse(json_str) catch {
        _ => {
          println("ERR")
          println("1")
          println("[(root)] Invalid JSON (got: " + json_str + ")")
          return
        }
      }
      match schema.parse(json) {
        Ok(clean) => {
          println("OK")
          println(@debug.to_string(clean))
        }
        Err(errors) => {
          println("ERR")
          println(errors.length().to_string())
          for e in errors {
            println(e.to_string())
          }
        }
      }
    }
    _ => {
      println("ERR")
      println("1")
      println(
        "Unknown command: " +
        command +
        ". Use 'schema', 'prompt', or 'validate'.",
      )
    }
  }
}
