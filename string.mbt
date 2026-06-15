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
  self : Schema,
  pattern : String,
  msg? : String = "",
) -> Schema {
  match inner_type(self.schema_type) {
    StringType => ()
    _ => abort("regex() is only valid for string schemas")
  }
  let message = if msg.is_empty() {
    "String must match pattern: \{pattern}"
  } else {
    msg
  }
  // MoonBit has no built-in regex; this is a simple substring check.
  println(
    "Warning: regex() is not fully implemented; it only checks for substring match.",
  )
  append_rule_with_annotation(
    self,
    fn(json) {
      match json {
        String(s) => s.contains(pattern)
        _ => false
      }
    },
    message,
    Json::object({ "pattern": Json::string(pattern) }),
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

///|
/// Require the string to be a valid CUID (25 chars, starts with 'c', alphanumeric).
pub fn Schema::cuid(self : Schema, msg? : String = "") -> Schema {
  match inner_type(self.schema_type) {
    StringType => ()
    _ => abort("cuid() is only valid for string schemas")
  }
  let message = if msg.is_empty() { "String must be a valid CUID" } else { msg }
  append_rule_with_annotation(
    self,
    fn(json) {
      match json {
        String(s) => {
          let chars = s.to_array()
          if chars.length() != 25 {
            return false
          }
          if chars[0] != 'c' {
            return false
          }
          for i = 1; i < 25; i = i + 1 {
            let c = chars[i]
            if !((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')) {
              return false
            }
          }
          true
        }
        _ => false
      }
    },
    message,
    Json::object({ "format": Json::string("cuid") }),
  )
}

///|
fn is_leap_year(year : Int) -> Bool {
  year % 400 == 0 || (year % 4 == 0 && year % 100 != 0)
}

///|

///|
fn is_valid_iso8601(s : String) -> Bool {
  let chars = s.to_array()
  let n = chars.length()
  if n < 10 {
    return false
  }
  // Validate YYYY-MM-DD structure
  if chars[4] != '-' || chars[7] != '-' {
    return false
  }
  for i = 0; i < 10; i = i + 1 {
    if i == 4 || i == 7 {
      continue
    }
    if chars[i] < '0' || chars[i] > '9' {
      return false
    }
  }
  let year = (chars[0].to_int() - 48) * 1000 +
    (chars[1].to_int() - 48) * 100 +
    (chars[2].to_int() - 48) * 10 +
    (chars[3].to_int() - 48)
  let month = (chars[5].to_int() - 48) * 10 + (chars[6].to_int() - 48)
  let day = (chars[8].to_int() - 48) * 10 + (chars[9].to_int() - 48)
  if year < 1 || month < 1 || month > 12 || day < 1 {
    return false
  }
  let days_in_month = match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    2 => if is_leap_year(year) { 29 } else { 28 }
    _ => 0
  }
  if day > days_in_month {
    return false
  }
  if n == 10 {
    return true
  }
  if chars[10] != 'T' {
    return false
  }
  if n < 16 {
    return false
  }
  // Find timezone marker: 'Z' or +/- starting from position 19 (after HH:mm:ss)
  let mut tz_start = n
  if chars[n - 1] == 'Z' {
    tz_start = n - 1
  } else {
    for i = 19; i < n; i = i + 1 {
      if chars[i] == '+' || chars[i] == '-' {
        tz_start = i
        break
      }
    }
  }
  // Validate time part: chars[11..tz_start)
  let time_len = tz_start - 11
  if time_len != 5 && time_len != 8 {
    return false
  }
  // Check HH:mm or HH:mm:ss
  for i = 11; i < tz_start; i = i + 1 {
    if i == 13 || i == 16 {
      if chars[i] != ':' {
        return false
      }
    } else if chars[i] < '0' || chars[i] > '9' {
      return false
    }
  }
  let hour = (chars[11].to_int() - 48) * 10 + (chars[12].to_int() - 48)
  let minute = (chars[14].to_int() - 48) * 10 + (chars[15].to_int() - 48)
  if hour < 0 || hour > 23 || minute < 0 || minute > 59 {
    return false
  }
  if time_len == 8 {
    let second = (chars[17].to_int() - 48) * 10 + (chars[18].to_int() - 48)
    if second < 0 || second > 59 {
      return false
    }
  }
  true
}

///|
/// Require the string to be a valid ISO 8601 datetime.
pub fn Schema::datetime(self : Schema, msg? : String = "") -> Schema {
  match inner_type(self.schema_type) {
    StringType => ()
    _ => abort("datetime() is only valid for string schemas")
  }
  let message = if msg.is_empty() {
    "String must be a valid ISO 8601 datetime"
  } else {
    msg
  }
  append_rule_with_annotation(
    self,
    fn(json) {
      match json {
        String(s) => is_valid_iso8601(s)
        _ => false
      }
    },
    message,
    Json::object({ "format": Json::string("date-time") }),
  )
}

///|
fn is_valid_ipv4(s : String) -> Bool {
  let chars = s.to_array()
  let n = chars.length()
  if n < 7 || n > 15 {
    return false
  }
  // Count dots
  let mut dot_count = 0
  for c in chars {
    if c == '.' {
      dot_count = dot_count + 1
    }
  }
  if dot_count != 3 {
    return false
  }
  // Parse 4 segments
  let mut seg_start = 0
  for seg = 0; seg < 4; seg = seg + 1 {
    // Find end of this segment
    let mut seg_end = n
    for i = seg_start; i < n; i = i + 1 {
      if chars[i] == '.' {
        seg_end = i
        break
      }
    }
    let len = seg_end - seg_start
    if len < 1 || len > 3 {
      return false
    }
    // No leading zeros
    if len > 1 && chars[seg_start] == '0' {
      return false
    }
    // Parse digits
    let mut val = 0
    for i = seg_start; i < seg_end; i = i + 1 {
      if chars[i] < '0' || chars[i] > '9' {
        return false
      }
      val = val * 10 + (chars[i].to_int() - 48)
    }
    if val > 255 {
      return false
    }
    seg_start = seg_end + 1
  }
  true
}

///|
fn is_valid_ipv6(s : String) -> Bool {
  let chars = s.to_array()
  let n = chars.length()
  if n < 2 {
    return false
  }
  // Count colons and detect ::
  let mut colon_count = 0
  let mut double_colon = false
  for i = 0; i < n; i = i + 1 {
    if chars[i] == ':' {
      colon_count = colon_count + 1
      if i + 1 < n && chars[i + 1] == ':' {
        double_colon = true
      }
    } else if !is_hex_digit(chars[i]) {
      return false
    }
  }
  if double_colon && colon_count > 7 {
    return false
  }
  if !double_colon && colon_count != 7 {
    return false
  }
  // Validate each hex group between colons
  let mut group_len = 0
  let mut groups = 0
  for i = 0; i < n; i = i + 1 {
    if chars[i] == ':' {
      if i + 1 < n && chars[i + 1] == ':' {
        // :: counts as 0+ groups
        groups = groups + 1
        if group_len > 0 {
          groups = groups + 1
        }
        group_len = 0
      } else {
        if group_len > 0 || groups > 0 {
          groups = groups + 1
        }
        group_len = 0
      }
    } else {
      group_len = group_len + 1
      if group_len > 4 {
        return false
      }
    }
  }
  if group_len > 0 {
    groups = groups + 1
  }
  if double_colon {
    groups <= 8
  } else {
    groups == 8
  }
}

///|
/// Require the string to be a valid IPv4 address.
pub fn Schema::ipv4(self : Schema, msg? : String = "") -> Schema {
  match inner_type(self.schema_type) {
    StringType => ()
    _ => abort("ipv4() is only valid for string schemas")
  }
  let message = if msg.is_empty() {
    "String must be a valid IPv4 address"
  } else {
    msg
  }
  append_rule_with_annotation(
    self,
    fn(json) {
      match json {
        String(s) => is_valid_ipv4(s)
        _ => false
      }
    },
    message,
    Json::object({ "format": Json::string("ipv4") }),
  )
}

///|
/// Require the string to be a valid IPv6 address.
pub fn Schema::ipv6(self : Schema, msg? : String = "") -> Schema {
  match inner_type(self.schema_type) {
    StringType => ()
    _ => abort("ipv6() is only valid for string schemas")
  }
  let message = if msg.is_empty() {
    "String must be a valid IPv6 address"
  } else {
    msg
  }
  append_rule_with_annotation(
    self,
    fn(json) {
      match json {
        String(s) => is_valid_ipv6(s)
        _ => false
      }
    },
    message,
    Json::object({ "format": Json::string("ipv6") }),
  )
}

///|
/// Require the string to be a valid IPv4 or IPv6 address.
pub fn Schema::ip(self : Schema, msg? : String = "") -> Schema {
  match inner_type(self.schema_type) {
    StringType => ()
    _ => abort("ip() is only valid for string schemas")
  }
  let message = if msg.is_empty() {
    "String must be a valid IP address"
  } else {
    msg
  }
  append_rule(
    self,
    fn(json) {
      match json {
        String(s) => is_valid_ipv4(s) || is_valid_ipv6(s)
        _ => false
      }
    },
    message,
  )
}

///|
fn schema_length_check(s : Schema, n : Int) -> (Json) -> Bool {
  match inner_type(s.schema_type) {
    StringType =>
      fn(json) {
        match json {
          String(s) => s.length() == n
          _ => false
        }
      }
    ArrayType(_) =>
      fn(json) {
        match json {
          Array(arr) => arr.length() == n
          _ => false
        }
      }
    _ => fn(_) { false }
  }
}

///|
fn schema_length_msg(s : Schema, n : Int) -> String {
  match inner_type(s.schema_type) {
    StringType => "String must contain exactly \{n} character(s)"
    ArrayType(_) => "Array must contain exactly \{n} item(s)"
    _ => abort("length() is only valid for string or array schemas")
  }
}

///|
/// Require the string or array to have exactly `n` items.
pub fn Schema::length(self : Schema, n : Int, msg? : String = "") -> Schema {
  let check = schema_length_check(self, n)
  let message = if msg.is_empty() { schema_length_msg(self, n) } else { msg }
  // No annotation — avoids conflict with minLength/maxLength
  append_rule(self, check, message)
}

///|
fn is_crockford_base32(c : Char) -> Bool {
  (c >= '0' && c <= '9') ||
  (c >= 'A' && c <= 'H') ||
  (c >= 'J' && c <= 'N') ||
  (c >= 'P' && c <= 'Z')
}

///|
/// Require the string to be a valid ULID (26 chars, Crockford Base32).
pub fn Schema::ulid(self : Schema, msg? : String = "") -> Schema {
  match inner_type(self.schema_type) {
    StringType => ()
    _ => abort("ulid() is only valid for string schemas")
  }
  let message = if msg.is_empty() { "String must be a valid ULID" } else { msg }
  append_rule_with_annotation(
    self,
    fn(json) {
      match json {
        String(s) => {
          let chars = s.to_array()
          if chars.length() != 26 {
            return false
          }
          // First char must be 0-7 (timestamp high bits)
          if chars[0] < '0' || chars[0] > '7' {
            return false
          }
          for c in chars {
            if !is_crockford_base32(c) {
              return false
            }
          }
          true
        }
        _ => false
      }
    },
    message,
    Json::object({ "format": Json::string("ulid") }),
  )
}
