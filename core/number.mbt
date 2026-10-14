///|
/// Numeric bounds accept both integer arguments and Double arguments.
pub(open) trait NumericBound {
  fn to_bound(Self) -> Double
}

///|
pub impl NumericBound for Int32 with fn to_bound(self) {
  self.to_double()
}

///|
pub impl NumericBound for Int64 with fn to_bound(self) {
  self.to_double()
}

///|
pub impl NumericBound for Double with fn to_bound(self) {
  self
}

///|
fn is_safe_integer(value : Double) -> Bool {
  !value.is_nan() &&
  !value.is_inf() &&
  value == value.floor() &&
  value.abs() <= 9007199254740991.0
}

///|
fn decimal_parts(value : Double) -> (@bigint.BigInt, Int32) {
  let chars = value.abs().to_string().to_array()
  let digits = StringBuilder()
  let mut fraction = 0
  let mut after_dot = false
  let mut i = 0
  while i < chars.length() && chars[i] != 'e' && chars[i] != 'E' {
    if chars[i] == '.' {
      after_dot = true
    } else {
      digits.write_char(chars[i])
      if after_dot {
        fraction = fraction + 1
      }
    }
    i = i + 1
  }
  let mut exponent = 0
  let mut negative = false
  if i < chars.length() {
    i = i + 1
    if chars[i] == '-' {
      negative = true
      i = i + 1
    } else if chars[i] == '+' {
      i = i + 1
    }
    while i < chars.length() {
      exponent = exponent * 10 + chars[i].to_int() - 48
      i = i + 1
    }
  }
  (
    @bigint.BigInt::from_string(digits.to_string()),
    (if negative { -exponent } else { exponent }) - fraction,
  )
}

///|
fn is_decimal_multiple(value : Double, divisor : Double) -> Bool {
  if value.is_nan() || value.is_inf() {
    return false
  }
  if is_safe_integer(value) && is_safe_integer(divisor) {
    return value % divisor == 0.0
  }
  let (left, left_scale) = decimal_parts(value)
  let (right, right_scale) = decimal_parts(divisor)
  let scale = if left_scale < right_scale { left_scale } else { right_scale }
  let ten = @bigint.BigInt::from_int(10)
  let numerator = left * ten.pow(@bigint.BigInt::from_int(left_scale - scale))
  let denominator = right *
    ten.pow(@bigint.BigInt::from_int(right_scale - scale))
  (numerator % denominator).is_zero()
}

///|
/// Create a schema that validates JSON numbers.
pub fn number(
  required_error~ : String = "",
  invalid_type_error~ : String = "",
) -> Schema {
  {
    schema_type: NumberType,
    rules: [],
    description: "",
    required_error,
    invalid_type_error,
    name: "",
    brand: "",
  }
}

///|
/// Require the number to be an integer (no fractional part).
pub fn Schema::int(self : Schema, msg~ : String = "") -> Schema {
  guard_no_user_transform(self)
  match inner_type(self.schema_type) {
    NumberType => ()
    _ => abort("int() is only valid for number schemas")
  }
  let message = if msg.is_empty() { "Value must be an integer" } else { msg }
  append_builtin_rule(
    self,
    fn(json) {
      match json {
        Number(v, ..) => is_safe_integer(v)
        _ => false
      }
    },
    message,
    IssueCode::InvalidFormat("integer"),
    Json::object({ "type": Json::string("integer") }),
    explicit_message=!msg.is_empty(),
  )
}

///|
/// Require the number to be positive (> 0).
pub fn Schema::positive(self : Schema, msg~ : String = "") -> Schema {
  guard_no_user_transform(self)
  match inner_type(self.schema_type) {
    NumberType => ()
    _ => abort("positive() is only valid for number schemas")
  }
  let message = if msg.is_empty() { "Value must be positive" } else { msg }
  append_builtin_rule(
    self,
    fn(json) {
      match json {
        Number(v, ..) => v > 0.0
        _ => false
      }
    },
    message,
    IssueCode::TooSmall("number", 0.0, false),
    Json::object({ "exclusiveMinimum": Json::number(0.0) }),
    explicit_message=!msg.is_empty(),
  )
}

///|
/// Require the number to be negative (< 0).
pub fn Schema::negative(self : Schema, msg~ : String = "") -> Schema {
  guard_no_user_transform(self)
  match inner_type(self.schema_type) {
    NumberType => ()
    _ => abort("negative() is only valid for number schemas")
  }
  let message = if msg.is_empty() { "Value must be negative" } else { msg }
  append_builtin_rule(
    self,
    fn(json) {
      match json {
        Number(v, ..) => v < 0.0
        _ => false
      }
    },
    message,
    IssueCode::TooBig("number", 0.0, false),
    Json::object({ "exclusiveMaximum": Json::number(0.0) }),
    explicit_message=!msg.is_empty(),
  )
}

///|
/// Require the number to be a multiple of `n`.
pub fn[N : NumericBound] Schema::multipleOf(
  self : Schema,
  n : N,
  msg~ : String = "",
) -> Schema {
  let n = n.to_bound()
  if n.is_nan() || n.is_inf() || n <= 0.0 {
    abort("multipleOf() requires a positive finite divisor")
  }
  guard_no_user_transform(self)
  match inner_type(self.schema_type) {
    NumberType => ()
    _ => abort("multipleOf() is only valid for number schemas")
  }
  let message = if msg.is_empty() {
    "Value must be a multiple of \{n}"
  } else {
    msg
  }
  append_builtin_rule(
    self,
    fn(json) {
      match json {
        Number(v, ..) => is_decimal_multiple(v, n)
        _ => false
      }
    },
    message,
    IssueCode::NotMultipleOf(n),
    Json::object({ "multipleOf": Json::number(n) }),
    explicit_message=!msg.is_empty(),
  )
}

///|
/// Require the number to be finite (reject Infinity and NaN).
pub fn Schema::finite(self : Schema, msg~ : String = "") -> Schema {
  guard_no_user_transform(self)
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
    IssueCode::Custom,
  )
}

///|
/// Require the number to be a safe integer (within ±2^53-1).
pub fn Schema::safe(self : Schema, msg~ : String = "") -> Schema {
  guard_no_user_transform(self)
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
  append_builtin_rule(
    self,
    fn(json) {
      match json {
        Number(v, ..) => is_safe_integer(v) && v >= min_safe && v <= max_safe
        _ => false
      }
    },
    message,
    IssueCode::Custom,
    Json::object({
      "type": Json::string("integer"),
      "minimum": Json::number(min_safe),
      "maximum": Json::number(max_safe),
    }),
    explicit_message=!msg.is_empty(),
  )
}

///|
/// Require a number to be strictly greater than a finite bound.
pub fn[N : NumericBound] Schema::gt(
  self : Schema,
  bound : N,
  msg~ : String = "",
) -> Schema {
  let bound = bound.to_bound()
  guard_numeric_bound(self, bound)
  append_builtin_rule(
    self,
    fn(value) {
      match value {
        Number(n, ..) => n > bound
        _ => false
      }
    },
    if msg.is_empty() {
      "Value must be > \{bound}"
    } else {
      msg
    },
    TooSmall("number", bound, false),
    Json::object({ "exclusiveMinimum": Json::number(bound) }),
    explicit_message=!msg.is_empty(),
  )
}

///|
/// Require a number to be strictly less than a finite bound.
pub fn[N : NumericBound] Schema::lt(
  self : Schema,
  bound : N,
  msg~ : String = "",
) -> Schema {
  let bound = bound.to_bound()
  guard_numeric_bound(self, bound)
  append_builtin_rule(
    self,
    fn(value) {
      match value {
        Number(n, ..) => n < bound
        _ => false
      }
    },
    if msg.is_empty() {
      "Value must be < \{bound}"
    } else {
      msg
    },
    TooBig("number", bound, false),
    Json::object({ "exclusiveMaximum": Json::number(bound) }),
    explicit_message=!msg.is_empty(),
  )
}

///|
fn guard_numeric_bound(schema : Schema, bound : Double) -> Unit {
  guard_no_user_transform(schema)
  if bound.is_nan() || bound.is_inf() {
    abort("numeric bounds must be finite")
  }
  guard inner_type(schema.schema_type) is NumberType else {
    abort("numeric bounds require a number schema")
  }
}
