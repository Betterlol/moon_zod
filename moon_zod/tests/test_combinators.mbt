///|
/// optional()
test "object field optional passes with missing field" {
  let s = @core.object({ "name": @core.string().optional() })
  let input = @core.parse_json("{}")
  match s.parse(input) {
    Ok(v) => @debug.assert_eq(v, input)
    Err(_) => fail("expected Ok")
  }
}

///|
test "object field nullish passes with null" {
  let s = @core.object({ "name": @core.string().nullish() })
  let input = @core.parse_json("{\"name\": null}")
  match s.parse(input) {
    Ok(v) => @debug.assert_eq(v, input)
    Err(_) => fail("expected Ok")
  }
}

///|
test "object field optional still validates non-null" {
  let s = @core.object({ "name": @core.string().min(3).optional() })
  let input = @core.parse_json("{\"name\": \"ab\"}")
  guard s.parse(input) is Err(_) else { fail("expected Err") }
}

///|
/// default()
test "object field default passes with missing field" {
  let s = @core.object({
    "name": @core.string().default(Json::string("default_name")),
  })
  let input = @core.parse_json("{}")
  match s.parse(input) {
    Ok(v) =>
      @debug.assert_eq(v, @core.parse_json("{\"name\":\"default_name\"}"))
    Err(_) => fail("expected Ok")
  }
}

///|
/// enum_values()
test "enum_values accepts valid value" {
  let s = @core.enum_values(["a", "b", "c"])
  match s.parse(Json::string("b")) {
    Ok(v) => @debug.assert_eq(v, Json::string("b"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "enum_values rejects invalid value" {
  let s = @core.enum_values(["a", "b", "c"])
  guard s.parse(Json::string("d")) is Err(_) else { fail("expected Err") }
}

///|
test "enum_values rejects non-string" {
  let s = @core.enum_values(["a", "b"])
  guard s.parse(Json::number(42.0)) is Err(_) else { fail("expected Err") }
}

///|
/// union()
test "union accepts first matching schema" {
  let s = @core.union([@core.string(), @core.number()])
  match s.parse(Json::string("hello")) {
    Ok(v) => @debug.assert_eq(v, Json::string("hello"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "union accepts second matching schema" {
  let s = @core.union([@core.string(), @core.number()])
  match s.parse(Json::number(42.0)) {
    Ok(v) => @debug.assert_eq(v, Json::number(42.0))
    Err(_) => fail("expected Ok")
  }
}

///|
test "union rejects when no schema matches" {
  let s = @core.union([@core.string(), @core.number()])
  guard s.parse(Json::boolean(true)) is Err(_) else { fail("expected Err") }
}

///|
/// Phase 4 — append_rule through optional/default chaining
test "string().optional().min(3) passes non-null long enough" {
  let s = @core.string().optional().min(3)
  match s.parse(Json::string("abc")) {
    Ok(v) => @debug.assert_eq(v, Json::string("abc"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "string().optional().min(3) rejects short string" {
  let s = @core.string().optional().min(3)
  guard s.parse(Json::string("ab")) is Err(_) else { fail("expected Err") }
}

///|
test "string().nullish().min(3) accepts null" {
  let s = @core.string().nullish().min(3)
  match s.parse(Json::null()) {
    Ok(v) => @debug.assert_eq(v, Json::null())
    Err(_) => fail("expected Ok")
  }
}

///|
test "string().default(x).min(3) uses default for missing" {
  let s = @core.string().default(Json::string("xyz")).min(3)
  match s.parse_missing() {
    Ok(Some(v)) => @debug.assert_eq(v, Json::string("xyz"))
    _ => fail("expected Ok")
  }
}

///|
test "default value satisfies rules chained after default" {
  let s = @core.string().default(Json::string("default!")).min(3)
  match s.parse_missing() {
    Ok(Some(v)) => @debug.assert_eq(v, Json::string("default!"))
    _ => fail("expected Ok")
  }
}

///|
/// Phase 4 — union parse details
test "union returns errors when no schema matches" {
  let s = @core.union([@core.number().positive(), @core.string().min(3)])
  let input = @core.parse_json("false")
  match s.parse(input) {
    Err(errors) => assert_true(errors.length() > 0)
    _ => fail("expected Err")
  }
}

///|
/// Phase 4 — DefaultType parse
test "default type accepts non-null and validates" {
  let s = @core.number().default(Json::number(0.0)).positive()
  match s.parse(Json::number(5.0)) {
    Ok(v) => @debug.assert_eq(v, Json::number(5.0))
    Err(_) => fail("expected Ok")
  }
}

///|
test "default type rejects non-null failing validation" {
  let s = @core.number().default(Json::number(0.0)).positive()
  guard s.parse(Json::number(-1.0)) is Err(_) else { fail("expected Err") }
}

///|
/// Phase 5 — union aggregated error reporting
test "union aggregates all branch errors" {
  let s = @core.union([@core.number().positive(), @core.string().min(5)])
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
  let s = @core.intersection([@core.string().min(3), @core.string().max(10)])
  match s.parse(Json::string("hello")) {
    Ok(v) => @debug.assert_eq(v, Json::string("hello"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "intersection fails when one schema fails" {
  let s = @core.intersection([@core.string(), @core.number()])
  match s.parse(Json::string("not a number")) {
    Err(_) => ()
    Ok(_) => fail("expected Err")
  }
}

///|
test "intersection merges object fields" {
  let s = @core.intersection([
    @core.object({ "a": @core.string() }),
    @core.object({ "b": @core.number() }),
  ])
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
  let s = @core.string().min(3).intersect(@core.string().max(10))
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
  let s = @core.intersection([
    @core.string().min(2),
    @core.string().max(20),
    @core.string().email(),
  ])
  match s.parse(Json::string("test@example.com")) {
    Ok(v) => @debug.assert_eq(v, Json::string("test@example.com"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "intersection collects all errors" {
  let s = @core.intersection([@core.number().positive(), @core.string().min(5)])
  match s.parse(Json::number(0.0)) {
    Err(errors) => @debug.assert_eq(errors.length(), 2)
    Ok(_) => fail("expected Err")
  }
}

///|
test "intersection single schema" {
  let s = @core.intersection([@core.string().min(3)])
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
  let s = @core.literal(Json::string("hello"))
  match s.parse(Json::string("hello")) {
    Ok(v) => @debug.assert_eq(v, Json::string("hello"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "literal string rejects different value" {
  let s = @core.literal(Json::string("hello"))
  guard s.parse(Json::string("world")) is Err(_) else { fail("expected Err") }
}

///|
test "literal string rejects different type" {
  let s = @core.literal(Json::string("hello"))
  guard s.parse(Json::number(42.0)) is Err(_) else { fail("expected Err") }
}

///|
test "literal number accepts matching value" {
  let s = @core.literal(Json::number(42.0))
  match s.parse(Json::number(42.0)) {
    Ok(v) => @debug.assert_eq(v, Json::number(42.0))
    Err(_) => fail("expected Ok")
  }
}

///|
test "literal number rejects different value" {
  let s = @core.literal(Json::number(42.0))
  guard s.parse(Json::number(100.0)) is Err(_) else { fail("expected Err") }
}

///|
test "literal boolean true accepts matching value" {
  let s = @core.literal(Json::boolean(true))
  match s.parse(Json::boolean(true)) {
    Ok(v) => @debug.assert_eq(v, Json::boolean(true))
    Err(_) => fail("expected Ok")
  }
}

///|
test "literal boolean false accepts matching value" {
  let s = @core.literal(Json::boolean(false))
  match s.parse(Json::boolean(false)) {
    Ok(v) => @debug.assert_eq(v, Json::boolean(false))
    Err(_) => fail("expected Ok")
  }
}

///|
test "literal boolean rejects opposite value" {
  let s = @core.literal(Json::boolean(true))
  guard s.parse(Json::boolean(false)) is Err(_) else { fail("expected Err") }
}

///|
test "literal null accepts null" {
  let s = @core.literal(Json::null())
  match s.parse(Json::null()) {
    Ok(v) => @debug.assert_eq(v, Json::null())
    Err(_) => fail("expected Ok")
  }
}

///|
test "literal null rejects non-null" {
  let s = @core.literal(Json::null())
  guard s.parse(Json::string("not null")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "literal in object field" {
  let s = @core.object({ "status": @core.literal(Json::string("active")) })
  match s.parse(Json::object({ "status": Json::string("active") })) {
    Ok(v) =>
      @debug.assert_eq(v, Json::object({ "status": Json::string("active") }))
    Err(_) => fail("expected Ok")
  }
}

///|
test "literal in object field rejects wrong value" {
  let s = @core.object({ "status": @core.literal(Json::string("active")) })
  guard s.parse(Json::object({ "status": Json::string("inactive") })) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "literal with custom error messages" {
  let s = @core.literal(
    Json::string("hello"),
    invalid_type_error="must be hello",
  )
  match s.parse(Json::string("world")) {
    Err(errors) => assert_true(errors[0].message.contains("must be hello"))
    _ => fail("expected Err")
  }
}

///|
test "literal complex values format expected message" {
  let array_schema = @core.literal(
    Json::array([Json::number(3.14), Json::boolean(false)]),
  )
  match array_schema.parse(Json::array([])) {
    Err(errors) => {
      assert_true(errors[0].message.contains("3.14"))
      assert_true(errors[0].message.contains("false"))
    }
    _ => fail("expected Err")
  }

  let object_schema = @core.literal(Json::object({ "ok": Json::null() }))
  match object_schema.parse(Json::empty_object()) {
    Err(errors) => assert_true(errors[0].message.contains("\"ok\": null"))
    _ => fail("expected Err")
  }
}

///|
/// brand()
test "brand sets brand field on schema" {
  let s = @core.string().brand("MyString")
  @debug.assert_eq(s.brand, "MyString")
}

///|
test "brand preserves chaining" {
  let s = @core.string().brand("EmailString").email()
  guard s.parse(Json::string("user@example.com")) is Ok(_) else {
    fail("expected Ok")
  }
}

///|
/// bigint()
test "bigint accepts integer number" {
  let s = @core.bigint()
  guard s.parse(@core.parse_json("42")) is Ok(_) else { fail("expected Ok") }
}

///|
test "bigint rejects non-integer number" {
  let s = @core.bigint()
  guard s.parse(@core.parse_json("3.14")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "bigint rejects boolean" {
  let s = @core.bigint()
  guard s.parse(Json::boolean(true)) is Err(_) else { fail("expected Err") }
}

///|
test "bigint respects min rule" {
  let s = @core.bigint().min(100)
  guard s.parse(@core.parse_json("50")) is Err(_) else { fail("expected Err") }
  guard s.parse(@core.parse_json("150")) is Ok(_) else { fail("expected Ok") }
}

///|
test "bigint respects positive rule" {
  let s = @core.bigint().positive()
  guard s.parse(@core.parse_json("-5")) is Err(_) else { fail("expected Err") }
  guard s.parse(@core.parse_json("5")) is Ok(_) else { fail("expected Ok") }
}
