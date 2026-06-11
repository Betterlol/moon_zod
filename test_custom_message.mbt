///|
/// custom message — string rules
test "string min custom message" {
  let s = string().min(3, msg="太短了")
  guard s.parse(Json::string("ab")) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].message, "太短了")
}

///|
test "string max custom message" {
  let s = string().max(3, msg="太长了")
  guard s.parse(Json::string("abcd")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].message, "太长了")
}

///|
test "string nonempty custom message" {
  let s = string().nonempty(msg="不能为空")
  guard s.parse(Json::string("")) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].message, "不能为空")
}

///|
test "string email custom message" {
  let s = string().email(msg="邮箱格式错误")
  guard s.parse(Json::string("not-email")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].message, "邮箱格式错误")
}

///|
test "string url custom message" {
  let s = string().url(msg="不是有效网址")
  guard s.parse(Json::string("example.com")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].message, "不是有效网址")
}

///|
/// custom message — number rules
test "number int custom message" {
  let s = number().int(msg="需要整数")
  guard s.parse(Json::number(3.14)) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].message, "需要整数")
}

///|
test "number positive custom message" {
  let s = number().positive(msg="需要正数")
  guard s.parse(Json::number(0.0)) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].message, "需要正数")
}

///|
test "number negative custom message" {
  let s = number().negative(msg="需要负数")
  guard s.parse(Json::number(5.0)) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].message, "需要负数")
}

///|
test "number multipleOf custom message" {
  let s = number().multipleOf(3, msg="必须是3的倍数")
  guard s.parse(Json::number(5.0)) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].message, "必须是3的倍数")
}

///|
/// custom message — with optional chain (decorator penetration)
test "custom message with optional chain" {
  let s = string().min(3, msg="太短").optional()
  guard s.parse(Json::string("ab")) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].message, "太短")
}

///|
/// custom message — with multiple rules
test "custom message with multiple rules" {
  let s = string().min(3, msg="太短").max(10, msg="太长")
  guard s.parse(Json::string("ab")) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].message, "太短")
  guard s.parse(Json::string("abcdefghijk")) is Err(errors2) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors2[0].message, "太长")
}

///|
/// custom message — without msg uses default
test "default message unchanged without msg" {
  let s = string().min(3)
  guard s.parse(Json::string("ab")) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(
    errors[0].message,
    "String must contain at least 3 character(s)",
  )
}

///|
/// custom message — in object field
test "custom message in object field" {
  let s = object({ "name": string().min(2, msg="姓名至少2个字") })
  guard s.parse(Json::object({ "name": Json::string("A") })) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].message, "姓名至少2个字")
}

///|
/// .message() method — basic usage
test "message method overrides last rule" {
  let s = string().min(3).message("太短了")
  guard s.parse(Json::string("ab")) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].message, "太短了")
}

///|
test "message method with max" {
  let s = string().max(3).message("太长了")
  guard s.parse(Json::string("abcd")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].message, "太长了")
}

///|
test "message method with multiple rules overrides only last" {
  let s = string().min(3).max(10).message("长度不符合要求")
  guard s.parse(Json::string("ab")) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(
    errors[0].message,
    "String must contain at least 3 character(s)",
  )
  guard s.parse(Json::string("abcdefghijk")) is Err(errors2) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors2[0].message, "长度不符合要求")
}

///|
test "message method with optional chain" {
  let s = string().min(3).message("太短了").optional()
  guard s.parse(Json::string("ab")) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].message, "太短了")
}

///|
test "message method with default chain" {
  let s = string().min(3).message("太短了").default(Json::string(""))
  guard s.parse(Json::string("ab")) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].message, "太短了")
}

///|
test "message method with transform chain" {
  let s = string().min(3).message("太短了").transform(fn(json) { Ok(json) })
  guard s.parse(Json::string("ab")) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].message, "太短了")
}

///|
test "message method in object field" {
  let s = object({ "name": string().min(2).message("姓名至少2个字") })
  guard s.parse(Json::object({ "name": Json::string("A") })) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].message, "姓名至少2个字")
}

///|
test "message method with nonempty" {
  let s = string().nonempty().message("不能为空")
  guard s.parse(Json::string("")) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].message, "不能为空")
}
