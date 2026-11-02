///|
/// object() — valid cases
test "object validates flat object" {
  let s = @core.object({ "name": @core.string(), "age": @core.number().int() })
  let input = @core.parse_json("{\"name\": \"Alice\", \"age\": 30}")
  match s.parse(input) {
    Ok(v) => @debug.assert_eq(v, input)
    Err(_) => fail("expected Ok")
  }
}

///|
test "object validates nested object" {
  let s = @core.object({
    "user": @core.object({ "profile": @core.object({ "name": @core.string() }) }),
  })
  let input = @core.parse_json(
    "{\"user\": {\"profile\": {\"name\": \"Alice\"}}}",
  )
  match s.parse(input) {
    Ok(v) => @debug.assert_eq(v, input)
    Err(_) => fail("expected Ok")
  }
}

///|
test "object passthrough allows extra fields" {
  let s = @core.object({ "name": @core.string() }).passthrough()
  let input = @core.parse_json("{\"name\": \"Alice\", \"extra\": 1}")
  match s.parse(input) {
    Ok(v) => @debug.assert_eq(v, input)
    Err(_) => fail("expected Ok")
  }
}

///|
/// object() — error cases
test "object rejects non-object" {
  let s = @core.object({ "name": @core.string() })
  guard s.parse(Json::string("hello")) is Err(_) else { fail("expected Err") }
}

///|
test "object reports missing field" {
  let s = @core.object({ "name": @core.string() })
  let input = @core.parse_json("{}")
  match s.parse(input) {
    Err(errors) => {
      @debug.assert_eq(errors.length(), 1)
      @debug.assert_eq(errors[0].path, "name")
      @debug.assert_eq(errors[0].message, "Required")
    }
    _ => fail("expected Err")
  }
}

///|
test "nested object reports correct error path" {
  let s = @core.object({
    "user": @core.object({
      "profile": @core.object({ "name": @core.string().min(10) }),
    }),
  })
  let input = @core.parse_json("{\"user\": {\"profile\": {\"name\": \"Bob\"}}}")
  match s.parse(input) {
    Err(errors) => @debug.assert_eq(errors[0].path, "user.profile.name")
    _ => fail("expected Err")
  }
}

///|
test "strict mode rejects extra fields" {
  let s = @core.object({ "name": @core.string() }).strict()
  let input = @core.parse_json("{\"name\": \"Alice\", \"extra\": 1}")
  guard s.parse(input) is Err(_) else { fail("expected Err") }
}

///|
test "strict mode reports extra field path" {
  let s = @core.object({ "name": @core.string() }).strict()
  let input = @core.parse_json("{\"name\": \"Alice\", \"extra\": 1}")
  match s.parse(input) {
    Err(errors) => {
      @debug.assert_eq(errors[0].path, "extra")
      @debug.assert_eq(errors[0].message, "Unexpected field")
    }
    _ => fail("expected Err")
  }
}

///|
test "object collects multiple field errors" {
  let s = @core.object({
    "a": @core.string().min(5),
    "b": @core.number().positive(),
  })
  let input = @core.parse_json("{\"a\": \"ab\", \"b\": -1}")
  match s.parse(input) {
    Err(errors) => @debug.assert_eq(errors.length(), 2)
    _ => fail("expected Err")
  }
}

///|
test "strict mode with nested path" {
  let s = @core.object({
    "inner": @core.object({ "x": @core.number() }).strict(),
  })
  let input = @core.parse_json("{\"inner\": {\"x\": 1, \"y\": 2}}")
  match s.parse(input) {
    Err(errors) => {
      @debug.assert_eq(errors[0].path, "inner.y")
      @debug.assert_eq(errors[0].message, "Unexpected field")
    }
    _ => fail("expected Err")
  }
}

///|
/// Error messages
test "error message includes path and expected type" {
  let s = @core.string()
  match s.parse(Json::number(1.0), path="root") {
    Err(errors) => {
      @debug.assert_eq(errors[0].path, "root")
      @debug.assert_eq(errors[0].message, "Expected string")
    }
    _ => fail("expected Err")
  }
}

///|
test "multiple rules report first failing" {
  let s = @core.string().min(5).max(10)
  match s.parse(Json::string("ab")) {
    Err(errors) =>
      @debug.assert_eq(
        errors[0].message,
        "String must contain at least 5 character(s)",
      )
    _ => fail("expected Err")
  }
}

///|
/// Phase 5 — Strip mode (default)
test "strip removes extra fields by default" {
  let s = @core.object({ "name": @core.string() })
  let input = @core.parse_json("{\"name\": \"Alice\", \"extra\": 1}")
  match s.parse(input) {
    Ok(v) => @debug.assert_eq(v, @core.parse_json("{\"name\": \"Alice\"}"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "strip removes extra fields in nested objects" {
  let s = @core.object({ "user": @core.object({ "name": @core.string() }) })
  let input = @core.parse_json(
    "{\"user\": {\"name\": \"Alice\", \"ignored\": true}}",
  )
  match s.parse(input) {
    Ok(v) =>
      @debug.assert_eq(v, @core.parse_json("{\"user\": {\"name\": \"Alice\"}}"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "explicit passthrough still allows extra fields" {
  let s = @core.object({ "name": @core.string() }).passthrough()
  let input = @core.parse_json("{\"name\": \"Alice\", \"extra\": 1}")
  match s.parse(input) {
    Ok(v) => @debug.assert_eq(v, input)
    Err(_) => fail("expected Ok")
  }
}

///|
test "explicit strip method works" {
  let s = @core.object({ "name": @core.string() }).strip()
  let input = @core.parse_json("{\"name\": \"Bob\", \"x\": 2, \"y\": 3}")
  match s.parse(input) {
    Ok(v) => @debug.assert_eq(v, @core.parse_json("{\"name\": \"Bob\"}"))
    Err(_) => fail("expected Ok")
  }
}

///|
/// Phase 5 — path stack correctness
test "deep nested path with arrays and objects" {
  let s = @core.object({
    "a": @core.array(@core.object({ "b": @core.number().positive() })),
  })
  let input = @core.parse_json("{\"a\": [{\"b\": 1}, {\"b\": -2}]}")
  match s.parse(input) {
    Err(errors) => @debug.assert_eq(errors[0].path, "a[1].b")
    _ => fail("expected Err")
  }
}

///|
/// Schema composition — pick()
test "pick selects specific fields" {
  let s = @core.object({
    "a": @core.string(),
    "b": @core.number(),
    "c": @core.boolean(),
  })
  let p = s.pick(["a", "c"])
  match
    p.parse(Json::object({ "a": Json::string("x"), "c": Json::boolean(true) })) {
    Ok(v) =>
      @debug.assert_eq(
        v,
        Json::object({ "a": Json::string("x"), "c": Json::boolean(true) }),
      )
    Err(_) => fail("expected Ok")
  }
}

///|
test "panic pick rejects keys not in original spec" {
  let _ = @core.object({ "x": @core.string() }).pick(["x", "y"])
}

///|
test "pick preserves field rules" {
  let p = @core.object({ "a": @core.string().min(3) }).pick(["a"])
  guard p.parse(Json::object({ "a": Json::string("ab") })) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "pick preserves object mode" {
  let p = @core.object({ "a": @core.string() }).strict().pick(["a"])
  guard p.parse(Json::object({ "a": Json::string("x"), "b": Json::number(1) }))
    is Err(_) else {
    fail("expected Err for strict mode")
  }
}

///|
/// Description preservation through composition
test "pick preserves schema description" {
  let s = @core.object({ "a": @core.string(), "b": @core.number() }).describe(
    "my schema",
  )
  let p = s.pick(["a"])
  @debug.assert_eq(p.description, "my schema")
}

///|
/// Schema composition — omit()
test "omit removes specific fields" {
  let s = @core.object({
    "a": @core.string(),
    "b": @core.number(),
    "c": @core.boolean(),
  })
  let o = s.omit(["b"])
  match
    o.parse(Json::object({ "a": Json::string("x"), "c": Json::boolean(true) })) {
    Ok(_) => ()
    Err(_) => fail("expected Ok")
  }
}

///|
test "omit all fields produces empty object" {
  let o = @core.object({ "a": @core.string() }).omit(["a"])
  match o.parse(Json::empty_object()) {
    Ok(v) => @debug.assert_eq(v, Json::empty_object())
    Err(_) => fail("expected Ok")
  }
}

///|
test "omit preserves field rules on remaining fields" {
  let o = @core.object({ "a": @core.string().min(3), "b": @core.number() }).omit([
      "b",
    ],
  )
  guard o.parse(Json::object({ "a": Json::string("ab") })) is Err(_) else {
    fail("expected Err from min(3)")
  }
}

///|
test "omit preserves schema description" {
  let s = @core.object({ "a": @core.string(), "b": @core.number() }).describe(
    "my schema",
  )
  let o = s.omit(["b"])
  @debug.assert_eq(o.description, "my schema")
}

///|
/// Schema composition — partial()
test "partial makes all fields optional" {
  let p = @core.object({ "a": @core.string(), "b": @core.number() }).partial()
  match p.parse(Json::empty_object()) {
    Ok(_) => ()
    Err(_) => fail("expected Ok")
  }
}

///|
test "partial rejects explicit null on nonnullable fields" {
  let p = @core.object({ "a": @core.string(), "b": @core.number() }).partial()
  assert_true(
    p.parse(Json::object({ "a": Json::null(), "b": Json::null() })) is Err(_),
  )
}

///|
test "partial still validates present values" {
  let p = @core.object({ "a": @core.string().min(3) }).partial()
  guard p.parse(Json::object({ "a": Json::string("ab") })) is Err(_) else {
    fail("expected Err from min(3)")
  }
}

///|
test "partial preserves object mode" {
  let p = @core.object({ "a": @core.string() }).strict().partial()
  guard p.parse(Json::object({ "a": Json::string("x"), "b": Json::number(1) }))
    is Err(_) else {
    fail("expected Err for strict mode")
  }
}

///|
test "partial on already partial keeps all fields optional" {
  let p = @core.object({ "a": @core.string() }).partial().partial()
  match p.parse(Json::empty_object()) {
    Ok(_) => ()
    Err(_) => fail("expected Ok")
  }
}

///|
test "partial preserves schema description" {
  let s = @core.object({ "a": @core.string(), "b": @core.number() }).describe(
    "my schema",
  )
  let p = s.partial()
  @debug.assert_eq(p.description, "my schema")
}

///|
/// Schema composition — extend()
test "extend adds fields" {
  let s = @core.object({ "a": @core.string() }).extend_with({
    "b": @core.number(),
  })
  guard s.parse(@core.parse_json("{\"a\": \"x\", \"b\": 1}")) is Ok(_) else {
    fail("expected Ok")
  }
}

///|
test "extend overrides existing fields" {
  let s = @core.object({ "a": @core.string() }).extend_with({
    "a": @core.number(),
  })
  guard s.parse(Json::object({ "a": Json::string("x") })) is Err(_) else {
    fail("expected Err")
  }
  guard s.parse(Json::object({ "a": Json::number(1) })) is Ok(_) else {
    fail("expected Ok")
  }
}

///|
test "extend preserves object mode" {
  let s = @core.object({ "a": @core.string() })
    .strict()
    .extend_with({ "b": @core.number() })
  guard s.parse(@core.parse_json("{\"a\": \"x\", \"b\": 1, \"c\": true}"))
    is Err(_) else {
    fail("expected Err for strict mode")
  }
}

///|
test "extend preserves schema metadata" {
  let s = @core.object({ "a": @core.string() }).describe("base").brand("Base")
  let e = s.extend_with({ "b": @core.number() })
  @debug.assert_eq(e.description, "base")
  @debug.assert_eq(e.brand, "Base")
}

///|
/// Schema composition — merge()
test "merge combines object fields" {
  let left = @core.object({ "a": @core.string() })
  let right = @core.object({ "b": @core.number() })
  let s = left.merge(right)
  guard s.parse(@core.parse_json("{\"a\": \"x\", \"b\": 1}")) is Ok(_) else {
    fail("expected Ok")
  }
}

///|
test "merge right side overrides duplicate fields" {
  let left = @core.object({ "a": @core.string() })
  let right = @core.object({ "a": @core.number() })
  let s = left.merge(right)
  guard s.parse(Json::object({ "a": Json::string("x") })) is Err(_) else {
    fail("expected Err")
  }
  guard s.parse(Json::object({ "a": Json::number(1) })) is Ok(_) else {
    fail("expected Ok")
  }
}

///|
test "merge inherits right object mode" {
  let left = @core.object({ "a": @core.string() }).strict()
  let right = @core.object({ "b": @core.number() }).passthrough()
  let s = left.merge(right)
  guard s.parse(@core.parse_json("{\"a\": \"x\", \"b\": 1, \"c\": true}"))
    is Ok(_) else {
    fail("expected Ok for passthrough mode")
  }
}
