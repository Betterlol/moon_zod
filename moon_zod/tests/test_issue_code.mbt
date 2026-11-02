///|
test "validation_error has code field" {
  let s = @core.string()
  guard s.parse(Json::number(42.0)) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].code, @core.IssueCode::InvalidType("string"))
}

///|
test "issue_code invalid_type string" {
  let s = @core.string()
  guard s.parse(Json::number(42.0)) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].code, @core.IssueCode::InvalidType("string"))
}

///|
test "issue_code invalid_type number" {
  let s = @core.number()
  guard s.parse(Json::string("abc")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].code, @core.IssueCode::InvalidType("number"))
}

///|
test "issue_code invalid_type boolean" {
  let s = @core.boolean()
  guard s.parse(Json::string("true")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].code, @core.IssueCode::InvalidType("boolean"))
}

///|
test "issue_code invalid_type object" {
  let s = @core.object(Map([]))
  guard s.parse(Json::string("hello")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].code, @core.IssueCode::InvalidType("object"))
}

///|
test "issue_code invalid_type array" {
  let s = @core.array(@core.string())
  guard s.parse(Json::string("hello")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].code, @core.IssueCode::InvalidType("array"))
}

///|
test "issue_code rule_error_too_small" {
  let s = @core.string().min(3)
  guard s.parse(Json::string("ab")) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(
    errors[0].code,
    @core.IssueCode::TooSmall("string", 3.0, true),
  )
}

///|
test "issue_code email_rule_invalid_format" {
  let s = @core.string().email()
  guard s.parse(Json::string("not-an-email")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].code, @core.IssueCode::InvalidFormat("email"))
}

///|
test "issue_code refine is custom" {
  let s = @core.string().refine(
    fn(s) {
      match s {
        Json::String(str) => str.length() > 3
        _ => false
      }
    },
    "too short",
  )
  guard s.parse(Json::string("ab")) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].code, @core.IssueCode::Custom)
  @debug.assert_eq(errors[0].message, "too short")
}

///|
test "issue_code missing_required" {
  let s = @core.object({ "name": @core.string() })
  let input = @core.parse_json("{}")
  guard s.parse(input) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].code, @core.IssueCode::MissingRequired("name"))
}

///|
test "issue_code missing_required custom message" {
  let s = @core.object({ "name": @core.string(required_error="姓名必填") })
  let input = @core.parse_json("{}")
  guard s.parse(input) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].code, @core.IssueCode::MissingRequired("name"))
  @debug.assert_eq(errors[0].message, "姓名必填")
}

///|
test "issue_code invalid_union" {
  let s = @core.union([@core.string(), @core.number()])
  guard s.parse(Json::boolean(true)) is Err(errors) else {
    fail("expected Err")
  }
  match errors[0].code {
    @core.IssueCode::InvalidUnion(_) => ()
    _ => fail("expected InvalidUnion")
  }
}

///|
test "issue_code unrecognized_keys strict" {
  let s = @core.object({ "name": @core.string() }).strict()
  let input = @core.parse_json("{\"name\": \"Alice\", \"extra\": 1}")
  guard s.parse(input) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].code, @core.IssueCode::UnrecognizedKeys(["extra"]))
}

///|
test "issue_code invalid_value enum" {
  let s = @core.enum_values(["red", "green", "blue"])
  guard s.parse(Json::string("yellow")) is Err(errors) else {
    fail("expected Err")
  }
  match errors[0].code {
    @core.IssueCode::InvalidValue(_) => ()
    _ => fail("expected InvalidValue")
  }
}

///|
test "issue_code invalid_value literal" {
  let s = @core.literal(Json::string("expected"))
  guard s.parse(Json::string("actual")) is Err(errors) else {
    fail("expected Err")
  }
  match errors[0].code {
    @core.IssueCode::InvalidValue(_) => ()
    _ => fail("expected InvalidValue")
  }
}

///|
test "issue_code nested object path" {
  let s = @core.object({ "user": @core.object({ "age": @core.number().int() }) })
  let input = @core.parse_json("{\"user\": {\"age\": \"x\"}}")
  guard s.parse(input) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].path, "user.age")
  @debug.assert_eq(errors[0].code, @core.IssueCode::InvalidType("number"))
}

///|
test "issue_code array_index_path" {
  let s = @core.array(@core.number().int())
  let input = @core.parse_json("[1, \"two\", 3]")
  guard s.parse(input) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].path, "[1]")
  @debug.assert_eq(errors[0].code, @core.IssueCode::InvalidType("number"))
}

///|
test "issue_code optional_missing_no_error" {
  let s = @core.object({ "name": @core.string().optional() })
  guard s.parse(@core.parse_json("{}")) is Ok(_) else { fail("expected Ok") }
}

///|
test "issue_code default_uses_default_no_error" {
  let s = @core.object({ "name": @core.string().default("anon") })
  guard s.parse(@core.parse_json("{}")) is Ok(_) else { fail("expected Ok") }
}
