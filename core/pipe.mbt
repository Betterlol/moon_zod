///|
/// Chain two schemas: validate the input against `self`, then validate the
/// result against `output`. Errors from each stage are reported independently.
///
/// Unlike `.transform()`, `.pipe()` creates a clear two-stage pipeline where
/// the output schema can have its own rules — errors are attributed to the
/// correct stage.
///
/// # Example
/// ```mbt nocheck
/// let s = string()
///   .transform(fn(s) { Ok(Json::string(s.length().to_string())) })
///   .pipe(number().min(5))
/// // string check → transform → number check(.min(5))
/// ```
pub fn Schema::pipe(self : Schema, output : Schema) -> Schema {
  {
    schema_type: PipeType(
      self,
      TransformClosure::{ f: fn(v) { Ok(v) }, is_builtin: true, },
      output,
    ),
    rules: [],
    description: self.description,
    required_error: self.required_error,
    invalid_type_error: self.invalid_type_error,
    name: self.name,
    brand: self.brand,
  }
}

///|
pub fn Schema::parse_pipe(
  self : Schema,
  input_schema : Schema,
  bridge : TransformClosure,
  output_schema : Schema,
  json : Json,
  path_stack : Array[String],
) -> RawSchemaResult {
  parse_inner(
    { ..self, schema_type: PipeType(input_schema, bridge, output_schema), },
    json,
    path_stack,
  )
}
