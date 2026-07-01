### json2schema
> 展示使用 CLI Tool 将 JSON 数据或 JSON Schema 转换为 moon_zod Schema 代码。

默认输出是可直接复制到 MoonBit 代码中的 schema 定义；需要查看解析后的输入时，加 `--verbose`。

```bash
# 从 JSON sample 推断 schema
sh cmd/json2schema/cli.sh '{"name": "Alice", "age": 30, "isStudent": false}'
sh cmd/json2schema/cli.sh --file data.json

# 从 JSON Schema 生成 moon_zod 代码
sh cmd/json2schema/cli.sh --from-json-schema '{"type": "object", "properties": {"name": {"type": "string"}, "age": {"type": "number"}, "isStudent": {"type": "boolean"}}}'
sh cmd/json2schema/cli.sh --from-json-schema --file schema.json

# 调试模式：同时打印解析后的输入
sh cmd/json2schema/cli.sh --verbose '{"name": "Alice"}'
```

```bash
# 项目内置样例
sh cmd/json2schema/cli.sh --file examples/resources/test_placeholder_post.json
sh cmd/json2schema/cli.sh --file examples/resources/test_placeholder_user.json
sh cmd/json2schema/cli.sh --file examples/resources/test_github_rust_repo.json

sh cmd/json2schema/cli.sh --from-json-schema --file examples/resources/Product_Json_Schema.json
```

输出示例：

```moonbit
let root = @moon_zod.object({ "name": @moon_zod.string(), "age": @moon_zod.number().int() }).name("Root")
```
