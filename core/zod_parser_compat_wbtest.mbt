///|
/// Differential expectations are pinned to local Zod 4.6.7 (afdac65).
test "zod strict intersections reconcile branch-owned keys" {
  let left = object({ "a": string() }).strict()
  let right = object({ "b": string() }).strict()
  review_expect_json(
    intersection([left, right]).parse(parse_json("{\"a\":\"x\",\"b\":\"y\"}")),
    parse_json("{\"a\":\"x\",\"b\":\"y\"}"),
  )
  guard intersection([left, right]).parse(
      parse_json("{\"a\":\"x\",\"b\":\"y\",\"c\":1}"),
    )
    is Err(errors) else {
    fail("shared unknown key")
  }
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].code, UnrecognizedKeys(["c"]))
  review_expect_json(
    intersection([left, object({ "b": string() })]).parse(
      parse_json("{\"a\":\"x\",\"b\":\"y\",\"c\":1}"),
    ),
    parse_json("{\"a\":\"x\",\"b\":\"y\"}"),
  )
}

///|
test "zod strict intersection reconciliation is local to its object" {
  let nested = intersection([
    object({ "inner": object({ "a": string() }).strict() }),
    object({ "inner": object({ "b": string() }) }),
  ])
  guard nested.parse(parse_json("{\"inner\":{\"a\":\"x\",\"b\":\"y\"}}"))
    is Err(errors) else {
    fail("nested strict must survive")
  }
  assert_eq(errors[0].code, UnrecognizedKeys(["b"]))
  assert_eq(errors[0].path, "inner.b")
}

///|
test "zod strict branches retain effects and output failures" {
  let left = object({ "a": string() })
    .strict()
    .transform(fn(v) { Ok(v) })
    .pipe(object({ "a": string().trim() }))
  let right = object({ "b": string() }).strict()
  review_expect_json(
    intersection([left, right]).parse(parse_json("{\"a\":\" x \",\"b\":\"y\"}")),
    parse_json("{\"a\":\"x\",\"b\":\"y\"}"),
  )
  let failing = object({ "a": string() })
    .strict()
    .transform(fn(_) { Err("effect failed") })
  guard intersection([failing, right]).parse(
      parse_json("{\"a\":\"x\",\"b\":\"y\"}"),
    )
    is Err(errors) else {
    fail("effect failure")
  }
  assert_true(errors.any(fn(e) { e.message == "effect failed" }))
  assert_true(
    object({ "a": string() })
    .strict()
    .transform(fn(v) { Ok(v) })
    .parse(parse_json("{\"a\":\"x\",\"extra\":1}"))
    is Err(_),
  )
}

///|
test "zod fractional integer failures stop later and parent refinements" {
  let calls : Array[Int32] = []
  let integer = number()
    .int()
    .refine(
      fn(_) {
        calls.push(1)
        true
      },
      "child",
    )
  let schema = object({ "n": integer }).refine(
    fn(_) {
      calls.push(2)
      true
    },
    "parent",
  )
  assert_true(schema.parse(parse_json("{\"n\":1.5}")) is Err(_))
  assert_eq(calls.length(), 0)
  guard integer.parse(Json::number(1.5)) is Err(errors) else {
    fail("fractional")
  }
  assert_eq(errors[0].code, InvalidType("int"))
  assert_true(integer.parse(Json::number(9007199254740992.0)) is Err(_))
  assert_eq(calls.length(), 1)
}

///|
test "zod integer range failures remain continuable" {
  for value in [9007199254740992.0, -9007199254740992.0] {
    let calls : Array[Int32] = []
    guard number()
      .int()
      .refine(
        fn(_) {
          calls.push(1)
          true
        },
        "check",
      )
      .parse(Json::number(value))
      is Err(errors) else {
      fail("unsafe integer")
    }
    assert_eq(calls.length(), 1)
    assert_eq(
      errors[0].code,
      if value > 0 {
        TooBig("int", 9007199254740991.0, true)
      } else {
        TooSmall("int", -9007199254740991.0, true)
      },
    )
  }
}

///|
test "zod builtin effects continue after ordinary constraint failures" {
  let observed : Array[Json] = []
  guard string()
    .min(3)
    .trim()
    .refine(
      fn(v) {
        observed.push(v)
        false
      },
      "after trim",
    )
    .parse(Json::string(" x"))
    is Err(errors) else {
    fail("min failure")
  }
  assert_eq(errors.length(), 2)
  @debug.assert_eq(observed, [Json::string("x")])
  let custom_calls : Array[Int32] = []
  assert_true(
    string()
    .min(3)
    .transform(fn(v) {
      custom_calls.push(1)
      Ok(v)
    })
    .parse(Json::string(" x"))
    is Err(_),
  )
  assert_eq(custom_calls.length(), 0)
}

///|
test "zod optional swallows failed absent prefaults but rejects present invalid input" {
  let field = string().min(3).prefault(Json::string("x")).optional()
  review_expect_json(
    object({ "a": field }).parse(Json::empty_object()),
    Json::empty_object(),
  )
  assert_true(field.parse_missing() is Ok(None))
  assert_true(field.parse(Json::string("x")) is Err(_))
  review_expect_json(
    object({ "a": string().min(3).prefault(Json::string("abc")).optional() }).parse(
      Json::empty_object(),
    ),
    parse_json("{\"a\":\"abc\"}"),
  )
}

///|
test "zod outer optional does not activate preprocess inner defaults" {
  let calls : Array[Int32] = []
  let field = preprocess(
    fn(v) {
      calls.push(1)
      Ok(v)
    },
    string().default(Json::string("fallback")),
  ).optional()
  review_expect_json(
    object({ "a": field }).parse(Json::empty_object()),
    Json::empty_object(),
  )
  assert_eq(calls.length(), 0)
}

///|
test "zod tuple reports minimum required prefix and all present failures" {
  guard tuple([string(), string().optional()]).parse(Json::array([]))
    is Err(errors) else {
    fail("required prefix")
  }
  assert_eq(errors[0].code, TooSmall("tuple", 1.0, true))
  guard tuple([string()]).parse(parse_json("[1,2]")) is Err(errors) else {
    fail("overlong tuple")
  }
  assert_eq(errors.length(), 2)
  assert_eq(errors[0].code, TooBig("tuple", 1.0, true))
  assert_eq(errors[1].path, "[0]")
}

///|
test "zod exact length diagnostics preserve direction" {
  guard string().length(2).parse(Json::string("x")) is Err(errors) else {
    fail("too short")
  }
  assert_eq(errors[0].code, TooSmall("string", 2.0, true))
  guard array(string()).length(1).parse(parse_json("[\"a\",\"b\"]"))
    is Err(errors) else {
    fail("too long")
  }
  assert_eq(errors[0].code, TooBig("array", 1.0, true))
}

///|
test "strict issues survive effects on substituted missing input" {
  let inner = object({ "a": string() })
    .strict()
    .prefault(parse_json("{\"a\":\"x\",\"extra\":1}"))
  assert_true(inner.transform(fn(v) { Ok(v) }).parse_missing() is Err(_))
  assert_true(inner.pipe(object({ "a": string() })).parse_missing() is Err(_))
}

///|
test "zod outer optional preserves absence before pipeline output defaults" {
  let schema = string().optional().pipe(string().default(Json::string("x")))
  assert_true(schema.parse_missing() is Ok(Some(String("x"))))
  assert_true(schema.optional().parse_missing() is Ok(None))
}

///|
test "zod absent strict intersection prefaults reconcile their own keys" {
  let fallback = parse_json("{\"a\":\"x\",\"b\":\"y\"}")
  let schema = intersection([
    object({ "a": string() }).strict().prefault(fallback),
    object({ "b": string() }).strict().prefault(fallback),
  ])
  assert_true(schema.parse_missing() is Ok(Some(value)) && value == fallback)
  let extra = parse_json("{\"a\":\"x\",\"b\":\"y\",\"c\":1}")
  assert_true(
    intersection([
      object({ "a": string() }).strict().prefault(extra),
      object({ "b": string() }).strict().prefault(extra),
    ]).parse_missing()
    is Err(_),
  )
}

///|
test "zod optional does not activate defaults inside intersections" {
  let combined = intersection([
    string().default(Json::string("a")),
    string().default(Json::string("a")),
  ])
  assert_true(combined.parse_missing() is Ok(Some(String("a"))))
  assert_true(combined.optional().parse_missing() is Ok(None))
  review_expect_json(
    object({ "v": combined.optional() }).parse(Json::empty_object()),
    Json::empty_object(),
  )
}

///|
test "zod bare intersection defaults do not make object and tuple positions optional" {
  let field = intersection([
    string().default(Json::string("a")),
    string().default(Json::string("a")),
  ])
  assert_true(object({ "v": field }).parse(Json::empty_object()) is Err(_))
  assert_true(tuple([field]).parse(Json::array([])) is Err(_))
  assert_true(field.parse_missing() is Ok(Some(String("a"))))
}

///|
test "zod overlong tuples stop tuple and parent refinements" {
  let calls : Array[Int32] = []
  let field = tuple([string()]).refine(
    fn(_) {
      calls.push(1)
      true
    },
    "tuple",
  )
  let schema = object({ "v": field }).refine(
    fn(_) {
      calls.push(2)
      true
    },
    "parent",
  )
  assert_true(schema.parse(parse_json("{\"v\":[\"a\",\"b\"]}")) is Err(_))
  assert_eq(calls.length(), 0)
}
