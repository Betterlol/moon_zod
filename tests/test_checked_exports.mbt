///|
fn exported_tree() -> Schema {
  recursive(fn() {
    object({
      "value": number(),
      "children": array(recursive(exported_tree)).optional(),
    })
  }).name("Tree")
}

///|
test "named recursive exports use references" {
  let schema = exported_tree()
  let exported = to_json_schema_named(schema)
  guard exported is Object(root) &&
    root.get("$defs") is Some(Object(defs)) &&
    defs.get("Tree") is Some(Object(tree)) &&
    tree.get("properties") is Some(Object(properties)) &&
    properties.get("children") is Some(Object(children)) &&
    children.get("items") is Some(Object(item)) else {
    fail("expected recursive tree definition")
  }
  @debug.assert_eq(item.get("$ref"), Some(Json::string("#/$defs/Tree")))
  assert_true(schema_to_prompt_named(schema).contains("Tree[]"))
  assert_true(
    schema_to_moon_zod_code_named(schema).contains("recursive(tree_schema)"),
  )
  assert_true(schema_to_moonbit_struct(schema).contains("Array[Tree]"))
}

///|
test "checked source refuses custom effects and refinements" {
  assert_true(
    try_schema_to_moon_zod_code(string().transform(fn(value) { Ok(value) }))
    is Err(_),
  )
  assert_true(
    try_schema_to_moon_zod_code(string().refine(fn(_) { false }, "opaque"))
    is Err(_),
  )
  guard try_schema_to_moon_zod_code(string().trim().length(3).message("three"))
    is Ok(code) else {
    fail("expected builtin source")
  }
  assert_true(code.contains(".trim().length(3).message(\"three\")"))
}

///|
test "pipeline input and output views describe different types" {
  let schema = string()
    .transform(fn(_) { Ok(Json::number(1.0)) })
    .pipe(number())
  guard try_to_json_schema(schema, view=InputView) is Ok(input) else {
    fail("expected input view")
  }
  guard try_to_json_schema(schema, view=OutputView) is Ok(output) else {
    fail("expected output view")
  }
  @debug.assert_eq(input, parse_json("{\"type\":\"string\"}"))
  @debug.assert_eq(output, parse_json("{\"type\":\"number\"}"))
  assert_true(
    try_to_json_schema(
      string().transform(fn(value) { Ok(value) }),
      view=OutputView,
    )
    is Err(_),
  )
}

///|
test "checked input strip view permits extras and output view requires defaults" {
  let schema = object({ "a": string().default(Json::string("x")) })
  guard try_to_json_schema(schema, view=InputView) is Ok(Object(input)) else {
    fail("expected input view")
  }
  @debug.assert_eq(input.get("additionalProperties"), Some(Json::boolean(true)))
  guard try_to_json_schema(schema, view=OutputView) is Ok(Object(output)) else {
    fail("expected output view")
  }
  @debug.assert_eq(output.get("required"), Some(parse_json("[\"a\"]")))
}

///|
test "datetime options are retained during JSON Schema roundtrip" {
  let schema = string().datetime(offset=false, precision=3)
  let imported = json_schema_to_schema(to_json_schema(schema))
  assert_true(imported.parse(Json::string("2024-01-01T12:00:00.123Z")) is Ok(_))
  assert_true(
    imported.parse(Json::string("2024-01-01T12:00:00.123+08:00")) is Err(_),
  )
}

///|
test "combined patterns survive typed JSON Schema roundtrip" {
  let original = string().startsWith("a").endsWith("z")
  let imported = json_schema_to_schema(to_json_schema(original))
  assert_true(imported.parse(Json::string("abz")) is Ok(_))
  assert_true(imported.parse(Json::string("abc")) is Err(_))
  assert_true(imported.parse(Json::string("zzz")) is Err(_))
}

///|
test "JSON Schema closed objects reject unknown keys" {
  let imported = json_schema_to_schema(
    parse_json(
      "{\"type\":\"object\",\"properties\":{\"a\":{\"type\":\"string\"}},\"additionalProperties\":false}",
    ),
  )
  assert_true(imported.parse(parse_json("{\"a\":\"x\",\"extra\":1}")) is Err(_))
}

///|
test "recursive struct source defines its helper" {
  let code = schema_to_moonbit_struct_full(exported_tree())
  assert_true(code.contains("fn tree_schema()"))
  assert_true(
    try_schema_to_moon_zod_code(
      object({ "a": exported_tree(), "b": string().name("Tree_schema") }),
    )
    is Err(_),
  )
  assert_true(
    schema_to_moon_zod_code(string().brand("Id")).contains(".brand(\"Id\")"),
  )
}

///|
test "recursive skeleton omits constraints" {
  fn tree() -> Schema {
    recursive(fn() {
      object({
        "v": string().min(5),
        "children": array(recursive(tree)).optional(),
      })
    }).name("SkeletonTree")
  }
  let skeleton = to_json_schema_skeleton(tree()).stringify()
  assert_true(!skeleton.contains("minLength"))
  assert_true(skeleton.contains("$ref"))
  assert_true(try_to_json_schema(tree(), view=InputView) is Err(_))
}

///|
test "checked flattening preserves wrapper output constraints" {
  let schema = preprocess(fn(v) { Ok(v) }, string()).min(4)
  guard try_to_json_schema(schema, view=OutputView) is Ok(Object(m)) else {
    fail("expected output")
  }
  @debug.assert_eq(m.get("minLength"), Some(Json::number(4.0)))
  let defaulted = string().default(Json::string("abc")).optional().min(4)
  guard try_to_json_schema(defaulted, view=OutputView) is Ok(json) else {
    fail("expected output")
  }
  assert_true(json.stringify().contains("minLength"))
}
