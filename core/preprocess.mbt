///|
/// Preprocess a JSON value before validating it with `inner`.
///
/// This is the inverse order of `.transform()`: `f` runs on raw input first,
/// then the returned JSON value is validated against `inner`.
pub fn preprocess(
  f : (Json) -> Result[Json, String],
  inner : Schema,
  required_error? : String = "",
  invalid_type_error? : String = "",
) -> Schema {
  {
    schema_type: PreprocessType(
      TransformClosure::{ f, is_builtin: false },
      inner,
    ),
    rules: [],
    description: inner.description,
    required_error,
    invalid_type_error,
    name: inner.name,
    brand: inner.brand,
  }
}

///|
pub fn Schema::parse_preprocess(
  self : Schema,
  closure : TransformClosure,
  inner : Schema,
  json : Json,
  path_stack : Array[String],
) -> RawSchemaResult {
  match (closure.f)(json) {
    Err(msg) => {
      let path = format_path(path_stack)
      Err([
        RawIssue::{ code: IssueCode::Custom, path, message: msg, input: json },
      ])
    }
    Ok(preprocessed) =>
      match parse_inner(inner, preprocessed, path_stack) {
        Err(e) => Err(e)
        Ok(parsed) => {
          let raw : Array[RawIssue] = []
          collect_raw_errors(raw, path_stack, parsed, self.rules)
          if raw.is_empty() {
            Ok(parsed)
          } else {
            Err(raw)
          }
        }
      }
  }
}
