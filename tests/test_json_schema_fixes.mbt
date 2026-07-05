///|
/// Tests for JSON Schema importer fixes
///
/// Verifies fixes for:
/// 1. exclusiveMinimum/Maximum semantic errors
/// 2. enum non-string values
/// 3. Basic functionality tests

///|
/// Test exclusiveMinimum with integer boundary
test "exclusive_minimum_integer accepts values > 5" {
  let json_schema = parse_json(
    "{\"type\": \"number\", \"exclusiveMinimum\": 5}",
  )
  let schema = json_schema_to_schema(json_schema)

  // Should accept 6 (> 5)
  match schema.parse(parse_json("6")) {
    Ok(_) => ()
    Err(_e) => fail("expected Ok for 6")
  }

  // Should reject 5 (not > 5)
  guard schema.parse(parse_json("5")) is Err(_) else {
    fail("exclusiveMinimum: should reject 5")
  }
}

///|
/// Test exclusiveMinimum with floating point
test "exclusive_minimum_float validates correctly" {
  let json_schema = parse_json(
    "{\"type\": \"number\", \"exclusiveMinimum\": 5.5}",
  )
  let schema = json_schema_to_schema(json_schema)

  // Should accept 5.6 (> 5.5)
  match schema.parse(parse_json("5.6")) {
    Ok(_) => ()
    Err(_e) => fail("expected Ok for 5.6")
  }

  // Should reject 5.5 (not > 5.5)
  guard schema.parse(parse_json("5.5")) is Err(_) else {
    fail("exclusiveMinimum: should reject 5.5")
  }

  // Should reject 5.4 (< 5.5)
  guard schema.parse(parse_json("5.4")) is Err(_) else {
    fail("exclusiveMinimum: should reject 5.4")
  }
}

///|
/// Test exclusiveMaximum with integer boundary
test "exclusive_maximum_integer rejects values >= 10" {
  let json_schema = parse_json(
    "{\"type\": \"number\", \"exclusiveMaximum\": 10}",
  )
  let schema = json_schema_to_schema(json_schema)

  // Should accept 9 (< 10)
  match schema.parse(parse_json("9")) {
    Ok(_) => ()
    Err(_e) => fail("expected Ok for 9")
  }

  // Should reject 10 (not < 10)
  guard schema.parse(parse_json("10")) is Err(_) else {
    fail("exclusiveMaximum: should reject 10")
  }
}

///|
/// Test enum with string values
test "enum_with_strings works correctly" {
  let json_schema = parse_json("{\"enum\": [\"red\", \"green\", \"blue\"]}")
  let schema = json_schema_to_schema(json_schema)

  // Should accept valid enum value
  match schema.parse(parse_json("\"red\"")) {
    Ok(_) => ()
    Err(_e) => fail("expected Ok for enum value")
  }

  // Should reject value not in enum
  guard schema.parse(parse_json("\"yellow\"")) is Err(_) else {
    fail("enum: should reject value not in list")
  }
}

///|
/// Test enum non-string value handling (numbers)
test "enum_with_numbers_converts_to_strings" {
  let json_schema = parse_json("{\"enum\": [1, 2, 3]}")
  let schema = json_schema_to_schema(json_schema)

  // The enum should accept the values (converted to strings internally)
  // but since our Schema internally uses strings, we validate numeric literals
  match schema.parse(parse_json("2")) {
    Ok(_) => ()
    Err(_e) => fail("expected Ok for numeric enum value")
  }
}

///|
/// Test json_schema_named with object schema
test "json_schema_named_object_type" {
  let schema = object({ "name": string().min(2), "age": number().int().min(0) }).name(
    "Person",
  )
  let json_result = to_json_schema_named(schema)

  match json_result {
    Object(m) => {
      // Should have a $ref at root since it's named
      match m.get("$ref") {
        Some(_) => ()
        None =>
          // Or it could have type directly
          match m.get("type") {
            Some(String("object")) => ()
            _ => fail("json_schema_named: missing $ref or type field")
          }
      }

      // Should have $defs
      match m.get("$defs") {
        Some(_) => ()
        None => fail("json_schema_named: missing '$defs'")
      }
    }
    _ => fail("json_schema_named: result is not an object")
  }
}

///|
/// Test roundtrip: JSON Schema → Schema → JSON Schema for string
test "json_schema_roundtrip_string" {
  let original = parse_json("{\"type\": \"string\", \"minLength\": 2}")
  let schema = json_schema_to_schema(original)
  let exported = to_json_schema(schema)

  // Should contain type field
  match exported {
    Object(m) =>
      match m.get("type") {
        Some(String(t)) =>
          if t == "string" {
            ()
          } else {
            fail("wrong type in roundtrip")
          }
        _ => fail("missing or invalid type in roundtrip")
      }
    _ => fail("exported schema is not an object")
  }
}

///|
/// Test exclusiveMaximum with floating point
test "exclusive_maximum_float validates correctly" {
  let json_schema = parse_json(
    "{\"type\": \"number\", \"exclusiveMaximum\": 9.5}",
  )
  let schema = json_schema_to_schema(json_schema)

  // Should accept 9.4 (< 9.5)
  match schema.parse(parse_json("9.4")) {
    Ok(_) => ()
    Err(_e) => fail("expected Ok for 9.4")
  }

  // Should reject 9.5 (not < 9.5)
  guard schema.parse(parse_json("9.5")) is Err(_) else {
    fail("exclusiveMaximum: should reject 9.5")
  }

  // Should reject 10 (> 9.5)
  guard schema.parse(parse_json("10")) is Err(_) else {
    fail("exclusiveMaximum: should reject 10")
  }
}

///|
/// Test number enum rejects values not in list
test "enum_with_numbers_rejects_invalid" {
  let json_schema = parse_json("{\"enum\": [1, 2, 3]}")
  let schema = json_schema_to_schema(json_schema)

  // Should accept 2 (in enum)
  match schema.parse(parse_json("2")) {
    Ok(_) => ()
    Err(_e) => fail("expected Ok for 2")
  }

  // Should reject 5 (not in enum)
  guard schema.parse(parse_json("5")) is Err(_) else {
    fail("enum: should reject 5")
  }

  // Should reject string (wrong type)
  guard schema.parse(parse_json("\"abc\"")) is Err(_) else {
    fail("enum: should reject string when enum is numeric")
  }
}

///|
/// Test mixed string+number enum: only strings are kept
test "enum_mixed_string_number" {
  let json_schema = parse_json("{\"enum\": [\"a\", \"b\", 1, 2]}")
  let schema = json_schema_to_schema(json_schema)

  // Should accept string "a" (in enum)
  match schema.parse(parse_json("\"a\"")) {
    Ok(_) => ()
    Err(_e) => fail("expected Ok for \"a\"")
  }

  // Should reject string "c" (not in enum)
  guard schema.parse(parse_json("\"c\"")) is Err(_) else {
    fail("enum: should reject \"c\"")
  }

  // Should reject number 1 (numbers dropped in mixed enum)
  guard schema.parse(parse_json("1")) is Err(_) else {
    fail("enum: should reject 1 when enum is mixed string+number")
  }
}

///|
/// Test boolean enum falls back to string (known limitation)
test "enum_boolean_falls_back_to_string" {
  let json_schema = parse_json("{\"enum\": [true, false]}")
  let schema = json_schema_to_schema(json_schema)

  // Current limitation: boolean enum falls back to string(),
  // so it accepts any string but rejects booleans
  guard schema.parse(parse_json("\"anything\"")) is Ok(_) else {
    fail("boolean enum fallback: should accept any string")
  }

  // Should reject boolean true (not a string)
  guard schema.parse(parse_json("true")) is Err(_) else {
    fail("boolean enum fallback: should reject true")
  }
}

///|
/// Test null enum falls back to string (known limitation)
test "enum_null_falls_back_to_string" {
  let json_schema = parse_json("{\"enum\": [null]}")
  let schema = json_schema_to_schema(json_schema)

  // Current limitation: null enum falls back to string()
  guard schema.parse(parse_json("\"any\"")) is Ok(_) else {
    fail("null enum fallback: should accept any string")
  }

  // Should reject null (not a string)
  guard schema.parse(parse_json("null")) is Err(_) else {
    fail("null enum fallback: should reject null")
  }
}

///|
test "json schema const imports literal schema" {
  let schema = json_schema_to_schema(parse_json("{\"const\": \"ready\"}"))
  guard schema.parse(Json::string("ready")) is Ok(_) else {
    fail("expected Ok")
  }
  guard schema.parse(Json::string("waiting")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "json schema imports string formats" {
  let datetime_schema = json_schema_to_schema(
    parse_json("{\"type\": \"string\", \"format\": \"date-time\"}"),
  )
  guard datetime_schema.parse(Json::string("2024-02-29T10:30:00Z")) is Ok(_) else {
    fail("expected valid datetime")
  }
  guard datetime_schema.parse(Json::string("2024-02-30T10:30:00Z")) is Err(_) else {
    fail("expected invalid datetime")
  }

  let ipv4_schema = json_schema_to_schema(
    parse_json("{\"type\": \"string\", \"format\": \"ipv4\"}"),
  )
  guard ipv4_schema.parse(Json::string("192.168.0.1")) is Ok(_) else {
    fail("expected valid ipv4")
  }
  guard ipv4_schema.parse(Json::string("999.168.0.1")) is Err(_) else {
    fail("expected invalid ipv4")
  }

  let uuid_schema = json_schema_to_schema(
    parse_json("{\"type\": \"string\", \"format\": \"uuid\"}"),
  )
  guard uuid_schema.parse(Json::string("550e8400-e29b-41d4-a716-446655440000"))
    is Ok(_) else {
    fail("expected valid uuid")
  }

  let ipv6_schema = json_schema_to_schema(
    parse_json("{\"type\": \"string\", \"format\": \"ipv6\"}"),
  )
  guard ipv6_schema.parse(
      Json::string("2001:0db8:85a3:0000:0000:8a2e:0370:7334"),
    )
    is Ok(_) else {
    fail("expected valid ipv6")
  }
}

///|
test "json schema imports array maxItems" {
  let schema = json_schema_to_schema(
    parse_json(
      "{\"type\": \"array\", \"items\": {\"type\": \"string\"}, \"maxItems\": 2}",
    ),
  )
  guard schema.parse(parse_json("[\"a\", \"b\"]")) is Ok(_) else {
    fail("expected Ok")
  }
  guard schema.parse(parse_json("[\"a\", \"b\", \"c\"]")) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "json schema fallback handles missing and unknown type" {
  let missing_items = json_schema_to_schema(parse_json("{\"type\": \"array\"}"))
  guard missing_items.parse(parse_json("[\"x\"]")) is Ok(_) else {
    fail("expected fallback string item")
  }
  guard missing_items.parse(parse_json("[1]")) is Err(_) else {
    fail("expected string item validation")
  }

  let unknown = json_schema_to_schema(parse_json("{\"type\": \"made-up\"}"))
  guard unknown.parse(Json::string("x")) is Ok(_) else { fail("expected Ok") }
  guard unknown.parse(Json::number(1)) is Err(_) else { fail("expected Err") }
}

///|
test "json schema fallback handles malformed schema shapes" {
  let non_object = json_schema_to_schema(Json::string("not a schema"))
  guard non_object.parse(Json::string("x")) is Ok(_) else {
    fail("expected Ok")
  }
  guard non_object.parse(Json::number(1)) is Err(_) else {
    fail("expected Err")
  }

  let empty_object = json_schema_to_schema(parse_json("{}"))
  guard empty_object.parse(Json::string("x")) is Ok(_) else {
    fail("expected fallback string schema")
  }

  let missing_ref = json_schema_to_schema(
    parse_json("{\"$ref\": \"#/missing\"}"),
  )
  guard missing_ref.parse(Json::string("x")) is Ok(_) else {
    fail("expected missing ref fallback")
  }
  guard missing_ref.parse(Json::boolean(true)) is Err(_) else {
    fail("expected string fallback to reject boolean")
  }
}

///|
test "json schema object without properties and mixed required" {
  let schema = json_schema_to_schema(
    parse_json("{\"type\": \"object\", \"required\": [\"name\", 1]}"),
  )
  guard schema.parse(parse_json("{}")) is Ok(_) else {
    fail("expected empty object schema")
  }
  guard schema.parse(Json::string("x")) is Err(_) else { fail("expected Err") }
}
