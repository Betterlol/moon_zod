///|
/// An event emitted while validating a JSON Lines input stream.
///
/// Events are delivered in input order. `line` is one-based and counts blank
/// lines too, so it can be used directly in diagnostics.
pub(all) enum JsonlEvent {
  Valid(Int, Json)
  InvalidJson(Int, String)
  InvalidSchema(Int, Array[@core.ValidationError])
}

///|
/// Callback invoked for each non-blank JSON Lines record.
///
/// The next record is not read until this callback finishes, providing natural
/// backpressure to the upstream reader.
pub type JsonlHandler = async (JsonlEvent) -> Unit

///|
/// Counts produced by `validate_jsonl`.
pub(all) struct JsonlSummary {
  lines_read : Int
  records : Int
  valid : Int
  invalid_json : Int
  invalid_schema : Int
  skipped : Int
}

///|
/// Read, parse, and validate a JSON Lines stream incrementally.
///
/// The reader is consumed one line at a time. Blank lines are skipped. A
/// malformed JSON record produces `InvalidJson`; a parsed value that fails the
/// schema produces `InvalidSchema`; successful records contain the cleaned
/// value returned by `Schema::parse`.
///
/// `root_path` is forwarded to the schema for every record. Use it when this
/// stream is nested beneath a larger validation path.
pub async fn validate_jsonl(
  reader : &@io.Reader,
  schema : @core.Schema,
  on_event : JsonlHandler,
  root_path? : String = "",
) -> JsonlSummary {
  let mut lines_read = 0
  let mut records = 0
  let mut valid = 0
  let mut invalid_json = 0
  let mut invalid_schema = 0
  let mut skipped = 0

  while reader.read_until("\n") is Some(line) {
    lines_read = lines_read + 1
    let source = line.trim().to_owned()
    if source.is_empty() {
      skipped = skipped + 1
      continue
    }

    records = records + 1
    let json = @json.parse(source) catch {
      _ => {
        invalid_json = invalid_json + 1
        on_event(InvalidJson(lines_read, source))
        continue
      }
    }
    match schema.parse(json, path=root_path) {
      Ok(clean) => {
        valid = valid + 1
        on_event(Valid(lines_read, clean))
      }
      Err(errors) => {
        invalid_schema = invalid_schema + 1
        on_event(InvalidSchema(lines_read, errors))
      }
    }
  }

  { lines_read, records, valid, invalid_json, invalid_schema, skipped, }
}

///|
/// Read and validate a JSON Lines stream with an `AsyncSchema`.
///
/// This has the same streaming and backpressure semantics as `validate_jsonl`,
/// but runs the wrapped schema's asynchronous refinements after each successful
/// synchronous parse.
pub async fn AsyncSchema::validate_jsonl(
  self : AsyncSchema,
  reader : &@io.Reader,
  on_event : JsonlHandler,
  root_path? : String = "",
) -> JsonlSummary {
  let mut lines_read = 0
  let mut records = 0
  let mut valid = 0
  let mut invalid_json = 0
  let mut invalid_schema = 0
  let mut skipped = 0

  while reader.read_until("\n") is Some(line) {
    lines_read = lines_read + 1
    let source = line.trim().to_owned()
    if source.is_empty() {
      skipped = skipped + 1
      continue
    }

    records = records + 1
    let json = @json.parse(source) catch {
      _ => {
        invalid_json = invalid_json + 1
        on_event(InvalidJson(lines_read, source))
        continue
      }
    }
    match self.parse_async(json, root_path~) {
      Ok(clean) => {
        valid = valid + 1
        on_event(Valid(lines_read, clean))
      }
      Err(errors) => {
        invalid_schema = invalid_schema + 1
        on_event(InvalidSchema(lines_read, errors))
      }
    }
  }

  { lines_read, records, valid, invalid_json, invalid_schema, skipped, }
}
