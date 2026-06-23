# Phase 29 — Schema → MoonBit struct `from_json()` 代码生成

**目标**: 补全 Phase 28 的类型定义能力，生成 `from_json()` 函数将验证后的 `Json` 值直接转换为类型安全的 MoonBit struct 值，无需用户手工 pattern match。

## 设计决策

### 核心策略：Direct Extraction 模式

不同于最初方案（生成 Schema 表达式 + 调用 `schema.parse()`），Phase 29 采用 **直接 Json 结构匹配**：

```moonbit
pub fn user_from_json(json : Json) -> Result[User, Array[ValidationError]] {
  match json {
    Object(map) => {
      let name = match map.get("name") {
        Some(String(s)) => s
        Some(got) => return Err([ValidationError::{ path: "name", message: "expected string", got }])
        None => return Err([ValidationError::{ path: "name", message: "required", got: Null }])
      }
      let age = match map.get("age") {
        Some(Number(v, ..)) => v.to_int()
        Some(got) => return Err([ValidationError::{ path: "age", message: "expected integer", got }])
        None => return Err([ValidationError::{ path: "age", message: "required", got: Null }])
      }
      Ok({ name:, age: })
    }
    _ => Err([ValidationError::{ path: "", message: "expected object", got: json }])
  }
}
```

### 为什么选择 Direct Extraction 而非 Schema-first

| 方案 | 优点 | 缺点 |
|---|---|---|
| Schema-first（调用 `schema.parse()`） | 复用现有验证逻辑 | 需生成 Schema 表达式；abort() 语义矛盾 |
| Direct Extraction（当前方案） | 无运行时 Schema 依赖；错误处理正确；代码自包含 | 生成代码略多 |

Direct Extraction 解决了 Phase 28 反馈中的三个关键问题：
1. ✅ **无 `abort()`** — 所有提取路径均返回 `Err(...)`
2. ✅ **无方法语法争议** — 使用独立函数 `fn user_from_json()`
3. ✅ **无嵌套 Schema 引用问题** — 嵌套对象通过 `other_from_json(v)` 委托

### 函数命名约定

```moonbit
pub fn ${snake_case}_from_json(json : Json) -> Result[${StructName}, Array[ValidationError]]
// 例: User → user_from_json, ItemList → item_list_from_json
```

`snake_case` 转换规则：
- `User` → `user_from_json`
- `ItemList` → `item_list_from_json`
- `HTTPServer` → `h_t_t_p_server_from_json`（每个大写字母前加分隔符）

### 提取类型表达式

| SchemaType | 生成的提取代码 |
|---|---|
| StringType | `match v { String(s) => s; _ => return Err(...) }` |
| NumberType (int) | `match v { Number(v, ..) => v.to_int(); _ => return Err(...) }` |
| NumberType (double) | `match v { Number(v, ..) => v; _ => return Err(...) }` |
| BooleanType | `match v { True => true; False => false; _ => return Err(...) }` |
| NullType | `match v { Null => (); _ => return Err(...) }` |
| OptionalType(inner) | `match v { Null => None; v => Some(extract(v, inner)) }` |
| DefaultType(inner, _) | 透明：`extract(v, inner)` |
| ArrayType(elem) | `match v { Array(elems) => { let mut items = []; for item in elems { items.push(extract(item, elem)) }; items }; _ => return Err(...) }` |
| ObjectType(命名) | `match v { Object(_) => other_from_json(v); _ => return Err(...) }` |
| ObjectType(未命名) | `match v { Object(_) => v; _ => return Err(...) }` |
| EnumType(values) | `match v { String(s) => match s { "a" => A; "b" => B; _ => return Err(...) }; _ => return Err(...) }` |
| UnionType(T+Null) | 同 OptionalType |
| UnionType(复杂) | `v /* TODO: union type extraction */` |
| IntersectionType | 委托第一个命名 Object；否则 `v /* TODO */` |
| TransformType(inner) | 透明：`extract(v, inner)` |

### 字段级提取模式

**必填字段**（非 Optional、非 Default）：
```moonbit
let field_name = match map.get("field_name") {
  Some(v) => extract_type_expr("v", field_schema, named_schemas)
  None => return Err([ValidationError::{ path: "field_name", message: "required", got: Null }])
}
```

**可选字段**（OptionalType）：
```moonbit
let field_name = match map.get("field_name") {
  Some(Null) | None => None
  Some(v) => Some(extract_type_expr("v", inner_schema, named_schemas))
}
```

### 公共 API

```moonbit
pub fn schema_to_moonbit_struct_full(schema : Schema) -> String
// 单个 schema: struct 定义 + from_json() 函数

pub fn schema_to_moonbit_struct_named_full(schema : Schema) -> String
// 命名导出: 所有命名 schema 的 struct + from_json，拓扑排序
```

## 内部函数管道

```
schema_to_moonbit_struct_full(schema)
  ├─ object_to_struct_definition(spec, 0, name)      ← Phase 28 复用
  ├─ generate_from_json_fn(schema, name, 0, [])
  └─ 拼接 struct_def + "\n\n" + from_json_fn

generate_from_json_fn(schema, struct_name, indent, named_schemas)
  ├─ 遍历 ObjectType 的每个 (key, val_schema)
  ├─ extract_field(key, val_schema, 4, struct_name, named_schemas)
  └─ 拼接完整函数定义

extract_field(key, schema, indent, parent_struct, named_schemas)
  ├─ 判定 is_optional_schema
  ├─ 调用 extract_type_expr("v", inner, named_schemas)
  └─ 生成 let binding + match

extract_type_expr(json_var, schema, named_schemas)
  └─ 分派到 12 种 SchemaType 的提取代码
```

## 文件变更

| 文件 | 操作 | 说明 |
|---|---|---|
| `moonbit_struct.mbt` | 修改 | 新增 `generate_from_json_fn`、`extract_field`、`extract_type_expr`、`struct_name_to_fn_prefix`、`schema_to_moonbit_struct_full`、`schema_to_moonbit_struct_named_full` 等 ~350 行 |
| `test_moonbit_struct.mbt` | 修改 | 新增 16 个测试（full 类型提取、签名验证、命名导出、嵌套委托） |

## 测试覆盖

| 测试名 | 验证点 |
|---|---|
| full unnamed schema returns comment | 无 name → 注释提示 |
| full output contains struct and fn | 包含 `pub struct` + `pub fn xxx_from_json` + `Result[...]` |
| full string field extraction | `String(s) => s` + `expected string` |
| full int64 field extraction | `Number(v, ..) => v.to_int()` + `expected integer` |
| full double field extraction | `Number(v, ..) => v` + `expected number` |
| full bool field extraction | `True => true; False => false` + `expected boolean` |
| full optional field extraction | `Some(Null) \| None => None` |
| full default field transparent | 默认字段脱包装，同 Optional |
| full array field extraction | `Array(elems) => { let mut items : Array[String] = []; ... }` |
| full top-level object match | `match json { Object(map) =>` |
| full required field error | `None => return Err(` + `required` |
| full wrong type error | `return Err([ValidationError::` |
| full named export nested delegation | 包含 `address_from_json(v)` 调用 |
| full named export topological sort | Address → Person → Company 顺序 |
| full no named schemas | 空 named 集合 → 注释 |
| full multiple fields extraction | 全部 5 种字段类型均出现在提取代码中 |

**产出**: 360/360 测试全部通过 0 警告。

## 代码质量

- `moon build` 0 错误 0 警告
- `.mbti` 新增 `pub fn schema_to_moonbit_struct_full(Schema) -> String` 和 `pub fn schema_to_moonbit_struct_named_full(Schema) -> String`
- 无代码坏味道：直接复用 Phase 28 的 `is_optional_schema()`、`object_to_struct_definition()`、`topological_sort_schemas()` 等

## 未包含内容

- `from_json` 对 UnionType（复杂）和 IntersectionType（非全 Object）→ 生成 `// TODO` 注释
- 多层路径错误追踪（当前仅单层 `path: "field_name"`）
- 生成的代码编译运行测试（仅字符串验证，不实际运行生成代码）
- CLI `cmd/gen-struct` 集成（Phase 30 规划）