///|
/// Create a schema that requires all given schemas to match (intersection / and).
/// For objects, fields from all schemas are merged into one.
pub fn intersection(
  schemas : Array[Schema],
  required_error? : String = "",
  invalid_type_error? : String = "",
) -> Schema {
  {
    schema_type: IntersectionType(schemas),
    rules: [],
    description: "",
    required_error,
    invalid_type_error,
    name: "",
  }
}

///|
/// Combine two schemas with intersection (both must match).
/// Equivalent to `intersection([self, other])`.
pub fn Schema::intersect(self : Schema, other : Schema) -> Schema {
  intersection([self, other])
}

///|
pub fn Schema::parse_intersection(
  _self : Schema,
  schemas : Array[Schema],
  json : Json,
  path_stack : Array[String],
) -> SchemaResult {
  fn merge_json(a : Json, b : Json) -> Json {
    match (a, b) {
      (Object(map_a), Object(map_b)) => {
        for k, v in map_b {
          map_a.set(k, v)
        }
        Json::object(map_a)
      }
      _ => a
    }
  }
  let errors : Array[ValidationError] = []
  let mut merged = json
  for s in schemas {
    match parse_inner(s, json, path_stack) {
      Ok(result) => merged = merge_json(merged, result)
      Err(errs) =>
        for e in errs {
          errors.push(e)
        }
    }
  }
  if errors.is_empty() {
    Ok(merged)
  } else {
    Err(errors)
  }
}
