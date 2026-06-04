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
