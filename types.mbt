///|
/// Represents a single validation failure.
///
/// `path` is the field path (e.g. `"name"`, `"address.city"`).
/// `message` describes what went wrong.
/// `got` is the actual JSON value that failed validation.
pub struct ValidationError {
  path : String
  message : String
  got : Json
}

///|
/// Result type returned by `Schema::parse`.
/// `Ok(json)` on success, `Err(errors)` with all collected errors on failure.
pub type SchemaResult = Result[Json, Array[ValidationError]]
