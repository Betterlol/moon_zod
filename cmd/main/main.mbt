///|
/// Benchmark: run a complex validation many times to measure throughput.
/// Run with `moon run cmd/main` from the project root.
fn main {
  let schema = @moon_zod.object({
    "name": @moon_zod.string().min(2).max(50).nonempty(),
    "age": @moon_zod.number().int().min(0).max(150),
    "email": @moon_zod.string().email().optional(),
    "tags": @moon_zod.array(@moon_zod.string().min(1)).optional(),
    "address": @moon_zod.object({
      "city": @moon_zod.string().min(1),
      "zip": @moon_zod.string().regex("\\d{5}").optional(),
    }).optional(),
  })

  let valid_input = Json::object({
    "name": Json::string("Alice"),
    "age": Json::number(30.0),
    "email": Json::string("alice@example.com"),
    "tags": Json::array([Json::string("admin"), Json::string("user")]),
    "address": Json::object({
      "city": Json::string("New York"),
      "zip": Json::string("10001"),
    }),
  })

  let n = 10_000
  for i = 0; i < n; i = i + 1 {
    let _ = schema.parse(valid_input)
  }
  println("Done: \{n} iterations without error")
}
