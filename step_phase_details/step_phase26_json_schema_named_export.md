# Phase 26 — JSON Schema Named Export (`to_json_schema_named()`)

**目标**: 实现 `to_json_schema_named()` — 将命名 Schema 导出为含 `$defs` 和 `$ref` 的标准 JSON Schema 文档，与 Phase 25 的 `schema_to_prompt_named()` 对标。

## 设计决策

### 输出格式

遵循 JSON Schema 2019-09+ 的 `$defs` 惯例：

```json
{
  "$ref": "#/$defs/User",
  "$defs": {
    "User": {
      "type": "object",
      "properties": {
        "address": { "$ref": "#/$defs/Address" }
      },
      "required": ["address"],
      "additionalProperties": true
    },
    "Address": {
      "type": "object",
      "properties": { "street": { "type": "string" } },
      "required": ["street"],
      "additionalProperties": true
    }
  }
}
```

- 根 Schema 若命名，使用 `$ref` 引用；若非命名，内联展开
- 对象字段、数组元素、union/intersection 子项中引用命名 Schema → `$ref`
- `$defs` 条目本身使用 `to_json_schema_named_full`（不 $ref 自身，但子元素 $ref）

### 算法架构

三层递归函数，复用 Phase 25 的收集与排序：

1. **`collect_named_schemas()`** (from `prompt.mbt`) — DFS 遍历收集所有命名 Schema
2. **`topological_sort_schemas()`** (from `prompt.mbt`) — 三态 DFS 拓扑排序保证定义顺序
3. **`to_json_schema_named(schema)`** — 入口：收集 → 排序 → 构建 `$defs` + 根
4. **`to_json_schema_ref(schema, named_names)`** — 若 schema 在命名列表中 → `$ref`；否则委派 `to_json_schema_named_full`
5. **`to_json_schema_named_full(schema, named_names)`** — 全量展开（不自引用），子元素使用 `to_json_schema_ref`

### 循环引用安全

- `to_json_schema_ref` 遇到命名 Schema 立即返回 `$ref`，不递归下降
- `to_json_schema_named_full` 不自引用，只对子元素递归
- 循环引用不会导致无限递归（每个命名 Schema 在 `$defs` 中展开一次）

### 非破坏性

- 无命名 Schema 时，输出 `{"$defs": {}}` 加根内联
- 与现有 `to_json_schema()` 完全独立，无 API 冲突
- 不修改现有任何函数签名

## 文件变更

| 文件 | 操作 | 说明 |
|---|---|---|
| `json_schema.mbt` | 修改 | 新增 `to_json_schema_named`、`to_json_schema_ref`、`to_json_schema_named_full`、`to_json_schema_ref_object` |
| `test_json_schema.mbt` | 修改 | 新增 9 个测试：命名导出基本功能、$ref 引用、数组/枚举/可选字段、拓扑排序顺序、空命名集 |

## 测试覆盖

| 测试名 | 覆盖场景 |
|---|---|
| named schema has $defs | 根命名 → `$ref` 引用 |
| $defs contains named schema | `$defs` 中有完整定义 |
| named field uses $ref | 对象字段引用命名 → `$ref` |
| array of named schemas | 数组元素引用命名 |
| enum named schema | 枚举命名导出 |
| optional named field | 可选字段不影响 required |
| no named schemas | 空 $defs 边界 case |
| topological sort ordering | 三层层级依赖排序 |
| named fields use $ref in $defs entries | $defs 内字段引用 $ref |

**产出**: 291/291 测试全部通过 0 警告。
