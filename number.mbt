///|
/// Create a schema that validates JSON numbers.
pub fn number(
  required_error? : String = "",
  invalid_type_error? : String = "",
) -> Schema {
  {
    schema_type: NumberType,
    rules: [],
    description: "",
    required_error,
    invalid_type_error,
    name: "",
  }
}

///|
/// Require the number to be an integer (no fractional part).
pub fn Schema::int(self : Schema, msg? : String = "") -> Schema {
  match inner_type(self.schema_type) {
    NumberType => ()
    _ => abort("int() is only valid for number schemas")
  }
  let message = if msg.is_empty() { "Value must be an integer" } else { msg }
  append_rule_with_annotation(
    self,
    fn(json) {
      match json {
        Number(v, ..) => v == v.to_int().to_double()
        _ => false
      }
    },
    message,
    Json::object({ "type": Json::string("integer") }),
  )
}

///|
/// Require the number to be positive (> 0).
pub fn Schema::positive(self : Schema, msg? : String = "") -> Schema {
  match inner_type(self.schema_type) {
    NumberType => ()
    _ => abort("positive() is only valid for number schemas")
  }
  let message = if msg.is_empty() { "Value must be positive" } else { msg }
  append_rule_with_annotation(
    self,
    fn(json) {
      match json {
        Number(v, ..) => v > 0.0
        _ => false
      }
    },
    message,
    Json::object({ "exclusiveMinimum": Json::number(0.0) }),
  )
}

///|
/// Require the number to be negative (< 0).
pub fn Schema::negative(self : Schema, msg? : String = "") -> Schema {
  match inner_type(self.schema_type) {
    NumberType => ()
    _ => abort("negative() is only valid for number schemas")
  }
  let message = if msg.is_empty() { "Value must be negative" } else { msg }
  append_rule_with_annotation(
    self,
    fn(json) {
      match json {
        Number(v, ..) => v < 0.0
        _ => false
      }
    },
    message,
    Json::object({ "exclusiveMaximum": Json::number(0.0) }),
  )
}

///|
/// Require the number to be a multiple of `n`.
pub fn Schema::multipleOf(self : Schema, n : Int, msg? : String = "") -> Schema {
  match inner_type(self.schema_type) {
    NumberType => ()
    _ => abort("multipleOf() is only valid for number schemas")
  }
  let message = if msg.is_empty() {
    "Value must be a multiple of \{n}"
  } else {
    msg
  }
  append_rule_with_annotation(
    self,
    fn(json) {
      match json {
        Number(v, ..) =>
          v / n.to_double() == (v / n.to_double()).to_int().to_double()
        _ => false
      }
    },
    message,
    Json::object({ "multipleOf": Json::number(n.to_double()) }),
  )
}

///|
/// Require the number to be finite (reject Infinity and NaN).
pub fn Schema::finite(self : Schema, msg? : String = "") -> Schema {
  match inner_type(self.schema_type) {
    NumberType => ()
    _ => abort("finite() is only valid for number schemas")
  }
  let message = if msg.is_empty() {
    "Value must be a finite number"
  } else {
    msg
  }
  append_rule(
    self,
    fn(json) {
      match json {
        Number(v, ..) => !v.is_nan() && !v.is_inf()
        _ => false
      }
    },
    message,
  )
}

///|
/// Require the number to be a safe integer (within ±2^53-1).
pub fn Schema::safe(self : Schema, msg? : String = "") -> Schema {
  match inner_type(self.schema_type) {
    NumberType => ()
    _ => abort("safe() is only valid for number schemas")
  }
  let message = if msg.is_empty() {
    "Value must be a safe integer"
  } else {
    msg
  }
  let min_safe = -9007199254740991.0
  let max_safe = 9007199254740991.0
  append_rule(
    self,
    fn(json) {
      match json {
        Number(v, ..) =>
          v == v.to_int().to_double() && v >= min_safe && v <= max_safe
        _ => false
      }
    },
    message,
  )
}
