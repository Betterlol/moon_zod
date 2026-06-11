///|
/// Phase 4 — to_json_schema
test "to_json_schema string" {
  let result = to_json_schema(string())
  let expected = parse_json("{\"type\": \"string\"}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema object with optional field" {
  let s = object({ "name": string(), "email": string().optional() })
  let result = to_json_schema(s)
  let expected = parse_json(
    "{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"},\"email\":{\"type\":\"string\"}},\"additionalProperties\":true,\"required\":[\"name\"]}",
  )
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema strict object" {
  let s = object({ "x": number() }).strict()
  let result = to_json_schema(s)
  let expected = parse_json(
    "{\"type\":\"object\",\"properties\":{\"x\":{\"type\":\"number\"}},\"additionalProperties\":false,\"required\":[\"x\"]}",
  )
  @debug.assert_eq(result, expected)
}

///|
/// Phase 13 (v0.2.0) — to_json_schema full constraint export
test "to_json_schema string with constraints" {
  let s = string().min(3).max(100)
  let result = to_json_schema(s)
  let expected = parse_json(
    "{\"type\":\"string\",\"minLength\":3,\"maxLength\":100}",
  )
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema skeleton omits constraints" {
  let s = string().min(3).max(100)
  let result = to_json_schema_skeleton(s)
  let expected = parse_json("{\"type\": \"string\"}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema number with int and positive" {
  let s = number().int().positive()
  let result = to_json_schema(s)
  let expected = parse_json("{\"type\":\"integer\",\"exclusiveMinimum\":0}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema number with multipleOf" {
  let s = number().multipleOf(5)
  let result = to_json_schema(s)
  let expected = parse_json("{\"type\":\"number\",\"multipleOf\":5}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema string with email format" {
  let s = string().email()
  let result = to_json_schema(s)
  let expected = parse_json("{\"type\":\"string\",\"format\":\"email\"}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema string with url format" {
  let s = string().url()
  let result = to_json_schema(s)
  let expected = parse_json("{\"type\":\"string\",\"format\":\"uri\"}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema nested object with constraints" {
  let s = object({
    "name": string().min(2).max(50),
    "age": number().int().min(0).max(150),
    "email": string().email().optional(),
  })
  let result = to_json_schema(s)
  let expected = parse_json(
    "{\"type\":\"object\",\"properties\":{\"name\":{\"minLength\":2,\"maxLength\":50,\"type\":\"string\"},\"age\":{\"minimum\":0,\"maximum\":150,\"type\":\"integer\"},\"email\":{\"type\":\"string\",\"format\":\"email\"}},\"additionalProperties\":true,\"required\":[\"name\",\"age\"]}",
  )
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema constraints penetrate optional" {
  let s = string().min(3).optional()
  let result = to_json_schema(s)
  // optional() should be transparent — constraints on the inner type
  // are exported as normal string constraints
  let expected = parse_json("{\"minLength\":3,\"type\":\"string\"}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema constraints penetrate transform" {
  let s = string().min(3).transform(fn(j) { Ok(j) })
  let result = to_json_schema(s)
  // transform() should be transparent — constraints on the inner type
  // are exported as normal string constraints
  let expected = parse_json("{\"minLength\":3,\"type\":\"string\"}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema ignores transform wrapper" {
  let s = string().transform(fn(json) { Ok(json) })
  let result = to_json_schema(s)
  let expected = parse_json("{\"type\": \"string\"}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema boolean type" {
  let result = to_json_schema(boolean())
  let expected = parse_json("{\"type\": \"boolean\"}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema null type" {
  let result = to_json_schema(null())
  let expected = parse_json("{\"type\": \"null\"}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema array type" {
  let result = to_json_schema(array(string()))
  let expected = parse_json(
    "{\"type\":\"array\",\"items\":{\"type\":\"string\"}}",
  )
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema enum type" {
  let result = to_json_schema(enum_values(["a", "b"]))
  let expected = parse_json("{\"type\":\"string\",\"enum\":[\"a\",\"b\"]}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema union type" {
  let result = to_json_schema(union([string(), number()]))
  let expected = parse_json(
    "{\"anyOf\":[{\"type\":\"string\"},{\"type\":\"number\"}]}",
  )
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema default type" {
  let result = to_json_schema(string().default(Json::string("x")))
  let expected = parse_json("{\"type\":\"string\",\"default\":\"x\"}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema skeleton boolean" {
  let result = to_json_schema_skeleton(boolean())
  let expected = parse_json("{\"type\": \"boolean\"}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema skeleton null" {
  let result = to_json_schema_skeleton(null())
  let expected = parse_json("{\"type\": \"null\"}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema skeleton array" {
  let result = to_json_schema_skeleton(array(string()))
  let expected = parse_json(
    "{\"type\":\"array\",\"items\":{\"type\":\"string\"}}",
  )
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema skeleton enum" {
  let result = to_json_schema_skeleton(enum_values(["x"]))
  let expected = parse_json("{\"type\":\"string\",\"enum\":[\"x\"]}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema skeleton union" {
  let result = to_json_schema_skeleton(union([string(), boolean()]))
  let expected = parse_json(
    "{\"anyOf\":[{\"type\":\"string\"},{\"type\":\"boolean\"}]}",
  )
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema skeleton optional" {
  let result = to_json_schema_skeleton(string().optional())
  let expected = parse_json("{\"type\": \"string\"}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema skeleton default" {
  let result = to_json_schema_skeleton(string().default(Json::string("x")))
  let expected = parse_json("{\"type\":\"string\",\"default\":\"x\"}")
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema intersection" {
  let result = to_json_schema(intersection([string(), number()]))
  let expected = parse_json(
    "{\"allOf\":[{\"type\":\"string\"},{\"type\":\"number\"}]}",
  )
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema skeleton intersection" {
  let result = to_json_schema_skeleton(intersection([string(), boolean()]))
  let expected = parse_json(
    "{\"allOf\":[{\"type\":\"string\"},{\"type\":\"boolean\"}]}",
  )
  @debug.assert_eq(result, expected)
}

///|
test "to_json_schema merge_annotations with refine rule" {
  let s = number().refine(
    fn(json) {
      match json {
        Number(v, ..) => v > 0.0
        _ => false
      }
    },
    "Must be positive",
  )
  let result = to_json_schema(s)
  // refine has Null annotation, so to_json_schema just outputs the number schema
  let expected = parse_json("{\"type\": \"number\"}")
  @debug.assert_eq(result, expected)
}
