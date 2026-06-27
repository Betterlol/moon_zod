# Stage Summary

## 1. Stage Description

实现 `literal()` 常数值校验并重构 `union.mbt` 拆分为独立模块文件。

**分两个任务完成**：
- **Task 1** (aa065e9): 实现 `literal()` 功能 — 新增 LiteralType 支持任意 JSON 常量校验
- **Task 2** (06c44e6): 重构 `union.mbt` — 按 "one factory per file" 约定拆分为独立模块

## 2. Stage Metadata
- STAGE_ID: phase-32
- STAGE_TYPE: feature + refactor
- BASE_COMMITS:
  - Task 1: aa065e9
  - Task 2: 06c44e6

## 3. Task 1: literal() 实现

### 背景

现有 `enum_values()` 只支持字符串枚举，不支持 number/boolean 等其他类型的常量。LLM Tool Calling 场景常需要校验字面量值（如 `"active"`、`42`、`true`）。

### 新增文件

| 文件 | 用途 |
|---|---|
| `literal.mbt` | `literal()` 工厂函数 + `parse_literal()` + `json_to_literal_string()` 辅助 |

### 修改文件

| 文件 | 变更 |
|---|---|
| `schema.mbt` | `SchemaType` 新增 `LiteralType(Json)` 变体；`parse_inner`/`expected_msg`/`inner_type` 添加 LiteralType 分支 |
| `union.mbt` | 新增 `literal()` 工厂函数 + `parse_literal()` 辅助函数 + `json_to_literal_string()` |
| `json_schema.mbt` | LiteralType 导出为 `{"const": value}` |
| `prompt.mbt` | 新增 `json_to_ts_literal()` 函数，LiteralType 渲染为 TypeScript 字面量（如 `"hello"`、`42`、`true`） |
| `moonbit_struct.mbt` | 新增 `literal_to_moonbit_type()` 和 `json_to_literal_code()`，LiteralType 映射到底层 MoonBit 类型并生成正确的 from_json match pattern |
| `test_combinators.mbt` | 新增 14 个测试覆盖 string/number/boolean/null literal |

### API 设计

```moonbit
/// 创建校验精确 JSON 值的 Schema
pub fn literal(
  value : Json,  // 支持 String/Number/Boolean/Null/Array/Object
  required_error? : String = "",
  invalid_type_error? : String = "",
) -> Schema
```

### 使用示例

```moonbit
// 字符串字面量
let s = @moon_zod.literal(Json::string("active"))
s.parse(Json::string("active")) // Ok
s.parse(Json::string("inactive")) // Err

// 数字字面量
let n = @moon_zod.literal(Json::number(42.0))
n.parse(Json::number(42.0)) // Ok
n.parse(Json::number(100.0)) // Err

// 布尔字面量
let b = @moon_zod.literal(Json::boolean(true))
b.parse(Json::boolean(true)) // Ok
b.parse(Json::boolean(false)) // Err

// 自定义错误消息
let s2 = @moon_zod.literal(Json::string("hello"), invalid_type_error="must be hello")
```

### JSON Schema 导出

```json
{ "const": "active" }
{ "const": 42 }
{ "const": true }
```

### TypeScript Prompt 导出

```typescript
"active" | 42 | true
```

## 4. Task 2: union.mbt 重构

### 背景

`union.mbt` 历史上积累了多个不相关的工厂函数，违反了项目 "one factory per file" 约定。需要拆分使结构更清晰。

### 拆分方案

| 原文件 | 新文件 | 包含内容 |
|---|---|---|
| `union.mbt` | `union.mbt` (改写) | `union()` + `parse_union()` |
| - | `optional.mbt` (新建) | `Schema::optional()` + `parse_optional()` |
| - | `default.mbt` (新建) | `Schema::default()` + `parse_default()` |
| - | `enum.mbt` (新建) | `enum_values()` + `parse_enum()` |
| - | `literal.mbt` (新建) | `literal()` + `parse_literal()` + `json_to_literal_string()` |

### 统计

| 文件 | 行数变化 |
|---|---|
| `union.mbt` | 217行 → 42行 (-81%) |
| `optional.mbt` | 新增 32行 |
| `default.mbt` | 新增 32行 |
| `enum.mbt` | 新增 49行 |
| `literal.mbt` | 新增 92行 |

## 5. 测试结果

- `moon build`: 0 errors
- `moon test`: 381/381 通过 (新增 14 个 literal 测试)

## 6. 后续展望

- 可考虑将 `enum.mbt` 重命名为 `enum_values.mbt` 以更清晰表达其用途
- `literal()` 可与 `union()` 组合实现带类型的枚举，如 `union([literal(Json::string("a")), literal(Json::string("b"))])`