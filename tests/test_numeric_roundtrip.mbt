///|
test "JSON Schema numeric boundaries retain fractional values" {
  let schema = json_schema_to_schema(
    parse_json("{\"type\":\"number\",\"minimum\":5.5,\"maximum\":5.7}"),
  )
  assert_true(schema.parse(Json::number(5.6)) is Ok(_))
  assert_true(schema.parse(Json::number(5.4)) is Err(_))
}

///|
test "JSON Schema integer exclusive boundaries still admit fractional inputs" {
  let schema = json_schema_to_schema(
    parse_json(
      "{\"type\":\"number\",\"exclusiveMinimum\":5,\"exclusiveMaximum\":10}",
    ),
  )
  assert_true(schema.parse(Json::number(5.5)) is Ok(_))
  assert_true(schema.parse(Json::number(9.5)) is Ok(_))
  assert_true(schema.parse(Json::number(5.0)) is Err(_))
  assert_true(schema.parse(Json::number(10.0)) is Err(_))
}

///|
test "JSON Schema decimal multipleOf survives import" {
  let schema = json_schema_to_schema(
    parse_json("{\"type\":\"number\",\"multipleOf\":0.1}"),
  )
  assert_true(schema.parse(Json::number(0.3)) is Ok(_))
  assert_true(schema.parse(Json::number(0.31)) is Err(_))
}
