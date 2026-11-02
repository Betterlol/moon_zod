///|
test "tuple rejects an unrepresentable interior missing position" {
  let schema = tuple([string().optional(), number().default(Json::number(1.0))])
  guard schema.parse(Json::array([])) is Err(errors) else {
    fail("must not invent null")
  }
  @debug.assert_eq(errors[0].path, "[0]")
  assert_true(errors[0].code is Custom)
  guard schema.parse(parse_json("[\"x\"]")) is Ok(output) else {
    fail("present first item")
  }
  @debug.assert_eq(output, parse_json("[\"x\",1]"))
  assert_true(schema.parse(output) is Ok(_))
}

///|
test "tuple distinguishes trailing absence from present null" {
  assert_true(
    tuple([number().default(Json::number(1.0)), string().optional()]).parse(
      Json::array([]),
    )
    is Ok(Array(items)) &&
    items.length() == 1,
  )
  let schema = tuple([string().nullish(), number().default(Json::number(1.0))])
  assert_true(schema.parse(Json::array([])) is Err(_))
  guard schema.parse(parse_json("[null]")) is Ok(output) else {
    fail("explicit null is allowed")
  }
  @debug.assert_eq(output, parse_json("[null,1]"))
}
