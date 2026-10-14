///|
test "int and safe cover the safe integer range" {
  for value in [2147483648.0, -2147483649.0, 9007199254740991.0] {
    assert_true(number().int().parse(Json::number(value)) is Ok(_))
    assert_true(number().safe().parse(Json::number(value)) is Ok(_))
  }
  assert_true(number().int().parse(Json::number(9007199254740992.0)) is Err(_))
}

///|
test "base number rejects all nonfinite values" {
  for value in [0.0 / 0.0, 1.0 / 0.0, -1.0 / 0.0] {
    assert_true(number().parse(Json::number(value)) is Err(_))
  }
}

///|
test "multipleOf handles large quotients and decimal divisors" {
  assert_true(number().multipleOf(1).parse(Json::number(2147483648.0)) is Ok(_))
  assert_true(number().multipleOf(0.1).parse(Json::number(0.3)) is Ok(_))
  assert_true(number().multipleOf(0.1).parse(Json::number(0.31)) is Err(_))
  assert_true(number().multipleOf(1.0e-7).parse(Json::number(3.0e-7)) is Ok(_))
  assert_true(
    number().multipleOf(0.1).parse(Json::number(0.30000000000000004)) is Err(_),
  )
}

///|
test "numeric bounds accept doubles without truncation" {
  let schema = number().min(5.5).max(5.7)
  assert_true(schema.parse(Json::number(5.6)) is Ok(_))
  assert_true(schema.parse(Json::number(5.4)) is Err(_))
  assert_true(number().gt(5).parse(Json::number(5.5)) is Ok(_))
  assert_true(number().lt(10).parse(Json::number(9.5)) is Ok(_))
}

///|
test "inferred schema accepts its heterogeneous sample" {
  for
    input in [
      parse_json("[1,\"x\",true,null]"),
      parse_json("[]"),
      parse_json("2147483648"),
    ] {
    assert_true(json_infer_schema(input).parse(input) is Ok(_))
  }
}
