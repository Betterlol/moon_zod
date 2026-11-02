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
