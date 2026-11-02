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
