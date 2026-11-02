///|
test "refinements have distinct identities and cannot vanish during export" {
  let base = @core.string().name("Base")
  let refined = base.refine(fn(_) { false }, "reject")
  assert_true(base.id != refined.id)
  let graph = @core.tuple([
    base,
    refined,
    @core.recursive(fn() { @core.number().name("Number") }),
  ])
  assert_true(@exporters.try_schema_to_moon_zod_code(graph) is Err(_))
  assert_true(@exporters.try_to_json_schema(graph) is Err(_))
}

///|
test "deferred nodes cannot replace completed definitions with duplicate names" {
  let schema = @core.tuple([
    @core.string().name("Same"),
    @core.recursive(fn() { @core.number().name("Same") }),
  ])
  assert_true(@exporters.try_schema_to_moon_zod_code(schema) is Err(_))
  assert_true(@exporters.try_to_json_schema(schema) is Err(_))
}

///|
test "productive recursion through the same deferred anchor exports" {
  let anchor : Ref[@core.Schema?] = Ref(None)
  let tree = @core.recursive(fn() {
    @core.object({ "children": @core.array(anchor.val.unwrap()) })
  }).name("AnchoredTree")
  anchor.val = Some(tree)
  assert_true(tree.parse(@core.parse_json("{\"children\":[]}")) is Ok(_))
  assert_true(@exporters.try_schema_to_moon_zod_code(tree) is Ok(_))
}

///|
test "named pipelines suppress only their inherited input name" {
  let schema = @core.string().name("Text").pipe(@core.string())
  guard @exporters.try_schema_to_moon_zod_code(schema) is Ok(code) else {
    fail("named pipe must export")
  }
  assert_true(code.contains("string().pipe(@moon_zod.string())"))
  assert_true(!@exporters.schema_to_prompt_named(schema).contains("Text →"))
}

///|
test "optional preserves deferred and union missing defaults" {
  let deferred = @core.recursive(fn() {
    @core.string().default(Json::string("x"))
  })
  let combined = @core.union([
    @core.string().default(Json::string("x")),
    @core.number(),
  ])
  assert_true(deferred.optional().parse_missing() is Ok(Some(String("x"))))
  assert_true(combined.optional().parse_missing() is Ok(Some(String("x"))))
}

///|
test "deferred optional tuple elements and fields remain optional" {
  let deferred = @core.recursive(fn() { @core.string().optional() })
  assert_true(
    @core.tuple([deferred]).parse(Json::array([])) is Ok(Array(items)) &&
    items.is_empty(),
  )
  guard @exporters.to_json_schema_named(@core.object({ "x": deferred }))
    is Object(root) &&
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
      [@core.string().optional(), @core.string().default(Json::string("x"))],
      [@core.string().default(Json::string("x")), @core.string().optional()],
    ] {
    assert_true(@core.intersection(branches).parse_missing() is Err(_))
  }
  assert_true(
    @core.intersection([@core.string().optional(), @core.number().optional()]).parse_missing()
    is Ok(None),
  )
}

///|
test "builtin output projection preserves optional absence" {
  let schema = @core.object({ "x": @core.string().optional().trim() })
  guard @exporters.try_to_json_schema(schema, view=OutputView)
    is Ok(Object(out)) else {
    fail("expected output")
  }
  @debug.assert_eq(out.get("required"), Some(Json::array([])))
}

///|
test "checked input conservatively refuses reconciled strict intersections" {
  let schema = @core.intersection([
    @core.object({ "a": @core.string() }).strict(),
    @core.object({ "b": @core.string() }).strict(),
  ])
  assert_true(
    schema.parse(@core.parse_json("{\"a\":\"a\",\"b\":\"b\"}")) is Ok(_),
  )
  assert_true(@exporters.try_to_json_schema(schema, view=InputView) is Err(_))
}

///|
test "outer required messages survive wrappers and combinators" {
  for
    schema in [
      @core.string().nullable(),
      @core.union([@core.string()]),
      @core.recursive(fn() { @core.string() }),
      @core.string().transform(fn(v) { Ok(v) }),
      @core.string().pipe(@core.string()),
    ] {
    guard schema.required_error("custom").parse_missing() is Err(errors) else {
      fail("required")
    }
    @debug.assert_eq(errors[0].message, "custom")
  }
}

///|
test "enum invalid value uses its configured explicit message" {
  guard @core.enum_values(["a"])
    .invalid_type_error("custom")
    .parse(Json::string("b"))
    is Err(errors) else {
    fail("invalid value")
  }
  @debug.assert_eq(errors[0].message, "custom")
}

///|
test "missing JSON callbacks never observe a null sentinel" {
  let calls = Ref(0)
  let schema = @core.string()
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
  let schema = @core.union([@core.string().min(5), @core.string().max(1)])
  guard schema.parse(Json::string("abc")) is Err(errors) &&
    errors[0].code is InvalidUnion(branches) else {
    fail("expected complete union diagnostics")
  }
  @debug.assert_eq(branches.length(), 2)
}

///|
test "missing union preserves default refinement failures" {
  let schema = @core.union([
    @core.string()
    .default(Json::string("x"))
    .refine(fn(_) { false }, "rejected fallback"),
    @core.number(),
  ])
  guard schema.parse_missing() is Err(errors) else { fail("expected error") }
  @debug.assert_eq(errors[0].message, "rejected fallback")
}

///|
test "failed effect input cannot run output refinements" {
  let calls = Ref(0)
  let schema = @core.string()
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
