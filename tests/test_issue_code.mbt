///|
test "validation_error has code field" {
  let s = string()
  guard s.parse(Json::number(42.0)) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].code, IssueCode::InvalidType("string"))
}

///|
test "issue_code invalid_type string" {
  let s = string()
  guard s.parse(Json::number(42.0)) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].code, IssueCode::InvalidType("string"))
}

///|
test "issue_code invalid_type number" {
  let s = number()
  guard s.parse(Json::string("abc")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].code, IssueCode::InvalidType("number"))
}

///|
test "issue_code invalid_type boolean" {
  let s = boolean()
  guard s.parse(Json::string("true")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].code, IssueCode::InvalidType("boolean"))
}

///|
test "issue_code invalid_type object" {
  let s = object(Map([]))
  guard s.parse(Json::string("hello")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].code, IssueCode::InvalidType("object"))
}

///|
test "issue_code invalid_type array" {
  let s = array(string())
  guard s.parse(Json::string("hello")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].code, IssueCode::InvalidType("array"))
}

///|
test "issue_code rule_error_too_small" {
  let s = string().min(3)
  guard s.parse(Json::string("ab")) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].code, IssueCode::TooSmall("string", 3.0, true))
}

///|
test "issue_code email_rule_invalid_format" {
  let s = string().email()
  guard s.parse(Json::string("not-an-email")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].code, IssueCode::InvalidFormat("email"))
}

///|
test "issue_code refine is custom" {
  let s = string().refine(
    fn(s) {
      match s {
        Json::String(str) => str.length() > 3
        _ => false
      }
    },
    "too short",
  )
  guard s.parse(Json::string("ab")) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].code, IssueCode::Custom)
  @debug.assert_eq(errors[0].message, "too short")
}

///|
test "issue_code missing_required" {
  let s = object({ "name": string() })
  let input = parse_json("{}")
  guard s.parse(input) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].code, IssueCode::MissingRequired("name"))
}

///|
test "issue_code missing_required custom message" {
  let s = object({ "name": string(required_error="姓名必填") })
  let input = parse_json("{}")
  guard s.parse(input) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].code, IssueCode::MissingRequired("name"))
  @debug.assert_eq(errors[0].message, "姓名必填")
}

///|
test "issue_code invalid_union" {
  let s = union([string(), number()])
  guard s.parse(Json::boolean(true)) is Err(errors) else {
    fail("expected Err")
  }
  match errors[0].code {
    IssueCode::InvalidUnion(_) => ()
    _ => fail("expected InvalidUnion")
  }
}

///|
test "issue_code unrecognized_keys strict" {
  let s = object({ "name": string() }).strict()
  let input = parse_json("{\"name\": \"Alice\", \"extra\": 1}")
  guard s.parse(input) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].code, IssueCode::UnrecognizedKeys(["extra"]))
}

///|
test "issue_code invalid_value enum" {
  let s = enum_values(["red", "green", "blue"])
  guard s.parse(Json::string("yellow")) is Err(errors) else {
    fail("expected Err")
  }
  match errors[0].code {
    IssueCode::InvalidValue(_) => ()
    _ => fail("expected InvalidValue")
  }
}

///|
test "issue_code invalid_value literal" {
  let s = literal(Json::string("expected"))
  guard s.parse(Json::string("actual")) is Err(errors) else {
    fail("expected Err")
  }
  match errors[0].code {
    IssueCode::InvalidValue(_) => ()
    _ => fail("expected InvalidValue")
  }
}

///|
test "issue_code nested object path" {
  let s = object({ "user": object({ "age": number().int() }) })
  let input = parse_json("{\"user\": {\"age\": \"x\"}}")
  guard s.parse(input) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].path, "user.age")
  @debug.assert_eq(errors[0].code, IssueCode::InvalidType("number"))
}

///|
test "issue_code array_index_path" {
  let s = array(number().int())
  let input = parse_json("[1, \"two\", 3]")
  guard s.parse(input) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].path, "[1]")
  @debug.assert_eq(errors[0].code, IssueCode::InvalidType("number"))
}

///|
test "issue_code optional_missing_no_error" {
  let s = object({ "name": string().optional() })
  guard s.parse(parse_json("{}")) is Ok(_) else { fail("expected Ok") }
}

///|
test "issue_code default_uses_default_no_error" {
  let s = object({ "name": string().default("anon") })
  guard s.parse(parse_json("{}")) is Ok(_) else { fail("expected Ok") }
}
