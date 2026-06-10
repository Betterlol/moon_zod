# moon_zod 设计文档

## 项目定位

MoonBit 版的 Zod/Pydantic——一个**运行时 JSON Schema 校验库**，核心场景是为 LLM Tool Calling 的输出做结构化校验和错误回溯。

> #### 设计哲学与战略优势 (Design Philosophy & Strategic Advantages)
> `moon_zod` 不追求成为一个包罗万象的通用数据验证框架，而是致力于成为**最适合 LLM 智能体（Agent）运行时的结构化数据引擎**。我们的核心优势建立在以下三个不可妥协的架构基石之上：
> 1. **LLM 幻觉防御优先 (Native Defense Against Hallucination)**
> * 与传统校验库默认的严格（Strict）或放行（Passthrough）模式不同，`moon_zod` 的 `object()` 默认采用 **Strip（清洗）模式**。
> * 这一设计是专门针对大语言模型常常“自行脑补”输出多余字段的痛点。我们以 $O(spec)$ 的复杂度进行数据提取，确保下游业务逻辑接管到的永远是干净、确定、严格符合定义的 Schema 数据。
> 2. **极致的性能与惰性路径格式化 (Lazy Path Formatting)**
> * 在自主智能体的高频 Tool Calling 循环中，校验层决不能成为性能瓶颈。
> * `moon_zod` 的核心路由 `parse_inner` 通过共享可变路径栈 (`path_stack: Array[String]`)，实现了在成功校验路径上的**零字符串格式化开销**——路径拼接仅在真正产生错误时才触发，无论嵌套层级多深。
> 3. **极简 API 与无缝组合 (Minimalist DX & Penetration)**
> * 拒绝复杂的泛型体操和冗长的配置声明。利用独特的 `append_rule` 装饰器穿透机制，使得 `string().optional().min(3)` 等链式调用能够符合开发者的直觉，保持代码的极度扁平与优雅。

> #### 明确的非目标 (Explicit Non-Goals)
> 为了维持 `moon_zod` 的轻量级与专注度，以下特性被明确排除在我们的核心演进路线之外：
> * **拒绝重型生态绑定**：我们不会在核心库中引入针对特定数据库 ORM（如 SQL 构造）或 GraphQL 的转换逻辑，保持 0 外部依赖。
> * **拒绝异步校验 (Async Validation)**：为了保持 WASM 运行时的极致执行速度和架构的简单性，`moon_zod` 坚持纯同步校验。涉及网络请求的异步验证应交由上层业务逻辑处理。
> * **拒绝臃肿的类型推演**：在 MoonBit 宏系统完全成熟之前，我们不会用过度复杂的代码生成去强行模拟类似 TypeScript `z.infer` 的行为，避免破坏当前的极简编译体验。作为现阶段的替代方案，我们通过提供 json2schema CLI 工具来实现“从数据到 Schema”的极速生产力闭环。

---

## API 设计目标

```mbt
// 最终用户代码风格
let schema = @moon_zod.object({
  "name": @moon_zod.string().min(2).max(50),
  "age": @moon_zod.number().int().min(0).max(150),
  "email": @moon_zod.string().email(),
})

let result = schema.parse(json_data)
// result: Result[Json, Array[ValidationError]]
```

---

## 开发阶段总览

完整阶段记录见 [`step_phase_summary.md`](./step_phase_summary.md)（详细总结，含每个阶段的文件变更、关键决策、产出指标）。

简明对照：

| Phase | 主题 | 核心产出 |
|---|---|---|
| 1 | 核心类型 + 基础校验器 | Schema 类型系统、string/number/boolean/null/array/refine |
| 2 | Object 三种模式 | Strip（默认）/ Passthrough / Strict |
| 3 | 组合子 | optional / default / enum / union |
| 4 | JSON Schema 导出 | `to_json_schema()` + `append_rule`/`inner_type` 穿透 |
| 5 | 可变路径栈 | 成功路径零堆分配 + Strip 默认模式 |
| 6 | 场景演示 | `examples/llm_agent/` + `cmd/main/` 基准 |
| 7 | 跨语言对比 | `cmd/wasm/` + `bench_cross_lang/`（Zod × MoonZod × Handcrafted） |
| 8 | v0.1.0 发布 | 边界修复、74 测试、API 冻结 |
| 9 | 健壮性基准 + 教育 Agent | 3 项基准 + `examples/educational_agent/` |
| 10 | JSON-to-Schema 生成器 | `cmd/json2schema/` CLI |
| 11 | 生产级 CLI 升级 | `@env.args()` + 键名转义 + 错误处理 |
| 12 | 零警告清理 + QoL 糖 | 全部警告归零 + `ValidationError::to_string()` |
| 13 (v0.2.0) | 路径栈白盒测试 + `.transform()` 管线 | 4 白盒测试 + `Schema::transform()` 数据变换 |
| 14 | Bench 重构 + 示例优化 | `@bench` 库迁移 + `examples/real_llm_agent/` 重构成 CLI |
| 15 (v0.2.2) | JSON Schema 完整约束导出 | `to_json_schema()` 带约束注解 + `to_json_schema_skeleton()` 骨架导出 |

---

## 核心架构设计

### 1. parse 路由 + 可变路径栈

```
Schema::parse(json)                   ← 公共入口，创建 path_stack
  └─ parse_inner(schema, json, stack) ← 内部转发枢纽（非 pub）
       ├─ parse_object()              ← push/pop 字段名
       ├─ parse_array()               ← push/pop [索引]
       ├─ parse_optional()            ← 直接传递 stack
       ├─ parse_default()             ← 直接传递 stack
       ├─ parse_transform()           ← 先校验 inner，再应用变换
       ├─ parse_enum()                ← format_path 后报错
       ├─ parse_union()               ← 直接传递 stack
       └─ 基本类型检查                ← format_path 后报错
```

路径栈 (`Array[String]`) 在所有 parse helper 间共享，进入子结构 `push` / 返回 `let _ = pop()`。仅在产生 `ValidationError` 时调用 `format_path(stack)` 拼接字符串。**成功路径零堆分配**。

### 2. append_rule — 装饰器穿透

```mbt
pub fn append_rule(schema, check, message) -> Schema {
  match schema.schema_type {
    OptionalType(inner)  => 递归到 inner，新建 OptionalType 包裹
    DefaultType(inner,_) => 递归到 inner，新建 DefaultType 包裹
    _ => 直接追加到 rules
  }
}
```

使 `string().optional().min(3)` 的 `min(3)` 规则穿透 OptionalType 落在 StringType 上。

### 3. Strip 默认模式

`object()` 默认 `Strip` 模式。parse 成功后只返回 spec 定义的字段（已递归校验清洗的值），未定义字段静默移除。嵌套对象递归剥离。

### 4. Union 错误聚合

所有分支失败时，聚合各分支第一个错误消息：
```
"Expected union type, but all branches failed. Branches: [Expected string, Expected number]"
```

### 5. JSON Schema 导出

`to_json_schema()` 递归遍历 SchemaType：
- OptionalType/DefaultType → 透明穿透（不产生 `oneOf`）
- Strip/Passthrough → `"additionalProperties": true`
- Strict → `"additionalProperties": false`

### 6. WASM CLI 参数分发

MoonBit wasm target 只导出 `_start` 和 `memory`。`cmd/wasm/` 通过 `@env.args()[1]` 分派模式（moonzod / handcrafted / verify / startup），Node.js 编排器用 `execFileSync` 调用。

---

## 项目结构

```
moon_zod/
├── types.mbt              # ValidationError, SchemaResult
├── schema.mbt             # SchemaType / Schema / ObjectMode / Rule / parse 入口
├── string.mbt             # string() + 规则链
├── number.mbt             # number() + 规则链
├── boolean.mbt            # boolean()
├── null.mbt               # null()
├── array.mbt              # array() + parse_array
├── object.mbt             # object() + strict/passthrough/strip / parse_object
├── union.mbt              # optional / default / enum_values / union
├── refine.mbt             # refine() 自定义规则
├── transform.mbt          # transform() 数据变换管线
├── json_schema.mbt        # to_json_schema() 导出
├── moon_zod.mbt           # 包级文档注释
├── moon_zod_test.mbt      # 黑盒测试（81 tests）
├── moon_zod_wbtest.mbt    # 白盒测试（4 tests）
│
├── cmd/main/              # 基准测试入口
├── cmd/wasm/              # WASM 跨语言对比基准
├── cmd/json2schema/       # JSON-to-Schema 代码生成器 CLI
│
├── examples/llm_agent/        # LLM 工具调用自愈演示
├── examples/educational_agent/ # AI 教育 Agent 3 轮自纠正演示
│
├── bench_cross_lang/      # Node.js 三路对比编排器
├── step_phase_details/    # 各阶段详细总结
├── step_phase_summary.md  # Phase 1-13 合并总结
├── summary_handover.md    # 项目交接文档
├── DESIGN.md              # 本文件（架构设计）
├── README.mbt.md          # 用户 README
└── AGENTS.md              # Agent 工作指南
```

---

## Demo/Example 编写规范

### Real LLM vs Mock 选择标准

| 场景 | 方式 | 原因 |
|---|---|---|
| `examples/` 展示 | **Real LLM** | 给别人看的 demo，真实调用才有说服力 |
| `moon_zod_test.mbt` 单元测试 | **Mock** | 确定性、快、不依赖网络、不花 API 费用 |
| CI / 回归测试 | **Mock** | 精确覆盖边界 case，LLM 不定输出 |
| Benchmarks | **Mock** | 控制变量，排除网络延迟干扰 |

**原则**：`examples/` 面向读者，应该调真 LLM 展示项目价值；测试面向开发者，保持 mock 确保确定性和速度。

---

## MoonBit 编码要点

1. **Block 风格**：每个公共函数/类型前用 `///|` 分隔，顺序无关。
2. **Result 模式**：所有可能失败的校验返回 `Result[Json, Array[ValidationError]]`，不要 raise。
3. **Trait 扩展**：利用 MoonBit 的 `derive` 机制，未来可考虑 `derive(ZodSchema)` 的宏（Phase 5+）。
4. **测试优先**：每个 rule 的实现 → 立即写 test（`_test.mbt` 测公开 API，`_wbtest.mbt` 测内部 helper）。
5. **提交前**：始终 `moon info && moon fmt`，检查 `.mbti` 变更是否符合预期。

---

## 参考

- [Zod](https://zod.dev/) — TypeScript 版参考 API
- [Pydantic](https://docs.pydantic.dev/) — Python 版参考
- MoonBit core `@json` 包 — 了解当前 JSON 类型系统
