### schema2json
> 展示将 Zod Schema 转换为 JSON Schema 的能力。

**MoonBit CLI** (direct schema inspection):
```bash
# moon run examples/schema2prompt -- [schema name] [schema|validate]
moon run examples/schema2json -- product schema
moon run examples/schema2json -- product validate '{"name":"Widget","description":"A useful gadget","price":9.99,"currency":"USD","category":"electronics","tags":["gadget"],"stock":100}'
```