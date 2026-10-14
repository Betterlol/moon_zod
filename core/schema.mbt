///|
/// Object validation mode.
pub(all) enum ObjectMode {
  Passthrough
  Strict
  Strip
} derive(Debug)

///|
#deprecated
pub extend ObjectMode with @debug.Debug::{to_repr}

///|
/// Internal tag for runtime type dispatch.
pub(all) enum SchemaType {
  StringType
  NumberType
  BooleanType
  NullType
  AnyType
  UnknownType
  ObjectType(Map[String, Schema], ObjectMode)
  ArrayType(Schema)
  TupleType(Array[Schema])
  OptionalType(Schema)
  NullableType(Schema)
  PrefaultType(Schema, Json)
  DefaultType(Schema, Json)
  EnumType(Array[String])
  UnionType(Array[Schema])
  IntersectionType(Array[Schema])
  PreprocessType(TransformClosure, Schema)
  TransformType(Schema, TransformClosure)
  LiteralType(Json)
  LazyType(() -> Schema)
  DiscriminatedUnionType(String, Map[String, Schema])
  PipeType(Schema, TransformClosure, Schema)
} derive(Debug)

///|
#deprecated
pub extend SchemaType with @debug.Debug::{to_repr}

///|
/// Internal wrapper for a transform function stored in TransformType.
pub(all) enum TransformKind {
  CustomTransform
  IdentityTransform
  TrimTransform
  LowerTransform
  UpperTransform
} derive(Debug)

///|
/// A built-in constraint's semantic identity, independent of rendered messages.
pub(all) enum Constraint {
  Minimum(String, Double, Bool)
  Maximum(String, Double, Bool)
  ExactLength(String, Int32)
  Multiple(Double)
  Integer
  Format(String)
  Pattern(String)
  Prefix(String)
  Suffix(String)
  Contains(String)
  Finite
  SafeInteger
  Opaque
} derive(Debug)

///|
/// Transform callbacks carry an explicit kind for inspection and source export.
pub(all) struct TransformClosure {
  f : (Json) -> Result[Json, String]
  kind : TransformKind
} derive(Debug)

///|
#deprecated
pub extend TransformClosure with @debug.Debug::{to_repr}

///|
/// A single validation rule: a predicate + error message + optional JSON Schema annotation.
pub(all) struct Rule {
  constraint : Constraint
  explicit_message : Bool
  check : (Json) -> Bool
  message : String
  code : IssueCode
  annotation : Json
} derive(Debug)

///|
#deprecated
pub extend Rule with @debug.Debug::{to_repr}

///|
/// A schema defines the shape and constraints of JSON data.
pub(all) struct Schema {
  id : Int32
  schema_type : SchemaType
  rules : Array[Rule]
  description : String
  required_error : String
  invalid_type_error : String
  name : String
  brand : String
} derive(Debug)

///|
#deprecated
pub extend Schema with @debug.Debug::{to_repr}

///|
/// Attach a human-readable description to a schema.
/// The description is rendered by `schema_to_prompt()` alongside type and constraints,
/// helping LLMs understand the semantic meaning of each field.
pub fn Schema::describe(self : Schema, text : String) -> Schema {
  { ..self, id: new_schema_id(), description: text, }
}

///|
/// Give a schema a name for export.
/// When used with `schema_to_prompt_named()`, named schemas are extracted as separate
/// interface/type definitions in the generated prompt, supporting Object and Enum types.
pub fn Schema::name(self : Schema, text : String) -> Schema {
  { ..self, id: new_schema_id(), name: text, }
}

///|
/// Assign a brand to a schema for nominal typing.
/// Branded schemas carry a type-level marker that distinguishes
/// structurally identical schemas (e.g., `UserId` vs `string`).
/// The brand is rendered in prompt and JSON Schema exports.
pub fn Schema::brand(self : Schema, text : String) -> Schema {
  { ..self, id: new_schema_id(), brand: text, }
}

///|
/// Override the error message when a required field is missing.
/// Only effective when this schema is used as an object field value.
pub fn Schema::required_error(self : Schema, text : String) -> Schema {
  { ..self, id: new_schema_id(), required_error: text, }
}

///|
/// Override the error message when the input type does not match.
pub fn Schema::invalid_type_error(self : Schema, text : String) -> Schema {
  let schema_type = match self.schema_type {
    OptionalType(inner) => OptionalType(inner.invalid_type_error(text))
    NullableType(inner) => NullableType(inner.invalid_type_error(text))
    DefaultType(inner, value) =>
      DefaultType(inner.invalid_type_error(text), value)
    PrefaultType(inner, value) =>
      PrefaultType(inner.invalid_type_error(text), value)
    TransformType(inner, closure) =>
      TransformType(inner.invalid_type_error(text), closure)
    PreprocessType(closure, inner) =>
      PreprocessType(closure, inner.invalid_type_error(text))
    PipeType(input, bridge, output) =>
      PipeType(input, bridge, output.invalid_type_error(text))
    other => other
  }
  { ..self, id: new_schema_id(), schema_type, invalid_type_error: text, }
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
  if !self.rules.is_empty() {
    let rules = self.rules.copy()
    let i = rules.length() - 1
    rules[i] = { ..rules[i], message: text, explicit_message: true, }
    return { ..self, id: new_schema_id(), rules, }
  }
  let schema_type = match self.schema_type {
    OptionalType(inner) => OptionalType(inner.message(text))
    NullableType(inner) => NullableType(inner.message(text))
    PrefaultType(inner, value) => PrefaultType(inner.message(text), value)
    DefaultType(inner, value) => DefaultType(inner.message(text), value)
    TransformType(inner, closure) => TransformType(inner.message(text), closure)
    PreprocessType(closure, inner) =>
      PreprocessType(closure, inner.message(text))
    PipeType(input, bridge, output) =>
      PipeType(input, bridge, output.message(text))
    _ => abort("message() must follow a rule method")
  }
  { ..self, id: new_schema_id(), schema_type, }
}

///|
/// Peel OptionalType / DefaultType wrappers to find the effective base type.
pub fn inner_type(t : SchemaType) -> SchemaType {
  match t {
    OptionalType(inner) | NullableType(inner) | PrefaultType(inner, _) =>
      inner_type(inner.schema_type)
    DefaultType(inner, _) => inner_type(inner.schema_type)
    PreprocessType(_, inner) => inner_type(inner.schema_type)
    TransformType(inner, _) => inner_type(inner.schema_type)
    LazyType(_) | DiscriminatedUnionType(_, _) => t
    PipeType(_, _, output) => inner_type(output.schema_type)
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
  code : IssueCode,
) -> Schema {
  append_rule_with_annotation(schema, check, message, code, Json::null())
}

///|
/// Append a rule with a JSON Schema annotation fragment.
/// The annotation is merged into the JSON Schema output when `to_json_schema()`
/// is called, enabling constraint export (minLength, maximum, pattern, etc.).
pub fn append_rule_with_annotation(
  schema : Schema,
  check : (Json) -> Bool,
  message : String,
  code : IssueCode,
  annotation : Json,
) -> Schema {
  append_typed_rule(schema, {
    check,
    message,
    code,
    annotation,
    constraint: Opaque,
    explicit_message: true,
  })
}

///|

///|
fn guard_no_user_transform(schema : Schema) -> Unit {
  match schema.schema_type {
    TransformType(inner, cls) =>
      if cls.kind is CustomTransform {
        abort(
          "cannot chain type-specific validation after transform(); use .pipe() instead",
        )
      } else {
        guard_no_user_transform(inner)
      }
    OptionalType(inner)
    | NullableType(inner)
    | DefaultType(inner, _)
    | PrefaultType(inner, _)
    | PreprocessType(_, inner) => guard_no_user_transform(inner)
    PipeType(_, _, output) => guard_no_user_transform(output)
    _ => ()
  }
}

///|
fn type_msg(schema : Schema) -> String {
  let default = "Expected " + type_origin(schema.schema_type)
  if !schema.invalid_type_error.is_empty() {
    schema.invalid_type_error
  } else {
    default
  }
}

///|

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
    path_key(name)
  } else {
    path +
    (if path_key(name).has_prefix("[") { "" } else { "." }) +
    path_key(name)
  }
}

///|
pub fn sub_index(path : String, i : Int32) -> String {
  if path.is_empty() {
    "[\{i}]"
  } else {
    "\{path}[\{i}]"
  }
}

///|
pub fn is_optional_schema(s : Schema) -> Bool {
  match s.schema_type {
    OptionalType(_) | DefaultType(_, _) | PrefaultType(_, _) => true
    NullableType(inner) | TransformType(inner, _) | PreprocessType(_, inner) =>
      is_optional_schema(inner)
    PipeType(input, _, output) =>
      has_missing_default(input) ||
      (is_optional_schema(input) && is_optional_schema(output))
    UnionType(branches) => branches.any(is_optional_schema)
    IntersectionType(branches) => branches.all(is_optional_schema)
    LazyType(_) => false
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
) -> RawSchemaResult {
  let out = parse_output(schema, json, path_stack)
  if out.issues.is_empty() {
    Ok(out.value)
  } else {
    Err(out.issues)
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
  path~ : String = "",
) -> SchemaResult {
  Schema::safe_parse(self, json, ParseParams::{ path, error_map: None, })
}

///|
/// Validate `json` against this schema with extended parameters.
/// Supports contextual error map override.
///
/// # Example
/// ```mbt nocheck
/// schema.safe_parse(json, { error_map: fn(code, path, input) {
///   match code { InvalidType(expected) => Some("必须是: " + expected) _ => None }
/// }})
/// ```
pub fn Schema::safe_parse(
  self : Schema,
  json : Json,
  params : ParseParams,
) -> SchemaResult {
  let path_stack : Array[String] = if params.path.is_empty() {
    []
  } else {
    [params.path]
  }
  match parse_inner(self, copy_json(json), path_stack) {
    Ok(v) => Ok(v)
    Err(raw) => Err(finalize_issues(raw, params))
  }
}

///|
/// Generate a schema from a JSON value.
/// Simple heuristics are used to infer types and constraints from the value.
pub fn json_infer_schema(json : Json) -> Schema {
  match json {
    String(_) => string()
    Number(v, ..) =>
      // Check if it's an integer value
      if is_safe_integer(v) {
        number().int()
      } else {
        number()
      }
    True | False => boolean()
    Null => null()
    Array(elements) => {
      let branches = elements.map(json_infer_schema)
      let elem_schema = if branches.is_empty() {
        unknown()
      } else if branches.length() == 1 {
        branches[0]
      } else {
        union(branches)
      }
      array(elem_schema)
    }
    Object(map) => {
      let fields : Map[String, Schema] = Map([])
      for key, val in map {
        let field_schema = json_infer_schema(val)
        fields.set(key, field_schema)
      }
      object(fields)
    }
  }
}

///|
/// Parse an absent value without conflating it with explicit JSON null.
/// An absent optional result is None; a default/prefault result is Some(value).
pub fn Schema::parse_missing(
  self : Schema,
) -> Result[Json?, Array[ValidationError]] {
  let out = parse_absent(self, [])
  if out.issues.is_empty() {
    Ok(if out.missing { None } else { Some(out.value) })
  } else {
    Err(finalize_issues(out.issues, ParseParams::default()))
  }
}
