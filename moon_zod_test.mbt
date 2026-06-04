///|
/// string() — valid cases
test "string accepts valid string" {
  let s = string()
  match s.parse(Json::string("hello")) {
    Ok(v) => assert_eq(v, Json::string("hello"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "string min passes long enough" {
  let s = string().min(3)
  match s.parse(Json::string("abc")) {
    Ok(v) => assert_eq(v, Json::string("abc"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "string max passes short enough" {
  let s = string().max(5)
  match s.parse(Json::string("hello")) {
    Ok(v) => assert_eq(v, Json::string("hello"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "string email passes valid" {
  let s = string().email()
  match s.parse(Json::string("user@example.com")) {
    Ok(v) => assert_eq(v, Json::string("user@example.com"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "string url passes valid" {
  let s = string().url()
  match s.parse(Json::string("https://moonbitlang.com")) {
    Ok(v) => assert_eq(v, Json::string("https://moonbitlang.com"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "string nonempty passes non-empty" {
  let s = string().nonempty()
  match s.parse(Json::string("x")) {
    Ok(v) => assert_eq(v, Json::string("x"))
    Err(_) => fail("expected Ok")
  }
}

///|
/// string() — error cases
test "string rejects number" {
  let s = string()
  guard s.parse(Json::number(42.0)) is Err(_) else { fail("expected Err") }
}

///|
test "string min fails too short" {
  let s = string().min(5)
  guard s.parse(Json::string("ab")) is Err(_) else { fail("expected Err") }
}

///|
test "string max fails too long" {
  let s = string().max(3)
  guard s.parse(Json::string("hello")) is Err(_) else { fail("expected Err") }
}

///|
test "string email rejects missing @ symbol" {
  let s = string().email()
  guard s.parse(Json::string("not-an-email")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "string email rejects empty domain" {
  let s = string().email()
  guard s.parse(Json::string("user@")) is Err(_) else { fail("expected Err") }
}

///|
test "string url rejects without protocol" {
  let s = string().url()
  guard s.parse(Json::string("example.com")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "string nonempty rejects empty string" {
  let s = string().nonempty()
  guard s.parse(Json::string("")) is Err(_) else { fail("expected Err") }
}

///|
/// number() — valid cases
test "number accepts valid number" {
  let s = number()
  match s.parse(Json::number(42.0)) {
    Ok(v) => assert_eq(v, Json::number(42.0))
    Err(_) => fail("expected Ok")
  }
}

///|
test "number int passes integer" {
  let s = number().int()
  match s.parse(Json::number(7.0)) {
    Ok(v) => assert_eq(v, Json::number(7.0))
    Err(_) => fail("expected Ok")
  }
}

///|
test "number positive passes positive" {
  let s = number().positive()
  match s.parse(Json::number(1.0)) {
    Ok(v) => assert_eq(v, Json::number(1.0))
    Err(_) => fail("expected Ok")
  }
}

///|
test "number negative passes negative" {
  let s = number().negative()
  match s.parse(Json::number(-1.0)) {
    Ok(v) => assert_eq(v, Json::number(-1.0))
    Err(_) => fail("expected Ok")
  }
}

///|
/// number() — error cases
test "number rejects string" {
  let s = number()
  guard s.parse(Json::string("42")) is Err(_) else { fail("expected Err") }
}

///|
test "number int rejects float" {
  let s = number().int()
  guard s.parse(Json::number(3.14)) is Err(_) else { fail("expected Err") }
}

///|
test "number positive rejects zero" {
  let s = number().positive()
  guard s.parse(Json::number(0.0)) is Err(_) else { fail("expected Err") }
}

///|
test "number negative rejects positive" {
  let s = number().negative()
  guard s.parse(Json::number(5.0)) is Err(_) else { fail("expected Err") }
}

///|
/// boolean() — valid / error
test "boolean accepts true" {
  let s = boolean()
  match s.parse(Json::boolean(true)) {
    Ok(v) => assert_eq(v, Json::boolean(true))
    Err(_) => fail("expected Ok")
  }
}

///|
test "boolean accepts false" {
  let s = boolean()
  match s.parse(Json::boolean(false)) {
    Ok(v) => assert_eq(v, Json::boolean(false))
    Err(_) => fail("expected Ok")
  }
}

///|
test "boolean rejects string" {
  let s = boolean()
  guard s.parse(Json::string("true")) is Err(_) else { fail("expected Err") }
}

///|
/// null()
test "null accepts null" {
  let s = null()
  match s.parse(Json::null()) {
    Ok(v) => assert_eq(v, Json::null())
    Err(_) => fail("expected Ok")
  }
}

///|
test "null rejects string" {
  let s = null()
  guard s.parse(Json::string("null")) is Err(_) else { fail("expected Err") }
}

///|
fn parse_json(input : String) -> Json {
  @json.parse(input) catch {
    _ => abort("bad test json: " + input)
  }
}

///|
/// object() — valid cases
test "object validates flat object" {
  let s = object({ "name": string(), "age": number().int() })
  let input = parse_json("{\"name\": \"Alice\", \"age\": 30}")
  match s.parse(input) {
    Ok(v) => assert_eq(v, input)
    Err(_) => fail("expected Ok")
  }
}

///|
test "object validates nested object" {
  let s = object({ "user": object({ "profile": object({ "name": string() }) }) })
  let input = parse_json("{\"user\": {\"profile\": {\"name\": \"Alice\"}}}")
  match s.parse(input) {
    Ok(v) => assert_eq(v, input)
    Err(_) => fail("expected Ok")
  }
}

///|
test "object passthrough (default) allows extra fields" {
  let s = object({ "name": string() })
  let input = parse_json("{\"name\": \"Alice\", \"extra\": 1}")
  match s.parse(input) {
    Ok(v) => assert_eq(v, input)
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
      assert_eq(errors.length(), 1)
      assert_eq(errors[0].path, "name")
      assert_eq(errors[0].message, "Required")
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
    Err(errors) => assert_eq(errors[0].path, "user.profile.name")
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
      assert_eq(errors[0].path, "extra")
      assert_eq(errors[0].message, "Unexpected field")
    }
    _ => fail("expected Err")
  }
}

///|
test "object collects multiple field errors" {
  let s = object({ "a": string().min(5), "b": number().positive() })
  let input = parse_json("{\"a\": \"ab\", \"b\": -1}")
  match s.parse(input) {
    Err(errors) => assert_eq(errors.length(), 2)
    _ => fail("expected Err")
  }
}

///|
test "strict mode with nested path" {
  let s = object({ "inner": object({ "x": number() }).strict() })
  let input = parse_json("{\"inner\": {\"x\": 1, \"y\": 2}}")
  match s.parse(input) {
    Err(errors) => {
      assert_eq(errors[0].path, "inner.y")
      assert_eq(errors[0].message, "Unexpected field")
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
      assert_eq(errors[0].path, "root")
      assert_eq(errors[0].message, "Expected string")
    }
    _ => fail("expected Err")
  }
}

///|
test "multiple rules report first failing" {
  let s = string().min(5).max(10)
  match s.parse(Json::string("ab")) {
    Err(errors) =>
      assert_eq(
        errors[0].message,
        "String must contain at least 5 character(s)",
      )
    _ => fail("expected Err")
  }
}
