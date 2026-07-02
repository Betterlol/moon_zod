# moon_zod 简介

---

## 目录

- [moon_zod 核心概念：Type、Rule、Schema](#moon_zod-核心概念typeruleschema)
- [moon_zod 校验逻辑](#moon_zod-检验逻辑)

## moon_zod 核心概念：Type、Rule、Schema

### 三者的关系

```
Schema {
  schema_type : SchemaType,   // "是什么类型、怎么调度"
  rules      : Array[Rule],   // "额外校验什么"
  description: String,        // "描述文本"
  name       : String,        // "导出时的名字"
  required_error: String,
  invalid_type_error: String,
}
```

**Schema** = Type + Rules + 元数据。

- **Type（SchemaType）**：决定 **"输入应该是什么结构的"**，以及 **"怎么递归调度"**。
- **Rule**：决定 **"输入还有什么额外约束"**。每个 Rule = 一个 `(Json) -> Bool` 谓词。
- **Schema**：两者的组合 + 元数据。

---

### 三类函数

1. *Schema* **工厂函数**：`string()`, `number()`, `object({...})` 等。
> `pub fn string() -> Schema { ... }` 直接调用
2. *Schema* **规则追加函数**：`min()`, `max()`, `email()`, `refine()` 等。
> `pub fn Schema::min(self, min: usize) -> Schema { ... }` Schema对象调用
> 不改变 schema_type，只在 rules 上追加一条 Rule。
3. *Schema* **包装函数**：`optional()`, `default()`, `transform()` 等。
> `pub fn Schema::optional(self) -> Schema { ... }` Schema对象调用
> 改变 schema_type，清空 rules，包装内层 Schema。
> 目前实现中是通过 `OptionalType(inner)`、`DefaultType(inner, v)`、`TransformType(inner, f)` 来包装。

### Type 和 Rule 的本质区别

| | Type (SchemaType) | Rule |
|---|---|---|
| 职责 | 结构校验 + 流程调度 | 额外约束检查 |
| 影响 | `parse_inner` 的 match 分支 | `collect_errors` 的循环谓词 |
| 何时执行 | 先于 rules 执行 | 在 type 校验通过后执行 |
| 能否改变输入 | 能（DefaultType 替换 null） | 否 |
| 能否改变流程 | 能（OptionalType 跳过/null 分支）| 否 |

**关键规则**：Type 校验**先于** Rule 校验。

`string().min(3)` 对一个数值输入 `42` 的校验路径：

```
parse_inner → schema_type = StringType
  → 检查 json：Number(42) ≠ String(_)
  → ❌ Err("Expected string")
  → rules（包括 min 的 rule）被跳过，因 type 不匹配就提前返回了
```

如果 type 校验通过，再依次执行每个 Rule：

```
parse_inner → schema_type = StringType
  → 检查 json："hi" 是 String(_) ✅
  → collect_errors(rules)
    → rule.check("hi")：length >= 3？❌ → 记录错误
  → 有错误 → Err([...])
```

---

### SchemaType 的三种角色

#### 1. 原始类型（校验 Json 变体）

```moonbit
StringType   → 输入必须是 Json::String(_)
NumberType   → 输入必须是 Json::Number(_)
BooleanType  → 输入必须是 Json::True | False
NullType     → 输入必须是 Json::Null
```

#### 2. 容器类型（递归调度子 Schema）

```moonbit
ObjectType(fields, mode) → 递归校验每个字段
ArrayType(elem)          → 递归校验每个元素
EnumType(values)         → 检查值在列表内
UnionType(schemas)       → 任意分支通过即可
IntersectionType(schemas)→ 所有分支都通过
LiteralType(expected)    → 精确值匹配
```

#### 3. 装饰器类型（改变校验流程）

```moonbit
OptionalType(inner)  → null 直接通过，非 null 委托 inner
DefaultType(inner, v)→ null 时返回 v，非 null 委托 inner
TransformType(inner, f) → 校验后通过 f 变换输出值
```

装饰器类型的特点是：它们不自己做类型校验，而是**穿透到内层**。这也是为什么 `string().optional()` 后 `.min(3)` 仍然有效——`append_rule` 穿透 OptionalType 把 rule 加到了内层的 StringType 上。

---

### 链式调用的三种行为

```moonbit
string()           // SchemaType = StringType,   rules = []
  .min(3)          // SchemaType = StringType,   rules = [+minRule]     ← 追加 Rule
  .max(50)         // SchemaType = StringType,   rules = [+min, +max]   ← 追加 Rule
  .optional()      // SchemaType = OptionalType(↑), rules = []          ← 包装 Type
  .default("hi")   // SchemaType = DefaultType(↑),  rules = []          ← 包装 Type
```

| 操作 | 对 rules 的影响 | 对 schema_type 的影响 |
|------|----------------|----------------------|
| `.min(3)` | `rules` 加一条 | 不变 |
| `.email()` | `rules` 加一条 | 不变 |
| `.refine(fn)` | `rules` 加一条 | 不变 |
| `.optional()` | **清空 rules**（移交给内层）| 包一层 `OptionalType(inner)` |
| `.default(x)` | **清空 rules** | 包一层 `DefaultType(inner, x)` |
| `.transform(fn)` | **清空 rules** | 包一层 `TransformType(inner, fn)` |
| `.describe(t)` | 不变 | 不变 |
| `.name(n)` | 不变 | 不变 |
| `.message(m)` | 改最后一条 rule 的消息 | 不变 |

**为什么 optional/default/transform 要清空 rules？**

因为装饰器创建了新的 Schema 层。内层 Schema（被装饰的对象）已经持有 rules。装饰器的 rules 数组为空，当 `append_rule` 被后续调用时，它递归穿透装饰器找到内层，把新 rule 加在里面。

---

### `append_rule` 的穿透机制

这就是为什么 `string().optional().min(3)` 能正确工作：

```moonbit
fn append_rule_with_annotation(schema, check, message, annotation):
  match schema.schema_type:
    OptionalType(inner) =>
      // 不在这里加 rule！递归到 inner 去加
      append_rule_with_annotation(inner, check, message, annotation)
      // 返回新 OptionalType(new_inner)
    TransformType(inner, _) =>  // 同理
    DefaultType(inner, _) =>    // 同理
    _ =>
      // 到这里说明已穿透装饰器，到达真实类型
      { ..schema, rules: schema.rules + [{check, message, annotation}] }
```

所以 `.min(3)` 的 rule 最终被加到内层 StringType 的 `rules` 上，而不是 OptionalType 的 `rules` 上。

---

### 常见误区

#### "`.optional()` 会丢掉之前的 rules？"

不会。它清空的是外层 OptionalType 的 `rules` 数组，但内层 Schema 的 `rules` 保留。后续 `.min(3)` 通过 `append_rule` 穿透进去加到内层。

#### "`.default(12)` 在 string 上会导致运行时类型错误？"

运行时不会。如果输入为 null，`default(12)` 直接返回 `12`，不经历 StringType 校验。这是 Zod 相同的行为——默认值是替代 null 的回退值，不校验类型。

如果想确保默认值也是合法 string：`string().default("hello")`。

#### "装饰器类型的 rules 为什么要是空的？"

装饰器的 Schema（OptionalType/DefaultType/TransformType）的 `rules: []` 是因为它们只负责调度流程，不负责校验。校验在内层进行。如果装饰器有自己的 rules，`append_rule` 会穿透进去加，所以装饰器的 rules 永远保持为空。

#### "SchemaType 和 Rule 的边界在哪？"

| 应该用 SchemaType | 应该用 Rule |
|---|---|
| 需要改变校验流程 | 只需额外检查 |
| 需要修改输入值 | 只通过/不通过 |
| 需要递归调度子 Schema | 只对当前值做判断 |
| 需要多 Schema 组合 | 单 Schema 约束 |

如果拿捏不准，一条经验法则：**如果可以用 `refine` 实现，就用 Rule；如果需要修改输入或改变流程，就用 SchemaType。**

---

## moon_zod 检验逻辑

### 校验流程全景

```
parse_inner(schema, json, path_stack)
  │
  ├─ ObjectType(spec, mode) → parse_object
  │    遍历 spec 每个字段 → parse_inner(字段schema, json值)
  │
  ├─ ArrayType(elem) → parse_array
  │    遍历每个元素 → parse_inner(elem, 元素值)
  │
  ├─ OptionalType(inner) → parse_optional
  │    null → Ok(null)  非 null → parse_inner(inner)
  │
  ├─ DefaultType(inner, default_val) → parse_default
  │    null → Ok(default_val)  非 null → parse_inner(inner)
  │
  ├─ TransformType(inner, closure) → parse_transform
  │    parse_inner(inner) → Ok → closure(result) → Ok(transformed)
  │
  ├─ EnumType(values) → parse_enum
  │    检查 json 是否在 values 中
  │
  ├─ UnionType(schemas) → parse_union
  │    遍历 schemas，第一个 Ok 就返回；全部 Err 则收集错误
  │
  ├─ IntersectionType(schemas) → parse_intersection
  │    遍历 schemas，全部 Ok 才 Ok；有 Err 则收集全部错误
  │
  ├─ LiteralType(expected) → parse_literal
  │    精确匹配 Json 结构 + 值
  │
  ├─ StringType/NumberType/BooleanType/NullType (原始类型):
  │    1. 检查 Json 变体是否匹配
  │       → 不匹配 → Err("Expected type")
  │    2. 匹配 → collect_errors(rules)
  │       → 有错误 → Err(errors)
  │       → 无错误 → Ok(json)
```

---

### `Schema::parse` 流程与 path_stack 设计

#### 入口

```moonbit
pub fn Schema::parse(
  self : Schema,
  json : Json,
  path? : String = "",   // 可选根路径
) -> Result[Json, Array[ValidationError]]
```

#### `format_path`：错误路径的字符串化

```moonbit
///|
pub fn format_path(stack : Array[String]) -> String {
  let mut result = ""
  let mut first = true
  for part in stack {
    if first {
      result = result + part
    } else if part.has_prefix("[") {
      result = result + part
    } else {
      result = result + "." + part
    }
    first = false
  }
  result
}
```

#### path_stack：零分配成功路径

`parse` 内部维护一个 `Array[String]` 作为**可变路径栈**。错误路径段在递归入栈时 push，返回时 pop。`format_path` 仅在真正产生 `ValidationError` 时才被调用，拼接字符串。

**成功路径**：零次 `format_path` 调用，零堆分配。

**错误路径**：一次 `format_path` 调用，拼接出 `"users[0].name"` 格式的错误路径。

#### 设计动机

Phase 5 之前，`parse` 函数通过 `path : String` 参数在递归调用中传递路径，每一层递归都**提前拼接出新字符串**：

```moonbit
// 旧方式：path 作为不可变 String 传递，每层递归都分配新字符串

// 入口：parse(schema, json, path = "")

// object.mbt 中：
for key, val_schema in spec {
  let new_path = sub_path(path, key)  // ← 每次都分配新 String
  let result = parse_inner(val_schema, json_value, new_path)
}

// array.mbt 中：
for i = 0; i < arr.length(); i = i + 1 {
  let new_path = sub_index(path, i)   // ← 每次都分配新 String
  let result = parse_inner(elem, arr[i], new_path)
}

// 底层原始类型（StringType / NumberType / ...）中：
// path 已经被拼好了，直接拿来用：
Err([ValidationError::{ path: path, message: "Expected string", got: json }])
```

**问题**：String 在 MoonBit 中是不可变类型，`sub_path(a, b)` 必须分配一块新内存来拼接结果。对于 `{"users": [{"name": "Alice", "age": 30}]}` 这样的校验，即使全部通过，路径字符串仍然在每层递归中被分配：

```
path="" → sub_path("", "users") → "users"              ← 分配
       → sub_index("users", 0) → "users[0]"            ← 分配
       → sub_path("users[0]", "name") → "users[0].name" ← 分配
       → sub_path("users[0]", "age")  → "users[0].age"  ← 分配
```

4 次堆分配，全部浪费（因为校验成功了，路径只在错误消息中使用）。

更糟糕的是，`union` 或 `intersection` 等组合子会尝试多个分支，如果第一个分支失败了，已拼接的路径字符串也白白浪费了：

```
union([schema_a, schema_b, schema_c])
  → parse_inner(schema_a, json, path)  ← 分支 A：分配了路径但失败了
  → parse_inner(schema_b, json, path)  ← 分支 B：又要分配路径
  → parse_inner(schema_c, json, path)  ← 分支 C：继续分配
```

**path_stack 方案**：使用共享可变 `Array[String]` 作为路径栈。递归时 `push` 入栈，返回前 `pop` 出栈。只在真正产生 `ValidationError` 时才调用 `format_path` 拼接字符串：

```moonbit
// 新方式：push/pop 操作数组，零分配
path_stack.push("users")
path_stack.push("[0]")
path_stack.push("name")

// 只有产生错误时才调用：
let path = format_path(path_stack)  // "users[0].name"

// 返回前 pop 恢复
let _ = path_stack.pop()
let _ = path_stack.pop()
let _ = path_stack.pop()
```

**关于 `sub_path` / `sub_index` 的现状**：这两个函数仍然保留在代码中（`core/schema.mbt`），但已不在 `parse` 的热路径上使用。它们目前被 `exporters/` 和 `importers/` 中的非性能关键代码使用，用于在生成代码时构建字符串路径。`parse` 核心路径已完全改用 `path_stack`。

#### 执行示例

校验 `object({"users": array(object({"name": string()}))})` 对 `{"users": [{"name": 42}]}`：

```
path_stack        操作                        format_path 调用？
[]                parse_inner(根object)       ❌
["users"]         push("users")              ❌
["users", "[0]"]  push("[0]")                ❌
["users", "[0]"]  parse_inner(name=42)       ❌
                  → StringType 检查:          ❌
                    42 ≠ String → Err!
                  → format_path(path_stack)   ✅ "users[0]"
                  → pop("[0]")               —
["users"]         pop("[0]")                  —
[]                pop("users")                —
```

返回 `Err([{ path: "users[0]", message: "Expected string", got: 42 }])`。

对于**成功路径**（如 `{"users": [{"name": "Alice"}]}`），全程无 `format_path` 调用。

#### 代码中的 path_stack 操作模式

```moonbit
// 入栈：
path_stack.push(field_name)
// 或
path_stack.push("[" + i.to_string() + "]")

// 需要错误消息时：
let path = format_path(path_stack)  // 只在产生错误时调用

// 出栈（用 _ 丢弃返回值，避免 unused warning）：
let _ = path_stack.pop()
```

```moonbit
// object.mbt 的字段校验循环（简化）：
for key, val_schema in spec {
  path_stack.push(key)
  let result = parse_inner(val_schema, json_value, path_stack)
  let _ = path_stack.pop()
  // 收集 result...
}

// array.mbt 的元素校验循环（简化）：
for i = 0; i < arr.length(); i = i + 1 {
  path_stack.push("[" + i.to_string() + "]")
  let result = parse_inner(elem_schema, arr[i], path_stack)
  let _ = path_stack.pop()
  // 收集 result...
}
```

#### 为什么不用不可变路径？

MoonBit 的 `Array` 是引用类型，同一个 path_stack 引用被传递给整个 parse 调用树，所有递归分支共享。如果用不可变的 `List` 或 `String` 传递，每次 push 都要复制，`format_path` 的成本会叠加。

**path_stack 的核心优势**：
1. 共享可变引用 → 零复制
2. 延迟格式化 → 成功路径零分配
3. push/pop 配对 → 自动维护路径上下文

这个模式在 Phase 5 引入后，通过了白盒测试（`moon_zod_wbtest.mbt`）验证，确保 push/pop 始终平衡，不会出现路径错位。

---

