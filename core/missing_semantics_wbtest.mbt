///|
test "optional rejects explicit null while nullable requires its key" {
  assert_true(string().optional().parse(Json::null()) is Err(_))
  assert_true(
    object({ "a": string().nullable() }).parse(Json::empty_object()) is Err(_),
  )
  assert_true(string().nullable().parse(Json::null()) is Ok(_))
}

///|
test "default inserts missing output but does not replace null" {
  review_expect_json(
    object({ "a": string().default(Json::string("x")) }).parse(
      Json::empty_object(),
    ),
    parse_json("{\"a\":\"x\"}"),
  )
  assert_true(string().default(Json::string("x")).parse(Json::null()) is Err(_))
}

///|
test "optional wrapped effects preserve absence and nested default fills it" {
  review_expect_json(
    object({ "a": string().optional().transform(fn(v) { Ok(v) }) }).parse(
      Json::empty_object(),
    ),
    Json::empty_object(),
  )
  review_expect_json(
    object({ "a": string().default(Json::string("x")).optional() }).parse(
      Json::empty_object(),
    ),
    parse_json("{\"a\":\"x\"}"),
  )
}

///|
test "prefault parses its fallback while default returns output fallback" {
  let transformed = string().transform(fn(v) {
    match v {
      String(s) => Ok(Json::number(s.length().to_double()))
      _ => Err("string")
    }
  })
  review_expect_json(
    object({ "a": transformed.prefault(Json::string("abc")) }).parse(
      Json::empty_object(),
    ),
    parse_json("{\"a\":3}"),
  )
  review_expect_json(
    object({ "a": transformed.default(Json::number(99.0)) }).parse(
      Json::empty_object(),
    ),
    parse_json("{\"a\":99}"),
  )
}

///|
test "nullish preserves explicit null and accepts missing keys" {
  let schema = object({ "a": string().nullish() })
  review_expect_json(schema.parse(Json::empty_object()), Json::empty_object())
  review_expect_json(
    schema.parse(parse_json("{\"a\":null}")),
    parse_json("{\"a\":null}"),
  )
}

///|
test "outer default refinement checks substituted output" {
  assert_true(
    object({
      "a": number().default(Json::number(1.0)).refine(fn(_) { false }, "reject"),
    }).parse(Json::empty_object())
    is Err(_),
  )
}

///|
test "tuple permits optional trailing values and materializes defaults" {
  review_expect_json(
    tuple([string(), number().optional()]).parse(parse_json("[\"x\"]")),
    parse_json("[\"x\"]"),
  )
  review_expect_json(
    tuple([string(), number().default(Json::number(1.0))]).parse(
      parse_json("[\"x\"]"),
    ),
    parse_json("[\"x\",1]"),
  )
}

///|
test "missing default still runs enclosing transformations" {
  review_expect_json(
    object({ "a": string().default(Json::string(" x ")).trim().optional() }).parse(
      Json::empty_object(),
    ),
    parse_json("{\"a\":\"x\"}"),
  )
  review_expect_json(
    object({ "a": string().default(Json::string("x")).pipe(string()) }).parse(
      Json::empty_object(),
    ),
    parse_json("{\"a\":\"x\"}"),
  )
}
