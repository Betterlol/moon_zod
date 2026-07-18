///|
test "enum exclude removes values" {
  let s = enum_values(["red", "green", "blue"]).exclude(["green"])
  guard s.parse(Json::string("red")) is Ok(_) else {
    fail("expected Ok for red")
  }
  guard s.parse(Json::string("blue")) is Ok(_) else {
    fail("expected Ok for blue")
  }
  guard s.parse(Json::string("green")) is Err(_) else {
    fail("expected Err for green")
  }
}

///|
test "enum exclude multiple values" {
  let s = enum_values(["a", "b", "c", "d"]).exclude(["a", "c"])
  guard s.parse(Json::string("b")) is Ok(_) else { fail("expected Ok") }
  guard s.parse(Json::string("d")) is Ok(_) else { fail("expected Ok") }
  guard s.parse(Json::string("a")) is Err(_) else { fail("expected Err") }
  guard s.parse(Json::string("c")) is Err(_) else { fail("expected Err") }
}

///|
test "enum exclude preserves metadata" {
  let s = enum_values(["x", "y"], invalid_type_error="not enum")
    .name("MyEnum")
    .exclude(["y"])
  @debug.assert_eq(s.name, "MyEnum")
  @debug.assert_eq(s.invalid_type_error, "not enum")
  guard s.parse(Json::string("x")) is Ok(_) else { fail("expected Ok") }
  guard s.parse(Json::string("y")) is Err(_) else { fail("expected Err") }
}

///|
test "enum extract keeps only specified values" {
  let s = enum_values(["red", "green", "blue"]).extract(["red", "blue"])
  guard s.parse(Json::string("red")) is Ok(_) else { fail("expected Ok") }
  guard s.parse(Json::string("blue")) is Ok(_) else { fail("expected Ok") }
  guard s.parse(Json::string("green")) is Err(_) else {
    fail("expected Err for green")
  }
}

///|
test "enum extract ignores values not in original" {
  let s = enum_values(["a", "b"]).extract(["a", "c"])
  guard s.parse(Json::string("a")) is Ok(_) else { fail("expected Ok") }
  guard s.parse(Json::string("b")) is Err(_) else { fail("expected Err") }
}

///|
test "enum exclude all values produces empty enum" {
  let s = enum_values(["a", "b"]).exclude(["a", "b"])
  guard s.parse(Json::string("a")) is Err(_) else { fail("expected Err") }
  guard s.parse(Json::string("b")) is Err(_) else { fail("expected Err") }
}

///|
test "enum extract empty list produces empty enum" {
  let s = enum_values(["a", "b"]).extract([])
  guard s.parse(Json::string("a")) is Err(_) else { fail("expected Err") }
}

///|
test "enum exclude preserves rules" {
  let s = enum_values(["a", "b"])
    .refine(
      fn(json) {
        match json {
          String(v) => v.length() > 0
          _ => false
        }
      },
      "must not be empty",
    )
    .exclude(["b"])
  guard s.parse(Json::string("a")) is Ok(_) else { fail("expected Ok") }
}
