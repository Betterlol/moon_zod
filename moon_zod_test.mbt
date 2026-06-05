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
test "object passthrough allows extra fields" {
  let s = object({ "name": string() }).passthrough()
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

///|
/// array() — valid
test "array validates elements" {
  let s = array(number())
  let input = parse_json("[1, 2, 3]")
  match s.parse(input) {
    Ok(v) => assert_eq(v, input)
    Err(_) => fail("expected Ok")
  }
}

///|
test "array rejects non-array" {
  let s = array(string())
  guard s.parse(Json::string("hello")) is Err(_) else { fail("expected Err") }
}

///|
test "array min length passes" {
  let s = array(string()).min(2)
  let input = parse_json("[\"a\", \"b\"]")
  match s.parse(input) {
    Ok(v) => assert_eq(v, input)
    Err(_) => fail("expected Ok")
  }
}

///|
test "array min length fails" {
  let s = array(string()).min(3)
  guard s.parse(parse_json("[\"a\", \"b\"]")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "array max length fails" {
  let s = array(string()).max(1)
  guard s.parse(parse_json("[\"a\", \"b\"]")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "array reports correct element index path" {
  let s = array(number().positive())
  let input = parse_json("[1, -2, 3]")
  match s.parse(input) {
    Err(errors) => assert_eq(errors[0].path, "[1]")
    _ => fail("expected Err")
  }
}

///|
test "nested array reports matrix path" {
  let s = array(array(number().positive()))
  let input = parse_json("[[1, -2], [3, 4]]")
  match s.parse(input) {
    Err(errors) => assert_eq(errors[0].path, "[0][1]")
    _ => fail("expected Err")
  }
}

///|
/// optional()
test "object field optional passes with missing field" {
  let s = object({ "name": string().optional() })
  let input = parse_json("{}")
  match s.parse(input) {
    Ok(v) => assert_eq(v, input)
    Err(_) => fail("expected Ok")
  }
}

///|
test "object field optional passes with null" {
  let s = object({ "name": string().optional() })
  let input = parse_json("{\"name\": null}")
  match s.parse(input) {
    Ok(v) => assert_eq(v, input)
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
    Ok(v) => assert_eq(v, input)
    Err(_) => fail("expected Ok")
  }
}

///|
/// enum_values()
test "enum_values accepts valid value" {
  let s = enum_values(["a", "b", "c"])
  match s.parse(Json::string("b")) {
    Ok(v) => assert_eq(v, Json::string("b"))
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
    Ok(v) => assert_eq(v, Json::string("hello"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "union accepts second matching schema" {
  let s = union([string(), number()])
  match s.parse(Json::number(42.0)) {
    Ok(v) => assert_eq(v, Json::number(42.0))
    Err(_) => fail("expected Ok")
  }
}

///|
test "union rejects when no schema matches" {
  let s = union([string(), number()])
  guard s.parse(Json::boolean(true)) is Err(_) else { fail("expected Err") }
}

///|
/// refine()
test "refine passes custom check" {
  let s = number().refine(
    fn(json) {
      match json {
        Number(v, ..) => v > 10.0
        _ => false
      }
    },
    "Value must be > 10",
  )
  match s.parse(Json::number(20.0)) {
    Ok(v) => assert_eq(v, Json::number(20.0))
    Err(_) => fail("expected Ok")
  }
}

///|
test "refine fails custom check" {
  let s = number().refine(
    fn(json) {
      match json {
        Number(v, ..) => v > 10.0
        _ => false
      }
    },
    "Value must be > 10",
  )
  guard s.parse(Json::number(5.0)) is Err(_) else { fail("expected Err") }
}

///|
/// Phase 4 — append_rule through optional/default chaining
test "string().optional().min(3) passes non-null long enough" {
  let s = string().optional().min(3)
  match s.parse(Json::string("abc")) {
    Ok(v) => assert_eq(v, Json::string("abc"))
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
    Ok(v) => assert_eq(v, Json::null())
    Err(_) => fail("expected Ok")
  }
}

///|
test "string().default(x).min(3) uses default for null" {
  let s = string().default(Json::string("xyz")).min(3)
  match s.parse(Json::null()) {
    Ok(v) => assert_eq(v, Json::string("xyz"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "default value satisfies rules chained after default" {
  let s = string().default(Json::string("default!")).min(3)
  match s.parse(Json::null()) {
    Ok(v) => assert_eq(v, Json::string("default!"))
    Err(_) => fail("expected Ok")
  }
}

///|
/// Phase 4 — to_json_schema
test "to_json_schema string" {
  let result = to_json_schema(string())
  let expected = parse_json("{\"type\": \"string\"}")
  assert_eq(result, expected)
}

///|
test "to_json_schema object with optional field" {
  let s = object({ "name": string(), "email": string().optional() })
  let result = to_json_schema(s)
  let expected = parse_json(
    "{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"},\"email\":{\"type\":\"string\"}},\"additionalProperties\":true,\"required\":[\"name\"]}",
  )
  assert_eq(result, expected)
}

///|
test "to_json_schema strict object" {
  let s = object({ "x": number() }).strict()
  let result = to_json_schema(s)
  let expected = parse_json(
    "{\"type\":\"object\",\"properties\":{\"x\":{\"type\":\"number\"}},\"additionalProperties\":false,\"required\":[\"x\"]}",
  )
  assert_eq(result, expected)
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
    Ok(v) => assert_eq(v, Json::number(5.0))
    Err(_) => fail("expected Ok")
  }
}

///|
test "default type rejects non-null failing validation" {
  let s = number().default(Json::number(0.0)).positive()
  guard s.parse(Json::number(-1.0)) is Err(_) else { fail("expected Err") }
}

///|
/// Phase 5 — Strip mode (default)
test "strip removes extra fields by default" {
  let s = object({ "name": string() })
  let input = parse_json("{\"name\": \"Alice\", \"extra\": 1}")
  match s.parse(input) {
    Ok(v) => assert_eq(v, parse_json("{\"name\": \"Alice\"}"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "strip removes extra fields in nested objects" {
  let s = object({ "user": object({ "name": string() }) })
  let input = parse_json("{\"user\": {\"name\": \"Alice\", \"ignored\": true}}")
  match s.parse(input) {
    Ok(v) => assert_eq(v, parse_json("{\"user\": {\"name\": \"Alice\"}}"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "explicit passthrough still allows extra fields" {
  let s = object({ "name": string() }).passthrough()
  let input = parse_json("{\"name\": \"Alice\", \"extra\": 1}")
  match s.parse(input) {
    Ok(v) => assert_eq(v, input)
    Err(_) => fail("expected Ok")
  }
}

///|
test "explicit strip method works" {
  let s = object({ "name": string() }).strip()
  let input = parse_json("{\"name\": \"Bob\", \"x\": 2, \"y\": 3}")
  match s.parse(input) {
    Ok(v) => assert_eq(v, parse_json("{\"name\": \"Bob\"}"))
    Err(_) => fail("expected Ok")
  }
}

///|
/// Phase 5 — path stack correctness
test "deep nested path with arrays and objects" {
  let s = object({ "a": array(object({ "b": number().positive() })) })
  let input = parse_json("{\"a\": [{\"b\": 1}, {\"b\": -2}]}")
  match s.parse(input) {
    Err(errors) => assert_eq(errors[0].path, "a[1].b")
    _ => fail("expected Err")
  }
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
