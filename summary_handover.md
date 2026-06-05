# moon_zod — 项目交接文档

## 1. 项目概述

**moon_zod** 是一个 MoonBit 运行时 JSON Schema 校验库，受 Zod (TypeScript) 和 Pydantic (Python) 启发。核心场景是 LLM Tool Calling 的输出结构化校验与精确错误回溯。

- **语言**: MoonBit
- **模块名**: `username/moon_zod`
- **版本**: 0.1.0
- **依赖**: 仅 `moonbitlang/core/json`
- **测试**: 74 个黑盒测试，全部通过
- **提交历史**: `2c333ad` (HEAD, Phase 5), `99cd546` (Phase 4), `fdc9741` (Phase 3), `bf6b00a` (Phase 2), `6466b60` (init)

---

## 2. 文件结构与职责

```
moon_zod/
├── moon.mod                  # 包元信息（模块名/版本/描述）
├── moon.pkg                  # 包声明（导入 @json）
├── AGENTS.md                 # Agent 工作指南
├── DESIGN.md                 # 架构设计文档（原始规划）
├── README.mbt.md             # 用户 README
├── summary_handover.md       # 本文件
├── step_phase4_*.md          # Phase 4 阶段总结
├── step_phase5_*.md          # Phase 5 阶段总结
│
├── types.mbt                 # ValidationError / SchemaResult 类型
├── schema.mbt                # 核心枢纽：SchemaType / Schema / ObjectMode / Rule / parse 入口
├── string.mbt                # string() 工厂 + 所有规则方法
├── number.mbt                # number() 工厂 + 所有规则方法
├── boolean.mbt               # boolean() 工厂
├── null.mbt                  # null() 工厂
├── array.mbt                 # array() 工厂 + parse_array helper
├── object.mbt                # object() 工厂 + strict/passthrough/strip 方法 + parse_object helper
├── union.mbt                 # optional / default / enum_values / union 工厂 + parse helpers
├── refine.mbt                # refine() 自定义规则
├── json_schema.mbt           # to_json_schema() 导出标准 JSON Schema
├── moon_zod.mbt              # 包级文档（doc comment）
│
├── moon_zod_test.mbt         # 黑盒测试（74 tests）
├── moon_zod_wbtest.mbt       # 白盒测试（空，可扩展）
├── cmd/main/
│   ├── moon.pkg              # 可执行包声明
│   └── main.mbt              # 性能 Benchmark（10k 迭代）
└── pkg.generated.mbti        # 自动生成的接口描述，**勿手动编辑**
```

---

## 3. 公共 API 完整参考

### 工厂函数

| 函数 | 说明 |
|---|---|
| `string() -> Schema` | 校验 JSON 字符串 |
| `number() -> Schema` | 校验 JSON 数字 |
| `boolean() -> Schema` | 校验 JSON 布尔值 |
| `null() -> Schema` | 校验 JSON null |
| `array(Schema) -> Schema` | 校验 JSON 数组，元素按给定 schema 递归校验 |
| `object(Map[String, Schema]) -> Schema` | 校验 JSON 对象。**默认 Strip 模式**（静默移除未定义字段）|
| `enum_values(Array[String]) -> Schema` | 固定枚举值 |
| `union(Array[Schema]) -> Schema` | 联合类型：任一通过即成功 |

### Schema 方法

| 方法 | 适用类型 | 说明 |
|---|---|---|
| `.parse(Json, path?: String) -> SchemaResult` | 所有 | 执行校验，返回 `Ok(Json)` 或 `Err(Array[ValidationError])` |
| `.min(n)` | string / number / array | 最小长度/最小值 |
| `.max(n)` | string / number / array | 最大长度/最大值 |
| `.nonempty()` | string | 字符串非空 |
| `.email()` | string | 类似 email 格式（含 @ 和 .）|
| `.url()` | string | 以 `http://` 或 `https://` 开头 |
| `.regex(pattern)` | string | 包含子串 pattern |
| `.int()` | number | 整数值（无小数部分）|
| `.positive()` | number | > 0 |
| `.negative()` | number | < 0 |
| `.multipleOf(n)` | number | n 的整数倍 |
| `.optional()` | 任意 | null 或缺失时跳过校验。**规则链穿透**：`.optional().min(3)` 正确工作 |
| `.default(value)` | 任意 | null 时替换为默认值。**规则链穿透** |
| `.strict()` | object | 拒绝未定义字段 |
| `.passthrough()` | object | 允许未定义字段原样保留 |
| `.strip()` | object | 静默移除未定义字段（默认行为）|
| `.refine(check, msg)` | 任意 | 自定义校验谓词 |

### 独立函数

| 函数 | 说明 |
|---|---|
| `to_json_schema(Schema) -> Json` | 导出为标准 JSON Schema 对象 |
| `append_rule(Schema, (Json)->Bool, String) -> Schema` | 内部辅助：穿透 Optional/Default 装饰器追加规则 |
| `inner_type(SchemaType) -> SchemaType` | 内部辅助：剥离 Optional/Default 获取基础类型 |
| `format_path(Array[String]) -> String` | 内部辅助：将路径栈拼接为点号路径字符串 |
| `is_optional_schema(Schema) -> Bool` | 内部辅助：判断是否为 Optional/Default 包装 |
| `parse_inner(Schema, Json, Array[String]) -> SchemaResult` | 内部辅助：共享路径栈的递归校验入口 |
| `sub_path(String, String) -> String` | 遗留辅助：字符串拼接路径（保留向后兼容）|
| `sub_index(String, Int) -> String` | 遗留辅助：字符串拼接数组索引路径 |
| `value_in_array(String, Array[String]) -> Bool` | 内部辅助：枚举值查找 |

### 核心类型

```mbt
pub(all) enum ObjectMode { Passthrough; Strict; Strip }
pub(all) enum SchemaType { StringType; NumberType; BooleanType; NullType;
    ObjectType(Map[String, Schema], ObjectMode); ArrayType(Schema);
    OptionalType(Schema); DefaultType(Schema, Json);
    EnumType(Array[String]); UnionType(Array[Schema]) }
pub(all) struct Rule { check: (Json) -> Bool; message: String }
pub struct Schema { schema_type: SchemaType; rules: Array[Rule] }
pub struct ValidationError { path: String; message: String; got: Json }
pub type SchemaResult = Result[Json, Array[ValidationError]]
```

---

## 4. 架构设计关键决策

### 4.1 parse 路由 + 路径栈 (Phase 4-5)

**数据流**：
```
Schema::parse(json, path?)          ← 公共入口，创建 path_stack
  └─ parse_inner(schema, json, stack)  ← 内部转发枢纽
       ├─ parse_object()                ← push/pop 字段名
       ├─ parse_array()                 ← push/pop [索引]
       ├─ parse_optional()              ← 直接传递 stack
       ├─ parse_default()               ← 直接传递 stack
       ├─ parse_enum()                  ← format_path 后在当前层级报错
       ├─ parse_union()                 ← 直接传递 stack
       └─ 基本类型检查                   ← format_path 后在当前层级报错
```

**路径栈设计** (Phase 5)：
- 所有内部 parse helper 接受 `path_stack: Array[String]` 而非 `path: String`
- 进入子结构前 `push()`，返回后 `let _ = pop()`
- 仅在真正产生 `ValidationError` 时才调用 `format_path(stack)` 拼接字符串
- **收益**: 成功路径零字符串分配

### 4.2 append_rule — 装饰器穿透 (Phase 4)

核心技巧：
```mbt
pub fn append_rule(schema, check, message) -> Schema {
  match schema.schema_type {
    OptionalType(inner)  => 递归到 inner，新建 OptionalType 包裹
    DefaultType(inner,_) => 递归到 inner，新建 DefaultType 包裹
    _ => 直接追加到 rules
  }
}
```
使得 `string().optional().min(3)` 的 `min(3)` 规则正确落在内部的 StringType 上，而非被 OptionalType 隔离。

### 4.3 inner_type — 类型擦除 (Phase 4)

```mbt
pub fn inner_type(t: SchemaType) -> SchemaType {
  match t {
    OptionalType(inner) | DefaultType(inner, _) => inner.schema_type
    other => other
  }
}
```
用在规则方法的类型守卫中（如 `min()` 检查是 StringType/NumberType/ArrayType），确保装饰器不干扰类型判断。

### 4.4 Strip 默认模式 (Phase 5)

`object()` 默认创建 `Strip` 模式，而非 `Passthrough`：
- 校验成功时，`parse_object` 收集 `parsed_fields: Map[String, Json]`（已递归校验/剥离的值）
- 返回 `Json::object(parsed_fields)`，只包含 spec 定义的字段
- 嵌套对象也能正确递归剥离，因为存储的是递归 parse 后的值

### 4.5 Union 错误聚合 (Phase 5)

所有分支失败时，收集每个分支的第一个错误 message，拼接为：
```
"Expected union type, but all branches failed. Branches: [Expected string, Expected number]"
```
而非只返回最后一个分支的错误。

### 4.6 JSON Schema 导出 (Phase 4)

`to_json_schema()` 递归遍历 `SchemaType`，生成标准 JSON Schema：
- OptionalType/DefaultType → 透明穿透（不产生 `oneOf`）
- Strip/Passthrough → 映射为 `"additionalProperties": true`
- Strict → 映射为 `"additionalProperties": false`

---

## 5. 各阶段提交摘要

| Phase | Commit | 内容 |
|---|---|---|
| init | `6466b60` | 项目初始化 |
| 1 | (合并到 init) | 核心类型 + 基础校验器 |
| 2 | `bf6b00a` | object schema + strict/passthrough 模式 |
| 3 | `fdc9741` | array, optional, default, enum, union, refine |
| 4 | `99cd546` | append_rule/inner_type 穿透、parse 分派重构、to_json_schema、benchmark |
| 5 | `2c333ad` | 可变路径栈、Strip 模式、union 错误聚合 |

---

## 6. 测试概况

- **74 个黑盒测试**，全部在 `moon_zod_test.mbt` 中
- 无外部依赖测试框架，使用 MoonBit 内建 `test` 块
- `parse_json()` 辅助函数用于从字符串构造 JSON（避免 `@json.parse` 的异常处理）
- 测试覆盖：
  - 每种 Schema 类型的正常/异常路径
  - 所有规则方法的通过/拒绝
  - 嵌套对象/数组的路径正确性
  - 装饰器穿透（`.optional().min()` 等）
  - Strip 模式行为
  - 错误消息内容
  - to_json_schema 输出

**运行测试**: `moon test`（需在项目目录下）

---

## 7. 编码规范

1. **Block 风格**: 每个公共项前用 `///|` 分隔；block 间顺序无关
2. **Result 模式**: 所有校验返回 `Result[Json, Array[ValidationError]]`，**绝不 raise**
3. **pub 语义**: `pub` = 包内可见，`pub(all)` = 外部包可见。内部辅助函数用 `pub`（需要跨文件访问）
4. **提交前**: 必须运行 `moon test && moon info && moon fmt`
5. **文件组织**: 每个工厂函数一个 `.mbt` 文件，对应规则方法写在同文件

---

## 8. 已知问题 / 未来方向

### 已知
- `union.mbt` 中的 parse helper 的 `self` 参数未使用（合法但有 warning），因为实际委托给 `parse_inner`
- 无白盒测试（`moon_zod_wbtest.mbt` 空）
- 无 CI/CD 配置

### 建议下一步
1. **Benchmark 精确计时**: 当前 cmd/main 只计数不测时，可用 `@bench` 包做 real benchmark
2. **refine 类型安全**: 允许用户定义 `refine<T>(fn(T) -> Bool)` 而不是 `fn(Json) -> Bool`
3. **Schema 组合器**: `Schema::or()`, `Schema::and()`, `Schema::transform()` 等
4. **错误本地化**: Error message 支持多语言模板
5. **derive 宏**: `derive(ZodSchema)` 从 MoonBit struct 自动生成 schema
6. **CI**: 配置 GitHub Actions 自动 `moon test`

---

## 9. 快速命令

```bash
moon test                # 运行全部测试
moon build               # 编译库
moon run cmd/main        # 运行 benchmark
moon info && moon fmt    # 更新接口 + 格式化
moon coverage analyze    # 查看测试覆盖率
```

---

*生成时间: 2026-06-05 | 由 opencode 在 Phase 5 完成后生成*
