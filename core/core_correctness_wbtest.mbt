///|
fn review_expect_json(result : SchemaResult, expected : Json) -> Unit raise {
  guard result is Ok(value) else { fail("expected Ok") }
  @debug.assert_eq(value, expected)
}

///|
test "parent refinement receives parsed children after continuable failures" {
  let seen : Array[Json] = []
  let schema = object({ "a": string().trim(), "b": string().min(3) }).refine(
    fn(value) {
      seen.push(value)
      false
    },
    "parent constraint",
  )
  guard schema.parse(parse_json("{\"a\":\" x \",\"b\":\"y\"}")) is Err(errors) else {
    fail("expected errors")
  }
  assert_eq(errors.length(), 2)
  assert_eq(seen.length(), 1)
  @debug.assert_eq(seen[0], parse_json("{\"a\":\"x\",\"b\":\"y\"}"))
}

///|
test "intersection recursively merges parsed arrays" {
  let left = array(object({ "a": number() }))
  let right = array(object({ "b": number() }))
  review_expect_json(
    intersection([left, right]).parse(parse_json("[{\"a\":1,\"b\":2}]")),
    parse_json("[{\"a\":1,\"b\":2}]"),
  )
}

///|
test "intersection reports nested output conflicts" {
  let left = object({ "a": string().transform(fn(_) { Ok(Json::number(1.0)) }) })
  let right = object({
    "a": string().transform(fn(_) { Ok(Json::number(2.0)) }),
  })
  guard intersection([left, right]).parse(parse_json("{\"a\":\"x\"}"))
    is Err(errors) else {
    fail("expected conflict")
  }
  assert_eq(errors[0].path, "a")
}

///|
test "review array propagates parsed values" {
  review_expect_json(
    array(string().trim()).parse(parse_json("[\" x \"]")),
    parse_json("[\"x\"]"),
  )
}

///|
test "review array strips nested fields" {
  review_expect_json(
    array(object({ "a": number() })).parse(
      parse_json("[{\"a\":1,\"extra\":2}]"),
    ),
    parse_json("[{\"a\":1}]"),
  )
}

///|
test "review tuple propagates parsed values" {
  review_expect_json(
    tuple([string().trim()]).parse(parse_json("[\" x \"]")),
    parse_json("[\"x\"]"),
  )
}

///|
test "review strict object propagates parsed values" {
  review_expect_json(
    object({ "a": string().trim() })
    .strict()
    .parse(parse_json("{\"a\":\" x \"}")),
    parse_json("{\"a\":\"x\"}"),
  )
}

///|
test "review passthrough object propagates parsed values" {
  review_expect_json(
    object({ "a": string().trim() })
    .passthrough()
    .parse(parse_json("{\"a\":\" x \",\"extra\":2}")),
    parse_json("{\"a\":\"x\",\"extra\":2}"),
  )
}

///|
test "review union refine is executed" {
  assert_true(
    union([string(), number()])
    .refine(fn(_) { false }, "reject")
    .parse(Json::string("x"))
    is Err(_),
  )
}

///|
test "review intersection refine is executed" {
  assert_true(
    intersection([string()])
    .refine(fn(_) { false }, "reject")
    .parse(Json::string("x"))
    is Err(_),
  )
}

///|
test "review enum refine is executed" {
  assert_true(
    enum_values(["x"])
    .refine(fn(_) { false }, "reject")
    .parse(Json::string("x"))
    is Err(_),
  )
}

///|
test "review literal refine is executed" {
  assert_true(
    literal(Json::string("x"))
    .refine(fn(_) { false }, "reject")
    .parse(Json::string("x"))
    is Err(_),
  )
}

///|
test "review optional refine can reject null" {
  assert_true(
    string().optional().refine(fn(_) { false }, "reject").parse(Json::null())
    is Err(_),
  )
}

///|
test "review intersection strips extra keys" {
  review_expect_json(
    intersection([object({ "a": number() }), object({ "b": number() })]).parse(
      parse_json("{\"a\":1,\"b\":2,\"extra\":3}"),
    ),
    parse_json("{\"a\":1,\"b\":2}"),
  )
}

///|
test "review intersection does not mutate input" {
  let input = parse_json("{\"a\":\" x \"}")
  let original = parse_json("{\"a\":\" x \"}")
  let _ = intersection([
    object({ "a": string().trim() }),
    object({ "a": string() }),
  ]).parse(input)
  @debug.assert_eq(input, original)
}

///|
test "review intersection detects incompatible primitive outputs" {
  assert_true(
    intersection([
      string().transform(fn(_) { Ok(Json::number(1.0)) }),
      string().transform(fn(_) { Ok(Json::number(2.0)) }),
    ]).parse(Json::string("x"))
    is Err(_),
  )
}

///|
test "review object refine receives parsed fields" {
  let s = object({ "a": string().trim() }).refine(
    fn(v) { v == parse_json("{\"a\":\"x\"}") },
    "must be cleaned",
  )
  assert_true(s.parse(parse_json("{\"a\":\" x \"}")) is Ok(_))
}

///|
test "review object refine skips invalid child types" {
  let calls : Array[Int32] = []
  let s = object({ "a": string() }).refine(
    fn(_) {
      calls.push(1)
      true
    },
    "check",
  )
  assert_true(s.parse(parse_json("{\"a\":1}")) is Err(_))
  assert_eq(calls.length(), 0)
}

///|
test "review message targets latest transform refine" {
  let s = string()
    .min(1)
    .transform(fn(v) { Ok(v) })
    .refine(fn(_) { false }, "old")
    .message("new")
  guard s.parse(Json::string("x")) is Err(errors) else {
    fail("expected error")
  }
  assert_eq(errors[0].message, "new")
}

///|
test "review intersection leaves failed input unchanged" {
  let input = parse_json("{\"a\":\" x \"}")
  let original = parse_json("{\"a\":\" x \"}")
  let s = intersection([
    object({ "a": string().trim() }),
    object({ "missing": string() }),
  ])
  assert_true(s.parse(input) is Err(_))
  @debug.assert_eq(input, original)
}

///|
test "review intersection preserves nested fields of both outputs" {
  let s = intersection([
    object({ "nested": object({ "a": number() }) }),
    object({ "nested": object({ "b": number() }) }),
  ])
  assert_true(s.parse(parse_json("{\"nested\":{\"a\":1,\"b\":2}}")) is Ok(_))
}

///|
test "review ordinary pipe refine is still enforced" {
  assert_true(
    string()
    .trim()
    .pipe(string())
    .refine(fn(_) { false }, "reject")
    .parse(Json::string("x"))
    is Err(_),
  )
}
