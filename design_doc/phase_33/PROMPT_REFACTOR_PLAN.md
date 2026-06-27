# prompt.mbt 重构计划

## 问题诊断

### 当前架构缺陷 (Visitor Pattern Anti-Pattern)

**现象**：13 个 SchemaType 变体分散在 6+ 个 match 语句中
- `type_to_prompt()` — 13 个分支
- `type_to_inline_prompt()` — 13 个分支（完全重复）
- `constraint_comment()` — 分发器
- `collect_named_schemas_impl()` — 9 个分支，缺 LiteralType
- `find_schema_dependencies_impl()` — 9 个分支，缺 LiteralType
- `schema_to_interface_definition_with_names()` — 仅 2 个分支，**缺 Union/Intersection/Literal** ❌

**后果**：
- 每新增 SchemaType → 修改 15+ 处
- 遗漏风险高（如 Union/Intersection named 导出 bug）
- ~170 行代码重复（union/intersection 渲染 + 约束提取逻辑）

### 代码重复分布

```
约束注释层 (Constraint Comment) — ~150 行重复
  ├─ string_constraint_comment()    [261-332]
  ├─ number_constraint_comment()    [335-428]
  ├─ array_constraint_comment()     [431-469]
  └─ 每个都重复了"从 Rule annotation 提取值"的逻辑

Union/Intersection 渲染 — ~20 行重复
  ├─ union_to_prompt() vs union_to_prompt_inline()
  └─ intersection_to_prompt() vs intersection_to_prompt_inline()
```

---

## 方案对比

| 方案 | 工作量 | 代码减少 | Match 数 | 新增 Type 成本 | 推荐度 |
|------|--------|--------|---------|--------------|--------|
| **A: Visitor 重构** | 1.5 天 | 909→~600 | 5+→1 | 1 处修改 | ⭐⭐⭐ |
| **B: 约束提取器** | 1-2 天 | 909→~750 | 5+→5 | 2-3 处修改 | ⭐⭐ |
| **C: 快速修复** | 2-3 小时 | 0 | 5+ | 15+ 处修改 | ⭐ |

---

## 推荐方案：A (Visitor Pattern with Traits)

### 核心设计

**关键更正**：MoonBit **有 trait 系统**，可直接实现 Visitor Pattern

```moonbit
pub trait SchemaRenderer {
  fn render_string(&self, schema: Schema) -> String
  fn render_number(&self, schema: Schema) -> String
  fn render_object(&self, schema: Schema, spec: Map[String, Schema]) -> String
  fn render_union(&self, schema: Schema, schemas: Array[Schema]) -> String
  fn render_intersection(&self, schema: Schema, schemas: Array[Schema]) -> String
  fn render_literal(&self, schema: Schema, value: Json) -> String
  // ... 其他 13 个类型的方法 ...
  
  /// 单一分发方法（这是唯一的 match 语句！）
  fn render(&self, schema: Schema) -> String {
    match schema.schema_type {
      StringType => self.render_string(schema)
      NumberType => self.render_number(schema)
      UnionType(schemas) => self.render_union(schema, schemas)
      IntersectionType(schemas) => self.render_intersection(schema, schemas)
      LiteralType(value) => self.render_literal(schema, value)
      // ... 其他 8 个类型 ...
    }
  }
}
```

### 具体实现

**BasicPromptRenderer** (无状态，基础 inline prompt)
```moonbit
pub struct BasicPromptRenderer {}

impl SchemaRenderer for BasicPromptRenderer {
  fn render_string(&self, _schema: Schema) -> String { "string" }
  fn render_number(&self, _schema: Schema) -> String { "number" }
  fn render_union(&self, _schema: Schema, schemas: Array[Schema]) -> String {
    // union_to_prompt_inline 的逻辑
  }
  fn render_literal(&self, _schema: Schema, value: Json) -> String {
    json_to_ts_literal(value)
  }
  // ... 实现其他 9 个方法 ...
}
```

**NamedPromptRenderer** (处理命名 schema 导出)
```moonbit
pub struct NamedPromptRenderer {
  named_schemas: Array[Schema]
}

impl SchemaRenderer for NamedPromptRenderer {
  // 覆盖：如果 schema 有名字，直接返回名字
  fn render_object(&self, schema: Schema, spec: Map[String, Schema]) -> String {
    if !schema.name.is_empty() {
      return schema.name
    }
    // 否则内联渲染
    self.render_object_inline(spec)
  }
  
  // 覆盖：生成 Union 接口定义
  fn render_union(&self, schema: Schema, schemas: Array[Schema]) -> String {
    if !schema.name.is_empty() {
      return "export type " + schema.name + " = " + self.union_to_type_expr(schemas)
    }
    self.union_to_type_expr(schemas)
  }
  
  // 新增：生成完整的接口定义
  fn generate_interface_definitions(&self) -> String {
    let sorted = topological_sort_schemas(self.named_schemas)
    let mut result = ""
    
    for schema in sorted {
      let def = match schema.schema_type {
        ObjectType(spec, _) => "export interface " + schema.name + " " + self.render_object(schema, spec)
        UnionType(schemas) => "export type " + schema.name + " = " + self.union_to_type_expr(schemas)
        LiteralType(value) => "export type " + schema.name + " = " + json_to_ts_literal(value)
        _ => ""
      }
      if !def.is_empty() { result = result + "\n\n" + def }
    }
    result
  }
}
```

### 公共 API

```moonbit
pub fn schema_to_prompt(schema: Schema) -> String {
  let renderer = BasicPromptRenderer {}
  renderer.render(schema)
}

pub fn schema_to_prompt_named(schema: Schema) -> String {
  let named_schemas = collect_named_schemas(schema)
  let renderer = NamedPromptRenderer { named_schemas }
  renderer.generate_interface_definitions() + "\n\n" + renderer.render(schema)
}
```

### 应用到其他模块

**json_schema.mbt** — 新建 `JsonSchemaRenderer` trait
```moonbit
pub trait JsonSchemaRenderer {
  fn render_string(&self, schema: Schema) -> Json
  fn render_object(&self, schema: Schema, spec: Map[String, Schema]) -> Json
  fn render_union(&self, schema: Schema, schemas: Array[Schema]) -> Json
  // ...
}

pub fn to_json_schema(schema: Schema) -> Json {
  let renderer = JsonSchemaRenderer {}
  renderer.render(schema)
}
```

**moonbit_struct.mbt** — 新建 `StructRenderer` trait
```moonbit
pub trait StructRenderer {
  fn render_string(&self, schema: Schema) -> String
  fn render_object(&self, schema: Schema, spec: Map[String, Schema]) -> String
  // ...
}
```

---

## 成本重新评估

| 任务 | 时间 |
|------|------|
| 定义 SchemaRenderer trait | 1 小时 |
| 实现 BasicPromptRenderer | 2 小时 |
| 实现 NamedPromptRenderer | 1.5 小时 |
| 迁移 prompt.mbt API | 1 小时 |
| 应用到 json_schema.mbt | 2 小时 |
| 应用到 moonbit_struct.mbt | 2-3 小时 |
| 测试 + 验证 | 2 小时 |
| **总计** | **~12 小时 (1.5 天)** |

**收益**：
- ✅ 代码行数：909 → ~600 (33% 减少)
- ✅ Match 语句：5+ → 1 个
- ✅ 新增 SchemaType：15+ 处修改 → 1 处修改
- ✅ 新增导出格式：新建 1 个 Trait impl

---

## 分阶段实施计划

### 阶段 1：快速修复 (2-3 小时) ✅ **已完成**
- ✅ Phase A: Union/Intersection/Literal 在 named 导出中的缺失
- ✅ Phase B: constraint_extractor.mbt 统一约束提取逻辑

### 阶段 2：约束提取器优化 (1-2 天) **可选**
- 若不做阶段 3，可独立优化约束提取
- 若做阶段 3，这部分会被 Visitor Pattern 包含

### 阶段 3：Visitor Pattern 重构 (1.5 天) **推荐**
1. 定义 `SchemaRenderer` trait 和两个实现
2. 迁移 prompt.mbt 的公共 API
3. 应用到 json_schema.mbt（创建 `JsonSchemaRenderer`）
4. 应用到 moonbit_struct.mbt（创建 `StructRenderer`）
5. 删除原来的 5+ 个 match 语句和重复代码
6. 全量单元测试

**后续验证**：需要确认 MoonBit trait object 的性能（vs 硬编码 match）

---

## 关键指标对比

```
需求：新增一个 SchemaType 变体

当前做法：
  ├─ type_to_prompt()                        ✏️
  ├─ type_to_inline_prompt()                 ✏️
  ├─ collect_named_schemas_impl()            ✏️
  ├─ find_schema_dependencies_impl()         ✏️
  ├─ schema_to_interface_definition_with_names() ✏️
  ├─ json_schema.mbt (5+ 个地方)            ✏️✏️✏️
  └─ moonbit_struct.mbt (10+ 个地方)        ✏️✏️✏️✏️✏️
  修改点：15+ 处，遗漏风险高 ❌

Visitor 模式：
  ├─ SchemaRenderer::render() [1 个 match]   ✏️
  ├─ BasicPromptRenderer::render_xxx()       ✏️
  ├─ NamedPromptRenderer::render_xxx()       ✏️
  ├─ JsonSchemaRenderer::render_xxx()        ✏️
  └─ StructRenderer::render_xxx()            ✏️
  修改点：5 处，遗漏风险低 ✅
```
