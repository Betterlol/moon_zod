///|
/// A lossless path segment distinguishes literal object keys from array indices.
pub(all) enum PathSegment {
  Field(String)
  Index(Int32)
} derive(Debug, Eq)

///|
fn path_key(key : String) -> String {
  let chars = key.to_array()
  if chars.is_empty() {
    return "[\"\"]"
  }
  let simple = chars.all(fn(c) {
    (c >= 'a' && c <= 'z') ||
    (c >= 'A' && c <= 'Z') ||
    (c >= '0' && c <= '9') ||
    c == '_'
  })
  if simple {
    key
  } else {
    "[" + Json::string(key).stringify() + "]"
  }
}

///|
/// Decode the canonical path notation, including quoted keys and indices.
pub fn parse_path(path : String) -> Array[PathSegment] {
  let chars = path.to_array()
  let result : Array[PathSegment] = []
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '.' {
      i = i + 1
      continue
    }
    if chars[i] != '[' {
      let start = i
      while i < chars.length() && chars[i] != '.' && chars[i] != '[' {
        i = i + 1
      }
      result.push(Field(chars_to_string(chars, start, i)))
      continue
    }
    let start = i + 1
    i = start
    let mut quoted = false
    let mut escaped = false
    while i < chars.length() {
      let c = chars[i]
      if escaped {
        escaped = false
      } else if quoted && c == '\\' {
        escaped = true
      } else if c == '"' {
        quoted = !quoted
      } else if !quoted && c == ']' {
        break
      }
      i = i + 1
    }
    let content = chars_to_string(chars, start, i)
    if content.has_prefix("\"") {
      let key = @json.parse(content) catch { _ => Json::string(content) }
      match key {
        String(key) => result.push(Field(key))
        _ => result.push(Field(content))
      }
    } else {
      let mut index = 0
      let mut numeric = !content.is_empty()
      for c in content.to_array() {
        if c < '0' || c > '9' || index > 214748364 {
          numeric = false
          break
        }
        let digit = c.to_int() - 48
        if index == 214748364 && digit > 7 {
          numeric = false
          break
        }
        index = index * 10 + digit
      }
      result.push(if numeric { Index(index) } else { Field(content) })
    }
    if i < chars.length() {
      i = i + 1
    }
  }
  result
}

///|
/// Format structured path segments without losing special object keys.
pub fn format_path_segments(segments : Array[PathSegment]) -> String {
  let parts = segments.map(fn(segment) {
    match segment {
      Field(key) => path_key(key)
      Index(index) => "[\{index}]"
    }
  })
  format_path(parts)
}

///|
fn stack_segments(parts : Array[String]) -> Array[PathSegment] {
  let result : Array[PathSegment] = []
  for part in parts {
    result.append(parse_path(part))
  }
  result
}

///|
fn last_field_name(parts : Array[String]) -> String {
  let segments = stack_segments(parts)
  match segments.last() {
    Some(Field(key)) => key
    Some(Index(index)) => "[\{index}]"
    None => ""
  }
}
