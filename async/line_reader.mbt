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
  let parts : Array[BytesView] = []
  let mut length = 0
  while true {
    if self.offset == self.chunk.length() {
      match self.reader.read_some(max_len=4096) {
        None => {
          if length == 0 || self.sse {
            return None
          }
          return Some((self.decode(parts, b"", length), length))
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
    if self.skip_lf {
      self.skip_lf = false
      if self.chunk[self.offset] == b'\n' {
        self.offset += 1
        continue
      }
    }
    let start = self.offset
    while self.offset < self.chunk.length() {
      let byte = self.chunk[self.offset]
      let size = length + (self.offset - start)
      if byte == b'\n' || (self.sse && byte == b'\r') {
        if frame_limit is Some((remaining, limit)) && size >= remaining {
          raise StreamLimitExceeded::FrameTooLarge(limit)
        }
        let tail = self.chunk[start:self.offset]
        self.offset += 1
        self.skip_lf = self.sse && byte == b'\r'
        return Some((self.decode(parts, tail, size), size))
      }
      if size >= self.max_line_bytes {
        raise StreamLimitExceeded::LineTooLong(self.max_line_bytes)
      }
      if frame_limit is Some((remaining, limit)) && size >= remaining - 1 {
        raise StreamLimitExceeded::FrameTooLarge(limit)
      }
      self.offset += 1
    }
    let part = self.chunk[start:self.offset]
    parts.push(part)
    length += part.length()
  } nobreak {
    None
  }
}

///|
/// Decode a contiguous line directly; join spanning chunks with one allocation.
fn LineReader::decode(
  self : LineReader,
  parts : Array[BytesView],
  tail : BytesView,
  length : Int32,
) -> String raise {
  let bytes : BytesView = if parts.is_empty() {
    tail
  } else {
    let buffer = FixedArray::make(length, b'\x00')
    let mut offset = 0
    for part in parts {
      buffer.blit_from_bytesview(offset, part)
      offset += part.length()
    }
    buffer.blit_from_bytesview(offset, tail)
    buffer.unsafe_reinterpret_as_bytes()[:]
  }
  let first_line = self.first_line
  self.first_line = false
  if self.sse {
    @utf8.decode_lossy(bytes, ignore_bom=first_line)
  } else {
    @utf8.decode(bytes)
  }
}
