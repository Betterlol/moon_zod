# moon_zod

[![CI](https://github.com/Betterlol/moon_zod/actions/workflows/ci.yml/badge.svg)](https://github.com/Betterlol/moon_zod/actions/workflows/ci.yml)
[![Mooncakes](https://img.shields.io/badge/mooncakes-published-blue)](https://mooncakes.io/docs/Betterlol/moon_zod)

> 🌏 [中文版 README](./README_zh.mbt.md)

A runtime JSON schema validation library for MoonBit, inspired by [Zod](https://zod.dev) and [Pydantic](https://docs.pydantic.dev).

**Designed for LLM Tool Calling** — validate structured JSON output from large language models at runtime, with precise error reporting and self-correction support.

---

## Documents

| Document | Description |
|---|---|
| [API Reference](./docs/en/API.md) | Detailed API documentation |
| [CLI Reference](./docs/en/CLI.md) | Command-line usage |
| [Benchmark](./docs/en/BENCHMARK.md) | Performance comparison with other validation libraries |
| [Examples](./docs/en/EXAMPLES.md) | Practical usage examples |

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

```moonbit nocheck
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
├── core/                     # Core schema validation library
│   ├── types.mbt             # ValidationError, SchemaResult, core types
│   ├── schema.mbt            # Schema struct, parse dispatch, path stack
│   ├── string.mbt            # string() factory + validators (trim, to_lower, to_upper)
│   ├── number.mbt            # number() factory + validators
│   ├── boolean.mbt           # boolean() factory
│   ├── null.mbt              # null() factory
│   ├── bigint.mbt            # bigint() factory
│   ├── any_unknown.mbt       # any() / unknown() pass-through schemas
│   ├── array.mbt             # array() factory + parse_array
│   ├── tuple.mbt             # tuple() factory + parse_tuple
│   ├── object.mbt            # object() + modes (strip/passthrough/strict), pick/omit/partial/extend/merge
│   ├── optional.mbt          # optional() factory
│   ├── default.mbt           # default() factory
│   ├── enum.mbt              # enum_values() factory
│   ├── literal.mbt           # literal() factory (constant values)
│   ├── union.mbt             # union() factory
│   ├── intersection.mbt      # intersection() / intersect()
│   ├── refine.mbt            # refine() for custom validation
│   ├── transform.mbt         # transform() for data transformation
│   ├── preprocess.mbt        # preprocess() for input preprocessing
│   ├── shared_utils.mbt      # Common utilities (unwrap_schema, peel_optional, etc.)
│   ├── constraint_extractor.mbt  # Extract constraint info from rules
│   └── moon_zod_wbtest.mbt   # White-box tests (path stack invariants)
│
├── combinators/              # Schema combinator utilities
│   ├── schema_combinators.mbt # Schema composition helpers
│   └── reexporter.mbt        # Re-exports
│
├── exporters/                # Code/schema export tools
│   ├── prompt.mbt            # schema_to_prompt() / schema_to_prompt_named()
│   ├── prompt_renderer.mbt   # Trait-based prompt rendering
│   ├── json_schema.mbt       # to_json_schema() / to_json_schema_named()
│   ├── json_schema_renderer.mbt # Trait-based JSON Schema rendering
│   ├── moonbit_struct.mbt    # schema_to_moonbit_struct() + static to_schema() generation
│   ├── schema_exporter.mbt   # Shared exporter utilities
│   └── reexporter.mbt        # Module re-exports
│
├── importers/                # Schema import tools
│   ├── from_json_schema.mbt  # json_schema_to_moon_zod() — reverse JSON Schema → moon_zod code generation
│   └── reexporter.mbt        # Module re-exports
│
├── tests/                    # Test suite (466 tests)
│   ├── test_string.mbt       # string() validator tests (trim, to_lower, to_upper, nonempty)
│   ├── test_number.mbt       # number() validator tests
│   ├── test_boolean_null.mbt # boolean/null tests
│   ├── test_object.mbt       # object() mode + pick/omit/partial/extend/merge tests
│   ├── test_array.mbt        # array() + nonempty tests
│   ├── test_tuple.mbt        # tuple() tests
│   ├── test_combinators.mbt  # union/literal/optional/default/brand/bigint tests
│   ├── test_any_unknown_preprocess.mbt # any/unknown/preprocess tests
│   ├── test_transform_refine.mbt # transform/refine tests
│   ├── test_json_schema.mbt  # JSON Schema export + $defs/$ref tests
│   ├── test_json_schema_fixes.mbt # exclusiveMin/Max semantics + enum edge cases
│   ├── test_moonbit_struct.mbt # MoonBit struct generation tests
│   ├── test_prompt.mbt       # Prompt generation tests
│   ├── test_prompt_named.mbt # Named schema export tests
│   ├── test_custom_message.mbt # Custom error message tests
│   ├── test_errors.mbt       # Error collection tests
│   ├── test_schema_to_code.mbt # Code generation tests
│   └── reexporter.mbt        # Test re-exports
│
├── cmd/                      # CLI tools
│   ├── main/                 # Benchmark runner (performance baselines)
│   ├── wasm/                 # WebAssembly cross-language benchmark
│   ├── json2schema/          # JSON → moon_zod schema code generator + JSON Schema reverse importer
│   ├── gen-struct/           # JSON Schema → MoonBit struct generator
│   └── validate/             # JSON schema validator (infer-then-validate)
│
└── examples/                 # LLM agent demonstrations
    ├── gen-struct/           # JSON Schema → MoonBit struct generator demo
    ├── json2schema/          # JSON → moon_zod schema code generation
    ├── mock/                 # Mock agent demonstrations
    │   ├── llm_agent/        # Basic LLM tool calling example
    │   └── educational_agent/ # Multi-round self-correction demo
    ├── multiple_schemas/     # Handling multiple schemas
    ├── real_llm_agent/       # Real LLM integration (with API fallback to mock)
    ├── resources/            # Sample data files (JSON, JSON Schema)
    ├── schema2json/          # Schema → JSON Schema export demo
    ├── schema2prompt/        # Schema → prompt generation showcase
    ├── shared_schemas/       # Shared schema definitions (library package)
    └── validate_cli/         # CLI validation demo
```

---

## Development

```bash
# Testing & Building
moon test                # Run all tests (466 total, 0 warnings)
moon build               # Build the library
moon check               # Type check (0 errors, 0 warnings)
moon info && moon fmt    # Update interface + format

# CLI Tools
moon run cmd/main                                      # Run performance benchmarks
moon run cmd/json2schema -- '{"hello":"world"}'      # JSON → moon_zod schema code
moon run cmd/json2schema -- --from-json-schema '<{...}>'  # JSON Schema → moon_zod code
moon run cmd/json2schema -- --from-json-schema '<{...}>' --verbose  # with debug output
moon run cmd/gen-struct -- --schema '<{...}>'          # JSON Schema → MoonBit structs
moon run cmd/validate -- '{"name":"Alice"}' '{"name":"Bob"}'  # Validate JSON

# Examples
moon run examples/mock/llm_agent                     # Basic LLM tool calling demo
moon run examples/mock/educational_agent             # Multi-round self-correction demo
moon run examples/real_llm_agent -- product prompt   # Real LLM with mock fallback
moon run examples/real_llm_agent -- product validate # Validate with real API
moon run examples/multiple_schemas                   # Multiple schema handling
moon run examples/schema2json -- product schema      # Schema → JSON Schema export
moon run examples/schema2prompt -- product schema    # Schema → prompt generation showcase
moon run examples/json2schema                        # JSON → moon_zod schema code gen
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
- **WebAssembly-ready**: Mutable path stack for zero heap allocation on success path
- **Performance**: ~18.5k-56k validations/second depending on schema complexity

---

## Learn More

- [DESIGN.md](./DESIGN.md) for architecture, design decisions, and future directions.
- [CHANGELOG.md](./CHANGELOG.md) for release history.
- [中文 README](./README_zh.mbt.md) for Chinese documentation.
