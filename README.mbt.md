# moon_zod

A runtime JSON schema validation library for MoonBit, inspired by Zod and Pydantic.

Designed for LLM Tool Calling scenarios: validate and error-report structured JSON output from large language models at runtime.

## Usage

```mbt nocheck
///|
let schema = @moon_zod.object({
  "name": @moon_zod.string().min(2).max(50),
  "age": @moon_zod.number().int().min(0).max(150),
})

///|
let result = schema.parse(@json.parse(raw))
```

See [DESIGN.md](./DESIGN.md) for architecture and development roadmap.