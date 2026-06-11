# MoonZod 开发历程回顾

> **项目**: moon_zod — MoonBit 运行时 JSON Schema 校验库
> **参赛赛道**: 2026 MoonBit × CCF 国产基础软件开源大赛
> **项目地址**: https://github.com/Betterlol/moon_zod
> **版本**: v0.4.0 | **测试**: 206 项, 0 警告 | **外部依赖**: 0

---

## 一、为什么做 MoonZod？

### 1.1 问题发现

2025 年底，我在使用大语言模型（LLM）的 Tool Calling 功能时，反复遇到同一个痛点：

LLM 输出 JSON 时，总是会"脑补"多余的字段、漏掉必填字段、搞错字段类型。传统的校验库要么在第一个错误就"报错停摆"（fail-fast），要么对幻觉字段无动于衷。而在 LLM 的 self-correction 工作流中，我们需要的是：**一次性收集所有错误**、**自动清洗幻觉字段**、**将错误反馈给模型进行下一轮修正**。

TypeScript 生态有 Zod，Python 有 Pydantic，但 MoonBit 生态里没有这样的库。

### 1.2 目标定义

我决定用 MoonBit 写一个运行时 JSON Schema 校验库，核心目标只有一个：

> **为 LLM Tool Calling 的结构化输出校验而设计。**

不追求包罗万象，而是专注做好三件事：

1. **全量错误收集** — 一次 parse 收集所有字段的校验错误，用于 LLM self-correction
2. **幻觉字段防御** — 默认 Strip 模式，静默移除 LLM 脑补的字段
3. **精确路径定位** — 每个错误附带 `users[0].profile.email` 这样的精确路径

---

## 二、从 Zod 和 Pydantic 借鉴了什么，舍弃了什么

### 2.1 借鉴

- **API 风格**: Zod 的链式调用 `string().min(3).max(50)` — 直觉友好
- **Schema 组合**: Zod 的对象/数组/联合类型组合方式
- **错误收集而非 fail-fast**: Pydantic 的 `pydantic.ValidationError` 能一次性收集所有错误

### 2.2 舍弃（设计哲学）

| Zod/Pydantic 的特性 | MoonZod 的处理 | 理由 |
|---|---|---|
| 类型推演（`z.infer`） | 不做 | MoonBit 宏未成熟，不堆砌代码生成 |
| 异步校验 | 不做 | 保持 WASM 运行时极致速度，纯同步 |
| 数据库 ORM/GQL 绑定 | 不做 | 保持核心库 0 外部依赖 |
| Strict 默认模式 | 改为 **Strip 默认** | LLM 幻觉字段是主要痛点 |

如果不做这个取舍，MoonZod 就只是 Zod 的又一个"移植版"。但 LLM 场景对 Strip 模式有天然需求——传统校验库默认允许未知字段通过（Passthrough），这在 LLM 场景等于把幻觉数据喂给下游。

---

## 三、关键架构决策与演进

### 3.1 装饰器穿透（Phase 4）— 最关键的 50 行代码

```mbt
pub fn append_rule(schema, check, message) -> Schema {
  match schema.schema_type {
    OptionalType(inner)  => 递归到 inner，新建 OptionalType 包裹
    DefaultType(inner,_) => 递归到 inner，新建 DefaultType 包裹
    _ => 直接追加到 rules
  }
}
```

这 50 行代码解决了看似简单的问题：`string().optional().min(3)` 为什么能正确工作？

没有 `append_rule` 之前，`optional()` 返回的 OptionalType 会"隔离"后面的 `.min(3)`，规则被加到了错误的层级。`append_rule` 的"装饰器穿透"机制，递归穿透 OptionalType/DefaultType 等包装类型，将规则落在最内层的真实类型上。

这个设计的灵感来自 Python 装饰器模式——但不是对函数装饰，而是对 Schema 类型进行"递归穿透装饰"。

### 3.2 可变路径栈（Phase 5）— 成功路径零堆分配

这是性能上最关键的决定。初始实现中，每个嵌套层级都拼接字符串：

```mbt
// 早期实现：每次递归都分配字符串
fn parse_object(schema, json, path: String) {
  parse_inner(val, path + "." + key)  // 堆分配！
}
```

LLM Tool Calling 中，**成功才是常态**（模型大部分时候输出正确的 JSON），失败是少数。这意味着每 parse 一次就要多次分配路径字符串——而大部分分配最终用不上。

优化方案：改用共享的可变数组 `Array[String]`，只在不成功时才拼接字符串。

```mbt
// Phase 5 优化：共享路径栈
fn parse_object(schema, json, path_stack: Array[String]) {
  path_stack.push(key)    // O(1) 栈操作
  let result = parse_inner(val, path_stack)
  let _ = path_stack.pop()
}
```

这个优化使得成功路径上**零字符串分配**。在 100k 次有效校验的基准测试中，MoonZod 取得了 **3.8M ops/sec**，大约是 TS Zod（0.24M ops/sec）的 **15x**。差距的核心原因之一就是路径栈的零分配设计。

### 3.3 Strip 默认模式（Phase 2/5）— LLM 幻觉防御

传统校验库默认 Pass-through（允许未知字段）。但在 LLM 场景，这意味着：

```json
{
  "name": "商品名称",
  "price": 100,
  "llm_hallucinated_field": "这是模型脑补的数据"  // ← 无声污染
}
```

MoonZod 反其道而行：**默认 Strip**。parse 时只收集 spec 中定义的字段，其余字段静默丢弃。嵌套对象也能正确递归剥离，因为存储的是递归 parse 后的值。

这个决策让下游业务逻辑永远拿到干净、确定、严格符合 Schema 的数据。

### 3.4 Transform 管线（Phase 13）— 从校验器到数据管道

v0.2.0 引入的 `.transform(fn)` 让 MoonZod 从纯校验器进化为数据变换管线：

```mbt
string().transform(fn(json) {
  match json {
    String(s) => Ok(Json::String(s.trim()))
    _ => Err("expected string")
  }
})
```

关键设计决策是 `TransformClosure` 结构体包裹函数类型，避免 enum 变体直接持有函数类型——这是一次编译失败后的教训。

### 3.5 schema_to_prompt()（Phase 16-17）— 闭合 LLM 工作流

v0.2.3 和 v0.3.0 分别引入了 `schema_to_prompt()` 和 `.describe()`，使得从 Schema 到 LLM Prompt 的转化完全自动化：

```
Schema (MoonBit)  →  schema_to_prompt()  →  TypeScript Interface  →  LLM
                                                                            ↓
                              schema.parse()  ←  LLM 返回 JSON  ←──────────┘
```

LLM 收到的不再是手写的、容易过时的 prompt，而是从 Schema 自动生成的、带有约束注释和字段描述的精确类型描述。

---

## 四、AI 工具的使用方式

### 4.1 编码助手协作模式

整个开发过程中，我大量使用 AI 编码助手（基于大语言模型的 Agent 工具）来辅助开发。具体协作方式如下：

**阶段一：设计讨论** — 在写第一行代码前，我和 AI 助手进行了多轮架构讨论：
- "MoonBit 的 enum 和 struct 系统如何建模 Schema 类型？"
- "如何处理 OptionalType 的规则链穿透？"
- "如何在 MoonBit 的 Result 模式下优雅收集错误？"

这些讨论帮助我快速排除了几个错误方向（比如早期的 Wrap/Unwrap 模式），直接走向 `append_rule` / `inner_type` 方案。

**阶段二：代码生成** — AI 助手负责生成以下类型的代码：
- 工厂函数和规则方法（string.mbt, number.mbt 等）— 模式固定，适合批量生成
- 测试用例（moon_zod_test.mbt 中的大量边界测试）
- 文档和 README

**阶段三：重构与调试** — 当编译错误或测试失败时，我将错误信息贴给 AI，由其分析根因并生成修复方案。Phase 5 的路径栈重构就是一个典型例子——手动推演所有递归分支的 push/pop 平衡是容易出错的，AI 帮助系统性地检查了每个 parse helper 的路径栈不变性。

### 4.2 AI 协助的边界

尽管 AI 辅助了大部分编码工作，但以下决策始终由人做出：
- **架构方向**: Strip 默认、路径栈零分配、装饰器穿透——这些核心设计都是人类深思熟虑的结果
- **API 设计**: 函数命名、参数顺序、返回值类型——需要开发者品味和一致性判断
- **测试策略**: 什么场景需要黑盒测试 vs 白盒测试 vs 快照测试
- **版本发布**: 语义化版本号、向下兼容性边界、发布范围

我的体会是：**AI 是优秀的"执行者"和"讨论伙伴"，但"设计师"的角色必须由人承担。**

### 4.3 MoonBit 特定陷阱

使用 MoonBit 开发的过程中遇到了一些语言特有的痛点，记录在此，供其他开发者参考：

1. **pub vs pub(all)** — MoonBit 默认 `pub` 是包内可见，`pub(all)` 才是外部可见。前期大量函数暴露错了作用域。
2. **Show trait 弃用** — Phase 12 时 `println(json)` 产生 30+ 弃用警告，全部改为 `@debug.to_string(json)`。
3. **enum 不能直接持有函数类型** — Phase 13 时 `TransformType` 需要 `TransformClosure` 结构体包装。
4. **wasm target 限制** — WASM 只导出 `_start` 和 `memory`，跨语言 benchmark 必须通过子进程 + CLI 参数分发。

---

## 五、项目演进与数据

### 5.1 22 个 Phase 概览

| Phase | 主题 | 关键决策 | 测试数 |
|---|---|---|---|
| 1 | 核心类型 + 基础校验器 | `inner_type` 规则穿透 | — |
| 2 | Object 三种模式 | Strip 默认 | — |
| 3 | Optional/Default/Enum/Union | 包装类型清空 rules | — |
| 4 | JSON Schema 导出 + 重构 | `append_rule` 穿透机制 | — |
| 5 | 可变路径栈 + Strip | 成功路径零堆分配 | 74 |
| 6-7 | Benchmark + 跨语言对比 | ~15x 快于 TS Zod | 74 |
| 8 | v0.1.0 发布 | API 冻结，边界修复 | 74 |
| 9 | 健壮性基准 + 教育 Agent | 3 项基准套件 | 74 |
| 10-11 | json2schema CLI | `@env.args()` 参数分发 | 74 |
| 12 | 零警告清理 | 全部警告归零 | 74 |
| 13 | `.transform()` 管线 | TransformClosure 包装 | 85 |
| 14 | Bench 重构 | `@bench` 迁移 | 85 |
| 15 | JSON Schema 约束导出 | 注解合并 + 骨架导出 | 95 |
| 16 | `schema_to_prompt()` | TS Interface 自动生成 | 112 |
| 17 | `.describe()` 字段描述 | 结构体展开传播 | 120 |
| 18 | Intersection 类型组合子 | `IntersectionType` + `allOf` + `&` prompt | 149 |
| 19 | 自定义错误消息 (v0.4.0) | `msg?` 参数 + `.message()` 方法 | 171 |
| 20 | 增强验证器集 | `startsWith`/`endsWith`/`includes`/`uuid`/改进 email | 189 |
| 21 | Schema 组合子 | `pick`/`omit`/`partial` | 206 |
| 22 | 代码质量清理 | 死代码修复 + description 传播 + 交并拆包 + 测试拆分 | 206 |

### 5.2 关键数据

- **62 次提交**，覆盖 22 个开发 Phase
- **206 项测试**（202 黑盒 + 4 白盒），全部通过
- **0 编译器警告**
- **0 外部依赖**（仅 `moonbitlang/core`）
- **15 个核心模块**（含 `intersection.mbt`、`prompt.mbt`），3 个 CLI 工具，5 个示例
- **性能**: 3.8M ops/sec（~15x TS Zod）
- **CI**: GitHub Actions（fmt check → native build → wasm build → test）

### 5.3 遇到的主要困难

1. **MoonBit 早期版本的不稳定性** — 开发过程中 MoonBit 经历了从 0.7 到 0.9 的多个版本，部分 API（如 `println` → `@debug.to_string`）发生过破坏性变更。这要求在 Phase 12 进行大规模的代码迁移。

2. **路径栈不变性的验证** — Phase 5 引入共享路径栈后，需要保证每个 parse helper 的 push/pop 严格平衡。缺少白盒测试时，这是一颗定时炸弹。Phase 13 补充了 4 个路径栈白盒测试才彻底解决。

3. **注解合并的复杂性** — Phase 15 的 JSON Schema 约束导出中，多个规则注解需要正确合并（如 `number().int().positive().multipleOf(2)` 产生包含 `"type": "integer"`、`"exclusiveMinimum": 0`、`"multipleOf": 2` 的单一 Schema 对象）。采用后写覆盖策略，使 `int()` 的注解正确覆盖 `number()` 的 `"type": "number"`。

4. **装饰器传播的完整性** — 每次新增包装类型（TransformType）时，需要同步更新 `append_rule`、`inner_type`、`to_json_schema`、`schema_to_prompt` 四个位置的穿透逻辑。这成为一个容易遗漏的模式。

5. **`append_rule` 中 description 的静默丢失** — Phase 17 在 `append_rule_with_annotation` 的 OptionalType/DefaultType/TransformType 穿透分支中使用了 `description: ""` 而非 `description: schema.description`。这意味着通过装饰器链式调用（如 `string().min(3).optional()`）时，`.describe()` 设置的描述会在 `optional()` 之后的规则调用中静默丢失。Phase 22 的代码审查中才发现并修复了这个积累的 bug。

---

## 六、心得体会

### 6.1 关于 MoonBit

MoonBit 是一门"有性格"的语言。它的函数式倾向（Result 模式、模式匹配）、严格的作用域控制（pub/pub(all)）、以及 WASM 原生支持，使得写出来的代码天然具有高可靠性和可维护性。

但 MoonBit 生态仍处于早期阶段——标准库覆盖不完整、调试工具不成熟、部分语法糖缺失。作为生态建设者，我的态度是：**不要等生态成熟再开始，而是通过贡献来推动生态成熟。**

### 6.2 关于 AI 辅助开发

这 17 个 Phase 的开发验证了一个假设：**在人类把控架构方向的前提下，AI 可以将开发效率提升数倍。** 核心模块（14 个 .mbt 文件，约 2000 行）的实际开发时间大约是 4-6 周的零散时间投入，如果纯手动编码，估计需要 2-3 个月。

但 AI 不是银弹。以下场景更需要人类判断：
- **权衡取舍**: Strip vs Passthrough 默认模式的选择涉及哲学层面的判断
- **API 品味**: `describe()` vs `description()` 这样的命名决策
- **测试策略**: 快照测试 vs 断言测试的选择

### 6.3 对开源工作的借鉴

MoonZod 站在 Zod 和 Pydantic 的肩膀上。但我们不是简单地"把 TypeScript/Python 的概念翻译成 MoonBit"，而是根据 LLM Tool Calling 这一特定场景进行了重新设计：

- **Strip 默认模式** — 如果只是移植 Zod，不会想到这个设计。这是在真实 LLM 使用中反复被幻觉字段困扰后的"场景驱动创新"。
- **路径栈零分配** — 传统校验库很少在性能上做到这个程度。但在 LLM 的高频 Tool Calling 循环中，每一个微秒都影响用户体验。
- **schema_to_prompt()** — 这是 Zod/Pydantic 都没有的功能。它不是"校验"的范畴，但它是"LLM 工作流"中不可或缺的一环。

---

## 七、未来方向

当前 MoonZod（v0.4.0）已经具备生产基本能力，但仍有改进空间：

1. ✅ ~~**自定义错误消息** — v0.4.0 已实现，支持 `msg?` 参数和 `.message()` 方法，使 self-correction loop 更精准~~
2. ✅ ~~**Schema 组合器** — `pick()`, `omit()`, `partial()` 已在 v0.4.0 实现，支持从已有 schema 派生子集~~
3. ✅ ~~**增强验证器** — `.uuid()`, `.startsWith()`, `.endsWith()`, 改进的 `.email()` 已在 v0.4.0 实现~~
4. **derive 宏** — 当 MoonBit 宏系统成熟时，从 struct 自动生成 Schema（等待 MoonBit 宏系统稳定）
5. **Schema 描述自动传播至 JSON Schema** — 当前 `.describe()` 仅影响 `schema_to_prompt()` 输出，未写入 JSON Schema 的 `description` 字段
6. **性能基准更新** — 测试已增至 206 项，跨语言基准需在更多硬件上验证 15x 结论

---

*本文章撰写于 2026 年 6 月，作为 MoonBit × CCF 开源创新大赛验收材料的一部分。*

*项目 GitHub: https://github.com/Betterlol/moon_zod*
