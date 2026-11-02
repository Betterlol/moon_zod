///|
test "outer optional preserves absence before a pipeline output default" {
  let schema = string().optional().pipe(string().default(Json::string("x")))
  assert_true(schema.parse_missing() is Ok(Some(String("x"))))
  assert_true(schema.optional().parse_missing() is Ok(None))
  guard object({ "v": schema }).partial().parse(parse_json("{}")) is Ok(result) else {
    fail("expected absent optional field")
  }
  @debug.assert_eq(result, parse_json("{}"))
}

///|
test "nested pipelines keep optional absence through lazy" {
  let schema = recursive(fn() {
    string().optional().pipe(string().trim().prefault(Json::string(" x ")))
  })
  assert_true(schema.optional().parse_missing() is Ok(None))
}

///|
test "an unreachable output default does not make input required under optional" {
  let schema = string().pipe(string().default(Json::string("x"))).optional()
  assert_true(schema.parse_missing() is Ok(None))
}
