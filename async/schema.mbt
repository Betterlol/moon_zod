///|
/// A non-blocking refinement run after a schema has successfully parsed.
///
/// The callback receives the cleaned JSON returned by the synchronous schema
/// parser. Return `Some(issue)` to report a custom validation failure, or
/// `None` when the value is accepted.
pub type AsyncCheck = async (Json) -> AsyncIssue?

///|
/// An asynchronous refinement that returns all issues found in cleaned JSON.
/// Return an empty array to accept the value. Issues retain their array order.
pub type AsyncSuperCheck = async (Json) -> Array[AsyncIssue]

///|
/// An execution error raised by the refinement at zero-based `index`.
/// The original error is preserved so callers can distinguish service failures.
pub(all) struct AsyncCheckError {
  index : Int32
  error : Error
}

///|
/// Validation failures and asynchronous execution failures are distinct.
/// `Execution` carries every execution error and any collected validation errors.
pub(all) enum AsyncParseError {
  Validation(Array[@core.ValidationError])
  Execution(Array[AsyncCheckError], Array[@core.ValidationError])
}

///|
/// Result of asynchronous parsing; ordinary errors are returned, never raised.
/// Task cancellation still propagates through the asynchronous runtime.
pub type AsyncParseResult = Result[Json, AsyncParseError]

///|
/// A synchronous moon_zod schema with additional asynchronous refinements.
///
/// Core schema parsing remains synchronous. This wrapper first calls the
/// wrapped schema, including its transformations and Strip-mode cleanup, then
/// runs every asynchronous refinement in declaration order.
pub struct AsyncSchema {
  priv schema : @core.Schema
  priv checks : Array[AsyncSuperCheck]
}

///|
/// Wrap a synchronous schema so that asynchronous refinements can be added.
pub fn async_schema(schema : @core.Schema) -> AsyncSchema {
  { schema, checks: [], }
}

///|
/// Add an asynchronous refinement.
///
/// Refinements run only after the synchronous schema succeeds. All refinement
/// failures are collected into the returned `AsyncParseResult`.
pub fn AsyncSchema::refine_async(
  self : AsyncSchema,
  check : AsyncCheck,
) -> AsyncSchema {
  self.super_refine_async(value => {
    match check(value) {
      None => []
      Some(issue) => [issue]
    }
  })
}

///|
/// Add a refinement that can report multiple issues for one value.
/// Checks and their issues are collected in declaration order. A raised error
/// reports this callback's index, rather than an index for each returned issue.
/// Like `refine_async`, adding a check leaves the original wrapper unchanged.
pub fn AsyncSchema::super_refine_async(
  self : AsyncSchema,
  check : AsyncSuperCheck,
) -> AsyncSchema {
  { ..self, checks: self.checks + [check], }
}

///|
/// Parse a JSON value and then run every asynchronous refinement.
///
/// A synchronous parse failure is returned as `Validation` and skips asynchronous
/// checks. Asynchronous failures use `IssueCode::Custom` and are appended in
/// refinement declaration order. Raised check errors are collected separately
/// as `Execution`; remaining checks still run. Cancellation is not caught.
pub async fn AsyncSchema::parse_async(
  self : AsyncSchema,
  json : Json,
  root_path~ : String = "",
) -> AsyncParseResult noraise {
  match self.schema.parse(json, path=root_path) {
    Err(errors) => Err(Validation(errors))
    Ok(clean) => self.check_clean_async(clean, root_path~)
  }
}

///|
/// Run refinements on already parsed output without repeating schema effects.
async fn AsyncSchema::check_clean_async(
  self : AsyncSchema,
  clean : Json,
  root_path~ : String,
) -> AsyncParseResult noraise {
  let errors : Array[@core.ValidationError] = []
  let execution_errors : Array[AsyncCheckError] = []
  for index, check in self.checks {
    let issues = check(clean) catch {
      error => {
        execution_errors.push({ index, error, })
        continue
      }
    }
    for issue in issues {
      errors.push({
        code: @core.IssueCode::Custom,
        path: join_async_path(root_path, issue.path),
        path_segments: @core.parse_path(join_async_path(root_path, issue.path)),
        message: issue.message,
        got: issue.got,
      })
    }
  }
  if !execution_errors.is_empty() {
    Err(Execution(execution_errors, errors))
  } else if errors.is_empty() {
    Ok(clean)
  } else {
    Err(Validation(errors))
  }
}

///|
/// Combine a parse root path with a refinement-relative path.
fn join_async_path(root_path : String, relative_path : String) -> String {
  if root_path.is_empty() {
    relative_path
  } else if relative_path.is_empty() {
    root_path
  } else if relative_path.has_prefix("[") {
    root_path + relative_path
  } else {
    root_path + "." + relative_path
  }
}
