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
├── combinators/              # Schema 组合工具
│   ├── schema_combinators.mbt # Schema 组合辅助函数
│   └── reexporter.mbt        # 重新导出
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
├── tests/                    # 测试套件（426 个测试）
│   ├── test_string.mbt       # string() 验证器测试
│   ├── test_number.mbt       # number() 验证器测试
│   ├── test_boolean_null.mbt # boolean/null 测试
│   ├── test_object.mbt       # object() 模式测试
│   ├── test_array.mbt        # array() 测试
│   ├── test_combinators.mbt  # union/literal/optional/default 测试
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
│   ├── main/                 # 基准测试运行器（性能基线）
│   ├── wasm/                 # WebAssembly 跨语言基准测试
│   ├── json2schema/          # JSON → moon_zod Schema 代码生成器 + JSON Schema 反向导入器
│   ├── gen-struct/           # JSON → MoonBit 结构 + from_json() 生成器
│   └── validate/             # JSON Schema 验证器（推断然后验证）
│
└── examples/                 # LLM 代理演示
    ├── json2schema/          # JSON → moon_zod schema 代码生成
    ├── mock/                 # Mock 代理演示
    │   ├── llm_agent/        # 基础 LLM 工具调用示例
    │   └── educational_agent/ # 多轮自纠正演示
    ├── multiple_schemas/     # 处理多个 Schema
    ├── real_llm_agent/       # 真实 LLM 集成（带 API 回退到 mock）
    ├── resources/            # 样本数据文件（JSON、JSON Schema）
    ├── schema2json/          # Schema → JSON Schema 导出演示
    ├── schema2prompt/        # Schema → 提示生成展示
    ├── shared_schemas/       # 共享 Schema 定义（库包）
    └── validate_cli/         # CLI 验证演示
```

---

## 开发

```bash
# 测试与构建
moon test                # 运行所有测试（共 426 个，0 个警告）
moon build               # 构建库
moon check               # 类型检查（0 错误，0 警告）
moon info && moon fmt    # 更新接口 + 格式化

# CLI 工具
moon run cmd/main                                      # 运行性能基准测试
moon run cmd/json2schema -- '{"hello":"world"}'      # JSON → moon_zod Schema 代码
moon run cmd/json2schema -- --from-json-schema '<{...}>'  # JSON Schema → moon_zod 代码
moon run cmd/json2schema -- --from-json-schema '<{...}>' --verbose  # 带调试输出版本
moon run cmd/gen-struct -- '{"name":"Alice"}'        # JSON → MoonBit 结构 + from_json()
moon run cmd/validate -- '{"name":"Alice"}' '{"name":"Bob"}'  # 验证 JSON

# 示例
moon run examples/mock/llm_agent                     # 基础 LLM 工具调用演示
moon run examples/mock/educational_agent             # 多轮自纠正演示
moon run examples/real_llm_agent -- product prompt   # 真实 LLM（带 mock 回退）
moon run examples/real_llm_agent -- product validate # 用真实 API 验证
moon run examples/multiple_schemas                   # 处理多个 Schema
moon run examples/schema2json -- product schema      # Schema → JSON Schema 导出
moon run examples/schema2prompt                      # Schema → 提示生成展示
moon run examples/json2schema                        # JSON → moon_zod schema 代码生成
```

---

## 特性

- **基础类型 Schema**：`string()`、`number()`、`boolean()`、`null()`
- **复合 Schema**：`object(Map)`、`array(Schema)`、`union(Array[Schema])`、`intersection(Array[Schema])`、`enum_values(Array[String])`、`literal(Json)`
- **字符串验证器**（20+）：`.min(n)`、`.max(n)`、`.nonempty()`、`.email()`（完整 RFC 验证）、`.url()`（完整结构）、`.regex(pattern)`（子字符串匹配）、`.startsWith()`、`.endsWith()`、`.includes()`、`.uuid()`、`.cuid()`、`.ulid()`、`.datetime()`、`.ip()`/`.ipv4()`/`.ipv6()`、`.length(n)`
- **数字验证器**（8+）：`.int()`、`.positive()`、`.negative()`、`.multipleOf()`、`.finite()`、`.safe()`、`.min()`、`.max()`
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

---