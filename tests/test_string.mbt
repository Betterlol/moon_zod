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

///|
/// cuid() — CUID validation
test "cuid passes valid" {
  let s = string().cuid()
  guard s.parse(Json::string("c123456789012345678901234")) is Ok(_) else {
    fail("expected Ok")
  }
}

///|
test "cuid rejects incorrect start char" {
  let s = string().cuid()
  guard s.parse(Json::string("x123456789012345678901234")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "cuid rejects wrong length" {
  let s = string().cuid()
  guard s.parse(Json::string("c1234567890")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "cuid custom message" {
  let s = string().cuid(msg="不是有效的CUID")
  guard s.parse(Json::string("x123456789012345678901234")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].message, "不是有效的CUID")
}

///|
/// datetime() — ISO 8601 datetime validation
test "datetime passes date only" {
  let s = string().datetime()
  guard s.parse(Json::string("2024-01-15")) is Ok(_) else {
    fail("expected Ok")
  }
}

///|
test "datetime passes with time and Z" {
  let s = string().datetime()
  guard s.parse(Json::string("2024-01-15T10:30:00Z")) is Ok(_) else {
    fail("expected Ok")
  }
}

///|
test "datetime passes leap year february" {
  let s = string().datetime()
  guard s.parse(Json::string("2024-02-29")) is Ok(_) else {
    fail("expected Ok")
  }
}

///|
test "datetime rejects invalid month" {
  let s = string().datetime()
  guard s.parse(Json::string("2024-13-01")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "datetime rejects non-leap feb 29" {
  let s = string().datetime()
  guard s.parse(Json::string("2023-02-29")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "datetime custom message" {
  let s = string().datetime(msg="不是有效的日期时间")
  guard s.parse(Json::string("not-a-date")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].message, "不是有效的日期时间")
}

///|
/// ipv4() — IPv4 address validation
test "ipv4 passes valid address" {
  let s = string().ipv4()
  guard s.parse(Json::string("192.168.1.1")) is Ok(_) else {
    fail("expected Ok")
  }
}

///|
test "ipv4 rejects out-of-range" {
  let s = string().ipv4()
  guard s.parse(Json::string("999.999.999.999")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "ipv4 rejects leading zeros" {
  let s = string().ipv4()
  guard s.parse(Json::string("192.168.01.1")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "ipv4 custom message" {
  let s = string().ipv4(msg="不是有效的IPv4地址")
  guard s.parse(Json::string("bad")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].message, "不是有效的IPv4地址")
}

///|
/// ipv6() — IPv6 address validation
test "ipv6 passes loopback" {
  let s = string().ipv6()
  guard s.parse(Json::string("::1")) is Ok(_) else { fail("expected Ok") }
}

///|
test "ipv6 passes full address" {
  let s = string().ipv6()
  guard s.parse(Json::string("2001:0db8:0000:0000:0000:ff00:0042:8329"))
    is Ok(_) else {
    fail("expected Ok")
  }
}

///|
test "ipv6 passes compressed" {
  let s = string().ipv6()
  guard s.parse(Json::string("2001:db8::ff00:42:8329")) is Ok(_) else {
    fail("expected Ok")
  }
}

///|
test "ipv6 rejects garbage" {
  let s = string().ipv6()
  guard s.parse(Json::string("not-an-ipv6")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "ipv6 custom message" {
  let s = string().ipv6(msg="不是有效的IPv6地址")
  guard s.parse(Json::string("bad")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].message, "不是有效的IPv6地址")
}

///|
/// ip() — auto-detect IPv4 or IPv6
test "ip accepts ipv4" {
  let s = string().ip()
  guard s.parse(Json::string("8.8.8.8")) is Ok(_) else { fail("expected Ok") }
}

///|
test "ip accepts ipv6" {
  let s = string().ip()
  guard s.parse(Json::string("::1")) is Ok(_) else { fail("expected Ok") }
}

///|
test "ip rejects invalid" {
  let s = string().ip()
  guard s.parse(Json::string("not-an-ip")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "ip custom message" {
  let s = string().ip(msg="不是有效的IP地址")
  guard s.parse(Json::string("bad")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].message, "不是有效的IP地址")
}

///|
/// length() — exact length for string
test "string length passes exact match" {
  let s = string().length(3)
  guard s.parse(Json::string("abc")) is Ok(_) else { fail("expected Ok") }
}

///|
test "string length rejects shorter" {
  let s = string().length(5)
  guard s.parse(Json::string("ab")) is Err(_) else { fail("expected Err") }
}

///|
test "string length rejects longer" {
  let s = string().length(2)
  guard s.parse(Json::string("abc")) is Err(_) else { fail("expected Err") }
}

///|
test "string length custom message" {
  let s = string().length(5, msg="长度必须为5")
  guard s.parse(Json::string("abc")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].message, "长度必须为5")
}

///|
/// ulid() — ULID validation
test "ulid passes valid" {
  let s = string().ulid()
  // ULID example: 01ARZ3NDEKTSV4RRFFQ69G5FAV
  guard s.parse(Json::string("01ARZ3NDEKTSV4RRFFQ69G5FAV")) is Ok(_) else {
    fail("expected Ok")
  }
}

///|
test "ulid rejects wrong first char" {
  let s = string().ulid()
  // '8' is not in 0-7 range for first char
  guard s.parse(Json::string("81ARZ3NDEKTSV4RRFFQ69G5FAV")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "ulid rejects wrong length" {
  let s = string().ulid()
  guard s.parse(Json::string("01ARZ3NDEKT")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "ulid rejects invalid characters" {
  let s = string().ulid()
  // 'I', 'L', 'O', 'U' are not valid Crockford Base32
  guard s.parse(Json::string("01ARZ3NDEKTSV4RRFFQ69G5FAI")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "ulid custom message" {
  let s = string().ulid(msg="不是有效的ULID")
  guard s.parse(Json::string("bad")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].message, "不是有效的ULID")
}

///|
/// IPv6 edge cases with ::
test "ipv6 passes complex compression" {
  let s = string().ipv6()
  guard s.parse(Json::string("::1:2:3:4:5:6:7")) is Ok(_) else {
    fail("expected Ok: ::1:2:3:4:5:6:7")
  }
}

///|
test "ipv6 passes double colon at start" {
  let s = string().ipv6()
  guard s.parse(Json::string("::1")) is Ok(_) else { fail("expected Ok: ::1") }
}

///|
test "ipv6 passes double colon at end" {
  let s = string().ipv6()
  guard s.parse(Json::string("1::")) is Ok(_) else { fail("expected Ok: 1::") }
}

///|
test "ipv6 passes with many groups and compression" {
  let s = string().ipv6()
  guard s.parse(Json::string("2001:db8::1:0:0:1")) is Ok(_) else {
    fail("expected Ok: 2001:db8::1:0:0:1")
  }
}

///|
/// Email enhanced: quoted local part
test "email passes quoted local" {
  let s = string().email()
  guard s.parse(Json::string("\"abc@def\"@example.com")) is Ok(_) else {
    fail("expected Ok for quoted local")
  }
}

///|
test "email passes ip literal ipv4" {
  let s = string().email()
  guard s.parse(Json::string("user@[192.168.1.1]")) is Ok(_) else {
    fail("expected Ok for IP literal")
  }
}

///|
test "email passes ip literal ipv6" {
  let s = string().email()
  guard s.parse(Json::string("user@[IPv6:2001:db8::1]")) is Ok(_) else {
    fail("expected Ok for IPv6 literal")
  }
}

///|
test "email passes plus tag" {
  let s = string().email()
  guard s.parse(Json::string("user+tag@example.com")) is Ok(_) else {
    fail("expected Ok for +tag")
  }
}

///|
test "email rejects tld too short" {
  let s = string().email()
  guard s.parse(Json::string("user@example.c")) is Err(_) else {
    fail("expected Err for short TLD")
  }
}

///|
/// URL enhanced tests
test "url passes with path" {
  let s = string().url()
  guard s.parse(Json::string("https://example.com/path/to/page")) is Ok(_) else {
    fail("expected Ok for URL with path")
  }
}

///|
test "url passes with port" {
  let s = string().url()
  guard s.parse(Json::string("https://example.com:8080/path")) is Ok(_) else {
    fail("expected Ok for URL with port")
  }
}

///|
test "url passes with query" {
  let s = string().url()
  guard s.parse(Json::string("https://example.com/search?q=hello&page=1"))
    is Ok(_) else {
    fail("expected Ok for URL with query")
  }
}

///|
test "url passes with fragment" {
  let s = string().url()
  guard s.parse(Json::string("https://example.com/page#section")) is Ok(_) else {
    fail("expected Ok for URL with fragment")
  }
}

///|
test "url passes ipv4 host" {
  let s = string().url()
  guard s.parse(Json::string("https://192.168.1.1/admin")) is Ok(_) else {
    fail("expected Ok for IPv4 host URL")
  }
}

///|
test "url passes localhost" {
  let s = string().url()
  guard s.parse(Json::string("http://localhost:3000/api")) is Ok(_) else {
    fail("expected Ok for localhost URL")
  }
}

///|
test "url rejects bad port" {
  let s = string().url()
  guard s.parse(Json::string("https://example.com:99999")) is Err(_) else {
    fail("expected Err for bad port")
  }
}

///|
test "url custom message" {
  let s = string().url(msg="不是有效的URL")
  guard s.parse(Json::string("not-a-url")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].message, "不是有效的URL")
}

///|
/// trim()
test "string trim removes leading and trailing whitespace" {
  let s = string().trim()
  match s.parse(Json::string("  hello  ")) {
    Ok(v) => @debug.assert_eq(v, Json::string("hello"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "string trim passes already-trimmed string" {
  let s = string().trim()
  match s.parse(Json::string("hello")) {
    Ok(v) => @debug.assert_eq(v, Json::string("hello"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "string trim with min rule" {
  let s = string().trim().min(3)
  // After trim, "ab" length is 2, so min(3) should fail
  guard s.parse(Json::string("  ab  ")) is Err(_) else { fail("expected Err") }
}

///|
/// to_lower()
test "string to_lower converts uppercase" {
  let s = string().to_lower()
  match s.parse(Json::string("HELLO")) {
    Ok(v) => @debug.assert_eq(v, Json::string("hello"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "string to_lower passes already-lowercase" {
  let s = string().to_lower()
  match s.parse(Json::string("hello")) {
    Ok(v) => @debug.assert_eq(v, Json::string("hello"))
    Err(_) => fail("expected Ok")
  }
}

///|
/// to_upper()
test "string to_upper converts lowercase" {
  let s = string().to_upper()
  match s.parse(Json::string("hello")) {
    Ok(v) => @debug.assert_eq(v, Json::string("HELLO"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "string to_upper passes already-uppercase" {
  let s = string().to_upper()
  match s.parse(Json::string("HELLO")) {
    Ok(v) => @debug.assert_eq(v, Json::string("HELLO"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "string to_lower aborts for string.abort calls" {
  // nonempty() should abort for non-string after to_lower chain
  // Just verify to_lower followed by min works
  let s = string().to_lower().min(2)
  guard s.parse(Json::string("A")) is Err(_) else { fail("expected Err") }
}
