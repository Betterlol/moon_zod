# Stage Summary

## 1. Stage Description

增强验证器 + 类型级错误消息 (v0.5.0): 修复 IPv6 `::` 组计数 bug、增强 email/url 校验深度、引入类型级错误消息。

## 2. Stage Metadata
- STAGE_ID: phase-24
- STAGE_TYPE: feature+bugfix
- BASE_COMMIT: 68581beba3a67aaa4c0a76bc51b543a8068a1c17

## 3. New Files
None

## 5. Modified Files

| File | Action | Description |
|---|---|---|
| `schema.mbt` | modify | Schema 新增 required_error/invalid_type_error 字段；parse_inner 类型错误使用自定义消息 |
| `string.mbt` | modify | IPv6 修复；email 重写；url 重写；工厂新增错误参数 |
| `number.mbt` | modify | 工厂新增错误参数 |
| `boolean.mbt` | modify | 工厂新增错误参数 |
| `null.mbt` | modify | 工厂新增错误参数 |
| `object.mbt` | modify | 工厂新增错误参数；parse_object 缺失字段使用 required_error |
| `array.mbt` | modify | 工厂新增错误参数；parse_array 类型错误使用自定义消息 |
| `union.mbt` | modify | optional/default 传播错误参数；enum_values/union 工厂新增错误参数 |
| `intersection.mbt` | modify | 工厂新增错误参数 |
| `transform.mbt` | modify | transform 传播错误参数 |
| `test_string.mbt` | modify | 25 个新测试（IPv6 边缘、email/url 增强） |
| `test_errors.mbt` | modify | 8 个类型级错误消息测试 |

## 8. ACTION_LOG

| Action | File | Reason |
|---|---|---|
| modify | `schema.mbt` | Schema struct +2 fields; type_error_msg helper; parse_inner type path |
| modify | `string.mbt` | Fix IPv6 :: bug; rewrite is_valid_email (quoted/IP literal/+tag); rewrite is_valid_url (full structure) |
| modify | `number/boolean/null/array/object` | Add required_error?/invalid_type_error? params |
| modify | `union.mbt` | optional/default propagate; enum_values/union add params |
| modify | `intersection.mbt` | Add params |
| modify | `transform.mbt` | Propagate error fields |
| modify | `test_string.mbt` | 25 new tests |
| modify | `test_errors.mbt` | 8 type-level error tests |

## 9. Risks / Notes

- **IPv6 fix**: `::` formerly counted as 2 colons, rejecting `::1:2:3:4:5:6:7` etc. Fixed by skipping second `:` with `i = i + 2` in while loops
- **Email**: New `find_unquoted_at` skips quoted content; supports `"abc@def"@example.com`, `user@[IPv6:...]`, `user+tag@...`, TLD >= 2 chars
- **URL**: Full URL structure parse (scheme://host[:port][/path][?query][#fragment]), supports domain/IPv4/localhost hosts, port validation
- **Type errors**: `Schema{required_error, invalid_type_error}` fields, propagated through all wrapper types
- **Tests**: 251 → 276 (25 new), 0 failures
