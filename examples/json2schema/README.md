### json2schema
> 展示使用CLI Tool将 JSON 数据转换为 Moon Zod Schema 的示例。

```bash
# generate a schema from a JSON sample
sh cmd/json2schema/cli.sh --file data.json
sh cmd/json2schema/cli.sh '{"name": "Alice", "age": 30, "isStudent": false}'

# if you want to generate a schema from a JSON Schema
sh cmd/json2schema/cli.sh --from-json-schema --file data.json
sh cmd/json2schema/cli.sh --from-json-schema '{"type": "object", "properties": {"name": {"type": "string"}, "age": {"type": "number"}, "isStudent": {"type": "boolean"}}}'
```

```bash
# for quick testing, you can use the following command to generate a JSON schema from a JSON file:
sh cmd/json2schema/cli.sh --file examples/resources/test_placeholder_post.json
sh cmd/json2schema/cli.sh --file examples/resources/test_placeholder_user.json
sh cmd/json2schema/cli.sh --file examples/resources/test_github_rust_repo.json

sh cmd/json2schema/cli.sh --from-json-schema --file examples/resources/Product_Json_Schema.json
```
