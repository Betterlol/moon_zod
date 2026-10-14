///|
/// Machine-readable issue code for structured error classification.
pub(all) enum IssueCode {
  InvalidType(String)
  TooBig(String, Double, Bool)
  TooSmall(String, Double, Bool)
  InvalidFormat(String)
  NotMultipleOf(Double)
  UnrecognizedKeys(Array[String])
  InvalidUnion(Array[Array[RawIssue]])
  MissingRequired(String)
  InvalidKey(String)
  InvalidElement(String, Int32)
  InvalidValue(Array[Json])
  Custom
} derive(Debug, Eq)

///|
#deprecated
pub extend IssueCode with @debug.Debug::{to_repr}

///|
#deprecated
pub extend IssueCode with Eq::{not_equal, equal}

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
  ParseParams::{ path: "", error_map: None, }
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
  path_segments : Array[PathSegment]
  explicit_message : Bool
} derive(Debug, Eq)

///|
/// Resolve an error message using the error map priority chain.
/// Priority: explicit Schema/rule message → error_map → default message.
pub fn finalize_issue(raw : RawIssue, params : ParseParams) -> ValidationError {
  let resolved = resolve_raw_issue(raw, params)
  ValidationError::{
    code: resolved.code,
    path: resolved.path,
    path_segments: resolved.path_segments,
    message: resolved.message,
    got: resolved.input,
  }
}

///|
fn resolve_raw_issue(raw : RawIssue, params : ParseParams) -> RawIssue {
  let code = match raw.code {
    InvalidUnion(branches) =>
      InvalidUnion(
        branches.map(fn(branch) {
          branch.map(fn(issue) { resolve_raw_issue(issue, params) })
        }),
      )
    other => other
  }
  let message = if raw.explicit_message {
    raw.message
  } else {
    match params.error_map {
      Some(map) => map(code, raw.path, raw.input).unwrap_or(raw.message)
      None => raw.message
    }
  }
  { ..raw, code, message, }
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
  path_stack : Array[String],
  json : Json,
  rules : Array[Rule],
) -> Unit {
  for rule in rules {
    if !(rule.check)(json) {
      out.push(RawIssue::{
        code: rule.code,
        path: format_path(path_stack),
        path_segments: stack_segments(path_stack),
        explicit_message: rule.explicit_message,
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
    NullableType(_) => "nullable"
    PrefaultType(_, _) => "prefault"
    DefaultType(_, _) => "default"
    LazyType(_) => "lazy"
    DiscriminatedUnionType(_, _) => "discriminated_union"
    PipeType(_, _, _) => "pipe"
  }
}
