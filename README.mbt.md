# moon_zod

> 🌏 [中文版 README](./README_zh.mbt.md)

A runtime JSON schema validation library for MoonBit, inspired by [Zod](https://zod.dev) and [Pydantic](https://docs.pydantic.dev).

**Designed for LLM Tool Calling** — validate structured JSON output from large language models at runtime, with precise error reporting and self-correction support.

---

## ✨ Why MoonZod? (AI-First)

| Feature | moon_zod | Typical Validation |
|---|---|---|
| **Error collection** | Collects **all** errors in one pass | Most libs fail-fast on first error |
| **Hallucination defense** | Default **Strip** mode silently removes unknown fields | Would pass through hallucinated data |
| **Named schema export** | `schema_to_prompt_named()` generates modular TypeScript interfaces with type name references | Inline expansion + duplication |
| **JSON Schema export** | `to_json_schema()` generates standard schema for LLM API | Manual schema maintenance |
| **Path precision** | Every error includes exact field path (`users[0].profile.age`) | Often just a flat message |
| **Wasm-ready** | Mutable path stack — zero heap allocation on success path | String-heavy allocation per parse |

In LLM Tool Calling, the model often produces **multiple errors at once** and **hallucinates extra fields**. moon_zod collects every error in a single pass (so you can send them all back for self-correction), and strips unknown fields by default (no silent data corruption from hallucinated keys).

---

## 🚀 Quick Start

```mbt nocheck
let schema = @moon_zod.object({
  "name": @moon_zod.string().min(2).max(50),
  "age": @moon_zod.number().int().min(0).max(150),
  "email": @moon_zod.string().email(),
})

match schema.parse(input_json) {
  Ok(valid) => // use valid
  Err(errors) => // report all errors back to LLM
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

---

## Project Layout

```
moon_zod/
├── types.mbt           # Core types
├── schema.mbt          # Schema hub + parse dispatch
├── string.mbt          # string() + rules
├── number.mbt          # number() + rules
├── boolean.mbt         # boolean()
├── null.mbt            # null()
├── array.mbt           # array() + parse_array
├── object.mbt          # object() + strict/passthrough/strip/pick/omit/partial
├── union.mbt           # optional / default / enum / union
├── intersection.mbt    # intersection() / intersect()
├── refine.mbt          # refine()
├── transform.mbt       # transform()
├── prompt.mbt          # schema_to_prompt() / schema_to_prompt_named() — LLM prompt generation
├── json_schema.mbt     # to_json_schema() / to_json_schema_skeleton()
├── moonbit_struct.mbt  # schema_to_moonbit_struct() / schema_to_moonbit_struct_full()
│
├── test_*.mbt          # 14 type-specific test files
├── test_prompt_named.mbt # Named schema export tests
├── moon_zod_wbtest.mbt # White-box tests
│
├── cmd/                # CLI tools + benchmarks
│   ├── main            # Benchmark runner
│   ├── wasm            # Wasm cross-language benchmark
│   ├── json2schema     # JSON → moon_zod schema code generator
│   ├── gen-struct      # JSON → MoonBit struct definition
│   └── validate        # JSON validation CLI
└── examples/           # LLM agent demos
```

---

## Development

```bash
moon test                # Run all tests (377 total, 0 warnings)
moon build               # Build the library
moon run cmd/main        # Run benchmark
moon run cmd/json2schema -- '{"hello":"world"}'  # Generate schema from JSON
moon run cmd/gen-struct -- '{"name":"Alice"}'    # Generate MoonBit struct from JSON
moon run cmd/validate -- '{"name":"Alice"}' '{"name":"Bob"}'  # Validate JSON
moon run examples/llm_agent  # Run LLM demo
moon run examples/real_llm_agent -- product prompt  # Schema → prompt
moon info && moon fmt    # Update interface + format
```

---

## Features

- **Primitive schemas**: `string()`, `number()`, `boolean()`, `null()`
- **Compound schemas**: `object(Map)`, `array(Schema)`, `union(Array[Schema])`, `intersection(Array[Schema])`, `enum_values(Array[String])`
- **Validation rules**: `.min(n)`, `.max(n)`, `.nonempty()`, `.email()`, `.url()`, `.regex(pattern)`, `.startsWith(prefix)`, `.endsWith(suffix)`, `.includes(substring)`, `.uuid()`, `.cuid()`, `.datetime()`, `.ip()`/`.ipv4()`/`.ipv6()`, `.ulid()`, `.length(n)`, `.int()`, `.positive()`, `.negative()`, `.multipleOf(n)`, `.finite()`, `.safe()` — all with optional custom error message `msg?` parameter
- **Optional / Default**: `.optional()` and `.default(value)` with correct rule chaining through wrappers
- **Object modes**: `.strict()` rejects extra fields; `.passthrough()` allows them; `.strip()` (default) silently removes them
- **Schema composition**: `.pick(keys)`, `.omit(keys)`, `.partial()` to derive object sub-schemas
- **Data transform**: `.transform(fn)` validates then transforms the output
- **Custom rules**: `.refine(check, message)`
- **LLM prompts**:
  - `schema_to_prompt()` auto-generates inline TypeScript-interface prompt text with constraint comments
  - `schema_to_prompt_named()` auto-extracts named schemas with topological sorting and generates modular interfaces with type name references
- **Field descriptions**: `.describe(text)` attaches human-readable descriptions rendered by `schema_to_prompt()`
- **JSON Schema export**: `to_json_schema(schema)` produces a standard JSON Schema object
- **Type-level errors**: `.string(invalid_type_error="...", required_error="...")` — customize type mismatch and required field messages at factory level
- **Detailed errors**: per-field path, message, and received value
- **MoonBit struct generation** (Phase 28-29):
  - `schema_to_moonbit_struct()` generates MoonBit struct definitions from any ObjectType/EnumType schema
  - `schema_to_moonbit_struct_full()` generates struct definitions + `from_json()` functions for type-safe JSON → struct conversion
  - `schema_to_moonbit_struct_named()` / `schema_to_moonbit_struct_named_full()` handle nested named schemas with topological sorting
  - CLI: `moon run cmd/gen-struct -- '<json>'` — infer struct from JSON sample


## API Reference

### Factory Functions

| Function | Description |
|---|---|---|
| `string(required_error?, invalid_type_error?)` | Validates JSON strings |
| `number(required_error?, invalid_type_error?)` | Validates JSON numbers |
| `boolean(required_error?, invalid_type_error?)` | Validates JSON booleans |
| `null(required_error?, invalid_type_error?)` | Validates JSON null |
| `array(Schema, required_error?, invalid_type_error?)` | Validates arrays, recursively checking elements |
| `object(Map[String, Schema], required_error?, invalid_type_error?)` | Validates objects. **Default: Strip mode** |
| `enum_values(Array[String], required_error?, invalid_type_error?)` | Fixed set of allowed string values |
| `union(Array[Schema], required_error?, invalid_type_error?)` | Union type — passes if any schema matches |
| `intersection(Array[Schema], required_error?, invalid_type_error?)` | Intersection — passes if all schemas match; object fields are merged |

### Schema Methods

| Method | Applies To | Description |
|---|---|---|
| `.parse(Json, path?)` | All | Validate, returns `Ok(Json)` or `Err(Array[ValidationError])` |
| `.min(n[, msg])` | string / number / array | Minimum length / value |
| `.max(n[, msg])` | string / number / array | Maximum length / value |
| `.nonempty([msg])` | string | String must not be empty |
| `.email([msg])` | string | Full email validation (quoted local, IP literal, +tag, TLD≥2, single @) |
| `.url([msg])` | string | Full URL structure: `scheme://host[:port][/path][?query][#fragment]` |
| `.regex(pattern[, msg])` | string | Must contain `pattern` as substring |
| `.startsWith(prefix[, msg])` | string | Must start with `prefix` |
| `.endsWith(suffix[, msg])` | string | Must end with `suffix` |
| `.includes(substring[, msg])` | string | Must contain `substring` |
| `.uuid([msg])` | string | Must be a valid UUID v4 |
| `.cuid([msg])` | string | Must be a valid CUID (c + base36 hash) |
| `.datetime([msg])` | string | Must be ISO 8601 datetime (date + T + time ± offset/Z) |
| `.ip([msg])` | string | Must be a valid IPv4 or IPv6 address |
| `.ipv4([msg])` | string | Must be a valid IPv4 address |
| `.ipv6([msg])` | string | Must be a valid IPv6 address (full/shorthand, :: support) |
| `.ulid([msg])` | string | Must be a valid ULID (26-char Crockford base32) |
| `.int([msg])` | number | Must be integer (no fractional part) |
| `.positive([msg])` | number | Must be > 0 |
| `.negative([msg])` | number | Must be < 0 |
| `.multipleOf(n[, msg])` | number | Must be multiple of `n` |
| `.length(n[, msg])` | string / array | Must have exact length `n` |
| `.finite([msg])` | number | Must be finite (not NaN, not ±Infinity) |
| `.safe([msg])` | number | Must be a safe integer (not NaN, not ±Infinity, no fractional part) |
| `.optional()` | Any | Null or missing values skip validation |
| `.default(value)` | Any | Replace null with default value |
| `.strict()` | object | Reject undefined fields |
| `.passthrough()` | object | Keep undefined fields as-is |
| `.strip()` | object | Silently remove undefined fields (default) |
| `.describe(text)` | Any | Attach description rendered by `schema_to_prompt()` for LLM prompts |
| `.message(text)` | Any | Override the last rule's error message |
| `.intersect(other)` | Any | Intersection: input must match both schemas; object fields are merged |
| `.pick(keys)` | object | Select only specified fields |
| `.omit(keys)` | object | Remove specified fields |
| `.partial()` | object | Make all fields optional |
| `.refine(check, msg)` | Any | Custom validation predicate |
| `.transform(fn)` | Any | Validate then transform output via `(Json) -> Result[Json, String]` |

### Standalone Functions

| Function | Description |
|---|---|
| `schema_to_prompt(Schema)` | Generate TypeScript-interface prompt string for LLM (with constraint comments) — inline expansion |
| `schema_to_prompt_named(Schema)` | Generate modular TypeScript interfaces from named schemas with topological sorting and type name references — for complex, nested LLM tool schemas |
| `to_json_schema(Schema)` | Export standard JSON Schema object with full constraint annotations |
| `to_json_schema_skeleton(Schema)` | Export lightweight JSON Schema skeleton (structure only, no constraints) |
| `to_json_schema_named(Schema)` | Export named schemas as separate JSON Schema definitions with `$defs` |
| `schema_to_moonbit_struct(Schema)` | Generate MoonBit struct definition (type name, fields, constraints) from ObjectType/EnumType |
| `schema_to_moonbit_struct_full(Schema)` | Generate struct definition + `from_json()` function for type-safe JSON → struct conversion |
| `schema_to_moonbit_struct_named(Schema)` | Same as `schema_to_moonbit_struct()` but extracts and topologically sorts all nested named schemas |
| `schema_to_moonbit_struct_named_full(Schema)` | Same as `schema_to_moonbit_struct_full()` but extracts all nested named schemas |
| `format_path(Array[String])` | Join path stack to dot-notation string |
| `ValidationError::to_string()` | Format error as `[path] message (got: value)` |

### Core Types

```mbt nocheck
///|
pub struct ValidationError {
  path : String
  message : String
  got : Json
}

///|
pub type SchemaResult = Result[Json, Array[ValidationError]]

///|
pub enum ObjectMode {
  Passthrough
  Strict
  Strip
}
```


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

### MoonBit Struct Generator (CLI)

Generate MoonBit struct definitions from any JSON sample — struct definitions + `from_json()` functions for type-safe conversion.

```bash
moon run cmd/gen-struct -- '{"name":"Alice","age":30}'
```

Output:

```moonbit
pub struct InferredSchema {
  name : String
  age : Int64
}

pub fn inferred_schema_from_json(json : Json) -> Result[InferredSchema, Array[ValidationError]] {
  match json {
    Object(map) => {
      let name = match map.get("name") {
        Some(String(s)) => s
        Some(got) => return Err([ValidationError::{ path: "name", message: "expected string", got }])
        None => return Err([ValidationError::{ path: "name", message: "required", got: Null }])
      }
      let age = match map.get("age") {
        Some(Number(v, ..)) => v.to_int()
        Some(got) => return Err([ValidationError::{ path: "age", message: "expected integer", got }])
        None => return Err([ValidationError::{ path: "age", message: "required", got: Null }])
      }
      Ok({ name:, age: })
    }
    _ => Err([ValidationError::{ path: "", message: "expected object", got: json }])
  }
}
```

Supports nested objects, arrays, and optional fields. Nested objects are automatically named and exported as separate struct definitions.

---

### JSON Validator (CLI)

Validate JSON data against a schema inferred from a sample — no code required. Supports JSON Lines for batch validation.

```bash
# Single JSON validation
moon run cmd/validate -- '{"name":"Alice","age":30}' '{"name":"Bob","age":25}'
# PASS

# Batch validation with JSON Lines
moon run cmd/validate -- '{"name":"Alice"}' '{"name":"Bob"}\n{"name":"Eve"}\n{"age":30}'
# FAIL: line 3
#   [name] Required (got: Null)
# Results: 2 passed, 1 failed
```

**Error output format**: `[field_path] message (got: value)`


## ⚡ Performance

moon_zod's **Mutable Path Stack** (Phase 5) defers path string construction until an error actually occurs. On the validation success path — the common case for well-behaved LLM output — **zero heap allocations** happen for path tracking.

This is especially important for **Wasm edge runtimes** where GC pauses and memory pressure directly impact request latency.

### Cross-Language Benchmark (100k iterations)

| Validator | Runtime | Ops/sec |
|---|---|---|
| **TS Zod** | In-process V8 | 243,178 ops/sec |
| **MoonZod** | Native (@bench) | **3,815,556 ops/sec** |

> Both validators run in-process with no subprocess overhead. MoonZod uses MoonBit's `@bench` library for calibrated iteration counts (ns/op → ops/sec); TS Zod uses wall-clock timing over 100k manual `parse()` calls. MoonZod is ~15x faster than TS Zod on this benchmark, demonstrating the advantage of a focused, zero-allocation validation path (Phase 5 Mutable Path Stack).

Run the benchmarks:
```
moon run cmd/main                  # MoonZod throughput (3 benchmarks)
cd bench_cross_lang && node bench.js  # Cross-language comparison
```


##  Demo: Schema → `schema_to_prompt()` → LLM → `schema.parse()`

The **full LLM Tool Calling pipeline** in four steps, with **zero hand-written prompts**:

```
define Schema  →  schema_to_prompt()  →  feed to LLM  →  schema.parse()
   (MoonBit)        (auto-generated         (model         (auto-validate
                     TS interface)           response)      + strip extra fields)
```

```bash
python3 examples/real_llm_agent/agent.py product --mock --moon-prompt
```

> No API key needed — mock mode simulates a 2-round self-correction loop.
> For full details and live LLM usage, see [`examples/real_llm_agent/README.md`](./examples/real_llm_agent/README.md).

**What happens:**
1. `schemas.mbt` defines a product listing schema (8 fields, constraints: min/max, positive, enum, int...)
2. `schema_to_prompt()` auto-generates a TypeScript-interface prompt with `//` constraint comments — **no hand-crafted prompt needed**
3. LLM receives the prompt and returns JSON (mock simulates a bad → good retry)
4. `schema.parse()` validates and **Strip mode silently removes hallucinated fields**

**Output excerpt:**
```text
Schema-to-Prompt (TS interface):         ← auto-generated by schema_to_prompt()
  {
    name: string,  // [3-100 chars]
    description: string,  // [10-500 chars]
    price: number,  // [positive]
    currency: "USD" | "EUR" | "GBP" | "JPY" | "CNY",
    category: "electronics" | "clothing" | "food" | "books" | "other",
    tags: string[],  // [min: 1]
    stock: number,  // [int, min: 0]
    metadata?: {
      brand: string,  // [min: 1]
      weight_kg: number,  // [positive]
    },
  }

── Round 1 ──────────────────────────────────

  Calling deepseek-ai/DeepSeek-V3.2...
  LLM output:
    {
        "name": "Quantum Computing Starter Kit",
        "description": "A beginner-friendly kit to explore quantum computing concepts with hands-on simulations and guided experiments. Includes software access, tutorials, and basic theory materials.",
        "price": 299.99,
        "currency": "USD",
        "category": "electronics",
        "tags": ["quantum", "educational", "STEM", "beginner", "simulation"],
        "stock": 150,
        "metadata": {
            "brand": "QuantumLabs",
            "weight_kg": 1.5
        }
    }

  Validating with moon_zod (product)...

  ✅ VALIDATION PASSED  (Strip mode active)

  Clean data (hallucinations stripped):
    Object(
      {
        "name": String("Quantum Computing Starter Kit"),
        "description": String("A beginner-friendly kit to explore quantum computing concepts with hands-on simulations and guided experiments. Includes software access, tutorials, and basic theory materials."),
        "price": Number(299.99),
        "currency": String("USD"),
        "category": String("electronics"),
        "tags": Array(
          [
            String("quantum"),
            String("educational"),
            String("STEM"),
            String("beginner"),
            String("simulation"),
          ],
        ),
        "stock": Number(150),
        "metadata": Object({ "brand": String("QuantumLabs"), "weight_kg": Number(1.5) }),
      },
    )

  ✅ Self-correction loop completed in 1 round(s)
════════════════════════════════════════════════════════════
  Status: ✅ Success
  Rounds: 1
  Strip:  Extra fields removed by moon_zod default mode
════════════════════════════════════════════════════════════
```

---

## 🔄 LLM Self-Correction Example

moon_zod is designed for the **error feedback loop** — the key pattern that makes AI agents reliable:

```mbt nocheck
///|
/// Retry loop: validate → collect errors → feed back → retry
fn call_llm_with_retry(schema : @moon_zod.Schema, times : Int) {
  var attempt = 0
  while attempt < times {
    let raw = llm_call(schema)  // LLM returns JSON
    match schema.parse(raw) {
      Ok(clean) => return clean   // Strip mode removes hallucinations
      Err(errors) => {
        // Format all errors for the correction prompt
        var msg = "Fix these errors:\n"
        for e in errors {
          msg = msg + "  - \{e.path}: \{e.message}\n"
        }
        llm_feedback(msg)         // Send errors back
      }
    }
    attempt = attempt + 1
  }
}
```

**Without moon_zod**: LLM hallucinates extra fields → data corruption. LLM makes multiple mistakes → multiple round-trips.

**With moon_zod**: Strip mode cleans hallucinations. Full error collection fixes all mistakes in one retry.

See [`examples/llm_agent/`](./examples/llm_agent/) for a complete runnable demo:
```
moon run examples/llm_agent
```

---

## 📦 Modular Schemas: `schema_to_prompt_named()` for Complex Tool Definitions

For **large, deeply-nested schemas** with **reusable type definitions**, use `schema_to_prompt_named()` instead of inline expansion:

**Inline approach** (Phase 16-17, `schema_to_prompt()`):
```
User { Order { Product { ... } } }  →  expand all inline  →  HUGE prompt
```

**Modular approach** (Phase 25+, `schema_to_prompt_named()`):
```
User → uses type name `User`
Order → uses type name `Order`
Product → uses type name `Product`
```

Then **LLM sees only the definitions it needs**, reducing token count and improving clarity.

**Example usage:**
```mbt nocheck
// Define named schemas
let user_schema = @moon_zod.object({ ... }).name("User")
let order_schema = @moon_zod.object({ ... }).name("Order")
let product_schema = @moon_zod.object({ ... }).name("Product")

// Auto-extract + generate modular prompt
let prompt = @moon_zod.schema_to_prompt_named(user_schema)
// Output:
// export interface User { ... }
// export interface Order { ... }
// export interface Product { ... }
```

**Benefits**:
- ✅ Auto-extracts all named schemas (no manual list maintenance)
- ✅ Topological sort ensures definitions precede references
- ✅ Object field references use names instead of inline expansion
- ✅ Circular reference detection prevents infinite loops
- ✅ Perfect for OpenAPI-style schema documentation


## Learn More

- [DESIGN.md](./DESIGN.md) for architecture, design decisions, and future directions.
- [CHANGELOG.md](./CHANGELOG.md) for release history.
- [中文 README](./README_zh.mbt.md) for Chinese documentation.
