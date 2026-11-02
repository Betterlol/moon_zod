///|
/// tuple() — valid cases
test "tuple validates fixed positions" {
  let s = @core.tuple([@core.string(), @core.number().int(), @core.boolean()])
  guard s.parse(@core.parse_json("[\"x\", 1, true]")) is Ok(_) else {
    fail("expected Ok")
  }
}

///|
test "tuple accepts empty tuple" {
  let s = @core.tuple([])
  guard s.parse(@core.parse_json("[]")) is Ok(_) else { fail("expected Ok") }
}

///|
/// tuple() — error cases
test "tuple rejects non-array" {
  let s = @core.tuple([@core.string()])
  guard s.parse(Json::string("x")) is Err(_) else { fail("expected Err") }
}

///|
test "tuple rejects wrong length" {
  let s = @core.tuple([@core.string(), @core.number()])
  match s.parse(@core.parse_json("[\"x\"]")) {
    Err(errors) =>
      @debug.assert_eq(errors[0].message, "Expected tuple of length 2")
    _ => fail("expected Err")
  }
}

///|
test "tuple reports item index path" {
  let s = @core.tuple([@core.string(), @core.number().positive()])
  match s.parse(@core.parse_json("[\"x\", -1]")) {
    Err(errors) => @debug.assert_eq(errors[0].path, "[1]")
    _ => fail("expected Err")
  }
}

///|
test "tuple supports chained array rules" {
  let s = @core.tuple([@core.string()]).nonempty()
  guard s.parse(@core.parse_json("[\"x\"]")) is Ok(_) else {
    fail("expected Ok")
  }
}
