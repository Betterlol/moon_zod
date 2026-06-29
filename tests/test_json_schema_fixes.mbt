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
  let json_schema = parse_json(
    "{\"enum\": [\"red\", \"green\", \"blue\"]}",
  )
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
  let json_schema = parse_json(
    "{\"enum\": [1, 2, 3]}",
  )
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
  let schema = object({
    "name": string().min(2),
    "age": number().int().min(0),
  }).name("Person")
  let json_result = to_json_schema_named(schema)

  match json_result {
    Object(m) => {
      // Should have a $ref at root since it's named
      match m.get("$ref") {
        Some(_) => ()
        None => {
          // Or it could have type directly
          match m.get("type") {
            Some(String("object")) => ()
            _ => fail("json_schema_named: missing $ref or type field")
          }
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
    Object(m) => {
      match m.get("type") {
        Some(String(t)) => {
          if t == "string" {
            ()
          } else {
            fail("wrong type in roundtrip")
          }
        }
        _ => fail("missing or invalid type in roundtrip")
      }
    }
    _ => fail("exported schema is not an object")
  }
}


