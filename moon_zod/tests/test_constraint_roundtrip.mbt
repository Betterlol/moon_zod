///|
test "JSON Schema keeps strongest repeated bound" {
  @debug.assert_eq(
    @exporters.to_json_schema(@core.string().min(5).min(2)),
    @core.parse_json("{\"type\":\"string\",\"minLength\":5}"),
  )
}

///|
test "prefix annotations escape regex syntax" {
  let schema = @core.string().startsWith("a.b")
  let imported = @importers.json_schema_to_schema(
    @exporters.to_json_schema(schema),
  )
  assert_true(imported.parse(Json::string("axb")) is Err(_))
  assert_true(imported.parse(Json::string("a.bx")) is Ok(_))
}

///|
test "exact length survives JSON Schema export" {
  let imported = @importers.json_schema_to_schema(
    @exporters.to_json_schema(@core.string().length(3)),
  )
  assert_true(imported.parse(Json::string("ab")) is Err(_))
  assert_true(imported.parse(Json::string("abc")) is Ok(_))
}

///|
test "source export preserves builtin transforms and exclusive bounds" {
  let code = @exporters.schema_to_moon_zod_code(
    @core.string().trim().to_lower().min(3),
  )
  assert_true(code.contains(".trim().to_lower().min(3)"))
  assert_true(
    @exporters.schema_to_moon_zod_code(@core.number().gt(5.5)).contains(
      ".gt(5.5)",
    ),
  )
}
