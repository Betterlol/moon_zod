///|
test "literal dotted keys and nested keys have different paths" {
  guard object({ "a.b": number() }).parse(parse_json("{\"a.b\":\"x\"}"))
    is Err(literal_errors) else {
    fail("expected literal error")
  }
  guard object({ "a": object({ "b": number() }) }).parse(
      parse_json("{\"a\":{\"b\":\"x\"}}"),
    )
    is Err(nested_errors) else {
    fail("expected nested error")
  }
  assert_eq(literal_errors[0].path, "[\"a.b\"]")
  assert_eq(nested_errors[0].path, "a.b")
}

///|
test "array-looking field keys are escaped" {
  guard object({ "[0]": number() }).parse(parse_json("{\"[0]\":\"x\"}"))
    is Err(errors) else {
    fail("expected error")
  }
  assert_eq(errors[0].path, "[\"[0]\"]")
}

///|
test "explicit schema and rule messages beat contextual error maps" {
  let params = ParseParams::{
    path: "",
    error_map: Some(fn(_, _, _) { Some("context") }),
  }
  guard string().min(3, msg="local").safe_parse(Json::string("x"), params)
    is Err(errors) else {
    fail("expected error")
  }
  assert_eq(errors[0].message, "local")
  guard string(invalid_type_error="schema").safe_parse(
      Json::number(1.0),
      params,
    )
    is Err(errors) else {
    fail("expected error")
  }
  assert_eq(errors[0].message, "schema")
}

///|
test "wrapper type errors are applied to the effective schema" {
  guard string()
    .optional()
    .invalid_type_error("custom")
    .parse(Json::number(1.0))
    is Err(errors) else {
    fail("expected error")
  }
  assert_eq(errors[0].message, "custom")
  guard preprocess(
      fn(value) { Ok(value) },
      number(),
      invalid_type_error="numeric",
    ).parse(Json::string("x"))
    is Err(errors) else {
    fail("expected error")
  }
  assert_eq(errors[0].message, "numeric")
}

///|
test "structured paths roundtrip literal brackets quotes and Unicode" {
  let paths : Array[PathSegment] = [
    Field("a.b"),
    Field("[0]"),
    Index(2),
    Field("\"\\\n中文"),
    Field(""),
  ]
  @debug.assert_eq(parse_path(format_path_segments(paths)), paths)
}

///|
test "union preserves every branch issue and contextualizes nested messages" {
  let schema = union([
    object({ "x": number(), "y": string() }),
    object({ "x": boolean() }),
  ])
  let params = ParseParams::{
    path: "",
    error_map: Some(fn(code, _, _) {
      match code {
        InvalidType(_) => Some("type")
        _ => None
      }
    }),
  }
  guard schema.safe_parse(parse_json("{\"x\":[],\"y\":1}"), params)
    is Err(errors) else {
    fail("expected union errors")
  }
  guard errors[0].code is InvalidUnion(branches) else {
    fail("expected structured union")
  }
  assert_eq(branches.length(), 2)
  assert_eq(branches[0].length(), 2)
  assert_eq(branches[1].length(), 1)
  assert_eq(branches[0][0].message, "type")
  @debug.assert_eq(branches[0][0].path_segments, [Field("x")])
}

///|
test "exclusive numeric custom messages remain explicit" {
  let params = ParseParams::{
    path: "",
    error_map: Some(fn(_, _, _) { Some("context") }),
  }
  guard number().gt(5, msg="greater").safe_parse(Json::number(4.0), params)
    is Err(errors) else {
    fail("expected error")
  }
  assert_eq(errors[0].message, "greater")
}
