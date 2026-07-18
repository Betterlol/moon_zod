///|
test "discriminated union dispatches correctly" {
  let s = discriminated_union("type", {
    "dog": object({ "bark": boolean() }),
    "cat": object({ "meow": boolean() }),
  })
  let dog_input = parse_json("{\"type\": \"dog\", \"bark\": true}")
  guard s.parse(dog_input) is Ok(_) else { fail("expected Ok for dog") }
  let cat_input = parse_json("{\"type\": \"cat\", \"meow\": false}")
  guard s.parse(cat_input) is Ok(_) else { fail("expected Ok for cat") }
}

///|
test "discriminated union rejects unknown discriminator" {
  let s = discriminated_union("type", { "dog": object({ "bark": boolean() }) })
  let input = parse_json("{\"type\": \"fish\"}")
  guard s.parse(input) is Err(errors) else { fail("expected Err") }
  match errors[0].code {
    IssueCode::InvalidValue(_) => ()
    _ => fail("expected InvalidValue")
  }
}

///|
test "discriminated union missing discriminator field" {
  let s = discriminated_union("type", { "dog": object({ "bark": boolean() }) })
  let input = parse_json("{\"name\": \"fido\"}")
  guard s.parse(input) is Err(errors) else { fail("expected Err") }
  match errors[0].code {
    IssueCode::MissingRequired("type") => ()
    _ => fail("expected MissingRequired")
  }
}

///|
test "discriminated union rejects non-object input" {
  let s = discriminated_union("type", { "dog": object({ "bark": boolean() }) })
  guard s.parse(Json::string("hello")) is Err(_) else { fail("expected Err") }
}

///|
test "discriminated union validates against selected schema" {
  let s = discriminated_union("type", {
    "dog": object({ "bark": boolean() }).strict(),
  })
  // dog schema uses strict mode: "meow" is not a valid field
  let input = parse_json("{\"type\": \"dog\", \"bark\": true, \"meow\": false}")
  guard s.parse(input) is Err(errors) else { fail("expected Err") }
  match errors[0].code {
    IssueCode::UnrecognizedKeys(_) => ()
    _ => fail("expected UnrecognizedKeys")
  }
}

///|
test "discriminated union refine rule is checked" {
  let s = discriminated_union("type", {
    "dog": object({ "bark": boolean() }),
  }).refine(fn(json) {
    match json {
      Object(map) => map.contains("active")
      _ => false
    }
  }, "active field required")
  let input = parse_json("{\"type\": \"dog\", \"bark\": true}")
  match s.parse(input) {
    Err(errors) => @debug.assert_eq(errors[0].message, "active field required")
    _ => fail("expected Err")
  }
}
