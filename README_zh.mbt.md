# moon_zod

> 🌐 [English README](./README.mbt.md)

MoonBit 运行时 JSON Schema 校验库，受 [Zod](https://zod.dev) 和 [Pydantic](https://docs.pydantic.dev) 启发。

**专为 LLM Tool Calling 设计** — 对大语言模型的结构化 JSON 输出进行运行时校验，提供精确的错误报告与自修正支持。

---

# ✨ 为什么选择 MoonZod？（AI 优先）

| 特性 | moon_zod | 典型验证库 |
|---|---|---|
| **错误收集** | 一次遍历收集**所有**错误 | 大多数库在第一个错误时快速失败 |
| **幻觉防御** | 默认 **Strip 模式**静默移除未知字段 | 会传递幻觉数据 |
| **命名 Schema 导出** | `schema_to_prompt_named()` 生成模块化 TypeScript 接口，带类型名称引用 | 内联展开 + 重复 |
| **JSON Schema 导出** | `to_json_schema()` 为 LLM API 生成标准 Schema | 手动维护 Schema |
| **路径精度** | 每个错误都包含精确字段路径（`users[0].profile.age`） | 通常只是平面消息 |
| **Wasm 就绪** | 可变路径栈 — 成功路径上零堆分配 | 每次解析都有大量字符串分配 |

在 LLM 工具调用中，模型通常**一次产生多个错误**并**幻觉额外字段**。moon_zod 在单次遍历中收集每个错误（这样你可以全部发回给 LLM 进行自我纠正），并默认移除未知字段（不会因幻觉键而发生无声数据损坏）。

---

## 🚀 快速开始

```mbt nocheck
let schema = @moon_zod.object({
  "name": @moon_zod.string().min(2).max(50),
  "age": @moon_zod.number().int().min(0).max(150),
  "email": @moon_zod.string().email(),
})

match schema.parse(input_json) {
  Ok(valid) => // use valid
  Err(errors) => // report all errors back to LLM
}
```

**零代码 CLI 验证：**
```bash
# 从样本推断 Schema，验证数据
moon run cmd/validate -- '{"name":"Alice","age":30}' '{"name":"Bob","age":25}'
# PASS

# 使用 JSON Lines 批量验证
moon run cmd/validate -- '{"name":"Alice"}' '{"name":"Bob"}\n{"name":"Eve"}'
# 结果：2 通过，0 失败
```

---

## 项目结构

```
moon_zod/
├── core/                     # 核心 Schema 验证库
│   ├── types.mbt             # ValidationError、SchemaResult、核心类型
│   ├── schema.mbt            # Schema 结构体、解析分发、路径栈
│   ├── string.mbt            # string() 工厂 + 验证器
│   ├── number.mbt            # number() 工厂 + 验证器
│   ├── boolean.mbt           # boolean() 工厂
│   ├── null.mbt              # null() 工厂
│   ├── array.mbt             # array() 工厂 + parse_array
│   ├── object.mbt            # object() + 模式（strip/passthrough/strict），pick/omit/partial
│   ├── optional.mbt          # optional() 工厂
│   ├── default.mbt           # default() 工厂
│   ├── enum.mbt              # enum_values() 工厂
│   ├── literal.mbt           # literal() 工厂（常量值）
│   ├── union.mbt             # union() 工厂
│   ├── intersection.mbt      # intersection() / intersect()
│   ├── refine.mbt            # refine() 自定义验证
│   ├── transform.mbt         # transform() 数据转换
│   ├── shared_utils.mbt      # 共享工具（unwrap_schema、peel_optional 等）
│   ├── constraint_extractor.mbt  # 从规则提取约束信息
│   └── moon_zod_wbtest.mbt   # 白盒测试（路径栈不变量）
│
├── exporters/                # 代码/Schema 导出工具
│   ├── prompt.mbt            # schema_to_prompt() / schema_to_prompt_named()
│   ├── prompt_renderer.mbt   # 基于 Trait 的提示渲染
│   ├── json_schema.mbt       # to_json_schema() / to_json_schema_named()
│   ├── json_schema_renderer.mbt # 基于 Trait 的 JSON Schema 渲染
│   ├── moonbit_struct.mbt    # schema_to_moonbit_struct() + from_json() 生成
│   ├── moonbit_renderer.mbt  # 基于 Trait 的 MoonBit 结构渲染
│   ├── schema_exporter.mbt   # 共享导出工具
│   └── reexporter.mbt        # 模块重新导出
│
├── importers/                # Schema 导入工具
│   ├── from_json_schema.mbt  # json_schema_to_moon_zod() — 反向 JSON Schema → moon_zod 代码生成
│   └── reexporter.mbt        # 模块重新导出
│
├── tests/                    # 测试套件（407 个测试）
│   ├── test_string.mbt       # string() 验证器测试
│   ├── test_number.mbt       # number() 验证器测试
│   ├── test_boolean_null.mbt # boolean/null 测试
│   ├── test_object.mbt       # object() 模式测试
│   ├── test_array.mbt        # array() 测试
│   ├── test_combinators.mbt  # union/literal/optional/default 测试
│   ├── test_transform_refine.mbt # transform/refine 测试
│   ├── test_json_schema.mbt  # JSON Schema 导出测试
│   ├── test_moonbit_struct.mbt # MoonBit 结构生成测试
│   ├── test_prompt.mbt       # 提示生成测试
│   ├── test_prompt_named.mbt # 命名 Schema 导出测试
│   ├── test_custom_message.mbt # 自定义错误消息测试
│   ├── test_errors.mbt       # 错误收集测试
│   ├── test_schema_to_code.mbt # 代码生成测试
│   └── reexporter.mbt        # 测试重新导出
│
├── cmd/                      # CLI 工具
│   ├── main/                 # 基准测试运行器（性能基线）
│   ├── wasm/                 # WebAssembly 跨语言基准测试
│   ├── json2schema/          # JSON → moon_zod Schema 代码生成器 + JSON Schema 反向导入器
│   ├── gen-struct/           # JSON → MoonBit 结构 + from_json() 生成器
│   └── validate/             # JSON Schema 验证器（推断然后验证）
│
└── examples/                 # LLM 代理演示
    ├── llm_agent/            # 基础 LLM 工具调用示例
    ├── educational_agent/    # 多轮自纠正演示
    ├── real_llm_agent/       # 真实 LLM 集成（带 API 回退到 mock）
    ├── multiple_schemas/     # 处理多个 Schema
    └── schema2prompt/        # Schema → 提示生成展示
```

---

## 开发

```bash
# 测试与构建
moon test                # 运行所有测试（共 407 个，0 个警告）
moon build               # 构建库
moon info && moon fmt    # 更新接口 + 格式化

# CLI 工具
moon run cmd/main                                      # 运行性能基准测试
moon run cmd/json2schema -- '{"hello":"world"}'      # JSON → moon_zod Schema 代码
moon run cmd/json2schema -- --from-json-schema '<{...}>'  # JSON Schema → moon_zod 代码
moon run cmd/gen-struct -- '{"name":"Alice"}'        # JSON → MoonBit 结构 + from_json()
moon run cmd/validate -- '{"name":"Alice"}' '{"name":"Bob"}'  # 验证 JSON

# 示例
moon run examples/llm_agent                          # 基础 LLM 工具调用演示
moon run examples/real_llm_agent -- product prompt   # 真实 LLM（带 mock 回退）
moon run examples/real_llm_agent -- product validate # 用真实 API 验证
moon run examples/multiple_schemas                    # 处理多个 Schema
```

---

## 特性

- **基础类型 Schema**：`string()`、`number()`、`boolean()`、`null()`
- **复合 Schema**：`object(Map)`、`array(Schema)`、`union(Array[Schema])`、`intersection(Array[Schema])`、`enum_values(Array[String])`、`literal(Json)`
- **字符串验证器**（20+）：`.min(n)`、`.max(n)`、`.nonempty()`、`.email()`（完整 RFC 验证）、`.url()`（完整结构）、`.regex(pattern)`（子字符串匹配）、`.startsWith()`、`.endsWith()`、`.includes()`、`.uuid()`、`.cuid()`、`.ulid()`、`.datetime()`、`.ip()`/`.ipv4()`/`.ipv6()`、`.length(n)`
- **数字验证器**（9+）：`.int()`、`.positive()`、`.negative()`、`.multipleOf()`、`.finite()`、`.safe()`、`.min()`、`.max()`、`.length()`
- **对象模式**：`.strip()`（默认，移除未知字段）、`.passthrough()`（保留未知字段）、`.strict()`（拒绝未知字段）
- **Schema 组合**：`.pick(keys)`、`.omit(keys)`、`.partial()` 派生对象子 Schema
- **可选/默认值处理**：`.optional()` 和 `.default(value)`，通过包装器正确链接规则
- **数据转换**：`.transform(fn)` 验证然后转换
- **自定义规则**：`.refine(check, message)`、`.intersect(other)` 显式交集
- **Schema 命名与描述**：`.name(text)` 用于命名导出，`.describe(text)` 用于提示中的人类可读描述
- **自定义错误消息**：所有验证器上的 `msg?` 参数、`.message(text)` 覆盖方法、类型级 `.string(invalid_type_error="...", required_error="...")`
- **错误收集**：一次遍历收集**所有**验证错误，非常适合 LLM 自纠正循环
- **全路径错误报告**：每个错误都包含精确字段路径（`users[0].profile.age`）
- **LLM 提示生成**：
  - `schema_to_prompt(schema)` — 内联 TypeScript-interface 加约束注释
  - `schema_to_prompt_named(schema, include_names?)` — 模块化接口、拓扑排序和类型名称引用
- **JSON Schema 导出**：
  - `to_json_schema(schema)` — 标准 JSON Schema 加完整约束注解
  - `to_json_schema_skeleton(schema)` — 轻量级骨架（仅结构）
  - `to_json_schema_named(schema, include_names?)` — 分离的 `$defs` 和 `$ref` 引用
- **JSON Schema 反向导入**：
  - `json_schema_to_moon_zod(json_schema)` — 从标准 JSON Schema 生成 moon_zod 源代码
  - 完整支持 `$defs`、`$ref`、约束、格式验证、枚举
- **MoonBit 结构生成**（Phase 28-29）：
  - `schema_to_moonbit_struct(schema)` — 生成 MoonBit 结构定义
  - `schema_to_moonbit_struct_full(schema)` — 生成结构 + `from_json()` 函数
  - `schema_to_moonbit_struct_named(schema)` / `schema_to_moonbit_struct_named_full(schema)` — 处理嵌套命名 Schema
- **零外部依赖**：仅 MoonBit 核心库（`@json`、`@debug` 等）
- **WebAssembly 就绪**：可变路径栈在成功路径上零堆分配
- **性能**：根据 Schema 复杂度，每秒约 18.5k-56k 次验证


## API 参考

### 工厂函数

| 函数 | 描述 |
|---|---|---|
| `string(required_error?, invalid_type_error?)` | 校验 JSON 字符串 |
| `number(required_error?, invalid_type_error?)` | 校验 JSON 数字 |
| `boolean(required_error?, invalid_type_error?)` | 校验 JSON 布尔值 |
| `null(required_error?, invalid_type_error?)` | 校验 JSON null |
| `array(Schema, required_error?, invalid_type_error?)` | 校验数组，递归检查元素 |
| `object(Map[String, Schema], required_error?, invalid_type_error?)` | 校验对象。**默认：Strip 模式** |
| `enum_values(Array[String], required_error?, invalid_type_error?)` | 固定的允许字符串值集合 |
| `literal(Json, required_error?, invalid_type_error?)` | **新增**：常量值校验 — 仅接受精确的 JSON 匹配（字符串、数字、布尔值、null、数组或对象） |
| `union(Array[Schema], required_error?, invalid_type_error?)` | 联合类型 — 如果任何 schema 匹配则通过 |
| `intersection(Array[Schema], required_error?, invalid_type_error?)` | 交集 — 如果所有 schema 都匹配则通过；对象字段被合并 |

### Schema 方法

| 方法 | 适用于 | 描述 |
|---|---|---|
| `.parse(Json, path?)` | 全部 | 校验，返回 `Ok(Json)` 或 `Err(Array[ValidationError])` |
| `.min(n[, msg])` | string / number / array | 最小长度 / 值 |
| `.max(n[, msg])` | string / number / array | 最大长度 / 值 |
| `.nonempty([msg])` | string | 字符串不能为空 |
| `.email([msg])` | string | 完整邮箱校验（引号本地部分、IP 字面量、+tag、TLD≥2、单个 @） |
| `.url([msg])` | string | 完整 URL 结构：`scheme://host[:port][/path][?query][#fragment]` |
| `.regex(pattern[, msg])` | string | 必须包含 `pattern` 作为子字符串 |
| `.startsWith(prefix[, msg])` | string | 必须以 `prefix` 开头 |
| `.endsWith(suffix[, msg])` | string | 必须以 `suffix` 结尾 |
| `.includes(substring[, msg])` | string | 必须包含 `substring` |
| `.uuid([msg])` | string | 必须是有效的 UUID v4 |
| `.cuid([msg])` | string | 必须是有效的 CUID（c + base36 哈希） |
| `.datetime([msg])` | string | 必须是 ISO 8601 日期时间（date + T + time ± offset/Z） |
| `.ip([msg])` | string | 必须是有效的 IPv4 或 IPv6 地址 |
| `.ipv4([msg])` | string | 必须是有效的 IPv4 地址 |
| `.ipv6([msg])` | string | 必须是有效的 IPv6 地址（完整/简写形式，支持 ::） |
| `.ulid([msg])` | string | 必须是有效的 ULID（26 字符 Crockford base32） |
| `.int([msg])` | number | 必须是整数（无小数部分） |
| `.positive([msg])` | number | 必须 > 0 |
| `.negative([msg])` | number | 必须 < 0 |
| `.multipleOf(n[, msg])` | number | 必须是 `n` 的倍数 |
| `.length(n[, msg])` | string / array | 必须恰好有 `n` 的长度 |
| `.finite([msg])` | number | 必须是有限数（不是 NaN，不是 ±Infinity） |
| `.safe([msg])` | number | 必须是安全整数（不是 NaN，不是 ±Infinity，无小数部分） |
| `.optional()` | 任意 | null 或缺失值跳过校验 |
| `.default(value)` | 任意 | 用默认值替换 null |
| `.strict()` | object | 拒绝未定义的字段 |
| `.passthrough()` | object | 保持未定义的字段不变 |
| `.strip()` | object | 无声地移除未定义的字段（默认） |
| `.describe(text)` | 任意 | 附加描述，由 `schema_to_prompt()` 为 LLM 提示渲染 |
| `.message(text)` | 任意 | 覆盖最后一条规则的错误消息 |
| `.intersect(other)` | 任意 | 交集：输入必须匹配两个 schema；对象字段被合并 |
| `.pick(keys)` | object | 仅选择指定字段 |
| `.omit(keys)` | object | 移除指定字段 |
| `.partial()` | object | 使所有字段可选 |
| `.refine(check, msg)` | 任意 | 自定义校验谓词 |
| `.transform(fn)` | 任意 | 校验然后通过 `(Json) -> Result[Json, String]` 转换输出 |

### 独立函数

| 函数 | 描述 |
|---|---|
| `schema_to_prompt(Schema)` | 为 LLM 生成 TypeScript 接口提示字符串（含约束注释） — 内联展开 |
| `schema_to_prompt_named(Schema, include_names?)` | 从命名 schema 生成模块化 TypeScript 接口，含拓扑排序和类型名称引用 — 用于复杂、嵌套的 LLM 工具 schema |
| `to_json_schema(Schema)` | 导出标准 JSON Schema 对象，含完整约束注解 |
| `to_json_schema_skeleton(Schema)` | 导出轻量级 JSON Schema 骨架（仅结构，无约束） |
| `to_json_schema_named(Schema, include_names?)` | 导出命名 schema 为独立的 JSON Schema 定义，含 `$defs` 和 `$ref` 引用 |
| `json_schema_to_moon_zod(Json)` | **新增**：反向生成 moon_zod Schema 源代码；完整支持 `$defs`、`$ref`、约束、格式验证 |
| `schema_to_moonbit_struct(Schema)` | 从 ObjectType/EnumType 生成 MoonBit 结构体定义（类型名、字段、约束） |
| `schema_to_moonbit_struct_full(Schema)` | 生成结构体定义 + `from_json()` 函数用于类型安全的 JSON → 结构体转换 |
| `schema_to_moonbit_struct_named(Schema, include_names?)` | 同 `schema_to_moonbit_struct()`，但提取并拓扑排序所有嵌套命名 schema |
| `schema_to_moonbit_struct_named_full(Schema, include_names?)` | 同 `schema_to_moonbit_struct_full()`，但提取所有嵌套命名 schema |
| `format_path(Array[String])` | 将路径栈连接为点号记号字符串 |
| `ValidationError::to_string()` | 将错误格式化为 `[path] message (got: value)` |

### 核心类型

```mbt nocheck
///|
pub struct ValidationError {
  path : String
  message : String
  got : Json
}

///|
pub type SchemaResult = Result[Json, Array[ValidationError]]

///|
pub enum ObjectMode {
  Passthrough
  Strict
  Strip
}

### JSON-to-Schema 生成器 (CLI)

从任何 JSON 负载中即时生成 `@moon_zod` schema 代码 — 无需为真实世界的 API 数据手工编写 schema。

```bash
moon run cmd/json2schema -- '{"hello": "world"}'
```

输出：

```
── Input JSON ──
Object({hello: String(world)})

── Generated moon_zod Schema (copy-paste ready) ──
@moon_zod.object({
  "hello": @moon_zod.string(),
})

── End ──
```

该生成器递归推断类型（`string`、`number`、`boolean`、`null`、`array`、`object`），并安全转义对象键中的特殊字符。空数组会生成 `/* TODO: specify exact type */` 注释，以便在类型推断缺乏数据时提醒你。

---

### JSON Schema 反向导入器 (CLI)

从标准 **JSON Schema (draft-07)** 定义生成 `@moon_zod` schema 代码 — `to_json_schema()` 的逆操作。

```bash
moon run cmd/json2schema -- --from-json-schema '{
  "type": "object",
  "properties": {
    "name": {"type": "string", "minLength": 2},
    "age": {"type": "integer", "minimum": 0, "maximum": 150}
  },
  "required": ["name", "age"]
}'
```

输出：

```moonbit nocheck
@moon_zod.object({
  "name": @moon_zod.string().min(2),
  "age": @moon_zod.number().int().min(0).max(150),
})
```

**特性**：
- 转换所有 JSON Schema 类型（string、number、integer、boolean、null、array、object）
- 提取约束：`minLength`、`maxLength`、`minimum`、`maximum`、`multipleOf`、`pattern`、`format`（email、uri、date-time、ipv4、ipv6、uuid）
- 处理 `$defs` 和 `$ref` 引用 — 生成单独的命名 schema 声明
- 支持 `enum` 和 `oneOf` / `anyOf` / `allOf`
- 不在 `required` 中的字段自动用 `.optional()` 包装
- 输出 **可直接复制粘贴的 MoonBit 源代码**

---

### MoonBit 结构体生成器 (CLI)

从任何 JSON 示例生成 MoonBit 结构体定义 — 包括结构体定义和 `from_json()` 函数，用于类型安全转换。

```bash
moon run cmd/gen-struct -- '{"name":"Alice","age":30}'
```

输出：

```moonbit nocheck
pub struct InferredSchema {
  name : String
  age : Int64
}

pub fn inferred_schema_from_json(json : Json) -> Result[InferredSchema, Array[ValidationError]] {
  match json {
    Object(map) => {
      let name = match map.get("name") {
        Some(String(s)) => s
        Some(got) => return Err([ValidationError::{ path: "name", message: "expected string", got }])
        None => return Err([ValidationError::{ path: "name", message: "required", got: Null }])
      }
      let age = match map.get("age") {
        Some(Number(v, ..)) => v.to_int()
        Some(got) => return Err([ValidationError::{ path: "age", message: "expected integer", got }])
        None => return Err([ValidationError::{ path: "age", message: "required", got: Null }])
      }
      Ok({ name:, age: })
    }
    _ => Err([ValidationError::{ path: "", message: "expected object", got: json }])
  }
}
```

支持嵌套对象、数组和可选字段。嵌套对象会自动命名并导出为单独的结构体定义。

---

### JSON 验证器 (CLI)

根据从示例推断的 schema 验证 JSON 数据 — 无需代码。支持 JSON Lines 进行批量验证。

```bash
# 单个 JSON 验证
moon run cmd/validate -- '{"name":"Alice","age":30}' '{"name":"Bob","age":25}'
# PASS

# 使用 JSON Lines 进行批量验证
moon run cmd/validate -- '{"name":"Alice"}' '{"name":"Bob"}\n{"name":"Eve"}\n{"age":30}'
# FAIL: line 3
#   [name] Required (got: Null)
# Results: 2 passed, 1 failed
```

**错误输出格式**：`[field_path] message (got: value)`


## ⚡ 性能

moon_zod 的**可变路径栈**（第 5 阶段）将路径字符串构造延迟到实际发生错误时。在验证成功路径上——这是格式良好的 LLM 输出的常见情况——路径跟踪**零堆分配**。

这对于 **Wasm 边缘运行时**尤其重要，因为垃圾回收暂停和内存压力直接影响请求延迟。

### 跨语言基准测试（100k 次迭代）

| 验证器 | 运行时 | 吞吐量 |
|---|---|---|
| **TS Zod** | In-process V8 | 243,178 ops/sec |
| **MoonZod** | Native (@bench) | **3,815,556 ops/sec** |

> 两个验证器都以进程内方式运行，无子进程开销。MoonZod 使用 MoonBit 的 `@bench` 库进行校准的迭代计数（ns/op → ops/sec）；TS Zod 在 100k 次手动 `parse()` 调用上使用挂钟计时。在此基准测试中，MoonZod 比 TS Zod 快约 15 倍，展示了专注、零分配验证路径（第 5 阶段可变路径栈）的优势。

运行基准测试：
```
moon run cmd/main                  # MoonZod 吞吐量（3 个基准测试）
cd bench_cross_lang && node bench.js  # 跨语言对比

# 演示：Schema → `schema_to_prompt()` → LLM → `schema.parse()`

**完整的 LLM 工具调用管道**分四步实现，**零手写提示词**：

```
define Schema  →  schema_to_prompt()  →  feed to LLM  →  schema.parse()
   (MoonBit)        (auto-generated         (model         (auto-validate
                     TS interface)           response)      + strip extra fields)
```

```bash
python3 examples/real_llm_agent/agent.py product --mock --moon-prompt
```

> 无需 API 密钥 — 模拟模式模拟 2 轮自我修正循环。
> 详细信息和实时 LLM 使用，请参阅 [`examples/real_llm_agent/README.md`](./examples/real_llm_agent/README.md)。

**执行流程：**
1. `schemas.mbt` 定义产品列表 Schema（8 个字段，约束：最小/最大值、正数、枚举、整数等）
2. `schema_to_prompt()` 自动生成带有 `//` 约束注释的 TypeScript 接口提示词 — **无需手工编写提示词**
3. LLM 接收提示词并返回 JSON（模拟显示错误 → 正确的重试过程）
4. `schema.parse()` 进行校验，**Strip 模式静默移除幻觉字段**

**输出摘录：**
```text
Schema-to-Prompt (TS interface):         ← schema_to_prompt() 自动生成
  {
    name: string,  // 3-100 chars
    description: string,  // 10-500 chars
    price: number,  // positive
    currency: "USD" | "EUR" | "GBP" | "JPY" | "CNY",
    category: "electronics" | "clothing" | "food" | "books" | "other",
    tags: string[],  // min: 1
    stock: number,  // int, min: 0
    metadata?: {
      brand: string,  // min: 1
      weight_kg: number,  // positive
    },
  }

── Round 1 ──────────────────────────────────

  Calling deepseek-ai/DeepSeek-V3.2...
  LLM output:
    {
        "name": "Quantum Computing Starter Kit",
        "description": "A beginner-friendly kit to explore quantum computing concepts with hands-on simulations and guided experiments. Includes software access, tutorials, and basic theory materials.",
        "price": 299.99,
        "currency": "USD",
        "category": "electronics",
        "tags": ["quantum", "educational", "STEM", "beginner", "simulation"],
        "stock": 150,
        "metadata": {
            "brand": "QuantumLabs",
            "weight_kg": 1.5
        }
    }

  Validating with moon_zod (product)...

  ✅ VALIDATION PASSED  (Strip mode active)

  Clean data (hallucinations stripped):
    Object(
      {
        "name": String("Quantum Computing Starter Kit"),
        "description": String("A beginner-friendly kit to explore quantum computing concepts with hands-on simulations and guided experiments. Includes software access, tutorials, and basic theory materials."),
        "price": Number(299.99),
        "currency": String("USD"),
        "category": String("electronics"),
        "tags": Array(
          [
            String("quantum"),
            String("educational"),
            String("STEM"),
            String("beginner"),
            String("simulation"),
          ],
        ),
        "stock": Number(150),
        "metadata": Object({ "brand": String("QuantumLabs"), "weight_kg": Number(1.5) }),
      },
    )

  ✅ Self-correction loop completed in 1 round(s)
════════════════════════════════════════════════════════════
  Status: ✅ Success
  Rounds: 1
  Strip:  Extra fields removed by moon_zod default mode
════════════════════════════════════════════════════════════
```

---

## 🔄 LLM 自我修正示例

moon_zod 为**错误反馈循环**设计 — 这是让 AI 代理可靠的关键模式：

```mbt nocheck
///|
/// Retry loop: validate → collect errors → feed back → retry
fn call_llm_with_retry(schema : @moon_zod.Schema, times : Int) {
  var attempt = 0
  while attempt < times {
    let raw = llm_call(schema)  // LLM returns JSON
    match schema.parse(raw) {
      Ok(clean) => return clean   // Strip mode removes hallucinations
      Err(errors) => {
        // Format all errors for the correction prompt
        var msg = "Fix these errors:\n"
        for e in errors {
          msg = msg + "  - \{e.path}: \{e.message}\n"
        }
        llm_feedback(msg)         // Send errors back
      }
    }
    attempt = attempt + 1
  }
}
```

**不使用 moon_zod**：LLM 产生幻觉字段 → 数据损坏。LLM 犯多个错误 → 多次往返。

**使用 moon_zod**：Strip 模式清理幻觉。完整错误收集在一次重试中修复所有错误。

参见 [`examples/llm_agent/`](./examples/llm_agent/) 获取完整可运行演示：
```
moon run examples/llm_agent
```

---

## 📦 模块化 Schemas：`schema_to_prompt_named()` 用于复杂工具定义

对于**大型、深层嵌套的 Schema** 和**可复用的类型定义**，使用 `schema_to_prompt_named()` 而非内联展开：

**内联方法**（第 16-17 阶段，`schema_to_prompt()`）：
```
User { Order { Product { ... } } }  →  expand all inline  →  HUGE prompt
```

**模块化方法**（第 25+ 阶段，`schema_to_prompt_named()`）：
```
User → uses type name `User`
Order → uses type name `Order`
Product → uses type name `Product`
```

然后 **LLM 只看到需要的定义**，减少令牌计数并提高清晰度。

**使用示例：**
```mbt nocheck
// Define named schemas

///|
let user_schema = @moon_zod.object(
  {
    ...
  },
).name("User")

///|
let order_schema = @moon_zod.object(
  {
    ...
  },
).name("Order")

///|
let product_schema = @moon_zod.object(
  {
    ...
  },
).name("Product")

// Auto-extract + generate modular prompt

///|
let prompt = @moon_zod.schema_to_prompt_named(user_schema)
// Output:
// export interface User { ... }
// export interface Order { ... }
// export interface Product { ... }
```

**优势**：
- ✅ 自动提取所有命名 Schema（无需手动维护列表）
- ✅ 拓扑排序确保定义在引用之前
- ✅ 对象字段引用使用名称而非内联展开
- ✅ 循环引用检测防止无限循环

## 了解更多

- [架构设计文档](./DESIGN.md) — 核心架构、设计决策与未来方向
- [发布日志](./CHANGELOG.md) — 版本发布历史
- [English README](./README.mbt.md) — English version
