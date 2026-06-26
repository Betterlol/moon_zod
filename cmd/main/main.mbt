///|
/// Validate data using raw pattern matching (handcrafted baseline).
fn validate_data(json : Json) -> Bool {
  match json {
    Object(map) =>
      match (map.get("users"), map.get("config")) {
        (Some(users), Some(config)) =>
          validate_users(users) && validate_config(config)
        _ => false
      }
    _ => false
  }
}

///|
fn validate_config(json : Json) -> Bool {
  match json {
    Object(fields) => {
      match fields.get("version") {
        Some(String(s)) => if s.length() < 1 { return false }
        _ => return false
      }
      match fields.get("debug") {
        Some(True) | Some(False) => ()
        _ => return false
      }
      match fields.get("maxRetries") {
        Some(Number(v, ..)) =>
          if v != v.to_int().to_double() || v < 0.0 || v > 10.0 {
            return false
          }
        _ => return false
      }
      true
    }
    _ => false
  }
}

///|
fn validate_users(json : Json) -> Bool {
  match json {
    Array(users) => {
      for user in users {
        if !validate_user(user) {
          return false
        }
      }
      true
    }
    _ => false
  }
}

///|
fn validate_user(json : Json) -> Bool {
  match json {
    Object(fields) => {
      match fields.get("id") {
        Some(Number(v, ..)) =>
          if v != v.to_int().to_double() || v < 0.0 {
            return false
          }
        _ => return false
      }
      match fields.get("name") {
        Some(String(s)) =>
          if s.length() < 1 || s.length() > 100 {
            return false
          }
        _ => return false
      }
      match fields.get("email") {
        Some(Null) | None => ()
        Some(String(s)) => if !has_at_and_dot(s) { return false }
        _ => return false
      }
      match fields.get("role") {
        Some(String(s)) =>
          if s != "admin" && s != "user" && s != "viewer" {
            return false
          }
        _ => return false
      }
      match fields.get("profile") {
        Some(p) => validate_profile(p)
        _ => false
      }
    }
    _ => false
  }
}

///|
fn validate_profile(json : Json) -> Bool {
  match json {
    Object(fields) => {
      match fields.get("age") {
        Some(Number(v, ..)) =>
          if v != v.to_int().to_double() || v < 0.0 || v > 150.0 {
            return false
          }
        _ => return false
      }
      match fields.get("tags") {
        Some(Array(tags)) =>
          for tag in tags {
            match tag {
              String(s) => if s.length() < 1 { return false }
              _ => return false
            }
          }
        _ => return false
      }
      match fields.get("metadata") {
        Some(Null) | None => ()
        Some(m) => if !validate_metadata(m) { return false }
      }
      true
    }
    _ => false
  }
}

///|
fn validate_metadata(json : Json) -> Bool {
  match json {
    Object(fields) => {
      match fields.get("department") {
        Some(String(s)) => if s.length() < 1 { return false }
        _ => return false
      }
      match fields.get("level") {
        Some(Number(v, ..)) =>
          if v != v.to_int().to_double() || v < 1.0 || v > 10.0 {
            return false
          }
        _ => return false
      }
      match fields.get("active") {
        Some(True) | Some(False) => ()
        _ => return false
      }
      true
    }
    _ => false
  }
}

///|
fn has_at_and_dot(s : String) -> Bool {
  let chars = s.to_array()
  let mut at_pos = -1
  for i, c in chars {
    if c == '@' {
      at_pos = i
      break
    }
  }
  if at_pos <= 0 {
    return false
  }
  for i = at_pos + 1; i < chars.length(); i = i + 1 {
    if chars[i] == '.' && i > at_pos + 1 && i < chars.length() - 1 {
      return true
    }
  }
  false
}

///|
/// Format moon_zod benchmark results
fn fmt_moonzod_results(summary : String) -> String {
  let results = @json.parse(summary) catch { _ => return summary }
  let mut output = ""
  let line = "│                                                                          │"
  let length = line.length()
  output = output +
    "╭──────────────────────────────────────────────────────────────────────────╮\n"
  output = output +
    "│                    MoonZod Benchmark Results (calibrated)                │\n"
  output = output +
    "╰──────────────────────────────────────────────────────────────────────────╯\n"
  output = output +
    "│                                                                          │\n"
  match results {
    Array(items) =>
      for item in items {
        match item {
          Object(obj) => {
            let name = match obj.get("name") {
              Some(String(s)) => s
              _ => "Unknown"
            }
            let mean = match obj.get("mean") {
              Some(Number(v, ..)) => v
              _ => 0.0
            }
            let batch = match obj.get("batch_size") {
              Some(Number(v, ..)) => v.to_int()
              _ => 1
            }
            let ns_per_op = mean / batch.to_double() * 1000000.0
            let ops_per_sec = batch.to_double() / mean * 1000
            let ns_str = "\{(ns_per_op * 10.0).to_int().to_double() / 10.0}"
            let ops_str = ops_per_sec.to_int().to_string()
            let base_line = "\{name}: \{ns_str} ns/op  (\{ops_str} ops/sec)"
            let padding_needed = length - 3 - base_line.length()
            if padding_needed > 0 {
              output = output +
                "│ \{base_line}" +
                " ".repeat(padding_needed) +
                "│\n"
            } else {
              output = output + "│ \{base_line}│\n"
            }
          }
          _ => ()
        }
      }
    _ => return summary
  }
  output = output +
    "│                                                                          │\n"
  output = output +
    "╰──────────────────────────────────────────────────────────────────────────╯"
  output
}

///|
/// Benchmark: measure throughput of moon_zod validation on a complex schema.
///
/// Three benchmarks:
///   1. Valid Throughput — pristine data, zero-allocation success path
///   2. Adversarial Hallucination — deep malformation, error generation stress
///   3. Extreme Redundancy — 100+ hallucinated fields, Strip mode filtration
///
/// Also runs handcrafted pattern-matching validation for comparison:
///   - moon_zod: general-purpose validation library
///   - handcrafted: raw pattern match, no library overhead
///
/// Usage:
///   moon run cmd/main                    # Run all benchmarks
///   moon run cmd/main -- '<json>'        # Run with custom JSON for Valid Throughput
///   moon run cmd/main -- --verify        # Verify moon_zod and handcrafted agree
///   moon run cmd/main -- --help          # Show usage
///
/// Run with: moon run cmd/main
fn main {
  let bench = @bench.new()
  let args = @env.args()

  // ── Parse arguments ───────────────────────────────────────────────
  let mode = if args.length() >= 2 {
    if args[1] == "--help" {
      println("Usage:")
      println("  moon run cmd/main                    # Run all benchmarks")
      println("  moon run cmd/main -- '<json>'        # Run with custom JSON")
      println(
        "  moon run cmd/main -- --verify        # Verify moon_zod == handcrafted",
      )
      println("")
      println("Benchmarks:")
      println("  - Valid Throughput (pristine data)")
      println("  - Adversarial Hallucination (error generation)")
      println("  - Extreme Redundancy (Strip mode filtration)")
      println("  - Handcrafted (raw pattern matching baseline)")
      return
    }
    if args[1] == "--verify" {
      "verify"
    } else {
      "bench"
    }
  } else {
    "bench"
  }

  let custom_input : Json? = if mode == "bench" && args.length() >= 3 {
    let parsed = @json.parse(args[2]) catch {
      _ => {
        println("Error: invalid JSON input")
        return
      }
    }
    Some(parsed)
  } else if mode == "bench" &&
    args.length() >= 2 &&
    args[1] != "--verify" &&
    args[1] != "--help" {
    let parsed = @json.parse(args[1]) catch {
      _ => {
        println("Error: invalid JSON input")
        return
      }
    }
    Some(parsed)
  } else {
    None
  }

  // ── Shared schema and input ───────────────────────────────────────
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

  let large_input : Json = match custom_input {
    Some(input) => input
    None =>
      Json::object({
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
  }

  // ── Verify mode ───────────────────────────────────────────────────
  if mode == "verify" {
    let mz_result = match schema.parse(large_input) {
      Ok(_) => true
      Err(_) => false
    }
    let hc_result = validate_data(large_input)
    if mz_result == hc_result {
      println("VERIFY: moon_zod and handcrafted both agree (validation passed)")
    } else {
      println(
        "VERIFY: MISMATCH! moon_zod=\{(if mz_result { "pass" } else { "fail" })}, handcrafted=\{(if hc_result { "pass" } else { "fail" })}",
      )
    }
    return
  }

  // ═══════════════════════════════════════════════════════════════════
  // MoonZod Benchmarks (calibrated by @bench)
  // ═══════════════════════════════════════════════════════════════════

  // Sanity check
  match schema.parse(large_input) {
    Ok(_) => ()
    Err(_) => println("WARNING: valid input unexpectedly failed")
  }
  bench.bench(name="Valid Throughput (moon_zod)", fn() {
    bench.keep(schema.parse(large_input))
  })

  // Adversarial
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
  match schema.parse(adv_input) {
    Err(errors) => {
      let mut count = 0
      for _ in errors {
        count = count + 1
      }
      println("Adversarial: \{count} errors generated (expected)")
    }
    Ok(_) => println("WARNING: adversarial input unexpectedly passed")
  }
  bench.bench(name="Adversarial (moon_zod)", fn() {
    bench.keep(schema.parse(adv_input))
  })

  // Extreme Redundancy
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
  match schema.parse(redundant_input) {
    Ok(cleaned) =>
      match cleaned {
        Object(map) => {
          let mut spec_count = 0
          for _ in map.keys() {
            spec_count = spec_count + 1
          }
          let stripped = 107 - spec_count
          println("Strip: \{stripped} hallucinated fields removed (expected)")
        }
        _ => println("WARNING: cleaned result is not an object")
      }
    Err(_) => println("WARNING: redundant input unexpectedly failed")
  }
  bench.bench(name="Extreme Redundancy (moon_zod)", fn() {
    bench.keep(schema.parse(redundant_input))
  })

  // ═══════════════════════════════════════════════════════════════════
  // Handcrafted Benchmark (raw pattern matching) — @bench calibrated
  // ═══════════════════════════════════════════════════════════════════
  bench.bench(name="Valid Throughput (handcrafted)", fn() {
    bench.keep(validate_data(large_input))
  })

  // ── Output results ────────────────────────────────────────────────
  let json_summary = bench.dump_summaries()
  println("")
  println(fmt_moonzod_results(json_summary))
  println("")
  println(
    "──────────────────────────────────────────────────────────────────────────",
  )
  println("")
  println("JSON:\{json_summary}")
}
