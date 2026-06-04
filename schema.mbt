///|
/// Object validation mode.
pub(all) enum ObjectMode {
  Passthrough
  Strict
}

///|
/// Internal tag for runtime type dispatch.
pub(all) enum SchemaType {
  StringType
  NumberType
  BooleanType
  NullType
  ObjectType(Map[String, Schema], ObjectMode)
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
    ObjectType(_, _) => "Expected object"
  }
}

///|
fn collect_errors(
  errors : Array[ValidationError],
  path : String,
  json : Json,
  rules : Array[Rule],
) -> Array[ValidationError] {
  let result : Array[ValidationError] = []
  for rule in rules {
    if !(rule.check)(json) {
      result.push(ValidationError::{ path, message: rule.message, got: json })
    }
  }
  for e in errors {
    result.push(e)
  }
  result
}

///|
/// Validate `json` against this schema.
pub fn Schema::parse(
  self : Schema,
  json : Json,
  path? : String = "",
) -> SchemaResult {
  match self.schema_type {
    ObjectType(spec, mode) =>
      match json {
        Object(input_map) => {
          let mut errors : Array[ValidationError] = []
          let sub = fn(name : String) -> String {
            if path.is_empty() {
              name
            } else {
              "\{path}.\{name}"
            }
          }
          for field_name in spec.keys() {
            match spec.get(field_name) {
              Some(field_schema) => {
                let sub_path = sub(field_name)
                match input_map.get(field_name) {
                  None =>
                    errors.push(ValidationError::{
                      path: sub_path,
                      message: "Required",
                      got: Json::null(),
                    })
                  Some(field_json) => {
                    let result = field_schema.parse(field_json, path=sub_path)
                    match result {
                      Err(field_errors) =>
                        for e in field_errors {
                          errors.push(e)
                        }
                      _ => ()
                    }
                  }
                }
              }
              None => ()
            }
          }
          match mode {
            Strict =>
              for key in input_map.keys() {
                match input_map.get(key) {
                  Some(value) =>
                    if !spec.contains(key) {
                      let field_path = sub(key)
                      errors.push(ValidationError::{
                        path: field_path,
                        message: "Unexpected field",
                        got: value,
                      })
                    }
                  None => ()
                }
              }
            _ => ()
          }
          errors = collect_errors(errors, path, json, self.rules)
          if errors.is_empty() {
            Ok(json)
          } else {
            Err(errors)
          }
        }
        _ =>
          Err([
            ValidationError::{
              path,
              message: expected_msg(self.schema_type),
              got: json,
            },
          ])
      }
    _ => {
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
      let errors = collect_errors([], path, json, self.rules)
      if errors.is_empty() {
        Ok(json)
      } else {
        Err(errors)
      }
    }
  }
}
