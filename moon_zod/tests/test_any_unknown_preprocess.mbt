///|
/// any()
test "any accepts primitive values" {
  let s = @core.any()
  guard s.parse(Json::string("x")) is Ok(_) else { fail("expected Ok") }
  guard s.parse(Json::number(1)) is Ok(_) else { fail("expected Ok") }
  guard s.parse(Json::boolean(true)) is Ok(_) else { fail("expected Ok") }
  guard s.parse(Json::null()) is Ok(_) else { fail("expected Ok") }
}

///|
test "any accepts compound values" {
  let s = @core.any()
  guard s.parse(@core.parse_json("{\"a\": [1, true, null]}")) is Ok(_) else {
    fail("expected Ok")
  }
}

///|
test "any supports refine" {
  let s = @core.any().refine(
    fn(json) { json == Json::string("ok") },
    "must be ok",
  )
  guard s.parse(Json::string("ok")) is Ok(_) else { fail("expected Ok") }
  guard s.parse(Json::string("bad")) is Err(_) else { fail("expected Err") }
}

///|
/// unknown()
test "unknown accepts any JSON value" {
  let s = @core.unknown()
  guard s.parse(@core.parse_json("[1, \"x\", false]")) is Ok(_) else {
    fail("expected Ok")
  }
}

///|
test "unknown preserves parsed value" {
  let s = @core.unknown()
  let input = @core.parse_json("{\"x\": 1}")
  match s.parse(input) {
    Ok(v) => @debug.assert_eq(v, input)
    Err(_) => fail("expected Ok")
  }
}

///|
/// preprocess()
test "preprocess runs before validation" {
  let s = @core.preprocess(
    fn(json) {
      match json {
        String(v) => Ok(Json::number(v.length().to_double()))
        _ => Ok(json)
      }
    },
    @core.number().min(3),
  )
  guard s.parse(Json::string("abcd")) is Ok(_) else { fail("expected Ok") }
  guard s.parse(Json::string("ab")) is Err(_) else { fail("expected Err") }
}

///|
test "preprocess returns transformed value" {
  let s = @core.preprocess(
    fn(json) {
      match json {
        String(v) => Ok(Json::number(v.length().to_double()))
        _ => Ok(json)
      }
    },
    @core.number().int(),
  )
  match s.parse(Json::string("abc")) {
    Ok(v) => @debug.assert_eq(v, Json::number(3))
    Err(_) => fail("expected Ok")
  }
}

///|
test "preprocess error includes path" {
  let s = @core.object({
    "age": @core.preprocess(fn(_) { Err("cannot preprocess") }, @core.number()),
  })
  match s.parse(@core.parse_json("{\"age\": \"x\"}")) {
    Err(errors) => {
      @debug.assert_eq(errors[0].path, "age")
      @debug.assert_eq(errors[0].message, "cannot preprocess")
    }
    _ => fail("expected Err")
  }
}

///|
test "preprocess supports chained rules on parsed value" {
  let s = @core.preprocess(fn(_) { Ok(Json::string("ab")) }, @core.string()).min(
    3,
  )
  guard s.parse(Json::number(1)) is Err(_) else { fail("expected Err") }
}
