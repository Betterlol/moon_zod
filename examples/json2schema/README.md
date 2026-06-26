### json2schema
> 展示使用CLI Tool将 JSON 数据转换为 Moon Zod Schema 的示例。

```bash
sh cmd/json2schema/cli.sh --file data.json
sh cmd/json2schema/cli.sh -- '{"name": "Alice", "age": 30, "isStudent": false}'
```

```bash
# for quick testing, you can use the following command to generate a JSON schema from a JSON file:
sh cmd/json2schema/cli.sh --file examples/json2schema/test_placeholder_post.json
sh cmd/json2schema/cli.sh --file examples/json2schema/test_placeholder_user.json
sh cmd/json2schema/cli.sh --file examples/json2schema/test_github_rust_repo.json
```
