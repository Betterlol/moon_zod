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
/// type-level error messages
test "string invalid_type_error" {
  let s = string(invalid_type_error="必须是字符串")
  guard s.parse(Json::number(42.0)) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].message, "必须是字符串")
}

///|
test "number invalid_type_error" {
  let s = number(invalid_type_error="必须是数字")
  guard s.parse(Json::string("abc")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].message, "必须是数字")
}

///|
test "boolean invalid_type_error" {
  let s = boolean(invalid_type_error="必须是布尔值")
  guard s.parse(Json::string("true")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].message, "必须是布尔值")
}

///|
test "null invalid_type_error" {
  let s = null(invalid_type_error="必须是null")
  guard s.parse(Json::string("null")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].message, "必须是null")
}

///|
test "object invalid_type_error" {
  let s = object(Map([]), invalid_type_error="必须是对象")
  guard s.parse(Json::string("not-object")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].message, "必须是对象")
}

///|
test "array invalid_type_error" {
  let s = array(string(), invalid_type_error="必须是数组")
  guard s.parse(Json::string("not-array")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].message, "必须是数组")
}

///|
test "object field required_error" {
  let s = object({ "name": string(required_error="姓名是必填项") })
  let input = parse_json("{}")
  match s.parse(input) {
    Err(errors) => @debug.assert_eq(errors[0].message, "姓名是必填项")
    _ => fail("expected Err")
  }
}

///|
test "string invalid_type_error defaults to expected" {
  let s = string()
  guard s.parse(Json::number(42.0)) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].message, "Expected string")
}

///|
/// Chainable .required_error() method
test "schema required_error chainable method" {
  let s = object({ "name": string().required_error("姓名是必填项") })
  let input = parse_json("{}")
  match s.parse(input) {
    Err(errors) => @debug.assert_eq(errors[0].message, "姓名是必填项")
    _ => fail("expected Err")
  }
}

///|
/// Chainable .invalid_type_error() method on string
test "schema invalid_type_error chainable method string" {
  let s = string().invalid_type_error("必须是字符串")
  guard s.parse(Json::number(42.0)) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].message, "必须是字符串")
}

///|
/// Chainable .invalid_type_error() method on number
test "schema invalid_type_error chainable method number" {
  let s = number().invalid_type_error("必须是数字")
  guard s.parse(Json::string("abc")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].message, "必须是数字")
}

///|
/// Chainable .invalid_type_error() overrides factory default
test "schema invalid_type_error chainable overrides factory" {
  let s = string(invalid_type_error="factory").invalid_type_error("chain")
  guard s.parse(Json::number(42.0)) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].message, "chain")
}
