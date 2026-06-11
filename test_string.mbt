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
/// startsWith() — string prefix validation
test "string startsWith passes with correct prefix" {
  let s = string().startsWith("https://")
  match s.parse(Json::string("https://example.com")) {
    Ok(v) => @debug.assert_eq(v, Json::string("https://example.com"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "string startsWith fails with wrong prefix" {
  let s = string().startsWith("https://")
  guard s.parse(Json::string("http://example.com")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "string startsWith accepts empty prefix" {
  let s = string().startsWith("")
  match s.parse(Json::string("anything")) {
    Ok(v) => @debug.assert_eq(v, Json::string("anything"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "string startsWith custom message" {
  let s = string().startsWith("abc", msg="必须以abc开头")
  guard s.parse(Json::string("xyz")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].message, "必须以abc开头")
}

///|
/// endsWith() — string suffix validation
test "string endsWith passes with correct suffix" {
  let s = string().endsWith(".com")
  match s.parse(Json::string("example.com")) {
    Ok(v) => @debug.assert_eq(v, Json::string("example.com"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "string endsWith fails with wrong suffix" {
  let s = string().endsWith(".com")
  guard s.parse(Json::string("example.org")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "string endsWith custom message" {
  let s = string().endsWith(".com", msg="必须以.com结尾")
  guard s.parse(Json::string("example.org")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].message, "必须以.com结尾")
}

///|
/// includes() — string substring validation
test "string includes passes with contained substring" {
  let s = string().includes("hello")
  match s.parse(Json::string("say hello world")) {
    Ok(v) => @debug.assert_eq(v, Json::string("say hello world"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "string includes fails with absent substring" {
  let s = string().includes("hello")
  guard s.parse(Json::string("goodbye world")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "string includes custom message" {
  let s = string().includes("xyz", msg="必须包含xyz")
  guard s.parse(Json::string("abc")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].message, "必须包含xyz")
}

///|
/// uuid() — UUID v4 validation
test "uuid passes valid v4" {
  let s = string().uuid()
  let valid = [
    "550e8400-e29b-41d4-a716-446655440000", "f47ac10b-58cc-4372-a567-0e02b2c3d479",
    "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d", "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11",
  ]
  for v in valid {
    guard s.parse(Json::string(v)) is Ok(_) else { fail("expected Ok: \{v}") }
  }
}

///|
test "uuid rejects invalid format" {
  let s = string().uuid()
  let invalid = [
    // wrong length
    "550e8400-e29b-41d4-a716-44665544000",
    // missing dash
     "550e8400e29b-41d4-a716-446655440000",
    // wrong version (not 4)
     "550e8400-e29b-51d4-a716-446655440000",
    // wrong variant
     "550e8400-e29b-41d4-c716-446655440000",
    // non-hex character
     "550e8400-e29b-41d4-a716-44665544000g",
  ]
  for v in invalid {
    guard s.parse(Json::string(v)) is Err(_) else { fail("expected Err: \{v}") }
  }
}

///|
test "uuid custom message" {
  let s = string().uuid(msg="不是有效的UUID")
  guard s.parse(Json::string("not-a-uuid")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].message, "不是有效的UUID")
}

///|
/// improved email() — more edge cases
test "email improved rejects multiple at signs" {
  let s = string().email()
  guard s.parse(Json::string("a@b@c.com")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "email improved rejects leading dot in local" {
  let s = string().email()
  guard s.parse(Json::string(".user@example.com")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "email improved rejects trailing dot in domain" {
  let s = string().email()
  guard s.parse(Json::string("user@example.com.")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "email improved passes subdomain" {
  let s = string().email()
  guard s.parse(Json::string("user@sub.example.com")) is Ok(_) else {
    fail("expected Ok")
  }
}

///|
test "email improved rejects single-char domain" {
  let s = string().email()
  guard s.parse(Json::string("user@domain")) is Err(_) else {
    fail("expected Err")
  }
}
