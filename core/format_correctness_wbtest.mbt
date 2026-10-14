///|
test "email rejects invalid domain and consecutive local dots" {
  for
    value in [
      "a@bad domain.com", "a..b@example.com", "a@example..com", "a@.com",
    ] {
    assert_true(string().email().parse(Json::string(value)) is Err(_))
  }
}

///|
test "datetime validates complete time timezone and fractions" {
  assert_true(
    string().datetime().parse(Json::string("2024-01-01T12:00:00+garbage"))
    is Err(_),
  )
  assert_true(
    string().datetime().parse(Json::string("2024-01-01T12:00:00.123Z")) is Ok(_),
  )
  assert_true(string().datetime().parse(Json::string("2024-01-01")) is Err(_))
  assert_true(
    string()
    .datetime(offset=true)
    .parse(Json::string("2024-01-01T12:00:00+08:00"))
    is Ok(_),
  )
  assert_true(
    string()
    .datetime(offset=true)
    .parse(Json::string("2024-01-01T12:00:00+99:99"))
    is Err(_),
  )
  assert_true(
    string().datetime(allow_local=true).parse(Json::string("2024-01-01T12:00"))
    is Ok(_),
  )
  assert_true(
    string()
    .datetime(precision=3)
    .parse(Json::string("2024-01-01T12:00:00.123Z"))
    is Ok(_),
  )
  assert_true(
    string().datetime(precision=3).parse(Json::string("2024-01-01T12:00:00Z"))
    is Err(_),
  )
}

///|
test "ipv6 rejects multiple compression and excess groups" {
  for value in ["1::2::3", ":::1", "1:2:3:4:5:6:7:8::", "1:2:3:4:5:6:7:"] {
    assert_true(string().ipv6().parse(Json::string(value)) is Err(_))
  }
  assert_true(string().ipv6().parse(Json::string("::ffff:192.0.2.1")) is Ok(_))
}

///|
test "URL separates authority from path and permits generic schemes" {
  for
    value in [
      "https://example.com/a:b", "https://example.com/?next=http://x.com", "http://[::1]:80/a",
      "mailto:a@example.com", "ftp://example.com/x", "HTTPS://example.com",
    ] {
    assert_true(string().url().parse(Json::string(value)) is Ok(_))
  }
  for
    value in [
      "http://", "https://example.com:9999999999999999999", "https://bad host.com",
      "https://[1::2::3]/",
    ] {
    assert_true(string().url().parse(Json::string(value)) is Err(_))
  }
}

///|
test "UUID accepts RFC versions beyond v4" {
  assert_true(
    string().uuid().parse(Json::string("6ba7b810-9dad-11d1-80b4-00c04fd430c8"))
    is Ok(_),
  )
}

///|
test "builtin string operations compose with following checks" {
  assert_true(
    string().trim().to_lower().min(1).parse(Json::string(" X ")) is Ok(_),
  )
  assert_true(
    string().trim().min(3).message("too short").parse(Json::string(" x "))
    is Err(_),
  )
}
