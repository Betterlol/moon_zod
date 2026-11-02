///|
test "JsonNullable decodes inline values and serializes without singleton arrays" {
  let values : Array[JsonNullable[String]] = @json.from_json(
    @core.parse_json("[null,\"x\"]"),
  )
  assert_true(values[0] is JsonNull)
  assert_true(values[1] is JsonValue("x"))
  @debug.assert_eq(ToJson::to_json(values), @core.parse_json("[null,\"x\"]"))
}

///|
test "JsonNullable rejects an invalid nonnull value through the inner decoder" {
  let rejected = try {
    let _value : JsonNullable[String] = @json.from_json(Json::number(1.0))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
