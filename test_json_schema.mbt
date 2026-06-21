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

///|
/// Phase 26 — to_json_schema_named
test "to_json_schema_named: named schema has $defs" {
  let s = object({ "name": string() }).name("User")
  let result = to_json_schema_named(s)
  // Root should use $ref
  match result {
    Object(m) => {
      @debug.assert_eq(m.get("$ref"), Some(Json::string("#/$defs/User")))
      @debug.assert_eq(m.contains("$defs"), true)
    }
    _ => @debug.assert_eq(true, false)
  }
}

///|
test "to_json_schema_named: $defs contains named schema" {
  let s = object({ "name": string() }).name("User")
  let result = to_json_schema_named(s)
  match result {
    Object(m) =>
      match m.get("$defs") {
        Some(Object(defs)) =>
          match defs.get("User") {
            Some(Object(user_def)) =>
              match user_def.get("type") {
                Some(String(t)) => @debug.assert_eq(t, "object")
                _ => @debug.assert_eq(true, false)
              }
            _ => @debug.assert_eq(true, false)
          }
        _ => @debug.assert_eq(true, false)
      }
    _ => @debug.assert_eq(true, false)
  }
}

///|
test "to_json_schema_named: named field uses $ref" {
  let address = object({ "street": string() }).name("Address")
  let user = object({ "name": string(), "address": address })
  let result = to_json_schema_named(user)
  match result {
    Object(m) =>
      match m.get("$defs") {
        Some(Object(defs)) => @debug.assert_eq(defs.contains("Address"), true)
        _ => @debug.assert_eq(true, false)
      }
    _ => @debug.assert_eq(true, false)
  }
  // The root user schema should reference Address via $ref in properties
  match result {
    Object(m) => {
      // Root is unnamed, should be inline
      @debug.assert_eq(m.contains("type"), true)
      match m.get("properties") {
        Some(Object(props)) =>
          match props.get("address") {
            Some(Object(addr_obj)) =>
              match addr_obj.get("$ref") {
                Some(String(ref_str)) =>
                  @debug.assert_eq(ref_str, "#/$defs/Address")
                _ => @debug.assert_eq(true, false)
              }
            _ => @debug.assert_eq(true, false)
          }
        _ => @debug.assert_eq(true, false)
      }
    }
    _ => @debug.assert_eq(true, false)
  }
}

///|
test "to_json_schema_named: array of named schemas" {
  let item = object({ "id": string() }).name("Item")
  let list = object({ "items": array(item) }).name("ItemList")
  let result = to_json_schema_named(list)
  match result {
    Object(m) => {
      @debug.assert_eq(m.contains("$defs"), true)
      match m.get("$defs") {
        Some(Object(defs)) => {
          @debug.assert_eq(defs.contains("Item"), true)
          @debug.assert_eq(defs.contains("ItemList"), true)
        }
        _ => @debug.assert_eq(true, false)
      }
    }
    _ => @debug.assert_eq(true, false)
  }
}

///|
test "to_json_schema_named: enum named schema" {
  let mood = enum_values(["happy", "sad"]).name("Mood")
  let s = object({ "mood": mood })
  let result = to_json_schema_named(s)
  match result {
    Object(m) =>
      match m.get("$defs") {
        Some(Object(defs)) =>
          match defs.get("Mood") {
            Some(Object(mood_def)) =>
              @debug.assert_eq(mood_def.contains("enum"), true)
            _ => @debug.assert_eq(true, false)
          }
        _ => @debug.assert_eq(true, false)
      }
    _ => @debug.assert_eq(true, false)
  }
}

///|
test "to_json_schema_named: optional named field" {
  let contact = object({ "email": string() }).name("Contact")
  let user = object({ "name": string(), "contact": contact.optional() }).name(
    "User",
  )
  let result = to_json_schema_named(user)
  match result {
    Object(m) => {
      @debug.assert_eq(m.contains("$defs"), true)
      match m.get("$defs") {
        Some(Object(defs)) => {
          @debug.assert_eq(defs.contains("Contact"), true)
          @debug.assert_eq(defs.contains("User"), true)
        }
        _ => @debug.assert_eq(true, false)
      }
    }
    _ => @debug.assert_eq(true, false)
  }
  // The optional field should NOT appear directly in User's required list
  match result {
    Object(m) =>
      match m.get("$defs") {
        Some(Object(defs)) =>
          match defs.get("User") {
            Some(Object(user_def)) =>
              match user_def.get("required") {
                Some(Array(required)) => @debug.assert_eq(required.length(), 1) // only "name"
                _ => @debug.assert_eq(true, false)
              }
            _ => @debug.assert_eq(true, false)
          }
        _ => @debug.assert_eq(true, false)
      }
    _ => @debug.assert_eq(true, false)
  }
}

///|
test "to_json_schema_named: no named schemas returns $defs with no entries" {
  let s = object({ "name": string() })
  let result = to_json_schema_named(s)
  match result {
    Object(m) => {
      @debug.assert_eq(m.contains("$defs"), true)
      match m.get("$defs") {
        Some(Object(defs)) => @debug.assert_eq(defs.length(), 0)
        _ => @debug.assert_eq(true, false)
      }
    }
    _ => @debug.assert_eq(true, false)
  }
}

///|
test "to_json_schema_named: topological sort ordering" {
  let address = object({ "street": string() }).name("Address")
  let person = object({ "address": address }).name("Person")
  let company = object({ "ceo": person }).name("Company")
  let result = to_json_schema_named(company)

  // Check $defs has all three entries
  match result {
    Object(m) =>
      match m.get("$defs") {
        Some(Object(defs)) => {
          @debug.assert_eq(defs.contains("Address"), true)
          @debug.assert_eq(defs.contains("Person"), true)
          @debug.assert_eq(defs.contains("Company"), true)
        }
        _ => @debug.assert_eq(true, false)
      }
    _ => @debug.assert_eq(true, false)
  }
}

///|
test "to_json_schema_named: named fields use $ref in $defs entries" {
  let address = object({ "street": string() }).name("Address")
  let person = object({ "address": address, "name": string() }).name("Person")
  let result = to_json_schema_named(person)

  // Person's definition in $defs should use $ref for address field
  match result {
    Object(m) =>
      match m.get("$defs") {
        Some(Object(defs)) =>
          match defs.get("Person") {
            Some(Object(person_def)) =>
              match person_def.get("properties") {
                Some(Object(props)) =>
                  match props.get("address") {
                    Some(Object(addr_ref)) =>
                      match addr_ref.get("$ref") {
                        Some(String(r)) =>
                          @debug.assert_eq(r, "#/$defs/Address")
                        _ => @debug.assert_eq(true, false)
                      }
                    _ => @debug.assert_eq(true, false)
                  }
                _ => @debug.assert_eq(true, false)
              }
            _ => @debug.assert_eq(true, false)
          }
        _ => @debug.assert_eq(true, false)
      }
    _ => @debug.assert_eq(true, false)
  }
}

///|
/// Phase 27 — json_schema_to_moon_zod
test "json_schema_to_moon_zod: basic string type" {
  let result = json_schema_to_moon_zod(parse_json("{\"type\":\"string\"}"))
  @debug.assert_eq(result, "@moon_zod.string()")
}

///|
test "json_schema_to_moon_zod: basic number type" {
  let result = json_schema_to_moon_zod(parse_json("{\"type\":\"number\"}"))
  @debug.assert_eq(result, "@moon_zod.number()")
}

///|
test "json_schema_to_moon_zod: integer type" {
  let result = json_schema_to_moon_zod(parse_json("{\"type\":\"integer\"}"))
  @debug.assert_eq(result, "@moon_zod.number().int()")
}

///|
test "json_schema_to_moon_zod: boolean type" {
  let result = json_schema_to_moon_zod(parse_json("{\"type\":\"boolean\"}"))
  @debug.assert_eq(result, "@moon_zod.boolean()")
}

///|
test "json_schema_to_moon_zod: null type" {
  let result = json_schema_to_moon_zod(parse_json("{\"type\":\"null\"}"))
  @debug.assert_eq(result, "@moon_zod.null()")
}

///|
test "json_schema_to_moon_zod: object with properties" {
  let input = parse_json(
    "{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"},\"age\":{\"type\":\"integer\"}},\"required\":[\"name\"]}",
  )
  let result = json_schema_to_moon_zod(input)
  @debug.assert_eq(result.contains("@moon_zod.object({"), true)
  @debug.assert_eq(result.contains("@moon_zod.string()"), true)
  @debug.assert_eq(result.contains("@moon_zod.number().int()"), true)
  @debug.assert_eq(result.contains(".optional()"), true) // age not in required
}

///|
test "json_schema_to_moon_zod: array type" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"type\":\"array\",\"items\":{\"type\":\"string\"}}"),
  )
  @debug.assert_eq(result, "@moon_zod.array(@moon_zod.string())")
}

///|
test "json_schema_to_moon_zod: enum type" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"type\":\"string\",\"enum\":[\"a\",\"b\",\"c\"]}"),
  )
  // enum should take priority over type
  @debug.assert_eq(result, "@moon_zod.enum_values([\"a\", \"b\", \"c\"])")
}

///|
test "json_schema_to_moon_zod: string with constraints" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"type\":\"string\",\"minLength\":3,\"maxLength\":100}"),
  )
  @debug.assert_eq(result, "@moon_zod.string().min(3).max(100)")
}

///|
test "json_schema_to_moon_zod: number with constraints" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"type\":\"number\",\"minimum\":0,\"maximum\":150}"),
  )
  @debug.assert_eq(result, "@moon_zod.number().min(0).max(150)")
}

///|
test "json_schema_to_moon_zod: email format" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"type\":\"string\",\"format\":\"email\"}"),
  )
  @debug.assert_eq(result, "@moon_zod.string().email()")
}

///|
test "json_schema_to_moon_zod: uri format" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"type\":\"string\",\"format\":\"uri\"}"),
  )
  @debug.assert_eq(result, "@moon_zod.string().url()")
}

///|
test "json_schema_to_moon_zod: anyOf type" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"anyOf\":[{\"type\":\"string\"},{\"type\":\"number\"}]}"),
  )
  @debug.assert_eq(
    result, "@moon_zod.union([@moon_zod.string(), @moon_zod.number()])",
  )
}

///|
test "json_schema_to_moon_zod: allOf type" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"allOf\":[{\"type\":\"string\"},{\"type\":\"number\"}]}"),
  )
  @debug.assert_eq(
    result, "@moon_zod.intersection([@moon_zod.string(), @moon_zod.number()])",
  )
}

///|
test "json_schema_to_moon_zod: $defs with $ref" {
  let input = parse_json(
    "{\"$defs\":{\"Address\":{\"type\":\"object\",\"properties\":{\"street\":{\"type\":\"string\"}},\"required\":[\"street\"]}},\"$ref\":\"#/$defs/Address\"}",
  )
  let result = json_schema_to_moon_zod(input)
  @debug.assert_eq(result.contains("let Address_schema ="), true)
  @debug.assert_eq(result.contains(".name(\"Address\")"), true)
  @debug.assert_eq(result.contains("Address_schema"), true)
}

///|
test "json_schema_to_moon_zod: object field with $ref" {
  let input = parse_json(
    "{\"$defs\":{\"Address\":{\"type\":\"object\",\"properties\":{\"street\":{\"type\":\"string\"}},\"required\":[\"street\"]}},\"type\":\"object\",\"properties\":{\"user\":{\"$ref\":\"#/$defs/Address\"}},\"required\":[\"user\"]}",
  )
  let result = json_schema_to_moon_zod(input)
  @debug.assert_eq(result.contains("let Address_schema ="), true)
  @debug.assert_eq(result.contains("\"user\": Address_schema"), true)
}

///|
test "json_schema_to_moon_zod: pattern constraint" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"type\":\"string\",\"pattern\":\"^[a-z]+$\"}"),
  )
  @debug.assert_eq(result, "@moon_zod.string().regex(\"^[a-z]+$\")")
}

///|
test "json_schema_to_moon_zod: array with minItems" {
  let result = json_schema_to_moon_zod(
    parse_json(
      "{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"minItems\":1}",
    ),
  )
  @debug.assert_eq(result, "@moon_zod.array(@moon_zod.string()).min(1)")
}

///|
test "json_schema_to_moon_zod: exclusive minimum (positive)" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"type\":\"number\",\"exclusiveMinimum\":0}"),
  )
  @debug.assert_eq(result, "@moon_zod.number().positive()")
}

///|
test "json_schema_to_moon_zod: exclusive maximum (negative)" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"type\":\"number\",\"exclusiveMaximum\":0}"),
  )
  @debug.assert_eq(result, "@moon_zod.number().negative()")
}

///|
test "json_schema_to_moon_zod: multipleOf constraint" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"type\":\"number\",\"multipleOf\":5}"),
  )
  @debug.assert_eq(result, "@moon_zod.number().multipleOf(5)")
}

///|
test "json_schema_to_moon_zod: nested object" {
  let input = parse_json(
    "{\"type\":\"object\",\"properties\":{\"user\":{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"}},\"required\":[\"name\"]}}}",
  )
  let result = json_schema_to_moon_zod(input)
  @debug.assert_eq(result.contains("@moon_zod.object({"), true)
  @debug.assert_eq(result.contains("\"user\": @moon_zod.object({"), true)
  @debug.assert_eq(result.contains("\"name\": @moon_zod.string()"), true)
}

///|
test "json_schema_to_moon_zod: empty object" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"type\":\"object\",\"properties\":{}}"),
  )
  @debug.assert_eq(result, "@moon_zod.object({})")
}

///|
test "json_schema_to_moon_zod: oneOf treated as union" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"oneOf\":[{\"type\":\"string\"},{\"type\":\"boolean\"}]}"),
  )
  @debug.assert_eq(
    result, "@moon_zod.union([@moon_zod.string(), @moon_zod.boolean()])",
  )
}

///|
test "json_schema_to_moon_zod: definitions alias for $defs" {
  let input = parse_json(
    "{\"definitions\":{\"Item\":{\"type\":\"string\"}},\"$ref\":\"#/definitions/Item\"}",
  )
  let result = json_schema_to_moon_zod(input)
  @debug.assert_eq(result.contains("let Item_schema ="), true)
  @debug.assert_eq(result.contains(".name(\"Item\")"), true)
}

///|
/// Phase 27 fix: default value produces correct Json constructor
test "json_schema_to_moon_zod: default string value" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"type\":\"string\",\"default\":\"hello\"}"),
  )
  // Must NOT contain nested .default()
  @debug.assert_eq(result.contains(".default(.default"), false)
  // Must use Json::string constructor
  @debug.assert_eq(result.contains("Json::string"), true)
  @debug.assert_eq(result.contains(".default(Json::string(\"hello\")"), true)
}

///|
test "json_schema_to_moon_zod: default number value" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"type\":\"number\",\"default\":42}"),
  )
  @debug.assert_eq(result.contains("Json::number"), true)
  @debug.assert_eq(result.contains(".default(Json::number(42))"), true)
}

///|
test "json_schema_to_moon_zod: default boolean value" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"type\":\"boolean\",\"default\":true}"),
  )
  @debug.assert_eq(result.contains("Json::true()"), true)
  @debug.assert_eq(result.contains(".default(Json::true())"), true)
}

///|
/// Phase 27 fix: $defs topological sort
test "json_schema_to_moon_zod: reverse $defs order" {
  // B depends on A, but defined before A in JSON
  let input = parse_json(
    "{\"$defs\":{\"B\":{\"type\":\"object\",\"properties\":{\"a\":{\"$ref\":\"#/$defs/A\"}},\"required\":[\"a\"]},\"A\":{\"type\":\"string\"}},\"$ref\":\"#/$defs/B\"}",
  )
  let result = json_schema_to_moon_zod(input)
  // Both defs should be present
  @debug.assert_eq(result.contains("let A_schema ="), true)
  @debug.assert_eq(result.contains("let B_schema ="), true)
  // A should appear before B (dependency first)
  let pos_a = result.find("let A_schema")
  let pos_b = result.find("let B_schema")
  match (pos_a, pos_b) {
    (Some(a), Some(b)) => @debug.assert_eq(a < b, true)
    _ => @debug.assert_eq(true, false)
  }
}

///|
/// Phase 27 fix: circular reference detection
test "json_schema_to_moon_zod: circular $defs reference" {
  // Node references itself
  let input = parse_json(
    "{\"$defs\":{\"Node\":{\"type\":\"object\",\"properties\":{\"child\":{\"$ref\":\"#/$defs/Node\"}},\"required\":[\"child\"]}},\"$ref\":\"#/$defs/Node\"}",
  )
  let result = json_schema_to_moon_zod(input)
  // Should include TODO comment for circular reference
  @debug.assert_eq(result.contains("TODO"), true)
  @debug.assert_eq(result.contains("circular"), true)
}

///|
test "json_schema_to_moon_zod: mutual circular $defs" {
  // A references B, B references A
  let input = parse_json(
    "{\"$defs\":{\"A\":{\"$ref\":\"#/$defs/B\"},\"B\":{\"$ref\":\"#/$defs/A\"}},\"$ref\":\"#/$defs/A\"}",
  )
  let result = json_schema_to_moon_zod(input)
  // Should include TODO comment for circular reference
  @debug.assert_eq(result.contains("TODO"), true)
  @debug.assert_eq(result.contains("circular"), true)
}
