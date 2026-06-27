///|
/// Unified constraint information extracted from Rule annotations.
/// This data structure consolidates all constraint metadata across different types.
pub struct ConstraintInfo {
  min_value: Double  // For string length, number min, array minItems
  max_value: Double  // For string length, number max, array maxItems
  format: String     // "email", "uri", "date-time", "uuid", "ipv4", etc.
  pattern: String    // regex pattern
  is_int: Bool       // For numbers: must be integer
  is_positive: Bool  // For numbers: > 0
  is_negative: Bool  // For numbers: < 0
  multiple_of: Double // For numbers: multiple of N
  custom_messages: Array[String]  // Custom error messages
}

///|
/// Create a default empty ConstraintInfo
pub fn constraint_info_default() -> ConstraintInfo {
  {
    min_value: -1.0,
    max_value: -1.0,
    format: "",
    pattern: "",
    is_int: false,
    is_positive: false,
    is_negative: false,
    multiple_of: 0.0,
    custom_messages: [],
  }
}

///|
/// Extract all constraint information from a Rule array.
/// Unified extraction that works across all types.
pub fn extract_constraints(rules: Array[Rule]) -> ConstraintInfo {
  let mut min_value = -1.0
  let mut max_value = -1.0
  let mut format_val = ""
  let mut pattern_val = ""
  let mut is_int_val = false
  let mut is_positive_val = false
  let mut is_negative_val = false
  let mut multiple_of_val = 0.0
  let custom_messages_val: Array[String] = []

  // First pass: extract from JSON annotations
  for rule in rules {
    match rule.annotation {
      Object(map) => {
        // Length/Value constraints
        if map.contains("minLength") {
          match map.get("minLength") {
            Some(Number(v, ..)) => min_value = v
            _ => ()
          }
        }
        if map.contains("maxLength") {
          match map.get("maxLength") {
            Some(Number(v, ..)) => max_value = v
            _ => ()
          }
        }
        if map.contains("minimum") {
          match map.get("minimum") {
            Some(Number(v, ..)) => min_value = v
            _ => ()
          }
        }
        if map.contains("maximum") {
          match map.get("maximum") {
            Some(Number(v, ..)) => max_value = v
            _ => ()
          }
        }
        if map.contains("minItems") {
          match map.get("minItems") {
            Some(Number(v, ..)) => min_value = v
            _ => ()
          }
        }
        if map.contains("maxItems") {
          match map.get("maxItems") {
            Some(Number(v, ..)) => max_value = v
            _ => ()
          }
        }

        // Format and pattern
        if map.contains("format") {
          match map.get("format") {
            Some(String(s)) => format_val = s
            _ => ()
          }
        }
        if map.contains("pattern") {
          match map.get("pattern") {
            Some(String(s)) => pattern_val = s
            _ => ()
          }
        }

        // Type-specific flags
        if map.contains("type") {
          match map.get("type") {
            Some(String(s)) => if s == "integer" { is_int_val = true }
            _ => ()
          }
        }

        // Numeric constraints
        if map.contains("exclusiveMinimum") {
          match map.get("exclusiveMinimum") {
            Some(Number(v, ..)) => if v == 0.0 { is_positive_val = true }
            _ => ()
          }
        }
        if map.contains("exclusiveMaximum") {
          match map.get("exclusiveMaximum") {
            Some(Number(v, ..)) => if v == 0.0 { is_negative_val = true }
            _ => ()
          }
        }
        if map.contains("multipleOf") {
          match map.get("multipleOf") {
            Some(Number(v, ..)) => multiple_of_val = v
            _ => ()
          }
        }
      }
      _ => ()
    }
  }

  // Second pass: collect custom error messages
  for rule in rules {
    match rule.annotation {
      Null => {
        // Skip certain standard messages
        if rule.message != "String must not be empty" {
          custom_messages_val.push(rule.message)
        }
      }
      _ => ()
    }
  }

  {
    min_value,
    max_value,
    format: format_val,
    pattern: pattern_val,
    is_int: is_int_val,
    is_positive: is_positive_val,
    is_negative: is_negative_val,
    multiple_of: multiple_of_val,
    custom_messages: custom_messages_val,
  }
}

///|
/// Convert ConstraintInfo to prompt comment string for strings.
pub fn constraint_info_to_string_comment(info: ConstraintInfo) -> String {
  let parts: Array[String] = []

  // Length constraints
  if info.min_value >= 0.0 && info.max_value >= 0.0 {
    parts.push(
      format_double_simple(info.min_value) +
      "-" +
      format_double_simple(info.max_value) +
      " chars",
    )
  } else if info.min_value >= 0.0 {
    parts.push("min: " + format_double_simple(info.min_value))
  } else if info.max_value >= 0.0 {
    parts.push("max: " + format_double_simple(info.max_value))
  }

  // Format
  if info.format == "email" {
    parts.push("email")
  } else if info.format == "uri" {
    parts.push("url")
  } else if !info.format.is_empty() {
    parts.push(info.format)
  }

  // Pattern
  if !info.pattern.is_empty() {
    parts.push("pattern: " + info.pattern)
  }

  // Custom messages
  for msg in info.custom_messages {
    parts.push(msg)
  }

  if parts.is_empty() {
    ""
  } else {
    join_parts(parts)
  }
}

///|
/// Convert ConstraintInfo to prompt comment string for numbers.
pub fn constraint_info_to_number_comment(info: ConstraintInfo) -> String {
  let parts: Array[String] = []

  // Type
  if info.is_int {
    parts.push("int")
  }

  // Range
  if info.is_positive {
    parts.push("positive")
  } else if info.is_negative {
    parts.push("negative")
  } else if info.min_value >= 0.0 && info.max_value >= 0.0 {
    parts.push(
      format_double_simple(info.min_value) + "-" + format_double_simple(info.max_value),
    )
  } else if info.min_value >= 0.0 {
    parts.push("min: " + format_double_simple(info.min_value))
  } else if info.max_value >= 0.0 {
    parts.push("max: " + format_double_simple(info.max_value))
  }

  // Special constraints
  if info.multiple_of > 0.0 {
    parts.push("multiple of " + format_double_simple(info.multiple_of))
  }

  // Custom messages
  for msg in info.custom_messages {
    parts.push(msg)
  }

  if parts.is_empty() {
    ""
  } else {
    join_parts(parts)
  }
}

///|
/// Convert ConstraintInfo to prompt comment string for arrays.
pub fn constraint_info_to_array_comment(info: ConstraintInfo) -> String {
  let parts: Array[String] = []

  // Item count (use min/max format, not range format like strings)
  if info.min_value >= 0.0 {
    parts.push("min: " + format_double_simple(info.min_value) + " items")
  }
  if info.max_value >= 0.0 {
    parts.push("max: " + format_double_simple(info.max_value) + " items")
  }

  // Custom messages
  for msg in info.custom_messages {
    parts.push(msg)
  }

  if parts.is_empty() {
    ""
  } else {
    join_parts(parts)
  }
}

///|
/// Convert ConstraintInfo to prompt comment string (fallback for unknown types).
pub fn constraint_info_to_fallback_comment(info: ConstraintInfo) -> String {
  let parts: Array[String] = []

  for msg in info.custom_messages {
    parts.push(msg)
  }

  if parts.is_empty() {
    ""
  } else {
    join_parts(parts)
  }
}
