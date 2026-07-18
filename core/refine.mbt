///|
/// Add a custom validation rule.
///
/// `check` is a predicate on the JSON value; `message` is the error message
/// shown when the predicate returns `false`.
pub fn Schema::refine(
  self : Schema,
  check : (Json) -> Bool,
  message : String,
) -> Schema {
  append_rule(self, check, message, IssueCode::Custom)
}
