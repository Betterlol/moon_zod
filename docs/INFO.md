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
├── core/                     # Core schema validation library
│   ├── types.mbt             # ValidationError, SchemaResult, core types
│   ├── schema.mbt            # Schema struct, parse dispatch, path stack
│   ├── string.mbt            # string() factory + validators
│   ├── number.mbt            # number() factory + validators
│   ├── boolean.mbt           # boolean() factory
│   ├── null.mbt              # null() factory
│   ├── array.mbt             # array() factory + parse_array
│   ├── object.mbt            # object() + modes (strip/passthrough/strict), pick/omit/partial
│   ├── optional.mbt          # optional() factory
│   ├── default.mbt           # default() factory
│   ├── enum.mbt              # enum_values() factory
│   ├── literal.mbt           # literal() factory (constant values)
│   ├── union.mbt             # union() factory
│   ├── intersection.mbt      # intersection() / intersect()
│   ├── refine.mbt            # refine() for custom validation
│   ├── transform.mbt         # transform() for data transformation
│   ├── shared_utils.mbt      # Common utilities (unwrap_schema, peel_optional, etc.)
│   ├── constraint_extractor.mbt  # Extract constraint info from rules
│   └── moon_zod_wbtest.mbt   # White-box tests (path stack invariants)
│
├── exporters/                # Code/schema export tools
│   ├── prompt.mbt            # schema_to_prompt() / schema_to_prompt_named()
│   ├── prompt_renderer.mbt   # Trait-based prompt rendering
│   ├── json_schema.mbt       # to_json_schema() / to_json_schema_named()
│   ├── json_schema_renderer.mbt # Trait-based JSON Schema rendering
│   ├── moonbit_struct.mbt    # schema_to_moonbit_struct() + from_json() generation
│   ├── moonbit_renderer.mbt  # Trait-based MoonBit struct rendering
│   ├── schema_exporter.mbt   # Shared exporter utilities
│   └── reexporter.mbt        # Module re-exports
│
├── importers/                # Schema import tools
│   ├── from_json_schema.mbt  # json_schema_to_moon_zod() — reverse JSON Schema → moon_zod code generation
│   └── reexporter.mbt        # Module re-exports
│
├── tests/                    # Test suite (407 tests)
│   ├── test_string.mbt       # string() validator tests
│   ├── test_number.mbt       # number() validator tests
│   ├── test_boolean_null.mbt # boolean/null tests
│   ├── test_object.mbt       # object() mode tests
│   ├── test_array.mbt        # array() tests
│   ├── test_combinators.mbt  # union/literal/optional/default tests
│   ├── test_transform_refine.mbt # transform/refine tests
│   ├── test_json_schema.mbt  # JSON Schema export tests
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
│   ├── gen-struct/           # JSON → MoonBit struct + from_json() generator
│   └── validate/             # JSON schema validator (infer-then-validate)
│
└── examples/                 # LLM agent demonstrations
    ├── llm_agent/            # Basic LLM tool calling example
    ├── educational_agent/    # Multi-round self-correction demo
    ├── real_llm_agent/       # Real LLM integration (with API fallback to mock)
    ├── multiple_schemas/     # Handling multiple schemas
    └── schema2prompt/        # Schema → prompt generation showcase
```

---

## Development

```bash
# Testing & Building
moon test                # Run all tests (407 total, 0 warnings)
moon build               # Build the library
moon info && moon fmt    # Update interface + format

# CLI Tools
moon run cmd/main                                      # Run performance benchmarks
moon run cmd/json2schema -- '{"hello":"world"}'      # JSON → moon_zod schema code
moon run cmd/json2schema -- --from-json-schema '<{...}>'  # JSON Schema → moon_zod code
moon run cmd/gen-struct -- '{"name":"Alice"}'        # JSON → MoonBit struct + from_json()
moon run cmd/validate -- '{"name":"Alice"}' '{"name":"Bob"}'  # Validate JSON

# Examples
moon run examples/llm_agent                          # Basic LLM tool calling demo
moon run examples/real_llm_agent -- product prompt   # Real LLM with mock fallback
moon run examples/real_llm_agent -- product validate # Validate with real API
moon run examples/multiple_schemas                    # Multiple schema handling
```

---

## Features

- **Primitive schemas**: `string()`, `number()`, `boolean()`, `null()`
- **Compound schemas**: `object(Map)`, `array(Schema)`, `union(Array[Schema])`, `intersection(Array[Schema])`, `enum_values(Array[String])`, `literal(Json)`
- **String validators** (20+): `.min(n)`, `.max(n)`, `.nonempty()`, `.email()` (full RFC validation), `.url()` (full structure), `.regex(pattern)` (substring match), `.startsWith()`, `.endsWith()`, `.includes()`, `.uuid()`, `.cuid()`, `.ulid()`, `.datetime()`, `.ip()`/`.ipv4()`/`.ipv6()`, `.length(n)`
- **Number validators** (9+): `.int()`, `.positive()`, `.negative()`, `.multipleOf()`, `.finite()`, `.safe()`, `.min()`, `.max()`, `.length()`
- **Object modes**: `.strip()` (default, removes unknown fields), `.passthrough()` (keeps unknown fields), `.strict()` (rejects unknown fields)
- **Schema composition**: `.pick(keys)`, `.omit(keys)`, `.partial()` to derive object sub-schemas
- **Optional/Default handling**: `.optional()` and `.default(value)` with correct rule chaining through wrappers
- **Data transformation**: `.transform(fn)` validates then transforms
- **Custom rules**: `.refine(check, message)`, `.intersect(other)` for explicit intersection
- **Schema naming & description**: `.name(text)` for named exports, `.describe(text)` for human-readable descriptions in prompts
- **Custom error messages**: `msg?` parameter on all validators, `.message(text)` override method, type-level `.string(invalid_type_error="...", required_error="...")`
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
- **MoonBit struct generation** (Phase 28-29):
  - `schema_to_moonbit_struct(schema)` — generate MoonBit struct definitions
  - `schema_to_moonbit_struct_full(schema)` — generate struct + `from_json()` functions
  - `schema_to_moonbit_struct_named(schema)` / `schema_to_moonbit_struct_named_full(schema)` — handle nested named schemas
- **Zero external dependencies**: Only core MoonBit library (`@json`, `@debug`, etc.)
- **WebAssembly-ready**: Mutable path stack for zero heap allocation on success path
- **Performance**: ~18.5k-56k validations/second depending on schema complexity

---