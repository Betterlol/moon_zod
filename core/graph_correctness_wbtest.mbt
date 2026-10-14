///|
test "tuple traversal collects named children" {
  assert_eq(collect_named_schemas(tuple([string().name("Child")])).length(), 1)
}

///|
test "named wrapper traversal reaches named descendants" {
  let schema = object({ "a": string().name("Child") }).name("Parent").optional()
  assert_eq(collect_named_schemas(schema).length(), 2)
}

///|
test "constructors isolate mutable schema maps and arrays" {
  let fields = { "a": string() }
  let schema = object(fields)
  fields.set("b", number())
  assert_true(schema.parse(parse_json("{\"a\":\"x\"}")) is Ok(_))
  let values = ["x"]
  let enumeration = enum_values(values)
  values.push("y")
  assert_true(enumeration.parse(Json::string("y")) is Err(_))
}

///|
test "discriminated union retains its tag in strip and strict branches" {
  for
    schema in [
      object({ "bark": boolean() }),
      object({ "bark": boolean() }).strict(),
    ] {
    let tagged = discriminated_union("type", { "dog": schema })
    review_expect_json(
      tagged.parse(parse_json("{\"type\":\"dog\",\"bark\":true}")),
      parse_json("{\"type\":\"dog\",\"bark\":true}"),
    )
  }
}

///|
fn anonymous_export_tree() -> Schema {
  recursive(fn() {
    object({ "children": array(recursive(anonymous_export_tree)).optional() })
  })
}

///|
fn named_export_tree() -> Schema {
  recursive(fn() {
    object({
      "value": number(),
      "children": array(recursive(named_export_tree)).optional(),
    })
  }).name("Tree")
}

///|
test "checked traversal stops anonymous recursive expansion" {
  assert_true(try_collect_named_schemas(anonymous_export_tree()) is Err(_))
}

///|
test "checked traversal supports named recursion and rejects duplicate definitions" {
  guard try_collect_named_schemas(named_export_tree()) is Ok(nodes) else {
    fail("expected named recursion")
  }
  assert_eq(nodes.length(), 1)
  assert_true(
    try_collect_named_schemas(
      object({ "a": string().name("Same"), "b": number().name("Same") }),
    )
    is Err(_),
  )
}

///|
test "lazy resolution is cached for a stable graph" {
  let calls = Ref(0)
  let schema = recursive(fn() {
    calls.val = calls.val + 1
    string()
  })
  assert_true(schema.parse(Json::string("x")) is Ok(_))
  assert_true(schema.parse(Json::string("y")) is Ok(_))
  assert_eq(calls.val, 1)
}
