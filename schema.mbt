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
/// Peel OptionalType / DefaultType wrappers to find the effective base type.
pub fn inner_type(t : SchemaType) -> SchemaType {
  match t {
    OptionalType(inner) => inner.schema_type
    DefaultType(inner, _) => inner.schema_type
    other => other
  }
}

///|
/// Append a rule through decoration wrappers.
/// When called on OptionalType / DefaultType, the rule is pushed to the
/// innermost base schema so that chaining after `.optional()` / `.default()`
/// works correctly (e.g. `string().optional().min(3)`).
pub fn append_rule(
  schema : Schema,
  check : (Json) -> Bool,
  message : String,
) -> Schema {
  match schema.schema_type {
    OptionalType(inner) => {
      let new_inner = append_rule(inner, check, message)
      { schema_type: OptionalType(new_inner), rules: [] }
    }
    DefaultType(inner, default_val) => {
      let new_inner = append_rule(inner, check, message)
      { schema_type: DefaultType(new_inner, default_val), rules: [] }
    }
    _ => { ..schema, rules: schema.rules + [{ check, message }] }
  }
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
) -> Unit {
  for rule in rules {
    if !(rule.check)(json) {
      errors.push(ValidationError::{ path, message: rule.message, got: json })
    }
  }
}

///|
pub fn sub_path(path : String, name : String) -> String {
  if path.is_empty() {
    name
  } else {
    "\{path}.\{name}"
  }
}

///|
pub fn sub_index(path : String, i : Int) -> String {
  if path.is_empty() {
    "[\{i}]"
  } else {
    "\{path}[\{i}]"
  }
}

///|
pub fn value_in_array(s : String, arr : Array[String]) -> Bool {
  for v in arr {
    if v == s {
      return true
    }
  }
  false
}

///|
pub fn is_optional_schema(s : Schema) -> Bool {
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
    ObjectType(spec, mode) => self.parse_object(spec, mode, json, path)
    ArrayType(element_schema) => self.parse_array(element_schema, json, path)
    OptionalType(inner) => self.parse_optional(inner, json, path)
    DefaultType(inner, default_val) =>
      self.parse_default(inner, default_val, json, path)
    EnumType(values) => self.parse_enum(values, json, path)
    UnionType(schemas) => self.parse_union(schemas, json, path)
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
      let errors : Array[ValidationError] = []
      collect_errors(errors, path, json, self.rules)
      if errors.is_empty() {
        Ok(json)
      } else {
        Err(errors)
      }
    }
  }
}
