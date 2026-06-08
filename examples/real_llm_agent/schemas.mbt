///|
/// Real LLM Agent — MoonZod Schemas
///
/// Defines multiple validation schemas and a unified CLI.
///
/// Usage:
///   Output JSON Schema:   moon run examples/real_llm_agent -- <name> schema
///   Validate JSON:        moon run examples/real_llm_agent -- <name> validate '<json>'
///
/// Schemas: product, movie

///|
fn product_schema() -> @moon_zod.Schema {
  @moon_zod.object({
    "name": @moon_zod.string().min(3).max(100),
    "description": @moon_zod.string().min(10).max(500),
    "price": @moon_zod.number().positive(),
    "currency": @moon_zod.enum_values(["USD", "EUR", "GBP", "JPY", "CNY"]),
    "category": @moon_zod.enum_values([
      "electronics", "clothing", "food", "books", "other",
    ]),
    "tags": @moon_zod.array(@moon_zod.string().min(1)),
    "stock": @moon_zod.number().int().min(0),
    "metadata": @moon_zod.object({
      "brand": @moon_zod.string().min(1),
      "weight_kg": @moon_zod.number().positive(),
    }).optional(),
  })
}

///|
fn movie_schema() -> @moon_zod.Schema {
  @moon_zod.object({
    "title": @moon_zod.string().min(1).max(200),
    "director": @moon_zod.string().min(1),
    "year": @moon_zod.number().int().min(1888),
    "rating": @moon_zod.number().min(0).max(10),
    "genres": @moon_zod.array(@moon_zod.string().min(1)),
    "cast": @moon_zod.array(
      @moon_zod.object({
        "name": @moon_zod.string().min(1),
        "role": @moon_zod.string().min(1),
      }),
    ),
    "duration_minutes": @moon_zod.number().int().positive(),
  })
}

///|
fn get_schema(name : String) -> Result[@moon_zod.Schema, String] {
  match name {
    "product" => Ok(product_schema())
    "movie" => Ok(movie_schema())
    _ => Err("Unknown schema: " + name)
  }
}

///|
fn main {
  let args = @env.args()
  if args.length() < 3 {
    println(
      "Usage: moon run examples/real_llm_agent -- <schema_name> [schema|validate] [json]",
    )
    println("")
    println("Schemas: product, movie")
    println("")
    println("Examples:")
    println(
      "  Output JSON Schema:  moon run examples/real_llm_agent -- product schema",
    )
    println(
      "  Validate JSON:       moon run examples/real_llm_agent -- product validate '<json>'",
    )
    println(
      "  Movie JSON Schema:   moon run examples/real_llm_agent -- movie schema",
    )
    return
  }

  let schema_name = args[1]
  let command = args[2]

  let schema = match get_schema(schema_name) {
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
      println("Unknown command: " + command + ". Use 'schema' or 'validate'.")
    }
  }
}
