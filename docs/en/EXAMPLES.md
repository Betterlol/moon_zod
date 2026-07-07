# Examples

moon_zod ships with a variety of examples demonstrating different use cases, from basic JSON validation to full LLM tool-calling self-correction loops.

## Quick Overview

| Example | Description | Output |
|---|---|---|
| [json2schema](../../examples/json2schema/) | Define schemas in MoonBit + validate hardcoded JSON | Prints validation results for User, Post, and GitHub API schemas |
| [mock/llm_agent](../../examples/mock/llm_agent/) | Simulated LLM self-correction loop (simple) | 2-round mock: bad JSON → errors → fixed JSON → Strip cleanse |
| [mock/educational_agent](../../examples/mock/educational_agent/) | Simulated 3-round self-correction (deep) | 3 rounds: structural → rule → Strip defense layers |
| [multiple_schemas](../../examples/multiple_schemas/) | Schema composition + multi-format code gen | Outputs TS / JSON Schema / MoonBit struct / moon_zod code |
| [real_llm_agent](../../examples/real_llm_agent/) | End-to-end Schema → Prompt → Real LLM → Parse | Self-correction loop: validate → collect errors → retry |
| [schema2json](../../examples/schema2json/) | moon_zod schema → JSON Schema export | Standard JSON Schema with full constraints |
| [schema2prompt](../../examples/schema2prompt/) | moon_zod schema → TS interface prompt | TypeScript interface with `//` constraint comments |
| [validate CLI](../../cmd/validate/) | JSON Schema → validate JSON | `PASS` / `FAIL` with error details |
| [gen-struct CLI](../../cmd/gen-struct/) | JSON Schema → MoonBit struct code gen | `pub struct` + `fn to_schema()` definitions |
| [json2schema CLI](../../cmd/json2schema/) | JSON → moon_zod schema code gen | Copy-paste ready `@moon_zod.object({...})` code |

---

## json2schema

**Path:** [`examples/json2schema/`](../../examples/json2schema/) • [README](../../examples/json2schema/README.md)

A runnable MoonBit program that defines realistic schemas (JSONPlaceholder user, post, GitHub Rust repo API response) and validates hardcoded JSON against them. Prints success/failure for each schema.

```bash
$ sh cmd/json2schema/cli.sh --file examples/resources/test_placeholder_post.json
```

Output:
```moonbit nocheck
let root = @moon_zod.object({ "userId": @moon_zod.number().int(), "id": @moon_zod.number().int(), "title": @moon_zod.string(), "body": @moon_zod.string() }).name("Root")
```

---

## mock

**Path:** [`examples/mock/`](../../examples/mock/) • [README](../../examples/mock/README.md)

### mock/llm_agent

Simulated self-correction loop for a user-profile schema. Mock LLM first returns invalid JSON — moon_zod collects all errors. After correction feedback, mock LLM retries with valid data plus a hallucinated field. Strip mode silently removes it.

```bash
$ moon run examples/mock/llm_agent
```

Output be like:
```text
── Round 1 ──────────────────────────
  Mock LLM output (bad): { "name": 123, "role": "superadmin" }
  Errors:
    [name] Expected string (got: 123)
    [role] Invalid enum value (got: "superadmin")
── Round 2 ──────────────────────────
  Mock LLM output (fixed + hallucination): { "name": "Alice", "role": "admin", "hacked": true }
  ✅ VALIDATION PASSED (Strip mode: "hacked" removed)
```

### mock/educational_agent

3-round simulation for a course schema, demonstrating moon_zod's three-layer defense:

| Round | Defense | Result |
|---|---|---|
| 1 | Structural | Catches wrong types, invalid enum |
| 2 | Rule | Catches min/max/positive violations |
| 3 | Strip | Removes 12 hallucinated metadata fields |

```bash
$ moon run examples/mock/educational_agent
```

Output be like:
```text
── Round 1 ──────────────────────────
  [lessons] Expected array (got: "not-an-array")
── Round 2 ──────────────────────────
  [title] String must contain at least 10 character(s)
  [lessons[0].duration_minutes] Value must be positive
── Round 3 ──────────────────────────
  ✅ VALIDATION PASSED (12 extra fields stripped)
```

---

## multiple_schemas

**Path:** [`examples/multiple_schemas/`](../../examples/multiple_schemas/) • [README](../../examples/multiple_schemas/README.md)

The most comprehensive schema composition example. Outputs different representations based on CLI argument:

```bash
$ moon run examples/multiple_schemas -- ts       # TypeScript interface prompt
$ moon run examples/multiple_schemas -- json     # JSON Schema
$ moon run examples/multiple_schemas -- moonbit  # MoonBit struct code
$ moon run examples/multiple_schemas -- moon_zod # moon_zod builder code
```

Demonstrates `.partial()`, `.omit()`, `.pick()`, `.extend_with()`, `.merge()`, `tuple`, `any`/`unknown`, `preprocess`, `transform`, `refine`, `union`, `intersection`, `literal`, `default`, and more.

```bash
$ moon run examples/multiple_schemas -- ts
```

Output be like:
> show only `TypeScript Interface with Names`
```typescript
export interface User {
  name: string,  // [2-50 chars] — The user's display name, 2-50 characters
  age: number,  // [int, 0-150]
}

export type ProductMetadata = {
  description?: string,  // [max: 2000]
  images: string[],  // [max: 10 items, url] — Product image URLs
} | null

export interface Product {
  name: string,  // [min: 1, product name cannot be 'invalid'] — Product display name
  price: number,  // [positive] — Price in dollars
  currency?: string,  // [String must contain exactly 3 character(s)] — ISO 4217 currency code
  in_stock?: boolean,  // Whether the product is currently in stock
  metadata?: ProductMetadata,
}

type OrderStatus = "pending" | "shipped" | "delivered" | "cancelled"

export interface HomeAddress {
  type: "home",
  street: string,  // [min: 1]
  city: string,  // [min: 1]
}

export interface OfficeAddress {
  type: "office",
  company: string,  // [min: 1]
}

export type Address = HomeAddress | OfficeAddress

export type OrderId = {
  id: number,  // [int, positive]
} & {
  id: number,  // [int, max: 100]
}

export interface DateTime {
  created_at: string,  // [date-time] — The time the order was created
  updated_at: string,  // [date-time] — The last time the order was updated
}

export type OrderInfo = OrderId & DateTime

export interface ShippingInfo {
  address: Address,
  tracking_number?: string,  // Tracking number, available after shipment
  estimated_days?: number,  // [int, 1-30] — Estimated delivery days
  gift_wrap?: boolean,  // Whether to gift wrap the order
  special_instructions?: string,  // Any special delivery instructions
}

export type ReviewScore = number | null  // [int, positive] — Rating from 1 to 5

export type PreprocessTransformSchema = string | null

export type Tuple = [string, number, boolean] | null

export interface Order {
  user: User,
  product: Product,
  status: OrderStatus,  // The status of an order
  quantity?: number,  // [int, positive] — Number of items ordered
  address: Address,
  info: OrderInfo,
  shipping: ShippingInfo,
  review_score?: ReviewScore,  // [int, positive] — Rating from 1 to 5
  notes?: string,  // Optional order notes
  is_priority?: boolean,  // Whether this is a priority order
  coupon_code?: string,  // Optional coupon code
  preprocessed_field?: PreprocessTransformSchema,
  tuple_field?: Tuple,
}
```

---

## real_llm_agent

**Path:** [`examples/real_llm_agent/`](../../examples/real_llm_agent/) • [README](../../examples/real_llm_agent/README.md)

The full Schema → Prompt → LLM → Parse closed-loop. Two modes:

- **Prompt mode**: moon_zod generates TS interface prompt → LLM returns JSON → moon_zod validates + strips
- **Tool mode**: OpenAI structured outputs + moon_zod as second-layer defense

```bash
# MoonBit prompt mode (TS interface style)
$ python3 examples/real_llm_agent/agent.py product --moon-prompt

# Classic mode (JSON Schema in prompt)
$ python3 examples/real_llm_agent/agent.py product

# Tool calling mode (OpenAI function calling)
$ python3 examples/real_llm_agent/agent.py product --mode tool
```

```bash
python3 examples/real_llm_agent/agent.py product --moon-prompt
```

Output be like:
```text
  Fetching schema for 'product'...
  Schema loaded (8 fields)

  user prompt:
  Generate a product listing in JSON format for:
  "Quantum Computing Starter Kit"
  
  Expected type:
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
        "description": "A comprehensive introduction to quantum computing with educational materials, simulation software, and theoretical guides. Perfect for beginners interested in quantum algorithms, superposition, and entanglement concepts.",
        "price": 189.99,
        "currency": "USD",
        "category": "electronics",
        "tags": ["quantum", "educational", "electronics", "simulation", "beginner"],
        "stock": 45,
        "metadata": {
            "brand": "QuantumLabs",
            "weight_kg": 2.5
        }
    }

  Validating with moon_zod (product)...

  ✅ VALIDATION PASSED  (Strip mode active)

  Clean data (hallucinations stripped):
    Object(
      {
        "name": String("Quantum Computing Starter Kit"),
        "description": String("A comprehensive introduction to quantum computing with educational materials, simulation software, and theoretical guides. Perfect forbeginners interested in quantum algorithms, superposition, and entanglement concepts."),
        "price": Number(189.99),
        "currency": String("USD"),
        "category": String("electronics"),
        "tags": Array(
          [
            String("quantum"),
            String("educational"),
            String("electronics"),
            String("simulation"),
            String("beginner"),
          ],
        ),
        "stock": Number(45),
        "metadata": Object({ "brand": String("QuantumLabs"), "weight_kg": Number(2.5) }),
      },
    )

  ✅ Self-correction loop completed in 1 round(s)
════════════════════════════════════════════════════════════
  Status: ✅ Success
  Rounds: 1
  Strip:  Extra fields removed by moon_zod default mode
════════════════════════════════════════════════════════════
```

Supports cases: `product`, `movie`, `course_catalog` (nested, triggers correction).

---

## schema2json

**Path:** [`examples/schema2json/`](../../examples/schema2json/) • [README](../../examples/schema2json/README.md)

Exports a moon_zod schema as standard JSON Schema with full constraint annotations:

```bash
$ moon run examples/schema2json -- product schema
```

Output be like:
```json
{
  "type": "object",
  "properties": {
    "name": {
      "type": "string",
      "minLength": 3,
      "maxLength": 100
    },
    "description": {
      "type": "string",
      "minLength": 10,
      "maxLength": 500
    },
    "price": {
      "type": "number",
      "exclusiveMinimum": 0
    },
    "currency": {
      "type": "string",
      "enum": [
        "USD",
        "EUR",
        "GBP",
        "JPY",
        "CNY"
      ]
    },
    "category": {
      "type": "string",
      "enum": [
        "electronics",
        "clothing",
        "food",
        "books",
        "other"
      ]
    },
    "tags": {
      "type": "array",
      "items": {
        "type": "string",
        "minLength": 1
      }
    },
    "stock": {
      "type": "integer",
      "minimum": 0
    },
    "metadata": {
      "anyOf": [
        {
          "type": "object",
          "properties": {
            "brand": {
              "type": "string",
              "minLength": 1
            },
            "weight_kg": {
              "type": "number",
              "exclusiveMinimum": 0
            }
          },
          "additionalProperties": false,
          "required": [
            "brand",
            "weight_kg"
          ]
        },
        {
          "type": "null"
        }
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "name",
    "description",
    "price",
    "currency",
    "category",
    "tags",
    "stock"
  ]
}
```

---

## schema2prompt

**Path:** [`examples/schema2prompt/`](../../examples/schema2prompt/) • [README](../../examples/schema2prompt/README.md)

Converts a moon_zod schema into a TypeScript-interface prompt string with constraint comments:

```bash
$ moon run examples/schema2prompt -- product prompt
```

Output be like:
```typescript
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
```

---

## validate CLI

**Path:** [`cmd/validate/`](../../cmd/validate/) • [README](../../examples/validate_cli/README.md)

Shell-based JSON validator. Infers schema from sample or reads JSON Schema, then validates JSON/JSONL input:

```bash
$ sh cmd/validate/cli.sh '{"name":"Alice"}' '{"name":"Bob"}'
```

```text
Schema: let root = @moon_zod.object({ "name": @moon_zod.string() }).name("Root")
PASS
```

```bash
$ sh cmd/validate/cli.sh '{"name":"Alice"}' '{"age":30}'
```

```text
Schema: let root = @moon_zod.object({ "name": @moon_zod.string() }).name("Root")
FAIL
  [name] Required (got: Null)
```

---

## gen-struct CLI

**Path:** [`cmd/gen-struct/`](../../cmd/gen-struct/) • [README](../../examples/gen-struct/README.md)

Converts JSON Schema into MoonBit struct definitions plus static `Type::to_schema()` functions:

```bash
$ sh cmd/gen-struct/cli.sh --from-json-schema '{"type":"object","properties":{"name":{"type":"string"},"age":{"type":"integer"}}}'
```

```moonbit nocheck
pub struct Root {
  name : String?
  age : Int64?  // int
} derive(ToJson, FromJson)

pub fn Root::to_schema() -> @moon_zod.Schema {
  let root = @moon_zod.object({ "name": @moon_zod.string().optional(), "age": @moon_zod.number().int().optional() }).name("Root")
  root
}
```

---

## json2schema CLI

**Path:** [`cmd/json2schema/`](../../cmd/json2schema/) • [README](../../examples/json2schema/README.md)

Infers a moon_zod schema from JSON, or reverse-imports from JSON Schema:

```bash
$ sh cmd/json2schema/cli.sh '{"name":"Alice","age":30}'
```

```moonbit nocheck
let root = @moon_zod.object({ "name": @moon_zod.string(), "age": @moon_zod.number().int() }).name("Root")
```

---

## See Also

- [API Reference](./API.md) for detailed API documentation
- [CLI Reference](./CLI.md) for command-line usage
- [Benchmark](./BENCHMARK.md) for performance comparison
