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

## 开发阶段总览

完整阶段记录见 [`step_phase_summary.md`](./step_phase_summary.md)（Phase 1-13 详细总结，含每个阶段的文件变更、关键决策、产出指标）。

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
