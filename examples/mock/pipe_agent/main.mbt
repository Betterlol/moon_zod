///|
/// Pipe-Type Multi-Stage Self-Correction Demo
///
/// Simulates an LLM agent loop where the model's text output must pass
/// through a two-stage validation pipeline:
///   1. String stage: raw output must be a non-empty string
///   2. Transform: parse the string as a JSON number
///   3. Pipe stage: the number must be an integer between 1-100
///
/// Correction prompts are stage-aware — they only report the failing
/// step, not the whole pipeline.
///
/// Run with: moon run examples/mock/pipe_agent

///|
/// Try to parse a JSON string value as a number.
fn parse_json_number(json : Json) -> Result[Json, String] {
  match json {
    String(s) => {
      let trimmed = s.trim()
      let parsed = @json.parse(trimmed) catch { _ => Json::null() }
      match parsed {
        Number(_) => Ok(parsed)
        _ => Err("cannot parse \"\{s}\" as a number")
      }
    }
    _ => Err("expected a string")
  }
}

///|
fn main {
  println(
    "╔══════════════════════════════════════════════════════════╗",
  )
  println("║   Multi-Stage Self-Correction Loop with .pipe()        ║")
  println(
    "╚══════════════════════════════════════════════════════════╝",
  )
  println("")

  // ── Two-stage validation pipeline ────────────────────────
  let score_pipeline = @moon_zod.string()
    .min(1)
    .transform(parse_json_number)
    .pipe(@moon_zod.number().int().min(1).max(100))

  // ═══════════════════════════════════════════════════════════
  // Round 1 — LLM outputs a word, not a number
  // ═══════════════════════════════════════════════════════════
  println(
    "─── [Round 1] Prompt to LLM ───────────────────────────",
  )
  println("  > Generate a single integer score between 1 and 100.")
  println("  > Return ONLY the number, no extra text.")
  println("")

  let llm_output1 = Json::string("forty-two")
  println(
    "─── [Round 1] LLM raw output ──────────────────────────",
  )
  println("  \"forty-two\"")
  println("")

  let r1_result = score_pipeline.parse(llm_output1)
  guard r1_result is Err(_) else { println("PASS (unexpected)") }
  println(
    "─── [Round 1] Validation breakdown ───────────────────",
  )
  println("  ✓ Stage 1 (string raw)       → PASS (non-empty)")
  println("  ✗ Transform (parse number)   → FAIL")
  println("  - Stage 2 (number validate)  → SKIPPED")
  println("")

  println(
    "─── [Round 1] Stage-aware correction prompt ─────────",
  )
  println("  Your response \"forty-two\" is not a valid number.")
  println("  I could not parse it as a numeric value.")
  println("  Please write a plain integer like 42, 73, or 100.")
  println("")

  // ═══════════════════════════════════════════════════════════
  // Round 2 — LLM fixes to a number, but out of range
  // ═══════════════════════════════════════════════════════════
  println("─── [Round 2] Prompt to LLM (with correction context) ──")
  println("  > Your last output could not be parsed.")
  println("  > Write a plain number between 1 and 100.")
  println("")

  let llm_output2 = Json::string("200")
  println(
    "─── [Round 2] LLM raw output ──────────────────────────",
  )
  println("  \"200\"")
  println("")

  let r2_result = score_pipeline.parse(llm_output2)
  guard r2_result is Err(errors) else { println("PASS (unexpected)") }
  let code_2 = errors[0].code
  let msg_2 = errors[0].message
  println(
    "─── [Round 2] Validation breakdown ───────────────────",
  )
  println("  ✓ Stage 1 (string raw)       → PASS")
  println("  ✓ Transform (parse number)   → PASS (parsed as 200)")
  println("  ✗ Stage 2 (number validate)  → FAIL")
  println("     \{msg_2}")
  println("     (code: \{@debug.to_string(code_2)})")
  println("")

  println(
    "─── [Round 2] Stage-aware correction prompt ─────────",
  )
  println("  You wrote \"200\", but the maximum allowed is 100.")
  println("  Your numeric value 200 exceeds the upper limit.")
  println("  Please pick a number between 1 and 100.")
  println("")

  // ═══════════════════════════════════════════════════════════
  // Round 3 — LLM finally gets it right
  // ═══════════════════════════════════════════════════════════
  println("─── [Round 3] Prompt to LLM (with correction context) ──")
  println("  > Your last output 200 was out of range.")
  println("  > Provide a number between 1 and 100.")
  println("")

  let llm_output3 = Json::string("73")
  println(
    "─── [Round 3] LLM raw output ──────────────────────────",
  )
  println("  \"73\"")
  println("")

  let r3_result = score_pipeline.parse(llm_output3)
  guard r3_result is Ok(v) else { println("FAIL (unexpected)") }
  println(
    "─── [Round 3] Validation breakdown ───────────────────",
  )
  println("  ✓ Stage 1 (string raw)       → PASS")
  println("  ✓ Transform (parse number)   → PASS (parsed as 73)")
  println("  ✓ Stage 2 (number validate)  → PASS")
  println("")
  println("  Final validated value: \{@debug.to_string(v)}")
  println("")
  println(
    "╔══════════════════════════════════════════════════════════╗",
  )
  println("║ Self-correction loop completed in 3 rounds.           ║")
  println(
    "╚══════════════════════════════════════════════════════════╝",
  )
}
