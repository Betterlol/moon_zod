///|
test "URI rejects illegal characters and malformed escapes in every component" {
  let schema = string().url()
  for
    input in [
      "https://example.com/a b", "https://example.com/%zz", "mailto:a\nb", "https://user name@example.com/",
      "https://example.com/?a=%", "https://example.com/#%0", "https://u%xx@example.com/",
      "https://a@b@example.com/", "mailto:[a]", "https://example.com/[x]", "https://example.com/#x#y",
      " https://example.com/ ", "https://example.com/\\x", "https://example.com/{x}",
      "https://example.com/中文",
    ] {
    assert_true(schema.parse(Json::string(input)) is Err(_), msg=input)
  }
}

///|
test "URI preserves percent encodings and valid component-specific delimiters" {
  let schema = string().url()
  for
    input in [
      "https://user:pass%40word@example.com/a%20b?x=%2F#ok?yes", "HTTPS://[2001:db8::1]:443/a%20b?x=%2F#ok",
      "mailto:a%2Bb@example.com", "urn:isbn:0451450523", "file:///a%20b", "https://example.com/a;b,c!d$e&f'g(h)i+j=k_~",
      "https://example.com/%E4%B8%AD",
    ] {
    assert_true(schema.parse(Json::string(input)) is Ok(_), msg=input)
  }
}
