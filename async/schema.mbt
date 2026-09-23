///|
/// A failure reported by an asynchronous refinement.
///
/// `path` is relative to the root path passed to `parse_async`. `got` should
/// contain the value that caused the refinement to fail.
pub(all) struct AsyncIssue {
  path : String
  message : String
  got : Json
}

///|
/// Create an asynchronous validation failure.
///
/// The default path identifies the value being checked. Pass a relative path
/// such as `"email"` or `"items[0]"` for a more precise error location.
pub fn async_issue(
  message : String,
  path? : String = "",
  got? : Json = Json::null(),
) -> AsyncIssue {
  { path, message, got, }
}

///|
/// A non-blocking refinement run after a schema has successfully parsed.
///
/// The callback receives the cleaned JSON returned by the synchronous schema
/// parser. Return `Some(issue)` to report a custom validation failure, or
/// `None` when the value is accepted.
pub type AsyncCheck = async (Json) -> AsyncIssue?

///|
/// A synchronous moon_zod schema with additional asynchronous refinements.
///
/// Core schema parsing remains synchronous. This wrapper first calls the
/// wrapped schema, including its transformations and Strip-mode cleanup, then
/// runs every asynchronous refinement in declaration order.
pub(all) struct AsyncSchema {
  schema : @core.Schema
  checks : Array[AsyncCheck]
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
/// failures are collected into the returned `SchemaResult`.
pub fn AsyncSchema::refine_async(
  self : AsyncSchema,
  check : AsyncCheck,
) -> AsyncSchema {
  { ..self, checks: self.checks + [check], }
}

///|
/// Parse a JSON value and then run every asynchronous refinement.
///
/// A synchronous parse failure is returned unchanged and skips asynchronous
/// checks. Asynchronous failures use `IssueCode::Custom` and are appended in
/// refinement declaration order.
pub async fn AsyncSchema::parse_async(
  self : AsyncSchema,
  json : Json,
  root_path? : String = "",
) -> @core.SchemaResult {
  match self.schema.parse(json, path=root_path) {
    Err(errors) => Err(errors)
    Ok(clean) => {
      let errors : Array[@core.ValidationError] = []
      for check in self.checks {
        match check(clean) {
          None => ()
          Some(issue) =>
            errors.push({
              code: @core.IssueCode::Custom,
              path: join_async_path(root_path, issue.path),
              message: issue.message,
              got: issue.got,
            })
        }
      }
      if errors.is_empty() {
        Ok(clean)
      } else {
        Err(errors)
      }
    }
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
