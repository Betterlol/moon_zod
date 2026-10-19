///|
fn append_typed_rule(schema : Schema, rule : Rule) -> Schema {
  let schema_type = match schema.schema_type {
    OptionalType(inner) => OptionalType(append_typed_rule(inner, rule))
    NullableType(inner) => NullableType(append_typed_rule(inner, rule))
    DefaultType(inner, value) =>
      DefaultType(append_typed_rule(inner, rule), value)
    PrefaultType(inner, value) =>
      PrefaultType(append_typed_rule(inner, rule), value)
    PipeType(input, bridge, output) =>
      PipeType(input, bridge, append_typed_rule(output, rule))
    _ => return { ..schema, id: new_schema_id(), rules: schema.rules + [rule], }
  }
  { ..schema, id: new_schema_id(), schema_type, }
}

///|
fn append_builtin_rule(
  schema : Schema,
  check : (Json) -> Bool,
  message : String,
  code : IssueCode,
  annotation : Json,
  explicit_message~ : Bool = false,
  constraint~ : Constraint? = None,
) -> Schema {
  append_typed_rule(schema, {
    check,
    message,
    code,
    annotation,
    explicit_message,
    constraint: constraint.unwrap_or(builtin_constraint(code, annotation)),
  })
}

///|
fn builtin_constraint(code : IssueCode, annotation : Json) -> Constraint {
  match code {
    TooSmall(origin, value, inclusive) =>
      return Minimum(origin, value, inclusive)
    TooBig(origin, value, inclusive) => return Maximum(origin, value, inclusive)
    NotMultipleOf(value) => return Multiple(value)
    InvalidFormat("integer") => return Integer
    _ => ()
  }
  if annotation is Object(fields) {
    if fields.get("type") is Some(String("integer")) {
      return Integer
    }
    for
      pair in [
        ("minLength", "maxLength", "string"),
        ("minItems", "maxItems", "array"),
      ] {
      let (minimum, maximum, origin) = pair
      match (fields.get(minimum), fields.get(maximum)) {
        (Some(Number(a, ..)), Some(Number(b, ..))) =>
          if a == b {
            return ExactLength(origin, a.to_int())
          }
        _ => ()
      }
    }
    if fields.get("pattern") is Some(String(pattern)) {
      return Pattern(pattern)
    }
    if fields.get("format") is Some(String(format)) {
      return Format(format)
    }
  }
  Opaque
}

///|
/// All rules in their execution order, including checks on built-in effects.
/// These describe execution stages; custom output types require an explicit pipe.
pub fn effective_rules(schema : Schema) -> Array[Rule] {
  let inherited = match schema.schema_type {
    OptionalType(inner)
    | NullableType(inner)
    | DefaultType(inner, _)
    | PrefaultType(inner, _)
    | PreprocessType(_, inner) => effective_rules(inner)
    TransformType(inner, _) => effective_rules(inner)
    PipeType(_, _, output) => effective_rules(output)
    _ => []
  }
  inherited + schema.rules
}

///|
fn escape_regex_literal(value : String) -> String {
  let result = StringBuilder()
  for c in value.to_array() {
    if c == '.' ||
      c == '*' ||
      c == '+' ||
      c == '?' ||
      c == '^' ||
      c == '$' ||
      c == '{' ||
      c == '}' ||
      c == '(' ||
      c == ')' ||
      c == '[' ||
      c == ']' ||
      c == '\\' ||
      c == '|' {
      result.write_char('\\')
    }
    result.write_char(c)
  }
  result.to_string()
}
