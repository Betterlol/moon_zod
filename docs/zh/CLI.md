### JSON转Schema生成器 (CLI)

从任何JSON数据负载即时生成 `@moon_zod` schema代码——无需手动为真实世界的API数据编写schema。

```bash
moon run cmd/json2schema -- '{"hello": "world"}'
```

输出（可直接复制粘贴的moon_zod代码）：

```moonbit
@moon_zod.object({
  "hello": @moon_zod.string(),
})
```

获取带有调试信息的详细输出：
```bash
moon run cmd/json2schema -- --verbose '{"hello": "world"}'
```

生成器递归推断类型（`string`、`number`、`boolean`、`null`、`array`、`object`），并安全转义对象键中的特殊字符。空数组会生成 `/* TODO: specify exact type */` 注释，以提醒你类型推断缺乏数据。

---

### JSON Schema反向导入器 (CLI)

从标准 **JSON Schema (draft-07)** 定义生成 `@moon_zod` schema代码——这是 `to_json_schema()` 的反向操作。

**内联模式**（JSON Schema作为命令参数）：
```bash
moon run cmd/json2schema -- --from-json-schema '{
  "type": "object",
  "properties": {
    "name": {"type": "string", "minLength": 2},
    "age": {"type": "integer", "minimum": 0, "maximum": 150}
  },
  "required": ["name", "age"]
}'
```

**文件模式**（从文件读取JSON Schema）：
```bash
moon run cmd/json2schema -- --from-json-schema --schema-file schema.json
```

输出：

```moonbit
@moon_zod.object({
  "name": @moon_zod.string().min(2),
  "age": @moon_zod.number().int().min(0).max(150),
})
```

**功能特性**：
- 转换所有JSON Schema类型（string、number、integer、boolean、null、array、object）
- 提取约束条件：`minLength`、`maxLength`、`minimum`、`maximum`、`exclusiveMinimum`、`exclusiveMaximum`、`multipleOf`、`pattern`、`format`（email、uri、date-time、ipv4、ipv6、uuid）
- 处理 `$defs` 和 `$ref` 引用——生成单独命名的schema声明
- 支持 `enum`、`oneOf`、`anyOf`、`allOf`
- 不在 `required` 中的字段自动用 `.optional()` 包装
- 输出**可直接复制粘贴的MoonBit源代码**
- 完全支持Phase 36语义：在适用的地方，`exclusiveMinimum`/`exclusiveMaximum` 生成 `.positive()`/`.negative()`

---

### MoonBit结构体生成器 (CLI)

从任何JSON样本生成MoonBit结构体定义——包括结构体定义和 `from_json()` 函数用于类型安全的转换。

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

支持嵌套对象、数组和可选字段。嵌套对象自动命名并作为单独的结构体定义导出。

---

### JSON校验器 (CLI)

针对从样本推断的schema校验JSON数据——无需代码。支持JSON Lines格式进行批量校验。

```bash
# 单个JSON校验
moon run cmd/validate -- '{"name":"Alice","age":30}' '{"name":"Bob","age":25}'
# PASS

# 使用JSON Lines进行批量校验
moon run cmd/validate -- '{"name":"Alice"}' '{"name":"Bob"}\n{"name":"Eve"}\n{"age":30}'
# FAIL: line 3
#   [name] Required (got: Null)
# Results: 2 passed, 1 failed

# 文件模式（JSON Schema作为schema源）
moon run cmd/validate -- --schema-file schema.json --sample-file data.json
```

**错误输出格式**：`[field_path] message (got: value)`