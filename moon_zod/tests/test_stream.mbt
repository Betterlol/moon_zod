///|
test "parse_stream accepts one JSON object across token boundaries" {
  let schema = @core.object({
    "name": @core.string().min(2),
    "age": @core.number().int(),
  })
  let parser = schema.parse_stream()
  guard parser.feed("{\"na") is StreamPending else { fail("expected pending") }
  guard parser.feed("me\":\"Ada\",\"age\":") is StreamPending else {
    fail("expected pending")
  }
  assert_true(parser.feed("42}") is StreamPending)
  guard parser.finish() is StreamValid(Object(value)) else {
    fail("expected a valid object")
  }
  @debug.assert_eq(value.get("name"), Some(Json::string("Ada")))
  @debug.assert_eq(value.get("age"), Some(Json::number(42.0)))
}

///|
test "parse_stream preserves string escapes split between tokens" {
  let parser = @core.object({ "text": @core.string() }).parse_stream()
  guard parser.feed("{\"text\":\"a\\") is StreamPending else {
    fail("expected pending")
  }
  assert_true(parser.feed("\"b\"}") is StreamPending)
  guard parser.finish() is StreamValid(Object(value)) else {
    fail("expected valid escaped string")
  }
  @debug.assert_eq(value.get("text"), Some(Json::string("a\"b")))
}

///|
test "parse_stream reports schema failures at finish" {
  let parser = @core.object({ "age": @core.number().positive() }).parse_stream()
  guard parser.feed("{\"age\":") is StreamPending else {
    fail("expected pending")
  }
  assert_true(parser.feed("-1}") is StreamPending)
  guard parser.finish() is StreamInvalidSchema(errors) else {
    fail("expected schema failure")
  }
  @debug.assert_eq(errors[0].path, "age")
}

///|
test "parse_stream reports malformed JSON without waiting for finish" {
  let parser = @core.object(Map([])).parse_stream()
  guard parser.feed("{") is StreamPending else { fail("expected pending") }
  guard parser.feed("]") is StreamInvalidJson(message) else {
    fail("expected invalid JSON")
  }
  @debug.assert_eq(message, "Mismatched closing delimiter")
}

///|
test "parse_stream rejects a closing delimiter after a scalar" {
  let parser = @core.number().parse_stream()
  guard parser.feed("1]") is StreamInvalidJson(message) else {
    fail("expected invalid JSON")
  }
  @debug.assert_eq(message, "Unexpected closing delimiter after a JSON scalar")
}

///|
test "parse_stream finishes a scalar root and rejects incomplete input" {
  let scalar = @core.number().parse_stream()
  guard scalar.feed("42") is StreamPending else { fail("expected pending") }
  guard scalar.finish() is StreamValid(Number(value, ..)) else {
    fail("expected valid scalar")
  }
  @debug.assert_eq(value, 42.0)

  let incomplete = @core.object(Map([])).parse_stream()
  guard incomplete.feed("{") is StreamPending else { fail("expected pending") }
  guard incomplete.finish() is StreamInvalidJson("Incomplete JSON input") else {
    fail("expected incomplete JSON error")
  }
}

///|
test "parse_stream rejects trailing content for every chunk split" {
  for source in ["{}garbage", "[]{}", "\"hello\"true", "42 false"] {
    for offset in 0..<=source.length() {
      let parser = @core.unknown().parse_stream()
      ignore(parser.feed(source[:offset].to_owned()))
      ignore(parser.feed(source[offset:].to_owned()))
      assert_true(parser.finish() is StreamInvalidJson(_))
    }
  }
}

///|
test "parse_stream waits for finish before returning success or running rules" {
  let calls : Array[Int32] = []
  let parser = @core.unknown()
    .refine(
      _ => {
        calls.push(1)
        true
      },
      "unused",
    )
    .parse_stream()
  assert_true(parser.feed("{}") is StreamPending)
  assert_true(parser.feed(" \r\n\t") is StreamPending)
  assert_eq(calls.length(), 0)
  assert_true(parser.finish() is StreamValid(_))
  assert_true(parser.finish() is StreamValid(_))
  assert_eq(calls.length(), 1)
}

///|
test "parse_stream preserves valid JSON at every two-chunk split" {
  for
    source in [
      "{\"text\":\"a\\\"b\\\\c\\u0041\",\"nested\":[true,null,-1.25e+2]}", "\"你好🌙\"",
      "  [1,{},[\"{[}]\"]]\r\n", "42", "true", "null",
    ] {
    for offset in 0..<=source.length() {
      let (left, right) = source.split_at(offset)
      let parser = @core.unknown().parse_stream()
      assert_true(parser.feed(left.to_owned()) is StreamPending)
      assert_true(parser.feed(right.to_owned()) is StreamPending)
      guard parser.finish() is StreamValid(value) else {
        fail("expected valid JSON")
      }
      @debug.assert_eq(value, @json.parse(source))
    }
  }
}

///|
test "parse_stream bounds all input before retaining oversized chunks" {
  let parser = @core.unknown().parse_stream(max_length=4)
  assert_true(parser.feed("{}") is StreamPending)
  assert_true(parser.feed("  ") is StreamPending)
  assert_true(parser.finish() is StreamValid(_))
  let over = @core.unknown().parse_stream(max_length=4)
  assert_true(over.feed("{}") is StreamPending)
  assert_true(
    over.feed("   ") is StreamInvalidJson("JSON input exceeds max_length"),
  )
  assert_true(over.finish() is StreamInvalidJson(_))
  let unclosed = @core.unknown().parse_stream(max_length=4)
  assert_true(unclosed.feed("\"abc") is StreamPending)
  assert_true(unclosed.feed("x") is StreamInvalidJson(_))
  let large = @core.unknown().parse_stream(max_length=4)
  assert_true(large.feed("x".repeat(4096)) is StreamInvalidJson(_))
}

///|
test "parse_stream bounds nesting across chunks and ignores brackets in strings" {
  let parser = @core.unknown().parse_stream(max_depth=2)
  assert_true(parser.feed("[{") is StreamPending)
  assert_true(parser.feed("}]") is StreamPending)
  assert_true(parser.finish() is StreamValid(_))
  let deep = @core.unknown().parse_stream(max_depth=2)
  assert_true(deep.feed("[[") is StreamPending)
  assert_true(
    deep.feed("[") is StreamInvalidJson("JSON nesting exceeds max_depth"),
  )
  let text = @core.string().parse_stream(max_depth=1)
  assert_true(text.feed("\"[[[{{{\"") is StreamPending)
  assert_true(text.finish() is StreamValid(_))
}

///|
test "parse_stream forwards root path and preserves schema cleanup" {
  let parser = @core.object({ "name": @core.string().trim() }).parse_stream(
    path="request",
  )
  assert_true(parser.feed("{\"name\":\" Ada \",\"extra\":1}") is StreamPending)
  guard parser.finish() is StreamValid(value) else {
    fail("expected cleaned JSON")
  }
  @debug.assert_eq(value, Json::object({ "name": Json::string("Ada") }))
  let invalid = @core.object({ "age": @core.number() }).parse_stream(
    path="request",
  )
  assert_true(invalid.feed("{\"age\":false}") is StreamPending)
  guard invalid.finish() is StreamInvalidSchema(errors) else {
    fail("expected error")
  }
  assert_eq(errors[0].path, "request.age")
}
