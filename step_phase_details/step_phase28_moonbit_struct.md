# Phase 28 — Schema → MoonBit struct 代码生成 (`schema_to_moonbit_struct`)

**目标**: 填补 `parse()` 返回 `Result[Json, ...]` 后用户需手工 pattern match 的 ergonomic gap。实现 Schema → MoonBit struct 定义的双向桥接：`schema_to_moonbit_struct()`（单个）和 `schema_to_moonbit_struct_named()`（命名导出）。

## 设计决策

### 输出策略

只生成类型定义（struct / enum），不生成 `from_json()` 转换函数。`from_json()` 留作 Phase 29。

- **ObjectType(有 name)** → `pub struct Name { key : Type, ... }`
- **EnumType** → `pub enum Name { Variant, ... }`
- **非命名 ObjectType** → 字段级输出 `Json /* TODO: define nested struct */`，保证可编译
- **UnionType** → 简单（T | Null）展开为 `T?`；复杂输出 `/* TODO: union type */`
- **IntersectionType** → 全 Object 合并字段；非全 Object 输出 `/* TODO: intersection type */`

### SchemaType → MoonBit 类型映射

| SchemaType | 条件 | MoonBit 类型 |
|---|---|---|
| StringType | — | `String` |
| NumberType | 有 `int()` 规则 | `Int64` |
| NumberType | 无 `int()` 规则 | `Double` |
| BooleanType | — | `Bool` |
| NullType | — | `Unit` |
| OptionalType(inner) | — | `T?` |
| DefaultType(inner, _) | — | `T`（is_optional_schema 标记字段为 `?`） |
| ArrayType(elem) | — | `Array[T]` |
| EnumType(values) | — | `pub enum { Variant, ... }` |
| UnionType(schemas) | T + Null | `T?` |
| UnionType(schemas) | 复杂 | `/* TODO: union type */` |
| IntersectionType(schemas) | 全 Object | 合并字段 |
| IntersectionType(schemas) | 非全 Object | `/* TODO: intersection type */` |
| TransformType(inner, _) | — | 透明展开 inner |

### 命名导出架构

复用 Phase 25 的收集与拓扑排序管线：
1. `collect_named_schemas()` — DFS 遍历收集所有命名 Schema
2. `topological_sort_schemas()` — 三态 DFS 拓扑排序保证依赖顺序
3. `generate_struct_definitions()` — 遍历排序后的 schema，调用 `struct_definition_with_names()` 或 `enum_to_moonbit()`
4. `type_to_inline_moonbit()` — 检查 schema.name 是否在 named_schemas 列表中 → 返回名称引用而非内联

### 约束注释复用

`struct_comment()` 直接调用 `prompt.mbt` 的 `string_constraint_comment()` / `number_constraint_comment()` / `array_constraint_comment()` 等私有函数（同包可见），输出 `// min: 2, max: 50` 等行内注释。

### 非破坏性

- 不修改任何现有函数签名
- 不引入新依赖
- 与现有 `schema_to_prompt()` / `to_json_schema()` 独立，无 API 冲突

## CLi 设计

`cmd/gen-struct/` — JSON payload → 推断 Schema → 输出 MoonBit struct 定义：

```
moon run cmd/gen-struct -- '{"name":"Alice","age":30,"active":true}'
→ pub struct GeneratedStruct {
    name : String
    age : Int64  // int
    active : Bool
  }
```

- `/--help` 显示用法
- 嵌套对象自动 PascalCase 命名 → 被 `schema_to_moonbit_struct_named()` 收集为独立 struct
- `json_infer_schema()` 递归推断；整数检测使用 `v == v.to_int().to_double()`

## 文件变更

| 文件 | 操作 | 说明 |
|---|---|---|
| `moonbit_struct.mbt` | 新增 | `schema_to_moonbit_struct()` + `schema_to_moonbit_struct_named()` + 12 个内部辅助函数 |
| `test_moonbit_struct.mbt` | 新增 | 22 个测试 |
| `cmd/gen-struct/main.mbt` | 新增 | CLI 入口 + `json_infer_schema()` + `auto_struct_name()` |
| `cmd/gen-struct/moon.pkg` | 新增 | CLI 包声明（is-main, depend on `Betterlol/moon_zod`） |

## 测试覆盖

| 测试名 | 覆盖场景 |
|---|---|
| unnamed schema returns comment | 无 name 的 Schema → 注释提示 |
| non-object type returns comment | 非 ObjectType/EnumType → 注释提示 |
| object with string field | `String` 字段 |
| object with int64 field | `Int64`（int() 规则） |
| object with double field | `Double`（无 int() 规则） |
| object with boolean field | `Bool` |
| object with optional field | `field? : String` |
| object with default field | `field? : String`（is_optional_schema 识别） |
| object with array field | `Array[String]` |
| object with nullable field | `union([string(), null()])` → `String?` |
| empty object | `pub struct Empty {}` |
| enum | `pub enum Mood { Calm; Nervous; Angry }` |
| union type comment | 复杂 union → `/* TODO */` |
| nested named objects | 两个 struct 定义 + 引用 |
| named enum export | enum + 引用 struct |
| topological sort | Address → Person → Company 顺序 |
| deep nesting | Level3 → Level2 → Level1 |
| array of named | `Array[Item]` |
| constraint comment | `// 2-50 chars` |
| multiple fields | 5 种不同类型字段 |
| no named schemas | 空 named 集合 → 注释 |
| unnamed root with named fields | 根无 name 但 field schema 有 name |

**产出**: 344/344 测试全部通过 0 警告。

## 代码质量

- `moon build` 0 错误 0 警告
- `.mbti` 新增 `pub fn schema_to_moonbit_struct(Schema) -> String` 和 `pub fn schema_to_moonbit_struct_named(Schema) -> String`
- 无代码坏味道：复用 `prompt.mbt` 的约束注释函数和 `schema.mbt` 的 `is_optional_schema()`，避免重复
