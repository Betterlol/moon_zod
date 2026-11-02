///|
test "output intersection recursively combines overlapping object fields" {
  let schema = @core.intersection([
    @core.object({ "n": @core.object({ "a": @core.string() }) }),
    @core.object({ "n": @core.object({ "b": @core.number() }) }),
  ])
  let input = @core.parse_json("{\"n\":{\"a\":\"x\",\"b\":1}}")
  guard schema.parse(input) is Ok(output) else { fail("valid intersection") }
  guard @exporters.try_to_json_schema(schema, view=OutputView) is Ok(contract) else {
    fail("representable output")
  }
  assert_true(@importers.json_schema_to_schema(contract).parse(output) is Ok(_))
}

///|
test "output intersection recursively combines arrays of objects" {
  let schema = @core.intersection([
    @core.array(@core.object({ "a": @core.string() })),
    @core.array(@core.object({ "b": @core.number() })),
  ])
  guard schema.parse(@core.parse_json("[{\"a\":\"x\",\"b\":1}]")) is Ok(output) else {
    fail("valid intersection")
  }
  guard @exporters.try_to_json_schema(schema, view=OutputView) is Ok(contract) else {
    fail("representable output")
  }
  assert_true(@importers.json_schema_to_schema(contract).parse(output) is Ok(_))
}

///|
test "ambiguous missing overlap fails checked output projection explicitly" {
  let schema = @core.intersection([
    @core.object({ "n": @core.string().optional() }),
    @core.object({ "n": @core.number().default(Json::number(1.0)) }),
  ])
  assert_true(schema.parse(@core.parse_json("{}")) is Ok(_))
  assert_true(@exporters.try_to_json_schema(schema, view=OutputView) is Err(_))
}
