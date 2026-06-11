///|
/// refine()
test "refine passes custom check" {
  let s = number().refine(
    fn(json) {
      match json {
        Number(v, ..) => v > 10.0
        _ => false
      }
    },
    "Value must be > 10",
  )
  match s.parse(Json::number(20.0)) {
    Ok(v) => @debug.assert_eq(v, Json::number(20.0))
    Err(_) => fail("expected Ok")
  }
}

///|
test "refine fails custom check" {
  let s = number().refine(
    fn(json) {
      match json {
        Number(v, ..) => v > 10.0
        _ => false
      }
    },
    "Value must be > 10",
  )
  guard s.parse(Json::number(5.0)) is Err(_) else { fail("expected Err") }
}

///|
/// Phase 2 — Transform Data Pipeline
test "transform appends suffix to string" {
  let s = string().transform(fn(json) {
    match json {
      String(v) => Ok(Json::string(v + "!!!"))
      _ => Err("expected string")
    }
  })
  match s.parse(Json::string("hello")) {
    Ok(v) => @debug.assert_eq(v, Json::string("hello!!!"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "transform passes through already-valid value" {
  let s = number().transform(fn(json) { Ok(json) })
  match s.parse(Json::number(42.0)) {
    Ok(v) => @debug.assert_eq(v, Json::number(42.0))
    Err(_) => fail("expected Ok")
  }
}

///|
test "transform returns error for invalid transform result" {
  let s = string().transform(fn(json) {
    match json {
      String(v) =>
        if v.length() > 3 {
          Err("too long after transform")
        } else {
          Ok(json)
        }
      _ => Err("expected string")
    }
  })
  guard s.parse(Json::string("hello")) is Err(_) else { fail("expected Err") }
}

///|
test "transform validates before transforming" {
  let s = string()
    .min(2)
    .transform(fn(json) {
      match json {
        String(v) => Ok(Json::string(v + "!!"))
        _ => Err("expected string")
      }
    })
  // min(2) passes: "ab" is length 2
  match s.parse(Json::string("ab")) {
    Ok(v) => @debug.assert_eq(v, Json::string("ab!!"))
    Err(_) => fail("expected Ok")
  }
  // min(2) fails: "a" is too short
  guard s.parse(Json::string("a")) is Err(_) else { fail("expected Err") }
}

///|
test "transform with optional accepts null" {
  let s = string()
    .transform(fn(json) {
      match json {
        String(v) => Ok(Json::string(v + "!"))
        _ => Err("expected string")
      }
    })
    .optional()
  // null should bypass the transform
  match s.parse(Json::null()) {
    Ok(v) => @debug.assert_eq(v, Json::null())
    Err(_) => fail("expected Ok")
  }
}

///|
test "transform error message includes path" {
  let s = object({
    "field": string().transform(fn(json) {
      match json {
        String(_) => Err("transform rejected this value")
        _ => Err("expected string")
      }
    }),
  })
  let json = parse_json("{\"field\": \"hello\"}")
  match s.parse(json) {
    Err(errors) => {
      @debug.assert_eq(errors[0].path, "field")
      @debug.assert_eq(errors[0].message, "transform rejected this value")
    }
    _ => fail("expected Err")
  }
}
