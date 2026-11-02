///|
test "panic pick rejects invalidated object refinements" {
  let schema = object(Map([("a", string()), ("b", string())])).refine(
    fn(_) { true },
    "cross field",
  )
  let _ = schema.pick(["a"])
}

///|
test "panic omit rejects invalidated object refinements" {
  let schema = object(Map([("a", string()), ("b", string())])).refine(
    fn(_) { true },
    "cross field",
  )
  let _ = schema.omit(["b"])
}

///|
test "panic partial rejects invalidated object refinements" {
  let schema = object(Map([("a", string()), ("b", string())])).refine(
    fn(_) { true },
    "cross field",
  )
  let _ = schema.partial()
}

///|
test "panic extend_with rejects invalidated object refinements" {
  let schema = object(Map([("a", string()), ("b", string())])).refine(
    fn(_) { true },
    "cross field",
  )
  let _ = schema.extend_with(Map([("a", number())]))
}

///|
test "panic merge rejects invalidated object refinements" {
  let schema = object(Map([("a", string()), ("b", string())])).refine(
    fn(_) { true },
    "cross field",
  )
  let _ = schema.merge(object(Map([("a", number())])))
}

///|
test "discriminator injection preserves object refinements" {
  let branch = object(Map([("v", number())])).refine(fn(_) { false }, "branch")
  let schema = discriminated_union("kind", Map([("a", branch)]))
  assert_true(
    schema.parse(
      Json::object(Map([("kind", Json::string("a")), ("v", Json::number(1.0))])),
    )
    is Err(_),
  )
}
