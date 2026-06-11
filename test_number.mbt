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
