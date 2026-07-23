///|
/// Apply a transformation function to the validated JSON value.
///
/// The schema is first validated normally. If validation succeeds, `f` is
/// called with the validated JSON. The transform can modify the value or
/// return an error.
///
/// Rules chained after `.transform()` are applied to the transformed value.
///
/// # Example
/// ```mbt nocheck
/// let s = string().transform(fn(json) {
///   match json {
///     String(s) => Ok(Json::string(s + "!"))
///     _ => Err("expected string")
///   }
/// })
/// ```
pub fn Schema::transform(
  self : Schema,
  f : (Json) -> Result[Json, String],
) -> Schema {
  {
    schema_type: TransformType(self, TransformClosure::{ f, is_builtin: false }),
    rules: [],
    description: self.description,
    required_error: self.required_error,
    invalid_type_error: self.invalid_type_error,
    name: self.name,
    brand: self.brand,
  }
}

///|
pub fn Schema::parse_transform(
  _self : Schema,
  inner : Schema,
  closure : TransformClosure,
  json : Json,
  path_stack : Array[String],
) -> RawSchemaResult {
  match parse_inner(inner, json, path_stack) {
    Err(e) => Err(e)
    Ok(validated) =>
      match (closure.f)(validated) {
        Ok(transformed) => {
          let raw : Array[RawIssue] = []
          collect_raw_errors(raw, path_stack, transformed, _self.rules)
          if raw.is_empty() {
            Ok(transformed)
          } else {
            Err(raw)
          }
        }
        Err(msg) => {
          let path = format_path(path_stack)
          Err([
            RawIssue::{
              code: IssueCode::Custom,
              path,
              message: msg,
              input: json,
            },
          ])
        }
      }
  }
}
