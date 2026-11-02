///|
test "nullable array elements retain recursive MoonBit option types" {
  let schema = @core.object({ "items": @core.array(@core.string().nullable()) }).name(
    "Row",
  )
  let code = @exporters.schema_to_moonbit_struct(schema)
  assert_true(code.contains("items : Array[@moon_zod.JsonNullable[String]]"))
}

///|
test "nested nullable and missing field types get one option marker" {
  let schema = @core.object({
    "items": @core.array(@core.array(@core.string().nullable()).nullable()).nullable(),
    "note": @core.string().nullish(),
    "value": @core.string().default(Json::string("x")).optional(),
    "pair": @core.array(@core.tuple([@core.string(), @core.number()])),
  }).name("NestedRow")
  let code = @exporters.schema_to_moonbit_struct(schema)
  assert_true(
    code.contains(
      "items : @moon_zod.JsonNullable[Array[@moon_zod.JsonNullable[Array[@moon_zod.JsonNullable[String]]]]]",
    ),
  )
  assert_true(code.contains("note : @moon_zod.JsonNullable[String]?"))
  assert_true(!code.contains("String??"))
  assert_true(!code.contains("value : String?"))
  assert_true(code.contains("pair : Array[Json]"))
}
