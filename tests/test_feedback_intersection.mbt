///|
test "output intersection recursively combines overlapping object fields" {
  let schema = intersection([
    object({ "n": object({ "a": string() }) }),
    object({ "n": object({ "b": number() }) }),
  ])
  let input = parse_json("{\"n\":{\"a\":\"x\",\"b\":1}}")
  guard schema.parse(input) is Ok(output) else { fail("valid intersection") }
  guard try_to_json_schema(schema, view=OutputView) is Ok(contract) else {
    fail("representable output")
  }
  assert_true(json_schema_to_schema(contract).parse(output) is Ok(_))
}

///|
test "output intersection recursively combines arrays of objects" {
  let schema = intersection([
    array(object({ "a": string() })),
    array(object({ "b": number() })),
  ])
  guard schema.parse(parse_json("[{\"a\":\"x\",\"b\":1}]")) is Ok(output) else {
    fail("valid intersection")
  }
  guard try_to_json_schema(schema, view=OutputView) is Ok(contract) else {
    fail("representable output")
  }
  assert_true(json_schema_to_schema(contract).parse(output) is Ok(_))
}

///|
test "ambiguous missing overlap fails checked output projection explicitly" {
  let schema = intersection([
    object({ "n": string().optional() }),
    object({ "n": number().default(Json::number(1.0)) }),
  ])
  assert_true(schema.parse(parse_json("{}")) is Ok(_))
  assert_true(try_to_json_schema(schema, view=OutputView) is Err(_))
}
