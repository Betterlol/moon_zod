# MoonZod core

Schema IR, schema factories, and synchronous JSON validation. This module depends
on `moonbitlang/regexp` and does not depend on importers, exporters, or async IO.

Add `Betterlol/moon_zod/core` as a module dependency and import its root package:

```moonbit
// moon.pkg
import {
  "Betterlol/moon_zod/core" @core,
}
```

```moonbit nocheck
let schema = @core.object({ "name": @core.string().min(2) })
let result = schema.parse(input_json)
```

In the repository workspace, run `moon test core` to test this module. See the
[workspace guide](../docs/WORKSPACE.md) for development and publishing.
