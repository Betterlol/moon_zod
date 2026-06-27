///|
/// Create a schema that accepts any of the given schemas (union / or).
/// Schemas are tried in order; the first match succeeds.
pub fn union(
  schemas : Array[Schema],
  required_error? : String = "",
  invalid_type_error? : String = "",
) -> Schema {
  {
    schema_type: UnionType(schemas),
    rules: [],
    description: "",
    required_error,
    invalid_type_error,
    name: "",
  }
}

///|
pub fn Schema::parse_union(
  _self : Schema,
  schemas : Array[Schema],
  json : Json,
  path_stack : Array[String],
) -> SchemaResult {
  let all_branch_errors : Array[String] = []
  for s in schemas {
    match parse_inner(s, json, path_stack) {
      Ok(v) => return Ok(v)
      Err(errors) =>
        if errors.length() > 0 {
          all_branch_errors.push(errors[0].message)
        }
    }
  }
  let path = format_path(path_stack)
  let branches = all_branch_errors.join(", ")
  let message = "Expected union type, but all branches failed. Branches: [" +
    branches +
    "]"
  Err([ValidationError::{ path, message, got: json }])
}
