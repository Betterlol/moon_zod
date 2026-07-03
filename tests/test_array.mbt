///|
/// array() — valid
test "array validates elements" {
  let s = array(number())
  let input = parse_json("[1, 2, 3]")
  match s.parse(input) {
    Ok(v) => @debug.assert_eq(v, input)
    Err(_) => fail("expected Ok")
  }
}

///|
test "array rejects non-array" {
  let s = array(string())
  guard s.parse(Json::string("hello")) is Err(_) else { fail("expected Err") }
}

///|
test "array min length passes" {
  let s = array(string()).min(2)
  let input = parse_json("[\"a\", \"b\"]")
  match s.parse(input) {
    Ok(v) => @debug.assert_eq(v, input)
    Err(_) => fail("expected Ok")
  }
}

///|
test "array min length fails" {
  let s = array(string()).min(3)
  guard s.parse(parse_json("[\"a\", \"b\"]")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "array max length fails" {
  let s = array(string()).max(1)
  guard s.parse(parse_json("[\"a\", \"b\"]")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "array reports correct element index path" {
  let s = array(number().positive())
  let input = parse_json("[1, -2, 3]")
  match s.parse(input) {
    Err(errors) => @debug.assert_eq(errors[0].path, "[1]")
    _ => fail("expected Err")
  }
}

///|
test "nested array reports matrix path" {
  let s = array(array(number().positive()))
  let input = parse_json("[[1, -2], [3, 4]]")
  match s.parse(input) {
    Err(errors) => @debug.assert_eq(errors[0].path, "[0][1]")
    _ => fail("expected Err")
  }
}

///|
/// length() — exact length for array
test "array length passes exact match" {
  let s = array(string()).length(3)
  guard s.parse(parse_json("[\"a\", \"b\", \"c\"]")) is Ok(_) else {
    fail("expected Ok")
  }
}

///|
test "array length rejects fewer items" {
  let s = array(string()).length(5)
  guard s.parse(parse_json("[\"a\", \"b\"]")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "array length rejects more items" {
  let s = array(string()).length(1)
  guard s.parse(parse_json("[\"a\", \"b\"]")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "array length custom message" {
  let s = array(string()).length(2, msg="数组长度必须为2")
  guard s.parse(parse_json("[\"a\"]")) is Err(errors) else {
    fail("expected Err")
  }
  @debug.assert_eq(errors[0].message, "数组长度必须为2")
}

///|
/// nonempty() for array
test "array nonempty passes non-empty" {
  let s = array(string()).nonempty()
  guard s.parse(parse_json("[\"a\"]")) is Ok(_) else { fail("expected Ok") }
}

///|
test "array nonempty rejects empty" {
  let s = array(string()).nonempty()
  guard s.parse(parse_json("[]")) is Err(_) else { fail("expected Err") }
}

///|
test "array nonempty custom message" {
  let s = array(string()).nonempty(msg="数组不能为空")
  guard s.parse(parse_json("[]")) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors[0].message, "数组不能为空")
}
