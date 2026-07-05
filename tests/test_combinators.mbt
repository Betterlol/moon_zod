///|
/// optional()
test "object field optional passes with missing field" {
  let s = object({ "name": string().optional() })
  let input = parse_json("{}")
  match s.parse(input) {
    Ok(v) => @debug.assert_eq(v, input)
    Err(_) => fail("expected Ok")
  }
}

///|
test "object field optional passes with null" {
  let s = object({ "name": string().optional() })
  let input = parse_json("{\"name\": null}")
  match s.parse(input) {
    Ok(v) => @debug.assert_eq(v, input)
    Err(_) => fail("expected Ok")
  }
}

///|
test "object field optional still validates non-null" {
  let s = object({ "name": string().min(3).optional() })
  let input = parse_json("{\"name\": \"ab\"}")
  guard s.parse(input) is Err(_) else { fail("expected Err") }
}

///|
/// default()
test "object field default passes with missing field" {
  let s = object({ "name": string().default(Json::string("default_name")) })
  let input = parse_json("{}")
  match s.parse(input) {
    Ok(v) => @debug.assert_eq(v, input)
    Err(_) => fail("expected Ok")
  }
}

///|
/// enum_values()
test "enum_values accepts valid value" {
  let s = enum_values(["a", "b", "c"])
  match s.parse(Json::string("b")) {
    Ok(v) => @debug.assert_eq(v, Json::string("b"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "enum_values rejects invalid value" {
  let s = enum_values(["a", "b", "c"])
  guard s.parse(Json::string("d")) is Err(_) else { fail("expected Err") }
}

///|
test "enum_values rejects non-string" {
  let s = enum_values(["a", "b"])
  guard s.parse(Json::number(42.0)) is Err(_) else { fail("expected Err") }
}

///|
/// union()
test "union accepts first matching schema" {
  let s = union([string(), number()])
  match s.parse(Json::string("hello")) {
    Ok(v) => @debug.assert_eq(v, Json::string("hello"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "union accepts second matching schema" {
  let s = union([string(), number()])
  match s.parse(Json::number(42.0)) {
    Ok(v) => @debug.assert_eq(v, Json::number(42.0))
    Err(_) => fail("expected Ok")
  }
}

///|
test "union rejects when no schema matches" {
  let s = union([string(), number()])
  guard s.parse(Json::boolean(true)) is Err(_) else { fail("expected Err") }
}

///|
/// Phase 4 — append_rule through optional/default chaining
test "string().optional().min(3) passes non-null long enough" {
  let s = string().optional().min(3)
  match s.parse(Json::string("abc")) {
    Ok(v) => @debug.assert_eq(v, Json::string("abc"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "string().optional().min(3) rejects short string" {
  let s = string().optional().min(3)
  guard s.parse(Json::string("ab")) is Err(_) else { fail("expected Err") }
}

///|
test "string().optional().min(3) accepts null" {
  let s = string().optional().min(3)
  match s.parse(Json::null()) {
    Ok(v) => @debug.assert_eq(v, Json::null())
    Err(_) => fail("expected Ok")
  }
}

///|
test "string().default(x).min(3) uses default for null" {
  let s = string().default(Json::string("xyz")).min(3)
  match s.parse(Json::null()) {
    Ok(v) => @debug.assert_eq(v, Json::string("xyz"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "default value satisfies rules chained after default" {
  let s = string().default(Json::string("default!")).min(3)
  match s.parse(Json::null()) {
    Ok(v) => @debug.assert_eq(v, Json::string("default!"))
    Err(_) => fail("expected Ok")
  }
}

///|
/// Phase 4 — union parse details
test "union returns errors when no schema matches" {
  let s = union([number().positive(), string().min(3)])
  let input = parse_json("false")
  match s.parse(input) {
    Err(errors) => assert_true(errors.length() > 0)
    _ => fail("expected Err")
  }
}

///|
/// Phase 4 — DefaultType parse
test "default type accepts non-null and validates" {
  let s = number().default(Json::number(0.0)).positive()
  match s.parse(Json::number(5.0)) {
    Ok(v) => @debug.assert_eq(v, Json::number(5.0))
    Err(_) => fail("expected Ok")
  }
}

///|
test "default type rejects non-null failing validation" {
  let s = number().default(Json::number(0.0)).positive()
  guard s.parse(Json::number(-1.0)) is Err(_) else { fail("expected Err") }
}

///|
/// Phase 5 — union aggregated error reporting
test "union aggregates all branch errors" {
  let s = union([number().positive(), string().min(5)])
  match s.parse(Json::boolean(false)) {
    Err(errors) => {
      assert_true(errors[0].message.contains("Branches:"))
      assert_true(errors.length() == 1)
    }
    _ => fail("expected Err")
  }
}

///|
/// intersection tests
test "intersection parse basic" {
  let s = intersection([string().min(3), string().max(10)])
  match s.parse(Json::string("hello")) {
    Ok(v) => @debug.assert_eq(v, Json::string("hello"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "intersection fails when one schema fails" {
  let s = intersection([string(), number()])
  match s.parse(Json::string("not a number")) {
    Err(_) => ()
    Ok(_) => fail("expected Err")
  }
}

///|
test "intersection merges object fields" {
  let s = intersection([object({ "a": string() }), object({ "b": number() })])
  match
    s.parse(
      Json::object({ "a": Json::string("hello"), "b": Json::number(42.0) }),
    ) {
    Ok(v) =>
      @debug.assert_eq(
        v,
        Json::object({ "a": Json::string("hello"), "b": Json::number(42.0) }),
      )
    Err(_) => fail("expected Ok")
  }
}

///|
test "intersection with .intersect() method" {
  let s = string().min(3).intersect(string().max(10))
  match s.parse(Json::string("hello")) {
    Ok(v) => @debug.assert_eq(v, Json::string("hello"))
    Err(_) => fail("expected Ok")
  }
  match s.parse(Json::string("ab")) {
    Err(_) => ()
    Ok(_) => fail("expected Err")
  }
}

///|
test "intersection with three schemas" {
  let s = intersection([string().min(2), string().max(20), string().email()])
  match s.parse(Json::string("test@example.com")) {
    Ok(v) => @debug.assert_eq(v, Json::string("test@example.com"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "intersection collects all errors" {
  let s = intersection([number().positive(), string().min(5)])
  match s.parse(Json::number(0.0)) {
    Err(errors) => @debug.assert_eq(errors.length(), 2)
    Ok(_) => fail("expected Err")
  }
}

///|
test "intersection single schema" {
  let s = intersection([string().min(3)])
  match s.parse(Json::string("hello")) {
    Ok(v) => @debug.assert_eq(v, Json::string("hello"))
    Err(_) => fail("expected Ok")
  }
  match s.parse(Json::string("ab")) {
    Err(_) => ()
    Ok(_) => fail("expected Err")
  }
}

// ─── literal() tests ─────────────────────────────────────────────────────────

///|
test "literal string accepts matching value" {
  let s = literal(Json::string("hello"))
  match s.parse(Json::string("hello")) {
    Ok(v) => @debug.assert_eq(v, Json::string("hello"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "literal string rejects different value" {
  let s = literal(Json::string("hello"))
  guard s.parse(Json::string("world")) is Err(_) else { fail("expected Err") }
}

///|
test "literal string rejects different type" {
  let s = literal(Json::string("hello"))
  guard s.parse(Json::number(42.0)) is Err(_) else { fail("expected Err") }
}

///|
test "literal number accepts matching value" {
  let s = literal(Json::number(42.0))
  match s.parse(Json::number(42.0)) {
    Ok(v) => @debug.assert_eq(v, Json::number(42.0))
    Err(_) => fail("expected Ok")
  }
}

///|
test "literal number rejects different value" {
  let s = literal(Json::number(42.0))
  guard s.parse(Json::number(100.0)) is Err(_) else { fail("expected Err") }
}

///|
test "literal boolean true accepts matching value" {
  let s = literal(Json::boolean(true))
  match s.parse(Json::boolean(true)) {
    Ok(v) => @debug.assert_eq(v, Json::boolean(true))
    Err(_) => fail("expected Ok")
  }
}

///|
test "literal boolean false accepts matching value" {
  let s = literal(Json::boolean(false))
  match s.parse(Json::boolean(false)) {
    Ok(v) => @debug.assert_eq(v, Json::boolean(false))
    Err(_) => fail("expected Ok")
  }
}

///|
test "literal boolean rejects opposite value" {
  let s = literal(Json::boolean(true))
  guard s.parse(Json::boolean(false)) is Err(_) else { fail("expected Err") }
}

///|
test "literal null accepts null" {
  let s = literal(Json::null())
  match s.parse(Json::null()) {
    Ok(v) => @debug.assert_eq(v, Json::null())
    Err(_) => fail("expected Ok")
  }
}

///|
test "literal null rejects non-null" {
  let s = literal(Json::null())
  guard s.parse(Json::string("not null")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "literal in object field" {
  let s = object({ "status": literal(Json::string("active")) })
  match s.parse(Json::object({ "status": Json::string("active") })) {
    Ok(v) =>
      @debug.assert_eq(v, Json::object({ "status": Json::string("active") }))
    Err(_) => fail("expected Ok")
  }
}

///|
test "literal in object field rejects wrong value" {
  let s = object({ "status": literal(Json::string("active")) })
  guard s.parse(Json::object({ "status": Json::string("inactive") })) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "literal with custom error messages" {
  let s = literal(Json::string("hello"), invalid_type_error="must be hello")
  match s.parse(Json::string("world")) {
    Err(errors) => assert_true(errors[0].message.contains("must be hello"))
    _ => fail("expected Err")
  }
}

///|
test "literal complex values format expected message" {
  let array_schema = literal(
    Json::array([Json::number(3.14), Json::boolean(false)]),
  )
  match array_schema.parse(Json::array([])) {
    Err(errors) => {
      assert_true(errors[0].message.contains("3.14"))
      assert_true(errors[0].message.contains("false"))
    }
    _ => fail("expected Err")
  }

  let object_schema = literal(Json::object({ "ok": Json::null() }))
  match object_schema.parse(Json::object({})) {
    Err(errors) => assert_true(errors[0].message.contains("\"ok\": null"))
    _ => fail("expected Err")
  }
}

///|
/// brand()
test "brand sets brand field on schema" {
  let s = string().brand("MyString")
  @debug.assert_eq(s.brand, "MyString")
}

///|
test "brand preserves chaining" {
  let s = string().brand("EmailString").email()
  guard s.parse(Json::string("user@example.com")) is Ok(_) else {
    fail("expected Ok")
  }
}

///|
/// bigint()
test "bigint accepts integer number" {
  let s = bigint()
  guard s.parse(parse_json("42")) is Ok(_) else { fail("expected Ok") }
}

///|
test "bigint rejects non-integer number" {
  let s = bigint()
  guard s.parse(parse_json("3.14")) is Err(_) else { fail("expected Err") }
}

///|
test "bigint rejects boolean" {
  let s = bigint()
  guard s.parse(Json::boolean(true)) is Err(_) else { fail("expected Err") }
}

///|
test "bigint respects min rule" {
  let s = bigint().min(100)
  guard s.parse(parse_json("50")) is Err(_) else { fail("expected Err") }
  guard s.parse(parse_json("150")) is Ok(_) else { fail("expected Ok") }
}

///|
test "bigint respects positive rule" {
  let s = bigint().positive()
  guard s.parse(parse_json("-5")) is Err(_) else { fail("expected Err") }
  guard s.parse(parse_json("5")) is Ok(_) else { fail("expected Ok") }
}
