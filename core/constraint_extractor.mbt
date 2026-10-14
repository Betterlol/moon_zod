///|
/// Constraint metadata uses optional bounds, preserving negative values.
pub(all) struct ConstraintInfo {
  min_value : Double?
  max_value : Double?
  min_inclusive : Bool
  max_inclusive : Bool
  format : String
  pattern : String
  patterns : Array[String]
  formats : Array[String]
  is_int : Bool
  is_positive : Bool
  is_negative : Bool
  multiple_of : Double
  multiples : Array[Double]
  custom_messages : Array[String]
}

///|
/// Empty constraints use None instead of a numeric sentinel.
pub fn constraint_info_default() -> ConstraintInfo {
  {
    min_value: None,
    max_value: None,
    min_inclusive: true,
    max_inclusive: true,
    format: "",
    pattern: "",
    patterns: [],
    formats: [],
    is_int: false,
    is_positive: false,
    is_negative: false,
    multiple_of: 0.0,
    multiples: [],
    custom_messages: [],
  }
}

///|
/// Extract built-in constraints and explicit annotation extensions.
pub fn extract_constraints(rules : Array[Rule]) -> ConstraintInfo {
  let mut info = constraint_info_default()
  for rule in rules {
    match rule.constraint {
      Minimum(_, value, inclusive) =>
        info = fold_minimum(info, value, inclusive)
      Maximum(_, value, inclusive) =>
        info = fold_maximum(info, value, inclusive)
      ExactLength(_, value) => {
        info = fold_minimum(info, value.to_double(), true)
        info = fold_maximum(info, value.to_double(), true)
      }
      Multiple(value) => {
        info.multiples.push(value)
        info = { ..info, multiple_of: value, }
      }
      Integer | SafeInteger => info = { ..info, is_int: true, }
      Format(value) => {
        info.formats.push(value)
        info = { ..info, format: value, }
      }
      Finite | Prefix(_) | Suffix(_) | Contains(_) => ()
      Pattern(value) => {
        info.patterns.push(value)
        info = { ..info, pattern: value, }
      }
      Opaque =>
        if rule.annotation is Null {
          info.custom_messages.push(rule.message)
        }
    }
    if rule.annotation is Object(fields) {
      for key, value in fields {
        match (key, value) {
          ("minLength" | "minItems" | "minimum", Number(v, ..)) =>
            info = fold_minimum(info, v, true)
          ("maxLength" | "maxItems" | "maximum", Number(v, ..)) =>
            info = fold_maximum(info, v, true)
          ("exclusiveMinimum", Number(v, ..)) =>
            info = fold_minimum(info, v, false)
          ("exclusiveMaximum", Number(v, ..)) =>
            info = fold_maximum(info, v, false)
          ("type", String("integer")) => info = { ..info, is_int: true, }
          ("format", String(v)) =>
            if !info.formats.contains(v) {
              info.formats.push(v)
              info = { ..info, format: v, }
            }
          ("pattern", String(v)) =>
            if !info.patterns.contains(v) {
              info.patterns.push(v)
              info = { ..info, pattern: v, }
            }
          ("multipleOf", Number(v, ..)) =>
            if !info.multiples.contains(v) {
              info.multiples.push(v)
              info = { ..info, multiple_of: v, }
            }
          _ => ()
        }
      }
    }
  }
  {
    ..info,
    is_positive: info.min_value is Some(0.0) && !info.min_inclusive,
    is_negative: info.max_value is Some(0.0) && !info.max_inclusive,
  }
}

///|
fn fold_minimum(
  info : ConstraintInfo,
  value : Double,
  inclusive : Bool,
) -> ConstraintInfo {
  match info.min_value {
    Some(previous) =>
      if value < previous {
        return info
      } else if value == previous {
        return { ..info, min_inclusive: info.min_inclusive && inclusive, }
      }
    None => ()
  }
  { ..info, min_value: Some(value), min_inclusive: inclusive, }
}

///|
fn fold_maximum(
  info : ConstraintInfo,
  value : Double,
  inclusive : Bool,
) -> ConstraintInfo {
  match info.max_value {
    Some(previous) =>
      if value > previous {
        return info
      } else if value == previous {
        return { ..info, max_inclusive: info.max_inclusive && inclusive, }
      }
    None => ()
  }
  { ..info, max_value: Some(value), max_inclusive: inclusive, }
}

///|
fn range_parts(info : ConstraintInfo, suffix : String) -> Array[String] {
  match (info.min_value, info.max_value) {
    (Some(a), Some(b)) =>
      if info.min_inclusive && info.max_inclusive {
        [format_double_simple(a) + "-" + format_double_simple(b) + suffix]
      } else {
        [
          (if info.min_inclusive { "min: " } else { "> " }) +
          format_double_simple(a),
          (if info.max_inclusive { "max: " } else { "< " }) +
          format_double_simple(b),
        ]
      }
    (Some(a), None) =>
      [
        (if info.min_inclusive { "min: " } else { "> " }) +
        format_double_simple(a),
      ]
    (None, Some(b)) =>
      [
        (if info.max_inclusive { "max: " } else { "< " }) +
        format_double_simple(b),
      ]
    _ => []
  }
}

///|
/// Render every string bound, format and pattern.
pub fn constraint_info_to_string_comment(info : ConstraintInfo) -> String {
  let parts = range_parts(info, " chars")
  for format in info.formats {
    parts.push(if format == "uri" { "url" } else { format })
  }
  for pattern in info.patterns {
    parts.push("pattern: " + pattern)
  }
  parts.append(info.custom_messages)
  parts.join(", ")
}

///|
/// Render numeric constraints, including negative and exclusive bounds.
pub fn constraint_info_to_number_comment(info : ConstraintInfo) -> String {
  let parts : Array[String] = []
  if info.is_int {
    parts.push("int")
  }
  if info.is_positive && info.max_value is None {
    parts.push("positive")
  } else if info.is_negative && info.min_value is None {
    parts.push("negative")
  } else {
    parts.append(range_parts(info, ""))
  }
  for multiple in info.multiples {
    parts.push("multiple of " + format_double_simple(multiple))
  }
  parts.append(info.custom_messages)
  parts.join(", ")
}

///|
/// Render array cardinality constraints.
pub fn constraint_info_to_array_comment(info : ConstraintInfo) -> String {
  let parts : Array[String] = []
  if info.min_value is Some(value) {
    parts.push("min: " + format_double_simple(value) + " items")
  }
  if info.max_value is Some(value) {
    parts.push("max: " + format_double_simple(value) + " items")
  }
  parts.append(info.custom_messages)
  parts.join(", ")
}

///|
/// Render opaque predicates.
pub fn constraint_info_to_fallback_comment(info : ConstraintInfo) -> String {
  info.custom_messages.join(", ")
}

///|
/// Keep checks attached after built-in effects when rendering constraints.
pub fn constraint_comment(schema : Schema) -> String {
  let info = extract_constraints(effective_rules(schema))
  match inner_type(schema.schema_type) {
    StringType => constraint_info_to_string_comment(info)
    NumberType => constraint_info_to_number_comment(info)
    ArrayType(_) => constraint_info_to_array_comment(info)
    _ => constraint_info_to_fallback_comment(info)
  }
}
