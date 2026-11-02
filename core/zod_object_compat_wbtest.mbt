///|
test "panic pick rejects an unknown requested key" {
  let _ = object({ "name": string() }).pick(["name", "typo"])
}

///|
test "panic omit rejects an unknown requested key" {
  let _ = object({ "name": string() }).omit(["typo"])
}

///|
test "pick and omit accept declared keys and retain strict mode" {
  let schema = object({ "name": string().trim(), "age": number() }).strict()
  for selected in [schema.pick(["name", "name"]), schema.omit(["age"])] {
    review_expect_json(
      selected.parse(parse_json("{\"name\":\" Alice \"}")),
      parse_json("{\"name\":\"Alice\"}"),
    )
    assert_true(
      selected.parse(parse_json("{\"name\":\"Alice\",\"extra\":1}")) is Err(_),
    )
  }
}

///|
test "empty pick and omit preserve their shape operations" {
  let schema = object({ "name": string() })
  review_expect_json(
    schema.pick([]).parse(parse_json("{\"name\":\"Alice\"}")),
    parse_json("{}"),
  )
  review_expect_json(
    schema.omit([]).parse(parse_json("{\"name\":\"Alice\"}")),
    parse_json("{\"name\":\"Alice\"}"),
  )
}
