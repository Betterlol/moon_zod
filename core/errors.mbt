///|
/// Machine-readable issue code for structured error classification.
pub(all) enum IssueCode {
  InvalidType(String)
  TooBig(String, Double, Bool)
  TooSmall(String, Double, Bool)
  InvalidFormat(String)
  NotMultipleOf(Double)
  UnrecognizedKeys(Array[String])
  InvalidUnion(Array[String])
  MissingRequired(String)
  InvalidKey(String)
  InvalidElement(String, Int)
  InvalidValue(Array[Json])
  Custom
} derive(Debug, Eq)

///|
/// Error map function: contextual override for error messages.
/// Returns `Some(msg)` to override, `None` to fall through to the pre-resolved message.
pub type ErrorMap = (IssueCode, String, Json) -> String?

///|
/// Parameters for `Schema::safe_parse`.
pub(all) struct ParseParams {
  path : String
  error_map : ErrorMap?
}

///|
pub fn ParseParams::default() -> ParseParams {
  ParseParams::{ path: "", error_map: None }
}

///|
/// A raw validation issue with the message pre-resolved at the generation site.
/// No Schema reference needed — messages are resolved immediately from
/// rule.message / schema.invalid_type_error / schema.required_error / hardcoded default.
pub(all) struct RawIssue {
  code : IssueCode
  path : String
  message : String
  input : Json
}

///|
/// Resolve an error message using the error map priority chain.
/// Priority: error_map (contextual) → pre-resolved message.
pub fn finalize_issue(raw : RawIssue, params : ParseParams) -> ValidationError {
  let message = match params.error_map {
    Some(map) =>
      match map(raw.code, raw.path, raw.input) {
        Some(m) => if m.is_empty() { raw.message } else { m }
        None => raw.message
      }
    None => raw.message
  }
  ValidationError::{ code: raw.code, path: raw.path, message, got: raw.input }
}

///|
/// Convert raw issues to validation errors using finalize_issue.
pub fn finalize_issues(
  raw_issues : Array[RawIssue],
  params : ParseParams,
) -> Array[ValidationError] {
  raw_issues.map(fn(raw) { finalize_issue(raw, params) })
}

///|
/// Collect raw issues from rule failures.
pub fn collect_raw_errors(
  out : Array[RawIssue],
  path : String,
  json : Json,
  rules : Array[Rule],
) -> Unit {
  for rule in rules {
    if !(rule.check)(json) {
      out.push(RawIssue::{
        code: rule.code,
        path,
        message: rule.message,
        input: json,
      })
    }
  }
}

///|
/// Map SchemaType to its origin string for IssueCode payloads.
pub fn type_origin(t : SchemaType) -> String {
  match t {
    StringType => "string"
    NumberType => "number"
    BooleanType => "boolean"
    NullType => "null"
    AnyType => "any"
    UnknownType => "unknown"
    ObjectType(_, _) => "object"
    ArrayType(_) => "array"
    TupleType(_) => "tuple"
    EnumType(_) => "enum"
    UnionType(_) => "union"
    IntersectionType(_) => "intersection"
    LiteralType(_) => "literal"
    TransformType(_, _) => "transform"
    PreprocessType(_, _) => "preprocess"
    OptionalType(_) => "optional"
    DefaultType(_, _) => "default"
  }
}
