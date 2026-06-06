///|
/// Real LLM Agent — MoonZod Validator
///
/// Receives a JSON string via CLI argument, validates against a product
/// schema, and outputs a machine-readable result for the Python agent.
///
/// Protocol (stdout):
///   OK     → line 1, followed by cleaned data in debug format
///   ERR    → line 1, count on line 2, one error per line after
///
/// Package: examples/real_llm_agent
/// Usage:   moon run examples/real_llm_agent -- '<json-string>'
let product_schema : @moon_zod.Schema = @moon_zod.object({
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

///|
fn main {
  let args = @env.args()
  if args.length() < 2 {
    println("ERR")
    println("1")
    println("[(root)] No input provided (got: null)")
    return
  }

  let json_str = args[1]
  let json = @json.parse(json_str) catch {
    _ => {
      println("ERR")
      println("1")
      println("[(root)] Invalid JSON (got: " + json_str + ")")
      return
    }
  }

  match product_schema.parse(json) {
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
