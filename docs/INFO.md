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

---