# moon_zod

> 🌐 [English README](./README.mbt.md)

MoonBit 运行时 JSON Schema 校验库，受 [Zod](https://zod.dev) 和 [Pydantic](https://docs.pydantic.dev) 启发。

**专为 LLM Tool Calling 设计** — 对大语言模型的结构化 JSON 输出进行运行时校验，提供精确的错误报告与自修正支持。

---

## ✨ 为什么选择 MoonZod？（AI 优先）

| 特性 | moon_zod | 典型校验库 |
|---|---|---|
| **错误收集** | 在一次遍历中收集**所有**错误 | 大多数库在第一个错误时快速失败 |
| **幻觉防御** | 默认 **Strip 模式**静默删除未知字段 | 会传递幻觉数据 |
| **命名 Schema 导出** | `schema_to_prompt_named()` 生成模块化 TypeScript 接口，带类型名称引用 | 内联展开 + 重复 |
| **JSON Schema 导出** | `to_json_schema()` 为 LLM API 生成标准 Schema | 手动 Schema 维护 |
| **路径精度** | 每个错误都包含确切的字段路径（`users[0].profile.age`） | 通常只是平面消息 |
| **Wasm 就绪** | 可变路径栈 —— 成功路径上零堆分配 | 每次解析都进行重字符串分配 |

在 LLM 工具调用中，模型经常**一次性产生多个错误**并**幻觉额外字段**。moon_zod 在一次遍历中收集每个错误（以便你可以将它们全部发回进行自我纠正），并默认剥离未知字段（不会因幻觉键而导致静默数据损坏）。

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

**零代码 CLI 校验：**
```bash
# 从样本推断 Schema，校验数据
moon run cmd/validate -- '{"name":"Alice","age":30}' '{"name":"Bob","age":25}'
# PASS

# 使用 JSON Lines 批量校验
moon run cmd/validate -- '{"name":"Alice"}' '{"name":"Bob"}\n{"name":"Eve"}'
# 结果：2 通过，0 失败
```

---

## 项目结构

```
moon_zod/
├── core/                     # 核心 Schema 校验库
│   ├── types.mbt             # ValidationError、SchemaResult、核心类型
│   ├── schema.mbt            # Schema 结构、解析分发、路径栈
│   ├── string.mbt            # string() 工厂 + 校验器（trim、to_lower、to_upper）
│   ├── number.mbt            # number() 工厂 + 校验器
│   ├── boolean.mbt           # boolean() 工厂
│   ├── null.mbt              # null() 工厂
│   ├── bigint.mbt            # bigint() 工厂
│   ├── any_unknown.mbt       # any() / unknown() 传递 Schema
│   ├── array.mbt             # array() 工厂 + parse_array
│   ├── tuple.mbt             # tuple() 工厂 + parse_tuple
│   ├── object.mbt            # object() + 模式（strip/passthrough/strict）、pick/omit/partial/extend/merge
│   ├── optional.mbt          # optional() 工厂
│   ├── default.mbt           # default() 工厂
│   ├── enum.mbt              # enum_values() 工厂
│   ├── literal.mbt           # literal() 工厂（常量值）
│   ├── union.mbt             # union() 工厂
│   ├── intersection.mbt      # intersection() / intersect()
│   ├── refine.mbt            # refine() 用于自定义校验
│   ├── transform.mbt         # transform() 用于数据转换
│   ├── preprocess.mbt        # preprocess() 用于输入预处理
│   ├── shared_utils.mbt      # 通用工具（unwrap_schema、peel_optional 等）
│   ├── constraint_extractor.mbt  # 从规则提取约束信息
│   └── moon_zod_wbtest.mbt   # 白盒测试（路径栈不变量）
│
├── combinators/              # Schema 组合器工具
│   ├── schema_combinators.mbt # Schema 组合辅助函数
│   └── reexporter.mbt        # 重新导出
│
├── exporters/                # 代码/Schema 导出工具
│   ├── prompt.mbt            # schema_to_prompt() / schema_to_prompt_named()
│   ├── prompt_renderer.mbt   # 基于特性的提示渲染
│   ├── json_schema.mbt       # to_json_schema() / to_json_schema_named()
│   ├── json_schema_renderer.mbt # 基于特性的 JSON Schema 渲染
│   ├── moonbit_struct.mbt    # schema_to_moonbit_struct() + from_json() 生成
│   ├── moonbit_renderer.mbt  # 基于特性的 MoonBit 结构渲染
│   ├── schema_exporter.mbt   # 共享导出器工具
│   └── reexporter.mbt        # 模块重新导出
│
├── importers/                # Schema 导入工具
│   ├── from_json_schema.mbt  # json_schema_to_moon_zod() —— 反向 JSON Schema → moon_zod 代码生成
│   └── reexporter.mbt        # 模块重新导出
│
├── tests/                    # 测试套件（466 个测试）
│   ├── test_string.mbt       # string() 校验器测试（trim、to_lower、to_upper、nonempty）
│   ├── test_number.mbt       # number() 校验器测试
│   ├── test_boolean_null.mbt # boolean/null 测试
│   ├── test_object.mbt       # object() 模式 + pick/omit/partial/extend/merge 测试
│   ├── test_array.mbt        # array() + nonempty 测试
│   ├── test_tuple.mbt        # tuple() 测试
│   ├── test_combinators.mbt  # union/literal/optional/default/brand/bigint 测试
│   ├── test_any_unknown_preprocess.mbt # any/unknown/preprocess 测试
│   ├── test_transform_refine.mbt # transform/refine 测试
│   ├── test_json_schema.mbt  # JSON Schema 导出 + $defs/$ref 测试
│   ├── test_json_schema_fixes.mbt # exclusiveMin/Max 语义 + enum 边界情况
│   ├── test_moonbit_struct.mbt # MoonBit 结构生成测试
│   ├── test_prompt.mbt       # 提示生成测试
│   ├── test_prompt_named.mbt # 命名 Schema 导出测试
│   ├── test_custom_message.mbt # 自定义错误消息测试
│   ├── test_errors.mbt       # 错误收集测试
│   ├── test_schema_to_code.mbt # 代码生成测试
│   └── reexporter.mbt        # 测试重新导出
│
├── cmd/                      # CLI 工具
│   ├── main/                 # 基准测试运行器（性能基准）
│   ├── wasm/                 # WebAssembly 跨语言基准测试
│   ├── json2schema/          # JSON → moon_zod Schema 代码生成器 + JSON Schema 反向导入器
│   ├── gen-struct/           # JSON → MoonBit 结构 + from_json() 生成器
│   └── validate/             # JSON Schema 校验器（推断后校验）
│
└── examples/                 # LLM 智能体演示
    ├── json2schema/          # JSON → moon_zod Schema 代码生成
    ├── mock/                 # 模拟智能体演示
    │   ├── llm_agent/        # 基础 LLM 工具调用示例
    │   └── educational_agent/ # 多轮自我纠正演示
    ├── multiple_schemas/     # 处理多个 Schema
    ├── real_llm_agent/       # 真实 LLM 集成（带 API 模拟回退）
    ├── resources/            # 样本数据文件（JSON、JSON Schema）
    ├── schema2json/          # Schema → JSON Schema 导出演示
    ├── schema2prompt/        # Schema → 提示生成展示
    ├── shared_schemas/       # 共享 Schema 定义（库包）
    └── validate_cli/         # CLI 校验演示
```

---

## 开发

```bash
# 测试与构建
moon test                # 运行所有测试（共 466 个，0 警告）
moon build               # 构建库
moon check               # 类型检查（0 错误，0 警告）
moon info && moon fmt    # 更新接口 + 格式化

# CLI 工具
moon run cmd/main                                      # 运行性能基准测试
moon run cmd/json2schema -- '{"hello":"world"}'      # JSON → moon_zod Schema 代码
moon run cmd/json2schema -- --from-json-schema '<{...}>'  # JSON Schema → moon_zod 代码
moon run cmd/json2schema -- --from-json-schema '<{...}>' --verbose  # 带调试输出
moon run cmd/gen-struct -- '{"name":"Alice"}'        # JSON → MoonBit 结构 + from_json()
moon run cmd/validate -- '{"name":"Alice"}' '{"name":"Bob"}'  # 校验 JSON

# 示例
moon run examples/mock/llm_agent                     # 基础 LLM 工具调用演示
moon run examples/mock/educational_agent             # 多轮自我纠正演示
moon run examples/real_llm_agent -- product prompt   # 真实 LLM 带模拟回退
moon run examples/real_llm_agent -- product validate # 用真实 API 校验
moon run examples/multiple_schemas                   # 多个 Schema 处理
moon run examples/schema2json -- product schema      # Schema → JSON Schema 导出
moon run examples/schema2prompt                      # Schema → 提示生成展示
moon run examples/json2schema                        # JSON → moon_zod Schema 代码生成
```

---

## 特性

- **原始类型 Schema**：`string()`、`number()`、`boolean()`、`null()`、`bigint()`
- **复合类型 Schema**：`object(Map)`、`array(Schema)`、`tuple([Schema...])`、`union(Array[Schema])`、`intersection(Array[Schema])`、`enum_values(Array[String])`、`literal(Json)`
- **传递 Schema**：`any()` 和 `unknown()` 接受任何 JSON 值（语义区分）
- **字符串校验器**（23+ 个）：`.min(n)`、`.max(n)`、`.nonempty()`、`.trim()`、`.to_lower()`、`.to_upper()`、`.email()`（完整 RFC 校验）、`.url()`（完整结构）、`.regex(pattern)`（子字符串匹配）、`.startsWith()`、`.endsWith()`、`.includes()`、`.uuid()`、`.cuid()`、`.ulid()`、`.datetime()`、`.ip()`/`.ipv4()`/`.ipv6()`、`.length(n)`
- **数字校验器**（8+ 个）：`.int()`、`.positive()`、`.negative()`、`.multipleOf()`、`.finite()`、`.safe()`、`.min()`、`.max()`
- **对象模式**：`.strip()`（默认，删除未知字段）、`.passthrough()`（保留未知字段）、`.strict()`（拒绝未知字段）
- **对象组合**：`.pick(keys)`、`.omit(keys)`、`.partial()`、`.extend(Map)`、`.merge(Schema)`
- **可选/默认处理**：`.optional()` 和 `.default(value)` 带正确的规则链接通过包装器
- **数据转换**：`.transform(fn)` 先校验再转换；`preprocess(fn, schema)` 先转换再校验
- **自定义规则**：`.refine(check, message)`、`.intersect(other)` 用于显式交集
- **Schema 命名与元数据**：`.name(text)` 用于命名导出、`.describe(text)` 用于 LLM 提示、`.brand(text)` 用于名义类型
- **自定义错误消息**：所有校验器上的 `msg?` 参数、`.message(text)` 覆盖方法、类型级别的 `required_error` / `invalid_type_error`
- **错误收集**：在一次遍历中收集**所有**校验错误，非常适合 LLM 自我纠正循环
- **完整路径错误报告**：每个错误都包含确切的字段路径（`users[0].profile.age`）
- **LLM 提示生成**：
  - `schema_to_prompt(schema)` —— 内联 TypeScript 接口，带约束注释
  - `schema_to_prompt_named(schema, include_names?)` —— 模块化接口，带拓扑排序和类型名称引用
- **JSON Schema 导出**：
  - `to_json_schema(schema)` —— 标准 JSON Schema，带完整约束注释
  - `to_json_schema_skeleton(schema)` —— 轻量级骨架（仅结构）
  - `to_json_schema_named(schema, include_names?)` —— 单独的 `$defs` 和 `$ref` 引用
- **JSON Schema 反向导入**：
  - `json_schema_to_moon_zod(json_schema)` —— 从标准 JSON Schema 生成 moon_zod 源代码
  - 完整支持 `$defs`、`$ref`、约束、格式校验、enum
- **MoonBit 结构生成**：

## API 参考

### 工厂函数

| 函数 | 描述 |
|---|---|
| `string(required_error?, invalid_type_error?)` | 校验 JSON 字符串 |
| `number(required_error?, invalid_type_error?)` | 校验 JSON 数字 |
| `boolean(required_error?, invalid_type_error?)` | 校验 JSON 布尔值 |
| `null(required_error?, invalid_type_error?)` | 校验 JSON null |
| `array(Schema, required_error?, invalid_type_error?)` | 校验数组，递归检查元素 |
| `tuple([Schema...], required_error?, invalid_type_error?)` | **Phase 38**：固定长度数组 — 按位置校验每个元素 |
| `object(Map[String, Schema], required_error?, invalid_type_error?)` | 校验对象。**默认：Strip 模式** |
| `enum_values(Array[String], required_error?, invalid_type_error?)` | 固定的允许字符串值集合 |
| `literal(Json, required_error?, invalid_type_error?)` | **Phase 32**：常量值校验 — 仅接受完全匹配的 JSON |
| `bigint(required_error?, invalid_type_error?)` | **Phase 37**：`number().int()` 的语义别名 — 表示大整数意图 |
| `any(required_error?, invalid_type_error?)` | **Phase 39**：接受任何 JSON 值（透传） |
| `unknown(required_error?, invalid_type_error?)` | **Phase 39**：接受任何 JSON 值作为未知类型（语义标记） |
| `preprocess((Json) -> Result[Json, String], Schema, required_error?, invalid_type_error?)` | **Phase 39**：先转换原始输入，再针对内部 schema 进行校验 |
| `union(Array[Schema], required_error?, invalid_type_error?)` | 联合类型 — 如果任何 schema 匹配则通过 |
| `intersection(Array[Schema], required_error?, invalid_type_error?)` | **Phase 18**：交集 — 如果所有 schema 都匹配则通过；对象字段合并 |

### Schema 方法

| 方法 | 适用范围 | 描述 |
|---|---|---|
| `.parse(Json, path?)` | 全部 | 校验，返回 `Ok(Json)` 或 `Err(Array[ValidationError])` |
| `.min(n[, msg])` | string / number / array | 最小长度 / 值 |
| `.max(n[, msg])` | string / number / array | 最大长度 / 值 |
| `.length(n[, msg])` | string / array / tuple | 精确长度 |
| `.nonempty([msg])` | string / array / tuple | 不能为空 |
| `.email([msg])` | string | 完整邮箱校验 |
| `.url([msg])` | string | 完整 URL 结构校验 |
| `.regex(pattern[, msg])` | string | 必须包含 `pattern` 作为子字符串 |
| `.startsWith(prefix[, msg])` | string | 必须以 `prefix` 开头 |
| `.endsWith(suffix[, msg])` | string | 必须以 `suffix` 结尾 |
| `.includes(substring[, msg])` | string | 必须包含 `substring` |
| `.trim()` | string | **Phase 37**：删除首尾空格 |
| `.to_lower()` | string | **Phase 37**：转换为小写 |
| `.to_upper()` | string | **Phase 37**：转换为大写 |
| `.uuid([msg])` | string | 必须是有效的 UUID v4 |
| `.cuid([msg])` | string | 必须是有效的 CUID |
| `.datetime([msg])` | string | 必须是 ISO 8601 日期时间 |
| `.ip([msg])` | string | 必须是有效的 IPv4 或 IPv6 |
| `.ipv4([msg])` | string | 必须是有效的 IPv4 |
| `.ipv6([msg])` | string | 必须是有效的 IPv6 |
| `.ulid([msg])` | string | 必须是有效的 ULID |
| `.int([msg])` | number | 必须是整数 |
| `.positive([msg])` | number | 必须 > 0 |
| `.negative([msg])` | number | 必须 < 0 |
| `.multipleOf(n[, msg])` | number | 必须是 `n` 的倍数 |
| `.finite([msg])` | number | 必须是有限数 |
| `.safe([msg])` | number | 必须是安全整数 |
| `.optional()` | any | Null 或缺失值跳过校验 |
| `.default(value)` | any | 用默认值替换 null |
| `.strict()` | object | 拒绝未定义的字段 |
| `.passthrough()` | object | 保持未定义的字段不变 |
| `.strip()` | object | 无声地删除未定义的字段（默认） |
| `.pick(keys)` | object | **Phase 21**：仅选择指定的字段 |
| `.omit(keys)` | object | **Phase 21**：删除指定的字段 |
| `.partial()` | object | **Phase 21**：使所有字段可选 |
| `.extend(Map[String, Schema])` | object | **Phase 38**：从 Map 中添加或覆盖字段 |
| `.merge(Schema)` | object | **Phase 38**：与另一个对象 schema 合并（右侧覆盖） |
| `.describe(text)` | any | **Phase 17**：为 LLM 提示附加描述 |
| `.name(text)` | any | **Phase 25**：为 schema 导出指定名称 |
| `.brand(text)` | any | **Phase 37**：为名义类型指定品牌标记 |
| `.message(text)` | any | **Phase 19**：覆盖最后一条规则的错误消息 |
| `.intersect(other)` | any | **Phase 18**：交集 — 输入必须同时匹配两个 schema |
| `.refine(check, msg)` | any | 自定义校验谓词 |
| `.transform(fn)` | any | **Phase 13**：校验后转换输出 |

### 独立函数

| 函数 | 描述 |
|---|---|
| `schema_to_prompt(Schema)` | **Phase 16**：为 LLM 工具调用生成 TypeScript 接口提示字符串 — 内联展开 |
| `schema_to_prompt_named(Schema, include_names?)` | **Phase 25, 34**：从命名 schema 生成模块化 TypeScript 接口 |
| `to_json_schema(Schema)` | **Phase 15**：导出包含完整约束注解的标准 JSON Schema |
| `to_json_schema_skeleton(Schema)` | **Phase 15**：导出轻量级 JSON Schema 骨架（仅结构） |
| `to_json_schema_named(Schema, include_names?)` | **Phase 26, 34**：将命名 schema 导出为 `$defs` 和 `$ref` |
| `json_schema_to_moon_zod(Json)` | **Phase 27, 36**：从 JSON Schema 反向生成 moon_zod 代码 |
| `schema_to_moonbit_struct(Schema)` | **Phase 28**：生成 MoonBit 结构体定义 |
| `schema_to_moonbit_struct_full(Schema)` | **Phase 29**：生成结构体 + `from_json()` 函数 |
| `schema_to_moonbit_struct_named(Schema, include_names?)` | **Phase 31**：从命名 schema 生成结构体 |
| `schema_to_moonbit_struct_named_full(Schema, include_names?)` | **Phase 31**：从命名 schema 生成结构体 + `from_json()` |
| `schema_to_moon_zod_code(Schema)` | 生成 moon_zod schema 源代码 |
| `schema_to_moon_zod_code_named(Schema, include_names?)` | 生成具有 `$defs` 和 `$ref` 的 moon_zod 代码 |
| `json_schema_to_schema(Json)` | 将 JSON Schema 反向解析为 moon_zod Schema |
| `json_infer_schema(Json)` | 从示例 JSON 值推断 moon_zod Schema |
| `append_rule(Schema, (Json) -> Bool, String)` | 追加原始校验规则 |
| `append_rule_with_annotation(Schema, (Json) -> Bool, String, Json)` | 追加具有注解载荷的规则 |
| `format_path(Array[String])` | 将路径栈连接为点号记法字符串 |
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
```


### JSON转Schema生成器 (CLI)

从任何JSON数据负载即时生成 `@moon_zod` schema代码——无需手动为真实世界的API数据编写schema。

```bash
moon run cmd/json2schema -- '{"hello": "world"}'
```

输出（可直接复制粘贴的moon_zod代码）：

```moonbit nocheck
@moon_zod.object({
  "hello": @moon_zod.string(),
})
```

获取带有调试信息的详细输出：
```bash
moon run cmd/json2schema -- --verbose '{"hello": "world"}'
```

生成器递归推断类型（`string`、`number`、`boolean`、`null`、`array`、`object`），并安全转义对象键中的特殊字符。空数组会生成 `/* TODO: specify exact type */` 注释，以提醒你类型推断缺乏数据。

---

### JSON Schema反向导入器 (CLI)

从标准 **JSON Schema (draft-07)** 定义生成 `@moon_zod` schema代码——这是 `to_json_schema()` 的反向操作。

**内联模式**（JSON Schema作为命令参数）：
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

**文件模式**（从文件读取JSON Schema）：
```bash
moon run cmd/json2schema -- --from-json-schema --schema-file schema.json
```

输出：

```moonbit nocheck
@moon_zod.object({
  "name": @moon_zod.string().min(2),
  "age": @moon_zod.number().int().min(0).max(150),
})
```

**功能特性**：
- 转换所有JSON Schema类型（string、number、integer、boolean、null、array、object）
- 提取约束条件：`minLength`、`maxLength`、`minimum`、`maximum`、`exclusiveMinimum`、`exclusiveMaximum`、`multipleOf`、`pattern`、`format`（email、uri、date-time、ipv4、ipv6、uuid）
- 处理 `$defs` 和 `$ref` 引用——生成单独命名的schema声明
- 支持 `enum`、`oneOf`、`anyOf`、`allOf`
- 不在 `required` 中的字段自动用 `.optional()` 包装
- 输出**可直接复制粘贴的MoonBit源代码**
- 完全支持Phase 36语义：在适用的地方，`exclusiveMinimum`/`exclusiveMaximum` 生成 `.positive()`/`.negative()`

---

### MoonBit结构体生成器 (CLI)

从任何JSON样本生成MoonBit结构体定义——包括结构体定义和 `from_json()` 函数用于类型安全的转换。

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

支持嵌套对象、数组和可选字段。嵌套对象自动命名并作为单独的结构体定义导出。

---

### JSON校验器 (CLI)

针对从样本推断的schema校验JSON数据——无需代码。支持JSON Lines格式进行批量校验。

```bash
# 单个JSON校验
moon run cmd/validate -- '{"name":"Alice","age":30}' '{"name":"Bob","age":25}'
# PASS

# 使用JSON Lines进行批量校验
moon run cmd/validate -- '{"name":"Alice"}' '{"name":"Bob"}\n{"name":"Eve"}\n{"age":30}'
# FAIL: line 3
#   [name] Required (got: Null)
# Results: 2 passed, 1 failed

# 文件模式（JSON Schema作为schema源）
moon run cmd/validate -- --schema-file schema.json --sample-file data.json
```


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

## 演示：Schema → `schema_to_prompt()` → LLM → `schema.parse()`

**完整的 LLM 工具调用流程**，分四步进行，**零手写提示词**：

```
定义 Schema  →  schema_to_prompt()  →  输入 LLM  →  schema.parse()
   (MoonBit)        (自动生成              (模型          (自动校验
                     TS 接口)               响应)          + 清除额外字段)
```

```bash
python3 examples/real_llm_agent/agent.py product --mock --moon-prompt
```

> 无需 API 密钥 — Mock 模式模拟一个 2 轮自我纠正循环。
> 完整详情及实时 LLM 使用方式，请见 [`examples/real_llm_agent/README.md`](./examples/real_llm_agent/README.md)。

**发生的过程：**
1. `schemas.mbt` 定义产品列表 Schema（8 个字段，约束条件：最小/最大、正数、枚举、整数...）
2. `schema_to_prompt()` 自动生成 TypeScript 接口提示词，带有 `//` 约束注释 — **无需手工编写提示词**
3. LLM 接收提示词并返回 JSON（Mock 模拟一个错误 → 正确的重试）
4. `schema.parse()` 进行校验，**Strip 模式静默移除幻觉字段**

**输出示例：**
```text
Schema-to-Prompt (TS 接口)：              ← 由 schema_to_prompt() 自动生成
  {
    name: string,  // [3-100 chars]
    description: string,  // [10-500 chars]
    price: number,  // [positive]
    currency: "USD" | "EUR" | "GBP" | "JPY" | "CNY",
    category: "electronics" | "clothing" | "food" | "books" | "other",
    tags: string[],  // [min: 1]
    stock: number,  // [int, min: 0]
    metadata?: {
      brand: string,  // [min: 1]
      weight_kg: number,  // [positive]
    },
  }

── 第 1 轮 ──────────────────────────────────

  调用 deepseek-ai/DeepSeek-V3.2...
  LLM 输出：
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

  使用 moon_zod (product) 进行校验...

  ✅ 校验通过  (Strip 模式激活)

  清理后的数据（幻觉字段已清除）：
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

  ✅ 自我纠正循环在 1 轮内完成

════════════════════════════════════════════════════════════
  状态：✅ 成功
  轮数：1
  清除：moon_zod 默认模式已移除额外字段
════════════════════════════════════════════════════════════
```

---

## 🔄 LLM 自我纠正示例

moon_zod 为**错误反馈循环**而设计 — 这是使 AI 智能体可靠的关键模式：

```mbt nocheck
///|
/// 重试循环：校验 → 收集错误 → 反馈 → 重试
fn call_llm_with_retry(schema : @moon_zod.Schema, times : Int) {
  var attempt = 0
  while attempt < times {
    let raw = llm_call(schema)  // LLM 返回 JSON
    match schema.parse(raw) {
      Ok(clean) => return clean   // Strip 模式移除幻觉字段
      Err(errors) => {
        // 格式化所有错误供纠正提示词使用
        var msg = "Fix these errors:\n"
        for e in errors {
          msg = msg + "  - \{e.path}: \{e.message}\n"
        }
        llm_feedback(msg)         // 将错误发送回去
      }
    }
    attempt = attempt + 1
  }
}
```

**不使用 moon_zod**：LLM 幻觉生成额外字段 → 数据损坏。LLM 犯多个错误 → 多次往返。

**使用 moon_zod**：Strip 模式清理幻觉。完整的错误收集在一次重试中修复所有错误。

参见 [`examples/llm_agent/`](./examples/llm_agent/) 获得完整可运行演示：
```
moon run examples/llm_agent
```

---

## 📦 模块化 Schema：`schema_to_prompt_named()` 用于复杂工具定义

对于**大型、深层嵌套的 Schema** 和**可复用类型定义**，使用 `schema_to_prompt_named()` 而非内联展开：

**内联方式**（阶段 16-17，`schema_to_prompt()`）：
```
User { Order { Product { ... } } }  →  全部内联展开  →  巨大的提示词
```

**模块化方式**（阶段 25+，`schema_to_prompt_named()`）：
```
User → 使用类型名称 `User`
Order → 使用类型名称 `Order`
Product → 使用类型名称 `Product`
```

然后 **LLM 仅看到它需要的定义**，减少 Token 计数并提高清晰度。

**使用示例：**
```mbt nocheck
// 定义命名 Schema
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

// 自动提取 + 生成模块化提示词

///|
let prompt = @moon_zod.schema_to_prompt_named(user_schema)
// 输出：
// export interface User { ... }
// export interface Order { ... }
// export interface Product { ... }
```

**优势**：
- ✅ 自动提取所有命名 Schema（无需手动列表维护）
- ✅ 拓扑排序确保定义先于引用
- ✅ 对象字段引用使用名称而非内联展开
- ✅ 循环引用检测防止无限循环

## 了解更多

- [架构设计文档](./DESIGN.md) — 核心架构、设计决策与未来方向
- [发布日志](./CHANGELOG.md) — 版本发布历史
- [English README](./README.mbt.md) — English version
