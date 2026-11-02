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
  path~ : String = "",
  got~ : Json = Json::null(),
) -> AsyncIssue {
  { path, message, got, }
}
