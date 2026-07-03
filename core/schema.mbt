///|
/// Object validation mode.
pub(all) enum ObjectMode {
  Passthrough
  Strict
  Strip
} derive(Debug)

///|
/// Internal tag for runtime type dispatch.
pub(all) enum SchemaType {
  StringType
  NumberType
  BooleanType
  NullType
  ObjectType(Map[String, Schema], ObjectMode)
  ArrayType(Schema)
  TupleType(Array[Schema])
  OptionalType(Schema)
  DefaultType(Schema, Json)
  EnumType(Array[String])
  UnionType(Array[Schema])
  IntersectionType(Array[Schema])
  TransformType(Schema, TransformClosure)
  LiteralType(Json)
} derive(Debug)

///|
/// Internal wrapper for a transform function stored in TransformType.
pub(all) struct TransformClosure {
  f : (Json) -> Result[Json, String]
} derive(Debug)

///|
/// A single validation rule: a predicate + error message + optional JSON Schema annotation.
pub(all) struct Rule {
  check : (Json) -> Bool
  message : String
  annotation : Json
} derive(Debug)

///|
/// A schema defines the shape and constraints of JSON data.
pub(all) struct Schema {
  schema_type : SchemaType
  rules : Array[Rule]
  description : String
  required_error : String
  invalid_type_error : String
  name : String
  brand : String
} derive(Debug)

///|
/// Attach a human-readable description to a schema.
/// The description is rendered by `schema_to_prompt()` alongside type and constraints,
/// helping LLMs understand the semantic meaning of each field.
pub fn Schema::describe(self : Schema, text : String) -> Schema {
  { ..self, description: text }
}

///|
/// Give a schema a name for export.
/// When used with `schema_to_prompt_named()`, named schemas are extracted as separate
/// interface/type definitions in the generated prompt, supporting Object and Enum types.
pub fn Schema::name(self : Schema, text : String) -> Schema {
  { ..self, name: text }
}

///|
/// Assign a brand to a schema for nominal typing.
/// Branded schemas carry a type-level marker that distinguishes
/// structurally identical schemas (e.g., `UserId` vs `string`).
/// The brand is rendered in prompt and JSON Schema exports.
pub fn Schema::brand(self : Schema, text : String) -> Schema {
  { ..self, brand: text }
}

///|
/// Override the error message of the last rule in the chain.
/// Peels through OptionalType / DefaultType / TransformType wrappers
/// to find the base schema with the rules array.
///
/// # Example
/// ```
/// string().min(2).message("姓名至少需要 2 个字符")
/// ```
pub fn Schema::message(self : Schema, text : String) -> Schema {
  match self.schema_type {
    OptionalType(inner) => {
      let new_inner = inner.message(text)
      {
        schema_type: OptionalType(new_inner),
        rules: [],
        description: self.description,
        required_error: self.required_error,
        invalid_type_error: self.invalid_type_error,
        name: self.name,
        brand: self.brand,
      }
    }
    DefaultType(inner, val) => {
      let new_inner = inner.message(text)
      {
        schema_type: DefaultType(new_inner, val),
        rules: [],
        description: self.description,
        required_error: self.required_error,
        invalid_type_error: self.invalid_type_error,
        name: self.name,
        brand: self.brand,
      }
    }
    TransformType(inner, cls) => {
      let new_inner = inner.message(text)
      {
        schema_type: TransformType(new_inner, cls),
        rules: [],
        description: self.description,
        required_error: self.required_error,
        invalid_type_error: self.invalid_type_error,
        name: self.name,
        brand: self.brand,
      }
    }
    _ => {
      let n = self.rules.length()
      if n == 0 {
        abort("message() must follow a rule method")
      }
      let new_rules : Array[Rule] = []
      for i = 0; i < n; i = i + 1 {
        if i == n - 1 {
          new_rules.push({ ..self.rules[i], message: text })
        } else {
          new_rules.push(self.rules[i])
        }
      }
      { ..self, rules: new_rules }
    }
  }
}

///|
/// Peel OptionalType / DefaultType wrappers to find the effective base type.
pub fn inner_type(t : SchemaType) -> SchemaType {
  match t {
    OptionalType(inner) => inner.schema_type
    DefaultType(inner, _) => inner.schema_type
    TransformType(inner, _) => inner.schema_type
    LiteralType(_) => t
    other => other
  }
}

///|
/// Append a rule through decoration wrappers.
pub fn append_rule(
  schema : Schema,
  check : (Json) -> Bool,
  message : String,
) -> Schema {
  append_rule_with_annotation(schema, check, message, Json::null())
}

///|
/// Append a rule with a JSON Schema annotation fragment.
/// The annotation is merged into the JSON Schema output when `to_json_schema()`
/// is called, enabling constraint export (minLength, maximum, pattern, etc.).
pub fn append_rule_with_annotation(
  schema : Schema,
  check : (Json) -> Bool,
  message : String,
  annotation : Json,
) -> Schema {
  match schema.schema_type {
    OptionalType(inner) => {
      let new_inner = append_rule_with_annotation(
        inner, check, message, annotation,
      )
      {
        schema_type: OptionalType(new_inner),
        rules: [],
        description: schema.description,
        required_error: schema.required_error,
        invalid_type_error: schema.invalid_type_error,
        name: schema.name,
        brand: schema.brand,
      }
    }
    DefaultType(inner, default_val) => {
      let new_inner = append_rule_with_annotation(
        inner, check, message, annotation,
      )
      {
        schema_type: DefaultType(new_inner, default_val),
        rules: [],
        description: schema.description,
        required_error: schema.required_error,
        invalid_type_error: schema.invalid_type_error,
        name: schema.name,
        brand: schema.brand,
      }
    }
    _ => { ..schema, rules: schema.rules + [{ check, message, annotation }] }
  }
}

///|
fn type_error_msg(schema : Schema) -> String {
  if !schema.invalid_type_error.is_empty() {
    schema.invalid_type_error
  } else {
    expected_msg(schema.schema_type)
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
    TupleType(_) => "Expected tuple"
    EnumType(_) => "Invalid enum value"
    IntersectionType(_) => "Expected intersection match"
    TransformType(_, _) => "Validation failed"
    LiteralType(_) => "Expected literal value"
    _ => "Validation failed"
  }
}

///|
fn collect_errors(
  errors : Array[ValidationError],
  path_stack : Array[String],
  json : Json,
  rules : Array[Rule],
) -> Unit {
  let path = format_path(path_stack)
  for rule in rules {
    if !(rule.check)(json) {
      errors.push(ValidationError::{ path, message: rule.message, got: json })
    }
  }
}

///|
pub fn format_path(stack : Array[String]) -> String {
  let mut result = ""
  let mut first = true
  for part in stack {
    if first {
      result = result + part
    } else if part.has_prefix("[") {
      result = result + part
    } else {
      result = result + "." + part
    }
    first = false
  }
  result
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
/// Internal dispatch that all parse helpers use for recursion.
/// Accepts a mutable path_stack that is shared across the call tree.
fn parse_inner(
  schema : Schema,
  json : Json,
  path_stack : Array[String],
) -> SchemaResult {
  // All parse helpers are called through this function so the same
  // mutable path_stack is shared across the entire call tree.
  match schema.schema_type {
    ObjectType(spec, mode) => schema.parse_object(spec, mode, json, path_stack)
    ArrayType(element_schema) =>
      schema.parse_array(element_schema, json, path_stack)
    TupleType(items) => schema.parse_tuple(items, json, path_stack)
    OptionalType(inner) => schema.parse_optional(inner, json, path_stack)
    DefaultType(inner, default_val) =>
      schema.parse_default(inner, default_val, json, path_stack)
    EnumType(values) => schema.parse_enum(values, json, path_stack)
    UnionType(schemas) => schema.parse_union(schemas, json, path_stack)
    IntersectionType(schemas) =>
      schema.parse_intersection(schemas, json, path_stack)
    TransformType(inner, closure) =>
      schema.parse_transform(inner, closure, json, path_stack)
    LiteralType(expected) => schema.parse_literal(expected, json, path_stack)
    _ => {
      let valid = match (schema.schema_type, json) {
        (StringType, String(_)) => true
        (NumberType, Number(_)) => true
        (BooleanType, True | False) => true
        (NullType, Null) => true
        _ => false
      }
      if !valid {
        let path = format_path(path_stack)
        return Err([
          ValidationError::{ path, message: type_error_msg(schema), got: json },
        ])
      }
      let errors : Array[ValidationError] = []
      collect_errors(errors, path_stack, json, schema.rules)
      if errors.is_empty() {
        Ok(json)
      } else {
        Err(errors)
      }
    }
  }
}

///|
/// Validate `json` against this schema.
/// Public API — accepts an optional root path string.
/// Internally converts to a mutable path stack to avoid string allocations
/// on the success path.
pub fn Schema::parse(
  self : Schema,
  json : Json,
  path? : String = "",
) -> SchemaResult {
  let path_stack : Array[String] = if path.is_empty() { [] } else { [path] }
  parse_inner(self, json, path_stack)
}

///|
/// Generate a schema from a JSON value.
/// Simple heuristics are used to infer types and constraints from the value.
pub fn json_infer_schema(json : Json) -> Schema {
  match json {
    String(_) => string()
    Number(v, ..) =>
      // Check if it's an integer value
      if v == v.to_int().to_double() {
        number().int()
      } else {
        number()
      }
    True | False => boolean()
    Null => null()
    Array(elements) => {
      let elem_schema = if elements.length() > 0 {
        json_infer_schema(elements[0])
      } else {
        string()
      }
      array(elem_schema)
    }
    Object(map) => {
      let fields : Map[String, Schema] = {}
      for key, val in map {
        let field_schema = json_infer_schema(val)
        fields.set(key, field_schema)
      }
      object(fields)
    }
  }
}
