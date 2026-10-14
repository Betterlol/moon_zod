///|
/// Bounded byte-oriented line reading; UTF-8 sequences can cross input chunks.
priv struct LineReader {
  reader : &@io.Reader
  sse : Bool
  max_line_bytes : Int32
  mut chunk : Bytes
  mut offset : Int32
  mut skip_lf : Bool
  mut first_line : Bool
}

///|
fn LineReader::new(
  reader : &@io.Reader,
  sse~ : Bool,
  max_line_bytes~ : Int32,
) -> LineReader {
  {
    reader,
    sse,
    max_line_bytes,
    chunk: b"",
    offset: 0,
    skip_lf: false,
    first_line: true,
  }
}

///|
/// Read at most 4 KiB ahead, accumulating only one bounded line.
/// SSE accepts CR, LF and CRLF; JSONL uses LF and preserves the final record.
async fn LineReader::next(
  self : LineReader,
  frame_limit~ : (Int32, Int32)? = None,
) -> (String, Int32)? {
  let bytes : Array[Byte] = []
  while true {
    if self.offset == self.chunk.length() {
      match self.reader.read_some(max_len=4096) {
        None => {
          if bytes.is_empty() || self.sse {
            return None
          }
          return Some((self.decode(bytes), bytes.length()))
        }
        Some(chunk) => {
          if chunk.is_empty() {
            continue
          }
          self.chunk = chunk
          self.offset = 0
        }
      }
    }
    let byte = self.chunk[self.offset]
    self.offset = self.offset + 1
    if self.skip_lf {
      self.skip_lf = false
      if byte == b'\n' {
        continue
      }
    }
    if byte == b'\n' || (self.sse && byte == b'\r') {
      if frame_limit is Some((remaining, limit)) && bytes.length() >= remaining {
        raise StreamLimitExceeded::FrameTooLarge(limit)
      }
      self.skip_lf = self.sse && byte == b'\r'
      return Some((self.decode(bytes), bytes.length()))
    }
    if bytes.length() >= self.max_line_bytes {
      raise StreamLimitExceeded::LineTooLong(self.max_line_bytes)
    }
    if frame_limit is Some((remaining, limit)) &&
      bytes.length() >= remaining - 1 {
      raise StreamLimitExceeded::FrameTooLarge(limit)
    }
    bytes.push(byte)
  } nobreak {
    None
  }
}

///|
fn LineReader::decode(self : LineReader, bytes : Array[Byte]) -> String raise {
  let bytes = Bytes::from_array(bytes)
  let first_line = self.first_line
  self.first_line = false
  if self.sse {
    @utf8.decode_lossy(bytes, ignore_bom=first_line)
  } else {
    @utf8.decode(bytes)
  }
}
