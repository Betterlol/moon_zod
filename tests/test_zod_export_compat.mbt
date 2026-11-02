///|
fn escaped_export_tree() -> Schema {
  recursive(fn() {
    object({
      "value": string(),
      "children": array(recursive(escaped_export_tree)).optional(),
    }).strict()
  }).name("Tree~/ %2F#树")
}

///|
test "named JSON references escape pointer tokens and URI fragments" {
  for
    (name, expected) in [
      ("A/B", "#/$defs/A~1B"),
      ("A~1B", "#/$defs/A~01B"),
      ("A%2FB", "#/$defs/A%252FB"),
      ("A B#C", "#/$defs/A%20B%23C"),
      ("é", "#/$defs/%C3%A9"),
      ("树😀", "#/$defs/%E6%A0%91%F0%9F%98%80"),
    ] {
    let contract = to_json_schema_named(string().name(name))
    guard contract is Object(root) &&
      root.get("$defs") is Some(Object(definitions)) else {
      fail("expected named contract")
    }
    @debug.assert_eq(root.get("$ref"), Some(Json::string(expected)))
    assert_true(definitions.contains(name))
  }
}

///|
test "checked recursive references retain escaped names" {
  guard try_to_json_schema(escaped_export_tree(), view=InputView)
    is Ok(Object(contract)) &&
    contract.get("$defs") is Some(Object(definitions)) &&
    definitions.get("Tree~/ %2F#树") is Some(Object(tree)) &&
    tree.get("properties") is Some(Object(properties)) &&
    properties.get("children") is Some(Object(children)) &&
    children.get("items") is Some(Object(item)) else {
    fail("expected checked recursive contract")
  }
  @debug.assert_eq(
    item.get("$ref"),
    Some(Json::string("#/$defs/Tree~0~1%20%252F%23%E6%A0%91")),
  )
}

///|
test "checked integer views retain both safe integer boundaries" {
  let views : Array[SchemaView] = [InputView, OutputView]
  for view in views {
    guard try_to_json_schema(number().int(), view~) is Ok(contract) else {
      fail("expected representable integer contract")
    }
    let validator = json_schema_to_schema(contract)
    for value in [-9007199254740991.0, 9007199254740991.0] {
      assert_true(validator.parse(Json::number(value)) is Ok(_))
    }
    for value in [-9007199254740992.0, 9007199254740992.0] {
      assert_true(validator.parse(Json::number(value)) is Err(_))
    }
  }
}

///|
test "checked output permits absence after an optional prefault fails" {
  let schema = object({
    "value": string().min(3).prefault(Json::string("x")).optional(),
    "defaulted": string().default(Json::string("ok")).optional(),
  })
  guard schema.parse(parse_json("{}")) is Ok(output) else {
    fail("optional must permit a failed prefault")
  }
  @debug.assert_eq(output, parse_json("{\"defaulted\":\"ok\"}"))
  guard try_to_json_schema(schema, view=OutputView) is Ok(contract) else {
    fail("expected structural output contract")
  }
  assert_true(json_schema_to_schema(contract).parse(output) is Ok(_))
  assert_true(json_schema_to_schema(contract).parse(parse_json("{}")) is Err(_))
}

///|
test "optional output remains omittable when intersection defaults conflict" {
  let schema = intersection([
    string().default(Json::string("a")),
    string().default(Json::string("b")),
  ]).optional()
  assert_true(schema.parse_missing() is Ok(None))
  assert_true(output_is_optional(schema))
}

///|
test "checked references reject unpaired surrogate names without replacement" {
  let invalid_name = "😀".unsafe_substring(start=0, end=1)
  assert_true(try_to_json_schema(string().name(invalid_name)) is Err(_))
  assert_true(string().name(invalid_name).parse(Json::string("x")) is Ok(_))
}
