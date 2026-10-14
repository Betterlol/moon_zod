///|
/// A parsed value is retained even after continuable constraint failures.
/// Structural failures prevent callbacks from observing an invalid shape.
priv struct ParseOutput {
  value : Json
  issues : Array[RawIssue]
  aborted : Bool
}

///|
fn parsed(value : Json) -> ParseOutput {
  { value, issues: [], aborted: false, }
}

///|
fn parse_failure(
  value : Json,
  code : IssueCode,
  message : String,
  path : Array[String],
) -> ParseOutput {
  {
    value,
    issues: [{ code, message, path: format_path(path), input: value, }],
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
    OptionalType(inner) =>
      if input is Null {
        parsed(input)
      } else {
        parse_output(inner, input, path)
      }
    DefaultType(inner, value) =>
      if input is Null {
        parsed(copy_json(value))
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
        Err(message) => parse_failure(input, Custom, message, path)
      }
    }
    PreprocessType(closure, inner) =>
      match (closure.f)(input) {
        Ok(value) => parse_output(inner, value, path)
        Err(message) => parse_failure(input, Custom, message, path)
      }
    PipeType(inner, bridge, output) => {
      let out = parse_output(inner, input, path)
      if !out.issues.is_empty() {
        return out
      }
      match (bridge.f)(out.value) {
        Ok(value) => parse_output(output, value, path)
        Err(message) => parse_failure(input, Custom, message, path)
      }
    }
    LazyType(resolve) => parse_output(resolve(), input, path)
    UnionType(branches) => {
      let messages : Array[String] = []
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
          messages.push(out.issues[0].message)
        }
      }
      match continuable {
        Some(out) => out
        None =>
          parse_failure(
            input,
            InvalidUnion(messages),
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
      { value: combined.unwrap_or(input), issues, aborted, }
    }
    DiscriminatedUnionType(discriminator, options) => {
      guard input is Object(fields) else {
        return parse_failure(
          input,
          InvalidType("object"),
          type_msg(schema),
          path,
        )
      }
      path.push(discriminator)
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
        return parse_failure(
          input,
          InvalidType("object"),
          type_msg(schema),
          path,
        )
      }
      let output : Map[String, Json] = Map([])
      let issues : Array[RawIssue] = []
      let mut aborted = false
      for key, child in spec {
        path.push(key)
        match fields.get(key) {
          Some(value) => {
            let out = parse_output(child, value, path)
            output.set(key, out.value)
            issues.append(out.issues)
            aborted = aborted || out.aborted
          }
          None =>
            if !is_optional_schema(child) {
              issues.push({
                code: MissingRequired(key),
                message: if child.required_error.is_empty() {
                  "Required"
                } else {
                  child.required_error
                },
                path: format_path(path),
                input: Json::null(),
              })
              aborted = true
            }
        }
        let _ = path.pop()
      }
      for key, value in fields {
        if !spec.contains(key) {
          match mode {
            Passthrough => output.set(key, copy_json(value))
            Strip => ()
            Strict => {
              path.push(key)
              issues.push({
                code: UnrecognizedKeys([key]),
                message: "Unexpected field",
                path: format_path(path),
                input: value,
              })
              let _ = path.pop()
            }
          }
        }
      }
      { value: Json::object(output), issues, aborted, }
    }
    ArrayType(child) => {
      guard input is Array(items) else {
        return parse_failure(
          input,
          InvalidType("array"),
          type_msg(schema),
          path,
        )
      }
      let output : Array[Json] = []
      let issues : Array[RawIssue] = []
      let mut aborted = false
      for i = 0; i < items.length(); i = i + 1 {
        path.push("[\{i}]")
        let out = parse_output(child, items[i], path)
        let _ = path.pop()
        output.push(out.value)
        issues.append(out.issues)
        aborted = aborted || out.aborted
      }
      { value: Json::array(output), issues, aborted, }
    }
    TupleType(children) => {
      guard input is Array(items) else {
        return parse_failure(
          input,
          InvalidType("tuple"),
          type_msg(schema),
          path,
        )
      }
      if items.length() != children.length() {
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
      for i = 0; i < items.length(); i = i + 1 {
        path.push("[\{i}]")
        let out = parse_output(children[i], items[i], path)
        let _ = path.pop()
        output.push(out.value)
        issues.append(out.issues)
        aborted = aborted || out.aborted
      }
      { value: Json::array(output), issues, aborted, }
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
        )
      }
    _ => {
      let valid = match (schema.schema_type, input) {
        (StringType, String(_))
        | (NumberType, Number(_))
        | (BooleanType, True | False)
        | (NullType, Null) => true
        (AnyType | UnknownType, _) => true
        _ => false
      }
      if valid {
        parsed(input)
      } else {
        parse_failure(
          input,
          InvalidType(type_origin(schema.schema_type)),
          type_msg(schema),
          path,
        )
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
            path.push(key)
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
    message: "Intersection outputs cannot be merged",
    input: value,
  }
}
