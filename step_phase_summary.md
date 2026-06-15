# moon_zod 开发阶段总结

> 本项目为 MoonBit 语言实现的 JSON Schema 运行时校验库，灵感来自 Zod/Pydantic。
> 以下按阶段总结每个 Phase 的核心交付物、关键设计决策及文件变更。

---

## Phase 1 — 核心类型与基础校验器

**目标**: 搭建 Schema 类型系统和四个基础校验器。

| 新增文件 | 用途 |
|---|---|
| `types.mbt` | `ValidationError` 结构体 + `SchemaResult` 类型 |
| `schema.mbt` | `Schema` 结构体、`SchemaType` 枚举（StringType/NumberType/BooleanType/NullType）、`Rule` 类型、`Schema::parse()` |
| `string.mbt` | `string()` 工厂 + 规则 chain（min/max/nonempty/email/url/regex） |
| `number.mbt` | `number()` 工厂 + 规则 chain（int/positive/negative/multipleOf） |
| `boolean.mbt` | `boolean()` 工厂 |
| `null.mbt` | `null()` 工厂 |

**产出**: 28 个基础测试通过。`append_rule`/`inner_type`/`array`/`refine`/`union` 等特性尚未引入。

---

## Phase 2 — 对象校验与两种模式

**目标**: 实现 `object()` 校验器及其两种字段处理模式。

| 文件 | 变更 |
|---|---|
| `object.mbt` | `object(Map)` 工厂 + `.strict()` / `.passthrough()` 链式方法 |
| `schema.mbt` | 新增 `ObjectMode` 枚举（Passthrough/Strict）、`ObjectType` 变体、`collect_errors` 辅助函数 |

**关键决策**: Passthrough 为默认行为（与当时 Zod 行为对齐）。Strip 模式尚未引入（Phase 5 才添加）。10 个新测试，总计 38。

---

## Phase 3 — 高级特性：Optional / Default / Enum / Union

**目标**: 补全组合子类型。

| 新增文件 | 用途 |
|---|---|
| `array.mbt` | `array(Schema)` 工厂 |
| `union.mbt` | `optional()` / `default(value)` / `enum_values(array)` / `union(array)` 四个工厂 |
| `refine.mbt` | `.refine(check, message)` 自定义规则 |

**关键决策**: `optional()` 和 `default()` 包裹内层 Schema 后清空 `rules`，链式调用需在包装之前调用（Phase 4 的 `append_rule` 才解决穿透）。`min()/max()` 扩展支持 `ArrayType`。19 个新测试，总计 57。

---

## Phase 4 — Parse 重构 + JSON Schema 导出

**目标**: 引入 `append_rule`/`inner_type` 规则链穿透机制、提取 parse 辅助函数、实现 `to_json_schema()` 导出。

| 新增文件 | 用途 |
|---|---|
| `json_schema.mbt` | `to_json_schema(Schema) -> Json` 导出函数 |

| 修改文件 | 变更 |
|---|---|
| `schema.mbt` | 新增 `inner_type()`、`append_rule()`；`collect_errors` 改为就地修改；面向 `Schema::parse` 向内部 helper 分发；`sub_path`/`sub_index` 等提升为 `pub` |
| `object.mbt` | 提取 `parse_object()` helper |
| `array.mbt` | 提取 `parse_array()` helper |
| `union.mbt` | 提取 `parse_optional`/`parse_default`/`parse_enum`/`parse_union` helper |
| `string.mbt` | 所有规则方法切换为 `append_rule()`，类型守卫使用 `inner_type()` 解包 Optional/Default |
| `number.mbt` | 同上切换为 `append_rule()` |
| `refine.mbt` | 切换为 `append_rule()` |
| `cmd/main/main.mbt` | 替换 stub 为 10k 迭代基准测试 |

**关键决策**: `append_rule` 递归穿透 OptionalType/DefaultType 装饰器，使 `string().optional().min(3)` 正确工作。`inner_type` 剥离装饰器让类型守卫识别真实类型。11 个新测试，总计 68。

---

## Phase 5 — 性能优化 + Strip 模式

**目标**: 消除成功路径字符串堆分配 + 新增 Strip 字段静默清洗模式。

| 文件 | 变更 |
|---|---|
| `schema.mbt` | 引入 `Array[String]` 可变路径栈 + `format_path()` 错误时延迟格式化 + `parse_inner` 内部递归分发 + `ObjectMode` 新增 `Strip` 变体 |
| `object.mbt` | 默认模式从 Passthrough 改为 Strip；新增 `Schema::strip()` 方法；parse 重写为 push/pop + 构建 `parsed_fields` Map |
| `array.mbt` | parse 重写为 push/pop `[index]` 路径段 |
| `union.mbt` | parse_union 聚合所有失败分支的首次错误消息为 `Branches: [...]` |

**关键决策**: 成功路径零堆分配 — `format_path()` 仅在产生 ValidationError 时才连接路径。Strip 模式为默认（O(spec) 遍历，非 spec 字段静默移除）。6 个新测试，总计 74。

---

## Phase 6 — 场景演示与基准测试升级

**目标**: 构建首个端到端 LLM 自愈展示 + 升级基准测试。

| 新增文件 | 用途 |
|---|---|
| `examples/llm_agent/` | LLM 工具调用自纠错闭环展示（5 步：定义 Schema → LLM 输出 → 校验 → 反馈 → 重试） |

| 修改文件 | 变更 |
|---|---|
| `cmd/main/main.mbt` | 从 10k 复杂 schema 升级为 100k 三用户嵌套数据基准测试 |
| `README.mbt.md` | 全面翻新为产品级 README |

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

**目标**: API 边界清理 + benchmark 数据归档 + 发布封板。

| 文件 | 变更 |
|---|---|
| `schema.mbt` | `parse_inner` 从 `pub fn` 降级为 `fn`（隐藏内部函数） |
| `README.mbt.md` | 添加 Phase 7 跨语言 benchmark 数据表 |
| `pkg.generated.mbti` | 自动重生成，`parse_inner` 不再对外暴露 |

**产出**: 74 个测试全部通过；零外部依赖；API 冻结。`pub` 表面 API 仅为 `schema`/`object`/`string`/`number`/`boolean`/`null`/`array`/`enum_values`/`union`/`to_json_schema` 及各 Schema 方法。

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

## Phase 14 — Bench 重构 + 示例优化 (v0.2.1)

**目标**: 将基准测试从手动循环计时迁移到 MoonBit 官方 `@bench` 标准库，获得校准的 ns/op 指标。

| 文件 | 变更 |
|---|---|
| `cmd/main/main.mbt` | 替换手动 for 循环为 `@bench.bench()` 调用，保留相同 schema/输入；添加合理性检查 |
| `cmd/main/moon.pkg` | 添加 `"moonbitlang/core/bench"` 依赖 |

**关键决策**: `@bench` 自动校准每批迭代次数（约 100ms/样本），Valid ~18.5k/批, Adversarial ~53k/批, Strip ~56k/批。`bench.keep()` 防止 DCE 优化掉 parse 结果。

**产出**: 核心库无变动，85/85 测试通过 0 警告。

---

## Phase 15 — JSON Schema 完整约束导出 (v0.2.2)

**目标**: 实现 `to_json_schema()` 带约束注解（minLength, maximum, pattern, format 等）的完整导出，新增 `to_json_schema_skeleton()` 轻量骨架导出。

| 文件 | 变更 |
|---|---|
| `schema.mbt` | `Rule` 增加 `annotation: Json` 字段；新增 `append_rule_with_annotation()` |
| `string.mbt` | `min`/`max` → minLength/maxLength(minItems/maxItems)；`email` → `format: "email"`；`url` → `format: "uri"`；`regex` → `pattern` |
| `number.mbt` | `int` → `type: "integer"`；`positive` → `exclusiveMinimum: 0`；`negative` → `exclusiveMaximum: 0`；`multipleOf` → `multipleOf: n` |
| `json_schema.mbt` | 新增 `to_json_schema_skeleton()`；重写 `to_json_schema()` 为递归 `to_json_schema_full` + `merge_annotations` |
| `moon_zod_test.mbt` | 8 个新增测试覆盖约束导出和骨架 |

**关键决策**: 非破坏性变更 — 无规则 schema 输出与之前完全一致。`nonempty()` 不产生 `minLength` 注解，避免与更严格的 `min(n)` 冲突。注解合并采用后写覆盖（`map.set`），使 `int()` 正确将 `"type":"number"` 升级为 `"type":"integer"`。

**产出**: 95/95 测试全部通过 0 警告。

---

## Phase 16 — `schema_to_prompt()` TypeScript Interface 生成

**目标**: 填补 LLM 工作流的缺失环节 — 给定 Schema，自动生成 TypeScript-interface 风格的可读类型描述，直接嵌入 system prompt 或修正 prompt。

| 新增文件 | 用途 |
|---|---|
| `prompt.mbt` | `schema_to_prompt()` 及其内部递归辅助（14 个函数，412 行） |

| 修改文件 | 变更 |
|---|---|
| `moon_zod_test.mbt` | 17 个新增测试覆盖所有类型和约束的输出格式 |
| `examples/real_llm_agent/schemas.mbt` | 新增 `prompt` CLI 命令：调用 `schema_to_prompt()` 输出 TS interface |
| `examples/real_llm_agent/core.py` | 新增 `fetch_moon_prompt()` 调用 MoonBit CLI 获取 prompt |
| `examples/real_llm_agent/agent.py` | 新增 `--moon-prompt` / `-p` 标志 |
| `examples/real_llm_agent/README.md` | 重写：显眼的 Mock Demo + 真实 LLM + CLI 使用说明 |
| `README.mbt.md` | 新增 Demo 章节 + `schema_to_prompt` API 参考 + 项目布局更新 |
| `AGENTS.md` | 新增 MoonBit 陷阱章节，链接到 `moonbit_syntax_pitfalls.md` |

**关键决策**:
- 约束注释使用 `[]` 括号格式（`// [min: 2, max: 50]`），与错误消息的 key-value 词汇对齐
- 内联 TypeScript Interface 风格，所有嵌套类型内联展开，不生成独立 interface
- `OptionalType`/`DefaultType`/`TransformType` 通过 `unwrap_schema()` 穿透取最内层规则

**产出**: 112/112 测试全部通过 0 警告。

---

## Phase 17 — `.describe()` 字段描述嵌入 Prompt (v0.3.0)

**目标**: 允许 schema 作者为字段附加人类可读的描述文本，通过 `schema_to_prompt()` 渲染到 LLM prompt 中，使 LLM 除了类型约束外还能理解字段语义。

| 修改文件 | 变更 |
|---|---|
| `schema.mbt` | `Schema` 结构体新增 `description: String` 字段；新增 `pub fn Schema::describe(text)` 方法；`append_rule_with_annotation` 3 个 wrapper 分支添加 `description: ""` |
| `string.mbt` / `number.mbt` / `boolean.mbt` / `null.mbt` | 工厂函数添加 `description: ""` |
| `array.mbt` / `object.mbt` | 工厂函数添加 `description: ""` |
| `union.mbt` | `optional()` / `default()` 传播 `self.description`；`enum_values()` / `union()` 添加 `description: ""` |
| `transform.mbt` | `transform()` 传播 `self.description` |
| `prompt.mbt` | `schema_comment()` 合并约束与描述（`// [constraints] — description`）；`object_to_prompt` 使用 `val_schema` 保留 optional 字段描述 |
| `moon_zod_test.mbt` | 8 个测试：describe 单独、describe+约束、optional、object 字段、嵌套对象、transform |
| `README.mbt.md` | 添加 `.describe()` 到 API 参考表；更新测试计数 |

**关键决策**:
- `.describe()` 使用 `{ ..self, description: text }` 结构体展开，可在链式调用末尾或任意位置调用
- `optional()` / `default()` / `transform()` 自动传播 `self.description`，确保 `describe()` 在 wrapper 之前调用也能正确传递
- 输出格式：有约束时 `// [constraints] — description`，仅描述时 `// description`

**产出**: 120/120 测试全部通过 0 警告。

---

## Phase 18 — Intersection 类型组合子 (Schema::intersect)

**目标**: 实现 `Schema::intersect()` / `IntersectionType` — 要求输入同时满足多个 Schema，对象字段自动合并。

| 修改文件 | 变更 |
|---|---|
| `schema.mbt` | `SchemaType` 新增 `IntersectionType(Array[Schema])` 变体；`parse_inner`/`expected_msg` 分发 |
| `union.mbt` | 新增 `intersection(Array[Schema])` 工厂、`Schema::intersect(Schema)` 方法、`Schema::parse_intersection()` 内部 helper |
| `json_schema.mbt` | `to_json_schema_full`/`to_json_schema_inner` 添加 IntersectionType → `allOf` 分支 |
| `prompt.mbt` | `type_to_prompt` 添加 IntersectionType → `"A & B & C"` 渲染；新增 `intersection_to_prompt` 函数 |
| `moon_zod_test.mbt` | 10 个新测试覆盖：基本解析、对象字段合并、跨类型失败、`.intersect()` 方法、三 Schema 组合、错误收集、JSON Schema allOf、骨架 allOf、prompt 输出、单 Schema |
| `pkg.generated.mbti` | 新增 `intersection`、`Schema::intersect`、`Schema::parse_intersection`、`IntersectionType` |

**关键决策**:
- `parse_intersection` 依次运行每个子 Schema，收集所有错误；若全部成功则合并结果（对象字段用 Map.set 逐 key 合并，非对象保留最后一个解析值）
- `intersect` 用作方法名（`and` 是 MoonBit 关键字，不可用）
- JSON Schema 使用 `allOf` 表达交集约束
- Prompt 使用 `&` 分隔符（`"string & number"`）

**产出**: 149/149 测试全部通过 0 警告；核心源码 ~4012 行覆盖 4k 竞争基准线。

---

## Phase 19 — 自定义错误消息 (v0.4.0)

**目标**: 让调用者能为每个规则覆写错误消息，使 LLM 自修正循环获得语义更精准的反馈。

| 修改文件 | 变更 |
|---|---|
| `string.mbt` | `min`, `max`, `nonempty`, `email`, `url`, `regex` 添加 `msg?: String = ""` 参数 |
| `number.mbt` | `int`, `positive`, `negative`, `multipleOf` 添加 `msg?: String = ""` 参数 |
| `schema.mbt` | 新增 `Schema::message(text)` 方法，穿透 OptionalType/DefaultType/TransformType 覆盖最后一条规则消息 |
| `moon_zod_test.mbt` | 22 个测试：14 个 `msg?` 参数 + 8 个 `.message()` 方法 |

**关键决策**:
- `msg?` 默认 `""`，非空时取代默认消息。零破坏性。
- `.message()` 递归穿透装饰器包装，找到 rules 所在的内层 schema，替换最后一条规则消息
- 两种调用方式等价：`string().min(3, msg="太短")` 与 `string().min(3).message("太短")`

**产出**: 171/171 测试全部通过 0 警告。

---

## Phase 20 — 增强验证器集

**目标**: 填补常用字符串验证器空白，改进 email 校验健壮性。

| 修改文件 | 变更 |
|---|---|
| `string.mbt` | 新增 `startsWith(prefix, msg?)`, `endsWith(suffix, msg?)`, `includes(substring, msg?)`, `uuid(msg?)`；`is_valid_email` 替代 `has_at_and_dot` |
| `moon_zod_test.mbt` | 18 个测试覆盖全部新验证器 + email 边缘 case |

**关键决策**:
- UUID v4 逐字符校验（8-4-4-4-12 布局，版本位 4，变体位 8/9/a/b），纯字符遍历 O(1)，无正则依赖
- 改进 email 校验：要求恰好一个 @、local 无首尾点、domain 至少一个点
- 所有验证器均支持 `msg?` 参数和 JSON Schema annotation

**产出**: 189/189 测试全部通过 0 警告。

---

## Phase 21 — Schema 组合器 (pick / omit / partial)

**目标**: 实现 Schema 级组合操作 — 从已有对象 Schema 派生子集，支持 `pick`、`omit`、`partial`。

| 修改文件 | 变更 |
|---|---|
| `object.mbt` | 新增 `Schema::pick(keys)`, `Schema::omit(keys)`, `Schema::partial()` — 过滤或包装 Object spec 字段，保留 mode/rules/description |
| `moon_zod_test.mbt` | 15 个测试覆盖 pick/omit/partial 的字段筛选、规则保留、mode 保留、prompt 输出、description 保留 |

**关键决策**:
- 三个方法均 `abort()` 非 object schema（保持与 `strict()`/`passthrough()` 一致）
- `partial()` 使用 `s.optional()` 包装每个字段，`partial().partial()` 幂等
- JSON Schema 导出无需修改：已有 `is_optional_schema` + `required` 排除逻辑正确处理

**产出**: 206/206 测试全部通过 0 警告。

---

## Phase 22 — 代码清理与重构

**目标**: 修复死代码、修复 description 传播、提取 intersection 模块、拆分巨型测试文件。

| 文件 | 操作 | 说明 |
|---|---|---|
| `string.mbt` | 修改 | `regex()` 修复：移除死代码阻塞，恢复为 substring match + 注释说明 |
| `schema.mbt` | 修改 | `append_rule_with_annotation` wrapper 分支的 `description: ""` → `description: schema.description` |
| `intersection.mbt` | 新建 | 从 `union.mbt` 抽取 intersection/intersect/parse_intersection |
| `union.mbt` | 修改 | 移除 intersection 相关函数 |
| `test_utils.mbt` | 新建 | 共享 `parse_json` 辅助 |
| `test_*.mbt` （11 个） | 新建 | 按类型拆分的专项测试文件（string/number/boolean_null/object/array/combinators/transform_refine/json_schema/prompt/custom_message/errors） |
| `moon_zod_wbtest.mbt` | 修改 | 移除重复 `parse_json` |
| `moon_zod_test.mbt` | 删除 | 被 11 个类型专项测试文件取代 |

**产出**: 206/206 测试全部通过 0 警告。单项测试文件总行数降低，定位问题更快。

---

## Phase 23 — 补全缺失验证器

**目标**: 填补与 Zod/Pydantic 的验证器差距 — 新增 7 个高频缺失验证器。

| 文件 | 变更 |
|---|---|
| `string.mbt` | 新增 `cuid()`、`datetime()`、`ip()`/`ipv4()`/`ipv6()`、`length(n)` (字符串/数组双支持)、`ulid()` |
| `number.mbt` | 新增 `finite()`（`!v.is_nan() && !v.is_inf()`）、`safe()`（安全整数范围校验） |
| `test_string.mbt` | 32 个新测试覆盖所有字符串验证器 |
| `test_number.mbt` | 9 个新测试覆盖 `finite`/`safe` |
| `test_array.mbt` | 4 个新测试覆盖 `length()` 数组行为 |

**关键决策**:
- `Double` 无 `is_finite()`，使用 `!v.is_nan() && !v.is_inf()` 替代
- `split()` 返回 `Iter[StringView]` 而非 `Array[String]`，所有 ip/datetime 函数重写为字符逐位解析
- `ip()` 自动检测 v4/v6；`ipv4()`/`ipv6()` 分别校验
- `length()` 不产生 JSON Schema annotation，避免与 `minLength`/`maxLength` 冲突

**产出**: 251/251 测试全部通过 0 警告。

---

## 项目当前状态

| 指标 | 数值 |
|---|---|
| 测试数量 | 251（247 黑盒 + 4 白盒） |
| 外部依赖 | 0（仅 `moonbitlang/core`） |
| 编译器警告 | 0 |
| 核心源码模块 | 15 个 `.mbt` 文件（含 `intersection.mbt`） |
| 测试文件 | 14 个（13 类型专项 + 1 白盒） |
| CLI 工具 | 3 个（`cmd/main` 基准, `cmd/wasm` 跨语言, `cmd/json2schema` 代码生成） |
| 展示示例 | 5 个（`llm_agent`, `educational_agent`, `real_llm_agent`, `json2schema`, `schema2json`） |

---

## 已知问题 / 未来方向

### 已知限制
- Wasm 基准通过子进程 + 启动开销抵扣估算，而非进程内精确计时（MoonBit wasm target 的限制）。
- `regex()` 仅做 substring match（MoonBit 无内建 regex 引擎）。

### 与 Zod/Pydantic 的差异
- **类型级错误消息**：Zod 可在 schema 级别定制 `{ required_error, invalid_type_error }`，我们只能覆写规则错误。
- **`msg` 只接受字符串**：Zod 可传 `{ message, code }` 对象。
- **全局错误映射**：Zod 有 `z.setErrorMap()`，我们没有。
- **`.url()` 深度**：只检查 `http://`/`https://` 前缀，非完整 URL 解析。
- **`.email()` 仍比 Zod 弱**：无 quoted local parts、IP literal domains。
- **缺失验证器**：`.nan()`（MoonBit Double 无 is_nan 构造函数）。

### 建议下一步
1. **多平台 CI**: 扩展 GitHub Actions 到 macos-latest / windows-latest。
2. **derive 宏**: `derive(ZodSchema)` 从 MoonBit struct 自动生成 schema。
3. **wasm-gc target**: 验证 `--target wasm-gc` 兼容性并优化 instantiation 开销。

---

详情见各 `step_phase_details/step_phase_*.md` 文件。
