## 演示：Schema → `schema_to_prompt()` → LLM → `schema.parse()`

**完整的 LLM 工具调用流程**，分四步进行，**零手写提示词**：

```
定义 Schema  →  schema_to_prompt()  →  输入 LLM  →  schema.parse()
   (MoonBit)        (自动生成              (模型          (自动校验
                     TS 接口)               响应)          + 清除额外字段)
```

```bash
python3 examples/real_llm_agent/agent.py product --mock --moon-prompt
```

> 无需 API 密钥 — Mock 模式模拟一个 2 轮自我纠正循环。
> 完整详情及实时 LLM 使用方式，请见 [`examples/real_llm_agent/README.md`](./examples/real_llm_agent/README.md)。

**发生的过程：**
1. `schemas.mbt` 定义产品列表 Schema（8 个字段，约束条件：最小/最大、正数、枚举、整数...）
2. `schema_to_prompt()` 自动生成 TypeScript 接口提示词，带有 `//` 约束注释 — **无需手工编写提示词**
3. LLM 接收提示词并返回 JSON（Mock 模拟一个错误 → 正确的重试）
4. `schema.parse()` 进行校验，**Strip 模式静默移除幻觉字段**

**输出示例：**
```text
Schema-to-Prompt (TS 接口)：              ← 由 schema_to_prompt() 自动生成
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

── 第 1 轮 ──────────────────────────────────

  调用 deepseek-ai/DeepSeek-V3.2...
  LLM 输出：
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

  使用 moon_zod (product) 进行校验...

  ✅ 校验通过  (Strip 模式激活)

  清理后的数据（幻觉字段已清除）：
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

  ✅ 自我纠正循环在 1 轮内完成

════════════════════════════════════════════════════════════
  状态：✅ 成功
  轮数：1
  清除：moon_zod 默认模式已移除额外字段
════════════════════════════════════════════════════════════
```

---

## 🔄 LLM 自我纠正示例

moon_zod 为**错误反馈循环**而设计 — 这是使 AI 智能体可靠的关键模式：

```mbt nocheck
///|
/// 重试循环：校验 → 收集错误 → 反馈 → 重试
fn call_llm_with_retry(schema : @moon_zod.Schema, times : Int) {
  var attempt = 0
  while attempt < times {
    let raw = llm_call(schema)  // LLM 返回 JSON
    match schema.parse(raw) {
      Ok(clean) => return clean   // Strip 模式移除幻觉字段
      Err(errors) => {
        // 格式化所有错误供纠正提示词使用
        var msg = "Fix these errors:\n"
        for e in errors {
          msg = msg + "  - \{e.path}: \{e.message}\n"
        }
        llm_feedback(msg)         // 将错误发送回去
      }
    }
    attempt = attempt + 1
  }
}
```

**不使用 moon_zod**：LLM 幻觉生成额外字段 → 数据损坏。LLM 犯多个错误 → 多次往返。

**使用 moon_zod**：Strip 模式清理幻觉。完整的错误收集在一次重试中修复所有错误。

参见 [`examples/llm_agent/`](./examples/llm_agent/) 获得完整可运行演示：
```
moon run examples/llm_agent
```

---

## 📦 模块化 Schema：`schema_to_prompt_named()` 用于复杂工具定义

对于**大型、深层嵌套的 Schema** 和**可复用类型定义**，使用 `schema_to_prompt_named()` 而非内联展开：

**内联方式**（阶段 16-17，`schema_to_prompt()`）：
```
User { Order { Product { ... } } }  →  全部内联展开  →  巨大的提示词
```

**模块化方式**（阶段 25+，`schema_to_prompt_named()`）：
```
User → 使用类型名称 `User`
Order → 使用类型名称 `Order`
Product → 使用类型名称 `Product`
```

然后 **LLM 仅看到它需要的定义**，减少 Token 计数并提高清晰度。

**使用示例：**
```mbt nocheck
// 定义命名 Schema
let user_schema = @moon_zod.object({ ... }).name("User")
let order_schema = @moon_zod.object({ ... }).name("Order")
let product_schema = @moon_zod.object({ ... }).name("Product")

// 自动提取 + 生成模块化提示词
let prompt = @moon_zod.schema_to_prompt_named(user_schema)
// 输出：
// export interface User { ... }
// export interface Order { ... }
// export interface Product { ... }
```

**优势**：
- ✅ 自动提取所有命名 Schema（无需手动列表维护）
- ✅ 拓扑排序确保定义先于引用
- ✅ 对象字段引用使用名称而非内联展开
- ✅ 循环引用检测防止无限循环
- ✅ 完美适用于 OpenAPI 风格的 Schema 文档