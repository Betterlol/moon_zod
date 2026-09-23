///|
async fn reject_admin_role(value : Json) -> @async.AsyncIssue? {
  @moon_async.pause()
  match value {
    Object(fields) =>
      match fields.get("extra") {
        Some(extra) =>
          Some(
            @async.async_issue(
              "Strip mode did not remove extra",
              path="extra",
              got=extra,
            ),
          )
        None =>
          match fields.get("role") {
            Some(String("admin")) =>
              Some(
                @async.async_issue(
                  "admin role is not permitted",
                  path="role",
                  got=Json::string("admin"),
                ),
              )
            _ => None
          }
      }
    _ => None
  }
}

///|
async fn reject_name(value : Json) -> @async.AsyncIssue? {
  @moon_async.pause()
  match value {
    Object(fields) =>
      match fields.get("name") {
        Some(String("Ada")) =>
          Some(
            @async.async_issue(
              "Ada requires approval",
              path="name",
              got=Json::string("Ada"),
            ),
          )
        _ => None
      }
    _ => None
  }
}

///|
async test "async refinements receive cleaned schema output and collect failures" {
  let base = @core.object({ "name": @core.string(), "role": @core.string() })
  let schema = @async.async_schema(base)
    .refine_async(reject_admin_role)
    .refine_async(reject_name)
  let input = Json::object({
    "name": Json::string("Ada"),
    "role": Json::string("admin"),
    "extra": Json::string("discarded"),
  })

  match schema.parse_async(input, root_path="request") {
    Err(errors) => {
      assert_eq(errors.length(), 2)
      assert_eq(errors[0].path, "request.role")
      assert_eq(errors[0].message, "admin role is not permitted")
      assert_eq(errors[1].path, "request.name")
      assert_eq(errors[1].message, "Ada requires approval")
    }
    Ok(_) => fail("expected asynchronous refinements to fail")
  }
}

///|
async test "synchronous failures skip asynchronous refinements" {
  let base = @core.object({ "name": @core.string(), "role": @core.string() })
  let schema = @async.async_schema(base).refine_async(reject_admin_role)
  let input = Json::object({ "role": Json::string("admin") })

  match schema.parse_async(input) {
    Err(errors) => {
      assert_eq(errors.length(), 1)
      assert_eq(errors[0].path, "name")
      assert_eq(errors[0].message, "Required")
    }
    Ok(_) => fail("expected synchronous schema failure")
  }
}

///|
async test "JSONL validation handles partial writes and trailing records" {
  let events : Array[@async.JsonlEvent] = []
  let reader = @io.MemoryReader() <| writer => {
    writer.write("{\"name\":\"Ada\"}\n{\"name\":1")
    writer.write("}\nnot json\n\n{\"name\":\"Bob\"}")
  }
  defer reader.close()
  let schema = @core.object({ "name": @core.string() })
  let summary = @async.validate_jsonl(reader, schema, event => {
    events.push(event)
  })

  assert_eq(summary.lines_read, 5)
  assert_eq(summary.records, 4)
  assert_eq(summary.valid, 2)
  assert_eq(summary.invalid_schema, 1)
  assert_eq(summary.invalid_json, 1)
  assert_eq(summary.skipped, 1)
  assert_eq(events.length(), 4)
  match events[0] {
    @async.Valid(line, _) => assert_eq(line, 1)
    _ => fail("expected valid first record")
  }
  match events[1] {
    @async.InvalidSchema(line, errors) => {
      assert_eq(line, 2)
      assert_eq(errors[0].path, "name")
    }
    _ => fail("expected schema failure on second record")
  }
  match events[2] {
    @async.InvalidJson(line, _) => assert_eq(line, 3)
    _ => fail("expected JSON failure on third record")
  }
  match events[3] {
    @async.Valid(line, value) => {
      assert_eq(line, 5)
      assert_true(value is Object(_))
    }
    _ => fail("expected trailing valid record")
  }
}

///|
async test "JSONL validation runs asynchronous refinements" {
  let events : Array[@async.JsonlEvent] = []
  let reader = @io.MemoryReader() <| writer => {
    writer.write("{\"name\":\"Ada\",\"role\":\"admin\"}\n")
  }
  defer reader.close()
  let schema = @async.async_schema(
    @core.object({ "name": @core.string(), "role": @core.string() }),
  ).refine_async(reject_admin_role)
  let summary = schema.validate_jsonl(reader, event => events.push(event))

  assert_eq(summary.records, 1)
  assert_eq(summary.invalid_schema, 1)
  match events[0] {
    @async.InvalidSchema(line, errors) => {
      assert_eq(line, 1)
      assert_eq(errors[0].path, "role")
      assert_eq(errors[0].message, "admin role is not permitted")
    }
    _ => fail("expected async refinement failure")
  }
}
