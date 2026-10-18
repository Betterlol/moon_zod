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
  async_schema(schema).validate_sse_json(reader, on_event, root_path~, limits~)
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
