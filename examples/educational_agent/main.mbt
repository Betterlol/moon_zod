///|
/// Production-Grade AI Educational Agent Showcase
///
/// Simulates a multi-round LLM self-correction loop for a curriculum
/// management tool. Demonstrates moon_zod's three-layer defense:
///
///   Layer 1 — Structural validation (type checks, enum constraints)
///   Layer 2 — Rule validation (min/max, positive, int)
///   Layer 3 — Strip cleanse (silent hallucinated-field removal)
///
/// Each round feeds validation errors back as a structured correction
/// prompt, mimicking a real LLM tool-calling retry loop.
///
/// Run with: moon run examples/educational_agent
fn main {
  println(
    "╔══════════════════════════════════════════════════════════╗",
  )
  println("║   AI Educational Agent — Resilience Loop Showcase       ║")
  println(
    "╚══════════════════════════════════════════════════════════╝",
  )
  println("")

  // ═══════════════════════════════════════════════════════════════════
  // Step 1: Define the CoursePayload Schema
  // ═══════════════════════════════════════════════════════════════════
  let course_schema = @moon_zod.object({
    "course_id": @moon_zod.number().int().min(0),
    "title": @moon_zod.string().min(5),
    "difficulty": @moon_zod.enum_values(["beginner", "intermediate", "advanced"]),
    "lessons": @moon_zod.array(
      @moon_zod.object({
        "lesson_id": @moon_zod.number().int().min(0),
        "topic": @moon_zod.string().min(1),
        "estimated_minutes": @moon_zod.number().int().positive(),
      }),
    ),
    "instructor": @moon_zod.string().optional(),
    "metadata": @moon_zod.object({
      "department": @moon_zod.string().min(1),
      "credits": @moon_zod.number().int().min(1).max(10),
    }).optional(),
  })

  println("── [Schema] CoursePayload ──")
  println("  Fields: course_id, title, difficulty, lessons[],")
  println("          instructor?, metadata?")
  println("  Rules:  title.min(5), difficulty.enum(...),")
  println("          estimated_minutes.positive(), credits.min(1).max(10)")
  println("")
  println("  JSON Schema skeleton (sent to LLM API):")
  println("  \{@moon_zod.to_json_schema(course_schema)}")
  println("")

  // ═══════════════════════════════════════════════════════════════════
  // Round 1 — Severe Structural Mutation
  // ═══════════════════════════════════════════════════════════════════
  println("── [Round 1] Severe Structural Mutation ──")
  println("  Simulating: LLM hallucinates types, invents enum values,")
  println(
    "              produces negative durations, and drops required fields.",
  )
  println("")

  let round1_json = mock_round1_response()
  println("  Raw LLM output: \{round1_json}")
  println("")

  match course_schema.parse(round1_json) {
    Err(errors) => {
      println("  >>> moon_zod caught \{errors.length().to_string()} error(s):")
      for e in errors {
        println("      [\{e.path}] \{e.message} (got: \{e.got})")
      }
      println("")

      // Build a structured correction prompt from error paths
      let prompt = build_correction_prompt(errors)
      println("  >>> Generated Correction Prompt (sent back to LLM):")
      println(
        "  ┌────────────────────────────────────────────────────",
      )
      println(prompt)
      println(
        "  └────────────────────────────────────────────────────",
      )
      println("")

      // ── LLM retries with corrected JSON ──────────────────────
      let round2_json = mock_round2_response()
      println("── [Round 2] LLM Retry (Schema Violation & Recovery) ──")
      println("  Simulating: LLM fixes structural types but violates")
      println("              rule constraints (title too short).")
      println("")
      println("  Raw LLM output: \{round2_json}")
      println("")

      match course_schema.parse(round2_json) {
        Err(errors2) => {
          println(
            "  >>> moon_zod caught \{errors2.length().to_string()} rule-level error(s):",
          )
          for e in errors2 {
            println("      [\{e.path}] \{e.message} (got: \{e.got})")
          }
          println("")
          println(
            "  >>> This is moon_zod's SECOND line of defense: even when types",
          )
          println(
            "      are correct, rule constraints (min, max, positive, etc.)",
          )
          println("      catch violations before data enters the system.")
          println("")

          let prompt2 = build_correction_prompt(errors2)
          println("  >>> Refined Correction Prompt:")
          println(
            "  ┌────────────────────────────────────────────────────",
          )
          println(prompt2)
          println(
            "  └────────────────────────────────────────────────────",
          )
          println("")

          // ── LLM retries again ──────────────────────────────────
          println("── [Round 3] Final Retry + Strip Cleanse ──")
          println("  Simulating: LLM returns structurally perfect JSON")
          println("              with 12 hallucinated metadata fields.")
          println("")

          let round3_json = mock_round3_response()
          println("  Raw LLM output: \{round3_json}")
          println("")

          match course_schema.parse(round3_json) {
            Ok(clean) => {
              println("  >>> Validation passed! (Strip mode active)")
              match clean {
                Object(map) => {
                  let mut field_count = 0
                  for _ in map.keys() {
                    field_count = field_count + 1
                  }
                  println(
                    "  >>> Stripped output (\{field_count.to_string()} spec fields, 12 hallucinated fields removed):",
                  )
                }
                _ => ()
              }
              println("  \{clean}")
              println("")
              println(
                "  >>> The LLM's hallucinated fields (llm_model, temperature,",
              )
              println(
                "      top_p, seed, etc.) were silently stripped by moon_zod's",
              )
              println(
                "      default Strip mode — the downstream system never sees them.",
              )
              println("")
              println(
                "╔══════════════════════════════════════════════════════════╗",
              )
              println(
                "║   SUCCESS: 3-round resilience loop completed.           ║",
              )
              println(
                "║   Layer 1 (types) → Layer 2 (rules) → Layer 3 (strip)   ║",
              )
              println(
                "╚══════════════════════════════════════════════════════════╝",
              )
            }
            Err(errors3) => {
              println("  >>> Still invalid after second retry:")
              for e in errors3 {
                println("      [\{e.path}] \{e.message}")
              }
            }
          }
        }
        Ok(_) => println("  Unexpected: round 2 passed (should have failed)")
      }
    }
    Ok(_) => println("  Unexpected: round 1 passed (should have failed)")
  }
}

///|
/// Build a structured correction prompt from validation errors.
/// Each error's path (formatted by moon_zod's internal format_path)
/// pinpoints the exact location for the LLM to fix.
fn build_correction_prompt(errors : Array[@moon_zod.ValidationError]) -> String {
  let mut prompt = "## Validation Errors Detected\n\n"
  prompt = prompt + "Your previous JSON output failed schema validation. "
  prompt = prompt +
    "The errors below show the exact field path, the constraint violated, and the value you provided.\n\n"
  prompt = prompt + "### Errors to fix:\n\n"
  for e in errors {
    prompt = prompt + "- **`\{e.path}`**: \{e.message}\n"
    prompt = prompt + "  (you provided: `\{e.got}`)\n"
  }
  prompt = prompt + "\n### Instructions:\n\n"
  prompt = prompt + "1. Fix each error at the exact path shown above\n"
  prompt = prompt + "2. Ensure all enum values match the allowed set\n"
  prompt = prompt + "3. Verify numeric constraints (min, max, positive, int)\n"
  prompt = prompt + "4. Include ALL required fields\n"
  prompt = prompt + "5. Return ONLY the corrected JSON object, no extra text\n"
  prompt
}

///|
/// Round 1 mock: severely malformed JSON.
///   - course_id is a string instead of number (type error)
///   - difficulty is "expert" (not in enum)
///   - title is missing (required field)
///   - lessons[0].estimated_minutes is -30 (violates positive())
///   - lessons[1].topic is empty (violates min(1))
///   - lessons[2] is missing lesson_id (required field)
fn mock_round1_response() -> Json {
  Json::object({
    "course_id": Json::string("CS101"),
    "difficulty": Json::string("expert"),
    "lessons": Json::array([
      Json::object({
        "lesson_id": Json::number(1.0),
        "topic": Json::string("Introduction to Algorithms"),
        "estimated_minutes": Json::number(-30.0),
      }),
      Json::object({
        "lesson_id": Json::number(2.0),
        "topic": Json::string(""),
        "estimated_minutes": Json::number(45.0),
      }),
      Json::object({
        "topic": Json::string("Graph Theory"),
        "estimated_minutes": Json::number(60.0),
      }),
    ]),
    "instructor": Json::string("Dr. Smith"),
    "metadata": Json::object({
      "department": Json::string("Computer Science"),
      "credits": Json::number(3.0),
    }),
  })
}

///|
/// Round 2 mock: structural types fixed but rule violations remain.
///   - title is "Math" (too short, min(5) violation)
///   - All other fields now have correct types and enum values
fn mock_round2_response() -> Json {
  Json::object({
    "course_id": Json::number(101.0),
    "title": Json::string("Math"),
    "difficulty": Json::string("intermediate"),
    "lessons": Json::array([
      Json::object({
        "lesson_id": Json::number(1.0),
        "topic": Json::string("Linear Algebra Basics"),
        "estimated_minutes": Json::number(45.0),
      }),
      Json::object({
        "lesson_id": Json::number(2.0),
        "topic": Json::string("Matrix Operations"),
        "estimated_minutes": Json::number(60.0),
      }),
    ]),
    "instructor": Json::string("Dr. Smith"),
    "metadata": Json::object({
      "department": Json::string("Mathematics"),
      "credits": Json::number(4.0),
    }),
  })
}

///|
/// Round 3 mock: structurally perfect + 12 hallucinated LLM metadata fields.
/// moon_zod's default Strip mode silently removes them all.
fn mock_round3_response() -> Json {
  let map : Map[String, Json] = {
    "course_id": Json::number(101.0),
    "title": Json::string("Mathematics for Computer Science"),
    "difficulty": Json::string("intermediate"),
    "lessons": Json::array([
      Json::object({
        "lesson_id": Json::number(1.0),
        "topic": Json::string("Linear Algebra Basics"),
        "estimated_minutes": Json::number(45.0),
      }),
      Json::object({
        "lesson_id": Json::number(2.0),
        "topic": Json::string("Matrix Operations"),
        "estimated_minutes": Json::number(60.0),
      }),
    ]),
    "instructor": Json::string("Dr. Smith"),
    "metadata": Json::object({
      "department": Json::string("Mathematics"),
      "credits": Json::number(4.0),
    }),
  }
  // Inject 12 hallucinated LLM metadata fields
  map.set("llm_model", Json::string("gpt-5-turbo"))
  map.set("generated_at", Json::string("2026-06-06T12:00:00Z"))
  map.set("confidence_score", Json::number(0.97))
  map.set("internal_id", Json::string("req_x9f2a1b"))
  map.set("cache_key", Json::string("ck_cache_v3"))
  map.set("request_id", Json::string("rid_7712ab34"))
  map.set("temperature", Json::number(0.7))
  map.set("top_p", Json::number(0.95))
  map.set("max_tokens", Json::number(4096.0))
  map.set("seed", Json::number(42.0))
  map.set("stream_flag", Json::boolean(false))
  map.set("version_tag", Json::string("v2.1.0-beta"))
  Json::object(map)
}
