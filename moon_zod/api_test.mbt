///|
test "facade preserves schema identity across workspace modules" {
  let schema : @core.Schema = @moon_zod.json_schema_to_schema({
    "type": "object",
    "properties": { "name": { "type": "string", "minLength": 2 } },
    "required": ["name"],
  })
  assert_true(schema.parse({ "name": "Ada" }) is Ok(_))
  assert_true(schema.parse({ "name": "A" }) is Err(_))
  assert_eq(@moon_zod.to_json_schema(schema), @exporters.to_json_schema(schema))
  assert_eq(
    @moon_zod.json_schema_to_prompt({ "type": "string" }),
    @exporters.schema_to_prompt_named(
      @importers.json_schema_to_schema({ "type": "string" }),
    ),
  )
}

///|
test "facade factories and keyword wrapper remain usable" {
  let schema : @moon_zod.Schema = @moon_zod.object({
    "name": @moon_zod.string().min(2),
    "note": @moon_zod.union([@moon_zod.string(), @moon_zod.null()]),
  })
  assert_true(schema.parse({ "name": "Ada", "note": Json::null() }) is Ok(_))
  assert_true(schema.parse({ "name": "Ada", "note": 42 }) is Err(_))
}
