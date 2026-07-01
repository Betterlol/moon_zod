### validate_cli
> 展示借助 CLI 工具验证 JSON 数据：既可以从 sample JSON 推断 schema，也可以直接使用 JSON Schema。

```bash
# 使用 JSON Schema 文件验证 JSON 文件
sh cmd/validate/cli.sh --schema-file examples/resources/Product_Json_Schema.json --file examples/resources/Product_Json_Data.json

# 兼容旧写法：第一个 --file 作为 JSON Schema 文件
sh cmd/validate/cli.sh --file examples/resources/Product_Json_Schema.json --file examples/resources/Product_Json_Data.json

# 使用 sample JSON 文件推断 schema，再验证 data JSON 文件
sh cmd/validate/cli.sh --sample-file examples/resources/test_placeholder_user.json --file examples/resources/test_placeholder_user.json

# 直接传入内联 JSON Schema 和 JSON 数据
sh cmd/validate/cli.sh --schema '{"type":"string","minLength":2}' '"hello"'

# 直接传入 sample JSON 和 data JSON
sh cmd/validate/cli.sh '{"name":"Alice"}' '{"name":"Bob"}'
```

输出说明：

```text
PASS
```

或：

```text
FAIL
  [field] message (got: ...)
```
