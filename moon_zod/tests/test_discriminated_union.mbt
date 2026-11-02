///|
test "discriminated union dispatches correctly" {
  let s = @core.discriminated_union("type", {
    "dog": @core.object({ "bark": @core.boolean() }),
    "cat": @core.object({ "meow": @core.boolean() }),
  })
  let dog_input = @core.parse_json("{\"type\": \"dog\", \"bark\": true}")
  guard s.parse(dog_input) is Ok(_) else { fail("expected Ok for dog") }
  let cat_input = @core.parse_json("{\"type\": \"cat\", \"meow\": false}")
  guard s.parse(cat_input) is Ok(_) else { fail("expected Ok for cat") }
}

///|
test "discriminated union rejects unknown discriminator" {
  let s = @core.discriminated_union("type", {
    "dog": @core.object({ "bark": @core.boolean() }),
  })
  let input = @core.parse_json("{\"type\": \"fish\"}")
  guard s.parse(input) is Err(errors) else { fail("expected Err") }
  match errors[0].code {
    @core.IssueCode::InvalidValue(_) => ()
    _ => fail("expected InvalidValue")
  }
}

///|
test "discriminated union missing discriminator field" {
  let s = @core.discriminated_union("type", {
    "dog": @core.object({ "bark": @core.boolean() }),
  })
  let input = @core.parse_json("{\"name\": \"fido\"}")
  guard s.parse(input) is Err(errors) else { fail("expected Err") }
  match errors[0].code {
    @core.IssueCode::MissingRequired("type") => ()
    _ => fail("expected MissingRequired")
  }
}

///|
test "discriminated union rejects non-object input" {
  let s = @core.discriminated_union("type", {
    "dog": @core.object({ "bark": @core.boolean() }),
  })
  guard s.parse(Json::string("hello")) is Err(_) else { fail("expected Err") }
}

///|
test "discriminated union validates against selected schema" {
  let s = @core.discriminated_union("type", {
    "dog": @core.object({ "bark": @core.boolean() }).strict(),
  })
  // dog schema uses strict mode: "meow" is not a valid field
  let input = @core.parse_json(
    "{\"type\": \"dog\", \"bark\": true, \"meow\": false}",
  )
  guard s.parse(input) is Err(errors) else { fail("expected Err") }
  match errors[0].code {
    @core.IssueCode::UnrecognizedKeys(_) => ()
    _ => fail("expected UnrecognizedKeys")
  }
}

///|
test "discriminated union refine rule is checked" {
  let s = @core.discriminated_union("type", {
    "dog": @core.object({ "bark": @core.boolean() }),
  }).refine(
    fn(json) {
      match json {
        Object(map) => map.contains("active")
        _ => false
      }
    },
    "active field required",
  )
  let input = @core.parse_json("{\"type\": \"dog\", \"bark\": true}")
  match s.parse(input) {
    Err(errors) => @debug.assert_eq(errors[0].message, "active field required")
    _ => fail("expected Err")
  }
}
