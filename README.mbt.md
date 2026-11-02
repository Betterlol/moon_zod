# moon_zod

[![CI](https://github.com/Betterlol/moon_zod/actions/workflows/ci.yml/badge.svg)](https://github.com/Betterlol/moon_zod/actions/workflows/ci.yml)
[![Mooncakes](https://img.shields.io/badge/mooncakes-published-blue)](https://mooncakes.io/docs/Betterlol/moon_zod)
[![doc](https://img.shields.io/badge/branch-doc-blue)](https://github.com/Betterlol/moon_zod/tree/doc)

> 🌏 [中文版 README](./README_zh.mbt.md)

---

## Documents

| Document | Description |
|---|---|
| [Design Document](./DESIGN.md) | Important! Core architecture, design decisions, and future directions |
| [API Reference](./docs/en/API.md) | Detailed API documentation |
| [CLI Reference](./docs/en/CLI.md) | Command-line usage |
| [Benchmark](./docs/en/BENCHMARK.md) | Performance comparison with other validation libraries |
| [Examples](./docs/en/EXAMPLES.md) | Practical usage examples |
| [Exporters](./exporters/README.md) | moon_zod exporters documentation |
| [Importers](./importers/README.md) | moon_zod importers documentation |

---

## About

moon_zod is a **runtime Schema intermediate representation (IR)** — a validation contract layer decoupled from input sources and output targets. It provides runtime JSON schema validation with a fluent chainable API, designed primarily for **LLM Tool Calling**, and serves as a cross-format schema interoperability bridge. See [DESIGN.md](./DESIGN.md) for details.

A Schema IR core providing runtime validation, multi-source import, multi-format export, and LLM hallucination defense — closing the loop from JSON Schema to prompt generation.

---

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

## Single-JSON token streams

`parse_stream()` validates one JSON document as text arrives. Feed it arbitrary
LLM token chunks synchronously; it can reject malformed JSON early. Keep feeding
until the token source ends, then call `finish()` to confirm success and run
schema validation once. Trailing content is rejected across chunk boundaries.

```mbt nocheck
let parser = @moon_zod.object({ "name": @moon_zod.string().min(2) }).parse_stream()

parser.feed("{\"na") // StreamPending
parser.feed("me\":\"Ada\"}") // StreamPending: still accepts trailing whitespace
match parser.finish() {
  StreamValid(value) => println("valid: " + @debug.to_string(value))
  StreamInvalidSchema(errors) => // report validation errors
  StreamInvalidJson(message) => // report malformed JSON
  StreamPending => ()
}
```

Input defaults to at most 1,048,576 UTF-16 code units and 128 nesting levels.
Set `max_length` and `max_depth` on `parse_stream()` to override these limits.
The parser buffers one document and releases its source text when JSON parsing
completes; successful schema validation is reported only by `finish()`.

**Zero-code CLI validation:**
```bash
# Infer schema from sample, validate data
moon run moon_zod/cmd/validate -- '{"name":"Alice","age":30}' '{"name":"Bob","age":25}'
# PASS

# Batch validation with JSON Lines
moon run moon_zod/cmd/validate -- '{"name":"Alice"}' '{"name":"Bob"}\n{"name":"Eve"}'
# Results: 2 passed, 0 failed
```

---

## ✨ Why MoonZod? (AI-First)

| Feature | moon_zod | Typical Validation |
|---|---|---|
| **Error collection** | Collects **all** errors in one pass | Most libs fail-fast on first error |
| **Hallucination defense** | Default **Strip** mode silently removes unknown fields | Would pass through hallucinated data |
| **Named schema export** | `schema_to_prompt_named()` generates modular TypeScript interfaces with type name references | Inline expansion + duplication |
| **JSON Schema export** | `to_json_schema()` generates standard schema for LLM API | Manual schema maintenance |
| **Path precision** | Every error includes exact field path (`users[0].profile.age`) | Often just a flat message |
| **Wasm-ready** | Shared path stack with error-path rendering | String-heavy allocation per parse |

In LLM Tool Calling, the model often produces **multiple errors at once** and **hallucinates extra fields**. moon_zod collects every error in a single pass (so you can send them all back for self-correction), and strips unknown fields by default (no silent data corruption from hallucinated keys).

---

## Project Layout

```
moon_zod/
├── moon.work                  # Workspace: five independently publishable modules
├── core/                      # Betterlol/moon_zod/core — Schema IR and validation
│   ├── moon.mod
│   └── ...
├── importers/                 # Betterlol/moon_zod/importers — JSON Schema import
│   ├── moon.mod
│   └── ...
├── exporters/                 # Betterlol/moon_zod/exporters — code/schema export
│   ├── moon.mod
│   └── ...
├── async/                     # Betterlol/moon_zod/async — independent async adapters
│   ├── moon.mod
│   └── benchmarks/
├── moon_zod/                  # Betterlol/moon_zod — unified facade
│   ├── moon.mod
│   ├── reexporter.mbt         # Single public API aggregation point
│   ├── combinators/          # Import/export composition
│   ├── cmd/                  # CLI tools and benchmarks
│   ├── examples/             # Usage examples and shared schemas
│   └── tests/                # Direct imports; no duplicate re-exports
├── docs/
└── moon_zod_lab/              # Separately managed consumer submodule
```

---

## Development

This repository uses `moon.work` to develop five modules together: the main
`Betterlol/moon_zod` facade and the independently publishable `/core`,
`/exporters`, `/importers`, and `/async` modules. Existing package import paths are
unchanged. See the [workspace guide](docs/WORKSPACE.md) for module dependencies,
direct imports, and release checks.

```bash
# Testing & Building
moon test                # Run tests across the workspace
moon build               # Build the library
moon check               # Type check (0 errors, 0 warnings)
moon info && moon fmt    # Update interface + format

# CLI Tools
moon run moon_zod/cmd/main                                      # Run performance benchmarks
moon run moon_zod/cmd/json2schema -- '{"hello":"world"}'      # JSON → moon_zod schema code
moon run moon_zod/cmd/json2schema -- --from-json-schema '<{...}>'  # JSON Schema → moon_zod code
moon run moon_zod/cmd/json2schema -- --from-json-schema '<{...}>' --verbose  # with debug output
moon run moon_zod/cmd/gen-struct -- --schema '<{...}>'          # JSON Schema → MoonBit structs
moon run moon_zod/cmd/validate -- '{"name":"Alice"}' '{"name":"Bob"}'  # Validate JSON

# Examples
moon run moon_zod/examples/mock/llm_agent                     # Basic LLM tool calling demo
moon run moon_zod/examples/mock/educational_agent             # Multi-round self-correction demo
moon run moon_zod/examples/real_llm_agent -- product prompt   # Real LLM with mock fallback
moon run moon_zod/examples/real_llm_agent -- product validate # Validate with real API
moon run moon_zod/examples/multiple_schemas                   # Multiple schema handling
moon run moon_zod/examples/schema2json -- product schema      # Schema → JSON Schema export
moon run moon_zod/examples/schema2prompt -- product schema    # Schema → prompt generation showcase
moon run moon_zod/examples/json2schema                        # JSON → moon_zod schema code gen
```

---

## Features

- **Primitive schemas**: `string()`, `number()`, `boolean()`, `null()`, `bigint()`
- **Compound schemas**: `object(Map)`, `array(Schema)`, `tuple([Schema...])`, `union(Array[Schema])`, `intersection(Array[Schema])`, `enum_values(Array[String])`, `literal(Json)`
- **Pass-through schemas**: `any()` and `unknown()` accept any JSON value (semantic distinction)
- **String validators** (23+): `.min(n)`, `.max(n)`, `.nonempty()`, `.trim()`, `.to_lower()`, `.to_upper()`, `.email()` (full RFC validation), `.url()` (full structure), `.regex(pattern)` (regular expression match), `.startsWith()`, `.endsWith()`, `.includes()`, `.uuid()`, `.cuid()`, `.ulid()`, `.datetime()`, `.ip()`/`.ipv4()`/`.ipv6()`, `.length(n)`
- **Number validators** (8+): `.int()`, `.positive()`, `.negative()`, `.multipleOf()`, `.finite()`, `.safe()`, `.min()`, `.max()`
- **Object modes**: `.strip()` (default, removes unknown fields), `.passthrough()` (keeps unknown fields), `.strict()` (rejects unknown fields)
- **Object composition**: `.pick(keys)`, `.omit(keys)`, `.partial()`, `.extend_with(Map)`, `.merge(Schema)`
- **Optional/Default handling**: `.optional()` and `.default(value)` with correct rule chaining through wrappers
- **Data transformation**: `.transform(fn)` validates then transforms; `preprocess(fn, schema)` transforms then validates
- **Custom rules**: `.refine(check, message)`, `.intersect(other)` for explicit intersection
- **Schema naming & metadata**: `.name(text)` for named exports, `.describe(text)` for LLM prompts, `.brand(text)` for nominal typing
- **Custom error messages**: `msg?` parameter on all validators, `.message(text)` override method, type-level `required_error` / `invalid_type_error`
- **Error collection**: Collects **all** validation errors in one pass, perfect for LLM self-correction loops
- **Full-path error reporting**: Every error includes exact field path (`users[0].profile.age`)
- **Optional async extensions**: `Betterlol/moon_zod/async` adds single/multi-issue async refinements, JSON Lines, and single/multi-frame SSE JSON validation while keeping the core API synchronous. See the [async guide](async/README.mbt.md)
- **LLM prompt generation**:
  - `schema_to_prompt(schema)` — inline TypeScript-interface with constraint comments
  - `schema_to_prompt_named(schema, include_names?)` — modular interfaces with topological sorting and type name references
- **JSON Schema export**:
  - `to_json_schema(schema)` — standard JSON Schema with full constraint annotations
  - `to_json_schema_skeleton(schema)` — lightweight skeleton (structure only)
  - `to_json_schema_named(schema, include_names?)` — separate `$defs` and `$ref` references
- **JSON Schema reverse import**:
  - `json_schema_to_moon_zod(json_schema)` — generate moon_zod source code from standard JSON Schema
  - Full support for `$defs`, `$ref`, constraints, format validation, enum
- **MoonBit struct generation**:
  - `schema_to_moonbit_struct(schema)` — recursively generate MoonBit struct/enum definitions for every object/enum schema
  - `schema_to_moonbit_struct_full(schema)` — generate definitions plus static `Type::to_schema()` functions
- **Lightweight dependencies**: Core MoonBit library plus official `moonbitlang/regexp` for regex validation
- **WebAssembly-ready**: Shared path stack; parsed containers are rebuilt to preserve transformed values
- **Historical performance**: ~18.5k–56k validations/second; reproduce the benchmark for the version under test

---

## Related Projects

- [vscode-moon-zod-schema](https://github.com/Betterlol/vscode-moon-zod-schema.git) - VSCode extension for moon_zod. 
> website: [extension](https://marketplace.visualstudio.com/items?itemName=Betterlol.vscode-moon-zod-schema).

---

## Learn More

- [DESIGN.md](./DESIGN.md) for architecture, design decisions, and future directions.
- [CHANGELOG.md](./CHANGELOG.md) for release history.
- [中文 README](./README_zh.mbt.md) for Chinese documentation.
