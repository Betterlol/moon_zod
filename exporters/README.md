# exporters

Schema → String / Json / MoonBit source code 导出工具包。

本包提供多条独立导出管线（Prompt / JSON Schema / MoonBit struct / MoonZod Schema）。每条管线对 `@core.SchemaType` 的 17 个变体做逐一渲染，支持内联展开和命名引用两种模式。

---

## 公开 API

### Prompt 导出

- `schema_to_prompt(schema) -> String` — 将 Schema 渲染为 TypeScript-interface 风格的提示文本（全内联）
- `schema_to_prompt_named(schema, include_names?) -> String` — 提取带 `name` 的 Schema 生成模块化接口，带拓扑排序和类型引用

### JSON Schema 导出

- `to_json_schema(schema) -> Json` — 标准 JSON Schema（完整约束注释）
- `to_json_schema_skeleton(schema) -> Json` — 轻量级骨架（仅类型结构，无约束）
- `to_json_schema_named(schema, include_names?) -> Json` — 命名 Schema 导出为 `$defs` + `$ref`

### MoonBit 结构导出

- `schema_to_moonbit_struct(schema) -> String` — 生成 MoonBit `pub struct` / `pub enum` 定义
- `schema_to_moonbit_struct_full(schema) -> String` — 生成定义 + 静态 `Type::to_schema()` 方法

### 代码生成

- `schema_to_moon_zod_code(schema) -> String` — 将 Schema 反转为可 copy-paste 的 moon_zod 源码
- `schema_to_moon_zod_code_named(schema, include_names?) -> String` — 带命名 Schema 引用的源码生成
- `schema_to_moon_zod_code_inline_with_refs(schema, include_names) -> String` — 内联渲染，可选命名引用替换

---

## 文件结构

```
exporters/
├── prompt.mbt                  # schema_to_prompt / schema_to_prompt_named 公共 API
├── prompt_renderer.mbt         # StringRenderer trait + NamedPromptRenderer 实现
├── json_schema.mbt             # to_json_schema / to_json_schema_named / to_json_schema_skeleton 公共 API
├── json_schema_renderer.mbt    # JsonSchemaRenderer trait + NamedJsonRenderer 实现
├── moonbit_struct.mbt          # schema_to_moonbit_struct / _full 公共 API
├── schema_exporter.mbt         # schema_to_moon_zod_code / _named / _inline 公共 API
└── pkg.generated.mbti          # moon info 生成的接口描述（勿手动编辑）
```

---

## 实现说明

### 渲染器架构

导出管线统一采用 **trait 分发** 模式：

1. 每个 `SchemaType` 变体对应 trait 中的一个方法
2. 顶层的 `render_type` / `render_json_type` 做单点分发
3. 渲染器只负责「类型 → 文本/Json」的转换，约束注释、命名引用、描述文本由各模块独立处理

```
Schema ──► render_type(renderer, schema) ──► StringRenderer ──► String
         └── render_json_type(renderer, schema) ──► JsonSchemaRenderer ──► Json
```

#### Prompt 导出（`prompt.mbt` + `prompt_renderer.mbt`）

- `schema_to_prompt()` 内部复用 `NamedPromptRenderer([])`，named 集合为空 → 全内联展开
- `schema_to_prompt_named()` 收集所有带 `name` 的 Schema，拓扑排序后生成 `export interface / export type` 定义
- `include_names?` 参数支持选择性导出（`None` = 全部，`Some([])` = 无，`Some([...])` = 指定）
- named wrapper schemas（primitive、array、optional、default、transform、tuple、any、unknown、preprocess）统一生成 `export type X = T`
- named intersection 当包含非 object 分支时输出 `export type X = A & B`，否则合并 object 字段

#### JSON Schema 导出（`json_schema.mbt` + `json_schema_renderer.mbt`）

- `NamedJsonRenderer` 的 `include_annotations` 参数统一三种模式：
  - `include_annotations=true` → `to_json_schema()`（完整约束）
  - `include_annotations=false` → `to_json_schema_skeleton()`（仅结构）
- `optional()` / `default()` 导出 nullable 语义：`anyOf: [inner, {"type": "null"}]`
- `Strip` 模式导出 `additionalProperties: false`（与运行时幻觉防御对齐）
- object intersection 合并为单个 closed object；同名字段用属性级 `allOf` 保留各自约束
- `$defs` 渲染时排除自引用（`ref_names.filter(n => n != ns.name)`）

### 代码生成架构

本包包含两条**反向代码生成**管线，均不采用 trait 分发，而是直接 match `SchemaType` 生成目标语言源码。

#### MoonBit 结构导出（`moonbit_struct.mbt`）

- `schema_to_moonbit_struct()` 将 `ObjectType` 映射为 `pub struct`，`EnumType` 映射为 `pub enum`
- `schema_to_moonbit_struct_full()` 额外生成静态 `Type::to_schema() -> @moon_zod.Schema` 方法，实现 struct ↔ Schema 往返
- 基础类型映射：`String → String`，`Number → Int64 / Double`（按 `.int()` 规则区分），`Boolean → Bool`
- `ArrayType → Array[T]`，可空 `UnionType` 剥除 `null` 后映射
- `AnyType / UnknownType` 当前回退为 `Json`
- `TupleType` / 非可空 `UnionType` / `IntersectionType` 当前回退为 `Json // TODO`
- 字段名和类型名自动转义（MoonBit 关键字、保留字、首字母数字）
- 约束注释以行内注释形式附加在 struct field 上

#### MoonZod 代码导出（`schema_exporter.mbt`）

- `schema_to_moon_zod_code()` 将运行时 Schema 反转为可 copy-paste 的 moon_zod 方法链源码
- 输出格式：`let name = @moon_zod.string().min(3).describe("...").name("name")`
- 根 Schema 无 `name` 时自动赋予 `"Root"`
- `schema_to_moon_zod_code_named()` 提取所有命名 Schema，拓扑排序后输出 `let name = ...` 定义列表
- 规则注释通过 `Rule.annotation` 反推 `.min()` / `.max()` / `.email()` / `.url()` / `.int()` 等
- `json_to_literal()` 将 Json 值转为 MoonBit 构造函数调用（`Json::string(...)` / `Json::number(...)` / `true` / `false` / `null`）
- `PreprocessType` / `TransformType` 输出占位闭包 `fn(x) { Ok(x) }`，标记为最佳代码输出（自定义闭包无法序列化）
- `.required_error()` / `.invalid_type_error()` 链式方法仍会输出代码，但当前 `Schema` 工厂 API 未暴露这两个参数——round-trip 不安全

---

## 已知限制

- 当前 `moonbit_struct.mbt` 中 `TupleType` 仍回退为 `Json`，`any/unknown` 仅做最低限度映射。待后续整体重构时重新评估。
- MoonBit 结构导出尚不支持 `tuple` / `intersection` / `union` 等复杂类型的精确类型映射，当前回退为 `Json // TODO`。
- MoonZod 代码导出对 `TransformType` / `PreprocessType` 输出占位闭包 `fn(x) { Ok(x) }`，自定义闭包无法序列化；`.required_error()` / `.invalid_type_error()` round-trip 不安全（工厂 API 未暴露这两个参数）。