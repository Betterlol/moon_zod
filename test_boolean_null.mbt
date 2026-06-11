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
