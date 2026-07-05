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

///|
test "json_infer_schema validates inferred object shape" {
  let schema = json_infer_schema(
    parse_json(
      "{\"name\": \"Alice\", \"age\": 30, \"tags\": [\"a\"], \"active\": true}",
    ),
  )

  guard schema.parse(
      parse_json(
        "{\"name\": \"Bob\", \"age\": 42, \"tags\": [\"b\"], \"active\": false}",
      ),
    )
    is Ok(_) else {
    fail("expected inferred schema to accept matching object")
  }
  guard schema.parse(
      parse_json(
        "{\"name\": \"Bob\", \"age\": 42.5, \"tags\": [\"b\"], \"active\": false}",
      ),
    )
    is Err(_) else {
    fail("expected inferred int field to reject float")
  }
}

///|
test "json_infer_schema handles empty arrays as string arrays" {
  let schema = json_infer_schema(parse_json("[]"))

  guard schema.parse(parse_json("[\"x\"]")) is Ok(_) else {
    fail("expected inferred empty array to accept strings")
  }
  guard schema.parse(parse_json("[1]")) is Err(_) else {
    fail("expected inferred empty array to reject numbers")
  }
}

///|
test "moon_zod code escaping helpers cover special identifiers" {
  @debug.assert_eq(escape_mbt_string("a\\b\n\t\"c"), "a\\\\b\\n\\t\\\"c")
  @debug.assert_eq(escape_ident("9 bad-name"), "_9_bad_name")
  @debug.assert_eq(escape_variable_name("UserName"), "userName")
  @debug.assert_eq(escape_variable_name("!!!"), "___")
}

///|
test "schema_to_moon_zod_code covers formats and literal values" {
  let formatted = schema_to_moon_zod_code(
    object({
      "time": string().datetime(),
      "ip4": string().ipv4(),
      "ip6": string().ipv6(),
      "id": string().uuid(),
      "tags": array(string()).max(3),
    }),
  )
  @debug.assert_eq(formatted.contains(".datetime()"), true)
  @debug.assert_eq(formatted.contains(".ipv4()"), true)
  @debug.assert_eq(formatted.contains(".ipv6()"), true)
  @debug.assert_eq(formatted.contains(".uuid()"), true)
  @debug.assert_eq(formatted.contains(".max(3)"), true)

  let literal_code = schema_to_moon_zod_code(
    literal(
      Json::object({
        "flag": Json::boolean(false),
        "items": Json::array([Json::number(1), Json::null()]),
      }),
    ),
  )
  @debug.assert_eq(literal_code.contains("Json::false()"), true)
  @debug.assert_eq(literal_code.contains("Json::array"), true)
  @debug.assert_eq(literal_code.contains("Json::object"), true)
}
