# moon_zod 开发阶段总结

> 本项目为 MoonBit 语言实现的 JSON Schema 运行时校验库，灵感来自 Zod/Pydantic。
> 以下按阶段总结每个 Phase 的核心交付物、关键设计决策及文件变更。

---

## Phase 33 — Trait-based Renderer Pattern 重构 (v0.7.2)

**目标**: 消除 3 个代码生成模块（prompt/json_schema/moonbit_struct）中 40 个散布的 `SchemaType` match 语句，统一为契约式的 trait 分发模式。

### Phase A: 快速修复 (fc04f42)

修复 Union/Intersection/Literal 在 named schema 导出中的缺失：

| 文件 | 变更 |
|------|------|
| `prompt.mbt` | +35 行：补全 `schema_to_interface_definition_with_names()` 分支 + `merge_intersection_object_specs()` |
| `test_prompt_named.mbt` | +58 行：4 个新测试（Union/Intersection/Literal/Complex）|

### Phase B: 约束提取器 (863fcea)

统一约束提取逻辑，消除 ~150 行重复代码：

| 新增文件 | 用途 |
|---------|------|
| `constraint_extractor.mbt` | `pub struct ConstraintInfo` + `extract_constraints()` 等统一约束管理 |

| 修改文件 | 变更 |
|---------|------|
| `prompt.mbt` | -248 行：删除 5 个旧约束函数，改为调用 `constraint_extractor` |
| `moonbit_struct.mbt` | +22 行：改进约束注释清晰度 |

### Phase C: Trait Renderer 重构 (1a1c06e)

核心架构变更 —— 从「40 个 match 散布」到「4 个 match + 3 个 trait」：

| 新增文件 | 用途 |
|---------|------|
| `shared_utils.mbt` | 共享工具：`unwrap_schema`, `peel_optional`, `indent_str`, 命名收集 + 拓扑排序 |
| `string_renderer.mbt` | `pub(open) trait StringRenderer` + `render_type` 分发 |
| `json_schema_renderer.mbt` | `pub(open) trait JsonSchemaRenderer` + `render_json_type` 分发 |
| `moonbit_renderer.mbt` | `pub(open) trait MoonBitStructRenderer` + `render_mbt_type` 分发 |

| 修改文件 | 变更 |
|---------|------|
| `prompt.mbt` | 重写为 `BasicPromptRenderer` + `NamedPromptRenderer`；-498 行 |
| `json_schema.mbt` | 重写为 `FullJsonRenderer` + `SkeletonJsonRenderer` + `NamedJsonRenderer`；-239 行 |
| `moonbit_struct.mbt` | 重写为 `InlineStructRenderer` + `NamedStructRenderer`；-332 行 |
| `constraint_extractor.mbt` | 新增 `pub fn constraint_comment()`；+59 行 |

**关键决策**:
- MoonBit 不支持泛型 trait（`trait Foo[T]`）和关联类型 → 必须为每输出类型分别定义 trait
- MoonBit 不支持 trait 作为参数类型 → 必须用泛型 `fn[R : Trait] render_type(...)`
- 原型验证 5/5 测试通过确认语法可行，然后全量实施
- `extract_type_expr`（moonbit_struct.mbt 的 from_json 生成）保留独立 match，因代码生成逻辑过于特殊无法抽象

**产出**: 385/385 测试全部通过 0 警告；SchemaType match 从 40 降至 4（-90%）；新增变体修改点从 ~15 降至 ~7。

---

## Phase 34 — `include_names` 选择性导出 + 过滤逻辑提取（v0.7.3）

**目标**: 为三个 named 导出函数新增 `include_names?` 可选参数，支持选择性导出命名 Schema；提取 4 处重复的过滤逻辑。

| 文件 | 变更 |
|------|------|
| `shared_utils.mbt` | 新增 `filter_named_schemas()` 统一过滤逻辑 |
| `prompt.mbt` | `schema_to_prompt_named` 新增 `include_names?` 参数 |
| `json_schema.mbt` | `to_json_schema_named` 新增 `include_names?` 参数 |
| `moonbit_struct.mbt` | 两个 named 函数新增 `include_names?` 参数 |
| `test_prompt_named.mbt` | 6 个 `include_names` 测试 |
| `test_json_schema.mbt` | 5 个 `include_names` 测试 |

**关键决策**:
- `None`=导出全部，`Some([])`=不导出任何内容，`Some([...])`=选择性导出
- 不过滤依赖链——调用者负责维护引用一致性
- struct 函数因 API 不稳定未加测试

**产出**: 396/396 测试全部通过；4 处重复逻辑消除。

---

## Special Phase — 项目结构的重组

将 moon_zod 项目拆分为 4 个子包
| 子包 | 说明 |
|------|------|
| `moon_zod/core` | 核心库，包含所有 Schema 定义、验证器等 |
| `moon_zod/tests` | 测试文件，包含所有 moon_zod 测试 |
| `moon_zod/exporters` | 导出工具，包含 prompt/json_schema/moonbit_struct 等导出功能 |
| `moon_zod/importers` | 导入工具，包含 json_schema -> moon_zod schema 对象转换和代码生成 |

## Phase 35 — 代码生成重构 + 项目模块化 (v0.7.4)

**目标**: 将 `from_json_schema.mbt` 中的混杂逻辑拆分为两层（JSON Schema → Schema → 代码），重构 `schema_to_moon_zod_code` 使其支持命名导出/description/object mode/错误消息，同时完成正式的子包模块化。

### Phase A: 代码生成重构 + 项目模块化

| 新增文件 | 用途 |
|---------|------|
| `exporters/schema_exporter.mbt` | Schema → moon_zod 源码生成器（`schema_to_moon_zod_code`, `_named`, `_inline`） |
| `importers/from_json_schema.mbt` | JSON Schema → Schema 运行时对象（`json_schema_to_schema`，与原代码生成解耦） |
| `core/moon.pkg` / `exporters/moon.pkg` / `importers/moon.pkg` / `tests/moon.pkg` | 四个正式子包声明 |
| 各子包 `reexporter.mbt` | 按包隔离的导出重声明 |
| `tests/test_schema_to_code.mbt` | 9 个代码生成专项测试 |
| `examples/validate_cli/README.md` | validate CLI 使用说明 |

| 修改文件 | 变更 |
|---------|------|
| `exporters/schema_exporter.mbt` | 重写：`schema_to_moon_zod_code` 输出 `let x = ... .name(...)` 格式；新增 `_named` 命名导出；支持 `.describe()` / `.required_error()` / `.invalid_type_error()` / `.strict()` / `.passthrough()` |
| `importers/from_json_schema.mbt` | 重写：新增 `json_schema_to_schema` 返回运行时 Schema 对象；新增 `visiting` 循环检测 + 前向引用处理 |
| `core/shared_utils.mbt` | 新增 `escape_variable_name` / `escape_type_name` / `escape_function_name` |
| `moon.pkg` | 改为 re-export core + exporters + importers |
| `tests/test_json_schema.mbt` | 27 个测试从 `assert_eq` 改为 `.contains()` |
| `cmd/*/main.mbt` | import 路径随子包迁移调整 |

| 移动文件 | 操作 |
|---------|------|
| `*.mbt` → `core/*.mbt` | 核心类型/验证器（17 文件） |
| `*_exporter.mbt`, `prompt.mbt`, `json_schema.mbt`, `moonbit_struct.mbt` → `exporters/*.mbt` | 代码生成器（6 文件） |
| `from_json_schema.mbt` → `importers/from_json_schema.mbt` | JSON Schema 导入器（移除旧的 586 行单体文件） |
| `test_*.mbt` → `tests/test_*.mbt` | 测试文件（13 文件） |

### Phase B: 架构精炼 — combinators 子包 + reexporter 去重

针对 Phase A 遗留的两大问题（`exporters` ← `importers` 依赖颠破、4 份重复 `reexporter.mbt`）进行整改：

| 新增文件 | 用途 |
|---------|------|
| `combinators/moon.pkg` | 组合层包声明，依赖 exporters + importers |
| `combinators/schema_combinators.mbt` | `json_schema_to_moon_zod` 端到端组合函数 |
| `combinators/reexporter.mbt` | re-export exporters + importers（无 `@core` 重导出）|

| 删除文件 | 原因 |
|---------|------|
| `exporters/reexporter.mbt` | 空壳（仅含 `pub using @core`），子包内改为 `@core.` 前缀引用 |
| `importers/reexporter.mbt` | 同上 |

| 修改文件 | 变更 |
|---------|------|
| `exporters/moon.pkg` | 移除 `importers` 依赖 — 消除架构违规 |
| `moon.pkg` (root) | 新增 `combinators` 依赖；添加 `escape_variable_name` |
| `tests/moon.pkg` | 新增 `combinators` 依赖 |
| `tests/reexporter.mbt` | `json_schema_to_moon_zod` 从 `@exporters` 移到 `@combinators`；添加 `escape_variable_name` |
| `exporters/*.mbt` (6 文件) | 所有核心引用加 `@core.` 前缀（`Schema` → `@core.Schema`） |
| `importers/from_json_schema.mbt` | `null()` → `@core.null()` |
| `reexporter.mbt` | `json_schema_to_moon_zod` 从 `@exporters` 移到 `@combinators`；添加 `escape_variable_name` |

**API 重命名**:
- `schema_to_moon_zod_code_with_names` → `schema_to_moon_zod_code_inline_with_refs`

**最终依赖图**:
```
core ← importers
core ← exporters
exporters + importers ← combinators  (组合层)
core + exporters + importers + combinators ← root
core + exporters + importers + combinators ← tests
```

**关键决策**:
- **子包隔离**：core 无外部依赖；exporters 仅依赖 core（不依赖 importers）；importers 仅依赖 core。组合层单独由 `combinators` 包负责。
- **`@core.` 前缀**：子包源码不再依靠 `pub using @core` 重导出，直接通过 `@core.Schema` 等限定名引用。仅有根 `reexporter.mbt` 作为单一 public API 入口。
- **`tests/` 保留 reexporter**：测试代码密集使用核心类型，保留 `tests/reexporter.mbt` 作为便利。
- **两层分离**：`json_schema_to_schema` 返回 Schema 对象（可做解析后处理），`schema_to_moon_zod_code_named` 负责代码生成。组合函数 `json_schema_to_moon_zod` = 两层串联。
- **循环引用**：用 `null().name(name)` 占位 + `visiting` 数组跟踪当前遍历路径。

**Bug 修复**:
- `schema_to_moon_zod_code` 条件反转：`{ schema.name } else { "Root" }` → `{ "Root" } else { schema.name }`

**产出**: 414/414 测试全部通过 0 警告。项目从平铺结构进化为 5 子包模块化结构，架构依赖清晰无违规。

---

## Phase 36 — 代码审查 + 统一导出设计 (v0.7.5)

**目标**: 对 exporters 和 importers 进行深度代码审查，修复语义 Bug，补充测试覆盖，统一所有导出函数的根 schema 命名行为。

### Part A: 代码审查 & 关键问题修复

| 新增文件 | 用途 |
|---------|------|
| `tests/test_json_schema_fixes.mbt` | 12 个专项测试（exclusiveMin/Max 边界、数字枚举、混合枚举、降级行为）|

| 修改文件 | 变更 |
|---------|------|
| `importers/from_json_schema.mbt` | 修复 `exclusiveMinimum`/`exclusiveMaximum` 语义错误；修复浮点数截断 Bug；扩展 enum 支持数字值 |
| `tests/test_json_schema.mbt` | 6 个测试适配新行为 |

**审查发现的 5 个 Bug（全部修复）**:

| # | 问题 | 严重程度 |
|---|------|---------|
| 1 | `exclusiveMinimum: 5` → `.min(5)` 应排他 | 🔴 高 — 语义错误 |
| 2 | `exclusiveMaximum: 10` → `.max(10)` 应排他 | 🔴 高 — 语义错误 |
| 3 | 原 exclusiveMaximum fix 浮点数分支 `max(int_trunc)` 比真实边界更严格 | 🔴 高 — 二次修复 |
| 4 | `minimum`/`maximum` 浮点数截断（`.to_int()` 丢失小数） | 🟡 中 — 精度丢失 |
| 5 | 非字符串 enum 值（数字/布尔/null）静默丢弃 | 🟡 中 — 功能缺失 |

### Part B: 统一导出函数设计

**统一模式** — 所有 7 个公共导出函数增加根 schema 名字保护：

```moonbit
let mut schema = schema
if schema.name.is_empty() {
  schema = schema.name("Root")
}
```

| 应用函数 | 文件 |
|---------|------|
| `schema_to_moon_zod_code` | `exporters/schema_exporter.mbt` |
| `schema_to_moon_zod_code_named` | `exporters/schema_exporter.mbt`（已有） |
| `to_json_schema` | `exporters/json_schema.mbt` |
| `to_json_schema_skeleton` | `exporters/json_schema.mbt` |
| `to_json_schema_named` | `exporters/json_schema.mbt` |
| `schema_to_prompt` | `exporters/prompt.mbt` |
| `schema_to_prompt_named` | `exporters/prompt.mbt` |
| `schema_to_moonbit_struct` | `exporters/moonbit_struct.mbt`（改进：错误消息→自动命名） |
| `schema_to_moonbit_struct_named` | `exporters/moonbit_struct.mbt` |
| `schema_to_moonbit_struct_full` | `exporters/moonbit_struct.mbt`（改进） |
| `schema_to_moonbit_struct_named_full` | `exporters/moonbit_struct.mbt` |

### Part C: CLI 工具易用性整理

**目标**: 让 `cmd/json2schema` 和 `cmd/validate` 更适合真实命令行使用，默认输出更可脚本消费，错误处理更稳定，并同步更新示例文档。

| 文件 | 变更 |
|---|---|
| `cmd/json2schema/main.mbt` | 默认只输出 copy-paste ready moon_zod 代码；新增 `--verbose` / `-v` 打印解析输入；参数解析提取为小 helper |
| `cmd/json2schema/cli.sh` | 简化文件输入；修复 `--from-json-schema` 非文件模式参数重复转发 |
| `cmd/validate/main.mbt` | 移除 `try!` abort 路径；所有 JSON parse 使用 `catch` 输出稳定 `ERROR`；`validate*` 返回 `Bool` 预留 exit code 接入点；help 不再承诺当前不可实现的 exit code |
| `cmd/validate/cli.sh` | 新增 `--schema-file` / `--sample-file` 明确文件模式；保留旧 `--file schema --file data` 兼容写法 |
| `examples/json2schema/README.md` | 更新默认纯代码输出、`--verbose`、JSON Schema 文件输入示例 |
| `examples/validate_cli/README.md` | 更新 JSON Schema 文件模式、sample 推断模式、内联模式示例 |
| `branch_doc/step_phase36_Phase_C_cli_polish.md` | 新增 Phase C 详细记录 |

**关键决策**:
- `json2schema` 默认输出从演示格式切换为纯代码，方便管道和复制；演示信息移入 `--verbose`。
- `validate --schema` 明确表示内联 JSON Schema；文件读取统一交给 `cli.sh`，符合 MoonBit core 无文件 I/O 的现实。
- 当前 MoonBit `core/env` 没有进程退出码 API，因此不再在 help 中承诺 exit code；内部返回 `Bool` 方便未来补齐。

**产出**: `moon check` 通过；`moon test` 426/426 通过；手动 smoke tests 覆盖两个 CLI 的内联与文件输入路径。

### 架构决策：Exporters & Importers 功能冻结

经过 Phase 35（重构模块化）和 Phase 36（审查修复 + 统一导出）两轮迭代，**exporters 和 importers 已达到功能完备、生产就绪状态**：

```
┌────────────────────────────────────────────────────────────┐
│  输入 (Input)         IR (Core)            输出 (Output)   │
│                                                           │
│  JSON Schema    →    Schema 对象    →    moon_zod 代码     │
│  (importers)         13 变体           TypeScript prompt   │
│                       校验管线           JSON Schema        │
│                                         MoonBit struct     │
│                                         + from_json()      │
└────────────────────────────────────────────────────────────┘
```

- 4 个代码生成器：13/13 SchemaType 全覆盖，trait 分发，命名导出
- 1 个 JSON Schema 导入器：主流 draft-07 关键词完整支持
- 0 个已知语义 Bug
- 426 测试全面覆盖

| 指标 | 数值 |
|---|---|
| 测试数量 | **426** |
| 外部依赖 | 0（仅 `moonbitlang/core`） |
| 子包数量 | 5（`core`, `exporters`, `importers`, `combinators`, `tests`） |
| 构建 | 0 errors, 0 warnings |

> 🚩 **自此，exporters 和 importers 的开发告一段落。后续将全力聚焦 core/ 核心校验库的完善和演进。**

---

## Phase 37 — Core API Enhancements (2db4cf6)

**目标**: 新增常用 Schema API：string Transform、array nonempty、bigint 工厂、brand 元数据标记。

**新增文件**:
- `core/bigint.mbt` — `bigint()` 工厂函数（`number().int()` 语义别名）

**修改文件**:
- `core/schema.mbt` — `Schema` 新增 `brand` 字段 + `.brand()` 方法，通过 `message()` / `append_rule_with_annotation()` 等包装器透传 `brand`
- `core/string.mbt` — 新增 `.trim()`, `.to_lower()`, `.to_upper()`；重写 `.nonempty()` 支持 string + array
- `core/transform.mbt` — 修改 `parse_transform` 对外层规则：链式规则作用于 transformed value 而非 inner schema；新增 `brand` 透传
- `core/{array,boolean,default,enum,intersection,literal,null,number,object,optional,union}.mbt` — 构造处补 `brand` 字段
- `tests/reexporter.mbt` — 重新导出 `bigint`
- `tests/test_string.mbt` — +72 行：trim/to_lower/to_upper/nonempty 测试
- `tests/test_array.mbt` — +20 行：array nonempty 测试
- `tests/test_combinators.mbt` — +48 行：brand + bigint 测试

**关键决策**:
- `.trim()/.to_lower()/.to_upper()` 基于 `.transform()` 实现，后续规则校验 transform 后值
- `bigint()` 定位为语义别名而非独立类型（暂不接受 string 编码大整数）
- `.brand()` 仅元数据标记，当前不主动导出到 prompt / JSON Schema

**产出**: 444/444 测试全部通过（0 failed）；`moon info && moon fmt` 通过。

---

## 项目当前状态

| 指标 | 数值 |
|---|---|
| 测试数量 | **444** (▲+18) |
| 外部依赖 | 0（仅 `moonbitlang/core`） |
| 编译器警告 | 0 |
| 子包数量 | 5（`core`, `exporters`, `importers`, `combinators`, `tests`） |
| CLI 工具 | 4 个（`cmd/main` 基准, `cmd/wasm` 跨语言, `cmd/json2schema` 代码生成, `cmd/validate` 校验） |
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
- **缺失验证器**：`.nan()`（MoonBit Double 无 is_nan 构造函数）。

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

#### ☐ Schema 递归类型支持
> 优先级较低

**问题**: 当前无法定义自引用 Schema（树、链表等递归数据结构）。

**任务**:
- [ ] 运行时递归引用机制（延迟解析，类似 `Lazy` 模式）
- [ ] `Schema::lazy(fn() -> Schema)` — 工厂模式延迟定义
- [ ] JSON Schema `$recursiveRef` / `$recursiveAnchor` 支持（draft 2019-09+）
- [ ] Prompt 生成中递归类型渲染（深度限制）
- [ ] JSON Schema 导出中递归引用导出

**价值**: 解锁树形/图形数据结构校验（LLM Agent 工具调用中的嵌套决策树）。

---

#### ☐ 错误消息体系升级

**问题**: 与 Zod 相比，错误消息缺乏结构化（无错误码、无全局映射、无法格式化）。

**任务**:
- [ ] `ValidationError` 新增 `code: String` 字段（machine-readable）
- [ ] `ValidationError::to_formatted_string()` — 多行可读输出
- [ ] `schema.set_error_map(fn(key, params) -> String)` — 全局/局部错误消息映射
- [ ] 错误消息国际化框架（`:i18n_key` 与现有 `msg?` 协作）
- [ ] `msg?` 支持结构化对象（`{ message, code }`）而非仅字符串

**价值**: 让 LLM 自修正循环和开发者调试都获得更精准的反馈。

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

- [ ] 多平台 CI：扩展 GitHub Actions 到 macOS/Windows
- [ ] wasm-gc target：验证兼容性并优化启动开销
- ⏳ derive 宏：需等待 MoonBit 宏系统成熟
> 然而，MoonBit 当前缺乏稳定的宏系统，只支持内置的几个 derive (Debug/Show/Eq/FromJson/ToJson)，无法实现自定义 derive。需要等待未来 MoonBit 引入稳定的宏系统后才能开发此功能。

#### 常驻任务

- 定期检查是否有 "代码坏味道" 出现（重复代码、过长函数、复杂条件分支等），及时重构保持代码质量；定期检查代码质量，保持核心库的简洁和可维护性，可拓展性。
> 如果某个很简单且必要的功能需要引入复杂的实现或大量代码，可能是设计上的坏味道，需要重构以保持核心库的简洁和可维护性。详情见各 `step_phase_details/step_phase_*.md` 文件。
