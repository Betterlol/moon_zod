# MoonZod

Runtime JSON schema validation, schema import, and code/prompt export for MoonBit.

This module provides the unified `Betterlol/moon_zod` API. Its schema types and
factories come from `Betterlol/moon_zod/core`; importers and exporters are
independently published modules sharing the same core types.

```sh
moon add Betterlol/moon_zod
```

```moonbit
// moon.pkg
import {
  "Betterlol/moon_zod",
}
```

```moonbit nocheck
let schema = @moon_zod.object({
  "name": @moon_zod.string().min(2),
  "age": @moon_zod.number().int().min(0),
})
let result = schema.parse(input_json)
let json_schema = @moon_zod.to_json_schema(schema)
```

For only synchronous validation, depend on `Betterlol/moon_zod/core` directly.
The optional `Betterlol/moon_zod/async` package adds asynchronous refinements,
JSON Lines validation, and SSE adapters.

See the [project README](https://github.com/Betterlol/moon_zod) and
[workspace guide](https://github.com/Betterlol/moon_zod/blob/main/docs/WORKSPACE.md)
for examples, development, and publishing instructions.
