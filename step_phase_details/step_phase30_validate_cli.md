# Phase 30 — Validate CLI 工具

**目标**: 提供零代码使用 moon_zod 库的能力，无需编写 MoonBit 代码即可校验 JSON 数据。

**Commit**: `bf9353b`

---

## 背景

Phase 28-29 完成了 Schema → MoonBit struct 代码生成，但用户仍需编写 MoonBit 代码才能使用 `schema.parse()` 进行校验。Validate CLI 让非 MoonBit 用户、CI/CD 流程、脚本场景都能直接受益于 moon_zod 的校验能力。

---

## 设计决策

### 1. Infer 模式（默认）

给定一个 sample JSON，CLI 自动推断其 schema，然后校验目标 JSON：

```
moon run cmd/validate -- '<sample.json>' '<data.json>'
```

```bash
# 推断 schema: { name: string, age: number.int }
# 校验 data.json 是否符合该 schema
moon run cmd/validate -- '{"name":"Alice","age":30}' '{"name":"Bob","age":25}'
# PASS

moon run cmd/validate -- '{"name":"Alice","age":30}' '{"age":25}'
# FAIL
#   [name] Required (got: Null)
```

### 2. JSON Lines 批量校验

数据文件含换行符时自动切换为 JSON Lines 模式，逐行校验并汇总：

```
moon run cmd/validate -- '<sample.json>' '<data.jsonl>'
```

```bash
$ moon run cmd/validate -- '{"name":"Alice"}' '{"name":"Bob"}
{"name":"Eve"}
{"age":30}'
FAIL: line 3
  [name] Required (got: Null)
Results: 2 passed, 1 failed
```

### 3. 错误输出格式

每个错误显示三要素：
- **path**: 字段路径（支持嵌套如 `address.city`）
- **message**: 人类可读消息（"Required"、"Expected number" 等）
- **got**: 实际收到的 JSON 值（Debug 格式）

### 4. 推断逻辑

从 sample JSON 推断 schema 的规则与 `cmd/gen-struct` 保持一致：

| JSON 类型 | 推断规则 |
|---|---|
| `"string"` | `@moon_zod.string()` |
| `42` (整数) | `@moon_zod.number().int()` |
| `3.14` (浮点) | `@moon_zod.number()` |
| `true/false` | `@moon_zod.boolean()` |
| `null` | `@moon_zod.null()` |
| `["a", "b"]` | `@moon_zod.array(string())` |
| `{"name": "x"}` | `@moon_zod.object({ "name": string() }).name("InferredSchema")` |

嵌套对象递归推断，数组取首个元素推断元素类型（空数组默认 `string()`）。

---

## 文件变更

| 文件 | 变更 |
|---|---|
| `cmd/validate/moon.pkg` | 新增包声明，`is-main: true` |
| `cmd/validate/main.mbt` | 新增核心实现 (~280 行) |

**核心函数**:

- `json_to_schema(json, name_hint) -> Schema` — JSON → moon_zod Schema 推断
- `validate_single(schema, data_raw)` — 单文件校验
- `validate_jsonl(schema, data_raw)` — JSON Lines 批量校验
- `auto_struct_name(key) -> String` — JSON key → PascalCase struct 字段名

---

## 关键实现细节

### 1. JSON 解析错误处理

`@json.parse()` 在 `fn main` 中通过 `catch { _ => { ... return } }` 处理：

```moonbit
let sample_json = @json.parse(sample_raw) catch {
  _ => {
    println("Error: invalid JSON in sample")
    return
  }
}
```

### 2. JSON Lines 检测

通过字符串是否含 `\n` 判断模式：

```moonbit
let is_jsonl = data_raw.contains("\n")
if is_jsonl {
  validate_jsonl(schema, data_raw)
} else {
  validate_single(schema, data_raw)
}
```

### 3. JSON Lines 校验中的 parse 失败处理

`@json.parse()` 失败时返回 `Json::null()` 作为哨兵值，校验时通过 `Null` 类型检测跳过：

```moonbit
let data_json = @json.parse(trimmed) catch {
  _ => {
    println("FAIL: line \{line_num} - invalid JSON")
    fail_count = fail_count + 1
    Json::null()
  }
}
// Skip if JSON parse failed (caught above)
if data_json is Null && fail_count > 0 {
  continue
}
```

---

## 测试结果

```
moon build  ✓ 0 errors 0 warnings
moon test   ✓ 360 tests passed
moon info   ✓ up to date
moon fmt    ✓ no changes
```

**手动测试**:

```bash
# 通过
moon run cmd/validate -- '{"name":"Alice"}' '{"name":"Bob"}'
# PASS

# 失败（缺少必填字段）
moon run cmd/validate -- '{"name":"Alice"}' '{"age":30}'
# FAIL
#   [name] Required (got: Null)

# 类型不匹配
moon run cmd/validate -- '{"name":"Alice","age":30}' '{"name":"Bob","age":"not-a-number"}'
# FAIL
#   [age] Expected number (got: String("not-a-number"))
```

---

## 未来扩展方向

1. **Schema 文件模式**: `moon run cmd/validate -- <schema.mbt> <data.json>` — 直接读取 moon_zod schema 文件
2. **内联 Schema 模式**: `--inline-schema '{"type":"string"}'` — 传入 JSON Schema 而非推断
3. **退出码**: 当前恒为 0，计划：0=全部通过，1=有错误，2=参数错误
4. **结构化输出**: `--json` 输出机器可读格式
5. **详细模式**: `-v` 显示推断出的 schema

---

## 价值

- **零代码使用**: 无需编写 MoonBit 代码，CLI 直接使用
- **CI 友好**: 退出码 + 错误报告，无外部依赖
- **快速验证**: JSON Schema 推断 + 校验一体化，适合数据质量检查流水线