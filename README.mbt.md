# moon_zod

A runtime JSON schema validation library for MoonBit, inspired by [Zod](https://zod.dev) and [Pydantic](https://docs.pydantic.dev).

**Designed for LLM Tool Calling** — validate structured JSON output from large language models at runtime, with precise error reporting and self-correction support.

---

## ✨ Why MoonZod? (AI-First)

| Feature | moon_zod | Typical Validation |
|---|---|---|
| **Error collection** | Collects **all** errors in one pass | Most libs fail-fast on first error |
| **Hallucination defense** | Default **Strip** mode silently removes unknown fields | Would pass through hallucinated data |
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

---

## Features

- **Primitive schemas**: `string()`, `number()`, `boolean()`, `null()`
- **Compound schemas**: `object(Map)`, `array(Schema)`, `union(Array[Schema])`, `enum_values(Array[String])`
- **Validation rules**: `.min(n)`, `.max(n)`, `.nonempty()`, `.email()`, `.url()`, `.regex(pattern)`, `.int()`, `.positive()`, `.negative()`, `.multipleOf(n)`
- **Optional / Default**: `.optional()` and `.default(value)` with correct rule chaining through wrappers
- **Object modes**: `.strict()` rejects extra fields; `.passthrough()` allows them; `.strip()` (default) silently removes them
- **Custom rules**: `.refine(check, message)`
- **JSON Schema export**: `to_json_schema(schema)` produces a standard JSON Schema object
- **Detailed errors**: per-field path, message, and received value

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

## ⚡ Performance

moon_zod's **Mutable Path Stack** (Phase 5) defers path string construction until an error actually occurs. On the validation success path — the common case for well-behaved LLM output — **zero heap allocations** happen for path tracking.

This is especially important for **Wasm edge runtimes** where GC pauses and memory pressure directly impact request latency.

### Cross-Language Benchmark (100k iterations)

| Validator | Runtime | Adjusted Time | Ops/sec |
|---|---|---|---|
| **TS Zod** | In-process V8 | 430.2 ms | **232,456 ops/sec** |
| **MoonZod** | Wasm via moonrun | 1,729.1 ms | 57,837 ops/sec |
| **Handcrafted Match** | Wasm via moonrun | 96.4 ms | **1,037,718 ops/sec** |

> Wasm times are adjusted by subtracting 12.8 ms startup overhead (moonrun process spawn + module instantiation). TS Zod runs in-process with no startup overhead.
>
> Handcrafted Match is ~10.8x faster than MoonZod — expected for a minimal state machine vs general-purpose library. MoonZod vs TS Zod is not a direct comparison due to subprocess overhead.

Run the benchmarks:
```
moon run cmd/main                  # MoonZod throughput
cd bench_cross_lang && node bench.js  # Three-way comparison
```

---

## API Reference

### Factory Functions

| Function | Description |
|---|---|
| `string()` | Validates JSON strings |
| `number()` | Validates JSON numbers |
| `boolean()` | Validates JSON booleans |
| `null()` | Validates JSON null |
| `array(Schema)` | Validates arrays, recursively checking elements |
| `object(Map[String, Schema])` | Validates objects. **Default: Strip mode** |
| `enum_values(Array[String])` | Fixed set of allowed string values |
| `union(Array[Schema])` | Union type — passes if any schema matches |

### Schema Methods

| Method | Applies To | Description |
|---|---|---|
| `.parse(Json, path?)` | All | Validate, returns `Ok(Json)` or `Err(Array[ValidationError])` |
| `.min(n)` | string / number / array | Minimum length / value |
| `.max(n)` | string / number / array | Maximum length / value |
| `.nonempty()` | string | String must not be empty |
| `.email()` | string | Must contain `@` and `.` |
| `.url()` | string | Must start with `http://` or `https://` |
| `.regex(pattern)` | string | Must contain `pattern` as substring |
| `.int()` | number | Must be integer (no fractional part) |
| `.positive()` | number | Must be > 0 |
| `.negative()` | number | Must be < 0 |
| `.multipleOf(n)` | number | Must be multiple of `n` |
| `.optional()` | Any | Null or missing values skip validation |
| `.default(value)` | Any | Replace null with default value |
| `.strict()` | object | Reject undefined fields |
| `.passthrough()` | object | Keep undefined fields as-is |
| `.strip()` | object | Silently remove undefined fields (default) |
| `.refine(check, msg)` | Any | Custom validation predicate |

### Standalone Functions

| Function | Description |
|---|---|
| `to_json_schema(Schema)` | Export standard JSON Schema object |
| `format_path(Array[String])` | Join path stack to dot-notation string |

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
├── object.mbt          # object() + strict/passthrough/strip
├── union.mbt           # optional / default / enum / union
├── refine.mbt          # refine()
├── json_schema.mbt     # to_json_schema()
├── cmd/main/           # Benchmark
├── examples/llm_agent/ # LLM self-correction demo
└── moon_zod_test.mbt   # 74 tests
```

---

## Development

```bash
moon test                # Run all tests (74 total)
moon build               # Build the library
moon run cmd/main        # Run benchmark
moon run examples/llm_agent  # Run LLM demo
moon info && moon fmt    # Update interface + format
```

See [DESIGN.md](./DESIGN.md) for architecture and development history.
