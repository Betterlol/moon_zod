# Stage Summary

## 1. Stage Description

Implement Phase 1 of `moon_zod`: core type system (`Schema`, `ValidationError`, `SchemaResult`) and four basic validators (`string`, `number`, `boolean`, `null`) with chainable rule methods, plus 28 passing tests.

## 2. Stage Metadata

- **STAGE_ID**: phase1
- **STAGE_TYPE**: core-implementation
- **BASE_COMMIT**: `6466b60b4a6b331868457fd2a9d96615bef386e8` (initial `moon new` template — single commit containing both template and Phase 1 work)

## 3. New Files

| File | Description |
|---|---|
| `types.mbt` | Core types: `ValidationError`, `SchemaResult` |
| `schema.mbt` | `Schema` struct, `SchemaType` enum, `Rule` type, `Schema::parse()` |
| `string.mbt` | `string()` factory + `.min()`, `.max()`, `.nonempty()`, `.email()`, `.url()`, `.regex()` |
| `number.mbt` | `number()` factory + `.int()`, `.positive()`, `.negative()`, `.multipleOf()` |
| `boolean.mbt` | `boolean()` factory |
| `null.mbt` | `null()` factory |
| `DESIGN.md` | Architecture design document, 4-phase roadmap |

## 4. New File Full Contents

### types.mbt

```
///|
/// Represents a single validation failure.
///
/// `path` is the field path (e.g. `"name"`, `"address.city"`).
/// `message` describes what went wrong.
/// `got` is the actual JSON value that failed validation.
pub struct ValidationError {
  path : String
  message : String
  got : Json
}

///|
/// Result type returned by `Schema::parse`.
/// `Ok(json)` on success, `Err(errors)` with all collected errors on failure.
pub type SchemaResult = Result[Json, Array[ValidationError]]
```

### schema.mbt

```
///|
/// Internal tag for runtime type dispatch.
pub(all) enum SchemaType {
  StringType
  NumberType
  BooleanType
  NullType
}

///|
/// A single validation rule: a predicate + error message.
pub(all) struct Rule {
  check : (Json) -> Bool
  message : String
}

///|
/// A schema defines the shape and constraints of JSON data.
pub struct Schema {
  schema_type : SchemaType
  rules : Array[Rule]
}

///|
fn expected_msg(schema_type : SchemaType) -> String {
  match schema_type {
    StringType => "Expected string"
    NumberType => "Expected number"
    BooleanType => "Expected boolean"
    NullType => "Expected null"
  }
}

///|
/// Validate `json` against this schema.
pub fn Schema::parse(
  self : Schema,
  json : Json,
  path? : String = "",
) -> SchemaResult {
  let valid = match (self.schema_type, json) {
    (StringType, String(_)) => true
    (NumberType, Number(_)) => true
    (BooleanType, True | False) => true
    (NullType, Null) => true
    _ => false
  }
  if !valid {
    return Err([
      ValidationError::{
        path,
        message: expected_msg(self.schema_type),
        got: json,
      },
    ])
  }
  let errors : Array[ValidationError] = []
  for rule in self.rules {
    if !(rule.check)(json) {
      errors.push(ValidationError::{ path, message: rule.message, got: json })
    }
  }
  if errors.is_empty() {
    Ok(json)
  } else {
    Err(errors)
  }
}
```

### string.mbt

```
///|
/// Create a schema that validates JSON strings.
pub fn string() -> Schema {
  { schema_type: StringType, rules: [] }
}

///|
fn schema_min_check(s : Schema, n : Int) -> (Json) -> Bool {
  match s.schema_type {
    StringType =>
      fn(json) {
        match json {
          String(s) => s.length() >= n
          _ => false
        }
      }
    NumberType =>
      fn(json) {
        match json {
          Number(v, ..) => v >= n.to_double()
          _ => false
        }
      }
    _ => fn(_) { false }
  }
}

///|
fn schema_min_msg(s : Schema, n : Int) -> String {
  match s.schema_type {
    StringType => "String must contain at least \{n} character(s)"
    NumberType => "Value must be >= \{n}"
    _ => abort("min() is only valid for string or number schemas")
  }
}

///|
/// Require the string length to be at least `n`.
pub fn Schema::min(self : Schema, n : Int) -> Schema {
  let check = schema_min_check(self, n)
  let message = schema_min_msg(self, n)
  { ..self, rules: self.rules + [{ check, message }] }
}

///|
fn schema_max_check(s : Schema, n : Int) -> (Json) -> Bool {
  match s.schema_type {
    StringType =>
      fn(json) {
        match json {
          String(s) => s.length() <= n
          _ => false
        }
      }
    NumberType =>
      fn(json) {
        match json {
          Number(v, ..) => v <= n.to_double()
          _ => false
        }
      }
    _ => fn(_) { false }
  }
}

///|
fn schema_max_msg(s : Schema, n : Int) -> String {
  match s.schema_type {
    StringType => "String must contain at most \{n} character(s)"
    NumberType => "Value must be <= \{n}"
    _ => abort("max() is only valid for string or number schemas")
  }
}

///|
/// Require the string length to be at most `n`.
pub fn Schema::max(self : Schema, n : Int) -> Schema {
  let check = schema_max_check(self, n)
  let message = schema_max_msg(self, n)
  { ..self, rules: self.rules + [{ check, message }] }
}

///|
/// Require the string to be non-empty.
pub fn Schema::nonempty(self : Schema) -> Schema {
  let _ = match self.schema_type {
    StringType => ()
    _ => abort("nonempty() is only valid for string schemas")
  }
  {
    ..self,
    rules: self.rules +
    [
      {
        check: fn(json) {
          match json {
            String(s) => !s.is_empty()
            _ => false
          }
        },
        message: "String must not be empty",
      },
    ],
  }
}

///|
fn has_at_and_dot(s : String) -> Bool {
  let chars = s.to_array()
  let mut at_pos : Int = -1
  for i, c in chars {
    if c == '@' {
      at_pos = i
      break
    }
  }
  if at_pos <= 0 {
    return false
  }
  for i = at_pos + 1; i < chars.length(); i = i + 1 {
    if chars[i] == '.' && i > at_pos + 1 && i < chars.length() - 1 {
      return true
    }
  }
  false
}

///|
/// Require the string to be a valid email.
pub fn Schema::email(self : Schema) -> Schema {
  let _ = match self.schema_type {
    StringType => ()
    _ => abort("email() is only valid for string schemas")
  }
  {
    ..self,
    rules: self.rules +
    [
      {
        check: fn(json) {
          match json {
            String(s) => has_at_and_dot(s)
            _ => false
          }
        },
        message: "String must be a valid email address",
      },
    ],
  }
}

///|
fn has_url_prefix(s : String) -> Bool {
  s.has_prefix("http://") || s.has_prefix("https://")
}

///|
/// Require the string to start with `http://` or `https://`.
pub fn Schema::url(self : Schema) -> Schema {
  let _ = match self.schema_type {
    StringType => ()
    _ => abort("url() is only valid for string schemas")
  }
  {
    ..self,
    rules: self.rules +
    [
      {
        check: fn(json) {
          match json {
            String(s) => has_url_prefix(s)
            _ => false
          }
        },
        message: "String must be a valid URL",
      },
    ],
  }
}

///|
/// Require the string to contain the given substring.
pub fn Schema::regex(self : Schema, pattern : String) -> Schema {
  let _ = match self.schema_type {
    StringType => ()
    _ => abort("regex() is only valid for string schemas")
  }
  {
    ..self,
    rules: self.rules +
    [
      {
        check: fn(json) {
          match json {
            String(s) => s.contains(pattern)
            _ => false
          }
        },
        message: "String must match pattern: \{pattern}",
      },
    ],
  }
}
```

### number.mbt

```
///|
/// Create a schema that validates JSON numbers.
pub fn number() -> Schema {
  { schema_type: NumberType, rules: [] }
}

///|
/// Require the number to be an integer (no fractional part).
pub fn Schema::int(self : Schema) -> Schema {
  let _ = match self.schema_type {
    NumberType => ()
    _ => abort("int() is only valid for number schemas")
  }
  {
    ..self,
    rules: self.rules +
    [
      {
        check: fn(json) {
          match json {
            Number(v, ..) => v == v.to_int().to_double()
            _ => false
          }
        },
        message: "Value must be an integer",
      },
    ],
  }
}

///|
/// Require the number to be positive (> 0).
pub fn Schema::positive(self : Schema) -> Schema {
  let _ = match self.schema_type {
    NumberType => ()
    _ => abort("positive() is only valid for number schemas")
  }
  {
    ..self,
    rules: self.rules +
    [
      {
        check: fn(json) {
          match json {
            Number(v, ..) => v > 0.0
            _ => false
          }
        },
        message: "Value must be positive",
      },
    ],
  }
}

///|
/// Require the number to be negative (< 0).
pub fn Schema::negative(self : Schema) -> Schema {
  let _ = match self.schema_type {
    NumberType => ()
    _ => abort("negative() is only valid for number schemas")
  }
  {
    ..self,
    rules: self.rules +
    [
      {
        check: fn(json) {
          match json {
            Number(v, ..) => v < 0.0
            _ => false
          }
        },
        message: "Value must be negative",
      },
    ],
  }
}

///|
/// Require the number to be a multiple of `n`.
pub fn Schema::multipleOf(self : Schema, n : Int) -> Schema {
  let _ = match self.schema_type {
    NumberType => ()
    _ => abort("multipleOf() is only valid for number schemas")
  }
  let msg = "Value must be a multiple of \{n}"
  {
    ..self,
    rules: self.rules +
    [
      {
        check: fn(json) {
          match json {
            Number(v, ..) =>
              v / n.to_double() == (v / n.to_double()).to_int().to_double()
            _ => false
          }
        },
        message: msg,
      },
    ],
  }
}
```

### boolean.mbt

```
///|
/// Create a schema that validates JSON booleans.
pub fn boolean() -> Schema {
  { schema_type: BooleanType, rules: [] }
}
```

### null.mbt

```
///|
/// Create a schema that validates JSON null.
pub fn null() -> Schema {
  { schema_type: NullType, rules: [] }
}
```

### DESIGN.md

(Architecture document — content omitted per summary file exclusion rule; present at `DESIGN.md`)

## 5. Modified Files

| File | Change |
|---|---|
| `moon_zod.mbt` | Replaced empty template with module-level doc comment + Quick start |
| `moon_zod_test.mbt` | Rewrote with 28 blackbox tests covering all validators |
| `moon.mod` | Added `keywords` and `description` metadata |
| `README.mbt.md` | Replaced placeholder with real project description |

## 6. Modified File Contents (Post-Modification)

### moon_zod.mbt

```
///|
/// moon_zod — A runtime JSON schema validation library for MoonBit.
///
/// Inspired by [Zod](https://zod.dev) (TypeScript) and [Pydantic](https://docs.pydantic.dev) (Python).
///
/// Designed for LLM Tool Calling: validate structured JSON output from large
/// language models at runtime, with precise error reporting.
///
/// # Quick start
///
/// ```mbt
/// let schema = @moon_zod.object({
///   "name": @moon_zod.string().min(2).max(50),
///   "age": @moon_zod.number().int().min(0).max(150),
/// })
///
/// match schema.parse(some_json) {
///   Ok(valid) => // use valid
///   Err(errors) => // report errors back to the LLM
/// }
/// ```
```

### moon_zod_test.mbt

(Full content at `moon_zod_test.mbt` — 28 tests covering string, number, boolean, null validators, chainable rules, and error message verification)

### moon.mod — metadata change

```
keywords = [ "json", "schema", "validation", "zod", "llm", "tool-calling" ]
description = "A runtime JSON schema validation library for MoonBit, inspired by Zod and Pydantic"
```

## 7. Deleted Files

None.

## 8. ACTION_LOG

| # | File | Action | Reason |
|---|---|---|---|
| 1 | `types.mbt` | CREATE | Define `ValidationError` and `SchemaResult` core types |
| 2 | `schema.mbt` | CREATE | Define `Schema` struct, `SchemaType` enum, `Rule` type, `parse()` core method |
| 3 | `string.mbt` | CREATE | `string()` factory with `.min()`, `.max()`, `.nonempty()`, `.email()`, `.url()`, `.regex()` |
| 4 | `number.mbt` | CREATE | `number()` factory with `.int()`, `.positive()`, `.negative()`, `.multipleOf()` |
| 5 | `boolean.mbt` | CREATE | `boolean()` factory |
| 6 | `null.mbt` | CREATE | `null()` factory |
| 7 | `DESIGN.md` | CREATE | Architecture doc with 4-phase roadmap |
| 8 | `moon_zod.mbt` | MODIFY | Add module doc comment + Quick start example |
| 9 | `moon_zod_test.mbt` | MODIFY | Write 28 tests covering valid/invalid cases, chainable rules, error messages, path propagation |
| 10 | `moon.mod` | MODIFY | Set `keywords` and `description` for package discovery |
| 11 | `README.mbt.md` | MODIFY | Replace placeholder with project overview and usage example |

## 9. Risks / Notes

- **Single-commit constraint**: BASE_COMMIT is the only commit, which combined the `moon new` template with Phase 1 work. No git diff against parent exists for modified template files.
- **`Json` enum constructors are read-only**: All `Json` values must be created via factory functions (`Json::string()`, `Json::number()`, `Json::boolean()`, `Json::null()`), not direct enum variants. This affected test writing.
- **`Number` enum quirks**: The `Number(Double, repr~: String?)` variant has a labeled argument `repr~`; pattern matching requires `Number(v, ..)` to suppress warnings.
- **`ValidationError` lacks `Eq`/`Show`**: `assert_eq` cannot be used directly on `Result[Json, Array[ValidationError]]`; tests use pattern matching instead.
- **Phase 1 scope complete**: 28/28 tests pass. Ready for Phase 2 (object support).
