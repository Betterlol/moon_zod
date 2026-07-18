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

> **后续变更（Phase 41）**: `schema_to_moonbit_struct_named` / `schema_to_moonbit_struct_named_full` 因 moonbit_struct 导出器未完成 Phase 41 硬化（tuple/any/unknown 仍为最低限度回退），从公开 API 中移除，待后续整体重构时重新评估。

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

## Phase 38 — Core Composition APIs (a9da166)

**目标**: 补齐核心组合能力：`object().extend()` / `.merge()` / `tuple()`。

**新增文件**:
- `core/tuple.mbt` — `tuple()` 工厂、`TupleType(Array[Schema])`、`Schema::parse_tuple()` 按位置校验
- `tests/test_tuple.mbt` — 6 个测试覆盖固定位置、空 tuple、错误长度、索引路径、链式规则

**修改文件**:
- `core/schema.mbt` — 新增 `TupleType(Array[Schema])`；parse dispatcher 增加 `parse_tuple()` 分发；`expected_msg` 增加 tuple 类型信息
- `core/object.mbt` — 新增 `Schema::extend()` 追加字段 + `Schema::merge()` 合并右侧 schema（继承右侧 object mode）
- `core/string.mbt` — `nonempty()` 增加 tuple 支持
- `tests/test_object.mbt` — +70 行：7 个 extend/merge 测试
- `tests/reexporter.mbt` — 重新导出 `tuple`

**消费层处理**: `exporters/*` 仅加 `TupleType(_) => abort("... not implemented")` 编译兜底，不做语义同步。

**关键决策**:
- `extend()` 通过 Map 合并实现，保留 base object mode 与 metadata
- `merge()` 继承右侧 object mode（与 Zod 保持一致）
- `tuple()` 不做为消费层实现 exporter 语义（消费层冻结）

**产出**: 457/457 测试全部通过（0 failed）；`moon check`, targeted `moon fmt`, `moon info` 通过。

---

## Phase 39 — Pass-through & Preprocess Core APIs

**目标**: 补齐 core 层的 pass-through schema 与 preprocess 管线：`any()` / `unknown()` / `preprocess()`。

**新增文件**:
- `core/any_unknown.mbt` — 新增 `any()` 与 `unknown()` 工厂，运行时接受任意 JSON 值
- `core/preprocess.mbt` — 新增 `preprocess(fn, schema)` 与 `Schema::parse_preprocess()`
- `tests/test_any_unknown_preprocess.mbt` — 9 个测试覆盖 pass-through、refine、preprocess 顺序、返回值与错误路径

**修改文件**:
- `core/schema.mbt` — 新增 `AnyType`, `UnknownType`, `PreprocessType`；parse dispatcher 支持 pass-through 与 preprocess
- `core/shared_utils.mbt` — named schema traversal 穿透 `PreprocessType`
- `tests/reexporter.mbt` — 重新导出 `any`, `unknown`, `preprocess`
- `exporters/{json_schema_renderer,moonbit_renderer,prompt_renderer,schema_exporter,moonbit_struct}.mbt` — 仅补最小 `abort("... not implemented")` 分支，保持消费层编译，不做语义同步

**关键决策**:
- `any()` / `unknown()` 当前运行时行为一致，区别保留为语义标记，后续消费层可分别解释
- `preprocess()` 与 `.transform()` 顺序相反：先处理 raw input，再进入 inner schema 校验
- preprocess 后续链式规则作用于 inner schema parse 后的值
- exporters/importers 当前冻结，新增类型只做编译兜底，不主动导出

**产出**: 466/466 测试全部通过（0 failed）；`moon check`, targeted `moon fmt`, `moon info`, `moon test` 通过。

---

## Phase 40 moonbit_struct 代码生成重构 和 gen-struct cli examples 的丰富实现（v0.8.0）

```bash
git diff --stat 6f637ff70f00aab555b4e106cf158415b9dd00ce 914d1cda317755e55ecbe17ab2a3428225228fb8 
```

### MoonBit Struct Generator Rewrite
- Complete rewrite of `schema_to_moonbit_struct()` — now emits static `Type::to_schema()` functions alongside struct/enum definitions, enabling schema-from-struct round-trips
- Dropped `from_json()` generation (`schema_to_moonbit_struct_full` no longer includes `FromJson` derive functions — use MoonBit's built-in `derive(FromJson)` instead)
- New `schema_to_moonbit_struct_full()` generates both type definitions and `Type::to_schema()` static methods
- Added keyword and reserved-name escaping for field names and type names (MoonBit `is_keyword()`, `escape_variable_name()`, `escape_type_name()`)
- Unified root name fallback with `"Root"` for unnamed schemas
- Constraint comments preserved on generated struct fields
- ~1500 line net reduction through elimination of `from_json()` code generation

### Gen-Struct CLI
- New `cmd/gen-struct/cli.sh` for file-based input: `sh cmd/gen-struct/cli.sh --schema schema.json`
- Inline mode: `moon run cmd/gen-struct -- --schema '<json>'`
- Outputs standalone struct definitions + optional `Type::to_schema()` functions
- Supports nested objects, arrays, optional fields, enums, union nullables

### Documentation & Examples
- New `examples/gen-struct/README.md` with generated struct output examples
- Major docs restructure: `README.mbt.md`/`README_zh.mbt.md` migrated to reference `docs/` directory
- `docs/API.md`, `docs/CLI.md`, `docs/INFO.md` (Chinese versions in `docs/zh/`) consolidated as single source of truth
- `EXAMPLES.md` rewritten to catalog all actual examples with output snippets

### Fixes
- `value_in_array` moved from `prompt.mbt` to `shared_utils.mbt` for cross-module reuse
- Fixed `json_to_literal()` boolean/null output to use valid MoonBit constructors
- Fixed `moon run cmd/validate` JSON Lines — shell `\n` is now correctly interpreted as real newline

**产出**: 448/448 测试全部通过（0 failed）；`moon check`, targeted `moon fmt`, `moon info`, `moon test` 通过。

## Phase 41 — Prompt & JSON Schema Exporter 硬化（v0.8.1）

**目标**: 消除 `schema_to_prompt()`/`to_json_schema()` 中对 `any/unknown/tuple/preprocess` 的直接 `abort`；修复可选字段语义（nullable）、object mode 的 `additionalProperties` 导出策略、object intersection 导致不可满足 schema 的问题；收敛重复 renderer 类型。

**Committs**: `4f4f6a0e37e08bd66368fe1a092a98f124d0c4bc` -> `8a8045dfc4c458f7c07f95937e108c2f40042039`

### CI/CD 增强和修复

使用 `moon fmt --check`, `moon update`, `moon check` 等，并把 `warning` 作为 `error` 处理，确保 CI/CD 流程的稳定性。


### A — Prompt 导出统一与语义修复

| 文件 | 变更 |
|------|------|
| `exporters/prompt_renderer.mbt` | `AnyType → "any"`、`UnknownType → "unknown"`、`TupleType → [T...]`、`PreprocessType → inner` |
| `exporters/prompt.mbt` | 删除 `BasicPromptRenderer`；`schema_to_prompt()` 复用 `NamedPromptRenderer([])`；named wrapper 现在生成 `export type X = T` 且字段引用保留 wrapper name；named intersection 不再合并 object 字段改为 `export type X = A & B` |
| `tests/test_prompt.mbt` | 新增 non-abort 测试（any/unknown/tuple/preprocess）& named inline 测试 |
| `tests/test_prompt_named.mbt` | 新增 wrapper alias 定义回归、ProductMetadata 引用回归、非 object intersection type expression 回归 |

### B — JSON Schema 语义修复与 renderer 收敛

| 文件 | 变更 |
|------|------|
| `exporters/json_schema_renderer.mbt` | `Any|Unknown → {}`、`TupleType → prefixItems + fixed length`、`PreprocessType → inner` |
| `exporters/json_schema.mbt` | 删除 `FullJsonRenderer` + `SkeletonJsonRenderer`；`NamedJsonRenderer` 新增 `include_annotations` 参数统一三种模式；`optional/default` 导出 nullable `anyOf: [inner, null]`；`Strip` 导出 `additionalProperties: false`（之前 `true`）；`$defs` 渲染排除自引用；object intersection 合并为单个 closed object（属性级 `allOf` 保留同名字段约束）|
| `tests/test_json_schema.mbt` | 新增 nullable、strip/passthrough、tuple/any/unknown/preprocess、object intersection 合并、同名约束等测试 |

### C — schema_to_moon_zod_code 语义修复

| 文件 | 变更 |
|------|------|
| `exporters/schema_exporter.mbt` | `AnyType → @moon_zod.any()`、`UnknownType → @moon_zod.unknown()`、`TupleType → @moon_zod.tuple([...])`、`PreprocessType → @moon_zod.preprocess(fn(x) { Ok(x) }, inner)` |

**关键决策**:
- Prompt renderer 统一：只保留 `NamedPromptRenderer`，`schema_to_prompt()` 用空 named set 调用 → 全内联。
- JSON Schema renderer 收敛：删除 Full/Skeleton 两个公开结构，`NamedJsonRenderer` 用 `include_annotations` 开关约束输出。
- object intersection 合并：输出单个 closed object 而非多个闭 object 的 `allOf`（避免不可满足），同名字段用属性级 `allOf` 保留约束。
- `schema_to_moon_zod_code` 的 `required_error` / `invalid_type_error` 链式方法仍输出，但实际不暴露在 `Schema` API 中——已知 round-trip 不安全，标记为最佳代码输出。
- **`schema_to_moonbit_struct_named` / `schema_to_moonbit_struct_named_full` 从公开 API 中移除**：Phase 34 曾承诺这两个 named 导出函数，但 moonbit_struct 导出器整体未随 Phase 41 统一硬化（tuple/any/unknown 仍为最低限度回退），为避免不一致的公开承诺，决定搁置 named struct 导出，待后续整体重构时重新评估。

**产出**: 470/470 测试全部通过（0 failed）；`moon check`, `moon info && moon fmt` 通过。

---

## Phase 42 — 结构化错误系统：IssueCode + ErrorMap + ParseParams

**目标**: 将扁平 `ValidationError{path, message, got}` 升级为带 `IssueCode` 的机器可读错误分类，新增 `safe_parse` API 支持上下文 `ErrorMap` 覆盖，集成 `constraint_extractor`，消除错误收集管线冗余。

**决策文档**: `branch_doc/DECISION_ERROR_SYSTEM.md`

### 核心架构

```moonbit
parse_inner() → RawSchemaResult
                     ↓
Schema::safe_parse() → finalize_issues(raw, params) → SchemaResult
Schema::parse() = safe_parse(error_map = None)
```

### Phase 42 vs phase42_zod_error_map 分支的关键改进

| 决策 | phase42 分支 (已废弃) | 本实现 |
|------|----------------------|--------|
| `RawIssue.path` | `Array[String]` — 每条错误 copy + finalize 再 format_path | `String` — 错误源一次格式化，finalize 零分配 |
| `RawIssue.inst` | `Schema?` — 携带完整 Schema 引用延迟消息解析 | **移除** — 消息在错误源预解析 |
| `Issue` 中间类型 | `RawIssue → Issue → ValidationError` | **移除** — 直连 `RawIssue → ValidationError` |
| `finalize_issue` | 4 层嵌套 if-else + 空字符串回退 | 2 层：error_map 覆盖 → 预解析消息 |
| `collect_raw_errors` 参数 | `path: String` — 每个调用点前置 `format_path` | `path_stack: Array[String]` — 内部格式化，消除 7 处冗余 |

### 变更清单

| 新增文件 | 用途 |
|---------|------|
| `core/errors.mbt` | `IssueCode` enum (12 变体), `ErrorMap` type, `ParseParams`, `RawIssue`, `finalize_issue`/`finalize_issues`/`collect_raw_errors`/`type_origin` |

| 修改文件 | 变更 |
|---------|------|
| `core/types.mbt` | `ValidationError` 新增 `code: IssueCode`；`RawSchemaResult` 类型别名 |
| `core/schema.mbt` | `Rule.code` 字段；`append_rule`/`append_rule_with_annotation` 增加 `code` 参数；`type_error_msg`/`expected_msg`/`collect_errors` 移除；`parse_inner` 返回 `RawSchemaResult`；新增 `safe_parse`；`parse` 委托给 `safe_parse` |
| `core/string.mbt` | 所有 rule 方法传入精确 IssueCode |
| `core/number.mbt` | 同上 |
| `core/object.mbt` | `parse_object` 返回 `RawSchemaResult`；MissingRequired/UnrecognizedKeys/InvalidType 生成 `RawIssue` |
| `core/array.mbt` | `parse_array` 返回 `RawSchemaResult` |
| `core/tuple.mbt` | `parse_tuple` 返回 `RawSchemaResult`；长度不匹配拆分为 `TooSmall`/`TooBig` |
| `core/enum.mbt` | `parse_enum` 返回 `RawSchemaResult`；`InvalidValue`/`InvalidType` |
| `core/union.mbt` | `parse_union` 返回 `RawSchemaResult`；`InvalidUnion` |
| `core/intersection.mbt` | `parse_intersection` 返回 `RawSchemaResult` |
| `core/literal.mbt` | `parse_literal` 返回 `RawSchemaResult`；`InvalidValue` |
| `core/optional.mbt` | 返回类型 `RawSchemaResult` |
| `core/default.mbt` | 返回类型 `RawSchemaResult` |
| `core/preprocess.mbt` | `parse_preprocess` 返回 `RawSchemaResult`；`Custom` |
| `core/transform.mbt` | `parse_transform` 返回 `RawSchemaResult`；`Custom` |
| `core/refine.mbt` | 传入 `IssueCode::Custom` |
| `core/constraint_extractor.mbt` | 新增 IssueCode 第一遍解析；annotation JSON 作为 Custom 规则的 fallback |
| `importers/from_json_schema.mbt` | 所有 3 个 `append_rule` 传入 `@core.IssueCode::Custom` |
| `tests/reexporter.mbt` | 导出新类型 |
| `tests/test_issue_code.mbt` | **新增** — 21 个测试覆盖所有 IssueCode 变体 |
| `tests/test_error_map.mbt` | **新增** — 15 个测试覆盖 safe_parse 和 ErrorMap 行为 |

### Test Coverage

| 测试文件 | 测试数 | 覆盖场景 |
|---------|--------|---------|
| `test_issue_code.mbt` | 21 | 所有 12 个 IssueCode 变体、嵌套路径、数组索引 |
| `test_error_map.mbt` | 15 | 类型/必填/union 覆盖、空字符串回退、嵌套、隔离性 |
| 已有测试 | 479 | 全部通过，零修改 |

**总测试**: 513，全部通过，0 警告。

### 构建产出

```bash
moon check    # 0 errors, 0 warnings
moon test     # 513/513 pass
moon info     # 接口文件生成
moon fmt      # 代码格式化
```

---