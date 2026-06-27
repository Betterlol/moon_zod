# Phase C — Trait Renderer 重构

> **前置**: Phase A (Quick Fix) ✅ + Phase B (Constraint Extractor) ✅  
> **原型验证**: MoonBit trait + generic dispatch 模式 5/5 测试通过 ✅  
> **状态**: 设计完成，准备实施

---

## 目录

1. [问题诊断与现状](#1-问题诊断与现状)
2. [设计方案：Trait + Generic Dispatch](#2-设计方案trait--generic-dispatch)
3. [步骤 1：共享工具抽取](#3-步骤-1共享工具抽取)
4. [步骤 2：约束注释统一](#4-步骤-2约束注释统一)
5. [步骤 3：三个 Trait 定义](#5-步骤-3三个-trait-定义)
6. [步骤 4：prompt.mbt 迁移](#6-步骤-4promptmbt-迁移)
7. [步骤 5：json_schema.mbt 迁移](#7-步骤-5json_schemambt-迁移)
8. [步骤 6：moonbit_struct.mbt 迁移](#8-步骤-6moonbitstructmbt-迁移)
9. [测试策略](#9-测试策略)
10. [收益评估](#10-收益评估)

---

## 1. 问题诊断与现状

### 40 个 match 语句散布在 4 个文件

| 文件 | 行数 | SchemaType match 数量 | 全穷举 match |
|------|------|----------------------|-------------|
| `prompt.mbt` | 748 | 12 | 2 (`type_to_prompt`, `type_to_inline_prompt`) |
| `json_schema.mbt` | 319 | 3 | 3 (`to_json_schema_full`, `to_json_schema_inner`, `to_json_schema_named_full`) |
| `moonbit_struct.mbt` | 1032 | 19 | 3 (`type_to_moonbit`, `type_to_inline_moonbit`, `extract_type_expr`) |
| `schema.mbt` | ~330 | 6 | 0 |
| **总计** | **~2429** | **40** | **8** |

### 新增 SchemaType 变体时需修改 ~15+ 处

当前做法：新增 `BigIntType` → 在 8 个全穷举 match + 若干部分 match + `schema.mbt` 的 `parse_inner`/`expected_msg` 中增加分支。

### 共享工具散落在 `prompt.mbt`

`prompt.mbt` 当前承载了 10+ 个被 `json_schema.mbt` 和 `moonbit_struct.mbt` 调用的工具函数：

- `collect_named_schemas` / `topological_sort_schemas` / `unwrap_schema`
- `indent_str` / `format_double_simple` / `join_parts`
- `escape_mbt_string` 重复定义在 `from_json_schema.mbt` 和 `cmd/json2schema/main.mbt`

### `expected_msg` 缺少 UnionType/OptionalType/DefaultType 处理

`schema.mbt:217` 的 `expected_msg` match 未显式处理 `UnionType`/`OptionalType`/`DefaultType`，导致这些类型返回通用消息 `"Validation failed"`。这是一个潜在 bug，需在本次重构中修复。

---

## 2. 设计方案：Trait + Generic Dispatch

### 原型验证结果 ✅

MoonBit 语法实践确认（基于 MoonBit 0.1.20260608）：

| 特性 | 状态 | 语法 |
|------|------|------|
| 定义 trait | ✅ | `pub(open) trait Renderer { fn method(Self, param: Type) -> Ret }` |
| 实现 trait | ✅ | `pub impl Renderer for Type with fn Type::method(self, ...) { ... }` |
| 默认方法实现 | ✅ | `impl Renderer with fn method(x, y) { ... }`（无 `for Type`） |
| 范型函数约束 | ✅ | `fn[R : Renderer] name(renderer: R, ...)` |
| 范型结构体（方法上加约束） | ✅ | `struct Wrapper[R]` + `fn[R : Renderer] Wrapper::method(...)` |
| **带类型参数的 trait** | ❌ | `trait Foo[T]` 不支持 — 必须为每个输出类型分别定义 trait |
| **关联类型** | ❌ | `type Output` 在 trait 内不支持 |
| **trait 作为参数类型** | ❌ | 必须用范型，不能 `fn foo(x: Trait)` |
| **trait 方法带默认 body** | ❌ | trait 内不能有 `{ }` 方法体 |

### 核心架构

```moonbit
// ── 每个输出类型一个 trait ──
pub(open) trait StringRenderer {
  fn render_string(Self, schema: Schema) -> String
  fn render_number(Self, schema: Schema) -> String
  fn render_boolean(Self, schema: Schema) -> String
  fn render_null(Self, schema: Schema) -> String
  fn render_object(Self, spec: Map[String, Schema], mode: ObjectMode, schema: Schema) -> String
  fn render_array(Self, elem: Schema, schema: Schema) -> String
  fn render_optional(Self, inner: Schema, schema: Schema) -> String
  fn render_default(Self, inner: Schema, default_val: Json, schema: Schema) -> String
  fn render_enum(Self, values: Array[String], schema: Schema) -> String
  fn render_union(Self, schemas: Array[Schema], schema: Schema) -> String
  fn render_intersection(Self, schemas: Array[Schema], schema: Schema) -> String
  fn render_transform(Self, inner: Schema, closure: TransformClosure, schema: Schema) -> String
  fn render_literal(Self, value: Json, schema: Schema) -> String
}

// ── 唯一的 match 分发函数（脱离 trait，用范型约束）──
fn[R : StringRenderer] render_type(renderer: R, schema: Schema) -> String {
  match schema.schema_type {
    StringType => renderer.render_string(schema)
    NumberType => renderer.render_number(schema)
    BooleanType => renderer.render_boolean(schema)
    NullType => renderer.render_null(schema)
    ObjectType(spec, mode) => renderer.render_object(spec, mode, schema)
    ArrayType(elem) => renderer.render_array(elem, schema)
    OptionalType(inner) => renderer.render_optional(inner, schema)
    DefaultType(inner, default_val) => renderer.render_default(inner, default_val, schema)
    EnumType(values) => renderer.render_enum(values, schema)
    UnionType(schemas) => renderer.render_union(schemas, schema)
    IntersectionType(schemas) => renderer.render_intersection(schemas, schema)
    TransformType(inner, closure) => renderer.render_transform(inner, closure, schema)
    LiteralType(value) => renderer.render_literal(value, schema)
  }
}
```

### 为什么不是经典 Visitor Pattern？

MoonBit 不支持：trait 对象、trait 内默认方法体、关联类型。因此采用 **「Separate Trait per Target + Shared Dispatch Function」** 模式。

### 三个 Trait

| Trait | 输出类型 | 适用目标 | 对应旧 match 数量 |
|-------|---------|---------|-----------------|
| `StringRenderer` | `String` | prompt 渲染 | 2 (type_to_prompt, type_to_inline_prompt) |
| `JsonSchemaRenderer` | `Json` | JSON Schema 导出 | 3 (full, inner, named_full) |
| `MoonBitStructRenderer` | `String` | MoonBit struct 生成 | 3 (type_to_moonbit, type_to_inline_moonbit, extract_type_expr) |

每个 trait 有 13 个方法（对应 13 个 SchemaType 变体）。

---

## 3. 步骤 1：共享工具抽取

### 3.1 新建 `shared_utils.mbt`

从 `prompt.mbt` 中抽取以下函数（它们被 2-3 个模块共同使用）：

```
collect_named_schemas(schema) -> Array[Schema]
collect_named_schemas_impl(schema, visited, result) -> Unit
topological_sort_schemas(named_schemas) -> Array[Schema]
find_schema_dependencies(schema, schema_map) -> Array[Schema]
find_schema_dependencies_impl(schema, schema_map, deps, visited_names) -> Unit
dfs_topo_sort(name, deps_list, visited, sorted, schema_map) -> Unit
visited_contains(visited_list, name) -> Bool
visited_get_status(visited_list, name) -> Int
visited_set_status(visited_list, name, status) -> Unit
unwrap_schema(schema) -> Schema
indent_str(n) -> String
format_double_simple(v) -> Double -> String
join_parts(parts) -> String
```

### 3.2 修复 `escape_mbt_string` 重复

`from_json_schema.mbt` 和 `cmd/json2schema/main.mbt` 各有一份 `escape_mbt_string`。抽取到 `shared_utils.mbt`。

### 3.3 新增 `peel_optional` 辅助

当前 "peel optional" 模式在 6 处重复（`object_to_prompt`, `object_to_inline_prompt`, `object_to_struct_definition`, `object_to_inline_moonbit`, `struct_definition_with_names`, `extract_field`）：

```moonbit
fn peel_optional(schema: Schema) -> Schema {
  match schema.schema_type {
    OptionalType(s) | DefaultType(s, _) => s
    _ => schema
  }
}
```

### 3.4 迁移路线图

```
┌───────────────────────────────────┐
│  Before: prompt.mbt = junk drawer │
│  hosting named/topo/format utils  │
└───────────────────────────────────┘
              ↓
┌───────────────────────────────────┐
│  After: shared_utils.mbt          │
│  (all named schema + fmt utils)   │
│  prompt.mbt (only prompt logic)   │
│  constraint_extractor.mbt         │
│  (also hosts struct_comment)      │
└───────────────────────────────────┘
```

---

## 4. 步骤 2：约束注释统一

### 目标

`struct_comment` (moonbit_struct.mbt:427) 与 `schema_comment` (prompt.mbt:185) 几乎相同。合并为一个函数放在 `constraint_extractor.mbt`。

### 改动

- `moonbit_struct.mbt` 删除 `struct_comment`
- `constraint_extractor.mbt` 新增 `schema_comment(schema) -> String`（或统一入口）
- 所有调用点指向 `constraint_extractor.mbt` 的版本

---

## 5. 步骤 3：三个 Trait 定义

### 5.1 `string_renderer.mbt` — `StringRenderer` trait

```moonbit
///|
/// Trait for rendering Schema as a String (prompt, struct output).
pub(open) trait StringRenderer {
  fn render_string(Self, schema: Schema) -> String
  fn render_number(Self, schema: Schema) -> String
  fn render_boolean(Self, schema: Schema) -> String
  fn render_null(Self, schema: Schema) -> String
  fn render_object(Self, spec: Map[String, Schema], mode: ObjectMode, schema: Schema) -> String
  fn render_array(Self, elem: Schema, schema: Schema) -> String
  fn render_optional(Self, inner: Schema, schema: Schema) -> String
  fn render_default(Self, inner: Schema, default_val: Json, schema: Schema) -> String
  fn render_enum(Self, values: Array[String], schema: Schema) -> String
  fn render_union(Self, schemas: Array[Schema], schema: Schema) -> String
  fn render_intersection(Self, schemas: Array[Schema], schema: Schema) -> String
  fn render_transform(Self, inner: Schema, closure: TransformClosure, schema: Schema) -> String
  fn render_literal(Self, value: Json, schema: Schema) -> String
}

///|
/// Single dispatch function — the ONLY match on SchemaType for String targets.
fn[R : StringRenderer] render_string_type(renderer: R, schema: Schema) -> String {
  match schema.schema_type {
    StringType => renderer.render_string(schema)
    NumberType => renderer.render_number(schema)
    BooleanType => renderer.render_boolean(schema)
    NullType => renderer.render_null(schema)
    ObjectType(spec, mode) => renderer.render_object(spec, mode, schema)
    ArrayType(elem) => renderer.render_array(elem, schema)
    OptionalType(inner) => renderer.render_optional(inner, schema)
    DefaultType(inner, default_val) => renderer.render_default(inner, default_val, schema)
    EnumType(values) => renderer.render_enum(values, schema)
    UnionType(schemas) => renderer.render_union(schemas, schema)
    IntersectionType(schemas) => renderer.render_intersection(schemas, schema)
    TransformType(inner, _closure) => renderer.render_transform(inner, _closure, schema)
    LiteralType(value) => renderer.render_literal(value, schema)
  }
}
```

### 5.2 `json_schema_renderer.mbt` — `JsonSchemaRenderer` trait

同上，但每个方法返回 `Json`，分发函数为 `render_json_type`。

### 5.3 `moonbit_renderer.mbt` — `MoonBitStructRenderer` trait

同上，返回 `String`，但增加 `extract_type_expr` 方法专用于 `from_json` 生成。

---

## 6. 步骤 4：prompt.mbt 迁移

### 6.1 需要创建的结构体

| Struct | 字段 | 用途 |
|--------|------|------|
| `BasicPromptRenderer` | — | 基础 prompt 渲染 |
| `NamedPromptRenderer` | `named_schemas: Array[Schema]` | 命名 prompt 渲染 |

### 6.2 方法映射

旧函数 → Trait 方法：

| 旧函数 | Trait 方法 |
|--------|-----------|
| `type_to_prompt(schema, indent)` | `render_string_type(renderer, schema)`（indent 由方法自行管理） |
| `enum_to_prompt(values)` | `render_enum(values, schema)` |
| `union_to_prompt(schemas, indent)` | `render_union(schemas, schema)` |
| `intersection_to_prompt(schemas, indent)` | `render_intersection(schemas, schema)` |
| `object_to_prompt(spec, indent)` | `render_object(spec, mode, schema)` |
| `json_to_ts_literal(json)` | `render_literal(value, schema)` |
| `schema_comment(schema)` | 留在 `constraint_extractor.mbt` |

### 6.3 Named variant

NamedPromptRenderer 额外能力：
1. 存储 `named_schemas` 列表
2. `render_object` 中检查 `has_name_in(schema, self.named_schemas)`，如已命名则返回名字而非内联
3. `generate_interface_definitions()` 方法（不是 trait 方法，是 struct 自有方法）生成所有 `export interface` / `export type` 定义

---

## 7. 步骤 5：json_schema.mbt 迁移

### 7.1 需要创建的结构体

| Struct | 字段 | 用途 |
|--------|------|------|
| `FullJsonRenderer` | — | 完整 JSON Schema（带约束注解） |
| `SkeletonJsonRenderer` | — | 骨架 JSON Schema（仅结构） |
| `NamedJsonRenderer` | `named_names: Array[String]` | 命名 JSON Schema（含 `$defs`/`$ref`） |

### 7.2 方法映射

旧函数 → Trait 方法：

| 旧函数 | Trait 方法 | 注意 |
|--------|-----------|------|
| `to_json_schema_full` | `render_json_type(renderer, schema)` | 分发函数 |
| `to_json_schema_inner` | `render_inner_type(renderer, schema_type)` | 直接操作 SchemaType |
| `to_json_schema_named_full` | NamedJsonRenderer 的方法 | 额外处理 named_names |
| `merge_annotations` | 移到 trait impl 方法内部 | 特定于 FullJsonRenderer |

### 7.3 特殊处理：`Json` 返回类型

`JsonSchemaRenderer` 的方法返回 `Json`，不能直接用字符串拼接。每个方法需要构造 `Json` 对象。

---

## 8. 步骤 6：moonbit_struct.mbt 迁移

### 8.1 需要创建的结构体

| Struct | 字段 | 用途 |
|--------|------|------|
| `InlineStructRenderer` | — | 基础 MoonBit struct 类型渲染 |
| `NamedStructRenderer` | `named_schemas: Array[Schema]` | 命名引用渲染 |
| `FullStructRenderer` | `named_schemas: Array[Schema]` | struct + from_json 函数生成 |

### 8.2 方法映射

三个全穷举 match 被 Trait 方法取代：
- `type_to_moonbit` → `render_string_type`
- `type_to_inline_moonbit` → NamedStructRenderer 的命名感知版
- `extract_type_expr` → 作为 `MoonBitStructRenderer` trait 下的一个方法（或独立辅助）

其余部分 match 的消除：
- named-dispatch match → NamedStructRenderer 的 `generate_struct_definitions`
- intersection-merge match → Intersection 渲染逻辑集中在 trait impl 中
- peel-optional match → 统一用 `peel_optional` 辅助函数（shared_utils.mbt）
- `struct_comment` → 移到 `constraint_extractor.mbt`
- `is_null_type` → 保留，或合入 `is_optional_schema`

### 8.3 `extract_type_expr` 的特殊性

`extract_type_expr` 生成 TypeScript 风格的 match 表达式，是 `from_json()` 函数的核心。它不是渲染类型名，而是生成提取代码。可以作为 `FullStructRenderer` 的独立方法，不进入 trait 方法列表。

---

## 9. 测试策略

### 9.1 迭代验证（每步之后）

```bash
moon fmt && moon info    # 检查 .mbti 变化
moon check               # 确保零错误零警告
moon test                # 全部通过
```

### 9.2 分步验证

| 步骤 | 验证 | 预期测试结果 |
|------|------|-------------|
| 1. 共享工具抽取 | `moon test` | 385/385 |
| 2. 约束注释统一 | `moon test` | 385/385 |
| 3. Trait 定义 | `moon check` | 0 errors |
| 4. prompt.mbt 迁移 | `moon test test_prompt*` | 所有 prompt 测试通过 |
| 5. json_schema.mbt 迁移 | `moon test test_json_schema*` | 所有 JSON Schema 测试通过 |
| 6. moonbit_struct.mbt 迁移 | `moon test test_moonbit_struct*` | 所有 struct 测试通过 |

### 9.3 行为等价验证

每个 trait impl 的输出必须与旧函数完全一致。通过现有测试保证。如果输出格式有微小变化，使用 `moon test --update` 更新快照。

---

## 10. 收益评估

### 代码质量

| 指标 | 重构前 | 重构后 | 改进 |
|------|--------|--------|------|
| SchemaType match 总数 | 40 | 4（3 个 trait 分发 + 1 个 parse_inner） | -90% |
| 全穷举 match 数 | 8 | 3 | -62% |
| 新增 SchemaType 修改点 | ~15 处 | ~7 处 | -53% |
| 核心代码行数 | ~2099 | ~1620 | -23% |
| 共享工具位置 | prompt.mbt (错误宿主) | shared_utils.mbt (正确宿主) | ✅ |

### 可维护性

| 场景 | 旧做法 | 新做法 |
|------|--------|--------|
| 新增 SchemaType 变体 | 修改 15+ 处 | 1. 在 3 个 trait 加方法 + 3 个 impl 加方法 |
| | | 2. 在 3 个分发函数加 1 个 match arm |
| | | 3. 在 `schema.mbt` 加处理 |
| 新增导出格式 | 新建 match 语句（复制重复模式） | 新建 struct + impl trait |
| `expected_msg` bug | 未处理 UnionType/OptionalType/DefaultType | 同期修复 |

### 风险

| 风险 | 影响 | 缓解 |
|------|------|------|
| MoonBit trait 性能 vs 硬编码 match | 可能微差 | 原型已验证编译通过；必要时基准测试对比 |
| `extract_type_expr` 不进入 trait | 新 SchemaType 仍需额外修改 | 可接受—`from_json` 生成是独有功能 |
| 多步骤迁移中测试可能短暂失败 | 需要中间状态的一致性 | 每步后运行 `moon test` 确保一致性 |

### 时间估算

| 步骤 | 内容 | 预计时间 |
|------|------|---------|
| 1 | 共享工具抽取 | 2h |
| 2 | 约束注释统一 | 0.5h |
| 3 | 三个 Trait 定义 | 1h |
| 4 | prompt.mbt 迁移 | 2h |
| 5 | json_schema.mbt 迁移 | 2h |
| 6 | moonbit_struct.mbt 迁移 | 3h |
| 7 | 测试 + 清理 | 1.5h |
| **总计** | | **~12h** |

---

## 附录 A：关键语法参考（已验证）

```moonbit
// Trait 定义
pub(open) trait MyTrait {
  fn method_name(Self, param: Type) -> ReturnType
}

// Trait 实现
pub impl MyTrait for MyType with fn MyType::method_name(
  self: MyType,
  param: Type
) -> ReturnType {
  // body
}

// 泛型函数约束
fn[R : MyTrait] my_func(renderer: R, data: Data) -> String { ... }

// 泛型结构体
pub struct Wrapper[T] { field: T }
// 约束写方法上，不写结构体上
fn[R : MyTrait] Wrapper::method(self: Wrapper[R], ...) -> String { ... }

// 结构体构造函数
pub fn Wrapper::Wrapper[T](field~ : T) -> Wrapper[T] { { field } }

// 空结构体
pub struct Empty {}
pub fn Empty::Empty() -> Empty { Empty::{} }

// 默认方法实现
impl MyTrait with fn default_method(x, y) -> Ret { ... }
```

---

*设计文档版本: v1.0*
*基于 MoonBit 0.1.20260608 (moonc v0.10.0) 语法验证*
