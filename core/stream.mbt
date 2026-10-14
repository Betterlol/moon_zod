///|
/// The result of advancing a single-JSON streaming parser.
///
/// `StreamPending` means the document has not been finalized. Only `finish()`
/// returns success; `feed()` can reject malformed input early. Other variants
/// are terminal and subsequent calls return the same result.
pub(all) enum StreamParseResult {
  StreamPending
  StreamValid(Json)
  StreamInvalidJson(String)
  StreamInvalidSchema(Array[ValidationError])
}

///|
/// Mutable state for incrementally parsing and validating one JSON value.
///
/// Create this value with `Schema::parse_stream()`, feed arbitrary text chunks
/// with `feed()`, then call `finish()` when the upstream token stream ends.
pub struct StreamParser {
  priv schema : Schema
  priv root_path : String
  priv mut source : StringBuilder
  priv stack : Array[Char]
  priv mut started : Bool
  priv mut in_string : Bool
  priv mut escaped : Bool
  priv mut root_scalar : Bool
  priv mut complete : Bool
  priv mut parsed : Json?
  priv mut source_length : Int32
  priv max_length : Int32
  priv max_depth : Int32
  priv mut result : StreamParseResult?
}

///|
/// Start validating one JSON value from an incremental text stream.
///
/// Each call to `StreamParser::feed()` may contain one LLM token, part of a
/// token, or multiple tokens. JSON strings and escape sequences may cross
/// chunk boundaries. Continue feeding until EOF, then call `finish()` to run
/// schema rules exactly once and confirm that no trailing content was received.
///
/// `max_length` bounds all input in UTF-16 code units (default 1 Mi units).
/// `max_depth` bounds object/array nesting (default 128, range 1..=1024).
/// `max_length` must be positive.
/// Text is buffered until the root closes; whitespace after it is not retained.
pub fn Schema::parse_stream(
  self : Schema,
  path~ : String = "",
  max_length~ : Int32 = 1048576,
  max_depth~ : Int32 = 128,
) -> StreamParser {
  if max_length <= 0 || max_depth <= 0 || max_depth > 1024 {
    abort("parse_stream requires max_length > 0 and max_depth in 1..=1024")
  }
  {
    schema: self,
    root_path: path,
    source: StringBuilder(size_hint=0),
    stack: [],
    started: false,
    in_string: false,
    escaped: false,
    root_scalar: false,
    complete: false,
    parsed: None,
    source_length: 0,
    max_length,
    max_depth,
    result: None,
  }
}

///|
/// Feed the next text chunk into this parser.
///
/// A `StreamInvalidJson` result is reported as soon as an unmatched closing
/// delimiter or trailing non-whitespace is seen. Other JSON syntax errors are
/// reported when the root value closes or when `finish()` is called.
pub fn StreamParser::feed(
  self : StreamParser,
  token : String,
) -> StreamParseResult {
  match self.result {
    Some(result) => result
    None => {
      if token.length() > self.max_length - self.source_length {
        return self.reject("JSON input exceeds max_length")
      }
      self.source_length = self.source_length + token.length()
      if !self.complete {
        self.source.write_string(token)
      }
      for c in token.iter() {
        if self.complete {
          if !is_json_whitespace(c) {
            return self.reject(
              "Unexpected content after the complete JSON value",
            )
          }
          continue
        }

        if !self.started {
          if is_json_whitespace(c) {
            continue
          }
          self.started = true
          match c {
            '{' | '[' => self.stack.push(c)
            '}' | ']' => return self.reject("Unexpected closing delimiter")
            '"' => self.in_string = true
            _ => self.root_scalar = true
          }
          continue
        }

        if self.in_string {
          if self.escaped {
            self.escaped = false
          } else if c == '\\' {
            self.escaped = true
          } else if c == '"' {
            self.in_string = false
            if self.stack.is_empty() {
              self.complete = true
            }
          }
          continue
        }

        if self.root_scalar && self.stack.is_empty() {
          if is_json_whitespace(c) {
            self.complete = true
          } else if c == '}' || c == ']' {
            return self.reject(
              "Unexpected closing delimiter after a JSON scalar",
            )
          }
          continue
        }

        match c {
          '"' => self.in_string = true
          '{' | '[' => {
            if self.stack.length() >= self.max_depth {
              return self.reject("JSON nesting exceeds max_depth")
            }
            self.stack.push(c)
          }
          '}' =>
            match self.stack.pop() {
              Some('{') => if self.stack.is_empty() { self.complete = true }
              _ => return self.reject("Mismatched closing delimiter")
            }
          ']' =>
            match self.stack.pop() {
              Some('[') => if self.stack.is_empty() { self.complete = true }
              _ => return self.reject("Mismatched closing delimiter")
            }
          _ => ()
        }
      }
      if self.complete && self.parsed is None {
        match self.parse_source() {
          Err(result) => return result
          Ok(json) => self.parsed = Some(json)
        }
      }
      StreamPending
    }
  }
}

///|
/// Mark the upstream token stream as finished and return its final result.
///
/// Required for every root type: success is final only at end of input.
pub fn StreamParser::finish(self : StreamParser) -> StreamParseResult {
  match self.result {
    Some(result) => result
    None => {
      if !self.started {
        return self.reject("Expected a JSON value")
      }
      if self.in_string || !self.stack.is_empty() {
        return self.reject("Incomplete JSON input")
      }
      self.complete = true
      let json = match self.parsed {
        Some(json) => json
        None =>
          match self.parse_source() {
            Ok(json) => json
            Err(result) => return result
          }
      }
      let result = match self.schema.parse(json, path=self.root_path) {
        Ok(value) => StreamValid(value)
        Err(errors) => StreamInvalidSchema(errors)
      }
      self.parsed = None
      self.result = Some(result)
      result
    }
  }
}

///|
/// Parse a closed root once, releasing its source buffer afterward.
fn StreamParser::parse_source(
  self : StreamParser,
) -> Result[Json, StreamParseResult] {
  let json = @json.parse(self.source.to_string()) catch {
    _ => return Err(self.reject("Invalid JSON input"))
  }
  self.source = StringBuilder()
  Ok(json)
}

///|
/// Cache a terminal failure and release partially buffered input.
fn StreamParser::reject(
  self : StreamParser,
  message : String,
) -> StreamParseResult {
  let result = StreamInvalidJson(message)
  self.source = StringBuilder()
  self.stack.clear()
  self.parsed = None
  self.result = Some(result)
  result
}

///|
/// Return whether this character is valid JSON whitespace.
fn is_json_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\n' || c == '\r' || c == '\t'
}
