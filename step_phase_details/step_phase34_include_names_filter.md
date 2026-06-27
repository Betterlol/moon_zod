# Stage Summary

## 1. Stage Description

为三个 named 导出函数（`schema_to_prompt_named`、`to_json_schema_named`、`schema_to_moonbit_struct_named`、`schema_to_moonbit_struct_named_full`）新增 `include_names?` 可选参数，支持选择性导出命名 Schema。

同时提取 4 处重复的过滤逻辑到 `shared_utils.mbt::filter_named_schemas`，补充 `to_json_schema_named` 的 `include_names` 测试。

## 2. Stage Metadata
- STAGE_ID: phase-34
- STAGE_TYPE: feature + refactor
- BASE_COMMIT: 368991c

## 3. 功能说明

### 新增 API 参数

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

### 使用示例

```moonbit
let address = object({ "street": string() }).name("Address")
let user = object({ "address": address, "name": string() }).name("User")
let order = object({ "user": user }).name("Order")

// 默认：导出全部
schema_to_prompt_named(order)
// → export interface Address { ... }
// → export interface User { ... }
// → export interface Order { ... }

// 选择性导出：只导出 Order
schema_to_prompt_named(order, include_names=Some(["Order"]))
// → export interface Order { ... }
// User 和 Address 被过滤
```

## 4. 代码质量改进

### 重复代码消除

4 处相同的 `include_names` 过滤逻辑提取到 `shared_utils.mbt`：

```moonbit
// 之前：prompt.mbt / json_schema.mbt / moonbit_struct.mbt × 2 中各有一段
let selected_schemas = match include_names {
  None => all_named
  Some(names) => {
    let filtered : Array[Schema] = []
    for ns in all_named {
      for name in names {
        if ns.name == name { filtered.push(ns); break }
      }
    }
    filtered
  }
}

// 之后：所有函数统一调用
let selected_schemas = filter_named_schemas(all_named, include_names)
```

## 5. 文件变更

| 文件 | 变更 |
|------|------|
| `shared_utils.mbt` | 新增 `pub fn filter_named_schemas()` |
| `prompt.mbt` | `schema_to_prompt_named` 新增 `include_names?` 参数 |
| `json_schema.mbt` | `to_json_schema_named` 新增 `include_names?` 参数 |
| `moonbit_struct.mbt` | 两个 named 函数新增 `include_names?` 参数 |
| `test_prompt_named.mbt` | 6 个 `include_names` 测试 |
| `test_json_schema.mbt` | 5 个 `include_names` 测试 + `check_defs_contains` 辅助 |

## 6. 测试结果

- `moon build`: 0 errors
- `moon test`: 396/396 全部通过（新增 11 个测试）
