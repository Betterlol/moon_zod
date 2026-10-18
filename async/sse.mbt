///|
/// A Server-Sent Event decoded from an event-stream frame.
///
/// `event` defaults to `"message"`. Multiple `data:` lines are joined with a
/// newline. `id` is the most recently received SSE event ID and therefore can
/// be carried forward from a preceding frame, as required by the SSE protocol.
pub(all) struct SseEvent {
  event : String
  data : String
  id : String?
}

///|
/// Callback invoked for each Server-Sent Event frame containing data.
///
/// Frames are delivered sequentially, awaiting each callback. Input may be
/// prefetched by up to 4 KiB; no further read occurs while a callback is running.
pub type SseHandler = async (SseEvent) -> Unit

///|
/// Callback that can stop SSE consumption after the current frame.
type SseControlHandler = async (SseEvent) -> Bool

///|
/// Counts produced by `read_sse`.
pub(all) struct SseSummary {
  lines_read : Int32
  events : Int32
  comments : Int32
}

///|
/// Read a Server-Sent Events stream one frame at a time.
///
/// This follows the SSE framing rules: CR, CRLF and LF are accepted, comment lines
/// are ignored, field values lose at most one leading space, and a frame is
/// emitted only when it contains at least one `data:` line and ends in a blank
/// line. EOF discards any unfinished frame. One leading UTF-8 BOM is ignored.
/// The caller owns the reader; input may be prefetched by up to 4 KiB.
pub async fn read_sse(
  reader : &@io.Reader,
  on_event : SseHandler,
  limits~ : StreamReadLimits = StreamReadLimits::default(),
) -> SseSummary {
  read_sse_until(
    reader,
    event => {
      on_event(event)
      true
    },
    limits~,
  )
}

///|
/// Read SSE frames until EOF or a callback asks to stop after its frame.
async fn read_sse_until(
  reader : &@io.Reader,
  on_event : SseControlHandler,
  limits~ : StreamReadLimits,
) -> SseSummary {
  limits.check()
  let lines = LineReader::new(
    reader,
    sse=true,
    max_line_bytes=limits.max_line_bytes,
  )
  let mut lines_read = 0
  let mut events = 0
  let mut comments = 0
  let mut data_lines : Array[String] = []
  let mut event_type = ""
  let mut last_event_id : String? = None
  let mut frame_bytes = 0

  while lines.next(
          frame_limit=Some(
            (limits.max_frame_bytes - frame_bytes, limits.max_frame_bytes),
          ),
        )
        is Some((line, line_bytes)) {
    lines_read = lines_read + 1
    if line_bytes >= limits.max_frame_bytes - frame_bytes {
      raise StreamLimitExceeded::FrameTooLarge(limits.max_frame_bytes)
    }
    frame_bytes = frame_bytes + line_bytes + 1
    if line.is_empty() {
      match
        emit_sse_event_until(event_type, data_lines, last_event_id, on_event) {
        None => ()
        Some(keep_reading) => {
          events = events + 1
          if !keep_reading {
            return { lines_read, events, comments, }
          }
        }
      }
      data_lines = []
      event_type = ""
      frame_bytes = 0
      continue
    }
    if line.has_prefix(":") {
      comments = comments + 1
      continue
    }

    let (field, value) = split_sse_field(line)
    match field {
      "data" => data_lines.push(value)
      "event" => event_type = value
      "id" => if !value.contains("\u{0000}") { last_event_id = Some(value) }
      _ => ()
    }
  }

  { lines_read, events, comments, }
}

///|
/// Split an SSE field line and remove its optional single leading value space.
fn split_sse_field(line : String) -> (String, String) {
  match line.split_once(":") {
    Some((field, raw_value)) => {
      let value = if raw_value.has_prefix(" ") {
        raw_value[1:]
      } else {
        raw_value
      }
      (field.to_owned(), value.to_owned())
    }
    None => (line, "")
  }
}

///|
/// Emit an event if its frame contains data and report whether reading continues.
async fn emit_sse_event_until(
  event_type : String,
  data_lines : Array[String],
  last_event_id : String?,
  on_event : SseControlHandler,
) -> Bool? {
  if data_lines.is_empty() {
    None
  } else {
    let event = if event_type.is_empty() { "message" } else { event_type }
    Some(
      on_event(SseEvent::{
        event,
        data: data_lines.join("\n"),
        id: last_event_id,
      }),
    )
  }
}

///|
/// An outcome from validating a JSON payload carried by a Server-Sent Event.
///
/// A `data: [DONE]` sentinel is reported as `SseDone` instead of being parsed
/// as JSON. `SseValid` contains the schema-cleaned JSON value.
pub(all) enum SseValidationEvent {
  SseDone(SseEvent)
  SseValid(SseEvent, Json)
  SseInvalidJson(SseEvent)
  SseInvalidSchema(SseEvent, Array[@core.ValidationError])
  SseExecutionFailed(
    SseEvent,
    Array[AsyncCheckError],
    Array[@core.ValidationError]
  )
}

///|
/// Callback invoked for each JSON validation outcome from an SSE frame.
pub type SseValidationHandler = async (SseValidationEvent) -> Unit

///|
/// Counts produced by SSE JSON validation.
pub(all) struct SseValidationSummary {
  lines_read : Int32
  events : Int32
  comments : Int32
  done : Bool
  valid : Int32
  invalid_json : Int32
  invalid_schema : Int32
  execution_failed : Int32
}

///|
/// Read SSE frames whose `data:` payloads are complete JSON values and validate
/// them with a synchronous schema.
///
/// This is suitable for SSE protocols that send one JSON envelope per frame.
/// For token-delta protocols, use `read_sse` and validate the assembled value
/// when the protocol marks it complete.
pub async fn validate_sse_json(
  reader : &@io.Reader,
  schema : @core.Schema,
  on_event : SseValidationHandler,
  root_path~ : String = "",
  limits~ : StreamReadLimits = StreamReadLimits::default(),
) -> SseValidationSummary {
  let mut done = false
  let mut valid = 0
  let mut invalid_json = 0
  let mut invalid_schema = 0
  let sse_summary = read_sse_until(
    reader,
    event => {
      if event.data == "[DONE]" {
        done = true
        on_event(SseDone(event))
        false
      } else {
        match parse_sse_json(event.data) {
          None => {
            invalid_json = invalid_json + 1
            on_event(SseInvalidJson(event))
          }
          Some(json) =>
            match schema.parse(json, path=root_path) {
              Ok(clean) => {
                valid = valid + 1
                on_event(SseValid(event, clean))
              }
              Err(errors) => {
                invalid_schema = invalid_schema + 1
                on_event(SseInvalidSchema(event, errors))
              }
            }
        }
        true
      }
    },
    limits~,
  )
  {
    lines_read: sse_summary.lines_read,
    events: sse_summary.events,
    comments: sse_summary.comments,
    done,
    valid,
    invalid_json,
    invalid_schema,
    execution_failed: 0,
  }
}

///|
/// Read SSE JSON frames and run asynchronous schema refinements.
pub async fn AsyncSchema::validate_sse_json(
  self : AsyncSchema,
  reader : &@io.Reader,
  on_event : SseValidationHandler,
  root_path~ : String = "",
  limits~ : StreamReadLimits = StreamReadLimits::default(),
) -> SseValidationSummary {
  let mut done = false
  let mut valid = 0
  let mut invalid_json = 0
  let mut invalid_schema = 0
  let mut execution_failed = 0
  let sse_summary = read_sse_until(
    reader,
    event => {
      if event.data == "[DONE]" {
        done = true
        on_event(SseDone(event))
        false
      } else {
        match parse_sse_json(event.data) {
          None => {
            invalid_json = invalid_json + 1
            on_event(SseInvalidJson(event))
          }
          Some(json) =>
            match self.parse_async(json, root_path~) {
              Ok(clean) => {
                valid = valid + 1
                on_event(SseValid(event, clean))
              }
              Err(Validation(errors)) => {
                invalid_schema = invalid_schema + 1
                on_event(SseInvalidSchema(event, errors))
              }
              Err(Execution(execution_errors, errors)) => {
                execution_failed = execution_failed + 1
                on_event(SseExecutionFailed(event, execution_errors, errors))
              }
            }
        }
        true
      }
    },
    limits~,
  )
  {
    lines_read: sse_summary.lines_read,
    events: sse_summary.events,
    comments: sse_summary.comments,
    done,
    valid,
    invalid_json,
    invalid_schema,
    execution_failed,
  }
}

///|
/// Parse one complete JSON payload without raising on malformed input.
fn parse_sse_json(source : String) -> Json? {
  let json = @json.parse(source) catch { _ => return None }
  Some(json)
}

///|
/// An outcome from assembling one JSON value across multiple SSE `data:` frames.
///
/// `SseStreamPending` is emitted for each accepted fragment until the JSON root
/// value is finalized. `SseStreamDone` is emitted after the `[DONE]` sentinel has
/// finished the parser, so a scalar root can become valid immediately before it.
pub(all) enum SseStreamValidationEvent {
  SseStreamPending(SseEvent)
  SseStreamDone(SseEvent)
  SseStreamValid(SseEvent, Json)
  SseStreamInvalidJson(SseEvent, String)
  SseStreamInvalidSchema(SseEvent, Array[@core.ValidationError])
  SseStreamExecutionFailed(
    SseEvent,
    Array[AsyncCheckError],
    Array[@core.ValidationError]
  )
}

///|
/// Callback invoked while validating one JSON value assembled from SSE frames.
///
/// Each callback is awaited before advancing; input read-ahead is at most 4 KiB.
pub type SseStreamValidationHandler = async (SseStreamValidationEvent) -> Unit

///|
/// Counts produced by `validate_sse_json_stream`.
pub(all) struct SseStreamValidationSummary {
  lines_read : Int32
  events : Int32
  comments : Int32
  fragments : Int32
  done : Bool
  valid : Int32
  invalid_json : Int32
  invalid_schema : Int32
  execution_failed : Int32
}

///|
/// Internal category used to update an SSE stream validation summary.
priv enum SseStreamResultKind {
  Pending
  Valid
  InvalidJson
  InvalidSchema
  ExecutionFailed
}

///|
/// Terminal outcome counts shared by DONE, EOF and early failure handling.
priv struct SseStreamCounts {
  mut valid : Int32
  mut invalid_json : Int32
  mut invalid_schema : Int32
  mut execution_failed : Int32
}

///|
/// Emit the public event for a completed incremental parser step.
async fn emit_sse_stream_result(
  schema : AsyncSchema,
  result : @core.StreamParseResult,
  event : SseEvent,
  on_event : SseStreamValidationHandler,
  root_path : String,
) -> SseStreamResultKind {
  match result {
    StreamPending => {
      on_event(SseStreamPending(event))
      Pending
    }
    StreamValid(value) =>
      match schema.check_clean_async(value, root_path~) {
        Ok(clean) => {
          on_event(SseStreamValid(event, clean))
          Valid
        }
        Err(Validation(errors)) => {
          on_event(SseStreamInvalidSchema(event, errors))
          InvalidSchema
        }
        Err(Execution(execution_errors, errors)) => {
          on_event(SseStreamExecutionFailed(event, execution_errors, errors))
          ExecutionFailed
        }
      }
    StreamInvalidJson(message) => {
      on_event(SseStreamInvalidJson(event, message))
      InvalidJson
    }
    StreamInvalidSchema(errors) => {
      on_event(SseStreamInvalidSchema(event, errors))
      InvalidSchema
    }
  }
}

///|
/// Update counters after one incremental parser result.
fn SseStreamCounts::record(
  self : SseStreamCounts,
  kind : SseStreamResultKind,
) -> Bool {
  match kind {
    Pending => return false
    Valid => self.valid += 1
    InvalidJson => self.invalid_json += 1
    InvalidSchema => self.invalid_schema += 1
    ExecutionFailed => self.execution_failed += 1
  }
  true
}

///|
/// Assemble and validate one JSON document whose raw text is split across SSE
/// `data:` frames.
///
/// Each non-`[DONE]` frame contributes its `data` payload directly to the
/// parser, so a fragment may end in the middle of a JSON string or escape
/// sequence. `[DONE]` and end-of-file finalize the parser and confirm success.
/// Non-whitespace after the JSON root is rejected even in a later frame.
/// A terminal failure stops consumption immediately without waiting for DONE.
/// The caller owns the reader and should close it on return or failure; up to
/// 4 KiB may already have been prefetched. Use a caller timeout for idle streams.
///
/// This accepts raw JSON fragments. Protocols such as OpenAI's chat-completion
/// SSE, whose frames contain JSON envelopes around a delta, should call
/// `read_sse()` and extract the delta before feeding it to a stream parser.
pub async fn validate_sse_json_stream(
  reader : &@io.Reader,
  schema : @core.Schema,
  on_event : SseStreamValidationHandler,
  root_path~ : String = "",
  limits~ : StreamReadLimits = StreamReadLimits::default(),
  max_length~ : Int32 = 1048576,
  max_depth~ : Int32 = 128,
) -> SseStreamValidationSummary {
  async_schema(schema).validate_sse_json_stream(
    reader,
    on_event,
    root_path~,
    limits~,
    max_length~,
    max_depth~,
  )
}

///|
/// Assemble one SSE JSON document, then run asynchronous refinements exactly once.
/// Checks receive schema-cleaned output only at DONE/EOF. Invalid JSON or a
/// synchronous schema failure skips checks. Execution failures are reported as
/// `SseStreamExecutionFailed`, preserving any validation issues. Reader ownership,
/// buffering limits and cancellation follow `validate_sse_json_stream`.
pub async fn AsyncSchema::validate_sse_json_stream(
  self : AsyncSchema,
  reader : &@io.Reader,
  on_event : SseStreamValidationHandler,
  root_path~ : String = "",
  limits~ : StreamReadLimits = StreamReadLimits::default(),
  max_length~ : Int32 = 1048576,
  max_depth~ : Int32 = 128,
) -> SseStreamValidationSummary {
  let parser = self.schema.parse_stream(path=root_path, max_length~, max_depth~)
  let mut fragments = 0
  let mut done = false
  let counts : SseStreamCounts = {
    valid: 0,
    invalid_json: 0,
    invalid_schema: 0,
    execution_failed: 0,
  }
  let mut terminal = false
  let mut last_fragment : SseEvent? = None

  let sse_summary = read_sse_until(
    reader,
    event => {
      if event.data == "[DONE]" {
        done = true
        if !terminal {
          terminal = counts.record(
            emit_sse_stream_result(
              self,
              parser.finish(),
              event,
              on_event,
              root_path,
            ),
          )
        }
        on_event(SseStreamDone(event))
        false
      } else if !terminal {
        fragments = fragments + 1
        last_fragment = Some(event)
        let kind = emit_sse_stream_result(
          self,
          parser.feed(event.data),
          event,
          on_event,
          root_path,
        )
        terminal = counts.record(kind)
        !terminal
      } else {
        false
      }
    },
    limits~,
  )

  if !done && !terminal {
    let event = match last_fragment {
      Some(event) => event
      None => empty_sse_event()
    }
    ignore(
      counts.record(
        emit_sse_stream_result(
          self,
          parser.finish(),
          event,
          on_event,
          root_path,
        ),
      ),
    )
  }

  {
    lines_read: sse_summary.lines_read,
    events: sse_summary.events,
    comments: sse_summary.comments,
    fragments,
    done,
    valid: counts.valid,
    invalid_json: counts.invalid_json,
    invalid_schema: counts.invalid_schema,
    execution_failed: counts.execution_failed,
  }
}

///|
/// Create the synthetic event used to report an empty SSE response at EOF.
fn empty_sse_event() -> SseEvent {
  { event: "message", data: "", id: None, }
}
