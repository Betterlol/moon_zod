///|
test "ValidationError to_string from parse error" {
  let s = string().min(3)
  match s.parse(Json::string("ab")) {
    Err(errors) => {
      let msg = errors[0].to_string()
      guard msg.contains("String must contain at least 3") else {
        fail("to_string missing message")
      }
      guard msg.contains("ab") else { fail("to_string missing value") }
    }
    _ => fail("expected Err")
  }
}

///|
test "ValidationError to_string path from nested object" {
  let s = object({ "name": string().min(3) })
  let input = parse_json("{\"name\": \"x\"}")
  match s.parse(input) {
    Err(errors) => {
      let msg = errors[0].to_string()
      guard msg.contains("[name]") else { fail("to_string missing path") }
      guard msg.contains("String must contain at least 3") else {
        fail("to_string missing message")
      }
    }
    _ => fail("expected Err")
  }
}
