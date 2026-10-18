///|
priv enum StreamApi {
  Jsonl
  Sse
  Assembled
}

///|
// Implementing Reader requires its buffer hook; keep this confined to the fixture.
#warnings("-alert_internal")
priv struct ObservedReader {
  buffer : @io.ReaderBuffer
  chunks : Array[Bytes]
  mut chunk_index : Int32
  mut chunk_offset : Int32
  mut reads : Int32
  failure : Error?
  block_at_end : Bool
}

///|
#warnings("-alert_internal")
fn observed_reader(
  chunks : Array[Bytes],
  failure~ : Error? = None,
  block_at_end~ : Bool = false,
) -> ObservedReader {
  {
    buffer: @io.ReaderBuffer::new(),
    chunks,
    chunk_index: 0,
    chunk_offset: 0,
    reads: 0,
    failure,
    block_at_end,
  }
}

///|
impl @io.Reader for ObservedReader with fn _get_internal_buffer(self) {
  self.buffer
}

///|
impl @io.Reader for ObservedReader with fn _direct_read(
  self,
  dst,
  offset~,
  max_len~,
) {
  self.reads += 1
  if self.chunk_index == self.chunks.length() {
    if self.block_at_end {
      @moon_async.sleep(10000)
    }
    if self.failure is Some(error) {
      raise error
    }
    return 0
  }
  let chunk = self.chunks[self.chunk_index]
  let remaining = chunk.length() - self.chunk_offset
  let count = if remaining < max_len { remaining } else { max_len }
  for i in 0..<count {
    dst[offset + i] = chunk[self.chunk_offset + i]
  }
  self.chunk_offset += count
  if self.chunk_offset == chunk.length() {
    self.chunk_index += 1
    self.chunk_offset = 0
  }
  count
}

///|
async fn consume_stream(
  api : StreamApi,
  reader : &@io.Reader,
  handler : async () -> Unit,
) -> Unit {
  match api {
    Jsonl =>
      ignore(@async.validate_jsonl(reader, @core.unknown(), _ => handler()))
    Sse =>
      ignore(@async.validate_sse_json(reader, @core.unknown(), _ => handler()))
    Assembled =>
      ignore(
        @async.validate_sse_json_stream(reader, @core.unknown(), _ => handler()),
      )
  }
}

///|
fn stream_chunks(api : StreamApi) -> Array[Bytes] {
  match api {
    Jsonl => [b"1\n", b"2\n"]
    Sse | Assembled => [b"data: 1\n\n", b"data: 2\n\n"]
  }
}

///|
async test "stream adapters await handlers before another underlying read" {
  for api in [Jsonl, Sse, Assembled] {
    let reader = observed_reader(stream_chunks(api))
    let calls : Array[Int32] = []
    consume_stream(api, reader, () => {
      calls.push(1)
      if calls.length() == 1 {
        assert_eq(reader.reads, 1)
        @moon_async.pause()
        assert_eq(reader.reads, 1)
      }
    })
    assert_eq(calls.length(), if api is Assembled { 3 } else { 2 })
  }
}

///|
async test "stream adapters preserve reader failures without finalizing partial input" {
  for api in [Jsonl, Sse, Assembled] {
    let reader = observed_reader(
      [stream_chunks(api)[0]],
      failure=Some(Failure::Failure("reader failed")),
    )
    let calls : Array[Int32] = []
    let raised = try {
      consume_stream(api, reader, () => calls.push(1))
      false
    } catch {
      Failure::Failure("reader failed") => true
      _ => false
    }
    assert_true(raised)
    assert_eq(calls.length(), 1)
  }
}

///|
async test "stream adapters propagate handler failures and stop reading" {
  for api in [Jsonl, Sse, Assembled] {
    let reader = observed_reader(stream_chunks(api))
    let raised = try {
      consume_stream(api, reader, () => raise Failure::Failure("handler failed"))
      false
    } catch {
      Failure::Failure("handler failed") => true
      _ => false
    }
    assert_true(raised)
    assert_eq(reader.reads, 1)
  }
}

///|
async test "stream adapters propagate cancellation while awaiting input" {
  for api in [Jsonl, Sse, Assembled] {
    let chunk = match api {
      Jsonl => b"1"
      Sse | Assembled => b"data: 1\n"
    }
    let reader = observed_reader([chunk], block_at_end=true)
    let calls : Array[Int32] = []
    let result = @moon_async.with_timeout_opt(100, () => {
      consume_stream(api, reader, () => calls.push(1))
    })
    assert_true(result is None)
    assert_eq(calls.length(), 0)
    assert_eq(reader.reads, 2)
  }
}

///|
async test "stream adapters propagate cancellation while awaiting handlers" {
  for api in [Jsonl, Sse, Assembled] {
    let reader = observed_reader(stream_chunks(api))
    let result = @moon_async.with_timeout_opt(100, () => {
      consume_stream(api, reader, () => @moon_async.sleep(10000))
    })
    assert_true(result is None)
    assert_eq(reader.reads, 1)
  }
}

///|
async test "assembled SSE cancellation skips later refinements and terminal events" {
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
  let reader = observed_reader([b"data: {}\n\ndata: [DONE]\n\n"])
  let events : Array[@async.SseStreamValidationEvent] = []
  let result = @moon_async.with_timeout_opt(100, () => {
    schema.validate_sse_json_stream(reader, event => events.push(event))
  })
  assert_true(result is None)
  assert_eq(calls.length(), 0)
  assert_eq(events.length(), 1)
  assert_true(events[0] is @async.SseStreamPending(_))
}

///|
async test "async adapters transform stripped objects once before refinements" {
  for api in [Jsonl, Sse, Assembled] {
    let transforms : Array[Json] = []
    let checks : Array[Json] = []
    let base = @core.object({ "name": @core.string() }).transform(clean => {
      transforms.push(clean)
      Ok(Json::string("clean"))
    })
    let schema = @async.async_schema(base).refine_async(clean => {
      checks.push(clean)
      None
    })
    let payload = "{\"name\":\"Ada\",\"extra\":1}"
    let reader = @io.MemoryReader() <| writer => {
      writer.write(
        if api is Jsonl {
          payload + "\n"
        } else {
          "data: " + payload + "\n\n"
        },
      )
    }
    defer reader.close()
    match api {
      Jsonl => ignore(schema.validate_jsonl(reader, _ => ()))
      Sse => ignore(schema.validate_sse_json(reader, _ => ()))
      Assembled => ignore(schema.validate_sse_json_stream(reader, _ => ()))
    }
    assert_eq(transforms, [Json::object({ "name": Json::string("Ada") })])
    assert_eq(checks, [Json::string("clean")])
  }
}

///|
async test "SSE parsing is invariant across every byte split of UTF8 BOM and CRLF" {
  let input = b"\xef\xbb\xbfid: x\r\ndata: \xe4\xbd\xa0\r\n\r\n"
  for split in 1..<input.length() {
    let reader = observed_reader([
      input[:split].to_owned(),
      input[split:].to_owned(),
    ])
    let events : Array[@async.SseEvent] = []
    let summary = @async.read_sse(reader, event => events.push(event))
    assert_eq(summary.events, 1)
    assert_eq(events[0].data, "你")
    assert_eq(events[0].id, Some("x"))
  }
}

///|
async test "JSONL decodes UTF8 across read-ahead boundaries and an unterminated final line" {
  let value = "a".repeat(4094) + "你" + "z"
  let reader = @io.MemoryReader() <| writer => {
    writer.write("\"" + value + "\"")
  }
  defer reader.close()
  let events : Array[@async.JsonlEvent] = []
  let summary = @async.validate_jsonl(reader, @core.string(), event => {
    events.push(event)
  })
  assert_eq(summary.valid, 1)
  guard events[0] is @async.Valid(1, String(clean)) else {
    fail("expected trailing record")
  }
  assert_eq(clean, value)
}

///|
async test "SSE spanning chunks enforces the exact raw frame budget" {
  let payload = "a".repeat(4088) + "你"
  let input = "data: " + payload + "\n\n"
  // UTF-8 raw length is 4099 bytes, including two logical line endings.
  let reader = @io.MemoryReader() <| writer => { writer.write(input) }
  defer reader.close()
  let events : Array[@async.SseEvent] = []
  ignore(
    @async.read_sse(reader, event => events.push(event), limits={
      max_line_bytes: 5000,
      max_frame_bytes: 4099,
    }),
  )
  assert_eq(events[0].data, payload)
  let oversized = @io.MemoryReader() <| writer => { writer.write(input) }
  defer oversized.close()
  let raised = try {
    ignore(
      @async.read_sse(oversized, _ => (), limits={
        max_line_bytes: 5000,
        max_frame_bytes: 4098,
      }),
    )
    false
  } catch {
    @async.StreamLimitExceeded::FrameTooLarge(4098) => true
    _ => false
  }
  assert_true(raised)
}

///|
async test "JSONL rejects malformed UTF8 after a read-ahead boundary" {
  let reader = @io.MemoryReader() <| writer => {
    writer.write(b" ".repeat(4096))
    writer.write(b"\xff\n")
  }
  defer reader.close()
  let calls : Array[Int32] = []
  let raised = try {
    ignore(@async.validate_jsonl(reader, @core.unknown(), _ => calls.push(1)))
    false
  } catch {
    @utf8.Malformed(_) => true
    _ => false
  }
  assert_true(raised)
  assert_eq(calls.length(), 0)
}
