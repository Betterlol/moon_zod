### gen-struct
> 展示使用 CLI Tool 将 JSON Schema 转换为 moonbit struct 代码。

```bash
# 从 JSON Schema 生成 moon_zod 代码
sh cmd/gen-struct/cli.sh --from-json-schema '{"type": "object", "properties": {"name": {"type": "string"}, "age": {"type": "number"}, "isStudent": {"type": "boolean"}}}'
sh cmd/gen-struct/cli.sh --from-json-schema --file path-to-json-schema-file
```

```bash
# 项目内置样例
sh cmd/gen-struct/cli.sh --from-json-schema --file examples/resources/Product_Json_Schema.json
```

输出示例：

```moonbit
pub struct Root {
  name : String?
  age : Double?
  isStudent : Bool?
} derive(ToJson, FromJson)

pub fn Root::to_schema() -> @moon_zod.Schema {
  let root = @moon_zod.object({ "name": @moon_zod.string().optional(), "age": @moon_zod.number().optional(), "isStudent": @moon_zod.boolean().optional() }).name("Root")
  root
}
```
