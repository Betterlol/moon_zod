///|
/// Preprocess a JSON value before validating it with `inner`.
///
/// This is the inverse order of `.transform()`: `f` runs on raw input first,
/// then the returned JSON value is validated against `inner`.
pub fn preprocess(
  f : (Json) -> Result[Json, String],
  inner : Schema,
  required_error~ : String = "",
  invalid_type_error~ : String = "",
) -> Schema {
  let inner = if invalid_type_error.is_empty() {
    inner
  } else {
    inner.invalid_type_error(invalid_type_error)
  }
  {
    id: new_schema_id(),
    schema_type: PreprocessType(
      TransformClosure::{ f, kind: CustomTransform, },
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
  parse_inner(
    {
      ..self,
      id: new_schema_id(),
      schema_type: PreprocessType(closure, inner),
    },
    json,
    path_stack,
  )
}
