# 演示：Schema → `schema_to_prompt()` → LLM → `schema.parse()`

**完整的 LLM 工具调用管道**分四步实现，**零手写提示词**：

```
define Schema  →  schema_to_prompt()  →  feed to LLM  →  schema.parse()
   (MoonBit)        (auto-generated         (model         (auto-validate
                     TS interface)           response)      + strip extra fields)
```

```bash
python3 examples/real_llm_agent/agent.py product --mock --moon-prompt
```

> 无需 API 密钥 — 模拟模式模拟 2 轮自我修正循环。
> 详细信息和实时 LLM 使用，请参阅 [`examples/real_llm_agent/README.md`](./examples/real_llm_agent/README.md)。

**执行流程：**
1. `schemas.mbt` 定义产品列表 Schema（8 个字段，约束：最小/最大值、正数、枚举、整数等）
2. `schema_to_prompt()` 自动生成带有 `//` 约束注释的 TypeScript 接口提示词 — **无需手工编写提示词**
3. LLM 接收提示词并返回 JSON（模拟显示错误 → 正确的重试过程）
4. `schema.parse()` 进行校验，**Strip 模式静默移除幻觉字段**

**输出摘录：**
```text
Schema-to-Prompt (TS interface):         ← schema_to_prompt() 自动生成
  {
    name: string,  // 3-100 chars
    description: string,  // 10-500 chars
    price: number,  // positive
    currency: "USD" | "EUR" | "GBP" | "JPY" | "CNY",
    category: "electronics" | "clothing" | "food" | "books" | "other",
    tags: string[],  // min: 1
    stock: number,  // int, min: 0
    metadata?: {
      brand: string,  // min: 1
      weight_kg: number,  // positive
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

## 🔄 LLM 自我修正示例

moon_zod 为**错误反馈循环**设计 — 这是让 AI 代理可靠的关键模式：

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

**不使用 moon_zod**：LLM 产生幻觉字段 → 数据损坏。LLM 犯多个错误 → 多次往返。

**使用 moon_zod**：Strip 模式清理幻觉。完整错误收集在一次重试中修复所有错误。

参见 [`examples/llm_agent/`](./examples/llm_agent/) 获取完整可运行演示：
```
moon run examples/llm_agent
```

---

## 📦 模块化 Schemas：`schema_to_prompt_named()` 用于复杂工具定义

对于**大型、深层嵌套的 Schema** 和**可复用的类型定义**，使用 `schema_to_prompt_named()` 而非内联展开：

**内联方法**（第 16-17 阶段，`schema_to_prompt()`）：
```
User { Order { Product { ... } } }  →  expand all inline  →  HUGE prompt
```

**模块化方法**（第 25+ 阶段，`schema_to_prompt_named()`）：
```
User → uses type name `User`
Order → uses type name `Order`
Product → uses type name `Product`
```

然后 **LLM 只看到需要的定义**，减少令牌计数并提高清晰度。

**使用示例：**
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

**优势**：
- ✅ 自动提取所有命名 Schema（无需手动维护列表）
- ✅ 拓扑排序确保定义在引用之前
- ✅ 对象字段引用使用名称而非内联展开
- ✅ 循环引用检测防止无限循环
- ✅ 完美适用于 OpenAPI 风格的 Schema 文档