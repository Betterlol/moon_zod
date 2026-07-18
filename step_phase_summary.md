# moon_zod 开发阶段总结

> 本项目为 MoonBit 语言实现的 JSON Schema 运行时校验库，灵感来自 Zod/Pydantic。
> 以下按阶段总结每个 Phase 的核心交付物、关键设计决策及文件变更。

---

## 项目当前状态

| 指标 | 数值 |
|------|------|
| 测试数量 | **524** |
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

## TODO（分析和计划表）

[Info](todo.md)



