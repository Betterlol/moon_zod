## Installation

```bash
moon add Betterlol/moon_zod
```

Or add to `moon.mod`:

```toml
import {
  "Betterlol/moon_zod",
}
```

---

## Quick Start

```moonbit nocheck
let schema = @moon_zod.object({
  "name": @moon_zod.string().min(2).max(50),
  "age": @moon_zod.number().int().min(0).max(150),
  "email": @moon_zod.string().email(),
})

match schema.parse(input_json) {
  Ok(valid) => {
    println("Valid")
    println(@debug.to_string(valid))
  }
  Err(errors) => {
    println("Invalid")
    println(errors.length().to_string())
    for e in errors {
      println(e.to_string())
    }
  }
}
```

**Zero-code CLI validation:**
```bash
# Infer schema from sample, validate data
moon run cmd/validate -- '{"name":"Alice","age":30}' '{"name":"Bob","age":25}'
# PASS

# Batch validation with JSON Lines
moon run cmd/validate -- '{"name":"Alice"}' '{"name":"Bob"}\n{"name":"Eve"}'
# Results: 2 passed, 0 failed
```
