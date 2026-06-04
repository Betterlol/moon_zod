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
  ArrayType(Schema)
  OptionalType(Schema)
  DefaultType(Schema, Json)
  EnumType(Array[String])
  UnionType(Array[Schema])
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
    ArrayType(_) => "Expected array"
    EnumType(_) => "Invalid enum value"
    _ => "Validation failed"
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
fn sub_path(path : String, name : String) -> String {
  if path.is_empty() {
    name
  } else {
    "\{path}.\{name}"
  }
}

///|
fn sub_index(path : String, i : Int) -> String {
  if path.is_empty() {
    "[\{i}]"
  } else {
    "\{path}[\{i}]"
  }
}

///|
fn value_in_array(s : String, arr : Array[String]) -> Bool {
  for v in arr {
    if v == s {
      return true
    }
  }
  false
}

///|
fn is_optional_schema(s : Schema) -> Bool {
  match s.schema_type {
    OptionalType(_) | DefaultType(_, _) => true
    _ => false
  }
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
          for field_name in spec.keys() {
            match spec.get(field_name) {
              Some(field_schema) => {
                let sp = sub_path(path, field_name)
                match input_map.get(field_name) {
                  None =>
                    if !is_optional_schema(field_schema) {
                      errors.push(ValidationError::{
                        path: sp,
                        message: "Required",
                        got: Json::null(),
                      })
                    }
                  Some(field_json) => {
                    let result = field_schema.parse(field_json, path=sp)
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
                      errors.push(ValidationError::{
                        path: sub_path(path, key),
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
    ArrayType(element_schema) =>
      match json {
        Array(elements) => {
          let mut errors : Array[ValidationError] = []
          let mut i = 0
          for element in elements {
            let sp = sub_index(path, i)
            let result = element_schema.parse(element, path=sp)
            match result {
              Err(item_errors) =>
                for e in item_errors {
                  errors.push(e)
                }
              _ => ()
            }
            i = i + 1
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
    OptionalType(inner) =>
      match json {
        Null => Ok(json)
        _ => inner.parse(json, path~)
      }
    DefaultType(inner, default_val) =>
      match json {
        Null => Ok(default_val)
        _ => inner.parse(json, path~)
      }
    EnumType(values) =>
      match json {
        String(s) =>
          if value_in_array(s, values) {
            Ok(json)
          } else {
            Err([
              ValidationError::{
                path,
                message: "Invalid enum value",
                got: json,
              },
            ])
          }
        _ =>
          Err([
            ValidationError::{
              path,
              message: "Expected string for enum",
              got: json,
            },
          ])
      }
    UnionType(schemas) => {
      let mut last_errors : Array[ValidationError]? = None
      for s in schemas {
        match s.parse(json, path~) {
          Ok(v) => return Ok(v)
          Err(errors) => last_errors = Some(errors)
        }
      }
      match last_errors {
        Some(errors) => Err(errors)
        None =>
          Err([
            ValidationError::{
              path,
              message: "Expected union type, none matched",
              got: json,
            },
          ])
      }
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
