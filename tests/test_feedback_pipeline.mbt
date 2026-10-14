///|
test "outer optional preserves a reachable pipeline output default" {
  let schema = string().optional().pipe(string().default(Json::string("x")))
  assert_true(schema.parse_missing() is Ok(Some(String("x"))))
  assert_true(schema.optional().parse_missing() is Ok(Some(String("x"))))
  guard object({ "v": schema }).partial().parse(parse_json("{}")) is Ok(result) else {
    fail("expected default")
  }
  @debug.assert_eq(result, parse_json("{\"v\":\"x\"}"))
}

///|
test "nested pipelines preserve prefaults through optional and lazy" {
  let schema = recursive(fn() {
    string().optional().pipe(string().trim().prefault(Json::string(" x ")))
  })
  assert_true(schema.optional().parse_missing() is Ok(Some(String("x"))))
}

///|
test "an unreachable output default does not make input required under optional" {
  let schema = string().pipe(string().default(Json::string("x"))).optional()
  assert_true(schema.parse_missing() is Ok(None))
}
