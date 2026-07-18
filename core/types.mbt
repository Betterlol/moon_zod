///|
/// Represents a single validation failure.
///
/// `code` is the structured issue code for machine-readable error classification.
/// `path` is the field path (e.g. `"name"`, `"address.city"`).
/// `message` describes what went wrong.
/// `got` is the actual JSON value that failed validation.
pub(all) struct ValidationError {
  code : IssueCode
  path : String
  message : String
  got : Json
} derive(Debug)

///|
/// Format a validation error as a human-readable string.
/// Uses Debug for the received value to avoid Show deprecation.
pub fn ValidationError::to_string(self : ValidationError) -> String {
  "[" +
  self.path +
  "] " +
  self.message +
  " (code: " +
  @debug.to_string(self.code) +
  ", got: " +
  @debug.to_string(self.got) +
  ")"
}

///|
/// Result type returned by `Schema::parse`.
/// `Ok(json)` on success, `Err(errors)` with all collected errors on failure.
pub type SchemaResult = Result[Json, Array[ValidationError]]

///|
/// Internal result type used during parsing before error message finalization.
pub type RawSchemaResult = Result[Json, Array[RawIssue]]
