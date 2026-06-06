# moon_zod 设计文档

## 项目定位

MoonBit 版的 Zod/Pydantic——一个**运行时 JSON Schema 校验库**，核心场景是为 LLM Tool Calling 的输出做结构化校验和错误回溯。

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

## 实施阶段

### Phase 1：核心类型 + 基础校验器

**文件**: `schema.mbt` / `types.mbt`

定义核心类型系统：

```
Schema[T]     — 校验器 trait/struct，携带校验规则
ValidationError — 错误类型，包含 field path + message + 期望值/实际值
SchemaResult[T] — type alias for Result[T, Array[ValidationError]]
```

基础校验器工厂函数：

| 函数 | 规则链方法 |
|---|---|
| `string()` | `.min(n)` `.max(n)` `.email()` `.url()` `.regex(pattern)` `.nonempty()` |
| `number()` | `.min(n)` `.max(n)` `.int()` `.positive()` `.negative()` `.multipleOf(n)` |
| `boolean()` | (无链式规则) |
| `null()` | — |
| `array(schema)` | `.min(n)` `.max(n)` `.nonempty()` |
| `object(spec)` | 见下 |

**关键设计决策**：
- 每个 Schema 是一个 struct，内部存储 `rules: Array[Rule]`。Rule 是一个函数类型 `(Json) -> Result[Json, ValidationError]`。
- 链式调用 `.min(2).max(10)` 只是往 rules 里 push 新 rule，返回 self。
- `parse(json)` 遍历 rules 依次执行。

### Phase 2：Object Schema 与字段级错误

**文件**: `object.mbt`

```mbt
pub fn object(spec: Map[String, Schema]) -> Schema
```

- parse 时遍历 spec 的每个 key，用对应 Schema 校验。
- 收集所有字段的错误，而非 fail-fast（一次性返回所有错误，方便 LLM 修正）。
- 支持 `.strict()`（拒绝未在 spec 中定义的字段）和 `.passthrough()`（默认，保留额外字段）。

### Phase 3：高级特性

- **可选字段**：`.optional()` → 值为 Null 或缺失时跳过校验。
- **默认值**：`.default(value)` → 缺失时填充默认值。
- **枚举校验**：`.enum(["a", "b", "c"])`。
- **联合类型**：`.union([schema1, schema2])` → 任一通过即成功。
- **自定义规则**：`.refine(fn) →` 用户注入自定义校验逻辑。
- **JSON Schema 导出**：`schema.to_json_schema()` → 输出标准 JSON Schema 字符串，可供 LLM 直接使用。

### Phase 4：Polish + JSON Schema 导出

- **错误收集**：`parse_object` 一次性收集所有字段错误而非 fail-fast，便于 LLM 一次性修正。
- **`append_rule` / `inner_type`**：实现装饰器穿透机制，令 `.optional().min(3)` 正确落在内层 Schema 上。
- **JSON Schema 导出**：`to_json_schema(schema)` 递归遍历 Schema 树，输出标准 JSON Schema 对象。
- **`parse_inner` 隐藏**：重构 parse 路由，`parse_inner` 从公共接口移除。

### Phase 5：可变路径栈 + Strip 模式

- **可变路径栈**：`Array[String]` 在 parse 树中共享，进入子结构 `push` / 返回 `pop`，仅在产生 `ValidationError` 时才调用 `format_path()` 拼接字符串。成功路径**零堆分配**。
- **Strip 默认模式**：`object()` 默认 Strip 模式，parse 后只返回 spec 定义的字段，嵌套对象递归剥离。
- **Union 错误聚合**：所有分支失败时聚合各分支首个错误消息，而非只返回最后一个。

### Phase 6：LLM 自愈 Demo + 基准测试

- **`examples/llm_agent/`**：5 步 LLM 工具调用自纠错闭环（定义 Schema → LLM 输出 → 校验 → 格式化反馈 → 重试），含 Strip 模式演示。
- **`cmd/main/`**：复杂嵌套 Schema × 10 万次迭代基准测试。
- **README 全面翻新**：API 参考、Benchmark 数据、LLM 自愈示例。

### Phase 7：跨语言基准测试

- **`cmd/wasm/`**：WASM 可执行包，CLI 参数分发模式（moonzod / handcrafted / verify / startup）。
- **`bench_cross_lang/`**：Node.js 编排器，三路对比（TS Zod × MoonZod Wasm × Handcrafted Match），扣除 ~12.8ms 进程启动开销。
- **结果**：Handcrafted Match ~10.8x 快于 MoonZod（通用库 vs 状态机）。

### Phase 8：健壮性增强 + v0.1.0 发布

- **边界 case 修复**：空 spec 正确处理、空数组提前返回、missing field 错误收集。
- **测试覆盖到 74 个**：零外部依赖，API 冻结。
- **发布 v0.1.0**：GitHub Release + CI（GitHub Actions fmt → build → test）。

### Phase 9：健壮性基准套件 + 教育 Agent

- **基准扩展为 3 项**：Valid Throughput (100k) + Adversarial Hallucination (50k) + Extreme Redundancy (50k)。
- **`examples/educational_agent/`**：3 轮 LLM 自纠正循环（类型错误 → 规则违例 → Strip 清洗），验证路径栈在 200k 总迭代中的稳定性。

### Phase 10：JSON-to-Schema 代码生成器

- **`cmd/json2schema/`**：递归遍历 JSON AST，自动生成 `@moon_zod.object({...})` 源码。零外部依赖。
- 含 CLI 参数解析、`--help`、`escape_mbt_string()` 键名安全转义、空数组 `/* TODO */` 提示。

### Phase 11：生产级 CLI 升级

- `@env.args()` 取代硬编码 mock，优雅处理无效 JSON 和缺失参数。
- 因 WASM 无文件系统 I/O（无 `@fs` 模块），采用内联 JSON 字符串参数。

### Phase 12：零警告清理 + QoL 糖

- 消除全部编译警告（unused `self`、unreachable code、Show deprecation × 30+）。
- `ValidationError::to_string()` 便利方法。
- README 新增 JSON-to-Schema Generator 章节。

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
├── json_schema.mbt        # to_json_schema() 导出
├── moon_zod.mbt           # 包级文档注释
├── moon_zod_test.mbt      # 黑盒测试（74 tests）
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
├── step_phase_summary.md  # Phase 1-12 合并总结
├── summary_handover.md    # 项目交接文档
├── DESIGN.md              # 本文件（架构设计）
├── README.mbt.md          # 用户 README
└── AGENTS.md              # Agent 工作指南
```

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
