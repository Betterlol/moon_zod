///|
test "pipe chains two schemas" {
  let s = string().pipe(string().min(3).max(10))
  guard s.parse(Json::string("hello")) is Ok(_) else { fail("expected Ok") }
}

///|
test "pipe rejects first stage" {
  let s = number().pipe(string())
  guard s.parse(Json::string("hello")) is Err(_) else { fail("expected Err") }
}

///|
test "pipe rejects second stage" {
  let s = string().pipe(string().min(3))
  guard s.parse(Json::string("ab")) is Err(errors) else { fail("expected Err") }
  @debug.assert_eq(errors.length(), 1)
  match errors[0].code {
    IssueCode::TooSmall(_, _, _) => ()
    _ => fail("expected TooSmall")
  }
}

///|
test "pipe with transform bridges types" {
  let s = string()
    .transform(fn(json) {
      match json {
        String(s) => Ok(Json::number(s.length().to_double()))
        _ => Err("expected string")
      }
    })
    .pipe(number().min(3).max(10).int())
  // "hello".length() = 5, which passes min(3) and max(10)
  guard s.parse(Json::string("hello")) is Ok(_) else { fail("expected Ok") }
  // "hi".length() = 2, fails min(3)
  guard s.parse(Json::string("hi")) is Err(_) else { fail("expected Err") }
}

///|
test "pipe reports first stage error before second stage" {
  // If first stage fails, second stage is never tried
  let s = number().refine(fn(json) {
    match json { Number(v, ..) => v > 0.0; _ => false }
  }, "must be positive").pipe(string())
  guard s.parse(Json::number(-1.0)) is Err(_) else { fail("expected Err") }
}

///|
test "pipe with chained rules after pipe" {
  let s = string().pipe(number()).refine(fn(json) {
    match json { Number(v, ..) => v > 0.0; _ => false }
  }, "must be positive")
  guard s.parse(Json::string("42")) is Err(_) else { fail("expected Err") }
}

///|
test "pipe error_map works for second stage" {
  let s = string().pipe(string().min(3))
  let params = ParseParams::{
    path: "",
    error_map: Some(fn(code, _path, _input) {
      match code {
        IssueCode::TooSmall(_, _, _) => Some("太短了")
        _ => None
      }
    }),
  }
  match s.safe_parse(Json::string("ab"), params) {
    Err(errors) => @debug.assert_eq(errors[0].message, "太短了")
    _ => fail("expected Err")
  }
}
