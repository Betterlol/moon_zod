///|
/// Benchmark: measure throughput of moon_zod validation on a complex schema.
///
/// Three benchmarks:
///   1. Valid Throughput — pristine data, zero-allocation success path
///   2. Adversarial Hallucination — deep malformation, error generation stress
///   3. Extreme Redundancy — 100+ hallucinated fields, Strip mode filtration
///
/// Uses MoonBit's @bench library for calibrated iteration counts and
/// precise ns/op measurements (mean, median, std_dev).
///
/// Key design feature demonstrated:
///   Mutable Path Stack (Phase 5) — zero string allocations on the success path,
///   critical for Wasm edge runtimes with constrained memory.
///
/// Run with: moon run cmd/main
fn main {
  let bench = @bench.new()

  // ── Shared complex nested schema ─────────────────────────────────
  let schema = @moon_zod.object({
    "users": @moon_zod.array(
      @moon_zod.object({
        "id": @moon_zod.number().int().min(0),
        "name": @moon_zod.string().min(1).max(100),
        "email": @moon_zod.string().email().optional(),
        "role": @moon_zod.enum_values(["admin", "user", "viewer"]),
        "profile": @moon_zod.object({
          "age": @moon_zod.number().int().min(0).max(150),
          "tags": @moon_zod.array(@moon_zod.string().min(1)),
          "metadata": @moon_zod.object({
            "department": @moon_zod.string().min(1),
            "level": @moon_zod.number().int().min(1).max(10),
            "active": @moon_zod.boolean(),
          }).optional(),
        }),
      }),
    ),
    "config": @moon_zod.object({
      "version": @moon_zod.string().min(1),
      "debug": @moon_zod.boolean(),
      "maxRetries": @moon_zod.number().int().min(0).max(10),
    }),
  })

  // ── Pristine valid input ─────────────────────────────────────────
  let large_input = Json::object({
    "users": Json::array([
      Json::object({
        "id": Json::number(1.0),
        "name": Json::string("Alice"),
        "email": Json::string("alice@example.com"),
        "role": Json::string("admin"),
        "profile": Json::object({
          "age": Json::number(30.0),
          "tags": Json::array([
            Json::string("rust"),
            Json::string("wasm"),
            Json::string("ai"),
          ]),
          "metadata": Json::object({
            "department": Json::string("Engineering"),
            "level": Json::number(5.0),
            "active": Json::boolean(true),
          }),
        }),
      }),
      Json::object({
        "id": Json::number(2.0),
        "name": Json::string("Bob"),
        "role": Json::string("user"),
        "profile": Json::object({
          "age": Json::number(25.0),
          "tags": Json::array([Json::string("design")]),
          "metadata": Json::object({
            "department": Json::string("Design"),
            "level": Json::number(3.0),
            "active": Json::boolean(false),
          }),
        }),
      }),
      Json::object({
        "id": Json::number(3.0),
        "name": Json::string("Charlie"),
        "role": Json::string("viewer"),
        "profile": Json::object({
          "age": Json::number(42.0),
          "tags": Json::array([Json::string("python"), Json::string("data")]),
        }),
      }),
    ]),
    "config": Json::object({
      "version": Json::string("1.0.0"),
      "debug": Json::boolean(false),
      "maxRetries": Json::number(3.0),
    }),
  })

  // ═══════════════════════════════════════════════════════════════════
  // Benchmark 1: Valid Throughput
  // ═══════════════════════════════════════════════════════════════════
  // Sanity: verify the valid input passes once before timing
  match schema.parse(large_input) {
    Ok(_) => ()
    Err(_) => println("WARNING: valid input unexpectedly failed")
  }
  bench.bench(name="Valid Throughput", fn() {
    bench.keep(schema.parse(large_input))
  })

  // ═══════════════════════════════════════════════════════════════════
  // Benchmark 2: Adversarial Hallucination (Error Generation)
  // ═══════════════════════════════════════════════════════════════════
  let adv_input = Json::object({
    "users": Json::array([
      Json::object({
        "name": Json::string(""),
        "email": Json::string("not-an-email"),
        "role": Json::string("superuser"),
        "profile": Json::object({
          "age": Json::number(-5.0),
          "tags": Json::array([]),
        }),
      }),
      Json::object({ "id": Json::number(99.0), "role": Json::number(123.0) }),
    ]),
    "config": Json::object({
      "version": Json::string(""),
      "debug": Json::number(1.0),
      "maxRetries": Json::number(999.0),
    }),
  })
  // Sanity: verify the adversarial input produces errors
  match schema.parse(adv_input) {
    Err(errors) => {
      let mut count = 0
      for _ in errors {
        count = count + 1
      }
      println("Adversarial: \{count.to_string()} errors generated (expected)")
    }
    Ok(_) =>
      println("WARNING: adversarial input unexpectedly passed validation")
  }
  bench.bench(name="Adversarial Hallucination", fn() {
    bench.keep(schema.parse(adv_input))
  })

  // ═══════════════════════════════════════════════════════════════════
  // Benchmark 3: Extreme Redundancy (Strip Mode Stress)
  // ═══════════════════════════════════════════════════════════════════
  let redundant_map : Map[String, Json] = {
    "users": Json::array([
      Json::object({
        "id": Json::number(1.0),
        "name": Json::string("Alice"),
        "email": Json::string("alice@example.com"),
        "role": Json::string("admin"),
        "profile": Json::object({
          "age": Json::number(30.0),
          "tags": Json::array([Json::string("rust"), Json::string("wasm")]),
        }),
      }),
    ]),
    "config": Json::object({
      "version": Json::string("1.0.0"),
      "debug": Json::boolean(false),
      "maxRetries": Json::number(3.0),
    }),
  }
  for i = 0; i < 105; i = i + 1 {
    redundant_map.set("h_field_\{i}", Json::string("hallucinated_value_\{i}"))
  }
  let redundant_input = Json::object(redundant_map)
  // Sanity: verify Strip mode removes hallucinated fields
  match schema.parse(redundant_input) {
    Ok(cleaned) =>
      match cleaned {
        Object(map) => {
          let mut spec_count = 0
          for _ in map.keys() {
            spec_count = spec_count + 1
          }
          let stripped = 107 - spec_count
          println(
            "Strip: \{stripped.to_string()} hallucinated fields removed (expected)",
          )
        }
        _ => println("WARNING: cleaned result is not an object")
      }
    Err(_) => println("WARNING: redundant input unexpectedly failed validation")
  }
  bench.bench(name="Extreme Redundancy", fn() {
    bench.keep(schema.parse(redundant_input))
  })

  // ── Output JSON summary ──────────────────────────────────────────
  println(bench.dump_summaries())
}
