# moon_zod

[![CI](https://github.com/Betterlol/moon_zod/actions/workflows/ci.yml/badge.svg)](https://github.com/Betterlol/moon_zod/actions/workflows/ci.yml)
[![Mooncakes](https://img.shields.io/badge/mooncakes-published-blue)](https://mooncakes.io/docs/Betterlol/moon_zod)
[![doc](https://img.shields.io/badge/branch-doc-blue)](https://github.com/Betterlol/moon_zod/tree/doc)

> 🌐 [English README](./README.mbt.md)

---

## 文档

| 文档 | 说明 |
|---|---|
| [设计文档](./DESIGN.md) | 重要！核心架构、设计决策与未来方向 |
| [API 参考](./docs/zh/API.md) | 详细的 API 文档 |
| [CLI 参考](./docs/zh/CLI.md) | 命令行使用说明 |
| [性能基准](./docs/zh/BENCHMARK.md) | 与其他校验库的性能对比 |
| [使用示例](./docs/zh/EXAMPLES.md) | 实际使用示例 |
| [导出器说明](./exporters/README.md) | moon_zod 的导出器说明 |
| [导入器说明](./importers/README.md) | moon_zod 的导入器说明 |

---

## 关于项目

moon_zod 是一个**运行时 Schema 中间表示（IR）**——独立于输入来源和输出目标的校验契约层。它提供了流畅的链式调用 API 构建校验契约，核心场景是 **LLM Tool Calling**，同时也是一道跨格式的 Schema 互操作桥梁。详见[设计文档](./DESIGN.md)。

以 Schema IR 为内核提供运行时校验、多源导入、多格式导出及 LLM 幻觉防御，支撑从 JSON Schema 到 Prompt 的闭环。

---

## 安装

```bash
moon add Betterlol/moon_zod
```

或在 `moon.mod` 中添加依赖：

```toml
import {
  "Betterlol/moon_zod",
}
```

---

## 快速开始

```moonbit nocheck
let schema = @moon_zod.object({
  "name": @moon_zod.string().min(2).max(50),
  "age": @moon_zod.number().int().min(0).max(150),
  "email": @moon_zod.string().email(),
})

match schema.parse(input_json) {
  Ok(valid) => {
    println("Valid")
    println(@debug.to_string(valid))
  }
  Err(errors) => {
    println("Invalid")
    println(errors.length().to_string())
    for e in errors {
      println(e.to_string())
    }
  }
}
```

## 单个 JSON 的 Token 流

`parse_stream()` 可以在文本逐段到达时校验一个 JSON 文档。同步地喂入任意大小的
LLM token 分片；它可以提前拒绝错误 JSON。持续喂入直到输入结束，再调用 `finish()`
确认成功并执行一次 Schema 校验。根值之后的多余内容即使跨分片也会被拒绝。

```mbt nocheck
let parser = @moon_zod.object({ "name": @moon_zod.string().min(2) }).parse_stream()

parser.feed("{\"na") // StreamPending
parser.feed("me\":\"Ada\"}") // StreamPending：仍可接收尾随空白
match parser.finish() {
  StreamValid(value) => println("有效：" + @debug.to_string(value))
  StreamInvalidSchema(errors) => // 处理 Schema 校验错误
  StreamInvalidJson(message) => // 处理 JSON 格式错误
  StreamPending => ()
}
```

默认上限为 1,048,576 个 UTF-16 代码单元和 128 层嵌套，可通过 `parse_stream()`
的 `max_length` 和 `max_depth` 参数调整。解析器会缓冲一个文档，并在完成 JSON
解析后释放原始文本；成功的 Schema 校验结果仅由 `finish()` 返回。

**零代码 CLI 校验：**
```bash
# 从样本推断 Schema，校验数据
moon run moon_zod/cmd/validate -- '{"name":"Alice","age":30}' '{"name":"Bob","age":25}'
# PASS

# 使用 JSON Lines 批量校验
moon run moon_zod/cmd/validate -- '{"name":"Alice"}' '{"name":"Bob"}\n{"name":"Eve"}'
# 结果：2 通过，0 失败
```

---

## ✨ 为什么选择 MoonZod？（AI 优先）

| 特性 | moon_zod | 典型校验库 |
|---|---|---|
| **错误收集** | 在一次遍历中收集**所有**错误 | 大多数库在第一个错误时快速失败 |
| **幻觉防御** | 默认 **Strip 模式**静默删除未知字段 | 会传递幻觉数据 |
| **命名 Schema 导出** | `schema_to_prompt_named()` 生成模块化 TypeScript 接口，带类型名称引用 | 内联展开 + 重复 |
| **JSON Schema 导出** | `to_json_schema()` 为 LLM API 生成标准 Schema | 手动 Schema 维护 |
| **路径精度** | 每个错误都包含确切的字段路径（`users[0].profile.age`） | 通常只是平面消息 |
| **Wasm 就绪** | 共享路径栈，错误路径按需渲染 | 每次解析都进行重字符串分配 |

在 LLM 工具调用中，模型经常**一次性产生多个错误**并**幻觉额外字段**。moon_zod 在一次遍历中收集每个错误（以便你可以将它们全部发回进行自我纠正），并默认剥离未知字段（不会因幻觉键而导致静默数据损坏）。

---

## 项目结构

```
moon_zod/
├── moon.work                  # Workspace: four independently publishable modules
├── core/                      # Betterlol/moon_zod/core — Schema IR and validation
│   ├── moon.mod
│   └── ...
├── importers/                 # Betterlol/moon_zod/importers — JSON Schema import
│   ├── moon.mod
│   └── ...
├── exporters/                 # Betterlol/moon_zod/exporters — code/schema export
│   ├── moon.mod
│   └── ...
├── moon_zod/                  # Betterlol/moon_zod — unified facade
│   ├── moon.mod
│   ├── reexporter.mbt         # Single public API aggregation point
│   ├── combinators/          # Import/export composition
│   ├── async/                # Optional asynchronous adapters
│   ├── cmd/                  # CLI tools and benchmarks
│   ├── examples/             # Usage examples and shared schemas
│   └── tests/                # Direct imports; no duplicate re-exports
├── docs/
└── moon_zod_lab/              # Separately managed consumer submodule
```

---

## 开发

本仓库通过 `moon.work` 联合开发四个模块：主模块 `Betterlol/moon_zod`
以及可独立发布的 `/core`、`/exporters`、`/importers`。现有包导入路径保持不变。
模块依赖、直接引用方式和发布检查见[工作区指南](docs/WORKSPACE.md)。

```bash
# 测试与构建
moon test                # 运行整个工作区的测试
moon build               # 构建库
moon check               # 类型检查（0 错误，0 警告）
moon info && moon fmt    # 更新接口 + 格式化

# CLI 工具
moon run moon_zod/cmd/main                                      # 运行性能基准测试
moon run moon_zod/cmd/json2schema -- '{"hello":"world"}'      # JSON → moon_zod Schema 代码
moon run moon_zod/cmd/json2schema -- --from-json-schema '<{...}>'  # JSON Schema → moon_zod 代码
moon run moon_zod/cmd/json2schema -- --from-json-schema '<{...}>' --verbose  # 带调试输出
moon run moon_zod/cmd/gen-struct -- --schema '<{...}>'          # JSON Schema → MoonBit 结构
moon run moon_zod/cmd/validate -- '{"name":"Alice"}' '{"name":"Bob"}'  # 校验 JSON

# 示例
moon run moon_zod/examples/mock/llm_agent                     # 基础 LLM 工具调用演示
moon run moon_zod/examples/mock/educational_agent             # 多轮自我纠正演示
moon run moon_zod/examples/real_llm_agent -- product prompt   # 真实 LLM 带模拟回退
moon run moon_zod/examples/real_llm_agent -- product validate # 用真实 API 校验
moon run moon_zod/examples/multiple_schemas                   # 多个 Schema 处理
moon run moon_zod/examples/schema2json -- product schema      # Schema → JSON Schema 导出
moon run moon_zod/examples/schema2prompt -- product schema    # Schema → 提示生成展示
moon run moon_zod/examples/json2schema                        # JSON → moon_zod Schema 代码生成
```

---

## 特性

- **原始类型 Schema**：`string()`、`number()`、`boolean()`、`null()`、`bigint()`
- **复合类型 Schema**：`object(Map)`、`array(Schema)`、`tuple([Schema...])`、`union(Array[Schema])`、`intersection(Array[Schema])`、`enum_values(Array[String])`、`literal(Json)`
- **传递 Schema**：`any()` 和 `unknown()` 接受任何 JSON 值（语义区分）
- **字符串校验器**（23+ 个）：`.min(n)`、`.max(n)`、`.nonempty()`、`.trim()`、`.to_lower()`、`.to_upper()`、`.email()`（完整 RFC 校验）、`.url()`（完整结构）、`.regex(pattern)`（正则表达式匹配）、`.startsWith()`、`.endsWith()`、`.includes()`、`.uuid()`、`.cuid()`、`.ulid()`、`.datetime()`、`.ip()`/`.ipv4()`/`.ipv6()`、`.length(n)`
- **数字校验器**（8+ 个）：`.int()`、`.positive()`、`.negative()`、`.multipleOf()`、`.finite()`、`.safe()`、`.min()`、`.max()`
- **对象模式**：`.strip()`（默认，删除未知字段）、`.passthrough()`（保留未知字段）、`.strict()`（拒绝未知字段）
- **对象组合**：`.pick(keys)`、`.omit(keys)`、`.partial()`、`.extend_with(Map)`、`.merge(Schema)`
- **可选/默认处理**：`.optional()` 和 `.default(value)` 带正确的规则链接通过包装器
- **数据转换**：`.transform(fn)` 先校验再转换；`preprocess(fn, schema)` 先转换再校验
- **自定义规则**：`.refine(check, message)`、`.intersect(other)` 用于显式交集
- **Schema 命名与元数据**：`.name(text)` 用于命名导出、`.describe(text)` 用于 LLM 提示、`.brand(text)` 用于名义类型
- **自定义错误消息**：所有校验器上的 `msg?` 参数、`.message(text)` 覆盖方法、类型级别的 `required_error` / `invalid_type_error`
- **错误收集**：在一次遍历中收集**所有**校验错误，非常适合 LLM 自我纠正循环
- **完整路径错误报告**：每个错误都包含确切的字段路径（`users[0].profile.age`）
- **可选异步扩展**：`Betterlol/moon_zod/async` 提供单问题/多问题异步 refine、JSON Lines 和单帧/跨帧 SSE JSON 校验，同时保持核心 API 同步。详见[异步指南](moon_zod/async/README.mbt.md)
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
  - `schema_to_moonbit_struct(schema)` —— 为每个对象/枚举 schema 生成 MoonBit struct/enum 定义
  - `schema_to_moonbit_struct_full(schema)` —— 生成定义并附加静态 `Type::to_schema()` 函数
- **轻量依赖**：核心 MoonBit 库加官方 `moonbitlang/regexp`，无其他外部依赖
- **WebAssembly 就绪**：共享路径栈；容器重建以保留转换后的结果
- **历史性能**：每秒约 18.5k–56k 次校验；应针对实际测试版本重新测量

---

## 相关项目

- [vscode-moon-zod-schema](https://github.com/Betterlol/vscode-moon-zod-schema.git) - moon_zod 的 VSCode 插件。
> 网站: [extension](https://marketplace.visualstudio.com/items?itemName=Betterlol.vscode-moon-zod-schema).

---

## 了解更多

- [架构设计文档](./DESIGN.md) — 核心架构、设计决策与未来方向
- [发布日志](./CHANGELOG.md) — 版本发布历史
- [English README](./README.mbt.md) — English version
