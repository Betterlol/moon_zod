///|
/// object() — valid cases
test "object validates flat object" {
  let s = object({ "name": string(), "age": number().int() })
  let input = parse_json("{\"name\": \"Alice\", \"age\": 30}")
  match s.parse(input) {
    Ok(v) => @debug.assert_eq(v, input)
    Err(_) => fail("expected Ok")
  }
}

///|
test "object validates nested object" {
  let s = object({ "user": object({ "profile": object({ "name": string() }) }) })
  let input = parse_json("{\"user\": {\"profile\": {\"name\": \"Alice\"}}}")
  match s.parse(input) {
    Ok(v) => @debug.assert_eq(v, input)
    Err(_) => fail("expected Ok")
  }
}

///|
test "object passthrough allows extra fields" {
  let s = object({ "name": string() }).passthrough()
  let input = parse_json("{\"name\": \"Alice\", \"extra\": 1}")
  match s.parse(input) {
    Ok(v) => @debug.assert_eq(v, input)
    Err(_) => fail("expected Ok")
  }
}

///|
/// object() — error cases
test "object rejects non-object" {
  let s = object({ "name": string() })
  guard s.parse(Json::string("hello")) is Err(_) else { fail("expected Err") }
}

///|
test "object reports missing field" {
  let s = object({ "name": string() })
  let input = parse_json("{}")
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
  let s = object({
    "user": object({ "profile": object({ "name": string().min(10) }) }),
  })
  let input = parse_json("{\"user\": {\"profile\": {\"name\": \"Bob\"}}}")
  match s.parse(input) {
    Err(errors) => @debug.assert_eq(errors[0].path, "user.profile.name")
    _ => fail("expected Err")
  }
}

///|
test "strict mode rejects extra fields" {
  let s = object({ "name": string() }).strict()
  let input = parse_json("{\"name\": \"Alice\", \"extra\": 1}")
  guard s.parse(input) is Err(_) else { fail("expected Err") }
}

///|
test "strict mode reports extra field path" {
  let s = object({ "name": string() }).strict()
  let input = parse_json("{\"name\": \"Alice\", \"extra\": 1}")
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
  let s = object({ "a": string().min(5), "b": number().positive() })
  let input = parse_json("{\"a\": \"ab\", \"b\": -1}")
  match s.parse(input) {
    Err(errors) => @debug.assert_eq(errors.length(), 2)
    _ => fail("expected Err")
  }
}

///|
test "strict mode with nested path" {
  let s = object({ "inner": object({ "x": number() }).strict() })
  let input = parse_json("{\"inner\": {\"x\": 1, \"y\": 2}}")
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
  let s = string()
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
  let s = string().min(5).max(10)
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
  let s = object({ "name": string() })
  let input = parse_json("{\"name\": \"Alice\", \"extra\": 1}")
  match s.parse(input) {
    Ok(v) => @debug.assert_eq(v, parse_json("{\"name\": \"Alice\"}"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "strip removes extra fields in nested objects" {
  let s = object({ "user": object({ "name": string() }) })
  let input = parse_json("{\"user\": {\"name\": \"Alice\", \"ignored\": true}}")
  match s.parse(input) {
    Ok(v) =>
      @debug.assert_eq(v, parse_json("{\"user\": {\"name\": \"Alice\"}}"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "explicit passthrough still allows extra fields" {
  let s = object({ "name": string() }).passthrough()
  let input = parse_json("{\"name\": \"Alice\", \"extra\": 1}")
  match s.parse(input) {
    Ok(v) => @debug.assert_eq(v, input)
    Err(_) => fail("expected Ok")
  }
}

///|
test "explicit strip method works" {
  let s = object({ "name": string() }).strip()
  let input = parse_json("{\"name\": \"Bob\", \"x\": 2, \"y\": 3}")
  match s.parse(input) {
    Ok(v) => @debug.assert_eq(v, parse_json("{\"name\": \"Bob\"}"))
    Err(_) => fail("expected Ok")
  }
}

///|
/// Phase 5 — path stack correctness
test "deep nested path with arrays and objects" {
  let s = object({ "a": array(object({ "b": number().positive() })) })
  let input = parse_json("{\"a\": [{\"b\": 1}, {\"b\": -2}]}")
  match s.parse(input) {
    Err(errors) => @debug.assert_eq(errors[0].path, "a[1].b")
    _ => fail("expected Err")
  }
}

///|
/// Schema composition — pick()
test "pick selects specific fields" {
  let s = object({ "a": string(), "b": number(), "c": boolean() })
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
test "pick ignores keys not in original spec" {
  let p = object({ "x": string() }).pick(["x", "y"])
  guard p.parse(Json::object({ "x": Json::string("ok") })) is Ok(_) else {
    fail("expected Ok")
  }
}

///|
test "pick preserves field rules" {
  let p = object({ "a": string().min(3) }).pick(["a"])
  guard p.parse(Json::object({ "a": Json::string("ab") })) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "pick preserves object mode" {
  let p = object({ "a": string() }).strict().pick(["a"])
  guard p.parse(Json::object({ "a": Json::string("x"), "b": Json::number(1) }))
    is Err(_) else {
    fail("expected Err for strict mode")
  }
}

///|
/// Description preservation through composition
test "pick preserves schema description" {
  let s = object({ "a": string(), "b": number() }).describe("my schema")
  let p = s.pick(["a"])
  @debug.assert_eq(p.description, "my schema")
}

///|
/// Schema composition — omit()
test "omit removes specific fields" {
  let s = object({ "a": string(), "b": number(), "c": boolean() })
  let o = s.omit(["b"])
  match
    o.parse(Json::object({ "a": Json::string("x"), "c": Json::boolean(true) })) {
    Ok(_) => ()
    Err(_) => fail("expected Ok")
  }
}

///|
test "omit all fields produces empty object" {
  let o = object({ "a": string() }).omit(["a"])
  match o.parse(Json::object({})) {
    Ok(v) => @debug.assert_eq(v, Json::object({}))
    Err(_) => fail("expected Ok")
  }
}

///|
test "omit preserves field rules on remaining fields" {
  let o = object({ "a": string().min(3), "b": number() }).omit(["b"])
  guard o.parse(Json::object({ "a": Json::string("ab") })) is Err(_) else {
    fail("expected Err from min(3)")
  }
}

///|
test "omit preserves schema description" {
  let s = object({ "a": string(), "b": number() }).describe("my schema")
  let o = s.omit(["b"])
  @debug.assert_eq(o.description, "my schema")
}

///|
/// Schema composition — partial()
test "partial makes all fields optional" {
  let p = object({ "a": string(), "b": number() }).partial()
  match p.parse(Json::object({})) {
    Ok(_) => ()
    Err(_) => fail("expected Ok")
  }
}

///|
test "partial allows null on all fields" {
  let p = object({ "a": string(), "b": number() }).partial()
  match p.parse(Json::object({ "a": Json::null(), "b": Json::null() })) {
    Ok(_) => ()
    Err(_) => fail("expected Ok")
  }
}

///|
test "partial still validates present values" {
  let p = object({ "a": string().min(3) }).partial()
  guard p.parse(Json::object({ "a": Json::string("ab") })) is Err(_) else {
    fail("expected Err from min(3)")
  }
}

///|
test "partial preserves object mode" {
  let p = object({ "a": string() }).strict().partial()
  guard p.parse(Json::object({ "a": Json::string("x"), "b": Json::number(1) }))
    is Err(_) else {
    fail("expected Err for strict mode")
  }
}

///|
test "partial on already partial keeps all fields optional" {
  let p = object({ "a": string() }).partial().partial()
  match p.parse(Json::object({})) {
    Ok(_) => ()
    Err(_) => fail("expected Ok")
  }
}

///|
test "partial preserves schema description" {
  let s = object({ "a": string(), "b": number() }).describe("my schema")
  let p = s.partial()
  @debug.assert_eq(p.description, "my schema")
}

///|
/// Schema composition — extend()
test "extend adds fields" {
  let s = object({ "a": string() }).extend({ "b": number() })
  guard s.parse(parse_json("{\"a\": \"x\", \"b\": 1}")) is Ok(_) else {
    fail("expected Ok")
  }
}

///|
test "extend overrides existing fields" {
  let s = object({ "a": string() }).extend({ "a": number() })
  guard s.parse(Json::object({ "a": Json::string("x") })) is Err(_) else {
    fail("expected Err")
  }
  guard s.parse(Json::object({ "a": Json::number(1) })) is Ok(_) else {
    fail("expected Ok")
  }
}

///|
test "extend preserves object mode" {
  let s = object({ "a": string() }).strict().extend({ "b": number() })
  guard s.parse(parse_json("{\"a\": \"x\", \"b\": 1, \"c\": true}")) is Err(_) else {
    fail("expected Err for strict mode")
  }
}

///|
test "extend preserves schema metadata" {
  let s = object({ "a": string() }).describe("base").brand("Base")
  let e = s.extend({ "b": number() })
  @debug.assert_eq(e.description, "base")
  @debug.assert_eq(e.brand, "Base")
}

///|
/// Schema composition — merge()
test "merge combines object fields" {
  let left = object({ "a": string() })
  let right = object({ "b": number() })
  let s = left.merge(right)
  guard s.parse(parse_json("{\"a\": \"x\", \"b\": 1}")) is Ok(_) else {
    fail("expected Ok")
  }
}

///|
test "merge right side overrides duplicate fields" {
  let left = object({ "a": string() })
  let right = object({ "a": number() })
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
  let left = object({ "a": string() }).strict()
  let right = object({ "b": number() }).passthrough()
  let s = left.merge(right)
  guard s.parse(parse_json("{\"a\": \"x\", \"b\": 1, \"c\": true}")) is Ok(_) else {
    fail("expected Ok for passthrough mode")
  }
}
