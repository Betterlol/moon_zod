# Phase 27 — JSON Schema → moon_zod 反向生成 (`json_schema_to_moon_zod()`)

**目标**: 实现 `json_schema_to_moon_zod()` — 将标准 JSON Schema (draft-07) 文档转换为 moon_zod Schema 表达式源码。

## 设计决策

### 核心定位

- **JSON Schema → moon_zod 源码**（不是运行时 Schema 对象）
- 输出是可直接 copy-paste 的 MoonBit 代码字符串
- 与 Phase 10 `cmd/json2schema` 互补（输入 JSON 值 vs 输入 JSON Schema 规范）

### 支持的 JSON Schema 特性

| 特性 | 映射到 |
|---|---|
| `type: "string"` | `@moon_zod.string()` |
| `type: "number"` | `@moon_zod.number()` |
| `type: "integer"` | `@moon_zod.number().int()` |
| `type: "boolean"` | `@moon_zod.boolean()` |
| `type: "null"` | `@moon_zod.null()` |
| `type: "object"` + `properties` | `@moon_zod.object({...})` |
| `type: "array"` + `items` | `@moon_zod.array(...)` |
| `enum: [...]` | `@moon_zod.enum_values([...])` |
| `$ref: "#/$defs/Name"` | 变量引用 `Name_schema` |
| `$defs` / `definitions` | `let Name_schema = ... .name("Name")` |
| `anyOf: [...]` | `@moon_zod.union([...])` |
| `allOf: [...]` | `@moon_zod.intersection([...])` |
| `oneOf: [...]` | `@moon_zod.union([...])`（近似） |
| `minLength` / `maxLength` | `.min(n)` / `.max(n)` |
| `minimum` / `maximum` | `.min(n)` / `.max(n)` |
| `exclusiveMinimum: 0` | `.positive()` |
| `exclusiveMaximum: 0` | `.negative()` |
| `multipleOf: n` | `.multipleOf(n)` |
| `pattern: "..."` | `.regex("...")` |
| `format: "email"/"uri"/"date-time"/"ipv4"/"ipv6"/"uuid"` | `.email()` / `.url()` / `.datetime()` / `.ipv4()` / `.ipv6()` / `.uuid()` |
| `minItems` / `maxItems` | `.min(n)` / `.max(n)`（数组） |
| `required` | 字段在 `required` 中 → 必填；不在 → `.optional()` |

### 算法架构

1. **`json_schema_to_moon_zod(schema)`** — 入口：提取 `$defs`/`definitions`，生成 `let Name_schema = ...` 声明 + 根代码
2. **`schema_to_code(schema, defs, indent)`** — 递归解析节点，按优先级匹配 `$ref` > `enum` > `type` > `anyOf`/`allOf`/`oneOf`
3. **`object_to_code(props, required, defs, indent)`** — 对象字段生成，检查字段是否在 `required` 中
4. **`apply_constraints_to_code(base, m)`** — 附加约束链式调用 (min/max/regex/format/positive/negative/multipleOf)
5. **`ref_to_code(ref_str, defs)`** — 解析 `$ref` URI 并映射到变量名

### CLI 集成

`cmd/json2schema` 新增 `--from-json-schema` 标志：
```
moon run cmd/json2schema -- --from-json-schema '{"type":"string","minLength":3}'
```

## 文件变更

| 文件 | 操作 | 说明 |
|---|---|---|
| `from_json_schema.mbt` | 新增 | ~284 行，核心实现：1 公共函数 + 11 内部 helper |
| `test_json_schema.mbt` | 修改 | 25 个新测试覆盖所有类型和约束 |
| `cmd/json2schema/main.mbt` | 修改 | 新增 `--from-json-schema` 标志 + 帮助文档 |
| `cmd/json2schema/moon.pkg` | 修改 | 添加 `"Betterlol/moon_zod"` 依赖 |

## 测试覆盖

| 测试名 | 覆盖场景 |
|---|---|
| basic string/number/integer/boolean/null | 基础类型 |
| object with properties | 对象 + 必填/可选字段 |
| array type | 数组 + items |
| enum type | 枚举 |
| string/number with constraints | minLength, maxLength, minimum, maximum |
| email/uri format | format 映射 |
| anyOf/allOf | 组合类型 |
| oneOf | 近似 union |
| $defs with $ref | 命名定义 + 引用 |
| object field with $ref | 对象字段中的引用 |
| pattern constraint | regex |
| array with minItems | 数组约束 |
| exclusiveMinimum/Maximum | positive/negative |
| multipleOf | 倍数约束 |
| nested object | 多层嵌套 |
| empty object | 边界情况 |
| definitions alias | `definitions` 兼容名 |

**产出**: 316/316 测试全部通过 0 警告。
