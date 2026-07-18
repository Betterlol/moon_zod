///|
test "safe_parse accepts valid input" {
  let s = string().min(3)
  let params = ParseParams::default()
  match s.safe_parse(Json::string("abc"), params) {
    Ok(v) => @debug.assert_eq(v, Json::string("abc"))
    Err(_) => fail("expected Ok")
  }
}

///|
test "safe_parse returns errors for invalid input" {
  let s = string().min(3)
  let params = ParseParams::default()
  guard s.safe_parse(Json::string("ab"), params) is Err(_) else {
    fail("expected Err")
  }
}

///|
test "error_map overrides type error message" {
  let s = string()
  let params = ParseParams::{
    path: "",
    error_map: Some(fn(code, _path, _input) {
      match code {
        IssueCode::InvalidType(_) => Some("必须是字符串")
        _ => None
      }
    }),
  }
  match s.safe_parse(Json::number(42.0), params) {
    Err(errors) => @debug.assert_eq(errors[0].message, "必须是字符串")
    Ok(_) => fail("expected Err")
  }
}

///|
test "error_map overrides missing required message" {
  let s = object({ "name": string() })
  let params = ParseParams::{
    path: "",
    error_map: Some(fn(code, _path, _input) {
      match code {
        IssueCode::MissingRequired(_) => Some("缺少姓名")
        _ => None
      }
    }),
  }
  match s.safe_parse(parse_json("{}"), params) {
    Err(errors) => @debug.assert_eq(errors[0].message, "缺少姓名")
    Ok(_) => fail("expected Err")
  }
}

///|
test "error_map overrides union error message" {
  let s = union([string(), number()])
  let params = ParseParams::{
    path: "",
    error_map: Some(fn(code, _path, _input) {
      match code {
        IssueCode::InvalidUnion(_) => Some("必须是字符串或数字")
        _ => None
      }
    }),
  }
  match s.safe_parse(Json::boolean(true), params) {
    Err(errors) =>
      @debug.assert_eq(errors[0].message, "必须是字符串或数字")
    Ok(_) => fail("expected Err")
  }
}

///|
test "error_map does not affect other parses" {
  let s = string()
  let params = ParseParams::{
    path: "",
    error_map: Some(fn(code, _path, _input) {
      match code {
        IssueCode::InvalidType(_) => Some("custom type error")
        _ => None
      }
    }),
  }
  match s.safe_parse(Json::number(42.0), params) {
    Err(errors) => @debug.assert_eq(errors[0].message, "custom type error")
    Ok(_) => fail("expected Err")
  }
  let default_params = ParseParams::default()
  match s.safe_parse(Json::number(42.0), default_params) {
    Err(errors) => @debug.assert_eq(errors[0].message, "Expected string")
    Ok(_) => fail("expected Err")
  }
}

///|
test "error_map none uses default message" {
  let s = string()
  let params = ParseParams::default()
  match s.safe_parse(Json::number(42.0), params) {
    Err(errors) => @debug.assert_eq(errors[0].message, "Expected string")
    Ok(_) => fail("expected Err")
  }
}

///|
test "error_map empty string falls back to inline or schema default" {
  let s = string(invalid_type_error="custom type error")
  let params = ParseParams::{
    path: "",
    error_map: Some(fn(code, _path, _input) {
      match code {
        IssueCode::InvalidType(_) => Some("")
        _ => None
      }
    }),
  }
  match s.safe_parse(Json::number(42.0), params) {
    Err(errors) => @debug.assert_eq(errors[0].message, "custom type error")
    Ok(_) => fail("expected Err")
  }
}

///|
test "error_map empty string falls back to hardcoded default" {
  let s = string()
  let params = ParseParams::{
    path: "",
    error_map: Some(fn(code, _path, _input) {
      match code {
        IssueCode::InvalidType(_) => Some("")
        _ => None
      }
    }),
  }
  match s.safe_parse(Json::number(42.0), params) {
    Err(errors) => @debug.assert_eq(errors[0].message, "Expected string")
    Ok(_) => fail("expected Err")
  }
}

///|
test "error_map multiple errors in one parse" {
  let s = object({ "name": string(), "age": number().int() })
  let params = ParseParams::{
    path: "",
    error_map: Some(fn(code, _path, _input) {
      match code {
        IssueCode::MissingRequired(_) => Some("缺少必填字段")
        IssueCode::InvalidType(_) => Some("类型错误")
        _ => None
      }
    }),
  }
  let input = parse_json("{\"name\": true}")
  match s.safe_parse(input, params) {
    Err(errors) => {
      @debug.assert_eq(errors.length(), 2)
      let messages = errors.map(fn(e) { e.message })
      @debug.assert_eq(messages.contains("缺少必填字段"), true)
      @debug.assert_eq(messages.contains("类型错误"), true)
    }
    Ok(_) => fail("expected Err")
  }
}

///|
test "error_map priority over invalid_type_error" {
  let s = string(invalid_type_error="schema type error")
  let params = ParseParams::{
    path: "",
    error_map: Some(fn(code, _path, _input) {
      match code {
        IssueCode::InvalidType(_) => Some("map type error")
        _ => None
      }
    }),
  }
  match s.safe_parse(Json::number(42.0), params) {
    Err(errors) => @debug.assert_eq(errors[0].message, "map type error")
    Ok(_) => fail("expected Err")
  }
}

///|
test "error_map nested schema" {
  let s = object({ "user": object({ "age": number().int() }) })
  let params = ParseParams::{
    path: "",
    error_map: Some(fn(code, _path, _input) {
      match code {
        IssueCode::InvalidType(expected) => Some("类型错误: " + expected)
        _ => None
      }
    }),
  }
  let input = parse_json("{\"user\": {\"age\": \"x\"}}")
  match s.safe_parse(input, params) {
    Err(errors) => @debug.assert_eq(errors[0].message, "类型错误: number")
    Ok(_) => fail("expected Err")
  }
}

///|
test "error_map array elements" {
  let s = array(number().int())
  let params = ParseParams::{
    path: "",
    error_map: Some(fn(code, _path, _input) {
      match code {
        IssueCode::InvalidType(expected) => Some("需要: " + expected)
        _ => None
      }
    }),
  }
  let input = parse_json("[1, \"two\"]")
  match s.safe_parse(input, params) {
    Err(errors) => @debug.assert_eq(errors[0].message, "需要: number")
    Ok(_) => fail("expected Err")
  }
}

///|
test "error_map priority over type error inline" {
  let s = string(invalid_type_error="custom type error")
  let params = ParseParams::{
    path: "",
    error_map: Some(fn(code, _path, _input) {
      match code {
        IssueCode::InvalidType(_) => Some("map type error")
        _ => None
      }
    }),
  }
  match s.safe_parse(Json::number(42.0), params) {
    Err(errors) => @debug.assert_eq(errors[0].message, "map type error")
    Ok(_) => fail("expected Err")
  }
}

///|
test "safe_parse with path prefix" {
  let s = string().min(3)
  let params = ParseParams::{ path: "user.name", error_map: None }
  match s.safe_parse(Json::string("ab"), params) {
    Err(errors) => @debug.assert_eq(errors[0].path, "user.name")
    Ok(_) => fail("expected Err")
  }
}
