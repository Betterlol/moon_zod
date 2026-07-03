///|
/// tuple() — valid cases
test "tuple validates fixed positions" {
  let s = tuple([string(), number().int(), boolean()])
  guard s.parse(parse_json("[\"x\", 1, true]")) is Ok(_) else {
    fail("expected Ok")
  }
}

///|
test "tuple accepts empty tuple" {
  let s = tuple([])
  guard s.parse(parse_json("[]")) is Ok(_) else { fail("expected Ok") }
}

///|
/// tuple() — error cases
test "tuple rejects non-array" {
  let s = tuple([string()])
  guard s.parse(Json::string("x")) is Err(_) else { fail("expected Err") }
}

///|
test "tuple rejects wrong length" {
  let s = tuple([string(), number()])
  match s.parse(parse_json("[\"x\"]")) {
    Err(errors) =>
      @debug.assert_eq(errors[0].message, "Expected tuple of length 2")
    _ => fail("expected Err")
  }
}

///|
test "tuple reports item index path" {
  let s = tuple([string(), number().positive()])
  match s.parse(parse_json("[\"x\", -1]")) {
    Err(errors) => @debug.assert_eq(errors[0].path, "[1]")
    _ => fail("expected Err")
  }
}

///|
test "tuple supports chained array rules" {
  let s = tuple([string()]).nonempty()
  guard s.parse(parse_json("[\"x\"]")) is Ok(_) else { fail("expected Ok") }
}
