///|
fn tree_schema() -> @core.Schema {
  @core.recursive(fn() {
    @core.object({
      "value": @core.number(),
      "children": @core.array(@core.recursive(tree_schema)).optional(),
    })
  })
}

///|
test "recursive tree schema parses valid input" {
  let s = tree_schema()
  let input = @core.parse_json("{\"value\": 1, \"children\": [{\"value\": 2}]}")
  guard s.parse(input) is Ok(_) else { fail("expected Ok") }
}

///|
test "recursive tree schema rejects invalid input" {
  let s = tree_schema()
  let input = @core.parse_json("{\"value\": \"not-a-number\"}")
  guard s.parse(input) is Err(_) else { fail("expected Err") }
}

///|
test "recursive schema with named root" {
  let s = tree_schema().name("Tree")
  let input = @core.parse_json("{\"value\": 1}")
  guard s.parse(input) is Ok(_) else { fail("expected Ok") }
}

///|
test "recursive schema self-reference parses deeply nested" {
  let s = tree_schema()
  let input = @core.parse_json(
    "{\"value\": 1, \"children\": [{\"value\": 2, \"children\": [{\"value\": 3}]}]}",
  )
  guard s.parse(input) is Ok(_) else { fail("expected Ok") }
}

///|
test "recursive schema rejects invalid nested value" {
  let s = tree_schema()
  let input = @core.parse_json(
    "{\"value\": 1, \"children\": [{\"value\": 2, \"children\": [{\"value\": \"bad\"}]}]}",
  )
  guard s.parse(input) is Err(_) else { fail("expected Err") }
}
