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
fn blocks_effect(issues : Array[RawIssue]) -> Bool {
  issues.any(fn(issue) { !(issue.code is UnrecognizedKeys(_)) })
}

///|
fn inherit_issues(out : ParseOutput, previous : Array[RawIssue]) -> ParseOutput {
  { ..out, issues: previous + out.issues, }
}

///|
fn rejected_keys(
  issues : Array[RawIssue],
  path : Array[String],
) -> Map[String, Bool] {
  let keys : Map[String, Bool] = Map([])
  for issue in issues {
    if issue.code is UnrecognizedKeys(rejected) {
      for key in rejected {
        if issue.path == sub_path(format_path(path), key) {
          keys.set(key, true)
        }
      }
    }
  }
  keys
}

///|
fn reconcile_key_issues(
  left : Array[RawIssue],
  right : Array[RawIssue],
  path : Array[String],
) -> Array[RawIssue] {
  let left_keys = rejected_keys(left, path)
  let right_keys = rejected_keys(right, path)
  let retained : Array[RawIssue] = []
  for side in [left, right] {
    for issue in side {
      let root_key = match issue.code {
        UnrecognizedKeys(keys) =>
          keys.length() == 1 &&
          issue.path == sub_path(format_path(path), keys[0])
        _ => false
      }
      if !root_key {
        retained.push(issue)
      }
    }
  }
  for issue in left {
    if issue.code is UnrecognizedKeys(keys) &&
      keys.length() == 1 &&
      issue.path == sub_path(format_path(path), keys[0]) &&
      left_keys.contains(keys[0]) &&
      right_keys.contains(keys[0]) {
      retained.push(issue)
    }
  }
  retained
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
    let aborted = collect_node_errors(out.issues, path, out.value, schema.rules)
    return { ..out, aborted, }
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
      if out.aborted ||
        (closure.kind is CustomTransform && blocks_effect(out.issues)) {
        return { ..out, aborted: true, }
      }
      match (closure.f)(out.value) {
        Ok(value) => { ..parsed(value), issues: out.issues, }
        Err(message) =>
          inherit_issues(
            parse_failure(input, Custom, message, path, explicit_message=true),
            out.issues,
          )
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
      if out.aborted || blocks_effect(out.issues) {
        return { ..out, aborted: true, }
      }
      match (bridge.f)(out.value) {
        Ok(value) =>
          inherit_issues(parse_output(output, value, path), out.issues)
        Err(message) =>
          inherit_issues(
            parse_failure(input, Custom, message, path, explicit_message=true),
            out.issues,
          )
      }
    }
    LazyType(resolve) => parse_output(resolve(), input, path)
    UnionType(branches) => parse_union_nodes(branches, Some(input), path)
    IntersectionType(branches) => {
      let issues : Array[RawIssue] = []
      let mut aborted = false
      let mut combined : Json? = None
      for branch_index, branch in branches {
        let out = parse_output(branch, copy_json(input), path)
        let reconciled = if branch_index == 0 {
          out.issues
        } else {
          reconcile_key_issues(issues, out.issues, path)
        }
        issues.clear()
        issues.append(reconciled)
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
          None => {
            let candidate = parse_absent(child, path)
            if candidate.issues.is_empty() && !is_optional_schema(child) {
              parse_failure(
                Json::null(),
                MissingRequired(key),
                if child.required_error.is_empty() {
                  "Required"
                } else {
                  child.required_error
                },
                path,
                explicit_message=!child.required_error.is_empty(),
              )
            } else {
              candidate
            }
          }
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
        output.push(out.value)
        issues.append(out.issues)
        aborted = aborted || out.aborted
      }
      { value: Json::array(output), issues, aborted, missing: false, }
    }
    TupleType(children) => {
      guard input is Array(items) else {
        return type_failure(schema, input, "tuple", path)
      }
      let mut minimum = children.length()
      while minimum > 0 && is_optional_schema(children[minimum - 1]) {
        minimum = minimum - 1
      }
      if items.length() < minimum {
        return parse_failure(
          input,
          TooSmall("tuple", minimum.to_double(), true),
          "Expected tuple of length \{minimum}",
          path,
        )
      }
      let output : Array[Json] = []
      let issues : Array[RawIssue] = []
      let mut aborted = items.length() > children.length()
      if items.length() > children.length() {
        issues.append(
          parse_failure(
            input,
            TooBig("tuple", children.length().to_double(), true),
            "Expected tuple of length \{children.length()}",
            path,
          ).issues,
        )
      }
      for i = 0; i < children.length(); i = i + 1 {
        path.push("[\{i}]")
        let out = if i < items.length() {
          parse_output(children[i], items[i], path)
        } else {
          parse_absent(children[i], path)
        }
        let _ = path.pop()
        if !out.missing {
          if output.length() < i {
            if !aborted {
              path.push("[\{output.length()}]")
              let failure = parse_failure(
                Json::null(),
                Custom,
                "Tuple output cannot represent a missing position before a present value",
                path,
              )
              issues.append(failure.issues)
              let _ = path.pop()
            }
            aborted = true
          } else {
            output.push(out.value)
          }
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
          if schema.invalid_type_error.is_empty() {
            "Invalid enum value"
          } else {
            schema.invalid_type_error
          },
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
        let candidate = parse_absent(inner, path)
        if candidate.issues.is_empty() {
          candidate
        } else {
          { value: Json::null(), missing: true, issues: [], aborted: false, }
        }
      } else {
        { value: Json::null(), missing: true, issues: [], aborted: false, }
      }
    NullableType(inner) | PreprocessType(_, inner) => parse_absent(inner, path)
    TransformType(inner, closure) => {
      let first = parse_absent(inner, path)
      if first.aborted ||
        (closure.kind is CustomTransform && blocks_effect(first.issues)) {
        { ..first, aborted: true, }
      } else if first.missing {
        first
      } else {
        match (closure.f)(first.value) {
          Ok(value) => { ..parsed(value), issues: first.issues, }
          Err(message) =>
            inherit_issues(
              parse_failure(
                first.value,
                Custom,
                message,
                path,
                explicit_message=true,
              ),
              first.issues,
            )
        }
      }
    }
    PipeType(input, bridge, output) => {
      let first = parse_absent(input, path)
      if first.aborted || blocks_effect(first.issues) {
        { ..first, aborted: true, }
      } else if first.missing {
        parse_absent(output, path)
      } else {
        match (bridge.f)(first.value) {
          Ok(value) =>
            inherit_issues(parse_output(output, value, path), first.issues)
          Err(message) =>
            inherit_issues(
              parse_failure(
                first.value,
                Custom,
                message,
                path,
                explicit_message=true,
              ),
              first.issues,
            )
        }
      }
    }
    LazyType(resolve) => parse_absent(resolve(), path)
    UnionType(branches) => parse_union_nodes(branches, None, path)
    IntersectionType(branches) => {
      let issues : Array[RawIssue] = []
      let mut combined : Json? = None
      let mut first_missing : Bool? = None
      let mut missing = true
      let mut aborted = false
      for branch_index, branch in branches {
        let candidate = parse_absent(branch, path)
        let reconciled = if branch_index == 0 {
          candidate.issues
        } else {
          reconcile_key_issues(issues, candidate.issues, path)
        }
        issues.clear()
        issues.append(reconciled)
        aborted = aborted || candidate.aborted
        if !candidate.aborted {
          match first_missing {
            None => first_missing = Some(candidate.missing)
            Some(previous) =>
              if previous != candidate.missing {
                issues.push(merge_conflict(candidate.value, path))
                aborted = true
              }
          }
        }
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
  if !schema.required_error.is_empty() {
    let current_path = format_path(path)
    for index, issue in out.issues {
      let missing_issue = match issue.code {
        MissingRequired(_) => true
        InvalidUnion(branches) =>
          branches.all(fn(issues) {
            issues.all(fn(issue) { issue.code is MissingRequired(_) })
          })
        _ => false
      }
      if missing_issue && issue.path == current_path {
        out.issues[index] = {
          ..issue,
          message: schema.required_error,
          explicit_message: true,
        }
      }
    }
  }
  if !out.aborted && !out.missing {
    let aborted = collect_node_errors(out.issues, path, out.value, schema.rules)
    return { ..out, aborted, }
  }
  out
}

///|
fn has_missing_default(schema : Schema) -> Bool {
  missing_default_impl(schema, Map([]), 0)
}

///|
fn missing_default_impl(
  schema : Schema,
  visited : Map[Int32, Bool],
  depth : Int32,
) -> Bool {
  if depth > 256 || visited.contains(schema.id) {
    return false
  }
  visited.set(schema.id, true)
  match schema.schema_type {
    DefaultType(_, _) | PrefaultType(_, _) => true
    OptionalType(inner) | NullableType(inner) | TransformType(inner, _) =>
      missing_default_impl(inner, visited, depth + 1)
    LazyType(resolve) => missing_default_impl(resolve(), visited, depth + 1)
    PipeType(input, _, _) => missing_default_impl(input, visited, depth + 1)
    UnionType(branches) =>
      branches.any(fn(child) {
        missing_default_impl(child, visited.copy(), depth + 1)
      })
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

///|
fn parse_union_nodes(
  branches : Array[Schema],
  input : Json?,
  path : Array[String],
) -> ParseOutput {
  let messages : Array[String] = []
  let branch_issues : Array[Array[RawIssue]] = []
  let mut continuable : ParseOutput? = None
  let mut continuable_count = 0
  for branch in branches {
    let out = match input {
      Some(value) => parse_output(branch, copy_json(value), path)
      None => parse_absent(branch, path)
    }
    if out.issues.is_empty() {
      return out
    }
    if !out.aborted {
      continuable_count = continuable_count + 1
      continuable = Some(out)
    }
    branch_issues.push(out.issues)
    messages.push(out.issues[0].message)
  }
  if continuable_count == 1 {
    match continuable {
      Some(out) => return out
      None => ()
    }
  }
  parse_failure(
    input.unwrap_or(Json::null()),
    InvalidUnion(branch_issues),
    "Expected union type, but all branches failed. Branches: [" +
    messages.join(", ") +
    "]",
    path,
  )
}
