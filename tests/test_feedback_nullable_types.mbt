///|
test "nullable array elements retain recursive MoonBit option types" {
  let schema = object({ "items": array(string().nullable()) }).name("Row")
  let code = schema_to_moonbit_struct(schema)
  assert_true(code.contains("items : Array[@moon_zod.JsonNullable[String]]"))
}

///|
test "nested nullable and missing field types get one option marker" {
  let schema = object({
    "items": array(array(string().nullable()).nullable()).nullable(),
    "note": string().nullish(),
    "value": string().default(Json::string("x")).optional(),
    "pair": array(tuple([string(), number()])),
  }).name("NestedRow")
  let code = schema_to_moonbit_struct(schema)
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
