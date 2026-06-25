### JSON-to-Schema 生成器 (CLI)

从任何 JSON 负载中即时生成 `@moon_zod` schema 代码 — 无需为真实世界的 API 数据手工编写 schema。

```bash
moon run cmd/json2schema -- '{"hello": "world"}'
```

输出：

```
── Input JSON ──
Object({hello: String(world)})

── Generated moon_zod Schema (copy-paste ready) ──
@moon_zod.object({
  "hello": @moon_zod.string(),
})

── End ──
```

该生成器递归推断类型（`string`、`number`、`boolean`、`null`、`array`、`object`），并安全转义对象键中的特殊字符。空数组会生成 `/* TODO: specify exact type */` 注释，以便在类型推断缺乏数据时提醒你。

---

### MoonBit 结构体生成器 (CLI)

从任何 JSON 示例生成 MoonBit 结构体定义 — 包括结构体定义和 `from_json()` 函数，用于类型安全转换。

```bash
moon run cmd/gen-struct -- '{"name":"Alice","age":30}'
```

输出：

```moonbit
pub struct InferredSchema {
  name : String
  age : Int64
}

pub fn inferred_schema_from_json(json : Json) -> Result[InferredSchema, Array[ValidationError]] {
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

支持嵌套对象、数组和可选字段。嵌套对象会自动命名并导出为单独的结构体定义。

---

### JSON 验证器 (CLI)

根据从示例推断的 schema 验证 JSON 数据 — 无需代码。支持 JSON Lines 进行批量验证。

```bash
# 单个 JSON 验证
moon run cmd/validate -- '{"name":"Alice","age":30}' '{"name":"Bob","age":25}'
# PASS

# 使用 JSON Lines 进行批量验证
moon run cmd/validate -- '{"name":"Alice"}' '{"name":"Bob"}\n{"name":"Eve"}\n{"age":30}'
# FAIL: line 3
#   [name] Required (got: Null)
# Results: 2 passed, 1 failed
```

**错误输出格式**：`[field_path] message (got: value)`