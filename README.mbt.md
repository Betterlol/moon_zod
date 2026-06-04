# moon_zod

A runtime JSON schema validation library for MoonBit, inspired by Zod and Pydantic.

Designed for LLM Tool Calling scenarios: validate and error-report structured JSON output from large language models at runtime.

## Features

- **Primitive schemas**: `string()`, `number()`, `boolean()`, `null()`
- **Compound schemas**: `object(Map)`, `array(Schema)`, `union(Array[Schema])`, `enum_values(Array[String])`
- **Validation rules**: `.min(n)`, `.max(n)`, `.nonempty()`, `.email()`, `.url()`, `.regex(pattern)`, `.int()`, `.positive()`, `.negative()`, `.multipleOf(n)`
- **Optional / Default**: `.optional()` and `.default(value)` with correct rule chaining through wrappers
- **Object modes**: `.strict()` rejects extra fields; `.passthrough()` (default) allows them
- **Custom rules**: `.refine(check, message)`
- **JSON Schema export**: `to_json_schema(schema)` produces a standard JSON Schema object
- **Detailed errors**: per-field path, message, and received value

## Usage

```mbt nocheck
///|
let schema = @moon_zod.object({
  "name": @moon_zod.string().min(2).max(50),
  "age": @moon_zod.number().int().min(0).max(150),
  "email": @moon_zod.string().email().optional(),
})

///|
let result = schema.parse(@json.parse(raw))
```

See [DESIGN.md](./DESIGN.md) for architecture and development roadmap.
