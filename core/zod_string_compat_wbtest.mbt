///|
test "Zod string lengths count code points rather than UTF-16 units" {
  for value in ["😀", "𐐀", "a😀b", "e\u{0301}", "🧑‍🍼"] {
    let count = match value {
      "😀" | "𐐀" => 1
      "a😀b" | "🧑‍🍼" => 3
      _ => 2
    }
    assert_true(string().length(count).parse(Json::string(value)) is Ok(_))
    assert_true(
      string().min(count).max(count).parse(Json::string(value)) is Ok(_),
    )
    assert_true(string().min(count + 1).parse(Json::string(value)) is Err(_))
    assert_true(string().max(count - 1).parse(Json::string(value)) is Err(_))
  }
}

///|
test "Zod string lengths preserve unpaired surrogate code points" {
  let high = "😀".unsafe_substring(start=0, end=1)
  let low = "😀".unsafe_substring(start=1, end=2)
  for (value, count) in [(high, 1), (low, 1), (high + "x", 2), (low + high, 2)] {
    assert_true(string().length(count).parse(Json::string(value)) is Ok(_))
  }
}

///|
test "Zod lower case maps Unicode scripts and expansions" {
  assert_eq(
    string()
    .to_lower()
    .parse(Json::string("ÉCOLE ΣΊΣΥΦΟΣ İ ẞ 𐐀 Ꭰ"))
    .unwrap(),
    Json::string("école σίσυφος i\u{0307} ß 𐐨 ꭰ"),
  )
}

///|
test "Zod upper case maps Unicode scripts and expansions" {
  assert_eq(
    string()
    .to_upper()
    .parse(Json::string("straße ﬃ ǰ ΐ 𐐨 ꭰ"))
    .unwrap(),
    Json::string("STRASSE FFI J\u{030c} Ι\u{0308}\u{0301} 𐐀 Ꭰ"),
  )
}

///|
test "Zod lower case uses original cased and case-ignorable sigma context" {
  for
    (value, expected) in [
      ("ΟΣ", "ος"),
      ("ΟΣΑ", "οσα"),
      ("Σ", "σ"),
      ("ΣΣ", "σς"),
      ("Ο\u{0301}Σ\u{0301}", "ο\u{0301}ς\u{0301}"),
      ("AΣ'A", "aσ'a"),
      ("AΣ'!", "aς'!"),
      ("AΣ\u{0345}A", "aσ\u{0345}a"),
      ("\u{0345}Σ", "\u{0345}σ"),
      ("AΣ1A", "aς1a"),
      ("1Σ", "1σ"),
      ("ⅠΣ", "ⅰς"),
    ] {
    assert_eq(
      string().to_lower().parse(Json::string(value)).unwrap(),
      Json::string(expected),
    )
  }
}

///|
test "Zod string casing preserves lone surrogates" {
  let high = "😀".unsafe_substring(start=0, end=1)
  let low = "😀".unsafe_substring(start=1, end=2)
  let value = high + "É" + low
  assert_eq(
    string().to_lower().parse(Json::string(value)).unwrap(),
    Json::string(high + "é" + low),
  )
}

///|
test "Zod trim recognizes the ECMAScript whitespace and line terminator set" {
  for
    whitespace in [
      "\t", "\n", "\u{000b}", "\u{000c}", "\r", " ", "\u{00a0}", "\u{1680}", "\u{2000}",
      "\u{2001}", "\u{2002}", "\u{2003}", "\u{2004}", "\u{2005}", "\u{2006}", "\u{2007}",
      "\u{2008}", "\u{2009}", "\u{200a}", "\u{2028}", "\u{2029}", "\u{202f}", "\u{205f}",
      "\u{3000}", "\u{feff}",
    ] {
    assert_eq(
      string()
      .trim()
      .parse(Json::string(whitespace + "x" + whitespace))
      .unwrap(),
      Json::string("x"),
    )
    assert_true(
      string().trim().nonempty().parse(Json::string(whitespace)) is Err(_),
    )
  }
  for value in ["\u{0085}", "\u{180e}", "\u{200b}", "\u{2060}"] {
    assert_eq(
      string().trim().parse(Json::string(value)).unwrap(),
      Json::string(value),
    )
  }
}

///|
test "Zod datetime minute precision accepts numeric offsets" {
  for
    value in [
      "2024-01-01T12:34Z", "2024-01-01T12:34+08:00", "2024-01-01T12:34-23:59",
    ] {
    assert_true(
      string().datetime(precision=-1, offset=true).parse(Json::string(value))
      is Ok(_),
    )
  }
  assert_true(
    string()
    .datetime(precision=-1, offset=true)
    .parse(Json::string("2024-01-01T12:34:00+08:00"))
    is Err(_),
  )
  assert_true(
    string()
    .datetime(precision=-1)
    .parse(Json::string("2024-01-01T12:34+08:00"))
    is Err(_),
  )
}

///|
test "Zod datetime zero precision requires local seconds" {
  assert_true(
    string()
    .datetime(precision=0, allow_local=true)
    .parse(Json::string("2024-01-01T12:34"))
    is Err(_),
  )
  assert_true(
    string()
    .datetime(precision=0, allow_local=true)
    .parse(Json::string("2024-01-01T12:34:00"))
    is Ok(_),
  )
  assert_true(
    string().datetime(allow_local=true).parse(Json::string("2024-01-01T12:34"))
    is Ok(_),
  )
}

///|
test "Zod ULID accepts lower and mixed case without widening its alphabet" {
  for value in ["01arz3ndektsv4rrffq69g5fav", "01ArZ3nDeKtSv4rRfFq69g5FaV"] {
    assert_true(string().ulid().parse(Json::string(value)) is Ok(_))
  }
  for bad in ["i", "l", "o", "u", "I", "L", "O", "U"] {
    assert_true(
      string().ulid().parse(Json::string("01ARZ3NDEKTSV4RRFFQ69G5FA" + bad))
      is Err(_),
    )
  }
}

///|
test "Zod string substring checks report invalid_format diagnostics" {
  for
    (schema, format) in [
      (string().startsWith("x"), "starts_with"),
      (string().endsWith("x"), "ends_with"),
      (string().includes("x"), "includes"),
    ] {
    guard schema.parse(Json::string("abc")) is Err(errors) else {
      fail("expected error")
    }
    assert_eq(errors[0].code, InvalidFormat(format))
  }
}
