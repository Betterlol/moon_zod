///|
/// Internal tag for runtime type dispatch.
pub(all) enum SchemaType {
  StringType
  NumberType
  BooleanType
  NullType
}

///|
/// A single validation rule: a predicate + error message.
pub(all) struct Rule {
  check : (Json) -> Bool
  message : String
}

///|
/// A schema defines the shape and constraints of JSON data.
pub struct Schema {
  schema_type : SchemaType
  rules : Array[Rule]
}

///|
fn expected_msg(schema_type : SchemaType) -> String {
  match schema_type {
    StringType => "Expected string"
    NumberType => "Expected number"
    BooleanType => "Expected boolean"
    NullType => "Expected null"
  }
}

///|
/// Validate `json` against this schema.
pub fn Schema::parse(
  self : Schema,
  json : Json,
  path? : String = "",
) -> SchemaResult {
  let valid = match (self.schema_type, json) {
    (StringType, String(_)) => true
    (NumberType, Number(_)) => true
    (BooleanType, True | False) => true
    (NullType, Null) => true
    _ => false
  }
  if !valid {
    return Err([
      ValidationError::{
        path,
        message: expected_msg(self.schema_type),
        got: json,
      },
    ])
  }
  let errors : Array[ValidationError] = []
  for rule in self.rules {
    if !(rule.check)(json) {
      errors.push(ValidationError::{ path, message: rule.message, got: json })
    }
  }
  if errors.is_empty() {
    Ok(json)
  } else {
    Err(errors)
  }
}
