# moon_zod 开发阶段总结

> 本项目为 MoonBit 语言实现的 JSON Schema 运行时校验库，灵感来自 Zod/Pydantic。
> 以下按阶段总结每个 Phase 的核心交付物、关键设计决策及文件变更。

---

## 项目当前状态

| 指标 | 数值 |
|------|------|
| 测试数量 | **539** |
| 外部依赖 | `moonbitlang/regexp` |
| 编译器警告 | 0 |
| 子包数量 | 5（`core`, `exporters`, `importers`, `combinators`, `tests`）|
| CLI 工具 | 4 个（`cmd/main`, `cmd/gen-struct`, `cmd/json2schema`, `cmd/validate`）|

---

## Phase 43 — Recursive Schema + Discriminated Union

**目标**: 补齐核心校验库剩余两个复合类型：递归 Schema（自引用树结构）和判别式联合（O(1) 分支分发）。

### 新增文件

| 文件 | 内容 |
|------|------|
| `core/lazy.mbt` | `LazyType(() -> Schema)` 变体；`recursive(f)` 工厂；`Schema::parse_lazy` |
| `core/discriminated_union.mbt` | `DiscriminatedUnionType(String, Map)` 变体；`discriminated_union(disc, options)` 工厂；`Schema::parse_discriminated_union` |

### 修改文件

| 文件 | 变更 |
|------|------|
| `core/schema.mbt` | SchemaType 新增两个变体；`parse_inner` dispatch；`inner_type` 穿透 |
| `core/shared_utils.mbt` | `collect_named_schemas_impl`/`find_schema_dependencies_impl` 新增 LazyType 解析 + DiscriminatedUnionType 遍历 |
| `core/errors.mbt` | `type_origin` 新增两个变体 |
| `exporters/*.mbt` (4 文件) | 所有渲染 dispatch 新增 LazyType/DiscriminatedUnionType 分支 |
| `reexporter.mbt` / `tests/reexporter.mbt` | 导出 `recursive` / `discriminated_union` |

### 已知限制

| # | 限制 | 原因 |
|---|------|------|
| 1 | `recursive` 无 memoization，每次 parse 创建新 Schema O(depth) | MoonBit `lazy` 关键字已预留但未实现，无法做值级别惰性自引用 |
| 2 | `discriminated_union` 导出时丢失判别信息，退化为普通 union | 完整判别式导出需在 renderer trait 新增方法 + 实现，工程量独立 |

**产出**: 524/524 测试通过，0 错误，0 警告。

---

## Phase 44 — PipeType 显式二阶段校验

**目标**: 新增 `PipeType(input, bridge, output)` SchemaType 变体，支持显式二阶段校验管线。解决 `TransformType` 语义模糊（规则归属不清、错误定位不精确），对齐 Zod `.pipe()` 设计。

### 新增文件

| 文件 | 内容 |
|------|------|
| `core/pipe.mbt` | `Schema::pipe(output)` 工厂；`Schema::parse_pipe`（input → bridge → output） |

### 修改文件

| 文件 | 变更 |
|------|------|
| `core/schema.mbt` | `PipeType(Schema, TransformClosure, Schema)` 变体；`parse_inner` dispatch；`append_rule_with_annotation` 穿透到 output（规则链追加到二阶段）；`inner_type` 穿透；`message()` 穿透 |
| `core/shared_utils.mbt` | `unwrap_schema` / `collect_named_schemas_impl` / `find_schema_dependencies_impl` 穿透 |
| `core/errors.mbt` | `type_origin` 新增 `"pipe"` |
| `exporters/prompt_renderer.mbt` | 渲染为 `input → output` |
| `exporters/json_schema_renderer.mbt` | 透明落到 output |
| `exporters/moonbit_struct.mbt` | `collect_type_defs` / `collect_field_defs` / `field_to_moonbit_type` 穿透到 output |
| `exporters/schema_exporter.mbt` | `.pipe(output)` 代码生成 |
| `tests/test_pipe.mbt` | **新增** — 7 个测试 |

### 设计决策

- `PipeType` 不需要单独 bridge 参数，使用 `TransformClosure` 作为内部桥接（identity 桥接为默认）
- `append_rule` 穿透到 output：`.pipe(output).min(5)` → min(5) 作用于 output 阶段，错误定位精确
- 导出器：prompt 渲染两阶段类型链，json_schema/moonbit_struct 透明落到 output（消费层无需理解 pipe）

**产出**: 531/531 测试通过，0 错误，0 警告。

---

## Phase 45 — 枚举 `exclude()` / `extract()`

**目标**: 为 enum 类型新增 `exclude()` 和 `extract()` 方法，支持灵活的子集组合。

| 新增方法 | 说明 |
|---------|------|
| `enum.exclude(values)` | 返回排除指定值后的新 enum |
| `enum.extract(values)` | 返回仅保留指定值后的新 enum |

两者均保留原 schema 的 metadata（name、description、brand、invalid_type_error、rules）。过滤后为空数组时产生永不匹配的 enum。

**产出**: 539/539 测试通过，0 错误，0 警告。

---

## TODO（分析和计划表）

[Info](todo.md)



