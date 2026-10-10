///|
test "parse_stream accepts one JSON object across token boundaries" {
  let schema = object({ "name": string().min(2), "age": number().int() })
  let parser = schema.parse_stream()
  guard parser.feed("{\"na") is StreamPending else { fail("expected pending") }
  guard parser.feed("me\":\"Ada\",\"age\":") is StreamPending else {
    fail("expected pending")
  }
  guard parser.feed("42}") is StreamValid(Object(value)) else {
    fail("expected a valid object")
  }
  @debug.assert_eq(value.get("name"), Some(Json::string("Ada")))
  @debug.assert_eq(value.get("age"), Some(Json::number(42.0)))
}

///|
test "parse_stream preserves string escapes split between tokens" {
  let parser = object({ "text": string() }).parse_stream()
  guard parser.feed("{\"text\":\"a\\") is StreamPending else {
    fail("expected pending")
  }
  guard parser.feed("\"b\"}") is StreamValid(Object(value)) else {
    fail("expected valid escaped string")
  }
  @debug.assert_eq(value.get("text"), Some(Json::string("a\"b")))
}

///|
test "parse_stream reports schema failures when the root closes" {
  let parser = object({ "age": number().positive() }).parse_stream()
  guard parser.feed("{\"age\":") is StreamPending else {
    fail("expected pending")
  }
  guard parser.feed("-1}") is StreamInvalidSchema(errors) else {
    fail("expected schema failure")
  }
  @debug.assert_eq(errors[0].path, "age")
}

///|
test "parse_stream reports malformed JSON without waiting for finish" {
  let parser = object(Map([])).parse_stream()
  guard parser.feed("{") is StreamPending else { fail("expected pending") }
  guard parser.feed("]") is StreamInvalidJson(message) else {
    fail("expected invalid JSON")
  }
  @debug.assert_eq(message, "Mismatched closing delimiter")
}

///|
test "parse_stream rejects a closing delimiter after a scalar" {
  let parser = number().parse_stream()
  guard parser.feed("1]") is StreamInvalidJson(message) else {
    fail("expected invalid JSON")
  }
  @debug.assert_eq(message, "Unexpected closing delimiter after a JSON scalar")
}

///|
test "parse_stream finishes a scalar root and rejects incomplete input" {
  let scalar = number().parse_stream()
  guard scalar.feed("42") is StreamPending else { fail("expected pending") }
  guard scalar.finish() is StreamValid(Number(value, ..)) else {
    fail("expected valid scalar")
  }
  @debug.assert_eq(value, 42.0)

  let incomplete = object(Map([])).parse_stream()
  guard incomplete.feed("{") is StreamPending else { fail("expected pending") }
  guard incomplete.finish() is StreamInvalidJson("Incomplete JSON input") else {
    fail("expected incomplete JSON error")
  }
}
