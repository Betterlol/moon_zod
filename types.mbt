///|
/// Represents a single validation failure.
///
/// `path` is the field path (e.g. `"name"`, `"address.city"`).
/// `message` describes what went wrong.
/// `got` is the actual JSON value that failed validation.
pub(all) struct ValidationError {
  path : String
  message : String
  got : Json
}

///|
/// Format a validation error as a human-readable string.
/// Uses Debug for the received value to avoid Show deprecation.
pub fn ValidationError::to_string(self : ValidationError) -> String {
  "[" +
  self.path +
  "] " +
  self.message +
  " (got: " +
  @debug.to_string(self.got) +
  ")"
}

///|
/// Result type returned by `Schema::parse`.
/// `Ok(json)` on success, `Err(errors)` with all collected errors on failure.
pub type SchemaResult = Result[Json, Array[ValidationError]]
