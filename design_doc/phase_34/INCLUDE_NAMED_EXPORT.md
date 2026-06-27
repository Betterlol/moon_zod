# Phase 34 — `include_names` 选择性导出特性

## 问题

三个 named 导出函数（`schema_to_prompt_named`、`to_json_schema_named`、`schema_to_moonbit_struct_named`）在 Phase 25-29 实现时，默认**导出所有命名 Schema**。这在大型 Schema 树中会生成大量不必要的定义，占用 LLM context 或增加代码体积。

场景举例：
```moonbit
let address = object({ "street": string() }).name("Address")
let user = object({ "address": address, "name": string() }).name("User")
let order = object({ "user": user, "items": array(string()) }).name("Order")
// schema_to_prompt_named(order) 会导出 Address、User、Order 三个 interface
// 但有时只需要导出 Order 和 User（Address 在 LLM 场景中已定义过）
```

## 设计

### API 签名

```moonbit
pub fn schema_to_prompt_named(
  schema : Schema,
  include_names? : Array[String]? = None,  // 新增
) -> String

pub fn to_json_schema_named(
  schema : Schema,
  include_names? : Array[String]? = None,  // 新增
) -> Json

pub fn schema_to_moonbit_struct_named(
  schema : Schema,
  include_names? : Array[String]? = None,  // 新增
) -> String

pub fn schema_to_moonbit_struct_named_full(
  schema : Schema,
  include_names? : Array[String]? = None,  // 新增
) -> String
```

### 行为

- `include_names` 为 `None`（默认）→ 行为不变，导出所有命名 Schema
- `include_names` 为 `Some([...])` → 只导出列表中的 Schema，其余被过滤

### 核心技术实现

过滤逻辑最初在 4 个函数中各重复一次，Phase 34 重构时提取到 `shared_utils.mbt`：

```moonbit
fn filter_named_schemas(
  all_named: Array[Schema],
  include_names: Array[String]?,
) -> Array[Schema] {
  match include_names {
    None => all_named
    Some(names) => {
      let filtered : Array[Schema] = []
      for ns in all_named {
        for name in names {
          if ns.name == name {
            filtered.push(ns)
            break
          }
        }
      }
      filtered
    }
  }
}
```

## 文件变更

| 文件 | 变更 |
|------|------|
| `shared_utils.mbt` | 新增 `filter_named_schemas()` 函数 |
| `prompt.mbt` | `schema_to_prompt_named` 新增 `include_names?` 参数，使用 `filter_named_schemas` |
| `json_schema.mbt` | `to_json_schema_named` 新增 `include_names?` 参数，使用 `filter_named_schemas` |
| `moonbit_struct.mbt` | `schema_to_moonbit_struct_named` 和 `schema_to_moonbit_struct_named_full` 新增 `include_names?` 参数 |
| `test_prompt_named.mbt` | +129 行，6 个 `include_names` 测试（default/selective/partial/empty/non-existent/multiple）|
| `test_json_schema.mbt` | +71 行，5 个 `include_names` 测试 + `check_defs_contains` 辅助函数 |

## 测试覆盖

| 函数 | `include_names` 测试数 |
|------|----------------------|
| `schema_to_prompt_named` | 6 |
| `to_json_schema_named` | 5 |
| `schema_to_moonbit_struct_named` | 0（struct API 不稳定，跳过）|
| `schema_to_moonbit_struct_named_full` | 0（同上）|

## 关键决策

- 使用 `Array[String]?` 而非 `Array[String]` + 空数组表示"不导出"——`Some([])` 明确表示"不导出任何内容"，`None` 表示"导出全部"
- 不过滤依赖链——如果 `include_names` 排除了被引用的 Schema（如 Address），输出中仍会引用其名称，由调用者负责维护一致性
- 过滤逻辑用 O(n*m) 线性搜索（n=all_named, m=include_names），因为命名 Schema 数量通常 < 100
