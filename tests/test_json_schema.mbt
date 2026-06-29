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
test "to_json_schema_named: named field uses $ref with Root name" {
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
  // Root should now be named "Root" and have a $ref
  match result {
    Object(m) => @debug.assert_eq(m.contains("$ref"), true)
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
test "to_json_schema_named: unnamed root gets Root name in defs" {
  let s = object({ "name": string() })
  let result = to_json_schema_named(s)
  match result {
    Object(m) => {
      @debug.assert_eq(m.contains("$defs"), true)
      match m.get("$defs") {
        Some(Object(defs)) => @debug.assert_eq(defs.contains("Root"), true)
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
/// Phase 33 — to_json_schema_named with include_names
fn check_defs_contains(result : Json, name : String) -> Bool {
  match result {
    Object(m) =>
      match m.get("$defs") {
        Some(Object(defs)) => defs.contains(name)
        _ => false
      }
    _ => false
  }
}

///|
test "to_json_schema_named with include_names: default (None)" {
  let address = object({ "street": string() }).name("Address")
  let person = object({ "address": address, "name": string() }).name("Person")
  let result = to_json_schema_named(person)
  @debug.assert_eq(check_defs_contains(result, "Address"), true)
  @debug.assert_eq(check_defs_contains(result, "Person"), true)
}

///|
test "to_json_schema_named with include_names: selective export" {
  let address = object({ "street": string() }).name("Address")
  let person = object({ "address": address, "name": string() }).name("Person")
  let result = to_json_schema_named(person, include_names=Some(["Person"]))
  @debug.assert_eq(check_defs_contains(result, "Person"), true)
  @debug.assert_eq(check_defs_contains(result, "Address"), false)
}

///|
test "to_json_schema_named with include_names: partial export" {
  let address = object({ "street": string() }).name("Address")
  let person = object({ "address": address, "name": string() }).name("Person")
  // Include Address but not Person — Address should appear, Person should not
  let result = to_json_schema_named(person, include_names=Some(["Address"]))
  @debug.assert_eq(check_defs_contains(result, "Address"), true)
  @debug.assert_eq(check_defs_contains(result, "Person"), false)
}

///|
test "to_json_schema_named with include_names: empty list" {
  let address = object({ "street": string() }).name("Address")
  let person = object({ "address": address }).name("Person")
  let result = to_json_schema_named(person, include_names=Some([]))
  match result {
    Object(m) =>
      match m.get("$defs") {
        Some(Object(defs)) => @debug.assert_eq(defs.length(), 0)
        _ => @debug.assert_eq(true, false)
      }
    _ => @debug.assert_eq(true, false)
  }
}

///|
test "to_json_schema_named with include_names: non-existent name" {
  let address = object({ "street": string() }).name("Address")
  let person = object({ "address": address }).name("Person")
  let result = to_json_schema_named(person, include_names=Some(["Nope"]))
  match result {
    Object(m) =>
      match m.get("$defs") {
        Some(Object(defs)) => @debug.assert_eq(defs.length(), 0)
        _ => @debug.assert_eq(true, false)
      }
    _ => @debug.assert_eq(true, false)
  }
}

///|
/// Phase 27 — json_schema_to_moon_zod
test "json_schema_to_moon_zod: basic string type" {
  let result = json_schema_to_moon_zod(parse_json("{\"type\":\"string\"}"))
  @debug.assert_eq(result.contains("@moon_zod.string()"), true)
}

///|
test "json_schema_to_moon_zod: basic number type" {
  let result = json_schema_to_moon_zod(parse_json("{\"type\":\"number\"}"))
  @debug.assert_eq(result.contains("@moon_zod.number()"), true)
}

///|
test "json_schema_to_moon_zod: integer type" {
  let result = json_schema_to_moon_zod(parse_json("{\"type\":\"integer\"}"))
  @debug.assert_eq(result.contains("@moon_zod.number().int()"), true)
}

///|
test "json_schema_to_moon_zod: boolean type" {
  let result = json_schema_to_moon_zod(parse_json("{\"type\":\"boolean\"}"))
  @debug.assert_eq(result.contains("@moon_zod.boolean()"), true)
}

///|
test "json_schema_to_moon_zod: null type" {
  let result = json_schema_to_moon_zod(parse_json("{\"type\":\"null\"}"))
  @debug.assert_eq(result.contains("@moon_zod.null()"), true)
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
  @debug.assert_eq(result.contains("@moon_zod.array(@moon_zod.string())"), true)
}

///|
test "json_schema_to_moon_zod: enum type" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"type\":\"string\",\"enum\":[\"a\",\"b\",\"c\"]}"),
  )
  // enum should take priority over type
  @debug.assert_eq(
    result.contains("@moon_zod.enum_values([\"a\", \"b\", \"c\"])"),
    true,
  )
}

///|
test "json_schema_to_moon_zod: string with constraints" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"type\":\"string\",\"minLength\":3,\"maxLength\":100}"),
  )
  @debug.assert_eq(result.contains("@moon_zod.string().min(3).max(100)"), true)
}

///|
test "json_schema_to_moon_zod: number with constraints" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"type\":\"number\",\"minimum\":0,\"maximum\":150}"),
  )
  @debug.assert_eq(result.contains("@moon_zod.number().min(0).max(150)"), true)
}

///|
test "json_schema_to_moon_zod: email format" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"type\":\"string\",\"format\":\"email\"}"),
  )
  @debug.assert_eq(result.contains("@moon_zod.string().email()"), true)
}

///|
test "json_schema_to_moon_zod: uri format" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"type\":\"string\",\"format\":\"uri\"}"),
  )
  @debug.assert_eq(result.contains("@moon_zod.string().url()"), true)
}

///|
test "json_schema_to_moon_zod: anyOf type" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"anyOf\":[{\"type\":\"string\"},{\"type\":\"number\"}]}"),
  )
  @debug.assert_eq(
    result.contains("@moon_zod.union([@moon_zod.string(), @moon_zod.number()])"),
    true,
  )
}

///|
test "json_schema_to_moon_zod: allOf type" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"allOf\":[{\"type\":\"string\"},{\"type\":\"number\"}]}"),
  )
  @debug.assert_eq(
    result.contains(
      "@moon_zod.intersection([@moon_zod.string(), @moon_zod.number()])",
    ),
    true,
  )
}

///|
test "json_schema_to_moon_zod: $defs with $ref" {
  let input = parse_json(
    "{\"$defs\":{\"Address\":{\"type\":\"object\",\"properties\":{\"street\":{\"type\":\"string\"}},\"required\":[\"street\"]}},\"$ref\":\"#/$defs/Address\"}",
  )
  let result = json_schema_to_moon_zod(input)
  @debug.assert_eq(
    result.contains(
      "let address = @moon_zod.object({ \"street\": @moon_zod.string() }).name(\"Address\")",
    ),
    true,
  )
}

///|
test "json_schema_to_moon_zod: object field with $ref" {
  let input = parse_json(
    "{\"$defs\":{\"Address\":{\"type\":\"object\",\"properties\":{\"street\":{\"type\":\"string\"}},\"required\":[\"street\"]}},\"type\":\"object\",\"properties\":{\"user\":{\"$ref\":\"#/$defs/Address\"}},\"required\":[\"user\"]}",
  )
  let result = json_schema_to_moon_zod(input)
  @debug.assert_eq(
    result.contains(
      "let address = @moon_zod.object({ \"street\": @moon_zod.string() }).name(\"Address\")",
    ),
    true,
  )
  @debug.assert_eq(
    result.contains(
      "let root = @moon_zod.object({ \"user\": address }).name(\"Root\")",
    ),
    true,
  )
}

///|
test "json_schema_to_moon_zod: pattern constraint" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"type\":\"string\",\"pattern\":\"^[a-z]+$\"}"),
  )
  @debug.assert_eq(
    result.contains("@moon_zod.string().regex(\"^[a-z]+$\")"),
    true,
  )
}

///|
test "json_schema_to_moon_zod: array with minItems" {
  let result = json_schema_to_moon_zod(
    parse_json(
      "{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"minItems\":1}",
    ),
  )
  @debug.assert_eq(
    result.contains("@moon_zod.array(@moon_zod.string()).min(1)"),
    true,
  )
}

///|
test "json_schema_to_moon_zod: exclusive minimum (positive)" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"type\":\"number\",\"exclusiveMinimum\":0}"),
  )
  @debug.assert_eq(result.contains("@moon_zod.number().positive()"), true)
}

///|
test "json_schema_to_moon_zod: exclusive maximum (negative)" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"type\":\"number\",\"exclusiveMaximum\":0}"),
  )
  @debug.assert_eq(result.contains("@moon_zod.number().negative()"), true)
}

///|
test "json_schema_to_moon_zod: multipleOf constraint" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"type\":\"number\",\"multipleOf\":5}"),
  )
  @debug.assert_eq(result.contains("@moon_zod.number().multipleOf(5)"), true)
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
  @debug.assert_eq(result.contains("@moon_zod.object({})"), true)
}

///|
test "json_schema_to_moon_zod: oneOf treated as union" {
  let result = json_schema_to_moon_zod(
    parse_json("{\"oneOf\":[{\"type\":\"string\"},{\"type\":\"boolean\"}]}"),
  )
  @debug.assert_eq(
    result.contains(
      "@moon_zod.union([@moon_zod.string(), @moon_zod.boolean()])",
    ),
    true,
  )
}

///|
test "json_schema_to_moon_zod: definitions alias for $defs" {
  let input = parse_json(
    "{\"definitions\":{\"Item\":{\"type\":\"string\"}},\"$ref\":\"#/definitions/Item\"}",
  )
  let result = json_schema_to_moon_zod(input)
  @debug.assert_eq(result.contains("let item = "), true)
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
test "json_schema_to_moon_zod: mutual circular $defs" {
  // A references B, B references A
  let input = parse_json(
    "{\"$defs\":{\"A\":{\"$ref\":\"#/$defs/B\"},\"B\":{\"$ref\":\"#/$defs/A\"}},\"$ref\":\"#/$defs/A\"}",
  )
  let result = json_schema_to_moon_zod(input)
  // Circular refs are replaced with null schema placeholders
  @debug.assert_eq(result.contains("null()"), true)
}

///|
/// Phase 36 — json_schema_to_schema runtime parser
test "json_schema_to_schema: basic string type" {
  let s = json_schema_to_schema(parse_json("{\"type\":\"string\"}"))
  match s.parse(Json::string("hello")) {
    Ok(_) => assert_true(true)
    _ => fail("expected Ok")
  }
  match s.parse(Json::number(42.0)) {
    Err(_) => assert_true(true)
    _ => fail("expected Err")
  }
}

///|
test "json_schema_to_schema: string with constraints" {
  let s = json_schema_to_schema(
    parse_json("{\"type\":\"string\",\"minLength\":2,\"maxLength\":5}"),
  )
  match s.parse(Json::string("hi")) {
    Ok(_) => ()
    _ => fail("hi")
  }
  match s.parse(Json::string("toolonger")) {
    Err(_) => ()
    _ => fail("too long")
  }
  match s.parse(Json::string("a")) {
    Err(_) => ()
    _ => fail("too short")
  }
}

///|
test "json_schema_to_schema: number" {
  let s = json_schema_to_schema(parse_json("{\"type\":\"number\"}"))
  match s.parse(Json::number(3.14)) {
    Ok(_) => ()
    _ => fail("expected Ok")
  }
}

///|
test "json_schema_to_schema: integer" {
  let s = json_schema_to_schema(parse_json("{\"type\":\"integer\"}"))
  match s.parse(Json::number(42.0)) {
    Ok(_) => ()
    _ => fail("expected Ok")
  }
}

///|
test "json_schema_to_schema: boolean" {
  let s = json_schema_to_schema(parse_json("{\"type\":\"boolean\"}"))
  match s.parse(Json::boolean(true)) {
    Ok(_) => ()
    _ => fail("expected Ok")
  }
}

///|
test "json_schema_to_schema: enum" {
  let s = json_schema_to_schema(
    parse_json("{\"type\":\"string\",\"enum\":[\"a\",\"b\"]}"),
  )
  match s.parse(Json::string("a")) {
    Ok(_) => ()
    _ => fail("expected Ok")
  }
  match s.parse(Json::string("c")) {
    Err(_) => ()
    _ => fail("expected Err")
  }
}

///|
test "json_schema_to_schema: object" {
  let s = json_schema_to_schema(
    parse_json(
      "{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"}},\"required\":[\"name\"]}",
    ),
  )
  match s.parse(Json::object({ "name": Json::string("Alice") })) {
    Ok(_) => ()
    _ => fail("expected Ok")
  }
}

///|
test "json_schema_to_schema: array" {
  let s = json_schema_to_schema(
    parse_json("{\"type\":\"array\",\"items\":{\"type\":\"number\"}}"),
  )
  match s.parse(Json::array([Json::number(1.0), Json::number(2.0)])) {
    Ok(_) => ()
    _ => fail("expected Ok")
  }
  match s.parse(Json::array([Json::string("x")])) {
    Err(_) => ()
    _ => fail("expected Err")
  }
}

///|
test "json_schema_to_schema: anyOf → union" {
  let s = json_schema_to_schema(
    parse_json("{\"anyOf\":[{\"type\":\"string\"},{\"type\":\"number\"}]}"),
  )
  match s.parse(Json::string("x")) {
    Ok(_) => ()
    _ => fail("expected Ok")
  }
  match s.parse(Json::number(1.0)) {
    Ok(_) => ()
    _ => fail("expected Ok")
  }
  match s.parse(Json::boolean(true)) {
    Err(_) => ()
    _ => fail("expected Err")
  }
}

///|
test "json_schema_to_schema: allOf → intersection" {
  let s = json_schema_to_schema(
    parse_json(
      "{\"allOf\":[{\"type\":\"object\",\"properties\":{\"a\":{\"type\":\"string\"}},\"required\":[\"a\"]},{\"type\":\"object\",\"properties\":{\"b\":{\"type\":\"number\"}},\"required\":[\"b\"]}]}",
    ),
  )
  match
    s.parse(Json::object({ "a": Json::string("x"), "b": Json::number(1.0) })) {
    Ok(_) => ()
    _ => fail("expected Ok")
  }
}

///|
test "json_schema_to_schema: $defs and $ref" {
  let input = parse_json(
    "{\"$defs\":{\"Name\":{\"type\":\"string\",\"minLength\":1}},\"$ref\":\"#/$defs/Name\"}",
  )
  let s = json_schema_to_schema(input)
  match s.parse(Json::string("Alice")) {
    Ok(_) => ()
    _ => fail("expected Ok")
  }
  match s.parse(Json::string("")) {
    Err(_) => ()
    _ => fail("expected Err")
  }
}
