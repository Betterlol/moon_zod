# moon_zod 项目申报书

## 基本信息

* **项目名称**：moon_zod：面向 AI Tool Calling 的 MoonBit 运行时 JSON Schema 校验库
* **参赛者**：李家成
* **联系方式**：17376330745
* **GitHub 仓库链接**：https://github.com/Betterlol/moon_zod
* **项目方向**：MoonBit 运行时数据校验基础库 / AI 结构化工具调用基础设施
* **是否为参考/移植项目**：是（参考并吸收了已有开源项目 Zod 与 Pydantic 的核心设计思想）

## 项目简介

`moon_zod` 是 MoonBit 版本的 Zod/Pydantic——一个专门针对**运行时 JSON Schema 校验**的高性能基础库。其核心场景是解决大语言模型（LLM）在 Tool Calling（工具调用）模式下生成的 JSON 输出经常伴随着格式不符、字段缺失或幻觉数据等痛点。

项目采用 Code-first（代码优先）与 Builder（链式调用）模式，允许开发者以 Fluent API 体验构建数据契约，并在运行时对动态的 `Json` 输入进行深度的级联验证。项目不仅能将 Schema 导出为模型所需的标准 JSON Schema，还能在校验失败时并行收集所有字段的路径缺陷并一次性回溯，是构建大模型自动纠错闭环（Auto-Correction Loop）的 AI 原生基础设施。

项目支持编译到 **WebAssembly**，可在 Wasm edge 运行时中直接运行，并提供了完整的跨语言性能对比基准（与 TypeScript Zod、手写 Match 校验器的三方对比）。同时内置了 **LLM 自愈闭环 Demo**（`examples/llm_agent/`），完整演示 Schema 定义 → JSON Schema 导出 → 模型输出校验 → 错误格式化 → 重试纠错 → Strip 清洗幻觉字段的全流程。

## 核心功能范围

1. **完备的基础校验器**：13 种 SchemaType 变体覆盖 JSON 规范全部类型（string、number、boolean、null、object、array、tuple、enum、union、intersection、literal 等）及高级语义（any / unknown / optional / default）。
2. **丰富的链式校验规则**：针对 string/number/array 提供 .min、.max、.nonempty、.email、.url、.regex、.uuid、.int、.positive、.finite、.safe、.multipleOf、.startsWith、.endsWith、.includes、.trim、.to_lower、.to_upper 等 30+ 内置约束规则。
3. **非 fail-fast 的级联错误收集**：专为大模型纠错设计，深度遍历并收集所有路径的缺陷，一次性将完整错误反馈给模型进行重试纠错。
4. **精确的 Path 错误追踪**：支持深层嵌套定位（如 `users[0].profile.email`），错误附带清晰的错误原因与收发数据对比。
5. **高级组合器与修饰器**：可选字段 .optional()、缺省填充 .default()、固定枚举 enum_values()、联合 union()、交集 intersection()、常量 literal()、数据变换 transform()、预处理 preprocess()、自定义 refine()、对象组合 pick/omit/partial/extend/merge 等。
6. **对象防幻觉放行控制**：Object 校验**默认 Strip 模式**（静默移除未定义字段），一键切换 .passthrough() / .strict()，从根源拦截 LLM 幻觉数据污染。
7. **标准 JSON Schema 导出**：to_json_schema(schema) 一键转换为标准 JSON Schema 文档；to_json_schema_named() 支持 $defs/$ref 命名引用导出。
8. **LLM Prompt 自动生成**：schema_to_prompt(schema) 自动输出 TypeScript-interface 风格类型描述（带约束注释），schema_to_prompt_named() 支持模块化命名引用；配合 .describe() 为模型提供字段语义说明。
9. **JSON Schema 反向导入**：json_schema_to_schema() 将标准 JSON Schema（draft-07）转换为运行时 Schema 对象，支持 $defs、$ref、anyOf/allOf/oneOf、enum 及约束条件映射。
10. **MoonBit 结构体代码生成**：schema_to_moonbit_struct(schema) 递归生成 MoonBit 结构体定义，schema_to_moonbit_struct_full() 额外生成静态 Type::to_schema() 方法。
11. **moon_zod 源码回生成**：schema_to_moon_zod_code(schema) 将 Schema 对象输出为 moon_zod 链式调用源码（带命名引用支持），形成代码双向闭环。
12. **低分配高性能**：Mutable Path Stack（可变路径栈）在成功路径上实现零字符串分配；100k 次迭代基准达 3.8M ops/sec，约 15 倍于 TypeScript Zod。
13. **完整工程实践**：5 子包模块化架构（core/exporters/importers/combinators/tests），470 项测试全通过，GitHub Actions CI 自动化验证。

## 移植或参考说明

* **原项目名称**：Zod (TypeScript) / Pydantic (Python)
* **原项目链接**：[https://github.com/colinhacks/zod](https://github.com/colinhacks/zod) / [https://github.com/pydantic/pydantic](https://github.com/pydantic/pydantic)
* **本项目许可证**：Apache-2.0

与原项目相比，本项目会做以下简化和重新设计：

1. **MoonBit 语言特性原生重构**：放弃 TypeScript 复杂的运行时类型推导黑魔法，通过 SchemaType 枚举 + Rule 闭包数组实现一套更纯粹、高性能的命令式+函数式混合架构。
2. **紧扣 AI 原生场景剪裁**：剔除异步校验、ORM 绑定等与 Tool Calling 无关的特性，核心聚焦 LLM 结构化验证、全量错误回溯、幻觉字段防御（Strip 默认）及多格式结构化导出。
3. **演进式类型系统与模组化设计**：当前以 Json 为底层载体，向上通过 5 子包架构隔离校验、导出、导入各层职责；四种代码生成管线支持 Schema ↔ 目标格式（TS prompt / JSON Schema / MoonBit struct / moon_zod 源码）的双向闭环。未来计划引入 derive 宏机制，打通动静类型壁垒。