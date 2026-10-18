///|
async test "assembled SSE runs async refinements once after DONE" {
  let calls : Array[Json] = []
  let transforms : Array[Json] = []
  let base = @core.number().transform(value => {
    transforms.push(value)
    Ok(Json::string("clean"))
  })
  let schema = @async.async_schema(base).refine_async(value => {
    @moon_async.pause()
    calls.push(value)
    None
  })
  let reader = @io.MemoryReader() <| writer => {
    writer.write("data: 4\n\ndata: 2\n\ndata: [DONE]\n\ndata: 9\n\n")
  }
  defer reader.close()
  let events : Array[@async.SseStreamValidationEvent] = []
  let summary = schema.validate_sse_json_stream(reader, event => {
    events.push(event)
  })
  assert_eq(summary.fragments, 2)
  assert_eq(summary.valid, 1)
  assert_eq(summary.execution_failed, 0)
  assert_true(summary.done)
  assert_eq(transforms, [Json::number(42)])
  assert_eq(calls, [Json::string("clean")])
  assert_eq(events.length(), 4)
  assert_true(events[2] is @async.SseStreamValid(_, String("clean")))
  assert_true(events[3] is @async.SseStreamDone(_))
}

///|
async test "assembled SSE runs async refinements at EOF and roots issue paths" {
  let schema = @async.async_schema(@core.unknown()).refine_async(_ => {
    Some(@async.async_issue("rejected", path="[0]"))
  })
  let reader = @io.MemoryReader() <| writer => { writer.write("data: []\n\n") }
  defer reader.close()
  let events : Array[@async.SseStreamValidationEvent] = []
  let summary = schema.validate_sse_json_stream(
    reader,
    event => events.push(event),
    root_path="response",
  )
  assert_true(!summary.done)
  assert_eq(summary.invalid_schema, 1)
  guard events[1] is @async.SseStreamInvalidSchema(_, errors) else {
    fail("expected asynchronous schema failure")
  }
  assert_eq(errors[0].path, "response[0]")
}

///|
async test "assembled SSE preserves execution errors and validation issues" {
  let schema = @async.async_schema(@core.unknown())
    .refine_async(_ => raise Failure::Failure("service unavailable"))
    .refine_async(_ => Some(@async.async_issue("denied", path="name")))
  let reader = @io.MemoryReader() <| writer => {
    writer.write("data: {}\n\ndata: [DONE]\n\n")
  }
  defer reader.close()
  let events : Array[@async.SseStreamValidationEvent] = []
  let summary = schema.validate_sse_json_stream(reader, event => {
    events.push(event)
  })
  assert_eq(summary.execution_failed, 1)
  assert_eq(summary.invalid_schema, 0)
  assert_eq(summary.valid, 0)
  guard events[1] is @async.SseStreamExecutionFailed(_, execution, errors) else {
    fail("expected execution failure")
  }
  assert_eq(execution[0].index, 0)
  assert_true(execution[0].error is Failure::Failure("service unavailable"))
  assert_eq(errors[0].path, "name")
  assert_true(events[2] is @async.SseStreamDone(_))
}

///|
async test "assembled SSE skips async refinements on invalid input" {
  let calls : Array[Json] = []
  let schema = @async.async_schema(@core.number()).refine_async(value => {
    calls.push(value)
    None
  })
  for input in ["data: ]\n\n", "data: {}\n\n", "data: 1\n\ndata: x\n\n", ""] {
    let reader = @io.MemoryReader() <| writer => { writer.write(input) }
    defer reader.close()
    let summary = schema.validate_sse_json_stream(reader, _ => ())
    assert_eq(summary.invalid_json + summary.invalid_schema, 1)
    assert_eq(summary.execution_failed, 0)
  }
  assert_eq(calls.length(), 0)
}
