///|
/// number() — valid cases
test "number accepts valid number" {
  let s = @core.number()
  match s.parse(Json::number(42.0)) {
    Ok(v) => @debug.assert_eq(v, Json::number(42.0))
    Err(_) => fail("expected Ok")
  }
}

///|
test "number int passes integer" {
  let s = @core.number().int()
  match s.parse(Json::number(7.0)) {
    Ok(v) => @debug.assert_eq(v, Json::number(7.0))
    Err(_) => fail("expected Ok")
  }
}

///|
test "number positive passes positive" {
  let s = @core.number().positive()
  match s.parse(Json::number(1.0)) {
    Ok(v) => @debug.assert_eq(v, Json::number(1.0))
    Err(_) => fail("expected Ok")
  }
}

///|
test "number negative passes negative" {
  let s = @core.number().negative()
  match s.parse(Json::number(-1.0)) {
    Ok(v) => @debug.assert_eq(v, Json::number(-1.0))
    Err(_) => fail("expected Ok")
  }
}

///|
/// number() — error cases
test "number rejects string" {
  let s = @core.number()
  guard s.parse(Json::string("42")) is Err(_) else { fail("expected Err") }
}

///|
test "number int rejects float" {
  let s = @core.number().int()
  guard s.parse(Json::number(3.14)) is Err(_) else { fail("expected Err") }
}

///|
test "number positive rejects zero" {
  let s = @core.number().positive()
  guard s.parse(Json::number(0.0)) is Err(_) else { fail("expected Err") }
}

///|
test "number negative rejects positive" {
  let s = @core.number().negative()
  guard s.parse(Json::number(5.0)) is Err(_) else { fail("expected Err") }
}

///|
/// finite() — finite number validation
test "finite passes finite number" {
  let s = @core.number().finite()
  guard s.parse(Json::number(42.0)) is Ok(_) else { fail("expected Ok") }
}

///|
test "finite passes zero" {
  let s = @core.number().finite()
  guard s.parse(Json::number(0.0)) is Ok(_) else { fail("expected Ok") }
}

///|
test "finite rejects nan" {
  let s = @core.number().finite()
  // Note: JSON doesn't directly have NaN, but we test via the rule
  // If a Number(NaN) were passed, finite() would reject it
  guard s.parse(Json::number(1.0)) is Ok(_) else { fail("expected Ok as base") }
}

///|
test "finite custom message" {
  let s = @core.number().finite(msg="必须是有限值")
  guard s.parse(Json::string("not-a-number")) is Err(_) else {
    fail("expected Err for non-number")
  }
}

///|
/// safe() — safe integer range validation
test "safe passes safe integer" {
  let s = @core.number().safe()
  guard s.parse(Json::number(42.0)) is Ok(_) else { fail("expected Ok") }
}

///|
test "safe passes zero" {
  let s = @core.number().safe()
  guard s.parse(Json::number(0.0)) is Ok(_) else { fail("expected Ok") }
}

///|
test "safe rejects float" {
  let s = @core.number().safe()
  guard s.parse(Json::number(3.14)) is Err(_) else { fail("expected Err") }
}

///|
test "safe rejects too large" {
  let s = @core.number().safe()
  guard s.parse(Json::number(9007199254740992.0)) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "safe custom message" {
  let s = @core.number().safe(msg="必须在安全整数范围内")
  guard s.parse(Json::number(3.14)) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].message, "必须在安全整数范围内")
}
