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

## Phase 24 — 增强验证器 + 类型级错误消息 (v0.5.0)

**目标**: 修复 IPv6 `::` 组计数 bug + 增强 email/url 校验 + 类型级 `required_error`/`invalid_type_error`。

| 文件 | 变更 |
|---|---|
| `schema.mbt` | Schema 新增 `required_error`/`invalid_type_error` 字段；`parse_inner` 类型错误使用自定义消息 |
| `string.mbt` | IPv6 `::` 双倍计数 bug 修复（`while` 循环 + `i=i+2`）；`is_valid_email` 重写（引号 local、IP literal、`+` 标签、TLD≥2）；`is_valid_url` 全新（scheme://host[:port][/path][?query][#fragment]） |
| `number/boolean/null/array/object/intersection.mbt` | 工厂函数新增加 `required_error?`/`invalid_type_error?` 参数 |
| `union.mbt` | `optional()`/`default()` 传播内层错误参数；`enum_values()`/`union()` 新增参数 |
| `transform.mbt` | `transform()` 传播内层错误参数 |
| `test_string.mbt` | 25 个新测试（IPv6 边缘、email 增强、URL 增强） |
| `test_errors.mbt` | 8 个类型级错误消息测试 |

**关键决策**:
- IPv6 修复：`for` 循环变量不可变，改用 `while` 循环手动控制索引
- Email 增强：`find_unquoted_at()` 跳过引号内容，准确找到分割 `@`
- URL 增强：完整结构解析而非前缀检查，复用已有的 `is_valid_ipv4`
- 类型错误消息：`invalid_type_error` 用于类型不匹配，`required_error` 用于缺失必填字段。空字符串=使用默认消息

**产出**: 276/276 测试全部通过 0 警告。12 文件修改，607 insertions。

---

## Phase 25 — Schema 命名导出与拓扑排序 (v0.6.0)

**目标**: 实现 `schema_to_prompt_named()` 自动提取命名 Schema 并生成分离的 TypeScript interface 定义，支持完整的拓扑排序和循环引用检测。

| 新增文件 | 用途 |
|---|---|
| `test_prompt_named.mbt` | Schema 命名导出 6 个测试（基础 + 深嵌套 + 拓扑排序 + optional 字段） |
| `branch_doc/design_doc/PHASE_25_NAMED_SCHEMA_EXPORT.md` | 完整设计文档（算法、场景演示、实现分阶段计划） |
| `branch_doc/step_phase_details/step_phase25_named_schema_export.md` | Phase 25 详细文档 |

| 修改文件 | 变更 |
|---|---|
| `schema.mbt` | Schema struct +1 field `name: String`；所有 wrapper 分支添加 `name: self.name` |
| `string.mbt` / `number.mbt` / `boolean.mbt` / `null.mbt` | 工厂函数添加 `name: ""` |
| `object.mbt` | 工厂函数添加 `name: ""`；pick/omit/partial 传播 `name` |
| `array.mbt` / `union.mbt` / `intersection.mbt` / `transform.mbt` | 工厂函数添加 `name: ""`；wrapper 传播 `name: self.name` |
| `prompt.mbt` | 新增 ~800 行：命名收集、拓扑排序、接口生成、名字引用；新增 `pub fn schema_to_prompt_named()` |

**关键决策**:
- **自动提取**：无需手动维护名字列表，递归遍历收集所有 `name != ""` 的 schema（O(n)）
- **拓扑排序**：三阶段 DFS 确保定义始终先于引用，三态标记（0=未访问/1=正在访问/2=已访问）检测循环
- **Array-based 实现**：避免 Map 依赖，visited 用 Array[(String, u32)] 实现 O(n) 线性查找（<100 个命名 schema 无感知）
- **字段替换**：新增 `object_to_inline_prompt()` 检查字段是否在 named_schemas 列表，若是用名字替代，否则内联展开

**示例输出对比**：
- ❌ **之前** (内联展开 + 重复定义)
- ✅ **现在** (分离导出 + 名字引用)

**产出**: 6 个新测试，总计 282/282 测试全部通过 0 警告。对象字段正确替换为名字引用，拓扑排序保证定义顺序正确。

---

## Phase 26 — JSON Schema Named Export (`to_json_schema_named()`)

**目标**: 实现命名 Schema 的 JSON Schema 标准导出 — 含 `$defs` 和 `$ref` 引用机制。

| 文件 | 变更 |
|---|---|
| `json_schema.mbt` | 新增 `to_json_schema_named()` 公共 API；内部 `to_json_schema_ref()` / `to_json_schema_named_full()` / `to_json_schema_ref_object()` |
| `test_json_schema.mbt` | 9 个新测试：`$defs` 结构、`$ref` 引用、数组/枚举/可选字段、拓扑排序、空命名集 |

**关键决策**:
- `to_json_schema_ref` 遇到命名 Schema 立即返回 `{"$ref": "#/$defs/Name"}`，确保循环引用安全
- `to_json_schema_named_full` 不自引用，仅对子元素使用 `$ref`，用于构建 `$defs` 条目
- 复用 Phase 25 的 `collect_named_schemas()` + `topological_sort_schemas()`，保证定义顺序
- 无命名 Schema 时输出 `{"$defs": {}}` + 根内联，退化为标准 JSON Schema

**产出**: 291/291 测试全部通过 0 警告。

---

## Phase 27 — JSON Schema → moon_zod 反向生成 (`json_schema_to_moon_zod()`)

**目标**: 实现 `json_schema_to_moon_zod()` — 将标准 JSON Schema (draft-07) 文档转换为 moon_zod Schema 表达式源码，形成完整的双向转换闭环。

| 文件 | 操作 | 说明 |
|---|---|---|
| `from_json_schema.mbt` | 新增 | ~284 行核心实现：1 公共函数 + 11 内部 helper |
| `test_json_schema.mbt` | 修改 | 25 个新测试覆盖所有类型和约束 |
| `cmd/json2schema/main.mbt` | 修改 | 新增 `--from-json-schema` 标志 |
| `cmd/json2schema/moon.pkg` | 修改 | 添加 `"Betterlol/moon_zod"` 依赖 |

**关键决策**:
- 输出 MoonBit **源码字符串**（非运行时 Schema），可直接 copy-paste
- 递归解析按优先级匹配：`$ref` > `enum` > `type` > `anyOf`/`allOf`/`oneOf`
- `$defs`/`definitions` 生成 `let Name_schema = ... .name("Name")` 声明
- 字段不在 `required` 中自动附加 `.optional()`
- `exclusiveMinimum: 0` → `.positive()`，`exclusiveMaximum: 0` → `.negative()`
- `format: "email"/"uri"/"date-time"/"ipv4"/"ipv6"/"uuid"` → 对应 moon_zod 验证器
- CLI 集成：`moon run cmd/json2schema -- --from-json-schema '<json>'`

**产出**: 316/316 测试全部通过 0 警告。

---

## Phase 28 — Schema → MoonBit struct 代码生成 (`schema_to_moonbit_struct`)

**目标**: 填补 `parse()` 返回 `Result[Json, ...]` 后需手工 pattern match 提取值的 ergonomic gap。实现 Schema → MoonBit struct 定义的双向桥接。

| 新增文件 | 用途 |
|---|---|
| `moonbit_struct.mbt` | `schema_to_moonbit_struct()` + `schema_to_moonbit_struct_named()` + 12 个内部辅助函数 |
| `test_moonbit_struct.mbt` | 22 个测试（基础类型映射、可选/默认字段、enum、约束注释、嵌套命名、拓扑排序） |
| `cmd/gen-struct/main.mbt` | CLI：JSON payload → 推断 Schema → 输出 struct 定义 |
| `cmd/gen-struct/moon.pkg` | CLI 包声明（is-main + `Betterlol/moon_zod` 依赖） |

**关键决策**:
- 只生成类型定义（struct/enum），不生成 from_json()（留待 Phase 29）
- 非命名 ObjectType → 字段输出 `Json /* TODO: define nested struct */`，保证可编译
- 约束注释复用 `prompt.mbt` 的 `string_constraint_comment()` 等函数（同包可见）
- CLI 嵌套对象自动 PascalCase 命名，被 `schema_to_moonbit_struct_named()` 收集
- 整数检测：`v == v.to_int().to_double()`

**类型映射**:
| SchemaType | MoonBit |
|---|---|
| String | `String` |
| Number (有 int()) | `Int64` |
| Number (无 int()) | `Double` |
| Boolean | `Bool` |
| Null | `Unit` |
| Optional | `T?` |
| Default | `T` (字段标记 `?`) |
| Array | `Array[T]` |
| Enum | `pub enum { Variant }` |
| Union(T+Null) | `T?` |
| Union(复杂) | `/* TODO */` |

**测试**: 22 个新测试，总计 344/344 全部通过 0 警告。

---

## Phase 29 — Schema → MoonBit struct `from_json()` 代码生成

**目标**: 补全 Phase 28 的类型定义能力，生成 `from_json()` 函数将验证后的 `Json` 值直接转换为类型安全的 MoonBit struct 值，无需用户手工 pattern match。

| 新增文件 | 用途 |
|---|---|
| `moonbit_struct.mbt` | 新增 `generate_from_json_fn`、`extract_field`、`extract_type_expr`、`struct_name_to_fn_prefix`、`schema_to_moonbit_struct_full`、`schema_to_moonbit_struct_named_full` 等 ~350 行 |
| `test_moonbit_struct.mbt` | 新增 16 个测试（类型提取、签名验证、命名导出、嵌套委托） |

**关键决策**:
- **Direct Extraction 模式**：直接对 Json 做结构匹配 + 提取，无 Schema 运行时依赖
- 解决了 `abort()` vs Result 矛盾 → 所有提取路径返回 `Err(...)`
- 独立函数命名：`fn user_from_json(json)` 而非 `fn User::from_json(self, json)`
- 嵌套对象委托：`other_from_json(v)` 而非内联 Schema 引用
- 可选字段：`Some(Null) | None => None` 分支

**生成的代码示例**:
```moonbit
pub struct User { name : String; age : Int64; email : String? }

pub fn user_from_json(json : Json) -> Result[User, Array[ValidationError]] {
  match json {
    Object(map) => {
      let name = match map.get("name") {
        Some(String(s)) => s
        Some(got) => return Err([ValidationError::{ path: "name", message: "expected string", got }])
        None => return Err([ValidationError::{ path: "name", message: "required", got: Null }])
      }
      let email = match map.get("email") {
        Some(Null) | None => None
        Some(v) => Some({ let r = match v { String(s) => s; _ => return Err([...]) }; r })
      }
      Ok({ name:, age:, email: })
    }
    _ => Err([ValidationError::{ path: "", message: "expected object", got: json }])
  }
}
```

**测试**: 16 个新测试，总计 360/360 全部通过 0 警告。

---

## Phase 30 — Validate CLI 工具

**目标**: 提供零代码使用 moon_zod 库的能力，无需编写 MoonBit 代码即可校验 JSON 数据。

| 新增文件 | 用途 |
|---|---|
| `cmd/validate/moon.pkg` | 包声明，`is-main: true` |
| `cmd/validate/main.mbt` | 核心实现 (~280 行) |

**核心功能**:

```bash
# Infer 模式：从 sample JSON 推断 schema，校验 data JSON
moon run cmd/validate -- '<sample.json>' '<data.json>'

# JSON Lines 批量校验
moon run cmd/validate -- '<sample.json>' '<data.jsonl>'
```

**关键实现**:
- `json_to_schema(json, name_hint) -> Schema` — JSON → moon_zod Schema 推断
- `validate_single(schema, data_raw)` — 单文件校验
- `validate_jsonl(schema, data_raw)` — JSON Lines 批量校验，统计 pass/fail
- 错误输出：path + message + got 三要素

**测试**: moon build ✓ 0 errors，moon test ✓ 360/360。

---

## Phase 31 — 测试扩展

**目标**: 补充 moonbit_struct 模块的测试覆盖，新增 17 个测试用例。

| 新增测试 | 覆盖场景 |
|---|---|
| 深度嵌套 3 层对象 | 验证中间层引用正确 |
| 数组类型 (简单/嵌套/optional/对象数组) | 5 个测试 |
| 可选字段 (纯 optional/optional object/optional array/default) | 4 个测试 |
| 特殊场景 (全类型组合、空对象、null 类型) | 4 个测试 |
| 兄弟 schema 引用 | 1 个测试 |

**关键发现**:
- `NullType` → `Unit` 而非 `Json`
- 深度嵌套必须用 `schema_to_moonbit_struct_named_full`
- 数组元素为命名 schema 时，`from_json` 委托 `item_from_json(item)`

**测试**: moon build ✓ 0 errors，moon test ✓ 377/377。

---

## Phase 32 — literal() 常量校验 + union.mbt 重构 (v0.7.1)

**目标**: 实现任意 JSON 常量值校验，并按 "one factory per file" 约定重构 `union.mbt`。

### Task 1: literal() 实现

新增 `literal(value: Json)` 工厂函数，支持 String/Number/Boolean/Null/Array/Object 常量精确匹配。

| 新增文件 | 用途 |
|---|---|
| `literal.mbt` | `literal()` 工厂 + `parse_literal()` + `json_to_literal_string()` |

| 修改文件 | 变更 |
|---|---|
| `schema.mbt` | `SchemaType` 新增 `LiteralType(Json)` |
| `union.mbt` | 新增 `literal()` + `parse_literal()` |
| `json_schema.mbt` | LiteralType → `{"const": value}` |
| `prompt.mbt` | 新增 `json_to_ts_literal()`，渲染 TS 字面量 |
| `moonbit_struct.mbt` | 新增 `literal_to_moonbit_type()` + `json_to_literal_code()` |
| `test_combinators.mbt` | 新增 14 个测试 |

**使用示例**:
```moonbit
@moon_zod.literal(Json::string("active"))  // 只接受 "active"
@moon_zod.literal(Json::number(42.0))       // 只接受 42
```

### Task 2: union.mbt 重构

按 "one factory per file" 约定拆分 `union.mbt`：

| 新文件 | 包含内容 |
|---|---|
| `optional.mbt` | `Schema::optional()` + `parse_optional()` |
| `default.mbt` | `Schema::default()` + `parse_default()` |
| `enum.mbt` | `enum_values()` + `parse_enum()` |
| `literal.mbt` | `literal()` + `parse_literal()` |
| `union.mbt` (改写) | 只保留 `union()` + `parse_union()` |

**统计**: `union.mbt` 217行 → 42行 (-81%)，新增 4 个模块文件。

**测试**: moon build ✓ 0 errors，moon test ✓ 381/381。

> `enum_values()` 仍然保留只支持枚举字符串，而不拓展其他类型甚至混合类型，`literal()` 则支持任意 JSON 常量值；这主要是为了防止逻辑复杂化和类型推导困难。
> 我们推荐使用 `union` + `literal()` 组合来实现任意类型的枚举。
> 特别需要考虑的是 `union` 枚举被导出 ts prompt 时应该作为 `type` 还是 `interface` 呢？不过目前暂时不深入讨论这个问题。

---
