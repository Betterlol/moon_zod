///|
/// array() — valid
test "array validates elements" {
  let s = @core.array(@core.number())
  let input = @core.parse_json("[1, 2, 3]")
  match s.parse(input) {
    Ok(v) => @debug.assert_eq(v, input)
    Err(_) => fail("expected Ok")
  }
}

///|
test "array rejects non-array" {
  let s = @core.array(@core.string())
  guard s.parse(Json::string("hello")) is Err(_) else { fail("expected Err") }
}

///|
test "array min length passes" {
  let s = @core.array(@core.string()).min(2)
  let input = @core.parse_json("[\"a\", \"b\"]")
  match s.parse(input) {
    Ok(v) => @debug.assert_eq(v, input)
    Err(_) => fail("expected Ok")
  }
}

///|
test "array min length fails" {
  let s = @core.array(@core.string()).min(3)
  guard s.parse(@core.parse_json("[\"a\", \"b\"]")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "array max length fails" {
  let s = @core.array(@core.string()).max(1)
  guard s.parse(@core.parse_json("[\"a\", \"b\"]")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "array reports correct element index path" {
  let s = @core.array(@core.number().positive())
  let input = @core.parse_json("[1, -2, 3]")
  match s.parse(input) {
    Err(errors) => @debug.assert_eq(errors[0].path, "[1]")
    _ => fail("expected Err")
  }
}

///|
test "nested array reports matrix path" {
  let s = @core.array(@core.array(@core.number().positive()))
  let input = @core.parse_json("[[1, -2], [3, 4]]")
  match s.parse(input) {
    Err(errors) => @debug.assert_eq(errors[0].path, "[0][1]")
    _ => fail("expected Err")
  }
}

///|
/// length() — exact length for array
test "array length passes exact match" {
  let s = @core.array(@core.string()).length(3)
  guard s.parse(@core.parse_json("[\"a\", \"b\", \"c\"]")) is Ok(_) else {
    fail("expected Ok")
  }
}

///|
test "array length rejects fewer items" {
  let s = @core.array(@core.string()).length(5)
  guard s.parse(@core.parse_json("[\"a\", \"b\"]")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "array length rejects more items" {
  let s = @core.array(@core.string()).length(1)
  guard s.parse(@core.parse_json("[\"a\", \"b\"]")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "array length custom message" {
  let s = @core.array(@core.string()).length(2, msg="数组长度必须为2")
  guard s.parse(@core.parse_json("[\"a\"]")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].message, "数组长度必须为2")
}

///|
/// nonempty() for array
test "array nonempty passes non-empty" {
  let s = @core.array(@core.string()).nonempty()
  guard s.parse(@core.parse_json("[\"a\"]")) is Ok(_) else {
    fail("expected Ok")
  }
}

///|
test "array nonempty rejects empty" {
  let s = @core.array(@core.string()).nonempty()
  guard s.parse(@core.parse_json("[]")) is Err(_) else { fail("expected Err") }
}

///|
test "array nonempty custom message" {
  let s = @core.array(@core.string()).nonempty(msg="数组不能为空")
  guard s.parse(@core.parse_json("[]")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].message, "数组不能为空")
}
