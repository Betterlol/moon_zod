///|
/// LLM Tool Calling Self-Correction Demo
///
/// Simulates an AI agent loop:
///   1. Define a tool schema → export JSON Schema skeleton
///   2. Mock LLM call → returns invalid JSON
///   3. Validate with moon_zod → catch & format errors
///   4. Feed errors back → LLM retries with corrected JSON
///   5. Strip mode auto-cleans hallucinated fields
///
/// Run with: moon run examples/llm_agent
fn main {
  // ── Step 1: Define a realistic tool schema ──────────────────────
  let user_schema = @moon_zod.object({
    "name": @moon_zod.string().min(1).max(100),
    "age": @moon_zod.number().int().min(0).max(150),
    "email": @moon_zod.string().email(),
    "role": @moon_zod.enum_values(["admin", "user", "guest"]),
    "metadata": @moon_zod.object({
      "department": @moon_zod.string().min(1),
      "level": @moon_zod.number().int().min(1).max(10),
    }).optional(),
  })

  // Export JSON Schema skeleton (what you'd send to an LLM API)
  println("=== [Tool Schema] JSON Skeleton (sent to LLM) ===")
  println(@debug.to_string(@moon_zod.to_json_schema(user_schema)))
  println("")

  // ── Step 2: First LLM call — returns MALFORMED JSON ────────────
  println("=== [Round 1] LLM returns invalid JSON ===")
  let bad_json = mock_bad_response()
  println("Raw output: \{@debug.to_string(bad_json)}")
  println("")

  // ── Step 3: Validate & format errors ──────────────────────────
  let parse_result = user_schema.parse(bad_json)
  match parse_result {
    Err(errors) => {
      println(">>> moon_zod caught \{errors.length().to_string()} error(s):")

      let error_lines : Array[String] = []
      for e in errors {
        error_lines.push("  - \{e.path}: \{e.message}")
      }
      let error_text = error_lines.join("\n")
      println(error_text)
      println("")

      // ── Step 4: Feed errors back → LLM retries ────────────────
      let correction_prompt = "Your previous JSON was invalid.\nErrors:\n" +
        error_text +
        "\nPlease fix it and return ONLY valid JSON."

      println("=== [Retry] Correction prompt sent to LLM ===")
      println("\{correction_prompt}")
      println("")

      let fixed_json = mock_fixed_response()
      println("=== [Round 2] LLM returns corrected JSON ===")
      println("Raw output: \{@debug.to_string(fixed_json)}")
      println("")

      let retry_result = user_schema.parse(fixed_json)
      match retry_result {
        Ok(clean) => {
          // Strip mode has already removed hallucinated fields
          println(
            ">>> Validation passed! Clean data (hallucinations stripped):",
          )
          println(@debug.to_string(clean))
          println("")
          println("=== Self-correction loop completed successfully ===")
        }
        Err(errors2) => {
          println(">>> Still invalid after retry — would loop again.")
          for e in errors2 {
            println("  - \{e.path}: \{e.message}")
          }
        }
      }
    }
    Ok(_) => println("Unexpected: bad JSON passed validation")
  }
}

///|
/// Mock LLM response — returns JSON with deliberate errors:
///   - "age" is a string instead of number
///   - "role" is not in the allowed enum
///   - "email" is missing (required field)
fn mock_bad_response() -> Json {
  Json::object({
    "name": Json::string("Alice"),
    "age": Json::string("twenty"),
    "role": Json::string("superadmin"),
    "metadata": Json::object({
      "department": Json::string("Engineering"),
      "level": Json::number(5.0),
    }),
  })
}

///|
/// Mock LLM retry — returns valid JSON with a hallucinated extra field.
/// moon_zod's default Strip mode will remove "extra_hallucinated_field".
fn mock_fixed_response() -> Json {
  Json::object({
    "name": Json::string("Alice"),
    "age": Json::number(30.0),
    "email": Json::string("alice@example.com"),
    "role": Json::string("admin"),
    "metadata": Json::object({
      "department": Json::string("Engineering"),
      "level": Json::number(5.0),
    }),
    "extra_hallucinated_field": Json::string("LLM imagined this"),
  })
}
