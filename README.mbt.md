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
moon run examples/schema2prompt                      # Schema → prompt generation showcase
moon run examples/json2schema                        # JSON → moon_zod schema code gen
```

---

## Features

- **Primitive schemas**: `string()`, `number()`, `boolean()`, `null()`, `bigint()`
- **Compound schemas**: `object(Map)`, `array(Schema)`, `tuple([Schema...])`, `union(Array[Schema])`, `intersection(Array[Schema])`, `enum_values(Array[String])`, `literal(Json)`
- **Pass-through schemas**: `any()` and `unknown()` accept any JSON value (semantic distinction)
- **String validators** (23+): `.min(n)`, `.max(n)`, `.nonempty()`, `.trim()`, `.to_lower()`, `.to_upper()`, `.email()` (full RFC validation), `.url()` (full structure), `.regex(pattern)` (substring match), `.startsWith()`, `.endsWith()`, `.includes()`, `.uuid()`, `.cuid()`, `.ulid()`, `.datetime()`, `.ip()`/`.ipv4()`/`.ipv6()`, `.length(n)`
- **Number validators** (8+): `.int()`, `.positive()`, `.negative()`, `.multipleOf()`, `.finite()`, `.safe()`, `.min()`, `.max()`
- **Object modes**: `.strip()` (default, removes unknown fields), `.passthrough()` (keeps unknown fields), `.strict()` (rejects unknown fields)
- **Object composition**: `.pick(keys)`, `.omit(keys)`, `.partial()`, `.extend(Map)`, `.merge(Schema)`
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
- **Zero external dependencies**: Only core MoonBit library (`@json`, `@debug`, etc.)
- **WebAssembly-ready**: Mutable path stack for zero heap allocation on success path
- **Performance**: ~18.5k-56k validations/second depending on schema complexity

---

## API Reference

### Factory Functions

| Function | Description |
|---|---|
| `string(required_error?, invalid_type_error?)` | Validates JSON strings |
| `number(required_error?, invalid_type_error?)` | Validates JSON numbers |
| `boolean(required_error?, invalid_type_error?)` | Validates JSON booleans |
| `null(required_error?, invalid_type_error?)` | Validates JSON null |
| `array(Schema, required_error?, invalid_type_error?)` | Validates arrays, recursively checking elements |
| `tuple([Schema...], required_error?, invalid_type_error?)` | **Phase 38**: Fixed-length array — validates each element by position |
| `object(Map[String, Schema], required_error?, invalid_type_error?)` | Validates objects. **Default: Strip mode** |
| `enum_values(Array[String], required_error?, invalid_type_error?)` | Fixed set of allowed string values |
| `literal(Json, required_error?, invalid_type_error?)` | **Phase 32**: Constant value validation — only accepts exact JSON match |
| `bigint(required_error?, invalid_type_error?)` | **Phase 37**: Semantic alias for `number().int()` — expresses big integer intent, need to truly implement |
| `any(required_error?, invalid_type_error?)` | **Phase 39**: Accepts any JSON value (pass-through) |
| `unknown(required_error?, invalid_type_error?)` | **Phase 39**: Accepts any JSON value as unknown (semantic marker) |
| `preprocess((Json) -> Result[Json, String], Schema, required_error?, invalid_type_error?)` | **Phase 39**: Transform raw input first, then validate against inner schema |
| `union(Array[Schema], required_error?, invalid_type_error?)` | Union type — passes if any schema matches |
| `intersection(Array[Schema], required_error?, invalid_type_error?)` | **Phase 18**: Intersection — passes if all schemas match; object fields are merged |

### Schema Methods

| Method | Applies To | Description |
|---|---|---|
| `.parse(Json, path?)` | All | Validate, returns `Ok(Json)` or `Err(Array[ValidationError])` |
| `.min(n[, msg])` | string / number / array | Minimum length / value |
| `.max(n[, msg])` | string / number / array | Maximum length / value |
| `.length(n[, msg])` | string / array / tuple | Exact length |
| `.nonempty([msg])` | string / array / tuple | Must not be empty |
| `.email([msg])` | string | Full email validation |
| `.url([msg])` | string | Full URL structure |
| `.regex(pattern[, msg])` | string | Must contain `pattern` as substring |
| `.startsWith(prefix[, msg])` | string | Must start with `prefix` |
| `.endsWith(suffix[, msg])` | string | Must end with `suffix` |
| `.includes(substring[, msg])` | string | Must contain `substring` |
| `.trim()` | string | **Phase 37**: Remove leading/trailing whitespace |
| `.to_lower()` | string | **Phase 37**: Convert to lowercase |
| `.to_upper()` | string | **Phase 37**: Convert to uppercase |
| `.uuid([msg])` | string | Must be a valid UUID v4 |
| `.cuid([msg])` | string | Must be a valid CUID |
| `.datetime([msg])` | string | Must be ISO 8601 datetime |
| `.ip([msg])` | string | Must be valid IPv4 or IPv6 |
| `.ipv4([msg])` | string | Must be valid IPv4 |
| `.ipv6([msg])` | string | Must be valid IPv6 |
| `.ulid([msg])` | string | Must be valid ULID |
| `.int([msg])` | number | Must be integer |
| `.positive([msg])` | number | Must be > 0 |
| `.negative([msg])` | number | Must be < 0 |
| `.multipleOf(n[, msg])` | number | Must be multiple of `n` |
| `.finite([msg])` | number | Must be finite |
| `.safe([msg])` | number | Must be a safe integer |
| `.optional()` | any | Null or missing values skip validation |
| `.default(value)` | any | Replace null with default |
| `.strict()` | object | Reject undefined fields |
| `.passthrough()` | object | Keep undefined fields as-is |
| `.strip()` | object | Silently remove undefined fields (default) |
| `.pick(keys)` | object | **Phase 21**: Select only specified fields |
| `.omit(keys)` | object | **Phase 21**: Remove specified fields |
| `.partial()` | object | **Phase 21**: Make all fields optional |
| `.extend(Map[String, Schema])` | object | **Phase 38**: Add or override fields from a Map |
| `.merge(Schema)` | object | **Phase 38**: Merge with another object schema (right side overrides) |
| `.describe(text)` | any | **Phase 17**: Attach description for LLM prompts |
| `.name(text)` | any | **Phase 25**: Assign a name for schema exports |
| `.brand(text)` | any | **Phase 37**: Assign a brand marker for nominal typing |
| `.message(text)` | any | **Phase 19**: Override the last rule's error message |
| `.intersect(other)` | any | **Phase 18**: Intersection — input must match both schemas |
| `.refine(check, msg)` | any | Custom validation predicate |
| `.transform(fn)` | any | **Phase 13**: Validate then transform output |

### Standalone Functions

| Function | Description |
|---|---|
| `schema_to_prompt(Schema)` | **Phase 16**: Generate TypeScript-interface prompt string for LLM — inline expansion |
| `schema_to_prompt_named(Schema, include_names?)` | **Phase 25, 34**: Generate modular TypeScript interfaces from named schemas |
| `to_json_schema(Schema)` | **Phase 15**: Export standard JSON Schema with full constraint annotations |
| `to_json_schema_skeleton(Schema)` | **Phase 15**: Export lightweight JSON Schema skeleton (structure only) |
| `to_json_schema_named(Schema, include_names?)` | **Phase 26, 34**: Export named schemas as `$defs` with `$ref` |
| `json_schema_to_moon_zod(Json)` | **Phase 27, 36**: Reverse-generate moon_zod code from JSON Schema |
| `schema_to_moonbit_struct(Schema)` | Generate MoonBit struct/enum definitions for every object/enum schema |
| `schema_to_moonbit_struct_full(Schema)` | Generate definitions plus static `Type::to_schema()` functions |
| `schema_to_moon_zod_code(Schema)` | Generate moon_zod schema source code |
| `schema_to_moon_zod_code_named(Schema, include_names?)` | Generate moon_zod code with `$defs` and `$ref` |
| `json_schema_to_schema(Json)` | Reverse-parse JSON Schema into a moon_zod Schema |
| `json_infer_schema(Json)` | Infer a moon_zod Schema from a sample JSON value |
| `append_rule(Schema, (Json) -> Bool, String)` | Append a raw validation rule |
| `append_rule_with_annotation(Schema, (Json) -> Bool, String, Json)` | Append a rule with annotation payload |
| `format_path(Array[String])` | Join path stack to dot-notation string |
| `ValidationError::to_string()` | Format error as `[path] message (got: value)` |

### Core Types

```moonbit nocheck
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

### JSON-to-Schema Generator (CLI)

Generate `@moon_zod` schema code instantly from any JSON payload — no need to write schemas by hand for real-world API data.

```bash
moon run cmd/json2schema -- '{"hello": "world"}'
```

Output (copy-paste ready moon_zod code):

```moonbit nocheck
@moon_zod.object({
  "hello": @moon_zod.string(),
})
```

For verbose output with debug information:
```bash
moon run cmd/json2schema -- --verbose '{"hello": "world"}'
```

The generator recursively infers types (`string`, `number`, `boolean`, `null`, `array`, `object`) and safely escapes special characters in object keys. Empty arrays produce a `/* TODO: specify exact type */` comment to alert you when type inference lacked data.

---

### JSON Schema Reverse Importer (CLI)

Generate `@moon_zod` schema code from a standard **JSON Schema (draft-07)** definition — the inverse of `to_json_schema()`.

**Inline mode** (JSON Schema as command argument):
```bash
moon run cmd/json2schema -- --from-json-schema '{
  "type": "object",
  "properties": {
    "name": {"type": "string", "minLength": 2},
    "age": {"type": "integer", "minimum": 0, "maximum": 150}
  },
  "required": ["name", "age"]
}'
```

**File mode** (read JSON Schema from file):
```bash
moon run cmd/json2schema -- --from-json-schema --schema-file schema.json
```

Output:

```moonbit nocheck
@moon_zod.object({
  "name": @moon_zod.string().min(2),
  "age": @moon_zod.number().int().min(0).max(150),
})
```

**Features**:
- Converts all JSON Schema types (string, number, integer, boolean, null, array, object)
- Extracts constraints: `minLength`, `maxLength`, `minimum`, `maximum`, `exclusiveMinimum`, `exclusiveMaximum`, `multipleOf`, `pattern`, `format` (email, uri, date-time, ipv4, ipv6, uuid)
- Handles `$defs` and `$ref` references — generates separate named schema declarations
- Supports `enum`, `oneOf`, `anyOf`, `allOf`
- Fields not in `required` auto-wrapped with `.optional()`
- Outputs **copy-paste-ready MoonBit source code**
- Full support for Phase 36 semantics: `exclusiveMinimum`/`exclusiveMaximum` generate `.positive()`/`.negative()` where applicable

---

### MoonBit Struct Generator (CLI)

Generate MoonBit struct definitions from any JSON Schema — struct definitions + static `Type::to_schema()` functions.

```bash
moon run cmd/gen-struct -- --schema '{"type":"object","properties":{"name":{"type":"string"},"age":{"type":"integer"}},"required":["name","age"]}'
```

Output:

```moonbit nocheck
///|
pub struct Root {
  name : String
  age : Int64 // int
} derive(ToJson, FromJson)

///|
pub fn Root::to_schema() -> @moon_zod.Schema {
  let root = @moon_zod.object({
    "name": @moon_zod.string(),
    "age": @moon_zod.number().int(),
  }).name("Root")
  root
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

# File mode (JSON Schema as schema source)
moon run cmd/validate -- --schema-file schema.json --sample-file data.json
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

```moonbit nocheck
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
```moonbit nocheck
// Define named schemas

///|
let user_schema = @moon_zod.object(
  {
    ...
  },
).name("User")

///|
let order_schema = @moon_zod.object(
  {
    ...
  },
).name("Order")

///|
let product_schema = @moon_zod.object(
  {
    ...
  },
).name("Product")

// Auto-extract + generate modular prompt

///|
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
