///|
/// Create a schema that validates JSON strings.
pub fn string() -> Schema {
  { schema_type: StringType, rules: [], description: "" }
}

///|
fn schema_min_check(s : Schema, n : Int) -> (Json) -> Bool {
  match inner_type(s.schema_type) {
    StringType =>
      fn(json) {
        match json {
          String(s) => s.length() >= n
          _ => false
        }
      }
    NumberType =>
      fn(json) {
        match json {
          Number(v, ..) => v >= n.to_double()
          _ => false
        }
      }
    ArrayType(_) =>
      fn(json) {
        match json {
          Array(arr) => arr.length() >= n
          _ => false
        }
      }
    _ => fn(_) { false }
  }
}

///|
fn schema_min_msg(s : Schema, n : Int) -> String {
  match inner_type(s.schema_type) {
    StringType => "String must contain at least \{n} character(s)"
    NumberType => "Value must be >= \{n}"
    ArrayType(_) => "Array must contain at least \{n} item(s)"
    _ => abort("min() is only valid for string, number, or array schemas")
  }
}

///|
/// Require the string length to be at least `n`.
pub fn Schema::min(self : Schema, n : Int, msg? : String = "") -> Schema {
  let check = schema_min_check(self, n)
  let message = if msg.is_empty() { schema_min_msg(self, n) } else { msg }
  let annotation = match inner_type(self.schema_type) {
    StringType => Json::object({ "minLength": Json::number(n.to_double()) })
    NumberType => Json::object({ "minimum": Json::number(n.to_double()) })
    ArrayType(_) => Json::object({ "minItems": Json::number(n.to_double()) })
    _ => Json::null()
  }
  append_rule_with_annotation(self, check, message, annotation)
}

///|
fn schema_max_check(s : Schema, n : Int) -> (Json) -> Bool {
  match inner_type(s.schema_type) {
    StringType =>
      fn(json) {
        match json {
          String(s) => s.length() <= n
          _ => false
        }
      }
    NumberType =>
      fn(json) {
        match json {
          Number(v, ..) => v <= n.to_double()
          _ => false
        }
      }
    ArrayType(_) =>
      fn(json) {
        match json {
          Array(arr) => arr.length() <= n
          _ => false
        }
      }
    _ => fn(_) { false }
  }
}

///|
fn schema_max_msg(s : Schema, n : Int) -> String {
  match inner_type(s.schema_type) {
    StringType => "String must contain at most \{n} character(s)"
    NumberType => "Value must be <= \{n}"
    ArrayType(_) => "Array must contain at most \{n} item(s)"
    _ => abort("max() is only valid for string, number, or array schemas")
  }
}

///|
/// Require the string length to be at most `n`.
pub fn Schema::max(self : Schema, n : Int, msg? : String = "") -> Schema {
  let check = schema_max_check(self, n)
  let message = if msg.is_empty() { schema_max_msg(self, n) } else { msg }
  let annotation = match inner_type(self.schema_type) {
    StringType => Json::object({ "maxLength": Json::number(n.to_double()) })
    NumberType => Json::object({ "maximum": Json::number(n.to_double()) })
    ArrayType(_) => Json::object({ "maxItems": Json::number(n.to_double()) })
    _ => Json::null()
  }
  append_rule_with_annotation(self, check, message, annotation)
}

///|
/// Require the string to be non-empty.
pub fn Schema::nonempty(self : Schema, msg? : String = "") -> Schema {
  match inner_type(self.schema_type) {
    StringType => ()
    _ => abort("nonempty() is only valid for string schemas")
  }
  let message = if msg.is_empty() { "String must not be empty" } else { msg }
  append_rule(
    self,
    fn(json) {
      match json {
        String(s) => !s.is_empty()
        _ => false
      }
    },
    message,
  )
}

///|
fn is_valid_email(s : String) -> Bool {
  let chars = s.to_array()
  let n = chars.length()
  // Find the single @ and validate local/domain parts
  let mut at_count = 0
  let mut at_pos = -1
  for i, c in chars {
    if c == '@' {
      at_count = at_count + 1
      at_pos = i
    }
  }
  if at_count != 1 {
    return false
  }
  // Local part: non-empty, no leading/trailing dot
  if at_pos <= 0 {
    return false
  }
  if chars[0] == '.' || chars[at_pos - 1] == '.' {
    return false
  }
  // Domain part: after @, at least one dot, no leading/trailing dot
  if at_pos >= n - 1 {
    return false
  }
  if chars[at_pos + 1] == '.' || chars[n - 1] == '.' {
    return false
  }
  // At least one dot in domain
  for i = at_pos + 1; i < n; i = i + 1 {
    if chars[i] == '.' {
      return true
    }
  }
  false
}

///|
/// Require the string to be a valid email.
pub fn Schema::email(self : Schema, msg? : String = "") -> Schema {
  match inner_type(self.schema_type) {
    StringType => ()
    _ => abort("email() is only valid for string schemas")
  }
  let message = if msg.is_empty() {
    "String must be a valid email address"
  } else {
    msg
  }
  append_rule_with_annotation(
    self,
    fn(json) {
      match json {
        String(s) => is_valid_email(s)
        _ => false
      }
    },
    message,
    Json::object({ "format": Json::string("email") }),
  )
}

///|
fn has_url_prefix(s : String) -> Bool {
  s.has_prefix("http://") || s.has_prefix("https://")
}

///|
/// Require the string to start with `http://` or `https://`.
pub fn Schema::url(self : Schema, msg? : String = "") -> Schema {
  match inner_type(self.schema_type) {
    StringType => ()
    _ => abort("url() is only valid for string schemas")
  }
  let message = if msg.is_empty() { "String must be a valid URL" } else { msg }
  append_rule_with_annotation(
    self,
    fn(json) {
      match json {
        String(s) => has_url_prefix(s)
        _ => false
      }
    },
    message,
    Json::object({ "format": Json::string("uri") }),
  )
}

///|
/// Not implemented — MoonBit has no built-in regex.
/// Use `includes()` for substring matching instead.
pub fn Schema::regex(
  _self : Schema,
  _pattern : String,
  _msg? : String = "",
) -> Schema {
  match inner_type(_self.schema_type) {
    StringType => ()
    _ => abort("regex() is only valid for string schemas")
  }
  let message = if _msg.is_empty() {
    "String must match pattern: \{_pattern}"
  } else {
    _msg
  }
  println(
    "Warning: regex() is not implemented. Use includes() for substring matching.",
  )
  abort(
    "regex() is not implemented in MoonBit, as it has no built-in regex support. Consider using includes() for simple substring checks.",
  )
  append_rule_with_annotation(
    _self,
    fn(json) {
      match json {
        String(s) => s.contains(_pattern) // Placeholder: just check if pattern is a substring
        _ => false
      }
    },
    message,
    Json::object({ "pattern": Json::string(_pattern) }),
  )
}

///|
/// Require the string to start with the given prefix.
pub fn Schema::startsWith(
  self : Schema,
  prefix : String,
  msg? : String = "",
) -> Schema {
  match inner_type(self.schema_type) {
    StringType => ()
    _ => abort("startsWith() is only valid for string schemas")
  }
  let message = if msg.is_empty() {
    "String must start with \"\{prefix}\""
  } else {
    msg
  }
  append_rule_with_annotation(
    self,
    fn(json) {
      match json {
        String(s) => s.has_prefix(prefix)
        _ => false
      }
    },
    message,
    Json::object({ "pattern": Json::string("^" + prefix) }),
  )
}

///|
/// Require the string to end with the given suffix.
pub fn Schema::endsWith(
  self : Schema,
  suffix : String,
  msg? : String = "",
) -> Schema {
  match inner_type(self.schema_type) {
    StringType => ()
    _ => abort("endsWith() is only valid for string schemas")
  }
  let message = if msg.is_empty() {
    "String must end with \"\{suffix}\""
  } else {
    msg
  }
  append_rule_with_annotation(
    self,
    fn(json) {
      match json {
        String(s) => s.has_suffix(suffix)
        _ => false
      }
    },
    message,
    Json::object({ "pattern": Json::string(suffix + "$") }),
  )
}

///|
/// Require the string to contain the given substring.
pub fn Schema::includes(
  self : Schema,
  substring : String,
  msg? : String = "",
) -> Schema {
  match inner_type(self.schema_type) {
    StringType => ()
    _ => abort("includes() is only valid for string schemas")
  }
  let message = if msg.is_empty() {
    "String must include \"\{substring}\""
  } else {
    msg
  }
  append_rule(
    self,
    fn(json) {
      match json {
        String(s) => s.contains(substring)
        _ => false
      }
    },
    message,
  )
}

///|
fn is_hex_digit(c : Char) -> Bool {
  (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

///|
/// Require the string to be a valid UUID v4.
/// Format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
pub fn Schema::uuid(self : Schema, msg? : String = "") -> Schema {
  match inner_type(self.schema_type) {
    StringType => ()
    _ => abort("uuid() is only valid for string schemas")
  }
  let message = if msg.is_empty() {
    "String must be a valid UUID v4"
  } else {
    msg
  }
  append_rule_with_annotation(
    self,
    fn(json) {
      match json {
        String(s) => {
          let chars = s.to_array()
          if chars.length() != 36 {
            return false
          }
          // Dashes at positions 8, 13, 18, 23
          if chars[8] != '-' ||
            chars[13] != '-' ||
            chars[18] != '-' ||
            chars[23] != '-' {
            return false
          }
          // Version digit at position 14 must be '4'
          if chars[14] != '4' {
            return false
          }
          // Variant at position 19 must be 8/9/a/b/A/B
          if chars[19] != '8' &&
            chars[19] != '9' &&
            chars[19] != 'a' &&
            chars[19] != 'b' &&
            chars[19] != 'A' &&
            chars[19] != 'B' {
            return false
          }
          // All other chars must be hex digits
          let positions = [
            0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 15, 16, 17, 20, 21, 22, 24, 25,
            26, 27, 28, 29, 30, 31, 32, 33, 34, 35,
          ]
          for i in positions {
            if !is_hex_digit(chars[i]) {
              return false
            }
          }
          true
        }
        _ => false
      }
    },
    message,
    Json::object({ "format": Json::string("uuid") }),
  )
}
