///|
test "schema_to_moon_zod_code unnamed string schema" {
  let schema = string()
  let code = schema_to_moon_zod_code(schema)
  assert_eq(code, "@moon_zod.string()")
}

///|
test "schema_to_moon_zod_code named string schema" {
  let schema = string().name("MyString")
  let code = schema_to_moon_zod_code(schema)
  assert_eq(code, "@moon_zod.string().named('MyString')")
}
