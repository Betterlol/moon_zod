///|
/// moon_zod Schema Generator — JSON to `@moon_zod` source code
///
/// A zero-dependency CLI utility that traverses a JSON AST and generates
/// the corresponding moon_zod schema expression. Designed for rapid
/// schema prototyping from real API payloads.
///
/// Run with: moon run cmd/json2schema
fn main {
  // ── Chinese teaching payload (realistic AI Agent scenario) ──────
  let mock_input = @json.parse(
    "{\"lesson_id\":101,\"hsk_level\":4,\"vocabulary\":[{\"hanzi\":\"你好\",\"pinyin\":\"nǐ hǎo\",\"translation\":\"hello\"},{\"hanzi\":\"老师\",\"pinyin\":\"lǎo shī\",\"translation\":\"teacher\"}],\"situational_dialogue\":{\"context\":\"At the airport\",\"speakers\":[{\"name\":\"Li Ming\",\"dialogue\":\"你好！请问机场怎么走？\"},{\"name\":\"Agent\",\"dialogue\":\"请跟我来。\"}]},\"is_published\":true}",
  ) catch {
    _ => abort("invalid mock JSON")
  }

  println(
    "╔══════════════════════════════════════════════════════════╗",
  )
  println("║   moon_zod Schema Generator — Chinese Teaching Demo     ║")
  println(
    "╚══════════════════════════════════════════════════════════╝",
  )
  println("")
  println("── Input JSON ──")
  println(mock_input)
  println("")
  println("── Generated moon_zod Schema (copy-paste ready) ──")
  println(infer_schema(mock_input, 0))
  println("")
  println("── End ──")
}

///|
/// Infer a moon_zod schema expression from a JSON value.
///
/// @param json   The JSON value to analyze.
/// @param indent Current nesting depth (each level = 2 spaces).
/// @returns      A `@moon_zod.*` expression string.
fn infer_schema(json : Json, indent : Int) -> String {
  match json {
    String(_) => "@moon_zod.string()"
    Number(_) => "@moon_zod.number()"
    True | False => "@moon_zod.boolean()"
    Null => "@moon_zod.null()"
    Array(elements) => infer_array_schema(elements, indent)
    Object(map) => infer_object_schema(map, indent)
  }
}

///|
/// Generate an `@moon_zod.object({...})` expression from a JSON object.
fn infer_object_schema(map : Map[String, Json], indent : Int) -> String {
  let mut result = "@moon_zod.object({\n"
  let mut first = true
  for key in map.keys() {
    if !first {
      result = result + ",\n"
    }
    first = false
    match map.get(key) {
      Some(val) => {
        let field_schema = infer_schema(val, indent + 1)
        result = result + pad(indent + 1) + "\"" + key + "\": " + field_schema
      }
      None => ()
    }
  }
  if first {
    // Empty map
    "@moon_zod.object({})"
  } else {
    result = result + ",\n" + pad(indent) + "})"
    result
  }
}

///|
/// Generate an `@moon_zod.array(...)` expression from a JSON array.
/// Inspects the first element to infer the element schema.
/// Empty arrays default to `@moon_zod.array(@moon_zod.string())`.
fn infer_array_schema(elements : Array[Json], indent : Int) -> String {
  let inner = if elements.length() > 0 {
    infer_schema(elements[0], indent + 1)
  } else {
    "@moon_zod.string()"
  }
  if has_newlines(inner) {
    "@moon_zod.array(\n" + pad(indent + 1) + inner + "\n" + pad(indent) + ")"
  } else {
    "@moon_zod.array(" + inner + ")"
  }
}

///|
/// Check if a string contains newline characters.
fn has_newlines(s : String) -> Bool {
  for c in s.to_array() {
    if c == '\n' {
      return true
    }
  }
  false
}

///|
/// Generate an indentation string for a given nesting level.
/// Each level produces 2 spaces.
fn pad(level : Int) -> String {
  let mut spaces = ""
  for i = 0; i < level * 2; i = i + 1 {
    spaces = spaces + " "
  }
  spaces
}
