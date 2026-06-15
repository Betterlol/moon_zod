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

1. **完备的基础校验器**：提供 `string()`、`number()`、`boolean()` 和 `null()` 的核心工厂函数，完整对齐 JSON 规范的基础数据类型。
2. **丰富的链式规则链（Rules）**：针对基础类型提供 `.min(n)`、`.max(n)`、`.nonempty()`、`.email()`、`.url()`、`.regex(pattern)`、`.int()`、`.positive()`、`.negative()`、`.multipleOf(n)` 等多维度内置约束规则。
3. **非 Fail-fast 的级联错误收集**：专为大模型纠错设计，在解析 Object 或 Array 时遇到错误不会立即熔断，而是深度遍历并收集所有路径的缺陷，方便一次性将错误完整反馈给模型。
4. **精确的 Path 错误追踪体系**：支持深层嵌套的结构化路径 splicing 拼接，错误发生时可以精确输出人类和模型均高度可读的字段定位（如 `"address.city"` 或 `"tags[0]"`），并包含清晰的错误原因与收发数据对比。
5. **高级组合器与修饰器**：全面支持可选字段 `.optional()`、缺省填充 `.default(value)`、固定枚举校验 `enum_values(Array)` 以及多选一的联合类型 `union(Array)` 组合器。
6. **具穿透性的规则追加机制**：通过 `append_rule` 与 `inner_type` 重构机制，能穿透 `.optional()` 或 `.default()` 等外部装饰器壳子，使后续链接的约束规则作用于最内层的核心类型。
7. **灵活的自定义业务规则注入**：提供 `.refine(check, message)` 接口，允许开发者根据特定业务场景动态注入自定义的谓词校验逻辑。
8. **严格的对象放行控制**：Object 校验**默认开启 Strip 模式**（静默移除 Schema 未定义的幻觉字段），并支持一键切换为 `.passthrough()`（放行额外字段）或 `.strict()`（严格拒绝未定义字段），从根源上拦截模型产生的无用脏数据污染下游。
9. **标准 JSON Schema 一键导出**：提供统一的 `to_json_schema(schema)` 顶层公开接口，可透明化提取当前的类型拓扑、属性映射、必需字段和严格性模式，转换为标准的 JSON Schema 数据，完美打通工具声明到运行时验证的闭环。
10. **低分配的高效运行时性能**：核心错误收集采用原地修改（mutate-in-place）的优化设计，减少了深层嵌套解析时的内存分配开销。**Mutable Path Stack**（可变路径栈）在校验成功路径上实现零字符串分配。项目内置了 100,000 次复杂嵌套结构体的迭代验证（3 个用户 × 嵌套 profile/metadata），并提供了跨语言对比基准（TS Zod vs MoonZod Wasm vs Handcrafted Match），在提供抽象能力的同时确保了运行稳定性。
11. **规范的工程实践与持续集成规划**：遵循 TDD（测试驱动开发）模式，当前已包含 **74 个全功能覆盖的单元测试**（含黑盒、白盒与回归测试），并配备了完整的 GitHub Actions CI 流水线（fmt check → native build → wasm build → test），每次推送自动全量验证。

## 移植或参考说明

* **原项目名称**：Zod (TypeScript) / Pydantic (Python)
* **原项目链接**：[https://github.com/colinhacks/zod](https://github.com/colinhacks/zod) / [https://github.com/pydantic/pydantic](https://github.com/pydantic/pydantic)
* **本项目许可证**：Apache-2.0

与原项目相比，本项目会做以下简化和重新设计：

1. **MoonBit 语言特性原生重构**：放弃 TypeScript 过于复杂的运行时类型推导黑魔法（如动态类型 `infer` 等），通过巧妙组合 MoonBit 的 `SchemaType` 枚举与 `Rule` 闭包函数数组，实现了一套更加纯粹、高性能且解耦的命令式+函数式混合架构。
2. **紧扣 AI 原生场景剪裁**：剔除原项目针对传统 Web 前端繁琐的转换（Transform）、异步校验（parseAsync）等强交互特性，将核心能力高度聚焦于 **LLM Tool Calling** 的结构化验证、并行错误回溯以及面向大模型的 JSON Schema 自动导出。
3. **演进式类型系统规划（向后兼容）**：当前以动态 `Json` 作为底层的强鲁棒承载体，同时对 MoonBit 的元编程能力保留前瞻性入口。未来计划引入 `derive(ZodSchema)` 宏机制，打通动态运行时校验与静态强类型 Struct 之间的壁垒。