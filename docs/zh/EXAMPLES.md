# 示例

moon_zod 包含多种示例，展示了不同的使用场景，从基本的 JSON 校验到完整的 LLM 工具调用自纠正循环。

## 快速概览

| 示例 | 描述 | 输出 |
|---|---|---|
| [json2schema](../../examples/json2schema/) | 在 MoonBit 中定义 Schema + 校验硬编码的 JSON | 打印 User、Post 和 GitHub API Schema 的校验结果 |
| [mock/llm_agent](../../examples/mock/llm_agent/) | 模拟的 LLM 自纠正循环（简单版） | 2 轮模拟：错误 JSON → 错误 → 修复后的 JSON → Strip 清理 |
| [mock/educational_agent](../../examples/mock/educational_agent/) | 模拟的 3 轮自纠正（深层版） | 3 轮：结构层 → 规则层 → Strip 防御层 |
| [multiple_schemas](../../examples/multiple_schemas/) | Schema 组合 + 多格式代码生成 | 输出 TS / JSON Schema / MoonBit struct / moon_zod 代码 |
| [real_llm_agent](../../examples/real_llm_agent/) | 端到端 Schema → Prompt → 真实 LLM → 解析 | 自纠正循环：校验 → 收集错误 → 重试 |
| [schema2json](../../examples/schema2json/) | moon_zod schema → JSON Schema 导出 | 包含完整约束的标准 JSON Schema |
| [schema2prompt](../../examples/schema2prompt/) | moon_zod schema → TS 接口 prompt | TypeScript 接口附带 `//` 约束注释 |
| [validate CLI](../../cmd/validate/) | JSON Schema → 校验 JSON | `PASS` / `FAIL` 附带错误详情 |
| [gen-struct CLI](../../cmd/gen-struct/) | JSON Schema → MoonBit struct 代码生成 | `pub struct` + `fn to_schema()` 定义 |
| [json2schema CLI](../../cmd/json2schema/) | JSON → moon_zod schema 代码生成 | 可直接复制粘贴的 `@moon_zod.object({...})` 代码 |

---

## json2schema

**路径：** [`examples/json2schema/`](../../examples/json2schema/) • [README](../../examples/json2schema/README.md)

一个可运行的 MoonBit 程序，定义现实的 Schema（JSONPlaceholder 用户、文章、GitHub Rust 仓库 API 响应），并针对这些 Schema 校验硬编码的 JSON。打印每个 Schema 的成功/失败状态。

```bash
$ sh cmd/json2schema/cli.sh --file examples/resources/test_placeholder_post.json
```

输出：
```moonbit nocheck
let root = @moon_zod.object({ "userId": @moon_zod.number().int(), "id": @moon_zod.number().int(), "title": @moon_zod.string(), "body": @moon_zod.string() }).name("Root")
```

---

## mock

**路径：** [`examples/mock/`](../../examples/mock/) • [README](../../examples/mock/README.md)

### mock/llm_agent

针对用户资料 Schema 的模拟自纠正循环。Mock LLM 首先返回无效的 JSON — moon_zod 收集所有错误。经过纠正反馈后，mock LLM 使用有效数据加上一个虚构字段重试。Strip 模式将其无声地移除。

```bash
$ moon run examples/mock/llm_agent
```

输出示例：
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

针对课程 Schema 的 3 轮模拟，展示 moon_zod 的三层防御：

| 轮次 | 防御层 | 结果 |
|---|---|---|
| 1 | 结构层 | 捕获错误的类型、无效的枚举 |
| 2 | 规则层 | 捕获最小值/最大值/正数违规 |
| 3 | Strip 层 | 移除 12 个虚构的元数据字段 |

```bash
$ moon run examples/mock/educational_agent
```

输出示例：
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

**路径：** [`examples/multiple_schemas/`](../../examples/multiple_schemas/) • [README](../../examples/multiple_schemas/README.md)

最全面的 Schema 组合示例。根据 CLI 参数输出不同的表示形式：

```bash
$ moon run examples/multiple_schemas -- ts       # TypeScript 接口 prompt
$ moon run examples/multiple_schemas -- json     # JSON Schema
$ moon run examples/multiple_schemas -- moonbit  # MoonBit struct 代码
$ moon run examples/multiple_schemas -- moon_zod # moon_zod 构建器代码
```

展示了 `.partial()`、`.omit()`、`.pick()`、`.extend_with()`、`.merge()`、`tuple`、`any`/`unknown`、`preprocess`、`transform`、`refine`、`union`、`intersection`、`literal`、`default` 等功能。

```bash
$ moon run examples/multiple_schemas -- ts
```

输出示例：
> 仅展示 `TypeScript Interface with Names`
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

**路径：** [`examples/real_llm_agent/`](../../examples/real_llm_agent/) • [README](../../examples/real_llm_agent/README.md)

完整的 Schema → Prompt → LLM → 解析闭环。两种模式：

- **Prompt 模式**：moon_zod 生成 TS 接口 prompt → LLM 返回 JSON → moon_zod 校验 + Strip
- **工具模式**：OpenAI 结构化输出 + moon_zod 作为第二层防御

```bash
# MoonBit prompt 模式（TS 接口风格）
$ python3 examples/real_llm_agent/agent.py product --moon-prompt

# 经典模式（JSON Schema 在 prompt 中）
$ python3 examples/real_llm_agent/agent.py product

# 工具调用模式（OpenAI 函数调用）
$ python3 examples/real_llm_agent/agent.py product --mode tool
```

```bash
python3 examples/real_llm_agent/agent.py product --moon-prompt
```

输出示例：
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

支持的场景：`product`、`movie`、`course_catalog`（嵌套式，会触发纠正）。

---

## schema2json

**路径：** [`examples/schema2json/`](../../examples/schema2json/) • [README](../../examples/schema2json/README.md)

将 moon_zod schema 导出为标准 JSON Schema，包含完整的约束注释：

```bash
$ moon run examples/schema2json -- product schema
```

输出示例：
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

**路径：** [`examples/schema2prompt/`](../../examples/schema2prompt/) • [README](../../examples/schema2prompt/README.md)

将 moon_zod schema 转换为 TypeScript 接口风格的 prompt 字符串，附带约束注释：

```bash
$ moon run examples/schema2prompt -- product prompt
```

输出示例：
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

**路径：** [`cmd/validate/`](../../cmd/validate/) • [README](../../examples/validate_cli/README.md)

基于 Shell 的 JSON 校验器。从样本推断 schema 或读取 JSON Schema，然后校验 JSON/JSONL 输入：

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

**路径：** [`cmd/gen-struct/`](../../cmd/gen-struct/) • [README](../../examples/gen-struct/README.md)

将 JSON Schema 转换为 MoonBit struct 定义及静态 `Type::to_schema()` 函数：

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

**路径：** [`cmd/json2schema/`](../../cmd/json2schema/) • [README](../../examples/json2schema/README.md)

从 JSON 样本推断 moon_zod schema，或从 JSON Schema 反向导入：

```bash
$ sh cmd/json2schema/cli.sh '{"name":"Alice","age":30}'
```

```moonbit nocheck
let root = @moon_zod.object({ "name": @moon_zod.string(), "age": @moon_zod.number().int() }).name("Root")
```

---

## 另见

- [API 参考](./API.md) — 详细的 API 文档
- [CLI 参考](./CLI.md) — 命令行使用说明
- [性能基准](./BENCHMARK.md) — 性能对比
    