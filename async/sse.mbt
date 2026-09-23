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
/// The reader does not consume the next frame until this callback completes,
/// preserving backpressure from the consumer to the input stream.
pub type SseHandler = async (SseEvent) -> Unit

///|
/// Counts produced by `read_sse`.
pub(all) struct SseSummary {
  lines_read : Int
  events : Int
  comments : Int
}

///|
/// Read a Server-Sent Events stream one frame at a time.
///
/// This follows the SSE framing rules: CRLF and LF are accepted, comment lines
/// are ignored, field values lose at most one leading space, and a frame is
/// emitted only when it contains at least one `data:` line. A final unterminated
/// frame is emitted at end of input.
pub async fn read_sse(
  reader : &@io.Reader,
  on_event : SseHandler,
) -> SseSummary {
  let mut lines_read = 0
  let mut events = 0
  let mut comments = 0
  let mut data_lines : Array[String] = []
  let mut event_type = ""
  let mut last_event_id : String? = None

  while reader.read_until("\n") is Some(raw_line) {
    lines_read = lines_read + 1
    let line = raw_line.trim_end(chars="\r").to_owned()
    if line.is_empty() {
      if emit_sse_event(event_type, data_lines, last_event_id, on_event) {
        events = events + 1
      }
      data_lines = []
      event_type = ""
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
      "id" => last_event_id = Some(value)
      _ => ()
    }
  }

  if emit_sse_event(event_type, data_lines, last_event_id, on_event) {
    events = events + 1
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
/// Emit an event if its frame contains data.
async fn emit_sse_event(
  event_type : String,
  data_lines : Array[String],
  last_event_id : String?,
  on_event : SseHandler,
) -> Bool {
  if data_lines.is_empty() {
    false
  } else {
    let event = if event_type.is_empty() { "message" } else { event_type }
    on_event(SseEvent::{
      event,
      data: data_lines.join("\n"),
      id: last_event_id,
    })
    true
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
}

///|
/// Callback invoked for each JSON validation outcome from an SSE frame.
pub type SseValidationHandler = async (SseValidationEvent) -> Unit

///|
/// Counts produced by SSE JSON validation.
pub(all) struct SseValidationSummary {
  lines_read : Int
  events : Int
  comments : Int
  done : Bool
  valid : Int
  invalid_json : Int
  invalid_schema : Int
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
  root_path? : String = "",
) -> SseValidationSummary {
  let mut done = false
  let mut valid = 0
  let mut invalid_json = 0
  let mut invalid_schema = 0
  let sse_summary = read_sse(reader, event => {
    if event.data == "[DONE]" {
      done = true
      on_event(SseDone(event))
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
    }
  })
  {
    lines_read: sse_summary.lines_read,
    events: sse_summary.events,
    comments: sse_summary.comments,
    done,
    valid,
    invalid_json,
    invalid_schema,
  }
}

///|
/// Read SSE JSON frames and run asynchronous schema refinements.
pub async fn AsyncSchema::validate_sse_json(
  self : AsyncSchema,
  reader : &@io.Reader,
  on_event : SseValidationHandler,
  root_path? : String = "",
) -> SseValidationSummary {
  let mut done = false
  let mut valid = 0
  let mut invalid_json = 0
  let mut invalid_schema = 0
  let sse_summary = read_sse(reader, event => {
    if event.data == "[DONE]" {
      done = true
      on_event(SseDone(event))
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
            Err(errors) => {
              invalid_schema = invalid_schema + 1
              on_event(SseInvalidSchema(event, errors))
            }
          }
      }
    }
  })
  {
    lines_read: sse_summary.lines_read,
    events: sse_summary.events,
    comments: sse_summary.comments,
    done,
    valid,
    invalid_json,
    invalid_schema,
  }
}

///|
/// Parse one complete JSON payload without raising on malformed input.
fn parse_sse_json(source : String) -> Json? {
  let json = @json.parse(source) catch { _ => return None }
  Some(json)
}
