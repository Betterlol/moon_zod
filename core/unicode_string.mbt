///|
// Unlike the standard char_length, also accepts unpaired UTF-16 surrogates.
fn ecma_code_point_at(value : String, index : Int32) -> (Int32, Int32) {
  let first = value[index].to_int()
  if first >= 0xd800 && first <= 0xdbff && index + 1 < value.length() {
    let second = value[index + 1].to_int()
    if second >= 0xdc00 && second <= 0xdfff {
      return (0x10000 + (first - 0xd800) * 0x400 + second - 0xdc00, 2)
    }
  }
  (first, 1)
}

///|
fn ecma_code_point_length(value : String) -> Int32 {
  let mut index = 0
  let mut count = 0
  while index < value.length() {
    let (_, width) = ecma_code_point_at(value, index)
    index = index + width
    count = count + 1
  }
  count
}

///|
fn unicode_property_contains(
  point : Int32,
  ranges : Array[(Int32, Int32)],
) -> Bool {
  let mut low = 0
  let mut high = ranges.length()
  while low < high {
    let mid = low + (high - low) / 2
    let (first, last) = ranges[mid]
    if point < first {
      high = mid
    } else if point > last {
      low = mid + 1
    } else {
      return true
    }
  }
  false
}

///|
fn unicode_simple_case(
  point : Int32,
  ranges : Array[(Int32, Int32, Int32, Int32)],
) -> Int32 {
  let mut low = 0
  let mut high = ranges.length()
  while low < high {
    let mid = low + (high - low) / 2
    let (first, last, stride, delta) = ranges[mid]
    if point < first {
      high = mid
    } else if point > last {
      low = mid + 1
    } else {
      return if (point - first) % stride == 0 { point + delta } else { point }
    }
  }
  point
}

///|
fn unicode_expanded_case(
  point : Int32,
  expansions : Array[(Int32, String)],
) -> String? {
  let mut low = 0
  let mut high = expansions.length()
  while low < high {
    let mid = low + (high - low) / 2
    let (key, mapped) = expansions[mid]
    if point < key {
      high = mid
    } else if point > key {
      low = mid + 1
    } else {
      return Some(mapped)
    }
  }
  None
}

///|
// Unicode Final_Sigma ignores Case_Ignorable before testing Cased, including
// code points with both properties. Context is read from the original input.
fn unicode_is_final_sigma(value : String, index : Int32) -> Bool {
  let mut before = index
  let mut preceded_by_cased = false
  while before > 0 {
    let mut start = before - 1
    let last = value[start].to_int()
    if last >= 0xdc00 && last <= 0xdfff && start > 0 {
      let previous = value[start - 1].to_int()
      if previous >= 0xd800 && previous <= 0xdbff {
        start = start - 1
      }
    }
    let (point, _) = ecma_code_point_at(value, start)
    before = start
    if unicode_property_contains(point, unicode_ignorable_ranges) {
      continue
    }
    preceded_by_cased = unicode_property_contains(point, unicode_cased_ranges)
    break
  }
  if !preceded_by_cased {
    return false
  }
  let mut after = index + 1
  while after < value.length() {
    let (point, width) = ecma_code_point_at(value, after)
    after = after + width
    if unicode_property_contains(point, unicode_ignorable_ranges) {
      continue
    }
    return !unicode_property_contains(point, unicode_cased_ranges)
  }
  true
}

///|
fn ecma_case_convert(value : String, upper : Bool) -> String {
  let ranges = if upper { unicode_upper_ranges } else { unicode_lower_ranges }
  let expansions = if upper {
    unicode_upper_expansions
  } else {
    unicode_lower_expansions
  }
  let result = StringBuilder(size_hint=value.length())
  let mut index = 0
  while index < value.length() {
    let (point, width) = ecma_code_point_at(value, index)
    if !upper && point == 0x03a3 && unicode_is_final_sigma(value, index) {
      result.write_char('ς')
    } else if unicode_expanded_case(point, expansions) is Some(mapped) {
      result.write_string(mapped)
    } else {
      let mapped = unicode_simple_case(point, ranges)
      if mapped == point {
        // Copy code units so lone surrogates are never coerced into Char.
        result.write_view(value[index:index + width])
      } else {
        // Generated mappings contain only Unicode scalar values.
        result.write_char(mapped.unsafe_to_char())
      }
    }
    index = index + width
  }
  result.to_string()
}

///|
fn ecma_is_whitespace(unit : UInt16) -> Bool {
  match unit.to_int() {
    0x0009
    | 0x000a
    | 0x000b
    | 0x000c
    | 0x000d
    | 0x0020
    | 0x00a0
    | 0x1680
    | 0x2000..<=0x200a
    | 0x2028
    | 0x2029
    | 0x202f
    | 0x205f
    | 0x3000
    | 0xfeff => true
    _ => false
  }
}

///|
fn ecma_trim(value : String) -> String {
  let mut start = 0
  let mut end = value.length()
  while start < end && ecma_is_whitespace(value[start]) {
    start = start + 1
  }
  while end > start && ecma_is_whitespace(value[end - 1]) {
    end = end - 1
  }
  // Both offsets are within bounds; avoid StringView's surrogate normalization.
  value.unsafe_substring(start~, end~)
}
