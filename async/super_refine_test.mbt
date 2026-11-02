///|
async test "super refinements preserve declaration order and multiple issue paths" {
  let schema = @async.async_schema(@core.unknown())
    .refine_async(_ => Some(@async.async_issue("first")))
    .super_refine_async(_ => {
      @moon_async.pause()
      [
        @async.async_issue("second", path="email", got=Json::string("taken")),
        @async.async_issue("third", path="items[0]"),
        @async.async_issue("fourth", path="[1]"),
      ]
    })
    .refine_async(_ => Some(@async.async_issue("last")))
  guard schema.parse_async(Json::null(), root_path="request")
    is Err(@async.Validation(errors)) else {
    fail("expected issues")
  }
  assert_eq(errors.length(), 5)
  assert_eq(errors[0].message, "first")
  assert_eq(errors[1].path, "request.email")
  assert_eq(errors[1].got, Json::string("taken"))
  assert_eq(errors[2].path, "request.items[0]")
  assert_eq(errors[3].path, "request[1]")
  assert_eq(errors[1].path_segments, [
    @core.Field("request"),
    @core.Field("email"),
  ])
  assert_eq(errors[2].path_segments, [
    @core.Field("request"),
    @core.Field("items"),
    @core.Index(0),
  ])
  assert_eq(errors[3].path_segments, [@core.Field("request"), @core.Index(1)])
  assert_eq(errors[4].message, "last")
  for error in errors {
    assert_true(error.code is @core.IssueCode::Custom)
  }
}

///|
async test "super refinements preserve mixed failures and callback indices" {
  let schema = @async.async_schema(@core.unknown())
    .super_refine_async(_ => [@async.async_issue("before")])
    .refine_async(_ => None)
    .super_refine_async(_ => raise Failure::Failure("lookup failed"))
    .super_refine_async(_ => [@async.async_issue("after")])
  guard schema.parse_async(Json::null())
    is Err(@async.Execution(execution, errors)) else {
    fail("expected execution error")
  }
  assert_eq(execution.length(), 1)
  assert_eq(execution[0].index, 2)
  assert_true(execution[0].error is Failure::Failure("lookup failed"))
  assert_eq(errors.length(), 2)
  assert_eq(errors[0].message, "before")
  assert_eq(errors[1].message, "after")
}

///|
async test "super refinement empty results accept and extension leaves the base unchanged" {
  let calls : Array[Int32] = []
  let base = @async.async_schema(@core.string()).super_refine_async(_ => {
    calls.push(1)
    []
  })
  let extended = base.super_refine_async(_ => [@async.async_issue("reject")])
  assert_true(base.parse_async(Json::string("ok")) is Ok(String("ok")))
  assert_true(
    extended.parse_async(Json::string("ok")) is Err(@async.Validation(_)),
  )
  assert_eq(calls.length(), 2)
}

///|
async test "synchronous failures skip super refinements" {
  let calls : Array[Int32] = []
  let schema = @async.async_schema(@core.string()).super_refine_async(_ => {
    calls.push(1)
    []
  })
  assert_true(schema.parse_async(Json::null()) is Err(@async.Validation(_)))
  assert_eq(calls.length(), 0)
}

///|
async test "all async stream adapters deliver every super refinement issue" {
  let schema = @async.async_schema(@core.unknown()).super_refine_async(_ => {
    [@async.async_issue("a", path="a"), @async.async_issue("b", path="b")]
  })
  let jsonl = @io.MemoryReader() <| writer => { writer.write("{}\n") }
  defer jsonl.close()
  let jsonl_summary = schema.validate_jsonl(jsonl, event => {
    guard event is @async.InvalidSchema(1, errors) else {
      fail("expected JSONL issues")
    }
    assert_eq(errors.length(), 2)
  })
  assert_eq(jsonl_summary.invalid_schema, 1)
  let sse = @io.MemoryReader() <| writer => { writer.write("data: {}\n\n") }
  defer sse.close()
  let sse_summary = schema.validate_sse_json(sse, event => {
    guard event is @async.SseInvalidSchema(_, errors) else {
      fail("expected SSE issues")
    }
    assert_eq(errors.length(), 2)
  })
  assert_eq(sse_summary.invalid_schema, 1)
  let stream = @io.MemoryReader() <| writer => { writer.write("data: {}\n\n") }
  defer stream.close()
  let results : Array[Array[@core.ValidationError]] = []
  let stream_summary = schema.validate_sse_json_stream(stream, event => {
    if event is @async.SseStreamInvalidSchema(_, errors) {
      results.push(errors)
    }
  })
  assert_eq(stream_summary.invalid_schema, 1)
  assert_eq(results.length(), 1)
  assert_eq(results[0].length(), 2)
}
