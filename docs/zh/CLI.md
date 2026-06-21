### JSON-to-Schema 生成器 (CLI)

从任何 JSON 数据有效负载中即时生成 `@moon_zod` schema 代码 — 无需为真实世界的 API 数据手动编写 schema。

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

生成器会递归推断类型（`string`、`number`、`boolean`、`null`、`array`、`object`），并安全地转义对象键中的特殊字符。空数组会产生 `/* TODO: specify exact type */` 注释，以在类型推断缺乏数据时提醒您。