///|
test "refinements have distinct identities and cannot vanish during export" {
  let base = string().name("Base")
  let refined = base.refine(fn(_) { false }, "reject")
  assert_true(base.id != refined.id)
  let graph = tuple([base, refined, recursive(fn() { number().name("Number") })])
  assert_true(try_schema_to_moon_zod_code(graph) is Err(_))
  assert_true(try_to_json_schema(graph) is Err(_))
}

///|
test "deferred nodes cannot replace completed definitions with duplicate names" {
  let schema = tuple([
    string().name("Same"),
    recursive(fn() { number().name("Same") }),
  ])
  assert_true(try_schema_to_moon_zod_code(schema) is Err(_))
  assert_true(try_to_json_schema(schema) is Err(_))
}

///|
test "productive recursion through the same deferred anchor exports" {
  let anchor : Ref[Schema?] = Ref(None)
  let tree = recursive(fn() {
    object({ "children": array(anchor.val.unwrap()) })
  }).name("AnchoredTree")
  anchor.val = Some(tree)
  assert_true(tree.parse(parse_json("{\"children\":[]}")) is Ok(_))
  assert_true(try_schema_to_moon_zod_code(tree) is Ok(_))
}

///|
test "named pipelines suppress only their inherited input name" {
  let schema = string().name("Text").pipe(string())
  guard try_schema_to_moon_zod_code(schema) is Ok(code) else {
    fail("named pipe must export")
  }
  assert_true(code.contains("string().pipe(@moon_zod.string())"))
  assert_true(!schema_to_prompt_named(schema).contains("Text →"))
}

///|
test "optional preserves deferred and union missing defaults" {
  let deferred = recursive(fn() { string().default(Json::string("x")) })
  let combined = union([string().default(Json::string("x")), number()])
  assert_true(deferred.optional().parse_missing() is Ok(Some(String("x"))))
  assert_true(combined.optional().parse_missing() is Ok(Some(String("x"))))
}

///|
test "deferred optional tuple elements and fields remain optional" {
  let deferred = recursive(fn() { string().optional() })
  assert_true(
    tuple([deferred]).parse(Json::array([])) is Ok(Array(items)) &&
    items.is_empty(),
  )
  guard to_json_schema_named(object({ "x": deferred })) is Object(root) &&
    root.get("$defs") is Some(Object(defs)) &&
    defs.get("Root") is Some(Object(definition)) else {
    fail("expected definition")
  }
  @debug.assert_eq(definition.get("required"), Some(Json::array([])))
}

///|
test "missing intersections reject absence versus present output" {
  for
    branches in [
      [string().optional(), string().default(Json::string("x"))],
      [string().default(Json::string("x")), string().optional()],
    ] {
    assert_true(intersection(branches).parse_missing() is Err(_))
  }
  assert_true(
    intersection([string().optional(), number().optional()]).parse_missing()
    is Ok(None),
  )
}

///|
test "builtin output projection preserves optional absence" {
  let schema = object({ "x": string().optional().trim() })
  guard try_to_json_schema(schema, view=OutputView) is Ok(Object(out)) else {
    fail("expected output")
  }
  @debug.assert_eq(out.get("required"), Some(Json::array([])))
}

///|
test "checked input conservatively refuses reconciled strict intersections" {
  let schema = intersection([
    object({ "a": string() }).strict(),
    object({ "b": string() }).strict(),
  ])
  assert_true(schema.parse(parse_json("{\"a\":\"a\",\"b\":\"b\"}")) is Ok(_))
  assert_true(try_to_json_schema(schema, view=InputView) is Err(_))
}

///|
test "outer required messages survive wrappers and combinators" {
  for
    schema in [
      string().nullable(),
      union([string()]),
      recursive(fn() { string() }),
      string().transform(fn(v) { Ok(v) }),
      string().pipe(string()),
    ] {
    guard schema.required_error("custom").parse_missing() is Err(errors) else {
      fail("required")
    }
    @debug.assert_eq(errors[0].message, "custom")
  }
}

///|
test "enum invalid value uses its configured explicit message" {
  guard enum_values(["a"]).invalid_type_error("custom").parse(Json::string("b"))
    is Err(errors) else {
    fail("invalid value")
  }
  @debug.assert_eq(errors[0].message, "custom")
}

///|
test "missing JSON callbacks never observe a null sentinel" {
  let calls = Ref(0)
  let schema = string()
    .optional()
    .refine(
      fn(value) {
        calls.val = calls.val + 1
        !(value is Null)
      },
      "present value",
    )
  assert_true(schema.parse_missing() is Ok(None))
  @debug.assert_eq(calls.val, 0)
}

///|
test "multiple continuable union failures preserve all branches" {
  let schema = union([string().min(5), string().max(1)])
  guard schema.parse(Json::string("abc")) is Err(errors) &&
    errors[0].code is InvalidUnion(branches) else {
    fail("expected complete union diagnostics")
  }
  @debug.assert_eq(branches.length(), 2)
}

///|
test "missing union preserves default refinement failures" {
  let schema = union([
    string()
    .default(Json::string("x"))
    .refine(fn(_) { false }, "rejected fallback"),
    number(),
  ])
  guard schema.parse_missing() is Err(errors) else { fail("expected error") }
  @debug.assert_eq(errors[0].message, "rejected fallback")
}

///|
test "failed effect input cannot run output refinements" {
  let calls = Ref(0)
  let schema = string()
    .min(4)
    .transform(fn(_) { Ok(Json::number(1.0)) })
    .refine(
      fn(_) {
        calls.val = calls.val + 1
        true
      },
      "output",
    )
  assert_true(schema.parse(Json::string("a")) is Err(_))
  @debug.assert_eq(calls.val, 0)
}
