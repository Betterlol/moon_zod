# moon_zod 开发阶段总结 (Phase 1–13)

> 本项目为 MoonBit 语言实现的 JSON Schema 运行时校验库，灵感来自 Zod/Pydantic。
> 以下按阶段总结每个 Phase 的核心交付物、关键设计决策及文件变更。

---

## Phase 1 — 核心类型与基础校验器

**目标**: 搭建 Schema 类型系统和基本校验骨架。

| 新增文件 | 用途 |
|---|---|
| `types.mbt` | `Schema` 枚举（Object/Array/String/Number/Boolean/Null/Union）+ `ValidationError` 结构体 + `SchemaResult` 类型 |
| `schema.mbt` | `parse()` 路由枢纽，`append_rule()` 规则链机制，`inner_type()` 穿透包装类型 |
| `string.mbt` | `string()` 工厂 + 规则 chain（min/max/nonempty/email/url/regex） |
| `number.mbt` | `number()` 工厂 + 规则 chain（int/positive/negative/multipleOf/min/max） |
| `boolean.mbt` | `boolean()` 工厂 |
| `null.mbt` | `null()` 工厂 |
| `array.mbt` | `array(Schema)` 工厂 + `parse_array` 逐元素校验 |
| `refine.mbt` | `refine(check, msg)` 自定义规则 |

**关键决策**: 用 `inner_type()` 规则穿透替代早期 Wrap/Unwrap 模式，使 `.optional().min(3)` 链式调用正确工作。

---

## Phase 2 — 对象校验与三种模式

**目标**: 实现 `object()` 校验器及其三种字段处理模式。

| 文件 | 变更 |
|---|---|
| `object.mbt` | `object(Map)` 工厂 + Strip（默认）/ Passthrough / Strict 三种模式 |
| `types.mbt` | 新增 `ObjectMode` 枚举 |

**关键决策**: Strip 模式为默认行为 — O(spec) 遍历 spec 字段，未在 spec 中定义的字段自动静默移除，适用于 LLM 幻觉字段过滤。

---

## Phase 3 — 高级特性：Optional / Default / Enum / Union

**目标**: 补全组合子类型。

| 文件 | 变更 |
|---|---|
| `union.mbt` | `optional()` / `default(value)` / `enum_values(array)` / `union(array)` 四个工厂及其 parse 实现 |
| `types.mbt` | 扩展 `Schema` 枚举新增四个变体 |

**关键决策**: `optional()` 和 `default()` 包裹内层 Schema 后清空 `rules`，后续链式调用 `.min()` 等通过 `append_rule` 穿透到内层。

---

## Phase 4 — JSON Schema 导出与重构

**目标**: 实现 `to_json_schema()` 将内部 Schema 转为标准 JSON Schema 对象 + 代码结构重构。

| 文件 | 变更 |
|---|---|
| `json_schema.mbt` | `to_json_schema(Schema) -> Json` 导出函数 |
| `refine.mbt` | 独立抽取 refine 逻辑 |

**关键决策**: `to_json_schema` 递归遍历 Schema 树，为每种 Schema 变体产生对应的 JSON Schema 片段。

---

## Phase 5 — 性能优化：可变路径栈

**目标**: 消除成功路径上的字符串堆分配。

| 文件 | 变更 |
|---|---|
| `schema.mbt` | 引入 `Array[String]` 可变路径栈，`push`/`pop` 在各 parse 函数间共享 |
| `types.mbt` | 新增 `format_path(Array[String]) -> String` 仅在错误发生时格式化路径 |

**关键决策**: 成功路径零堆分配 — `format_path()` 仅当产生 ValidationError 时才连接路径字符串。

---

## Phase 6 — 场景演示与基准测试

**目标**: 构建首个端到端展示（AI 中文教学平台）和本地基准测试。

| 新增文件 | 用途 |
|---|---|
| `examples/llm_agent/` | LLM 工具调用自纠错闭环展示（5 步：定义 Schema → LLM 输出 → 校验 → 反馈 → 重试） |
| `cmd/main/` | 基准测试入口（10 万次单 Schema 迭代） |

---

## Phase 7 — 跨语言基准测试

**目标**: 与 TypeScript Zod 进行跨语言性能对比。

| 新增文件 | 用途 |
|---|---|
| `cmd/wasm/` | WASM 可执行包 + 手写 match 对比基准 |
| `bench_cross_lang/` | Node.js 三路对比脚本（Zod × MoonZod Wasm × Handcrafted Match） |

**结果**: Handcrafted Match ~10.8x 快于 MoonZod（通用库 vs 状态机）；MoonZod vs TS Zod 因子进程开销非直接对比。

---

## Phase 8 — 健壮性增强与 v0.1.0 发布

**目标**: 补全边界 case、错误处理、测试覆盖。

| 文件 | 变更 |
|---|---|
| `object.mbt` | 修复 `parse_object` 空 spec 正确处理，missing required field 错误收集 |
| `array.mbt` | 修复 `parse_array` 空数组提前返回避免 `inner_type` panic |
| `examples/` | LLM Agent 展示升级：Strip 模式演示 + 幻觉字段清理 |
| `summary_handover.md` | v0.1.0 完整交付文档 |

**产出**: 74 个测试全部通过；零外部依赖；API 冻结。

---

## Phase 9 — 健壮性基准测试与 AI 教育 Agent 展示

**目标**: 扩展基准测试套件 + 构建 3 轮 LLM 自纠正教育场景展示。

| 文件 | 变更 |
|---|---|
| `cmd/main/main.mbt` | 从 1 个基准测试扩展为 3 个：Valid Throughput (100k) + Adversarial Hallucination (50k) + Extreme Redundancy (50k) |
| `examples/educational_agent/` | 新建：CoursePayload Schema + 3 轮 LLM 自纠正循环（类型错误 → 规则违例 → Strip 清洗） |

**关键决策**: 路径栈零分配设计在 200k 总迭代验证中表现稳定；Strip 模式 105 个幻觉字段一键清洗。

---

## Phase 10 — JSON-to-Schema 代码生成器 CLI

**目标**: 构建零依赖 CLI 工具，将 JSON 自动转为 `@moon_zod` 源码。

| 新增文件 | 用途 |
|---|---|
| `cmd/json2schema/main.mbt` | 递归 JSON AST 遍历：`infer_schema()` / `infer_object_schema()` / `infer_array_schema()` |
| `cmd/json2schema/moon.pkg` | 可执行包声明，依赖 `moonbitlang/core/json` |

**关键决策**: 仅推断首个数组元素类型（同构数组假设）；空数组默认 `@moon_zod.string()`。

---

## Phase 11 — 生产级 CLI 升级

**目标**: 将 json2schema 从硬编码 mock 升级为真正的 CLI 工具。

| 文件 | 变更 |
|---|---|
| `cmd/json2schema/main.mbt` | `@env.args()` 参数解析 + `--help` + `escape_mbt_string()` 键名安全转义 + 空数组 `/* TODO */` 注释 + `@json.parse()` 优雅错误处理 |
| `cmd/json2schema/moon.pkg` | 添加 `"moonbitlang/core/env"` 依赖 |

**关键决策**: WASM 无文件系统 I/O（无 `@fs` 模块），采用内联 JSON 参数而非文件读取。

---

## Phase 12 — 零警告清理与 QoL 糖

**目标**: 消除所有编译器警告 + 便利方法 + README 完善。

| 文件 | 变更 |
|---|---|
| `union.mbt` | `self` → `_self` 消除 4 个未使用变量警告 |
| `cmd/wasm/main.mbt` | 移除不可达 `_ => return false` |
| `types.mbt` | 新增 `pub fn ValidationError::to_string()` |
| `moon.pkg` / 各子包 | 添加 `"moonbitlang/core/debug"` 导入 |
| 所有 `main.mbt` 文件 | `println(json)` → `println(@debug.to_string(json))` 消除 Show 弃用警告 |
| `moon_zod_test.mbt` | `assert_eq` → `@debug.assert_eq` |
| `tmp/` 教学文件 | 相同 Show 修复 |
| `README.mbt.md` | 新增 JSON-to-Schema Generator 章节 |

**产出**: `moon build` 0 警告，`moon test` 74/74 通过 0 警告。

---

## Phase 13 — 路径栈白盒测试 + `.transform()` 数据变换管线 (v0.2.0)

**目标**: 从纯校验器进化到数据变换管线，同时为路径栈零分配优化建立自动化安全网。

| 新增文件 | 用途 |
|---|---|
| `transform.mbt` | `Schema::transform(fn)` 方法 + `Schema::parse_transform()` 内部 helper |
| `moon_zod_wbtest.mbt` | 白盒测试：4 个路径栈 invariant 测试（成功/错误路径推入推出平衡） |

| 修改文件 | 变更 |
|---|---|
| `schema.mbt` | `TransformType` 枚举变体、`TransformClosure` 结构体、`append_rule`/`inner_type` 装饰器穿透、`parse_inner` 分发 |
| `json_schema.mbt` | `to_json_schema_inner` TransformType 透明穿透 |
| `moon_zod_test.mbt` | 7 个 transform 黑盒测试（字符串变换、错误处理、optional 链式调用、路径报告） |
| `pkg.generated.mbti` | 新增 `Schema::transform`、`Schema::parse_transform`、`TransformType`、`TransformClosure` |

**关键决策**:
- `TransformClosure` 内部包装 `(Json) -> Result[Json, String]` 函数，避免 enum 变体直接持有函数类型
- `append_rule` 对 TransformType 递归穿透到 inner schema，使 `.transform().min(3)` 正确工作
- `inner_type` 剥离 TransformType，使类型守卫（如 `min()` 识别 StringType）保持正确
- `to_json_schema` 透明穿透 TransformType，因为变换是运行时任意函数，无法用 JSON Schema 表达

**产出**: (81 黑盒 + 4 白盒 = 85) 测试全部通过 0 警告。

---

## 项目当前状态

| 指标 | 数值 |
|---|---|
| 测试数量 | 85（81 黑盒 + 4 白盒） |
| 外部依赖 | 0（仅 `moonbitlang/core`） |
| 编译器警告 | 0 |
| 核心源码模块 | 14 个 `.mbt` 文件 |
| CLI 工具 | 3 个（`cmd/main` 基准, `cmd/wasm` 跨语言, `cmd/json2schema` 代码生成） |
| 展示示例 | 2 个（`llm_agent`, `educational_agent`） |

详情见各 `step_phase_details/step_phase_*.md` 文件。
