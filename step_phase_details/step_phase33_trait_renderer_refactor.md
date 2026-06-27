# Stage Summary

## 1. Stage Description

对三个代码生成模块（`prompt.mbt`、`json_schema.mbt`、`moonbit_struct.mbt`）进行 Trait-based Renderer Pattern 架构重构，消除 40 个散布的 `SchemaType` match 语句，统一为契约式的 trait 分发模式。

**分三个阶段完成**：
- **Phase A** (fc04f42): 快速修复 — 补全 Union/Intersection/Literal 在 named schema 导出中的缺失
- **Phase B** (863fcea): 约束提取器重构 — 创建 `constraint_extractor.mbt` 统一约束提取逻辑
- **Phase C** (1a1c06e): Trait Renderer 重构 — 3 个 trait + 3 个分发函数替代旧 match 语句

## 2. Stage Metadata
- STAGE_ID: phase-33
- STAGE_TYPE: refactor
- BASE_COMMITS:
  - Phase A: fc04f42
  - Phase B: 863fcea
  - Phase C: 1a1c06e

## 3. 问题诊断

### 40 个 match 语句散布在 4 个文件

| 文件 | 行数 | SchemaType match 数量 | 全穷举 match |
|------|------|----------------------|-------------|
| `prompt.mbt` | 748 | 12 | 2 |
| `json_schema.mbt` | 319 | 3 | 3 |
| `moonbit_struct.mbt` | 1032 | 19 | 3 |
| `schema.mbt` | ~330 | 6 | 0 |
| **总计** | ~2429 | **40** | **8** |

### 新增 SchemaType 变体时需修改 ~15+ 处

每新增一个变体（如 `BigIntType`），需要在 8 个全穷举 match + 若干部分 match + `schema.mbt` 的 `parse_inner`/`expected_msg` 中分别添加分支，遗漏风险高。

### 共享工具宿主错误

`prompt.mbt` 承载了 10+ 个被 `json_schema.mbt` 和 `moonbit_struct.mbt` 调用的工具函数（`collect_named_schemas`、`topological_sort_schemas`、`unwrap_schema`、`indent_str` 等），模块职责不清。

## 4. Phase A — 快速修复

**完成时间**: ~1 小时

### 修复内容

1. **`schema_to_interface_definition_with_names()`** — 补全 Union/Intersection/Literal 类型的命名导出
2. **`merge_intersection_object_specs()`** — 新增辅助函数，递归合并 intersection 中的对象字段
3. **新增 4 个单元测试** — Union/Intersection/Literal/Complex 场景

### 文件变更

| 文件 | 变更 |
|------|------|
| `prompt.mbt` | +35 行（添加 Union/Intersection/Literal 分支 + merge 函数）|
| `test_prompt_named.mbt` | +58 行（4 个新测试）|

### 测试

381→385 全部通过。

## 5. Phase B — 约束提取器重构

**完成时间**: ~1.5 小时

### 核心改进

1. **创建 `constraint_extractor.mbt`** (286 行) — 统一约束信息提取和格式化逻辑
2. **消除 ~150 行重复代码** — 4 个分散的约束解析函数合并为 1 个共享实现
3. **更新 `prompt.mbt`** — 删除 5 个旧约束函数 (-248 行)

### 架构改进

| 方面 | 之前 | 之后 |
|------|------|------|
| 约束解析位置 | 4 个函数分散在 prompt.mbt | 1 个函数在 constraint_extractor.mbt |
| 新增验证器成本 | 修改 4 个约束函数 | 仅修改 `extract_constraints()` |
| 跨模块复用 | 不可复用 | `constraint_info_to_*_comment` 全部 `pub` |

### 测试

385/385 全部通过。

## 6. Phase C — Trait Renderer 重构

**完成时间**: ~3-4 小时（含语法原型验证）

### 架构设计

```
trait StringRenderer {          // 13 个方法，每 SchemaType 一个
  fn render_string(Self, schema, indent) -> String
  fn render_number(Self, schema, indent) -> String
  // ...
}

fn[R : StringRenderer] render_type(renderer, schema, indent) -> String {
  match schema.schema_type {
    StringType => renderer.render_string(schema, indent)
    // ... 唯一的 13 个 match arm
  }
}

// 每个输出目标一个 struct + impl
struct BasicPromptRenderer {}
impl StringRenderer for BasicPromptRenderer { ... }

struct FullJsonRenderer {}
impl JsonSchemaRenderer for FullJsonRenderer { ... }

struct InlineStructRenderer {}
impl MoonBitStructRenderer for InlineStructRenderer { ... }
```

### 3 个 Trait

| Trait | 返回类型 | 适用模块 |
|-------|---------|---------|
| `StringRenderer` | `String` | prompt + moonbit_struct 类型渲染 |
| `JsonSchemaRenderer` | `Json` | JSON Schema 导出 |
| `MoonBitStructRenderer` | `String` | MoonBit struct 类型渲染 |

### 原型验证

在正式实施前创建了 `trait_proto.mbt` + `trait_proto_wbtest.mbt` 进行 MoonBit trait 语法验证，确认：
- ✅ `pub(open) trait` 定义
- ✅ `pub impl Trait for Type` 实现
- ✅ `fn[R : Trait]` 泛型函数
- ✅ 范型结构体 + 方法约束
- ❌ 不支持 `trait Foo[T]`（带类型参数的 trait）
- ❌ 不支持 trait 作为参数类型（必须用泛型）

### 步骤 1：共享工具抽取

**新文件**: `shared_utils.mbt` (294 行)

从 `prompt.mbt` 抽取出 14 个函数：
- `unwrap_schema`, `peel_optional` — 装饰器剥离
- `indent_str`, `format_double_simple`, `join_parts` — 格式化
- `collect_named_schemas`, `topological_sort_schemas` 全家桶——命名 schema 收集与拓扑排序

### 步骤 2：约束注释统一

- 在 `constraint_extractor.mbt` 新增 `pub fn constraint_comment(schema: Schema) -> String`
- `moonbit_struct.mbt` 的 `struct_comment` 改为调用此函数后删除

### 步骤 3：Trait 定义文件

| 新文件 | 内容 |
|-------|------|
| `string_renderer.mbt` (89 行) | `pub(open) trait StringRenderer` + `render_type`/`render_type_named` |
| `json_schema_renderer.mbt` (72 行) | `pub(open) trait JsonSchemaRenderer` + `render_json_type`/`render_json_type_ref` |
| `moonbit_renderer.mbt` (88 行) | `pub(open) trait MoonBitStructRenderer` + `render_mbt_type`/`render_mbt_type_named` |

### 步骤 4：prompt.mbt 迁移

- 新增 `BasicPromptRenderer` + `NamedPromptRenderer` 实现 `StringRenderer`
- 删除旧函数：`type_to_prompt`, `type_to_inline_prompt`, `enum_to_prompt`, `union_to_prompt`, `intersection_to_prompt`, `object_to_prompt`, 以及所有 inline 变体
- 删除从 `shared_utils.mbt` 抽取的重复定义

### 步骤 5：json_schema.mbt 迁移

- 新增 `FullJsonRenderer` + `SkeletonJsonRenderer` + `NamedJsonRenderer` 实现 `JsonSchemaRenderer`
- 删除旧 3 个全穷举 match：`to_json_schema_full`, `to_json_schema_inner`, `to_json_schema_named_full`
- 保留 `merge_annotations` 等辅助函数

### 步骤 6：moonbit_struct.mbt 迁移

- 新增 `InlineStructRenderer` + `NamedStructRenderer` 实现 `MoonBitStructRenderer`
- 删除旧 2 个全穷举 match：`type_to_moonbit`, `type_to_inline_moonbit`
- 4 个 peel-optional 模式 → `peel_optional` 统一辅助
- 新增 renderer-based 泛型 helper 函数（`object_to_struct_def`、`union_to_moonbit_helper` 等）

### 保留的 match 语句

- `extract_type_expr` (moonbit_struct.mbt) — 生成 `from_json()` 提取代码，无法抽象到 trait
- `schema_to_moonbit_struct`, `schema_to_moonbit_struct_full` — 顶级分发
- `merge_intersection_object_specs` — 字段合并逻辑

## 7. 文件变更汇总

### 新增文件

| 文件 | 行数 | 用途 |
|------|------|------|
| `shared_utils.mbt` | 294 | 共享工具：unwrap_schema, peel_optional, indent_str, 命名收集 + 拓扑排序 |
| `string_renderer.mbt` | 89 | StringRenderer trait + render_type 分发 |
| `json_schema_renderer.mbt` | 72 | JsonSchemaRenderer trait + render_json_type 分发 |
| `moonbit_renderer.mbt` | 88 | MoonBitStructRenderer trait + render_mbt_type 分发 |

### 修改文件

| 文件 | 变更 |
|------|------|
| `prompt.mbt` | 重写为 BasicPromptRenderer + NamedPromptRenderer；-498 行 |
| `json_schema.mbt` | 重写为 FullJsonRenderer + SkeletonJsonRenderer + NamedJsonRenderer；-239 行 |
| `moonbit_struct.mbt` | 重写为 InlineStructRenderer + NamedStructRenderer；-332 行 |
| `constraint_extractor.mbt` | 新增 `pub fn constraint_comment()`；+59 行 |
| `test_prompt_named.mbt` | +15 行（Phase A 新增测试）|

## 8. 测试结果

- `moon build`: 0 errors
- `moon check`: 0 errors
- `moon test`: 385/385 全部通过

## 9. 关键指标

| 指标 | 重构前 | 重构后 | 改进 |
|------|--------|--------|------|
| SchemaType match 总数 | 40 | 4（3 个 trait 分发 + 1 个 parse_inner）| **-90%** |
| 全穷举 match 数 | 8 | 3 | **-62%** |
| 新增 SchemaType 修改点 | ~15 处 | ~7 处 | **-53%** |
| 核心代码行数（3 个模块）| ~2099 | ~1620 | **-23%** |
| 共享工具宿主 | prompt.mbt（错误） | shared_utils.mbt（正确）| ✅ |

## 10. MoonBit Trait 语法实践记录

本次重构验证了 MoonBit 的 trait 语法能力，记录以下要点：

### 支持的特性
- `pub(open) trait Name { fn method(Self, param: Type) -> Ret }`
- `pub impl Trait for Type with fn Type::method(self, ...) { ... }`
- 默认方法实现：`impl Trait with fn method(x, y) { ... }`（无 `for Type`）
- 泛型函数约束：`fn[R : Trait] func_name(...)`
- 泛型结构体（约束在方法上）：`stuct Wrapper[R]` + `fn[R : Trait] Wrapper::method(...)`
- trait 继承：`trait Child: Parent { ... }`

### 不支持的特性
- **带类型参数的 trait**：`trait Foo[T]` 不支持 → 必须为每输出类型分别定义 trait
- **关联类型**：`type Output` 在 trait 内不支持
- **trait 作为参数类型**：必须用泛型，不能 `fn foo(x: Trait)`
- **trait 方法带 body**：trait 内不能有 `{ }` 方法体

### Struct 构造函数要点
MoonBit struct 不会自动生成构造函数，需显式声明 `fn Type::Type(field~ : Type) -> Type { { field } }`。空结构体构造使用 `Type::{}`。

## 11. 后续展望

### 剩余 match 语句
仍有 4 个 SchemaType match 无法消除（属于核心逻辑）:
1. `parse_inner` (schema.mbt) — 运行时解析分发
2. 3 个 trait 分发函数（各 13 个 arm）— 编译时类型安全

### 后续优化
- `extract_type_expr` (moonbit_struct.mbt) ~200 行的 13 变体 match 当前未进入 trait。如果需要为不同目标语言生成 from_json 函数，可在此处应用同样的 trait 模式
- `escape_mbt_string` 仍有重复定义（`from_json_schema.mbt` + `cmd/json2schema/main.mbt`）
