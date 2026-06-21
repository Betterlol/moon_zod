# Phase 27.1 — `json_schema_to_moon_zod()` 缺陷修复

**目标**: 修复 Phase 27 遗留的三个真实 Bug。

---

## Bug 1: `json_to_literal()` 默认值双重嵌套

### 症状
输入 `{"type": "string", "default": "hello"}` 输出：
```
@moon_zod.string().default(@moon_zod.string().default("hello"))
```

### 根因
`json_to_literal(String(s))` 返回 `@moon_zod.string().default("hello")`（完整 moon_zod 表达式），被 `apply_constraints_to_code` 再次 `.default()` 包裹，形成双重嵌套。

### 修复
`json_to_literal` 改为输出 MoonBit Json 构造函数：

| 输入 Json | 修复前 | 修复后 |
|---|---|---|
| `String("hello")` | `@moon_zod.string().default("hello")` | `Json::string("hello")` |
| `Number(42)` | `@moon_zod.number().default(42)` | `Json::number(42)` |
| `True` | `@moon_zod.boolean().default(true)` | `Json::true()` |
| `False` | `@moon_zod.boolean().default(false)` | `Json::false()` |
| `Null` | `@moon_zod.null()` | `Json::null()` |

生成的最终链式调用正确：`@moon_zod.string().default(Json::string("hello"))`

---

## Bug 2: `$defs` 生成顺序无拓扑排序

### 症状
`$defs` 条目的 `let Name_schema = ...` 按 Map 遍历顺序生成，若 B 依赖 A 但 B 在 A 之前定义，生成的 MoonBit 代码出现前向引用错误。

### 根因
`json_schema_to_moon_zod` 直接遍历 `Map[String, Json]` 收集 names，未考虑依赖顺序。

### 修复
新增独立于 JSON 值的拓扑排序管线：

1. **`find_defs_deps(val, defs_names)`** — 递归扫描 JSON 树中的 `$ref` 值，匹配 `defs_names` 集合
2. **`collect_refs(val, defs_names, deps)`** — DFS 收集器，处理 Object/Array 递归
3. **`topo_sort_defs(deps_list)`** — 三态 DFS 排序，复用 Phase 25 的 0/1/2 标记协议
4. **`dfs_sort(...)`** — 递归访问，检测环并将 cycle 节点标记

`json_schema_to_moon_zod` 改为：收集 names → 构建 deps_list → 拓扑排序（含 cycle 标记）→ 按序生成代码

**注意**: Phase 25 的 `topological_sort_schemas()` 操作 `Schema` 对象类型（依赖 `.name` 字段），无法直接复用。本实现是全新的、适用于 JSON 值（`Json`）的拓扑排序。

---

## Bug 3: 循环引用无检测

### 症状
自引用 `$defs`（如 `Node → self` 或 `A ↔ B`）生成：
```
let Node_schema = @moon_zod.object({ "child": Node_schema }).name("Node")
```
MoonBit `let` 绑定不支持递归，编译错误。

### 根因
`ref_to_code` 无条件返回变量名，未检测是否构成循环引用。

### 修复
在 `dfs_sort` 中添加路径追踪：当发现 `status == 1`（正在访问中）的节点时，从 path 中捕获整个环中的节点 → 标记 `in_cycle`。

代码生成时，环中节点的 `let` 声明追加 `/* TODO: circular reference — manual fix needed */` 注释。

---

## 变更文件

| 文件 | 变更 |
|---|---|
| `from_json_schema.mbt` | +226/-32 行：新增拓扑排序管线 + `json_to_literal` 重写 + cycle 检测 |
| `test_json_schema.mbt` | +76 行：6 个新测试 |

## 测试覆盖

| 测试 | 场景 |
|---|---|
| default string/number/boolean value | Bug 1 修复验证 |
| reverse $defs order | Bug 2 修复：B 依赖 A 但 B 在前 |
| circular $defs reference | Bug 3：自引用 Node |
| mutual circular $defs | Bug 3：A↔B 互引用 |

**产出**: 322/322 测试全部通过 0 警告。
