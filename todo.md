## 已知问题 / 未来方向

### 已知限制
- Wasm 基准通过子进程 + 启动开销抵扣估算，而非进程内精确计时（MoonBit wasm target 的限制）。
- `regex()` 仅做 substring match（MoonBit 无内建 regex 引擎）。

### 与 Zod/Pydantic 的差异
- **类型级错误消息**：Zod 可在 schema 级别定制 `{ required_error, invalid_type_error }`，我们只能覆写规则错误。
- **`msg` 只接受字符串**：Zod 可传 `{ message, code }` 对象。
- **全局错误映射**：Zod 有 `z.setErrorMap()`，我们没有（by design：MoonBit 无全局可变状态习惯，调用者显式传 fn）。
- **缺失验证器**：`.nan()`（MoonBit Double 无 is_nan 构造函数）。
- **递归 memoization**：Zod 的 `z.lazy()` 通过 JS 闭包共享 Schema 实例；MoonBit 的 `recursive()` 需要 `fn` 模式，每次 parse 创建新 Schema O(depth)。

### 建议下一步（实现规划）

每实现一个功能，完成时在前面打勾 `☑`，保留实现历史无需反复更新。

---

#### ☑ Schema 命名导出与拓扑排序

**完成状态**:
- [x] `pub fn schema_to_prompt_named(schema: Schema) -> String`
- [x] 递归收集命名 Schema（自动提取）
- [x] 拓扑排序与循环检测
- [x] 6 个新测试，282/282 通过

---

#### ☑ 从 JSON Schema 反向生成 moon_zod Schema

**完成状态**:
- [x] `pub fn json_schema_to_moon_zod(json_schema: Json) -> String`
- [x] 支持基础类型、对象、数组、enum、$ref 引用、约束条件
- [x] 输出可直接 copy-paste 的 MoonBit 源码
- [x] 集成到 cmd/json2schema（`--from-json-schema` 标志）
- [x] 25 个新测试，316/316 通过

**Phase 27.1 缺陷修复** (详见 `step_phase_details/step_phase27_1_fixes.md`):
- ✅ `json_to_literal` 双重嵌套 → 改输出 `Json::string()` 等 MoonBit 构造函数
- ✅ `$defs` 拓扑排序 → 新增基于 JSON `$ref` 扫描的独立排序管线（不可复用 Phase 25 Schema 版）
- ✅ 循环引用检测 → DFS 三态标记 + `/* TODO: circular reference */` 注释
- **测试**: +6 个测试，总计 322/322 全部通过 0 警告

---

#### ☑ `schema_to_json_schema_named()` 函数

**完成状态**:
- [x] `pub fn to_json_schema_named(schema: Schema) -> Json`
- [x] 命名 Schema 分离为 `$defs` 条目，字段引用使用 `$ref: "#/$defs/Name"`
- [x] 复用 Phase 25 的收集与拓扑排序，循环引用安全
- [x] 9 个新测试，291/291 通过

---

#### ☑ `literal()` 常量值校验

**完成状态** (Phase 32):
- [x] `pub fn literal(value: Json) -> Schema`
- [x] `LiteralType(Json)` 变体添加到 `SchemaType` 枚举
- [x] 支持 String/Number/Boolean/Null/Array/Object 精确匹配
- [x] JSON Schema 导出为 `{"const": value}`
- [x] TypeScript prompt 渲染为字面量语法
- [x] MoonBit struct 代码生成支持
- [x] 14 个新测试，381/381 通过
- [x] 重构 `union.mbt` 拆分为独立模块文件（one factory per file）

---

#### ☑ Trait-based Renderer Pattern 重构

**完成状态** (Phase 33):
- [x] Phase A: Union/Intersection/Literal named 导出修复
- [x] Phase B: constraint_extractor.mbt 约束提取统一
- [x] Phase C: 3 个 trait（StringRenderer、JsonSchemaRenderer、MoonBitStructRenderer）
- [x] 共享工具抽取（shared_utils.mbt）
- [x] SchemaType match 数从 40 降至 4（-90%）
- [x] 385/385 测试通过

---

#### ☑ `include_names` 选择性导出

**完成状态** (Phase 34):
- [x] 4 个 named 函数新增 `include_names? : Array[String]? = None`
- [x] 提取 `filter_named_schemas` 到 `shared_utils.mbt`
- [x] 11 个新测试（prompt 6 + json_schema 5），396/396 通过

---

#### ☑ 核心校验器增强 — Phase 37 已交付

**完成状态**:

| 功能 | 状态 |
|------|------|
| **`.string().trim()` / `.to_lower()` / `.to_upper()`** | ✅ 已实现 |
| **`.array().nonempty([msg])`** | ✅ 已实现 |
| **`bigint()` 工厂** | ✅ 已实现 |
| **`.brand(brand_name)`** | ✅ 已实现 |

**任务完成情况**:
- [x] `string.mbt`: 新增 `.trim()`, `.to_lower()`, `.to_upper()` 方法
- [x] `array.mbt`: 新增 `.nonempty()` 方法（实际在 `string.mbt` 中扩展，统一 `Schema::nonempty`）
- [x] 新建 `bigint.mbt`: 新增 `bigint()` 工厂
- [x] `schema.mbt`: 新增 `.brand()` 方法 + `brand` 字段，所有包装器透传
- [x] test 覆盖完成
- [ ] ~~所有新增功能覆盖 prompt 导出、JSON Schema 导出、struct 代码生成~~ — **搁置**：exporters 功能冻结

<!--
### 当前实现不足之处（后续改进方向）

#### string().trim() / .to_lower() / .to_upper()
- 内部基于 `.transform()` 实现，链式规则在 transform 后执行
- 但 JS/Zod 里 trim/lower/upper 是"净化（sanitize）"语义，验证器应作用于净化后值，当前行为对齐 Zod
- ✅ 行为正确，无已知缺陷

#### array().nonempty()
- 在 `Schema::nonempty` 中通过运行时 type dispatch 同时支持 string 和 array
- MoonBit 不支持方法重载，这是唯一可行方案
- ⚠️ 潜在问题：`inner_type()` 穿透 TransformType/OptionalType/DefaultType 后判断 StringType/ArrayType
  - 若用户在 `.transform().nonempty()` 链上调用，inner_type 取到的是 inner schema 的类型而非 TransformType
  - 当前 `transform()` 返回 `TransformType` 且 schema_type 不变，这一行为对 nonempty 实际无害（规则不依赖 inner_type 结果）
  - 但如果未来 nonempty 需要根据 inner_type 做不同逻辑（如现在区分 StringType vs ArrayType 的默认消息），transform 穿透可能导致意外
  
#### bigint()
- 当前实现为 `number().int()` 的语义别名，只接受 JSON number（且必须为整数）
- 局限性：
  - ❌ 不接受 JSON string 编码的大整数（如 `"9007199254740993"`）
  - ❌ MoonBit Double 精度限制（53 bits），超出 `Number.MAX_SAFE_INTEGER` 的值在 JSON parse 阶段已失真
  - ❌ 无法校验超出 Double 范围的整数字符串
- 真正的大整数需要：MoonBit BigInt 类型支持 + JSON parse 阶段保留精度（自定义 number parser）— 当前语言层面不支持
- 可作为临时方案：在 JSON.parse 之前用字符串预处理拦截大数字

#### .brand()
- 当前仅存储 `brand: String` 字段，不主动输出到任何 exporter
- 局限性：
  - ❌ prompt 导出不渲染 brand
  - ❌ JSON Schema 导出不渲染 brand（JSON Schema 无 brand 标准字段）
  - ❌ struct 代码生成忽略 brand
  - 若需 exporter 渲染 brand，需在三个 renderer trait 的 render_method 中处理（或作为约束注释追加）
  - 建议：brand 本质是"名义类型标记"，prompt 导出的最佳位置是类型名注释，如 `// Brand: UserId`
-->

---

#### ☐ `PipeType(input, output)` — 显式二阶段转换与校验（代替当前 `TransformType` 的模糊语义）

**问题**: 当前 `TransformType(inner, closure)` 存在设计缺陷：

1. **语义模糊**：`string().transform(fn).min(5)` — `.min(5)` 在 transform 后执行（检查转换后值），但错误报告的 `got` 是转换后的值，LLM/用户难以回溯到原始输入
2. **exporters 无法表达**：所有 renderer 将 transform 当作透明包装渲染 inner，闭包逻辑完全丢失；`schema_to_moon_zod_code` 只能生成占位的 identity transform
3. **与 Zod 的差距**：Zod 用 `.pipe()` 显式创建新 Schema 阶段，后续校验逻辑属于新 Schema，错误報告精确到阶段
4. **链式规则归属混乱**：`append_rule` 不再穿透 TransformType（修复后的行为），但用户期望的 `.transform().min(5)` 到底是检查原始值还是转换值？两种直觉都有道理

**方案**: 新增 `PipeType(input: Schema, output: Schema)` 变体，替代当前 `TransformType` 的"先校验再转换再校验"混在一起的设计。

```moonbit
// 新设计：PipeType
let s = string()
  .transform(fn(s) { Ok(Json::string(s.length().to_string())) })
  .pipe(number().min(5))
// 语义：string校验 → transform → number校验(.min(5))
```

**`PipeType` 与其他方案对比**:

| 方案 | 描述 | 优点 | 缺点 |
|------|------|------|------|
| ✅ `PipeType(input, output)` | 新 SchemaType 变体，input 先校验，transform 可选桥接，output 再校验 | 结构清晰，LLM 错误定位明确，exporters 可分别渲染 input/output | 新增变体，需改所有 match |
| ❌ 保留 `TransformType` 加强 | 在现有基础上修补 | 改动小 | 语义模糊根本问题不解决 |
| ❌ 纯函数方案 | 外部 `combinators` 提供 pipe 函数而非 Schema 变体 | 核心理干净 | 无法被 exporters 识别渲染 |

**核心设计**:

```moonbit
pub enum SchemaType {
  // ...
  PipeType(Schema, TransformClosure, Schema)  // input, bridge, output
}
```

- `parse_pipe` 流程：`parse_inner(input)` → Ok → `bridge(parsed)` → Ok → `parse_inner(output)` → Ok → collect errors on output
- 桥接闭包不可见（如 Zod 的 `.pipe()` 要求类型兼容，这里用 transform 桥接）
- 所有错误来自具体阶段：input 失败 → "input 段错误"，output 失败 → "output 段错误"

**任务**:
- [ ] `types.mbt`: 新增 `PipeType(Schema, TransformClosure, Schema)` 变体
- [ ] `pipe.mbt`（新文件）: `Schema::pipe(self, output: Schema, bridge?: (Json) -> Result[Json, String])` 工厂
- [ ] `schema.mbt`: `parse_inner` 新增 `PipeType` 分支 → `parse_pipe`
- [ ] `pipe.mbt`: `parse_pipe` 实现 — input 校验 → bridge → output 校验
- [ ] `schema.mbt`: `append_rule_with_annotation` 的 `PipeType` 分支 — **rules 追加到 output schema**（与 Zod .pipe() 语义一致）
- [ ] `shared_utils.mbt`: `unwrap_schema` / `inner_type` / `is_optional_schema` 穿透 PipeType 到 output
- [ ] `schema.mbt`: `message()` / `brand` 传播处理 PipeType
- [ ] 所有 exporters 新增 `render_pipe` trait 方法（`prompt_renderer.mbt`, `json_schema_renderer.mbt`, `moonbit_renderer.mbt`）
- [ ] prompt 导出：`PipeType(input, _, output)` → 渲染 input + ` → ` + output 类型
- [ ] JSON Schema 导出：`PipeType` 透明落到 output（JSON Schema 无 pipe 概念）
- [ ] struct 代码生成：`PipeType(input, _, output)` → 用 output 的类型
- [ ] `schema_to_moon_zod_code` 适配：`.pipe(output)` 代码生成
- [ ] 新增 `tests/test_pipe.mbt` — 完整测试覆盖
- [ ] **迁移策略**：逐步废弃 `TransformType`，推荐用户改用 `transform().pipe()`
- [ ] 更新 `doc/INTRODUCTION.md` 的校验流程全景图

**价值**: 解决当前 transform 的语义模糊问题，对齐 Zod `.pipe()` 设计，LLM/用户能获得精确的阶段级错误定位。

---

#### ☐ 多语言代码生成框架
> 优先级较低

**任务**:
- [ ] 创建 `code_gen.mbt` 模块
- [ ] 实现 `pub fn schema_to_code_gen(schema: Schema, lang: String) -> String`
- [ ] Python 生成器：`dataclass` + Pydantic validator
- [ ] Go 生成器：`struct` + 验证函数
- [ ] Rust 生成器：`struct` + serde 属性 + 验证 trait
- [ ] JSON Schema 生成器：标准 JSON Schema 定义

---

#### ☐ 性能基准与优化
> 优先级中等

**任务**:
- [ ] 创建 100-500 个命名 Schema 的基准测试
- [ ] 测试 `topological_sort_schemas()` / `collect_named_schemas()` 性能
- [ ] 评估 visited 线性查找 O(n) 是否瓶颈
- [ ] 必要时升级为 O(1) 查找（Map 依赖 vs 手写哈希表权衡）
- [ ] 对标 Zod/Pydantic 的代码生成速度

---

#### ☐ Schema 国际化与文档生成
> 优先级较低

**任务**:
- [ ] `.i18n_key()` 方法为规则附加 i18n 标记
- [ ] `generate_i18n_strings()` 提取翻译键
- [ ] `schema_to_markdown_doc()` 生成多语言 API 文档
- [ ] 编写多语言错误消息测试

---

#### ☑ Schema → MoonBit struct 代码生成 (`schema_to_moonbit_struct`)

**完成状态** (Phase 28 + Phase 29):
- [x] `pub fn schema_to_moonbit_struct(schema: Schema) -> String`
- [x] 基础类型映射（string → String, number → Int64/Double, boolean → Bool）
- [x] 可选字段（`String?`）、默认值
- [x] 嵌套对象、数组（`Array[T]`）
- [x] `from_json()` 函数生成（Phase 29）- `schema_to_moonbit_struct_full()` / `schema_to_moonbit_struct_named_full()`
- [x] CLI 集成：`moon run cmd/gen-struct -- '<json>'`
- [x] 命名导出：`schema_to_moonbit_struct_named()` + 拓扑排序
- [x] 约束注释在 struct field 上的展示（Phase 28 已实现）

**价值**: 填补最大 ergonomic gap，完成 Schema → Code 生成器四件套（TS prompt / JSON Schema / moon_zod code / MoonBit struct）

---

#### ☑ Validate CLI 工具

**完成状态** (Phase 30):
- [x] `cmd/validate/` — 独立可执行包 (`moon.pkg` + `main.mbt`)
- [x] `moon run cmd/validate -- '<sample.json>' '<data.json>'` — Infer 模式
- [x] JSON Lines (`.jsonl`) 批量校验，统计 pass/fail
- [x] 输出格式：通过/失败 + 详细错误报告（path + message + got）
- [ ] 退出码：0=全部通过，1=有错误，2=参数错误（恒为 0）

**待扩展**:
- [ ] Schema 文件模式：`moon run cmd/validate -- <schema.mbt> <data.json>`
- [ ] `--inline-schema '{"type":"string"}'` — 内联 JSON Schema 模式
- [ ] 结构化输出：`--json` 输出机器可读格式

**价值**: 零代码使用库的能力，CI 集成，非 MoonBit 用户也能受益。

---

#### ☐ Schema 条件逻辑与逻辑组合子

**问题**: 缺少 `if/then/else`、`not`、`oneOf` 精确匹配等的逻辑组合子，无法实现复杂业务规则校验。

**任务**:
- [ ] `Schema::not(Schema)` — 新 `NotType` 变体，输入不能通过内层 schema
> not 不应该阻塞原本类型的渲染，不该实现为覆盖，而是体现为 rule 约束，即导出 prompt:
> `name: "not(...)"` ❌️
> `name: "string" // [not(...)]` ✅️
- [ ] `Schema::if_then_else(condition, then, else)` — 条件校验
- [ ] 增强 `oneOf` 严格模式：精确匹配一个分支 vs 当前 `union` 近似
- [ ] 所有新逻辑组合子支持 JSON Schema 导出、prompt 生成

**价值**: 支持复杂业务规则校验。
> 事实上，Zod/Pydantic/Rust 都没有实现 `if/then/else` `not` `oneOf`。
> `not` 变体可用于实现 `Schema::exclude(Schema)`，即排除某些值的校验，这个是比较有用的功能。
> 然而，`not` 的实现事实上可以用 `refine()` 来间接实现，而且实现起来也比较简单；同时 `not` 实现风险很高，它对 prompt 和 Json Schema 的渲染都比较难处理。
> 另外，`if/then/else` 和 `oneOf` 有用与否却是有待商榷了，事实上，虽然它们与 `union` 语义上严格来说不完全等价，但在实际业务中，`union` 已经足够覆盖大部分场景了。
> 举例来说：
> ```mbt
> let schema = Schema::union([
>  object({ "status": literal("success"), "data": ..., "error": null() }),
>  object({ "status": literal("error"), "error": ..., "data": null() }),
> ])
> 等价于
> let schema = Schema::oneOf([
>  object({ "status": literal("success"), "data": ..., "error": null() }),
>  object({ "status": literal("error"), "error": ..., "data": null() }),
> ])
> 等价于
> let schema = Schema::if_then_else(
>  if=object({ "status": literal(Json::string("success")) }),
>  then=object({ "data": ..., "error": null() }),
>  else=object({ "data": null(), "error": ... }),
> )
> ```
> `if/then/else` 和 `oneOf` 的主要价值在于 `严格模式`，即要求输入必须严格匹配一个分支，而不是多个分支的近似匹配，这在某些业务场景下可能是有用的，但在大多数情况下，`union` 已经足够了。

---

#### ☐ 枚举类型的 `exclude()` 和 `extract()` 方法
> 优先级中等

**问题**: 当前无法在枚举类型中排除某些值，也无法提取某些值的子集，导致在复杂业务规则中无法灵活组合枚举类型。

**任务**:
- [ ] `Schema::exclude(self : Schema, values: Array[Json])` — 排除某些值的校验
- [ ] `Schema::extract(self : Schema, values: Array[Json])` — 提取某些值的子集校验
- [ ] 枚举类型支持 JSON Schema 导出、prompt 生成

**价值**: 支持复杂业务规则校验，尤其是在枚举类型中灵活组合。
> 这个功能相比于 `not()` 等来说更有实现的必要和价值。
> 示例：
> ```mbt
> let schema = Schema::enum(["red", "green", "blue"])
> let schema_exclude = schema.exclude(["green"]) // 只允许 "red" 和 "blue"
> let schema_extract = schema.extract(["red"]) // 只允许 "red"
> ```

#### ☑ Recursive Schema (Phase 43 已交付)

**问题**: 之前无法定义自引用 Schema（树、链表等递归数据结构）。

**完成状态**:
- [x] `pub fn recursive(fn() -> Schema)` — 工厂，闭包在 parse 时调用
- [x] `LazyType(() -> Schema)` SchemaType 变体
- [x] 支持自引用树结构（函数式模式，`let rec` 不可用）
- [x] 导出器：解析闭包后递归渲染
- [x] 5 个测试（正常、错误、深度嵌套、命名根、嵌套无效）
- [x] 524/524 测试通过

**已知限制**: 无 memoization，每次 parse O(depth) 创建新 Schema 对象。MoonBit `lazy` 关键字已预留但未实现，无法做值级别惰性自引用。

---

#### ☑ 错误消息体系升级 — Phase 42 已交付

**完成状态**:

| 功能 | 状态 |
|------|------|
| `ValidationError.code: IssueCode` 结构化错误码 | ✅ `IssueCode` enum (12 变体) |
| `Schema::safe_parse(json, ParseParams)` 上下文 error_map | ✅ 2 层优先级链 |
| IssueCode 集成到 `constraint_extractor` | ✅ `rule.code` 作为约束提取主源 |
| 路径精度：每个错误包含确切的字段路径 | ✅ 预格式化 String，零 finalize 额外分配 |

**明确不做（设计决策）**:

| 功能 | 不做的理由 |
|------|-----------|
| 全局 error map | MoonBit 模块系统无全局可变状态习惯；调用者自行组织 `fn my_map()` 并传入每个 `safe_parse` |
| `msg?` 支持结构化对象 | 当前 `msg? : String = ""` 足够覆盖 LLM 场景 |
| 错误消息国际化框架 | 暂不需要，`ParseParams.error_map` 可在调用层实现翻译 |
| `to_formatted_string()` 多行输出 | `to_string()` 当前单行已覆盖调试需求 |

**未来可选扩展**: `InvalidKey`/`InvalidElement` 变体已预留在 enum 中，但未在任何 rule 中构造，待 map key 校验等场景触发时使用。

---

#### ☑ Discriminated Union (Phase 43 已交付)

**问题**: 之前 `union()` 需要逐一尝试每个分支，O(n)。

**完成状态**:
- [x] `pub fn discriminated_union(discriminator, options: Map[String, Schema])` 工厂
- [x] `DiscriminatedUnionType(String, Map)` SchemaType 变体
- [x] O(1) 分支分发（Map 直接查找，不尝试所有选项）
- [x] 精确错误码：`MissingRequired`（缺判别字段）、`InvalidValue`（未知判别值）、`InvalidType`（非对象输入/非字符串判别值）
- [x] 链式规则（`.refine()` 等）在 dispatch 后正确检查
- [x] 5 个测试（分发、未知判别值、缺字段、非对象、schema 级校验+refine）

**已知限制**: 导出时退化为普通 union（丢失判别信息）。完整判别式导出需 renderer trait 扩展，作为独立功能。

---

#### ☐ Prompt 压缩与 Token 优化
> 优先级较低

**问题**: `schema_to_prompt()` 在大 schema 下生成冗余约束说明，占用 LLM context window。

**任务**:
- [ ] `schema_to_prompt_compact(schema)` — 移除可选注释，使用最短类型名
- [ ] `schema_to_prompt_tokens(schema) -> Int` — 估算 token 消耗
- [ ] 约束合并压缩（`// 2-100 chars, email, pattern: ^[a-z]` → 更短表示）
- [ ] 命名引用 vs 内联展开的 token 对比分析
- [ ] 可选：输出 JSON Schema 格式（OpenAI tool 模式）而非 TS interface

**价值**: 直接降低 LLM API 调用成本。100+ 字段的复杂 schema 可节省 30-50% prompt tokens。

---

#### ☐ 流式与批量校验
> 优先级较低

**问题**: 每次 `schema.parse(item)` 重新创建 path_stack，无法复用校验上下文。

**任务**:
- [ ] `Schema::parse_batch(Array[Json]) -> Array[SchemaResult]` — 批量校验
- [ ] 预热缓存（共享 schema 编译/预检查）
- [ ] `Schema::parse_stream(Iter[Json]) -> Iter[SchemaResult]` — 惰性流式校验
- [ ] 大数组场景性能基准对比

**价值**: 高吞吐场景（日志分析、数据管道）性能关键。

---

#### ◐ Schema 服务端 / 注册中心
> 优先级较低

**问题**: Schema 定义分散在代码中，无法共享、发现、版本管理。

**任务**:
- [ ] `.moon_schema` 文件格式定义（JSON Schema + moon_zod 扩展）
- [ ] `schema_to_file(schema, path)` / `schema_from_file(path)` — 文件 IO
- [ ] 可选：HTTP 服务端接受 JSON 并返回校验结果
- [ ] 可选：GraphQL-like schema registry（发布、发现、版本化）

**价值**: 大型项目中 Schema 治理的基石。长远可发展为 OpenAPI registry 的轻量替代。

---

#### ◐ 可并行推进（不阻塞核心功能）

- [x] 多平台 CI：扩展 GitHub Actions 到 macOS/Windows
- [ ] wasm-gc target：验证兼容性并优化启动开销
- ⏳ derive 宏：需等待 MoonBit 宏系统成熟
> 然而，MoonBit 当前缺乏稳定的宏系统，只支持内置的几个 derive (Debug/Show/Eq/FromJson/ToJson)，无法实现自定义 derive。需要等待未来 MoonBit 引入稳定的宏系统后才能开发此功能。

#### 常驻任务

- 定期检查是否有 "代码坏味道" 出现（重复代码、过长函数、复杂条件分支等），及时重构保持代码质量；定期检查代码质量，保持核心库的简洁和可维护性，可拓展性。
> 如果某个很简单且必要的功能需要引入复杂的实现或大量代码，可能是设计上的坏味道，需要重构以保持核心库的简洁和可维护性。详情见各 `step_phase_details/step_phase_*.md` 文件。