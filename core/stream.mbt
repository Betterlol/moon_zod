///|
/// The result of advancing a single-JSON streaming parser.
///
/// `StreamPending` means more input is required. A parser becomes terminal after
/// it returns any other variant; do not feed more tokens after that point.
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
pub(all) struct StreamParser {
  schema : Schema
  root_path : String
  source : StringBuilder
  mut stack : Array[Char]
  mut started : Bool
  mut in_string : Bool
  mut escaped : Bool
  mut root_scalar : Bool
  mut complete : Bool
  mut result : StreamParseResult?
}

///|
/// Start validating one JSON value from an incremental text stream.
///
/// Each call to `StreamParser::feed()` may contain one LLM token, part of a
/// token, or multiple tokens. JSON strings and escape sequences may cross
/// chunk boundaries. Schema rules run as soon as the complete root value is
/// available; use `finish()` to report an unfinished or scalar-root document.
pub fn Schema::parse_stream(self : Schema, path? : String = "") -> StreamParser {
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
      self.source.write_string(token)
      for c in token.to_array() {
        if self.complete {
          if !is_json_whitespace(c) {
            let result = StreamInvalidJson(
              "Unexpected content after the complete JSON value",
            )
            self.result = Some(result)
            return result
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
            '}' | ']' => {
              let result = StreamInvalidJson("Unexpected closing delimiter")
              self.result = Some(result)
              return result
            }
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
          }
          continue
        }

        match c {
          '"' => self.in_string = true
          '{' | '[' => self.stack.push(c)
          '}' =>
            match self.stack.pop() {
              Some('{') => if self.stack.is_empty() { self.complete = true }
              _ => {
                let result = StreamInvalidJson("Mismatched closing delimiter")
                self.result = Some(result)
                return result
              }
            }
          ']' =>
            match self.stack.pop() {
              Some('[') => if self.stack.is_empty() { self.complete = true }
              _ => {
                let result = StreamInvalidJson("Mismatched closing delimiter")
                self.result = Some(result)
                return result
              }
            }
          _ => ()
        }
      }
      if self.complete {
        self.complete_result()
      } else {
        StreamPending
      }
    }
  }
}

///|
/// Mark the upstream token stream as finished and return its final result.
///
/// This is required for root scalar values such as `42`, `true`, and `null`,
/// whose boundary is the end of input rather than a closing delimiter.
pub fn StreamParser::finish(self : StreamParser) -> StreamParseResult {
  match self.result {
    Some(result) => result
    None => {
      if !self.started {
        let result = StreamInvalidJson("Expected a JSON value")
        self.result = Some(result)
        return result
      }
      if self.in_string || !self.stack.is_empty() {
        let result = StreamInvalidJson("Incomplete JSON input")
        self.result = Some(result)
        return result
      }
      self.complete = true
      self.complete_result()
    }
  }
}

///|
/// Parse the completed JSON source and apply the schema once.
fn StreamParser::complete_result(self : StreamParser) -> StreamParseResult {
  let json = @json.parse(self.source.to_string()) catch {
    _ => {
      let result = StreamInvalidJson("Invalid JSON input")
      self.result = Some(result)
      return result
    }
  }
  let result = match self.schema.parse(json, path=self.root_path) {
    Ok(value) => StreamValid(value)
    Err(errors) => StreamInvalidSchema(errors)
  }
  self.result = Some(result)
  result
}

///|
/// Return whether this character is valid JSON whitespace.
fn is_json_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\n' || c == '\r' || c == '\t'
}
