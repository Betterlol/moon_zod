///|
/// Create a schema that validates JSON strings.
pub fn string(
  required_error~ : String = "",
  invalid_type_error~ : String = "",
) -> Schema {
  {
    schema_type: StringType,
    rules: [],
    description: "",
    required_error,
    invalid_type_error,
    name: "",
    brand: "",
  }
}

///|
fn schema_min_check(s : Schema, n : Double) -> (Json) -> Bool {
  match inner_type(s.schema_type) {
    StringType =>
      fn(json) {
        match json {
          String(s) => s.length().to_double() >= n
          _ => false
        }
      }
    NumberType =>
      fn(json) {
        match json {
          Number(v, ..) => v >= n
          _ => false
        }
      }
    ArrayType(_) =>
      fn(json) {
        match json {
          Array(arr) => arr.length().to_double() >= n
          _ => false
        }
      }
    _ => fn(_) { false }
  }
}

///|
fn schema_min_msg(s : Schema, n : Double) -> String {
  match inner_type(s.schema_type) {
    StringType => "String must contain at least \{n} character(s)"
    NumberType => "Value must be >= \{n}"
    ArrayType(_) => "Array must contain at least \{n} item(s)"
    _ => abort("min() is only valid for string, number, or array schemas")
  }
}

///|
/// Require the string length to be at least `n`.
pub fn[N : NumericBound] Schema::min(
  self : Schema,
  n : N,
  msg~ : String = "",
) -> Schema {
  let n = n.to_bound()
  guard_sized_bound(self, n)
  guard_no_user_transform(self)
  let check = schema_min_check(self, n)
  let message = if msg.is_empty() { schema_min_msg(self, n) } else { msg }
  let annotation = match inner_type(self.schema_type) {
    StringType => Json::object({ "minLength": Json::number(n) })
    NumberType => Json::object({ "minimum": Json::number(n) })
    ArrayType(_) => Json::object({ "minItems": Json::number(n) })
    _ => Json::null()
  }
  let origin = match inner_type(self.schema_type) {
    StringType => "string"
    NumberType => "number"
    ArrayType(_) => "array"
    _ => "value"
  }
  append_rule_with_annotation(
    self,
    check,
    message,
    IssueCode::TooSmall(origin, n, true),
    annotation,
  )
}

///|
fn schema_max_check(s : Schema, n : Double) -> (Json) -> Bool {
  match inner_type(s.schema_type) {
    StringType =>
      fn(json) {
        match json {
          String(s) => s.length().to_double() <= n
          _ => false
        }
      }
    NumberType =>
      fn(json) {
        match json {
          Number(v, ..) => v <= n
          _ => false
        }
      }
    ArrayType(_) =>
      fn(json) {
        match json {
          Array(arr) => arr.length().to_double() <= n
          _ => false
        }
      }
    _ => fn(_) { false }
  }
}

///|
fn schema_max_msg(s : Schema, n : Double) -> String {
  match inner_type(s.schema_type) {
    StringType => "String must contain at most \{n} character(s)"
    NumberType => "Value must be <= \{n}"
    ArrayType(_) => "Array must contain at most \{n} item(s)"
    _ => abort("max() is only valid for string, number, or array schemas")
  }
}

///|
/// Require the string length to be at most `n`.
pub fn[N : NumericBound] Schema::max(
  self : Schema,
  n : N,
  msg~ : String = "",
) -> Schema {
  let n = n.to_bound()
  guard_sized_bound(self, n)
  guard_no_user_transform(self)
  let check = schema_max_check(self, n)
  let message = if msg.is_empty() { schema_max_msg(self, n) } else { msg }
  let annotation = match inner_type(self.schema_type) {
    StringType => Json::object({ "maxLength": Json::number(n) })
    NumberType => Json::object({ "maximum": Json::number(n) })
    ArrayType(_) => Json::object({ "maxItems": Json::number(n) })
    _ => Json::null()
  }
  let origin = match inner_type(self.schema_type) {
    StringType => "string"
    NumberType => "number"
    ArrayType(_) => "array"
    _ => "value"
  }
  append_rule_with_annotation(
    self,
    check,
    message,
    IssueCode::TooBig(origin, n, true),
    annotation,
  )
}

///|
fn chars_to_string(chars : Array[Char], start : Int32, end : Int32) -> String {
  let mut result = ""
  for i = start; i < end; i = i + 1 {
    result = result + chars[i].to_string()
  }
  result
}

///|
fn is_valid_email(s : String) -> Bool {
  let parts = s.split("@").to_array()
  if parts.length() != 2 || parts[0].is_empty() {
    return false
  }
  let local_part = parts[0].to_array()
  if local_part[0] == '.' || local_part[local_part.length() - 1] == '.' {
    return false
  }
  let mut previous_dot = false
  for c in local_part {
    if c == '.' && previous_dot {
      return false
    }
    if !((c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '_' ||
      c == '+' ||
      c == '-' ||
      c == '\'' ||
      c == '.') {
      return false
    }
    previous_dot = c == '.'
  }
  let labels = parts[1].split(".").to_array()
  if labels.length() < 2 {
    return false
  }
  for label in labels {
    if label.is_empty() || label[0] == '-' {
      return false
    }
    for c in label.to_array() {
      if !((c >= 'a' && c <= 'z') ||
        (c >= 'A' && c <= 'Z') ||
        (c >= '0' && c <= '9') ||
        c == '-') {
        return false
      }
    }
  }
  let tld = labels[labels.length() - 1]
  tld.length() >= 2 &&
  tld.to_array().all(fn(c) { (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') })
}

///|
/// Require the string to be a valid email.
pub fn Schema::email(self : Schema, msg~ : String = "") -> Schema {
  guard_no_user_transform(self)
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
    IssueCode::InvalidFormat("email"),
    Json::object({ "format": Json::string("email") }),
  )
}

///|
fn is_valid_url(s : String) -> Bool {
  let chars = s.trim().to_owned().to_array()
  let mut colon = -1
  for i = 0; i < chars.length(); i = i + 1 {
    if chars[i] == ':' {
      colon = i
      break
    }
  }
  if colon <= 0 {
    return false
  }
  if !((chars[0] >= 'a' && chars[0] <= 'z') ||
    (chars[0] >= 'A' && chars[0] <= 'Z')) {
    return false
  }
  for i = 1; i < colon; i = i + 1 {
    let c = chars[i]
    if !((c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '+' ||
      c == '-' ||
      c == '.') {
      return false
    }
  }
  let scheme = chars_to_string(chars, 0, colon).to_lower()
  let special = scheme == "http" || scheme == "https" || scheme == "ftp"
  let has_authority = colon + 2 < chars.length() &&
    chars[colon + 1] == '/' &&
    chars[colon + 2] == '/'
  if !has_authority {
    return !special
  }
  let start = colon + 3
  let mut end = start
  while end < chars.length() &&
        chars[end] != '/' &&
        chars[end] != '?' &&
        chars[end] != '#' {
    end = end + 1
  }
  if end == start {
    return scheme == "file"
  }
  let mut host_start = start
  for i = start; i < end; i = i + 1 {
    if chars[i] == '@' {
      host_start = i + 1
    }
  }
  if host_start >= end {
    return false
  }
  let mut port_start = end
  if chars[host_start] == '[' {
    let mut closing = host_start + 1
    while closing < end && chars[closing] != ']' {
      closing = closing + 1
    }
    if closing == end ||
      !is_valid_ipv6(chars_to_string(chars, host_start + 1, closing)) {
      return false
    }
    if closing + 1 < end {
      if chars[closing + 1] != ':' {
        return false
      }
      port_start = closing + 2
    }
  } else {
    let mut host_end = end
    for i = host_start; i < end; i = i + 1 {
      if chars[i] == ':' {
        host_end = i
        port_start = i + 1
        break
      }
    }
    if host_end == host_start {
      return false
    }
    let host = chars_to_string(chars, host_start, host_end)
    let mut numeric_host = true
    for c in host.to_array() {
      if !((c >= 'a' && c <= 'z') ||
        (c >= 'A' && c <= 'Z') ||
        (c >= '0' && c <= '9') ||
        c == '.' ||
        c == '-' ||
        c == '_') {
        return false
      }
      if !(c >= '0' && c <= '9') && c != '.' {
        numeric_host = false
      }
    }
    if numeric_host && host.contains(".") && !is_valid_ipv4(host) {
      return false
    }
  }
  if port_start < end {
    let mut port = 0
    for i = port_start; i < end; i = i + 1 {
      if chars[i] < '0' || chars[i] > '9' {
        return false
      }
      port = port * 10 + chars[i].to_int() - 48
      if port > 65535 {
        return false
      }
    }
  }
  true
}

///|
/// Require an absolute URI; authority validation supports IPv4/IPv6 and ports.
/// This portable validator does not perform WHATWG URL normalization.
pub fn Schema::url(self : Schema, msg~ : String = "") -> Schema {
  guard_no_user_transform(self)
  match inner_type(self.schema_type) {
    StringType => ()
    _ => abort("url() is only valid for string schemas")
  }
  let message = if msg.is_empty() { "String must be a valid URL" } else { msg }
  append_rule_with_annotation(
    self,
    fn(json) {
      match json {
        String(s) => is_valid_url(s)
        _ => false
      }
    },
    message,
    IssueCode::InvalidFormat("url"),
    Json::object({ "format": Json::string("uri") }),
  )
}

///|
/// Require the string to match the given regex pattern.
pub fn Schema::regex(
  self : Schema,
  pattern : String,
  msg~ : String = "",
) -> Schema {
  guard_no_user_transform(self)
  match inner_type(self.schema_type) {
    StringType => ()
    _ => abort("regex() is only valid for string schemas")
  }
  let message = if msg.is_empty() {
    "String must match pattern: \{pattern}"
  } else {
    msg
  }
  let re = @regexp.compile(pattern) catch {
    _ => abort("Invalid regex pattern: \{pattern}")
  }
  append_rule_with_annotation(
    self,
    fn(json) {
      match json {
        String(s) => re.execute(s).matched()
        _ => false
      }
    },
    message,
    IssueCode::InvalidFormat("regex"),
    Json::object({ "pattern": Json::string(pattern) }),
  )
}

///|
/// Require the string to start with the given prefix.
pub fn Schema::startsWith(
  self : Schema,
  prefix : String,
  msg~ : String = "",
) -> Schema {
  guard_no_user_transform(self)
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
    IssueCode::Custom,
    Json::object({ "pattern": Json::string("^" + prefix) }),
  )
}

///|
/// Require the string to end with the given suffix.
pub fn Schema::endsWith(
  self : Schema,
  suffix : String,
  msg~ : String = "",
) -> Schema {
  guard_no_user_transform(self)
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
    IssueCode::Custom,
    Json::object({ "pattern": Json::string(suffix + "$") }),
  )
}

///|
/// Require the string to contain the given substring.
pub fn Schema::includes(
  self : Schema,
  substring : String,
  msg~ : String = "",
) -> Schema {
  guard_no_user_transform(self)
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
    IssueCode::Custom,
  )
}

///|
fn is_hex_digit(c : Char) -> Bool {
  (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

///|
/// Require the string to be a valid RFC UUID.
/// Format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
pub fn Schema::uuid(self : Schema, msg~ : String = "") -> Schema {
  guard_no_user_transform(self)
  match inner_type(self.schema_type) {
    StringType => ()
    _ => abort("uuid() is only valid for string schemas")
  }
  let message = if msg.is_empty() {
    "String must be a valid RFC UUID"
  } else {
    msg
  }
  append_rule_with_annotation(
    self,
    fn(json) {
      match json {
        String(s) => {
          if s == "00000000-0000-0000-0000-000000000000" ||
            s == "ffffffff-ffff-ffff-ffff-ffffffffffff" {
            return true
          }
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
          if chars[14] < '1' || chars[14] > '8' {
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
    IssueCode::InvalidFormat("uuid"),
    Json::object({ "format": Json::string("uuid") }),
  )
}

///|
/// Require the string to be a valid CUID (25 chars, starts with 'c', alphanumeric).
pub fn Schema::cuid(self : Schema, msg~ : String = "") -> Schema {
  guard_no_user_transform(self)
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
    IssueCode::InvalidFormat("cuid"),
    Json::object({ "format": Json::string("cuid") }),
  )
}

///|
fn is_leap_year(year : Int32) -> Bool {
  year % 400 == 0 || (year % 4 == 0 && year % 100 != 0)
}

///|

///|
fn is_valid_iso8601(
  s : String,
  offset : Bool,
  allow_local : Bool,
  precision : Int32,
) -> Bool {
  let chars = s.to_array()
  let n = chars.length()
  if n < 16 || chars[4] != '-' || chars[7] != '-' || chars[10] != 'T' {
    return false
  }
  for i = 0; i < 10; i = i + 1 {
    if i != 4 && i != 7 && (chars[i] < '0' || chars[i] > '9') {
      return false
    }
  }
  let year = (chars[0].to_int() - 48) * 1000 +
    (chars[1].to_int() - 48) * 100 +
    (chars[2].to_int() - 48) * 10 +
    chars[3].to_int() -
    48
  let month = (chars[5].to_int() - 48) * 10 + chars[6].to_int() - 48
  let day = (chars[8].to_int() - 48) * 10 + chars[9].to_int() - 48
  let days = match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    2 => if is_leap_year(year) { 29 } else { 28 }
    _ => 0
  }
  if day < 1 ||
    day > days ||
    !valid_clock_pair(chars, 11, 23) ||
    chars[13] != ':' ||
    !valid_clock_pair(chars, 14, 59) {
    return false
  }
  let mut pos = 16
  let has_seconds = pos < n && chars[pos] == ':'
  if has_seconds {
    if !valid_clock_pair(chars, 17, 59) {
      return false
    }
    pos = 19
  }
  if precision == -1 && has_seconds {
    return false
  }
  if !has_seconds && precision != -1 && !allow_local {
    return false
  }
  let mut decimals = 0
  if pos < n && chars[pos] == '.' {
    if !has_seconds {
      return false
    }
    pos = pos + 1
    while pos < n && chars[pos] >= '0' && chars[pos] <= '9' {
      decimals = decimals + 1
      pos = pos + 1
    }
    if decimals == 0 {
      return false
    }
  }
  if precision >= 0 && decimals != precision {
    return false
  }
  if pos == n {
    return allow_local
  }
  if chars[pos] == 'Z' {
    return pos + 1 == n && (has_seconds || precision == -1)
  }
  if !offset ||
    !has_seconds ||
    pos + 6 != n ||
    (chars[pos] != '+' && chars[pos] != '-') ||
    chars[pos + 3] != ':' {
    return false
  }
  valid_clock_pair(chars, pos + 1, 23) && valid_clock_pair(chars, pos + 4, 59)
}

///|
fn valid_clock_pair(
  chars : Array[Char],
  start : Int32,
  maximum : Int32,
) -> Bool {
  if start + 1 >= chars.length() {
    return false
  }
  let a = chars[start]
  let b = chars[start + 1]
  a >= '0' &&
  a <= '9' &&
  b >= '0' &&
  b <= '9' &&
  (a.to_int() - 48) * 10 + b.to_int() - 48 <= maximum
}

///|
/// Require the string to be a valid ISO 8601 datetime.
pub fn Schema::datetime(
  self : Schema,
  msg~ : String = "",
  offset~ : Bool = false,
  allow_local~ : Bool = false,
  precision~ : Int32 = -2,
) -> Schema {
  if precision < -2 {
    abort(
      "datetime precision must be -2 (default), -1 (minutes), or nonnegative",
    )
  }
  guard_no_user_transform(self)
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
        String(s) => is_valid_iso8601(s, offset, allow_local, precision)
        _ => false
      }
    },
    message,
    IssueCode::InvalidFormat("datetime"),
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
  let segments = s.split(":").to_array()
  if segments.length() < 3 {
    return false
  }
  let chars = s.to_array()
  let mut compression = 0
  let mut i = 0
  while i + 1 < chars.length() {
    if chars[i] == ':' && chars[i + 1] == ':' {
      compression = compression + 1
      i = i + 2
      if i < chars.length() && chars[i] == ':' {
        return false
      }
    } else {
      i = i + 1
    }
  }
  if compression > 1 {
    return false
  }
  if compression == 0 && (s.has_prefix(":") || s.has_suffix(":")) {
    return false
  }
  if s.has_prefix(":") && !s.has_prefix("::") {
    return false
  }
  if s.has_suffix(":") && !s.has_suffix("::") {
    return false
  }
  let mut groups = 0
  for i = 0; i < segments.length(); i = i + 1 {
    let segment = segments[i]
    if segment.is_empty() {
      continue
    }
    if segment.contains(".") {
      if i != segments.length() - 1 || !is_valid_ipv4(segment.to_owned()) {
        return false
      }
      groups = groups + 2
    } else {
      if segment.length() > 4 || !segment.to_array().all(is_hex_digit) {
        return false
      }
      groups = groups + 1
    }
  }
  if compression == 1 {
    groups < 8
  } else {
    groups == 8
  }
}

///|
/// Require the string to be a valid IPv4 address.
pub fn Schema::ipv4(self : Schema, msg~ : String = "") -> Schema {
  guard_no_user_transform(self)
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
    IssueCode::InvalidFormat("ipv4"),
    Json::object({ "format": Json::string("ipv4") }),
  )
}

///|
/// Require the string to be a valid IPv6 address.
pub fn Schema::ipv6(self : Schema, msg~ : String = "") -> Schema {
  guard_no_user_transform(self)
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
    IssueCode::InvalidFormat("ipv6"),
    Json::object({ "format": Json::string("ipv6") }),
  )
}

///|
/// Require the string to be a valid IPv4 or IPv6 address.
pub fn Schema::ip(self : Schema, msg~ : String = "") -> Schema {
  guard_no_user_transform(self)
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
    IssueCode::InvalidFormat("ip"),
  )
}

///|
fn schema_length_check(s : Schema, n : Int32) -> (Json) -> Bool {
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
fn schema_length_msg(s : Schema, n : Int32) -> String {
  match inner_type(s.schema_type) {
    StringType => "String must contain exactly \{n} character(s)"
    ArrayType(_) => "Array must contain exactly \{n} item(s)"
    _ => abort("length() is only valid for string or array schemas")
  }
}

///|
/// Require the string to be non-empty (or array to be non-empty).
pub fn Schema::nonempty(self : Schema, msg~ : String = "") -> Schema {
  guard_no_user_transform(self)
  match inner_type(self.schema_type) {
    StringType => ()
    ArrayType(_) => ()
    TupleType(_) => ()
    _ => abort("nonempty() is only valid for string, array, or tuple schemas")
  }
  let default_msg = match inner_type(self.schema_type) {
    StringType => "String must not be empty"
    _ => "Array must not be empty"
  }
  let message = if msg.is_empty() { default_msg } else { msg }
  let origin = match inner_type(self.schema_type) {
    StringType => "string"
    ArrayType(_) => "array"
    TupleType(_) => "tuple"
    _ => "value"
  }
  append_rule(
    self,
    fn(json) {
      match json {
        String(s) => !s.is_empty()
        Array(arr) => !arr.is_empty()
        _ => false
      }
    },
    message,
    IssueCode::TooSmall(origin, 1.0, true),
  )
}

///|
/// Trim leading and trailing whitespace from the string.
pub fn Schema::trim(self : Schema) -> Schema {
  guard_no_user_transform(self)
  match inner_type(self.schema_type) {
    StringType => ()
    _ => abort("trim() is only valid for string schemas")
  }
  {
    schema_type: TransformType(self, TransformClosure::{
      f: fn(json) {
        match json {
          String(s) => Ok(Json::string(s.trim().to_owned()))
          _ => Err("Expected string")
        }
      },
      is_builtin: true,
    }),
    rules: [],
    description: self.description,
    required_error: self.required_error,
    invalid_type_error: self.invalid_type_error,
    name: self.name,
    brand: self.brand,
  }
}

///|
/// Convert the string to lowercase.
pub fn Schema::to_lower(self : Schema) -> Schema {
  guard_no_user_transform(self)
  match inner_type(self.schema_type) {
    StringType => ()
    _ => abort("to_lower() is only valid for string schemas")
  }
  {
    schema_type: TransformType(self, TransformClosure::{
      f: fn(json) {
        match json {
          String(s) => Ok(Json::string(s.to_lower()))
          _ => Err("Expected string")
        }
      },
      is_builtin: true,
    }),
    rules: [],
    description: self.description,
    required_error: self.required_error,
    invalid_type_error: self.invalid_type_error,
    name: self.name,
    brand: self.brand,
  }
}

///|
/// Convert the string to uppercase.
pub fn Schema::to_upper(self : Schema) -> Schema {
  guard_no_user_transform(self)
  match inner_type(self.schema_type) {
    StringType => ()
    _ => abort("to_upper() is only valid for string schemas")
  }
  {
    schema_type: TransformType(self, TransformClosure::{
      f: fn(json) {
        match json {
          String(s) => Ok(Json::string(s.to_upper()))
          _ => Err("Expected string")
        }
      },
      is_builtin: true,
    }),
    rules: [],
    description: self.description,
    required_error: self.required_error,
    invalid_type_error: self.invalid_type_error,
    name: self.name,
    brand: self.brand,
  }
}

///|
/// Require the string or array to have exactly `n` items.
pub fn Schema::length(self : Schema, n : Int32, msg~ : String = "") -> Schema {
  let check = schema_length_check(self, n)
  let message = if msg.is_empty() { schema_length_msg(self, n) } else { msg }
  // No annotation — avoids conflict with minLength/maxLength
  append_rule(self, check, message, IssueCode::Custom)
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
pub fn Schema::ulid(self : Schema, msg~ : String = "") -> Schema {
  guard_no_user_transform(self)
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
    IssueCode::InvalidFormat("ulid"),
    Json::object({ "format": Json::string("ulid") }),
  )
}

///|
fn guard_sized_bound(schema : Schema, bound : Double) -> Unit {
  if bound.is_nan() || bound.is_inf() {
    abort("bounds must be finite")
  }
  match inner_type(schema.schema_type) {
    NumberType => ()
    StringType | ArrayType(_) =>
      if bound < 0.0 || bound != bound.floor() {
        abort("length bounds must be nonnegative integers")
      }
    _ => abort("min()/max() require a string, number or array schema")
  }
}
