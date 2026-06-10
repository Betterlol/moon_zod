///|
/// Create a schema that validates JSON numbers.
pub fn number() -> Schema {
  { schema_type: NumberType, rules: [], description: "" }
}

///|
/// Require the number to be an integer (no fractional part).
pub fn Schema::int(self : Schema) -> Schema {
  match inner_type(self.schema_type) {
    NumberType => ()
    _ => abort("int() is only valid for number schemas")
  }
  append_rule_with_annotation(
    self,
    fn(json) {
      match json {
        Number(v, ..) => v == v.to_int().to_double()
        _ => false
      }
    },
    "Value must be an integer",
    Json::object({ "type": Json::string("integer") }),
  )
}

///|
/// Require the number to be positive (> 0).
pub fn Schema::positive(self : Schema) -> Schema {
  match inner_type(self.schema_type) {
    NumberType => ()
    _ => abort("positive() is only valid for number schemas")
  }
  append_rule_with_annotation(
    self,
    fn(json) {
      match json {
        Number(v, ..) => v > 0.0
        _ => false
      }
    },
    "Value must be positive",
    Json::object({ "exclusiveMinimum": Json::number(0.0) }),
  )
}

///|
/// Require the number to be negative (< 0).
pub fn Schema::negative(self : Schema) -> Schema {
  match inner_type(self.schema_type) {
    NumberType => ()
    _ => abort("negative() is only valid for number schemas")
  }
  append_rule_with_annotation(
    self,
    fn(json) {
      match json {
        Number(v, ..) => v < 0.0
        _ => false
      }
    },
    "Value must be negative",
    Json::object({ "exclusiveMaximum": Json::number(0.0) }),
  )
}

///|
/// Require the number to be a multiple of `n`.
pub fn Schema::multipleOf(self : Schema, n : Int) -> Schema {
  match inner_type(self.schema_type) {
    NumberType => ()
    _ => abort("multipleOf() is only valid for number schemas")
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
    "Value must be a multiple of \{n}",
    Json::object({ "multipleOf": Json::number(n.to_double()) }),
  )
}
