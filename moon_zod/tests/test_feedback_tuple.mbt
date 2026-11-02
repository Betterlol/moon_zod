///|
test "tuple rejects an unrepresentable interior missing position" {
  let schema = @core.tuple([
    @core.string().optional(),
    @core.number().default(Json::number(1.0)),
  ])
  guard schema.parse(Json::array([])) is Err(errors) else {
    fail("must not invent null")
  }
  @debug.assert_eq(errors[0].path, "[0]")
  assert_true(errors[0].code is Custom)
  guard schema.parse(@core.parse_json("[\"x\"]")) is Ok(output) else {
    fail("present first item")
  }
  @debug.assert_eq(output, @core.parse_json("[\"x\",1]"))
  assert_true(schema.parse(output) is Ok(_))
}

///|
test "tuple distinguishes trailing absence from present null" {
  assert_true(
    @core.tuple([
      @core.number().default(Json::number(1.0)),
      @core.string().optional(),
    ]).parse(Json::array([]))
    is Ok(Array(items)) &&
    items.length() == 1,
  )
  let schema = @core.tuple([
    @core.string().nullish(),
    @core.number().default(Json::number(1.0)),
  ])
  assert_true(schema.parse(Json::array([])) is Err(_))
  guard schema.parse(@core.parse_json("[null]")) is Ok(output) else {
    fail("explicit null is allowed")
  }
  @debug.assert_eq(output, @core.parse_json("[null,1]"))
}
