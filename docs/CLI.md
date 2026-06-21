### JSON-to-Schema Generator (CLI)

Generate `@moon_zod` schema code instantly from any JSON payload — no need to write schemas by hand for real-world API data.

```bash
moon run cmd/json2schema -- '{"hello": "world"}'
```

Output:

```
── Input JSON ──
Object({hello: String(world)})

── Generated moon_zod Schema (copy-paste ready) ──
@moon_zod.object({
  "hello": @moon_zod.string(),
})

── End ──
```

The generator recursively infers types (`string`, `number`, `boolean`, `null`, `array`, `object`) and safely escapes special characters in object keys. Empty arrays produce a `/* TODO: specify exact type */` comment to alert you when type inference lacked data.

---