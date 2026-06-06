///|
/// Parse a JSON string, aborting on malformed test input.
fn parse_json(input : String) -> Json {
  @json.parse(input) catch {
    _ => abort("bad test json: " + input)
  }
}

///|
/// White-box tests for the mutable path_stack invariant.
///
/// The path_stack is a shared mutable Array[String] passed through
/// parse_inner -> parse_object / parse_array / etc. Each helper must
/// push before descending and pop after returning -- even on error paths.
///
/// These tests directly call `parse_inner` (package-private, fn) to
/// inspect the stack after parsing completes, verifying the invariant
/// that the stack is clean (length == 0) after both success and error.

///|
test "path_stack returns to length 0 after deep nested parse success" {
  let s = object({
    "a": object({ "b": array(object({ "c": number().positive() })) }),
  })
  let json = parse_json("{\"a\": {\"b\": [{\"c\": 1}, {\"c\": 2}]}}")
  let stack : Array[String] = []
  match parse_inner(s, json, stack) {
    Ok(_) => @debug.assert_eq(stack.length(), 0)
    Err(_) => fail("expected parse to succeed")
  }
}

///|
test "path_stack returns to length 0 after parse error" {
  let s = object({
    "a": object({ "b": array(object({ "c": number().positive() })) }),
  })
  // Deliberately invalid: c = -1 fails positive() rule
  let json = parse_json("{\"a\": {\"b\": [{\"c\": 1}, {\"c\": -1}]}}")
  let stack : Array[String] = []
  match parse_inner(s, json, stack) {
    Err(_) => @debug.assert_eq(stack.length(), 0)
    Ok(_) => fail("expected parse to fail")
  }
}

///|
test "path_stack returns to length 0 after strict mode error" {
  let s = object({ "x": number() }).strict()
  // strict mode rejects extra field "y"
  let json = parse_json("{\"x\": 1, \"y\": 2}")
  let stack : Array[String] = []
  match parse_inner(s, json, stack) {
    Err(_) => @debug.assert_eq(stack.length(), 0)
    Ok(_) => fail("expected parse to fail")
  }
}

///|
test "path_stack returns to length 0 after type error in array" {
  let s = array(number())
  // array element is a string, not a number
  let json = parse_json("[\"hello\"]")
  let stack : Array[String] = []
  match parse_inner(s, json, stack) {
    Err(_) => @debug.assert_eq(stack.length(), 0)
    Ok(_) => fail("expected parse to fail")
  }
}
