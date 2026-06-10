///|
/// string() — valid cases
test "string accepts valid string" {
  let s = string()
  match s.parse(Json::string("hello")) {
    Ok(v) => @debug.assert_eq(v, Json::string("hello"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "string min passes long enough" {
  let s = string().min(3)
  match s.parse(Json::string("abc")) {
    Ok(v) => @debug.assert_eq(v, Json::string("abc"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "string max passes short enough" {
  let s = string().max(5)
  match s.parse(Json::string("hello")) {
    Ok(v) => @debug.assert_eq(v, Json::string("hello"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "string email passes valid" {
  let s = string().email()
  match s.parse(Json::string("user@example.com")) {
    Ok(v) => @debug.assert_eq(v, Json::string("user@example.com"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "string url passes valid" {
  let s = string().url()
  match s.parse(Json::string("https://moonbitlang.com")) {
    Ok(v) => @debug.assert_eq(v, Json::string("https://moonbitlang.com"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "string nonempty passes non-empty" {
  let s = string().nonempty()
  match s.parse(Json::string("x")) {
    Ok(v) => @debug.assert_eq(v, Json::string("x"))
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
    Ok(v) => @debug.assert_eq(v, Json::number(42.0))
    Err(_) => fail("expected Ok")
  }
}

///|
test "number int passes integer" {
  let s = number().int()
  match s.parse(Json::number(7.0)) {
    Ok(v) => @debug.assert_eq(v, Json::number(7.0))
    Err(_) => fail("expected Ok")
  }
}

///|
test "number positive passes positive" {
  let s = number().positive()
  match s.parse(Json::number(1.0)) {
    Ok(v) => @debug.assert_eq(v, Json::number(1.0))
    Err(_) => fail("expected Ok")
  }
}

///|
test "number negative passes negative" {
  let s = number().negative()
  match s.parse(Json::number(-1.0)) {
    Ok(v) => @debug.assert_eq(v, Json::number(-1.0))
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
    Ok(v) => @debug.assert_eq(v, Json::boolean(true))
    Err(_) => fail("expected Ok")
  }
}

///|
test "boolean accepts false" {
  let s = boolean()
  match s.parse(Json::boolean(false)) {
    Ok(v) => @debug.assert_eq(v, Json::boolean(false))
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
    Ok(v) => @debug.assert_eq(v, Json::null())
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
/// array() — valid
test "array validates elements" {
  let s = array(number())
  let input = parse_json("[1, 2, 3]")
  match s.parse(input) {
    Ok(v) => @debug.assert_eq(v, input)
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
    Ok(v) => @debug.assert_eq(v, input)
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
    Err(errors) => @debug.assert_eq(errors[0].path, "[1]")
    _ => fail("expected Err")
  }
}

///|
test "nested array reports matrix path" {
  let s = array(array(number().positive()))
  let input = parse_json("[[1, -2], [3, 4]]")
  match s.parse(input) {
    Err(errors) => @debug.assert_eq(errors[0].path, "[0][1]")
    _ => fail("expected Err")
  }
}

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
    Ok(v) => @debug.assert_eq(v, Json::number(20.0))
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
/// Phase 4 — to_json_schema
test "to_json_schema string" {
  let result = to_json_schema(string())
  let expected = parse_json("{\"type\": \"string\"}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema object with optional field" {
  let s = object({ "name": string(), "email": string().optional() })
  let result = to_json_schema(s)
  let expected = parse_json(
    "{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"},\"email\":{\"type\":\"string\"}},\"additionalProperties\":true,\"required\":[\"name\"]}",
  )
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema strict object" {
  let s = object({ "x": number() }).strict()
  let result = to_json_schema(s)
  let expected = parse_json(
    "{\"type\":\"object\",\"properties\":{\"x\":{\"type\":\"number\"}},\"additionalProperties\":false,\"required\":[\"x\"]}",
  )
  @debug.assert_eq(result, expected)
}

///|
/// Phase 13 (v0.2.0) — to_json_schema full constraint export
test "to_json_schema string with constraints" {
  let s = string().min(3).max(100)
  let result = to_json_schema(s)
  let expected = parse_json(
    "{\"type\":\"string\",\"minLength\":3,\"maxLength\":100}",
  )
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema skeleton omits constraints" {
  let s = string().min(3).max(100)
  let result = to_json_schema_skeleton(s)
  let expected = parse_json("{\"type\": \"string\"}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema number with int and positive" {
  let s = number().int().positive()
  let result = to_json_schema(s)
  let expected = parse_json("{\"type\":\"integer\",\"exclusiveMinimum\":0}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema number with multipleOf" {
  let s = number().multipleOf(5)
  let result = to_json_schema(s)
  let expected = parse_json("{\"type\":\"number\",\"multipleOf\":5}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema string with email format" {
  let s = string().email()
  let result = to_json_schema(s)
  let expected = parse_json("{\"type\":\"string\",\"format\":\"email\"}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema string with url format" {
  let s = string().url()
  let result = to_json_schema(s)
  let expected = parse_json("{\"type\":\"string\",\"format\":\"uri\"}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema string with regex pattern" {
  let s = string().regex("hello")
  let result = to_json_schema(s)
  let expected = parse_json("{\"type\":\"string\",\"pattern\":\"hello\"}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema nested object with constraints" {
  let s = object({
    "name": string().min(2).max(50),
    "age": number().int().min(0).max(150),
    "email": string().email().optional(),
  })
  let result = to_json_schema(s)
  let expected = parse_json(
    "{\"type\":\"object\",\"properties\":{\"name\":{\"minLength\":2,\"maxLength\":50,\"type\":\"string\"},\"age\":{\"minimum\":0,\"maximum\":150,\"type\":\"integer\"},\"email\":{\"type\":\"string\",\"format\":\"email\"}},\"additionalProperties\":true,\"required\":[\"name\",\"age\"]}",
  )
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema constraints penetrate optional" {
  let s = string().min(3).optional()
  let result = to_json_schema(s)
  // optional() should be transparent — constraints on the inner type
  // are exported as normal string constraints
  let expected = parse_json("{\"minLength\":3,\"type\":\"string\"}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema constraints penetrate transform" {
  let s = string().min(3).transform(fn(j) { Ok(j) })
  let result = to_json_schema(s)
  // transform() should be transparent — constraints on the inner type
  // are exported as normal string constraints
  let expected = parse_json("{\"minLength\":3,\"type\":\"string\"}")
  @debug.assert_eq(result, expected)
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
/// Phase 2 — Transform Data Pipeline
test "transform appends suffix to string" {
  let s = string().transform(fn(json) {
    match json {
      String(v) => Ok(Json::string(v + "!!!"))
      _ => Err("expected string")
    }
  })
  match s.parse(Json::string("hello")) {
    Ok(v) => @debug.assert_eq(v, Json::string("hello!!!"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "transform passes through already-valid value" {
  let s = number().transform(fn(json) { Ok(json) })
  match s.parse(Json::number(42.0)) {
    Ok(v) => @debug.assert_eq(v, Json::number(42.0))
    Err(_) => fail("expected Ok")
  }
}

///|
test "transform returns error for invalid transform result" {
  let s = string().transform(fn(json) {
    match json {
      String(v) =>
        if v.length() > 3 {
          Err("too long after transform")
        } else {
          Ok(json)
        }
      _ => Err("expected string")
    }
  })
  guard s.parse(Json::string("hello")) is Err(_) else { fail("expected Err") }
}

///|
test "transform validates before transforming" {
  let s = string()
    .min(2)
    .transform(fn(json) {
      match json {
        String(v) => Ok(Json::string(v + "!!"))
        _ => Err("expected string")
      }
    })
  // min(2) passes: "ab" is length 2
  match s.parse(Json::string("ab")) {
    Ok(v) => @debug.assert_eq(v, Json::string("ab!!"))
    Err(_) => fail("expected Ok")
  }
  // min(2) fails: "a" is too short
  guard s.parse(Json::string("a")) is Err(_) else { fail("expected Err") }
}

///|
test "transform with optional accepts null" {
  let s = string()
    .transform(fn(json) {
      match json {
        String(v) => Ok(Json::string(v + "!"))
        _ => Err("expected string")
      }
    })
    .optional()
  // null should bypass the transform
  match s.parse(Json::null()) {
    Ok(v) => @debug.assert_eq(v, Json::null())
    Err(_) => fail("expected Ok")
  }
}

///|
test "transform error message includes path" {
  let s = object({
    "field": string().transform(fn(json) {
      match json {
        String(_) => Err("transform rejected this value")
        _ => Err("expected string")
      }
    }),
  })
  let json = parse_json("{\"field\": \"hello\"}")
  match s.parse(json) {
    Err(errors) => {
      @debug.assert_eq(errors[0].path, "field")
      @debug.assert_eq(errors[0].message, "transform rejected this value")
    }
    _ => fail("expected Err")
  }
}

///|
test "to_json_schema ignores transform wrapper" {
  let s = string().transform(fn(json) { Ok(json) })
  let result = to_json_schema(s)
  let expected = parse_json("{\"type\": \"string\"}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema boolean type" {
  let result = to_json_schema(boolean())
  let expected = parse_json("{\"type\": \"boolean\"}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema null type" {
  let result = to_json_schema(null())
  let expected = parse_json("{\"type\": \"null\"}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema array type" {
  let result = to_json_schema(array(string()))
  let expected = parse_json(
    "{\"type\":\"array\",\"items\":{\"type\":\"string\"}}",
  )
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema enum type" {
  let result = to_json_schema(enum_values(["a", "b"]))
  let expected = parse_json("{\"type\":\"string\",\"enum\":[\"a\",\"b\"]}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema union type" {
  let result = to_json_schema(union([string(), number()]))
  let expected = parse_json(
    "{\"anyOf\":[{\"type\":\"string\"},{\"type\":\"number\"}]}",
  )
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema default type" {
  let result = to_json_schema(string().default(Json::string("x")))
  let expected = parse_json("{\"type\":\"string\",\"default\":\"x\"}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema skeleton boolean" {
  let result = to_json_schema_skeleton(boolean())
  let expected = parse_json("{\"type\": \"boolean\"}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema skeleton null" {
  let result = to_json_schema_skeleton(null())
  let expected = parse_json("{\"type\": \"null\"}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema skeleton array" {
  let result = to_json_schema_skeleton(array(string()))
  let expected = parse_json(
    "{\"type\":\"array\",\"items\":{\"type\":\"string\"}}",
  )
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema skeleton enum" {
  let result = to_json_schema_skeleton(enum_values(["x"]))
  let expected = parse_json("{\"type\":\"string\",\"enum\":[\"x\"]}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema skeleton union" {
  let result = to_json_schema_skeleton(union([string(), boolean()]))
  let expected = parse_json(
    "{\"anyOf\":[{\"type\":\"string\"},{\"type\":\"boolean\"}]}",
  )
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema skeleton optional" {
  let result = to_json_schema_skeleton(string().optional())
  let expected = parse_json("{\"type\": \"string\"}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema skeleton default" {
  let result = to_json_schema_skeleton(string().default(Json::string("x")))
  let expected = parse_json("{\"type\":\"string\",\"default\":\"x\"}")
  @debug.assert_eq(result, expected)
}

///|
test "ValidationError to_string from parse error" {
  let s = string().min(3)
  match s.parse(Json::string("ab")) {
    Err(errors) => {
      let msg = errors[0].to_string()
      guard msg.contains("String must contain at least 3") else {
        fail("to_string missing message")
      }
      guard msg.contains("ab") else { fail("to_string missing value") }
    }
    _ => fail("expected Err")
  }
}

///|
test "ValidationError to_string path from nested object" {
  let s = object({ "name": string().min(3) })
  let input = parse_json("{\"name\": \"x\"}")
  match s.parse(input) {
    Err(errors) => {
      let msg = errors[0].to_string()
      guard msg.contains("[name]") else { fail("to_string missing path") }
      guard msg.contains("String must contain at least 3") else {
        fail("to_string missing message")
      }
    }
    _ => fail("expected Err")
  }
}

///|
test "schema_to_prompt object field with default" {
  let s = object({ "role": string().default(Json::string("user")) })
  let expected = "{\n" + "  role?: string,\n" + "}"
  @debug.assert_eq(schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt array with element and array constraints" {
  let s = array(string().min(2)).min(1).max(10)
  let expected = "string[]  // [min: 1 items, max: 10 items, min: 2]"
  @debug.assert_eq(schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt string refine custom message" {
  let s = string().refine(
    fn(json) {
      match json {
        String(s) => s.contains("good")
        _ => false
      }
    },
    "Must contain 'good'",
  )
  @debug.assert_eq(schema_to_prompt(s), "string  // [Must contain 'good']")
}

///|
test "to_json_schema merge_annotations with refine rule" {
  let s = number().refine(
    fn(json) {
      match json {
        Number(v, ..) => v > 0.0
        _ => false
      }
    },
    "Must be positive",
  )
  let result = to_json_schema(s)
  // refine has Null annotation, so to_json_schema just outputs the number schema
  let expected = parse_json("{\"type\": \"number\"}")
  @debug.assert_eq(result, expected)
}

///|
/// Phase 16 — schema_to_prompt TypeScript interface generation
test "schema_to_prompt leaf types" {
  @debug.assert_eq(schema_to_prompt(string()), "string")
  @debug.assert_eq(schema_to_prompt(number()), "number")
  @debug.assert_eq(schema_to_prompt(boolean()), "boolean")
  @debug.assert_eq(schema_to_prompt(null()), "null")
}

///|
test "schema_to_prompt optional and default" {
  @debug.assert_eq(schema_to_prompt(string().optional()), "string | null")
  @debug.assert_eq(
    schema_to_prompt(string().default(Json::string("x"))),
    "string | null",
  )
}

///|
test "schema_to_prompt string constraints" {
  @debug.assert_eq(
    schema_to_prompt(string().min(2).max(50)),
    "string  // [2-50 chars]",
  )
  @debug.assert_eq(schema_to_prompt(string().min(3)), "string  // [min: 3]")
  @debug.assert_eq(schema_to_prompt(string().max(100)), "string  // [max: 100]")
  @debug.assert_eq(schema_to_prompt(string().email()), "string  // [email]")
  @debug.assert_eq(schema_to_prompt(string().url()), "string  // [url]")
  @debug.assert_eq(
    schema_to_prompt(string().regex("hello")),
    "string  // [pattern: hello]",
  )
}

///|
test "schema_to_prompt number constraints" {
  @debug.assert_eq(schema_to_prompt(number().int()), "number  // [int]")
  @debug.assert_eq(
    schema_to_prompt(number().positive()),
    "number  // [positive]",
  )
  @debug.assert_eq(
    schema_to_prompt(number().negative()),
    "number  // [negative]",
  )
  @debug.assert_eq(
    schema_to_prompt(number().int().min(0).max(150)),
    "number  // [int, 0-150]",
  )
  @debug.assert_eq(schema_to_prompt(number().min(10)), "number  // [min: 10]")
  @debug.assert_eq(schema_to_prompt(number().max(100)), "number  // [max: 100]")
  @debug.assert_eq(
    schema_to_prompt(number().multipleOf(5)),
    "number  // [multiple of 5]",
  )
}

///|
test "schema_to_prompt enum" {
  @debug.assert_eq(
    schema_to_prompt(enum_values(["admin", "user", "viewer"])),
    "\"admin\" | \"user\" | \"viewer\"",
  )
  @debug.assert_eq(schema_to_prompt(enum_values(["a"])), "\"a\"")
}

///|
test "schema_to_prompt array" {
  @debug.assert_eq(schema_to_prompt(array(string())), "string[]")
  @debug.assert_eq(
    schema_to_prompt(array(string()).min(2)),
    "string[]  // [min: 2 items]",
  )
  @debug.assert_eq(
    schema_to_prompt(array(string()).max(5)),
    "string[]  // [max: 5 items]",
  )
  @debug.assert_eq(
    schema_to_prompt(array(string()).min(1).max(10)),
    "string[]  // [min: 1 items, max: 10 items]",
  )
  @debug.assert_eq(
    schema_to_prompt(array(string().email())),
    "string[]  // [email]",
  )
}

///|
test "schema_to_prompt union" {
  @debug.assert_eq(
    schema_to_prompt(union([string(), number()])),
    "string | number",
  )
  @debug.assert_eq(
    schema_to_prompt(union([string(), number(), boolean()])),
    "string | number | boolean",
  )
}

///|
test "schema_to_prompt optional with constraints" {
  @debug.assert_eq(
    schema_to_prompt(string().min(3).optional()),
    "string | null  // [min: 3]",
  )
  @debug.assert_eq(
    schema_to_prompt(number().int().optional()),
    "number | null  // [int]",
  )
}

///|
test "schema_to_prompt transform transparent" {
  let s = string().transform(fn(json) { Ok(json) })
  @debug.assert_eq(schema_to_prompt(s), "string")
  let s2 = number().int().transform(fn(j) { Ok(j) })
  @debug.assert_eq(schema_to_prompt(s2), "number  // [int]")
}

///|
test "schema_to_prompt empty object" {
  @debug.assert_eq(schema_to_prompt(object({})), "{}")
}

///|
test "schema_to_prompt simple object" {
  let s = object({
    "name": string().min(2).max(50),
    "age": number().int().min(0).max(150),
  })
  let expected = "{\n" +
    "  name: string,  // [2-50 chars]\n" +
    "  age: number,  // [int, 0-150]\n" +
    "}"
  @debug.assert_eq(schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt object with optional fields" {
  let s = object({
    "name": string(),
    "email": string().email().optional(),
    "role": enum_values(["admin", "user"]),
  })
  let expected = "{\n" +
    "  name: string,\n" +
    "  email?: string,  // [email]\n" +
    "  role: \"admin\" | \"user\",\n" +
    "}"
  @debug.assert_eq(schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt nested object" {
  let s = object({
    "profile": object({
      "age": number().int().min(0).max(150),
      "tags": array(string().min(1)),
    }),
  })
  let expected = "{\n" +
    "  profile: {\n" +
    "    age: number,  // [int, 0-150]\n" +
    "    tags: string[],  // [min: 1]\n" +
    "  },\n" +
    "}"
  @debug.assert_eq(schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt nested optional object" {
  let s = object({
    "metadata": object({ "level": number().int().min(1).max(10) }).optional(),
  })
  let expected = "{\n" +
    "  metadata?: {\n" +
    "    level: number,  // [int, 1-10]\n" +
    "  },\n" +
    "}"
  @debug.assert_eq(schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt refine custom message" {
  let s = number().refine(
    fn(json) {
      match json {
        Number(v, ..) => v > 10.0
        _ => false
      }
    },
    "Value must be > 10",
  )
  @debug.assert_eq(schema_to_prompt(s), "number  // [Value must be > 10]")
}

///|
test "schema_to_prompt nonempty is filtered" {
  // nonempty has no annotation and its message matches the built-in
  let s = string().nonempty()
  @debug.assert_eq(schema_to_prompt(s), "string")
}

///|
test "schema_to_prompt default with constraints" {
  let s = string().min(3).default(Json::string("abc"))
  @debug.assert_eq(schema_to_prompt(s), "string | null  // [min: 3]")
}

///|
test "schema_to_prompt describe alone" {
  @debug.assert_eq(
    schema_to_prompt(string().describe("用户名")),
    "string  // 用户名",
  )
}

///|
test "schema_to_prompt describe with constraints" {
  @debug.assert_eq(
    schema_to_prompt(string().min(3).max(50).describe("用户名")),
    "string  // [3-50 chars] — 用户名",
  )
}

///|
test "schema_to_prompt describe on optional" {
  @debug.assert_eq(
    schema_to_prompt(string().min(3).optional().describe("昵称")),
    "string | null  // [min: 3] — 昵称",
  )
}

///|
test "schema_to_prompt describe alone on optional" {
  @debug.assert_eq(
    schema_to_prompt(string().optional().describe("备注")),
    "string | null  // 备注",
  )
}

///|
test "schema_to_prompt describe on object fields" {
  let s = object({
    "name": string().min(2).max(50).describe("产品名称"),
    "price": number().positive().describe("产品价格"),
    "url": string().url().describe("产品链接"),
  })
  let expected = "{\n" +
    "  name: string,  // [2-50 chars] — 产品名称\n" +
    "  price: number,  // [positive] — 产品价格\n" +
    "  url: string,  // [url] — 产品链接\n" +
    "}"
  @debug.assert_eq(schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt describe on optional object field" {
  let s = object({
    "email": string().email().optional().describe("用户邮箱"),
  })
  let expected = "{\n" +
    "  email?: string,  // [email] — 用户邮箱\n" +
    "}"
  @debug.assert_eq(schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt describe on nested object field" {
  let s = object({
    "profile": object({
      "bio": string().min(10).max(500).describe("个人简介"),
    }).describe("用户资料"),
  })
  let expected = "{\n" +
    "  profile: {\n" +
    "    bio: string,  // [10-500 chars] — 个人简介\n" +
    "  },  // 用户资料\n" +
    "}"
  @debug.assert_eq(schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt describe through transform" {
  let s = string().describe("保持原样").transform(fn(j) { Ok(j) })
  @debug.assert_eq(schema_to_prompt(s), "string  // 保持原样")
}
