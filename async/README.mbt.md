# moon_zod async

`Betterlol/moon_zod/async` is an optional companion package. It leaves
`Betterlol/moon_zod/core` synchronous and dependency-light. The underlying
MoonBit async runtime is native-first; its Wasm support remains experimental.

## Async refinements

Wrap a normal schema with `async_schema()` and add checks that may perform I/O.
The normal parser runs first, so each check receives transformed and Strip-mode
cleaned JSON. A failing check returns `Some(async_issue(...))`; all check
failures are returned as `IssueCode::Custom` validation errors. `parse_async()`
returns `AsyncParseResult` and does not raise ordinary errors. A raised check
error is collected with its zero-based check index, and later checks still run.
Task cancellation propagates normally.

```mbt nocheck
let user = @moon_zod_async.async_schema(
  @moon_zod.object({ "email": @moon_zod.string().email() }),
).refine_async(value => {
  if email_is_taken(value) {
    Some(@moon_zod_async.async_issue("Email is already registered", path="email"))
  } else {
    None
  }
})

match user.parse_async(input) {
  Ok(clean) => // use clean
  Err(@moon_zod_async.Validation(errors)) => // report validation errors
  Err(@moon_zod_async.Execution(check_errors, errors)) => // handle execution failures and any validation errors
}
```

## JSON Lines streams

`validate_jsonl(reader, schema, handler)` reads one record at a time from an
`@io.Reader`. It waits for `handler` to finish before reading the next record,
providing backpressure without buffering the whole stream. Each non-blank line
emits `Valid`, `InvalidJson`, or `InvalidSchema`. Async refinements can also emit
`ExecutionFailed(line, check_errors, validation_errors)`. The returned
`JsonlSummary.execution_failed` counts these records separately.

Call `async_schema.validate_jsonl(reader, handler)` when each record must also
run asynchronous refinements.

## SSE framing

`read_sse(reader, handler)` accepts CR, LF and CRLF, ignores one leading UTF-8
BOM, and replaces malformed UTF-8 according to SSE decoding rules. Event IDs
carry forward; an empty `id:` resets the ID and an ID containing NUL is ignored.
Only a blank line dispatches a frame. EOF discards incomplete frames, including
an unterminated `[DONE]` frame.

`validate_sse_json()` validates one complete JSON value per frame.
`async_schema.validate_sse_json()` additionally reports
`SseExecutionFailed(event, check_errors, validation_errors)` and increments
`SseValidationSummary.execution_failed` when checks raise.

## Multi-frame SSE JSON

`validate_sse_json_stream(reader, schema, handler)` assembles one raw JSON
document from multiple SSE `data:` frames. It emits `SseStreamPending` for
accepted fragments, including a closed root, and confirms success when it
receives a complete `data: [DONE]` frame or reaches EOF.
The final outcome is `SseStreamValid`, `SseStreamInvalidJson`, or
`SseStreamInvalidSchema`.
Trailing non-whitespace is rejected across frames. A malformed document stops
consumption immediately, so `summary.done` can be false on an early failure.

```mbt nocheck
let reader = @io.MemoryReader() <| writer => {
  writer.write("data: {\"na\n\ndata: me\":\"Ada\"}\n\n")
  writer.write("data: [DONE]\n\n")
}
defer reader.close()
let summary = @moon_zod_async.validate_sse_json_stream(
  reader,
  @moon_zod.object({ "name": @moon_zod.string() }),
  event => { /* handle SseStreamValidationEvent */ },
)
```

This API expects raw JSON fragments. If an SSE protocol wraps each token in a
JSON envelope, use `read_sse()` and extract the token before feeding it to the
core `parse_stream()` parser.

## Resource limits and reader ownership

All reader APIs accept `limits=StreamReadLimits::{ max_line_bytes, max_frame_bytes }`.
Defaults are 65,536 UTF-8 bytes per line and 1,048,576 bytes per SSE frame.
Frame accounting includes comments, ignored fields and one byte per logical
line ending. Both limits must be positive. Oversized input raises
`StreamLimitExceeded::LineTooLong(limit)` or `FrameTooLarge(limit)` before
buffering beyond the configured line/frame budget; I/O and handler errors also
propagate to the caller. JSONL decoding rejects malformed UTF-8.

`validate_sse_json_stream()` also accepts `max_length` and `max_depth`, with the
same defaults and units as core `parse_stream()`. Document-limit failures are
reported as `SseStreamInvalidJson`.

Callbacks are awaited sequentially. The readers use bounded 4 KiB read-ahead,
so input after DONE or an early failure may already have been consumed from the
underlying reader. Treat these APIs as consuming the response; do not resume
raw reading from the same reader afterward. The caller owns and closes the
reader (including on failure) and supplies a timeout when idle connections
must be bounded. None of these APIs closes a borrowed reader automatically.

## Migration

- Handle `Err(Validation(errors))` and `Err(Execution(check_errors, errors))`
  instead of `Err(errors)` from `parse_async()`.
- Handle the new execution-failure variants in exhaustive JSONL/SSE matches.
- Obtain successful core stream results from `finish()`, and successful SSE
  stream results at DONE/EOF; a closed root still emits pending.
- Terminate every SSE frame with a blank line; EOF no longer dispatches it.
- Override the finite defaults for applications that accept larger documents.
