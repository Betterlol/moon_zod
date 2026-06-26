### schema2prompt
> 展示将 Zod Schema 转换为 Prompt （TS Interface） 的能力。

**MoonBit CLI** (direct schema inspection):
```bash
# moon run examples/schema2prompt -- [schema name] [prompt|validate]
moon run examples/schema2prompt -- product prompt
moon run examples/schema2prompt -- product validate '{"name":"Widget","description":"A useful gadget","price":9.99,"currency":"USD","category":"electronics","tags":["gadget"],"stock":100}'
```