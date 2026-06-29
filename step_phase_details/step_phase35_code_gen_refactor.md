# Stage Summary

## 1. Stage Description

对 `schema_to_moon_zod_code`（Schema → MoonBit 源码）和 `json_schema_to_schema`（JSON Schema → Schema 运行时对象）两个核心管线进行全面重构，将原先混杂在 `from_json_schema.mbt` 中的代码生成逻辑拆分为两层职责独立的模块。同时完成项目结构重整，建立 `core/`、`exporters/`、`importers/`、`tests/` 四个正式子包。

## 2. Stage Metadata

- STAGE_ID: phase-35
- STAGE_TYPE: refactor + feature
- COMMITS:
  - `02b97c9` (baseline)
  - `8e19397` — `json_schema_to_schema`: runtime JSON Schema parser
  - `ee9058b` — 模块拆分与代码生成重构
  - `a3722f1` — `schema_to_moon_zod` code generation fix
  - `da934d2` — 完成彻底重构，消除所有 warning
  - `b145e38` — Phase B: combinators 子包 + reexporter 去重 + API 重命名

## 3. 架构变更

### 3.1 项目结构重整

```
旧结构（平铺）:             新结构（子包）:
moon_zod/                   moon_zod/
├── types.mbt                ├── core/        # moon.pkg — 核心类型 + 验证器
├── schema.mbt               │   ├── types.mbt, schema.mbt
├── string.mbt               │   ├── string.mbt, number.mbt, ...
├── ...                      │   └── moon.pkg
├── from_json_schema.mbt     ├── exporters/   # moon.pkg — 代码生成器
├── json_schema.mbt          │   ├── schema_exporter.mbt
├── prompt.mbt               │   ├── json_schema.mbt, prompt.mbt, ...
├── moonbit_struct.mbt       │   └── moon.pkg
├── reexporter.mbt           ├── importers/   # moon.pkg — JSON Schema 导入
└── test_*.mbt               │   ├── from_json_schema.mbt
                             │   └── moon.pkg
                             ├── tests/       # moon.pkg — 全量测试
                             │   ├── test_*.mbt
                             │   └── moon.pkg
                             ├── reexporter.mbt     (顶层再导出)
                             └── moon.pkg
```

每个子包拥有独立的 `moon.pkg` 和 `reexporter.mbt`，顶层 `reexporter.mbt` 统一 re-export 三个子包。
测试包依赖 core + exporters + importers。

### 3.2 两层职责分离

```
┌─────────────────────────────────────────────────────────┐
│                    Phase 35 架构                          │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  [importers/from_json_schema.mbt]                       │
│  Layer 1: JSON Schema → Schema 对象                      │
│  pub fn json_schema_to_schema(json) -> Schema            │
│                                                         │
│  [exporters/schema_exporter.mbt]                         │
│  Layer 2: Schema 对象 → moon_zod 源码                     │
│  pub fn schema_to_moon_zod_code(schema) -> String        │
│  pub fn schema_to_moon_zod_code_named(schema) -> String  │
│                                                         │
│  [exporters/schema_exporter.mbt]                         │
│  组合: JSON Schema → moon_zod 源码                        │
│  pub fn json_schema_to_moon_zod(json) -> String          │
│  (= Layer 2 ∘ Layer 1)                                  │
└─────────────────────────────────────────────────────────┘
```

## 4. 功能变更

### 4.1 `exporters/schema_exporter.mbt` — 代码生成重构

| 函数 | 变更 |
|------|------|
| `schema_to_moon_zod_code` | **语义变更**：现在总是生成 `let <name> = <code>.name("<name>")` 包装格式 |
| `schema_to_moon_zod_code_with_names` | **入参变更**：`defined_names: Array[String]` → `include_names: Array[String]?` |
| `schema_to_moon_zod_code_named` | **新增**：收集所有命名 Schema，拓扑排序后逐个输出 `let` 定义 |
| `schema_to_moon_zod_code_inline` | **新增**（原 `_with_refs` 重命名）：生成内联表达式，支持可选的名字引用替换 |

**新增特性**：
- `.describe()` 描述文本输出
- `.required_error()` / `.invalid_type_error()` 类型级错误消息输出
- 对象模式 `.strict()` / `.passthrough()` 输出（默认 Strip 不输出）
- 导出变量名首字母小写（`escape_variable_name`），符合 MoonBit 命名规范
- named schema 引用用变量名直接引用而非 `Name_schema` 格式

### 4.2 `importers/from_json_schema.mbt` — JSON Schema 导入重构

| 方面 | 旧实现 | 新实现 |
|------|--------|--------|
| 输出 | 直接生成 MoonBit 源码字符串 | 先生成 Schema 运行时对象，再可选转代码 |
| 循环引用 | `/* TODO: circular reference */` 注释 | 用 `null().name(name)` 占位 |
| 前向引用 | 无处理，$ref 可能失败 | 主动检测并递归处理前向引用 |
| 遍历 | `visiting` 参数跟踪当前路径防循环 | 同左，但新增前向引用处理 |
| API | `json_schema_to_moon_zod(Json)` — 单一入口 | `json_schema_to_schema(Json) → Schema` + `json_schema_to_moon_zod(Json) → String` |
| `$defs` 处理 | 单次扫描，不支持循环 | 两遍：先处理所有 `$defs` 建 cache，再解析根 |

### 4.3 `core/shared_utils.mbt` — 新增工具函数

```moonbit
pub fn escape_variable_name(name : String) -> String   // 首字母小写
pub fn escape_function_name(name : String) -> String   // 同 escape_variable_name
pub fn escape_type_name(name : String) -> String        // 首字母大写
pub fn escape_mbt_string(s : String) -> String          // 从 schema_exporter 移入
pub fn escape_ident(name : String) -> String            // 从 schema_exporter 移入
```

## 5. 文件变更清单

### 新增文件
| 文件 | 用途 |
|------|------|
| `core/moon.pkg` | core 包声明 |
| `exporters/moon.pkg` | exporters 包声明（依赖 core） |
| `exporters/reexporter.mbt` | exporters 导出重声明 |
| `exporters/schema_exporter.mbt` | Schema → moon_zod 源码代码生成器 |
| `importers/moon.pkg` | importers 包声明（依赖 core） |
| `importers/reexporter.mbt` | importers 导出重声明 |
| `importers/from_json_schema.mbt` | JSON Schema → Schema 运行时对象导入器 |
| `tests/moon.pkg` | tests 包声明（依赖 core + exporters + importers） |
| `tests/reexporter.mbt` | tests 导出重声明 |
| `tests/test_schema_to_code.mbt` | Schema → 代码生成专项测试 |
| `cmd/validate/cli.sh` | validate CLI 示例脚本 |
| `examples/resources/Product_Json_Data.json` | 示例数据 |
| `examples/resources/Product_Json_Schema.json` | 示例 Schema |
| `examples/validate_cli/README.md` | validate CLI 使用说明 |

### 移动文件（R100）
core 目录：`array.mbt`, `boolean.mbt`, `default.mbt`, `enum.mbt`, `intersection.mbt`, `literal.mbt`, `moon_zod_wbtest.mbt`, `null.mbt`, `number.mbt`, `object.mbt`, `optional.mbt`, `refine.mbt`, `schema.mbt`, `string.mbt`, `transform.mbt`, `types.mbt`, `union.mbt`
exporters 目录：`json_schema.mbt`, `json_schema_renderer.mbt`, `moonbit_renderer.mbt`, `moonbit_struct.mbt`, `prompt.mbt`, `string_renderer.mbt`
tests 目录：`test_array.mbt`, `test_boolean_null.mbt`, `test_combinators.mbt`, `test_custom_message.mbt`, `test_errors.mbt`, `test_json_schema.mbt`, `test_moonbit_struct.mbt`, `test_number.mbt`, `test_object.mbt`, `test_prompt.mbt`, `test_prompt_named.mbt`, `test_string.mbt`, `test_transform_refine.mbt`

### 修改文件
| 文件 | 变更 |
|------|------|
| `core/shared_utils.mbt` | 新增 escape_variable_name / escape_function_name / escape_type_name |
| `core/schema.mbt` | 少量 import 调整 |
| `core/test_utils.mbt` | import 调整 |
| `core/constraint_extractor.mbt` | import 路径调整 |
| `moon.pkg` | 改为 re-export core + exporters + importers |
| `reexporter.mbt` | 顶层统一再导出 |
| `cmd/json2schema/main.mbt` | import 路径调整 |
| `cmd/gen-struct/main.mbt` | import 路径调整 |
| `cmd/validate/main.mbt` | import 路径调整 |
| `cmd/json2schema/cli.sh` | 路径调整 |
| `docs/*.md`, `README*.md` | 文档更新 |
| `examples/*` | 示例路径与 README 调整 |

### 删除文件
| 文件 | 原因 |
|------|------|
| `from_json_schema.mbt` | 拆分为 importers/ 版（仅留 parser，代码生成移至 exporters/schema_exporter.mbt）|

## 6. 测试

| 指标 | 数值 |
|------|------|
| 测试总数 | 396 → 414 |
| 新增测试 | 18（`test_schema_to_code.mbt` 中 9 个 + `test_json_schema.mbt` 中 9 个+） |
| 测试通过 | 414/414 |

### 新增测试场景（`tests/test_schema_to_code.mbt`）
- unnamed string schema（用 contains 适配新输出格式）
- string with constraints + description
- object with strict/passthrough/strip mode
- schema with description (含中文)
- `schema_to_moon_zod_code_named` with `include_names` 过滤
- named root schema
- unnamed root schema（自动赋名 Root）

### 变更测试（`tests/test_json_schema.mbt`）
- 27 个 `json_schema_to_moon_zod` 测试从 `assert_eq` 改为 `.contains()` 子串匹配，适配新输出格式
- `$defs with $ref` 测试断言更新为变量名首字母小写格式
- 循环引用测试从 `TODO` 注释改为 `null()` 占位

## 7. 已知问题

### 已修复
- ~~`schema_to_moon_zod_code` 条件写反：`if schema.name.is_empty() { schema.name } else { "Root" }` → `{ "Root" } else { schema.name }`~~ (commit 之后修复)
- ~~`exporters` ← `importers` 依赖违规~~（`combinators/` 子包消除）
- ~~4 份重复 `pub using @core` 的 `reexporter.mbt`~~（删除 `exporters/` 和 `importers/` 的，改用 `@core.` 前缀）
- ~~缺少 `escape_variable_name` 在根 reexporter 中~~（已添加）
- ~~`schema_to_moon_zod_code_with_names` 命名模糊~~（重命名为 `_inline_with_refs`）

### 仍存在的潜在问题
- 测试从 `assert_eq` 退化为 `.contains()`，无法捕捉多余的 `.name()` 调用等异常
- 循环引用产生 `null()` 占位，输出代码可能运行时失败（不如 `TODO` 注释诚实）
- `schema_to_moon_zod_code` 返回值格式变更（从纯表达式变为赋值语句），非向后兼容
- `tests/reexporter.mbt` 仍保留 `pub using @core`，与根 reexporter 重复（有意为之，测试密集使用）

## 8. Phase B — 架构精炼 (b145e38)

### 8.1 动机
Phase A 建立子包结构后引入了一个架构违规（exporters 依赖 importers）和 reexporter 代码重复。Phase B 专门解决这两个问题。

### 8.2 核心变更

#### 架构：新建 `combinators/` 子包
```diff
- 旧: exporters ← importers (违规)
+ 新: combinators ← exporters + importers (正确的组合层)
```
`json_schema_to_moon_zod`（端到端组合函数）从 `exporters/schema_exporter.mbt` 移入 `combinators/schema_combinators.mbt`。`exporters/moon.pkg` 移除对 `importers` 的依赖。

#### Reexporter 去重
- 删除 `exporters/reexporter.mbt` 和 `importers/reexporter.mbt`
- 子包源码中所有核心引用改为 `@core.` 前缀：`Schema` → `@core.Schema`，`string()` → `@core.string()`，`collect_named_schemas()` → `@core.collect_named_schemas()` 等
- `null()` 工厂调用改为 `@core.null()`（importers 中 3 处）
- `combinators/reexporter.mbt` 仅含 `pub using @exporters` + `pub using @importers`，无 `@core` 重导出
- `tests/reexporter.mbt` 保留（测试密集使用核心类型）
- 根 `reexporter.mbt` 作为唯一全量 public API 入口，新增 `escape_variable_name`

#### API 重命名
`schema_to_moon_zod_code_with_names` → `schema_to_moon_zod_code_inline_with_refs`

### 8.3 文件变更
| 操作 | 文件 | 说明 |
|------|------|------|
| 新增 | `combinators/moon.pkg` | 依赖 exporters + importers |
| 新增 | `combinators/schema_combinators.mbt` | `json_schema_to_moon_zod` |
| 新增 | `combinators/reexporter.mbt` | 精简导出 |
| 删除 | `exporters/reexporter.mbt` | 空壳移除 |
| 删除 | `importers/reexporter.mbt` | 空壳移除 |
| 修改 | 6 个 exporters 源文件 | `@core.` 前缀化 |
| 修改 | `importers/from_json_schema.mbt` | `null()` → `@core.null()` |
| 修改 | `exporters/moon.pkg` | 移除 importers 依赖 |
| 修改 | `moon.pkg` (root) | 添加 combinators |
| 修改 | `reexporter.mbt` (root) | combinators + escape_variable_name |
| 修改 | `tests/moon.pkg` | 添加 combinators |
| 修改 | `tests/reexporter.mbt` | combinators + escape_variable_name + inline_with_refs |

### 8.4 最终依赖图
```
core (moonbitlang/core + moon_zod core)
├── importers  (json_schema_to_schema)
├── exporters  (code generation)
├── combinators (composition, depends on exporters + importers)
└── root (public API, depends on all of the above)
tests (depends on all packages)
```
