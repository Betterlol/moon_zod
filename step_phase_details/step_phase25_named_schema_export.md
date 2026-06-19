# Stage Summary

## 1. Stage Description

Schema 命名导出与拓扑排序 (v0.6.0): 实现 `schema_to_prompt_named()` 自动提取命名 Schema 并生成分离的 TypeScript interface 定义，支持完整的拓扑排序和循环引用检测。

**分两个阶段完成**：
- **Stage 1** (cb16376): 基础命名导出 — 自动收集命名 Schema、生成接口定义
- **Stage 2** (99f966e): 健壮性完善 — 拓扑排序、循环检测、扩展测试
- **Bug Fix** (a8eec11): 修复重复定义和字段引用问题

## 2. Stage Metadata
- STAGE_ID: phase-25
- STAGE_TYPE: feature (major)
- BASE_COMMITS:
  - Stage 1: cb16376
  - Stage 2: 99f966e
  - Bug Fix: a8eec11

## 3. New Files

| File | Purpose |
|---|---|
| `test_prompt_named.mbt` | Schema 命名导出 6 个测试（基础 + 深嵌套 + 拓扑排序 + optional 字段） |
| `branch_doc/design_doc/PHASE_25_NAMED_SCHEMA_EXPORT.md` | 完整设计文档（算法、场景演示、实现分阶段计划） |

## 4. Modified Files

| File | Action | Description |
|---|---|---|
| `schema.mbt` | modify | Schema struct +1 field `name: String`；所有 wrapper 分支添加 `name: self.name` |
| `string.mbt` | modify | `string()` 工厂添加 `name: ""` |
| `number.mbt` | modify | `number()` 工厂添加 `name: ""` |
| `boolean.mbt` | modify | `boolean()` 工厂添加 `name: ""` |
| `null.mbt` | modify | `null()` 工厂添加 `name: ""` |
| `object.mbt` | modify | `object()` 工厂添加 `name: ""`；pick/omit/partial 传播 `name` |
| `array.mbt` | modify | `array()` 工厂添加 `name: ""` |
| `union.mbt` | modify | `optional()`/`default()`/`enum_values()`/`union()` 工厂添加 `name` 初始化/传播 |
| `intersection.mbt` | modify | `intersection()` 工厂添加 `name: ""` |
| `transform.mbt` | modify | `transform()` 传播 `name` |
| `prompt.mbt` | modify | 新增 ~800 行：命名收集、拓扑排序、接口生成、名字引用；新增 `schema_to_prompt_named()` 公开 API |
| `test_prompt_named.mbt` | create | 6 个新测试 |

## 5. Algorithm Deep Dive

### Stage 1: 基础命名导出

**核心逻辑**：
```
collect_named_schemas(schema)
  ├─ collect_named_schemas_impl(schema, visited, result)
  │  └─ 递归遍历所有字段/元素，收集 name != "" 的 schema
  │  └─ visited 数组检测循环，避免重复
  └─ 返回命名 schema 数组

schema_to_prompt_named(schema)
  ├─ collect_named_schemas(schema) → named_schemas
  ├─ generate_prompt_with_interfaces(named_schemas)
  └─ 返回完整 TypeScript interface 列表
```

**自动收集优势**：
- ✅ 无需手动维护名字列表
- ✅ 避免实现 schema 等价性判断（`schema_eq` 复杂度高）
- ✅ 一次遍历收集 O(n)

### Stage 2: 健壮性完善 — 拓扑排序

**问题**：未排序时，引用可能先于定义出现（前向引用）

**解决**：三阶段拓扑排序
```
1. find_schema_dependencies(schema_map) → deps_list
   - 遍历每个 named schema，递归收集依赖关系
   - 返回 [(name, [dep_names])] 列表

2. dfs_topo_sort(name, deps_list, visited, sorted)
   - 三态标记：0=未访问, 1=正在访问, 2=已访问
   - 后序遍历：先递归访问依赖，再添加当前 schema
   - 自动跳过循环（visited[dep] == 1 时忽略）

3. 排序后顺序保证：定义始终先于引用
```

**关键设计**：
- ✅ 用 Array 实现（避免 Map 依赖）
- ✅ 三态标记检测循环（简单高效）
- ✅ O(V + E) 图遍历复杂度

### Field Reference Replacement

**问题** (Bug Fix)：对象字段内容未被替换为名字

**解决**：新增 `schema_to_interface_definition_with_names()`
```
ObjectType(spec, _)
  ├─ 不使用 object_to_prompt()  ❌ 返回内联展开
  └─ 使用 object_to_inline_prompt(spec, 0, named_schemas) ✅
     └─ 检查每个字段是否在 named_schemas 中
     └─ 若是，用名字替代；否则内联展开
```

## 8. ACTION_LOG

| Action | Details |
|---|---|
| Add field | Schema.name: String |
| Update factories | All 11 factories initialize name="" |
| New public API | `pub fn schema_to_prompt_named(Schema) -> String` |
| New internal functions | collect_named_schemas_impl, topological_sort_schemas, find_schema_dependencies_impl, dfs_topo_sort, schema_to_interface_definition_with_names, type_to_inline_prompt, object_to_inline_prompt, union_to_prompt_inline, intersection_to_prompt_inline |
| New tests | test_prompt_named.mbt (6 tests) |
| Bug fix | 修复重复定义 + 字段引用替换 |

## 9. Test Coverage

**新增 6 个测试** (282 → 282, +3 新 → 已修复至 282):

| Test | Purpose |
|---|---|
| object_and_enum_export | 基础命名导出验证 |
| nested_objects | 嵌套对象递归收集 |
| array_of_named_objects | 数组元素命名 schema |
| deep_nesting | 3 层深度嵌套 |
| topological_sort | 定义顺序正确性 |
| optional_named_field | optional 包装兼容性 |

**示例输出对比**：

❌ **之前** (内联展开 + 重复定义):
```typescript
export interface Order {
  user: {
    name: string,
    age: number,
  },
  product: {
    name: string,
    price: number,
  },
}
export interface Order Order  // 重复！
```

✅ **现在** (分离导出 + 名字引用):
```typescript
export interface User {
  name: string,
  age: number,
}

export interface Product {
  name: string,
  price: number,
}

export interface Order {
  user: User,
  product: Product,
}
```

## 10. Risks / Notes

- **自动收集循环检测**：visited 数组 O(n) 查找，对小规模 schema 可接受；大规模需优化
- **拓扑排序局限**：仅处理 DAG，循环引用时自动跳过（不报错，可能无限等待某个定义）
- **Array-based 实现**：无外部依赖，但 visited 查找线性。对 <100 个命名 schema 无感知
- **Enum 导出**：生成 `type Mood = "calm" | ...` 而非 `export interface Mood`

## 11. Performance

- **收集阶段**：O(n) 单次深度遍历
- **排序阶段**：O(V + E) DFS
- **总体**：O(n) 对大多数应用无感知

## 12. Version Impact

- **v0.6.0**：新增 `schema_to_prompt_named()` 公开 API（向后兼容）
- 不影响现有 `schema_to_prompt()` 行为
- 不影响验证逻辑

## 13. Known Issues / Future Work

- ⚠️ 循环引用时的行为：自动跳过（不报错）— 可能改进为检测并警告
- ⚠️ 大规模 schema 图性能：考虑 visited 使用 Map 代替 Array
- ⚠️ 多层循环：三态标记仅检测单路径循环，复杂图仍需强化

---

详见 `PHASE_25_NAMED_SCHEMA_EXPORT.md` 完整设计文档。
