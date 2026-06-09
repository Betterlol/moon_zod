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
pub fn Schema::min(self : Schema, n : Int) -> Schema {
  let check = schema_min_check(self, n)
  let message = schema_min_msg(self, n)
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
pub fn Schema::max(self : Schema, n : Int) -> Schema {
  let check = schema_max_check(self, n)
  let message = schema_max_msg(self, n)
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
pub fn Schema::nonempty(self : Schema) -> Schema {
  match inner_type(self.schema_type) {
    StringType => ()
    _ => abort("nonempty() is only valid for string schemas")
  }
  append_rule(
    self,
    fn(json) {
      match json {
        String(s) => !s.is_empty()
        _ => false
      }
    },
    "String must not be empty",
  )
}

///|
fn has_at_and_dot(s : String) -> Bool {
  let chars = s.to_array()
  let mut at_pos : Int = -1
  for i, c in chars {
    if c == '@' {
      at_pos = i
      break
    }
  }
  if at_pos <= 0 {
    return false
  }
  for i = at_pos + 1; i < chars.length(); i = i + 1 {
    if chars[i] == '.' && i > at_pos + 1 && i < chars.length() - 1 {
      return true
    }
  }
  false
}

///|
/// Require the string to be a valid email.
pub fn Schema::email(self : Schema) -> Schema {
  match inner_type(self.schema_type) {
    StringType => ()
    _ => abort("email() is only valid for string schemas")
  }
  append_rule_with_annotation(
    self,
    fn(json) {
      match json {
        String(s) => has_at_and_dot(s)
        _ => false
      }
    },
    "String must be a valid email address",
    Json::object({ "format": Json::string("email") }),
  )
}

///|
fn has_url_prefix(s : String) -> Bool {
  s.has_prefix("http://") || s.has_prefix("https://")
}

///|
/// Require the string to start with `http://` or `https://`.
pub fn Schema::url(self : Schema) -> Schema {
  match inner_type(self.schema_type) {
    StringType => ()
    _ => abort("url() is only valid for string schemas")
  }
  append_rule_with_annotation(
    self,
    fn(json) {
      match json {
        String(s) => has_url_prefix(s)
        _ => false
      }
    },
    "String must be a valid URL",
    Json::object({ "format": Json::string("uri") }),
  )
}

///|
/// Require the string to contain the given substring.
pub fn Schema::regex(self : Schema, pattern : String) -> Schema {
  match inner_type(self.schema_type) {
    StringType => ()
    _ => abort("regex() is only valid for string schemas")
  }
  append_rule_with_annotation(
    self,
    fn(json) {
      match json {
        String(s) => s.contains(pattern)
        _ => false
      }
    },
    "String must match pattern: \{pattern}",
    Json::object({ "pattern": Json::string(pattern) }),
  )
}
