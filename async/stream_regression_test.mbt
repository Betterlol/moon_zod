///|
async test "SSE accepts CR-only separators and a split CRLF" {
  let events : Array[@async.SseEvent] = []
  let reader = @io.MemoryReader() <| writer => {
    writer.write("data: first\r\rdata: second\r")
    writer.write("\n\r\n")
  }
  defer reader.close()
  let summary = @async.read_sse(reader, event => events.push(event))
  assert_eq(summary.events, 2)
  assert_eq(events[0].data, "first")
  assert_eq(events[1].data, "second")
}

///|
async test "SSE strips only the leading BOM" {
  let events : Array[@async.SseEvent] = []
  let reader = @io.MemoryReader() <| writer => {
    writer.write(b"\xef")
    writer.write(b"\xbb\xbfdata: first\n\ndata: \xef\xbb\xbfsecond\n\n")
  }
  defer reader.close()
  let summary = @async.read_sse(reader, event => events.push(event))
  assert_eq(summary.events, 2)
  assert_eq(events[0].data, "first")
  assert_eq(events[1].data, "\u{FEFF}second")
}

///|
async test "SSE ignores NUL ids and supports empty id reset" {
  let events : Array[@async.SseEvent] = []
  let reader = @io.MemoryReader() <| writer => {
    writer.write("id: good\n\nid: bad\u{0000}id\ndata: first\n\n")
    writer.write("id:\ndata: second\n\ndata: third\n\n")
  }
  defer reader.close()
  ignore(@async.read_sse(reader, event => events.push(event)))
  assert_eq(events[0].id, Some("good"))
  assert_eq(events[1].id, Some(""))
  assert_eq(events[2].id, Some(""))
}

///|
async test "SSE discards an unterminated DONE frame at EOF" {
  let reader = @io.MemoryReader() <| writer => {
    writer.write("data: [DONE]\n")
  }
  defer reader.close()
  let summary = @async.validate_sse_json(reader, @core.unknown(), _ => ())
  assert_eq(summary.events, 0)
  assert_true(!summary.done)
}

///|
async test "SSE stream rejects trailing content across frames" {
  let reader = @io.MemoryReader() <| writer => {
    writer.write("data: {}\n\ndata: garbage\n\ndata: [DONE]\n\n")
  }
  defer reader.close()
  let summary = @async.validate_sse_json_stream(reader, @core.unknown(), _ => ())
  assert_eq(summary.valid, 0)
  assert_eq(summary.invalid_json, 1)
  assert_eq(summary.fragments, 2)
  assert_true(!summary.done)
}

///|
async test "async parsing collects execution and validation failures without raising" {
  let calls : Array[Int32] = []
  let schema = @async.async_schema(@core.unknown())
    .refine_async(_ => Some(@async.async_issue("before", path="[0]")))
    .refine_async(_ => raise Failure::Failure("remote unavailable"))
    .refine_async(_ => {
      calls.push(1)
      Some(@async.async_issue("after"))
    })
    .refine_async(_ => raise Failure::Failure("second failure"))
  // This helper's noraise annotation checks the API's ordinary error contract.
  let result = parse_without_raising(schema)
  guard result is Err(@async.Execution(execution_errors, errors)) else {
    fail("expected execution failures")
  }
  assert_eq(execution_errors.length(), 2)
  assert_eq(execution_errors[0].index, 1)
  assert_true(
    execution_errors[0].error is Failure::Failure("remote unavailable"),
  )
  assert_eq(execution_errors[1].index, 3)
  assert_eq(errors.length(), 2)
  assert_eq(errors[0].path, "request[0]")
  assert_eq(errors[1].path, "request")
  assert_eq(calls.length(), 1)
}

///|
async fn parse_without_raising(
  schema : @async.AsyncSchema,
) -> @async.AsyncParseResult noraise {
  schema.parse_async(Json::null(), root_path="request")
}

///|
async test "async parsing propagates cancellation and skips later checks" {
  let calls : Array[Int32] = []
  let schema = @async.async_schema(@core.unknown())
    .refine_async(_ => {
      @moon_async.sleep(10000)
      None
    })
    .refine_async(_ => {
      calls.push(1)
      None
    })
  let result = @moon_async.with_timeout_opt(100, () => {
    schema.parse_async(Json::null())
  })
  assert_true(result is None)
  assert_eq(calls.length(), 0)
}

///|
async test "JSONL reports execution failures and continues with later records" {
  let schema = @async.async_schema(@core.number()).refine_async(value => {
    if value is Number(1.0, ..) {
      raise Failure::Failure("lookup failed")
    }
    None
  })
  let events : Array[@async.JsonlEvent] = []
  let reader = @io.MemoryReader() <| writer => { writer.write("1\n2\n") }
  defer reader.close()
  let summary = schema.validate_jsonl(reader, event => events.push(event))
  assert_eq(summary.records, 2)
  assert_eq(summary.execution_failed, 1)
  assert_eq(summary.invalid_schema, 0)
  assert_eq(summary.valid, 1)
  assert_true(events[0] is @async.ExecutionFailed(1, _, _))
  assert_true(events[1] is @async.Valid(2, Number(2.0, ..)))
}

///|
async test "SSE reports execution failures separately from invalid schema" {
  let schema = @async.async_schema(@core.number()).refine_async(_ => {
    raise Failure::Failure("lookup failed")
  })
  let events : Array[@async.SseValidationEvent] = []
  let reader = @io.MemoryReader() <| writer => {
    writer.write("data: 1\n\ndata: [DONE]\n\n")
  }
  defer reader.close()
  let summary = schema.validate_sse_json(reader, event => events.push(event))
  assert_eq(summary.execution_failed, 1)
  assert_eq(summary.invalid_schema, 0)
  assert_true(summary.done)
  assert_true(events[0] is @async.SseExecutionFailed(_, _, _))
}

///|
async test "SSE rejects an oversized line before its terminator" {
  let reader = @io.MemoryReader() <| writer => {
    writer.write("data: 12345")
    @moon_async.sleep(10000)
  }
  defer reader.close()
  let result = @moon_async.with_timeout_opt(250, () => {
    try {
      ignore(
        @async.read_sse(reader, _ => (), limits={
          max_line_bytes: 10,
          max_frame_bytes: 100,
        }),
      )
      false
    } catch {
      @async.StreamLimitExceeded::LineTooLong(10) => true
      _ => false
    }
  })
  assert_true(result is Some(true))
}

///|
async test "SSE bounds all frame lines including comments and ignored fields" {
  let reader = @io.MemoryReader() <| writer => {
    writer.write(":1234\nretry: 1\n\n")
  }
  defer reader.close()
  let raised = try {
    ignore(
      @async.read_sse(reader, _ => (), limits={
        max_line_bytes: 10,
        max_frame_bytes: 12,
      }),
    )
    false
  } catch {
    @async.StreamLimitExceeded::FrameTooLarge(12) => true
    _ => false
  }
  assert_true(raised)
}

///|
async test "SSE frame limit rejects an unterminated line before EOF" {
  let reader = @io.MemoryReader() <| writer => {
    writer.write("data: 1234")
    @moon_async.sleep(10000)
  }
  defer reader.close()
  let result = @moon_async.with_timeout_opt(250, () => {
    try {
      ignore(
        @async.read_sse(reader, _ => (), limits={
          max_line_bytes: 100,
          max_frame_bytes: 8,
        }),
      )
      false
    } catch {
      @async.StreamLimitExceeded::FrameTooLarge(8) => true
      _ => false
    }
  })
  assert_true(result is Some(true))
}

///|
async test "SSE accepts a frame exactly at its configured limit" {
  let events : Array[@async.SseEvent] = []
  let reader = @io.MemoryReader() <| writer => { writer.write("data: x\n\n") }
  defer reader.close()
  let summary = @async.read_sse(reader, event => events.push(event), limits={
    max_line_bytes: 7,
    max_frame_bytes: 9,
  })
  assert_eq(summary.events, 1)
  assert_eq(events[0].data, "x")
}

///|
async test "JSONL bounds raw UTF-8 bytes and resets its line limit per record" {
  let reader = @io.MemoryReader() <| writer => {
    writer.write("\"你\"\r\n1\n2")
  }
  defer reader.close()
  let summary = @async.validate_jsonl(reader, @core.unknown(), _ => (), limits={
    max_line_bytes: 6,
    max_frame_bytes: 20,
  })
  assert_eq(summary.valid, 3)
  let oversized = @io.MemoryReader() <| writer => { writer.write("\"你\"\n") }
  defer oversized.close()
  let raised = try {
    ignore(
      @async.validate_jsonl(oversized, @core.unknown(), _ => (), limits={
        max_line_bytes: 4,
        max_frame_bytes: 20,
      }),
    )
    false
  } catch {
    @async.StreamLimitExceeded::LineTooLong(4) => true
    _ => false
  }
  assert_true(raised)
}

///|
async test "SSE stream stops on malformed input without waiting for DONE or EOF" {
  let reader = @io.MemoryReader() <| writer => {
    writer.write("data: ]\n\n")
    @moon_async.sleep(10000)
  }
  defer reader.close()
  let result = @moon_async.with_timeout_opt(250, () => {
    @async.validate_sse_json_stream(reader, @core.unknown(), _ => ())
  })
  guard result is Some(summary) else {
    fail("reader waited after terminal failure")
  }
  assert_eq(summary.invalid_json, 1)
  assert_eq(summary.events, 1)
  assert_true(!summary.done)
}

///|
async test "SSE stream enforces document and depth limits across frames" {
  let reader = @io.MemoryReader() <| writer => {
    writer.write("data: \"abc\n\ndata: d\n\n")
  }
  defer reader.close()
  let length = @async.validate_sse_json_stream(
    reader,
    @core.unknown(),
    _ => (),
    max_length=4,
  )
  assert_eq(length.invalid_json, 1)
  let nested = @io.MemoryReader() <| writer => {
    writer.write("data: [\n\ndata: [\n\n")
  }
  defer nested.close()
  let depth = @async.validate_sse_json_stream(
    nested,
    @core.unknown(),
    _ => (),
    max_depth=1,
  )
  assert_eq(depth.invalid_json, 1)
}

///|
async test "SSE replaces malformed UTF-8 and preserves split multibyte data" {
  let events : Array[@async.SseEvent] = []
  let reader = @io.MemoryReader() <| writer => {
    writer.write(b"data: \xff\xe4")
    writer.write(b"\xbd\xa0\n\n")
  }
  defer reader.close()
  ignore(@async.read_sse(reader, event => events.push(event)))
  assert_eq(events[0].data, "\u{FFFD}你")
}

///|
async test "SSE handles CRLF across its read-ahead boundary and resets frame budget" {
  let payload = "a".repeat(4089)
  let events : Array[@async.SseEvent] = []
  let reader = @io.MemoryReader() <| writer => {
    writer.write("data: " + payload + "\r\n\r\ndata: second\r\n\r\n")
  }
  defer reader.close()
  let summary = @async.read_sse(reader, event => events.push(event), limits={
    max_line_bytes: 4095,
    max_frame_bytes: 4097,
  })
  assert_eq(summary.events, 2)
  assert_eq(summary.lines_read, 4)
  assert_eq(events[0].data, payload)
  assert_eq(events[1].data, "second")
}

///|
async test "SSE stream finalizes a complete document at EOF with no DONE" {
  let events : Array[@async.SseStreamValidationEvent] = []
  let reader = @io.MemoryReader() <| writer => {
    writer.write("data: {}\n\ndata:  \n\n")
  }
  defer reader.close()
  let summary = @async.validate_sse_json_stream(reader, @core.unknown(), event => {
    events.push(event)
  })
  assert_eq(summary.valid, 1)
  assert_true(!summary.done)
  assert_eq(events.length(), 3)
  assert_true(events[0] is @async.SseStreamPending(_))
  assert_true(events[1] is @async.SseStreamPending(_))
  assert_true(events[2] is @async.SseStreamValid(_, _))
}
