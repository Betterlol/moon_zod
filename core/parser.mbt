///|
/// A parsed value is retained even after continuable constraint failures.
/// Structural failures prevent callbacks from observing an invalid shape.
priv struct ParseOutput {
  value : Json
  missing : Bool
  issues : Array[RawIssue]
  aborted : Bool
}

///|
fn parsed(value : Json) -> ParseOutput {
  { value, missing: false, issues: [], aborted: false, }
}

///|
fn parse_failure(
  value : Json,
  code : IssueCode,
  message : String,
  path : Array[String],
  explicit_message~ : Bool = false,
) -> ParseOutput {
  {
    value,
    missing: false,
    issues: [
      {
        code,
        message,
        path: format_path(path),
        input: value,
        path_segments: stack_segments(path),
        explicit_message,
      },
    ],
    aborted: true,
  }
}

///|
fn copy_json(value : Json) -> Json {
  match value {
    Object(fields) => {
      let copied = Map([])
      for key, child in fields {
        copied.set(key, copy_json(child))
      }
      Json::object(copied)
    }
    Array(items) => Json::array(items.map(copy_json))
    _ => value
  }
}

///|
fn parse_output(
  schema : Schema,
  input : Json,
  path : Array[String],
) -> ParseOutput {
  let out = parse_node(schema, input, path)
  if !out.aborted {
    collect_raw_errors(out.issues, path, out.value, schema.rules)
  }
  out
}

///|
fn parse_node(
  schema : Schema,
  input : Json,
  path : Array[String],
) -> ParseOutput {
  match schema.schema_type {
    OptionalType(inner) | DefaultType(inner, _) | PrefaultType(inner, _) =>
      parse_output(inner, input, path)
    NullableType(inner) =>
      if input is Null {
        parsed(input)
      } else {
        parse_output(inner, input, path)
      }
    TransformType(inner, closure) => {
      let out = parse_output(inner, input, path)
      if !out.issues.is_empty() {
        return out
      }
      match (closure.f)(out.value) {
        Ok(value) => parsed(value)
        Err(message) =>
          parse_failure(input, Custom, message, path, explicit_message=true)
      }
    }
    PreprocessType(closure, inner) =>
      match (closure.f)(input) {
        Ok(value) => parse_output(inner, value, path)
        Err(message) =>
          parse_failure(input, Custom, message, path, explicit_message=true)
      }
    PipeType(inner, bridge, output) => {
      let out = parse_output(inner, input, path)
      if !out.issues.is_empty() {
        return out
      }
      match (bridge.f)(out.value) {
        Ok(value) => parse_output(output, value, path)
        Err(message) =>
          parse_failure(input, Custom, message, path, explicit_message=true)
      }
    }
    LazyType(resolve) => parse_output(resolve(), input, path)
    UnionType(branches) => {
      let messages : Array[String] = []
      let branch_issues : Array[Array[RawIssue]] = []
      let mut continuable : ParseOutput? = None
      for branch in branches {
        let out = parse_output(branch, copy_json(input), path)
        if out.issues.is_empty() {
          return out
        }
        if !out.aborted && continuable is None {
          continuable = Some(out)
        }
        if !out.issues.is_empty() {
          branch_issues.push(out.issues)
          messages.push(out.issues[0].message)
        }
      }
      match continuable {
        Some(out) => out
        None =>
          parse_failure(
            input,
            InvalidUnion(branch_issues),
            "Expected union type, but all branches failed. Branches: [" +
            messages.join(", ") +
            "]",
            path,
          )
      }
    }
    IntersectionType(branches) => {
      let issues : Array[RawIssue] = []
      let mut aborted = false
      let mut combined : Json? = None
      for branch in branches {
        let out = parse_output(branch, copy_json(input), path)
        issues.append(out.issues)
        aborted = aborted || out.aborted
        if !out.aborted {
          match combined {
            None => combined = Some(out.value)
            Some(previous) =>
              match merge_parsed(previous, out.value, path) {
                Ok(value) => combined = Some(value)
                Err(issue) => {
                  issues.push(issue)
                  aborted = true
                }
              }
          }
        }
      }
      { value: combined.unwrap_or(input), issues, aborted, missing: false, }
    }
    DiscriminatedUnionType(discriminator, options) => {
      guard input is Object(fields) else {
        return type_failure(schema, input, "object", path)
      }
      path.push(path_key(discriminator))
      let selected = match fields.get(discriminator) {
        Some(String(value)) =>
          match options.get(value) {
            Some(branch) => Ok(branch)
            None =>
              Err(
                parse_failure(
                  input,
                  InvalidValue(
                    options.keys().map(fn(k) { Json::string(k) }).collect(),
                  ),
                  "Invalid discriminator value",
                  path,
                ),
              )
          }
        Some(value) =>
          Err(
            parse_failure(
              value,
              InvalidType("string"),
              "Discriminator field must be a string",
              path,
            ),
          )
        None =>
          Err(
            parse_failure(
              Json::null(),
              MissingRequired(discriminator),
              "Required",
              path,
            ),
          )
      }
      let _ = path.pop()
      match selected {
        Ok(branch) => parse_output(branch, input, path)
        Err(out) => out
      }
    }
    ObjectType(spec, mode) => {
      guard input is Object(fields) else {
        return type_failure(schema, input, "object", path)
      }
      let output : Map[String, Json] = Map([])
      let issues : Array[RawIssue] = []
      let mut aborted = false
      for key, child in spec {
        path.push(path_key(key))
        let out = match fields.get(key) {
          Some(value) => parse_output(child, value, path)
          None => parse_absent(child, path)
        }
        if !out.missing {
          output.set(key, out.value)
        }
        issues.append(out.issues)
        aborted = aborted || out.aborted
        let _ = path.pop()
      }
      for key, value in fields {
        if !spec.contains(key) {
          match mode {
            Passthrough => output.set(key, copy_json(value))
            Strip => ()
            Strict => {
              path.push(path_key(key))
              issues.push({
                code: UnrecognizedKeys([key]),
                message: "Unexpected field",
                path: format_path(path),
                path_segments: stack_segments(path),
                explicit_message: false,
                input: value,
              })
              let _ = path.pop()
            }
          }
        }
      }
      { value: Json::object(output), issues, aborted, missing: false, }
    }
    ArrayType(child) => {
      guard input is Array(items) else {
        return type_failure(schema, input, "array", path)
      }
      let output : Array[Json] = []
      let issues : Array[RawIssue] = []
      let mut aborted = false
      for i = 0; i < items.length(); i = i + 1 {
        path.push("[\{i}]")
        let out = parse_output(child, items[i], path)
        let _ = path.pop()
        if !out.missing {
          while output.length() < i {
            output.push(Json::null())
          }
          output.push(out.value)
        }
        issues.append(out.issues)
        aborted = aborted || out.aborted
      }
      { value: Json::array(output), issues, aborted, missing: false, }
    }
    TupleType(children) => {
      guard input is Array(items) else {
        return type_failure(schema, input, "tuple", path)
      }
      if items.length() > children.length() ||
        (
          items.length() < children.length() &&
          !children[items.length():].to_owned().all(is_optional_schema)
        ) {
        let expected = children.length().to_double()
        return parse_failure(
          input,
          if items.length() < children.length() {
            TooSmall("tuple", expected, true)
          } else {
            TooBig("tuple", expected, true)
          },
          "Expected tuple of length \{children.length()}",
          path,
        )
      }
      let output : Array[Json] = []
      let issues : Array[RawIssue] = []
      let mut aborted = false
      for i = 0; i < children.length(); i = i + 1 {
        path.push("[\{i}]")
        let out = if i < items.length() {
          parse_output(children[i], items[i], path)
        } else {
          parse_absent(children[i], path)
        }
        let _ = path.pop()
        if !out.missing {
          while output.length() < i {
            output.push(Json::null())
          }
          output.push(out.value)
        }
        issues.append(out.issues)
        aborted = aborted || out.aborted
      }
      { value: Json::array(output), issues, aborted, missing: false, }
    }
    EnumType(values) => {
      guard input is String(value) else {
        return parse_failure(
          input,
          InvalidType("string"),
          if schema.invalid_type_error.is_empty() {
            "Expected string for enum"
          } else {
            schema.invalid_type_error
          },
          path,
          explicit_message=!schema.invalid_type_error.is_empty(),
        )
      }
      if value_in_array(value, values) {
        parsed(input)
      } else {
        parse_failure(
          input,
          InvalidValue(values.map(fn(v) { Json::string(v) })),
          "Invalid enum value",
          path,
          explicit_message=!schema.invalid_type_error.is_empty(),
        )
      }
    }
    LiteralType(value) =>
      if input == value {
        parsed(input)
      } else {
        parse_failure(
          input,
          InvalidValue([value]),
          if schema.invalid_type_error.is_empty() {
            "Expected literal value \{json_to_literal_string(value)}, got different value"
          } else {
            schema.invalid_type_error
          },
          path,
          explicit_message=!schema.invalid_type_error.is_empty(),
        )
      }
    _ => {
      let valid = match (schema.schema_type, input) {
        (StringType, String(_))
        | (BooleanType, True | False)
        | (NullType, Null) => true
        (NumberType, Number(value, ..)) => !value.is_nan() && !value.is_inf()
        (AnyType | UnknownType, _) => true
        _ => false
      }
      if valid {
        parsed(input)
      } else {
        type_failure(schema, input, type_origin(schema.schema_type), path)
      }
    }
  }
}

///|
fn merge_parsed(
  a : Json,
  b : Json,
  path : Array[String],
) -> Result[Json, RawIssue] {
  if a == b {
    return Ok(copy_json(a))
  }
  match (a, b) {
    (Object(left), Object(right)) => {
      let output : Map[String, Json] = Map([])
      for key, value in left {
        output.set(key, copy_json(value))
      }
      for key, value in right {
        match left.get(key) {
          None => output.set(key, copy_json(value))
          Some(previous) => {
            path.push(path_key(key))
            let merged = merge_parsed(previous, value, path)
            let _ = path.pop()
            match merged {
              Ok(value) => output.set(key, value)
              Err(issue) => return Err(issue)
            }
          }
        }
      }
      Ok(Json::object(output))
    }
    (Array(left), Array(right)) => {
      if left.length() != right.length() {
        return Err(merge_conflict(a, path))
      }
      let output : Array[Json] = []
      for i = 0; i < left.length(); i = i + 1 {
        path.push("[\{i}]")
        let merged = merge_parsed(left[i], right[i], path)
        let _ = path.pop()
        match merged {
          Ok(value) => output.push(value)
          Err(issue) => return Err(issue)
        }
      }
      Ok(Json::array(output))
    }
    _ => Err(merge_conflict(a, path))
  }
}

///|
fn merge_conflict(value : Json, path : Array[String]) -> RawIssue {
  {
    code: Custom,
    path: format_path(path),
    path_segments: stack_segments(path),
    explicit_message: false,
    message: "Intersection outputs cannot be merged",
    input: value,
  }
}

///|
fn parse_absent(schema : Schema, path : Array[String]) -> ParseOutput {
  let out = match schema.schema_type {
    DefaultType(_, value) => parsed(copy_json(value))
    PrefaultType(inner, value) => parse_output(inner, copy_json(value), path)
    OptionalType(inner) =>
      if has_missing_default(inner) {
        parse_absent(inner, path)
      } else {
        { value: Json::null(), missing: true, issues: [], aborted: false, }
      }
    NullableType(inner) | PreprocessType(_, inner) => parse_absent(inner, path)
    TransformType(inner, closure) => {
      let first = parse_absent(inner, path)
      if !first.issues.is_empty() || first.missing {
        first
      } else {
        match (closure.f)(first.value) {
          Ok(value) => parsed(value)
          Err(message) =>
            parse_failure(
              first.value,
              Custom,
              message,
              path,
              explicit_message=true,
            )
        }
      }
    }
    PipeType(input, _, output) => {
      let first = parse_absent(input, path)
      if !first.issues.is_empty() {
        first
      } else if first.missing {
        parse_absent(output, path)
      } else {
        parse_output(output, first.value, path)
      }
    }
    LazyType(resolve) => parse_absent(resolve(), path)
    UnionType(branches) => {
      let mut answer = parse_failure(
        Json::null(),
        MissingRequired(last_field_name(path)),
        "Required",
        path,
      )
      for branch in branches {
        let candidate = parse_absent(branch, path)
        if candidate.issues.is_empty() {
          answer = candidate
          break
        }
      }
      answer
    }
    IntersectionType(branches) => {
      let issues : Array[RawIssue] = []
      let mut combined : Json? = None
      let mut missing = true
      let mut aborted = false
      for branch in branches {
        let candidate = parse_absent(branch, path)
        issues.append(candidate.issues)
        aborted = aborted || candidate.aborted
        if !candidate.missing && !candidate.aborted {
          missing = false
          match combined {
            None => combined = Some(candidate.value)
            Some(previous) =>
              match merge_parsed(previous, candidate.value, path) {
                Ok(value) => combined = Some(value)
                Err(issue) => {
                  issues.push(issue)
                  aborted = true
                }
              }
          }
        }
      }
      { value: combined.unwrap_or(Json::null()), missing, issues, aborted, }
    }
    _ =>
      parse_failure(
        Json::null(),
        MissingRequired(last_field_name(path)),
        if schema.required_error.is_empty() {
          "Required"
        } else {
          schema.required_error
        },
        path,
        explicit_message=!schema.required_error.is_empty(),
      )
  }
  if !out.aborted {
    collect_raw_errors(out.issues, path, out.value, schema.rules)
  }
  out
}

///|
fn has_missing_default(schema : Schema) -> Bool {
  match schema.schema_type {
    DefaultType(_, _) | PrefaultType(_, _) => true
    OptionalType(inner)
    | NullableType(inner)
    | TransformType(inner, _)
    | PreprocessType(_, inner) => has_missing_default(inner)
    PipeType(input, _, _) => has_missing_default(input)
    _ => false
  }
}

///|
fn type_failure(
  schema : Schema,
  input : Json,
  expected : String,
  path : Array[String],
) -> ParseOutput {
  parse_failure(
    input,
    InvalidType(expected),
    type_msg(schema),
    path,
    explicit_message=!schema.invalid_type_error.is_empty(),
  )
}
