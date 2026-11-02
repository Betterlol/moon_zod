///|
/// Merge projected output shapes using the same structural cases as runtime merge.
fn merge_output_shapes(
  items : Array[@core.Schema],
) -> Result[@core.Schema, String] {
  if items.is_empty() {
    return Ok(@core.unknown())
  }
  let mut result = items[0]
  for i = 1; i < items.length(); i = i + 1 {
    match merge_output_pair(result, items[i]) {
      Ok(merged) => result = merged
      Err(message) => return Err(message)
    }
  }
  Ok(result)
}

///|
fn merge_output_pair(
  left : @core.Schema,
  right : @core.Schema,
) -> Result[@core.Schema, String] {
  if @core.output_is_optional(left) || @core.output_is_optional(right) {
    return Err(
      "Intersection output with overlapping missing values requires an explicit output schema",
    )
  }
  let merged = match (left.schema_type, right.schema_type) {
    (ObjectType(a, mode_a), ObjectType(b, mode_b)) => {
      let fields = a.copy()
      for key, child in b {
        match fields.get(key) {
          None => fields.set(key, child)
          Some(previous) =>
            match merge_output_pair(previous, child) {
              Ok(child) => fields.set(key, child)
              Err(message) => return Err(message + " at field " + key)
            }
        }
      }
      let result = @core.object(fields)
      if mode_a is Strict || mode_b is Strict {
        result.strict()
      } else if mode_a is Passthrough || mode_b is Passthrough {
        result.passthrough()
      } else {
        result
      }
    }
    (ArrayType(a), ArrayType(b)) =>
      match merge_output_pair(a, b) {
        Ok(element) => @core.array(element)
        Err(message) => return Err(message)
      }
    (TupleType(a), TupleType(b)) => {
      if a.length() != b.length() {
        return Err(
          "Intersection tuple output with different lengths requires an explicit output schema",
        )
      }
      let items : Array[@core.Schema] = []
      for i = 0; i < a.length(); i = i + 1 {
        match merge_output_pair(a[i], b[i]) {
          Ok(child) => items.push(child)
          Err(message) => return Err(message)
        }
      }
      @core.tuple(items)
    }
    _ => {
      if output_scalar_only(left) && output_scalar_only(right) {
        return Ok(@core.intersection([left, right]))
      }
      return Err(
        "Intersection output involving conditional or mixed structural shapes requires an explicit output schema",
      )
    }
  }
  Ok({ ..merged, rules: left.rules + right.rules, })
}

///|
fn output_scalar_only(schema : @core.Schema) -> Bool {
  match schema.schema_type {
    StringType | NumberType | BooleanType | NullType | EnumType(_) => true
    LiteralType(value) => !(value is Object(_) || value is Array(_))
    UnionType(items) | IntersectionType(items) => items.all(output_scalar_only)
    NullableType(inner) => output_scalar_only(inner)
    _ => false
  }
}
