# Stage Summary

## 1. Stage Description

Phase 42 — Structured Error System: IssueCode + ErrorMap + ParseParams + constraint_extractor integration.

Replace flat `ValidationError{path, message, got}` with machine-readable `IssueCode` enum, add `safe_parse` API with contextual `ErrorMap` override, integrate IssueCode with `constraint_extractor`, and remove redundancy in error collection pipeline.

## 2. Stage Metadata

- STAGE_ID: Phase 42
- STAGE_TYPE: refactor + feature
- BRANCH: phase42_zod_error_map (reference), implemented on `develop`
- COMMITS: `1567bb8`, `ab39c11`, `c9578f1`

## 3. Decision Document

See `branch_doc/DECISION_ERROR_SYSTEM.md` for the full design rationale covering:
- Why IssueCode + ErrorMap (Zod-like) over Rust trait approach
- Why no global error map (MoonBit module system constraints)
- Why no intermediate `Issue` type (flat pipeline)
- Why no `inst: Schema?` in RawIssue (messages resolved at source)

## 4. Architecture

### Data Flow

```moonbit
parse_inner() → RawSchemaResult = Result[Json, Array[RawIssue]]
                                       ↓
Schema::safe_parse() → finalize_issues(raw, params) → SchemaResult
                                       ↓
Schema::parse() — delegates to safe_parse(error_map = None)
```

### Priority Chain

```
1. ParseParams.error_map    ← contextual override (highest)
2. Pre-resolved message     ← resolved at error source (rule.message /
                              type_msg(schema) / required_msg(schema) /
                              hardcoded string)
```

### Key Design Decisions vs phase42 Branch

| Decision | phase42 (abandoned) | This implementation |
|----------|---------------------|---------------------|
| `RawIssue.path` | `Array[String]` — copied per error, then format_path in finalize | `String` — formatted once at error source, zero allocation in finalize |
| `RawIssue.inst` | `Schema?` — carries full schema ref for deferred message resolution | **Removed** — messages resolved at error source |
| `Issue` intermediate | `RawIssue → Issue → ValidationError` | **Removed** — `RawIssue → ValidationError` direct |
| `finalize_issue` | 4-layer nested if-else with empty-string fallback | 2-layer: error_map override → pre-resolved message |
| `collect_raw_errors` param | `path: String` — each call site had `let path = format_path(path_stack)` | `path_stack: Array[String]` — formats internally, eliminating 7 redundant lines |

## 5. New Files

- `core/errors.mbt`

## 6. New File Full Contents

### core/errors.mbt

```moonbit
///|
pub(all) enum IssueCode {
  InvalidType(String)
  TooBig(String, Double, Bool)
  TooSmall(String, Double, Bool)
  InvalidFormat(String)
  NotMultipleOf(Double)
  UnrecognizedKeys(Array[String])
  InvalidUnion(Array[String])
  MissingRequired(String)
  InvalidKey(String)
  InvalidElement(String, Int)
  InvalidValue(Array[Json])
  Custom
} derive(Debug, Eq)

pub type ErrorMap = (IssueCode, String, Json) -> String?

pub(all) struct ParseParams {
  path : String
  error_map : ErrorMap?
}

pub(all) struct RawIssue {
  code : IssueCode
  path : String
  message : String
  input : Json
}

pub fn finalize_issue(raw : RawIssue, params : ParseParams) -> ValidationError
pub fn finalize_issues(raw_issues : Array[RawIssue], params : ParseParams) -> Array[ValidationError]
pub fn collect_raw_errors(out : Array[RawIssue], path_stack : Array[String], json : Json, rules : Array[Rule]) -> Unit
pub fn type_origin(t : SchemaType) -> String
```

## 7. Modified Files

| File | Changes |
|------|---------|
| `core/types.mbt` | `ValidationError` gains `code: IssueCode`, `derive(Debug)`, `to_string()` includes code in output. New `RawSchemaResult` type alias. |
| `core/schema.mbt` | `Rule` gains `code: IssueCode`. `append_rule`/`append_rule_with_annotation` take `code`. `type_error_msg`/`expected_msg`/`collect_errors` removed; replaced by `type_msg()` and `collect_raw_errors()`. `parse_inner` returns `RawSchemaResult`. New `Schema::safe_parse()` public API. `parse()` delegates to `safe_parse`. |
| `core/string.mbt` | All rule methods pass precise IssueCode: `TooSmall` for `.min()`, `TooBig` for `.max()`, `InvalidFormat("email"/"url"/"uuid"/etc)` for format validators, `TooSmall(1.0)` for `.nonempty()`. |
| `core/number.mbt` | `.int()` → `InvalidFormat("integer")`, `.positive()` → `TooSmall`, `.negative()` → `TooBig`, `.multipleOf()` → `NotMultipleOf`. |
| `core/object.mbt` | `parse_object` returns `RawSchemaResult`. `MissingRequired` creates `RawIssue` with pre-resolved message. `UnrecognizedKeys` per push/pop path. |
| `core/array.mbt` | `parse_array` returns `RawSchemaResult`. |
| `core/tuple.mbt` | `parse_tuple` returns `RawSchemaResult`. Length mismatch split into `TooSmall`/`TooBig` per actual vs expected. |
| `core/enum.mbt` | `parse_enum` returns `RawSchemaResult`. Invalid value → `InvalidValue`, type mismatch → `InvalidType("string")`. |
| `core/union.mbt` | `parse_union` returns `RawSchemaResult`. First branch error message captured per branch. |
| `core/intersection.mbt` | `parse_intersection` returns `RawSchemaResult`. |
| `core/literal.mbt` | `parse_literal` returns `RawSchemaResult`. Mismatch → `InvalidValue`. |
| `core/optional.mbt` | Return type `RawSchemaResult`. |
| `core/default.mbt` | Return type `RawSchemaResult`. |
| `core/preprocess.mbt` | `parse_preprocess` returns `RawSchemaResult`. Transform error → `Custom`. |
| `core/transform.mbt` | `parse_transform` returns `RawSchemaResult`. Transform error → `Custom`. |
| `core/refine.mbt` | `.refine()` → `IssueCode::Custom`. |
| `core/constraint_extractor.mbt` | Now reads `min_value`/`max_value`/`format`/`multiple_of`/`is_int` from `Rule.code` (structured IssueCode) as primary source. Annotation JSON kept as fallback for `Custom` rules. |
| `core/errors.mbt` | `collect_raw_errors` accepts `path_stack: Array[String]` and formats internally — eliminates redundant `format_path` at all 7 call sites. |
| `importers/from_json_schema.mbt` | All 3 `append_rule` calls pass `@core.IssueCode::Custom`. |
| `tests/reexporter.mbt` | Re-exports `IssueCode`, `RawIssue`, `ParseParams`, `ErrorMap`, `RawSchemaResult`, `finalize_issue`, `finalize_issues`, `collect_raw_errors`. |
| `tests/test_prompt.mbt` | Updated "nonempty is filtered" test to expect `[min: 1]` (now correctly extracted from IssueCode). |

## 8. Test Coverage

| Test File | Tests | Coverage |
|-----------|-------|----------|
| `tests/test_issue_code.mbt` | 21 tests | All IssueCode variants: InvalidType (6), TooSmall, InvalidFormat, Custom, MissingRequired (2), InvalidUnion, UnrecognizedKeys, InvalidValue (2), nested path, array index |
| `tests/test_error_map.mbt` | 15 tests | Override type/missing/union, empty string fallback, multiple errors, nested schema, array, path prefix, isolation between parses |
| Existing tests | 479 tests | All pass with no modification needed |

**Total**: 513 tests, 0 failed, 0 warnings.

## 9. IssueCode Coverage by Rule Method

| Rule Method | IssueCode |
|------------|-----------|
| `string().min(n)` | `TooSmall("string", n, true)` |
| `string().max(n)` | `TooBig("string", n, true)` |
| `string().email()` | `InvalidFormat("email")` |
| `string().url()` | `InvalidFormat("url")` |
| `string().uuid()` | `InvalidFormat("uuid")` |
| `string().cuid()` | `InvalidFormat("cuid")` |
| `string().ulid()` | `InvalidFormat("ulid")` |
| `string().datetime()` | `InvalidFormat("datetime")` |
| `string().ipv4()` | `InvalidFormat("ipv4")` |
| `string().ipv6()` | `InvalidFormat("ipv6")` |
| `string().ip()` | `InvalidFormat("ip")` |
| `string().regex(p)` | `InvalidFormat("regex")` |
| `string().nonempty()` | `TooSmall("string", 1.0, true)` |
| `number().int()` | `InvalidFormat("integer")` |
| `number().positive()` | `TooSmall("number", 0.0, false)` |
| `number().negative()` | `TooBig("number", 0.0, false)` |
| `number().multipleOf(n)` | `NotMultipleOf(n)` |
| `string().startsWith()` | `Custom` |
| `string().endsWith()` | `Custom` |
| `string().includes()` | `Custom` |
| `string().length(n)` | `Custom` |
| `number().finite()` | `Custom` |
| `number().safe()` | `Custom` |
| `refine(check, msg)` | `Custom` |
| Missing required field | `MissingRequired(name)` |
| Extra field (strict mode) | `UnrecognizedKeys([name])` |
| Union all branches fail | `InvalidUnion(messages)` |
| Invalid enum value | `InvalidValue(allowed)` |
| Literal mismatch | `InvalidValue(expected)` |
| Type mismatch (primitive) | `InvalidType(origin)` |
| Type mismatch (array) | `InvalidType("array")` |
| Type mismatch (object) | `InvalidType("object")` |
| Type mismatch (tuple) | `InvalidType("tuple")` |
| Tuple too few elements | `TooSmall("tuple", n, true)` |
| Tuple too many elements | `TooBig("tuple", n, true)` |

## 10. `ErrorMap` Usage Example

```moonbit
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
match s.safe_parse(input, params) {
  Err(errors) =>
    for e in errors {
      println(e.message)  // "缺少必填字段" or "类型错误"
      println(e.code)     // IssueCode::MissingRequired("age") or IssueCode::InvalidType("number")
    }
  _ => ()
}
```

## 11. Reviewer Feedback Addressed

| Issue | Resolution |
|-------|-----------|
| Tuple length used `InvalidUnion` | Split into `TooSmall`/`TooBig` per actual vs expected |
| Hardcoded `InvalidType` strings in array/object/tuple | Unified via `type_origin(self.schema_type)` |
| `constraint_extractor` ignored IssueCode | Added IssueCode-first pass: reads min/max/format/multipleOf from `rule.code` |
| Redundant `format_path` at every `collect_raw_errors` call site | `collect_raw_errors` now accepts `path_stack` and formats internally |
| UUID/ULID comments accidentally deleted | Restored in `string.mbt` |
| `reexporter.mbt` dropped `ConstraintInfo` | Fixed |
