///|
test "schema_to_moon_zod_code unnamed string schema" {
  let schema = string()
  let code = schema_to_moon_zod_code(schema)
  assert_eq(code.contains("@moon_zod.string()"), true)
}

///|
test "schema_to_moon_zod_code string with constraints" {
  let schema = string().min(2).max(50).describe("username")
  let code = schema_to_moon_zod_code(schema)
  assert_eq(
    code.contains("@moon_zod.string().min(2).max(50).describe(\"username\")"),
    true,
  )
}

///|
test "schema_to_moon_zod_code object with mode" {
  let schema = object({
    "name": string().min(1),
    "age": number().int().positive(),
  }).strict()
  let code = schema_to_moon_zod_code(schema)
  // Should include .strict() for Strict mode
  @debug.assert_eq(code.contains(".strict()"), true)
}

///|
test "schema_to_moon_zod_code with description" {
  let schema = string().describe("用户名")
  let code = schema_to_moon_zod_code(schema)
  assert_eq(code.contains("@moon_zod.string().describe(\"用户名\")"), true)
}

///|
test "schema_to_moon_zod_code with object passthrough mode" {
  let schema = object({ "name": string() }).passthrough()
  let code = schema_to_moon_zod_code(schema)
  @debug.assert_eq(code.contains(".passthrough()"), true)
}

///|
test "schema_to_moon_zod_code with strip mode (default)" {
  let schema = object({ "name": string() }).strip()
  let code = schema_to_moon_zod_code(schema)
  // strip is default, so should not include .strip()
  @debug.assert_eq(!code.contains(".strip()"), true)
}

///|
test "schema_to_moon_zod_code_named with include_names" {
  let schema = object({
    "user": object({ "name": string(), "age": number() }).name("User"),
    "admin": object({ "name": string(), "age": number() }).name("Admin"),
  })
  let code = schema_to_moon_zod_code_named(schema, include_names=Some(["User"]))
  // Should include definition for User but not Admin
  @debug.assert_eq(code.contains("let user = "), true)
  @debug.assert_eq(
    code.contains(
      "@moon_zod.object({ \"name\": @moon_zod.string(), \"age\": @moon_zod.number() }).name(\"User\")",
    ),
    true,
  )
  @debug.assert_eq(code.contains("let admin = "), false)
}

///|
test "schema_to_moon_zod_code_named for named root" {
  let schema = object({
    "user": object({ "name": string(), "age": number() }).name("User"),
    "admin": object({ "name": string(), "age": number() }).name("Admin"),
  }).name("Group")
  let code = schema_to_moon_zod_code_named(schema)
  @debug.assert_eq(code.contains("let user = "), true)
  @debug.assert_eq(code.contains("let admin = "), true)
  @debug.assert_eq(
    code.contains(
      "let group = @moon_zod.object({ \"user\": user, \"admin\": admin }).name(\"Group\")",
    ),
    true,
  )
}

///|
test "schema_to_moon_zod_code_named for unnamed root" {
  let schema = object({
    "user": object({ "name": string(), "age": number() }).name("User"),
    "admin": object({ "name": string(), "age": number() }).name("Admin"),
  })
  let code = schema_to_moon_zod_code_named(schema)
  @debug.assert_eq(code.contains("let user = "), true)
  @debug.assert_eq(code.contains("let admin = "), true)
  @debug.assert_eq(
    code.contains(
      "let root = @moon_zod.object({ \"user\": user, \"admin\": admin })",
    ),
    true,
  )
}
