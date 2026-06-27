
## 背景

当前 `schema_to_prompt()` 将所有嵌套对象内联展开，LLM 面对深嵌套时理解准确率下降。需要一种方式将命名的子 schema 提取为独立 `export interface`/`type`，引用处用名字替代内联。

**核心思路**：采用**自动提取方案**
- 在定义时用 `.name()` 标记需要导出的 schema
- 导出时自动遍历 schema 树，收集所有命名的 schema
- 无需显式管理名字列表，避免实现复杂的 schema 等价性判断

---

## 场景展示

### 示例 1：Object 命名导出

```mbt
fn user_schema() -> @moon_zod.Schema {
  @moon_zod.object({
    "name": @moon_zod.string().min(2).max(50),
    "age": @moon_zod.number().int().min(0).max(150),
  }).name("User")
}

fn product_schema() -> @moon_zod.Schema {
  @moon_zod.object({
    "name": @moon_zod.string().min(1),
    "price": @moon_zod.number().positive(),
  }).name("Product")
}

fn order_schema() -> @moon_zod.Schema {
  @moon_zod.object({
    "user": user_schema(),      // 直接引用命名的 schema
    "product": product_schema(),
  }).name("Order")
}

fn main {
    let order = order_schema()
    let prompt = schema_to_prompt_named(order)  // 自动提取所有命名 schema
    println!(prompt)
}
```

**预期输出**：
```text
export interface User {
  name: string; // [2-50 chars]
  age: number; // [int, 0-150]
}

export interface Product {
  name: string; // [min: 1]
  price: number; // [positive]
}

export interface Order {
  user: User;
  product: Product;
}
```

### 示例 2：Enum 命名导出

```mbt
let mood = @moon_zod.enum(["calm", "nervous", "angry", "anxious"])
  .name("NPCMood")

let npc = @moon_zod.object({
  "name": @moon_zod.string(),
  "mood": mood,
}).name("NPC")

let prompt = schema_to_prompt_named(npc)
```

**预期输出**：
```text
type NPCMood = "calm" | "nervous" | "angry" | "anxious"

export interface NPC {
  name: string;
  mood: NPCMood;
}
```

---

## 实现设计

### 1. Schema 结构改动

在现有 Schema 结构基础上增加 `name` 字段：

```mbt
pub struct Schema {
  schema_type: SchemaType
  rules: Array[Rule]
  description: String
  name: String              // 新增：schema 的导出名（默认空字符串）
}
```

### 2. 新增方法

```mbt
// 给 schema 命名
pub fn Schema::name(self: Schema, text: String) -> Schema {
  { ...self, name: text }
}
```

### 3. 新增导出函数

```mbt
// 自动提取并导出命名的 schema
pub fn schema_to_prompt_named(schema: Schema) -> String
```

### 4. 核心算法

#### 步骤 1：收集所有命名 schema

遍历 schema 树，收集所有 `name` 不为空的 schema，去重（以 name 为 key）

```mbt
fn collect_named_schemas(schema: Schema, visited: @map.Map[String, Schema]) -> Array[Schema] {
  if visited.contains(schema.name) {
    return []  // 已处理，避免循环
  }

  let result = []
  if schema.name != "" {
    result.push(schema)
    visited.insert(schema.name, schema)
  }

  // 递归收集嵌套的命名 schema
  match schema.schema_type {
    | ObjectType(fields, _, _) => {
      fields.foreach(|_, field_schema| {
        result.extend(collect_named_schemas(field_schema, visited))
      })
    }
    | ArrayType(inner) => {
      result.extend(collect_named_schemas(inner, visited))
    }
    | _ => {}
  }

  result
}
```

#### 步骤 2：拓扑排序（可选但推荐）

确保被引用的 schema 先于引用者导出，避免前向引用问题

```mbt
fn topological_sort(schemas: Array[Schema]) -> Array[Schema] {
  // 构建依赖图
  // 深度优先遍历，生成排序后的列表
  // 避免循环引用：遍历时记录访问状态 (white/gray/black)
}
```

#### 步骤 3：生成 TypeScript 代码

对每个命名 schema，根据 schema_type 生成对应的 interface 或 type 定义：

- **ObjectType** → `export interface Name { ... }`
- **EnumType** → `type Name = "val1" | "val2" | ...`
- **ArrayType（仅作为顶级）** → `type Name = Array<...>`
- 其他类型不导出（inline）

#### 步骤 4：处理引用

在生成 prompt 时：
- 引用处检查是否已命名，若是则用名字替代，否则内联展开

```mbt
fn schema_to_typescript_type(schema: Schema, named_set: @set.Set[String]) -> String {
  if named_set.contains(schema.name) && schema.name != "" {
    return schema.name  // 已导出，直接引用
  }
  // 否则内联展开...
}
```

---

## 关键设计决策

| 决策 | 方案 | 原因 |
|------|------|------|
| 何时收集命名 | 自动遍历（不用显式列表） | 避免手动维护，无需 schema_eq 实现 |
| 支持的类型 | Object、Enum、Array | 其他基础类型命名无实际意义 |
| 循环检测 | 遍历时用 visited set | 高效、清晰 |
| 导出顺序 | 拓扑排序（可选） | 保证定义顺序正确 |
| 未命名的嵌套 | 内联展开 | 保持向后兼容，简化逻辑 |

---

## 实现阶段

**第 1 阶段**（最小化可用）：
- [ ] Schema 增加 name 字段
- [ ] 实现 `.name()` 方法
- [ ] 实现简单版 collect_named_schemas（无排序）
- [ ] 实现 schema_to_prompt_named（调用现有的生成逻辑）

**第 2 阶段**（健壮性）：
- [ ] 实现拓扑排序
- [ ] 完善循环引用检测
- [ ] 添加单元测试（深嵌套、重复引用、循环等）