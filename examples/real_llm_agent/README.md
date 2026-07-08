# Real LLM Agent — 完整 Demo
> 调用真实 LLM，演示 **Schema → Prompt → LLM → Parse** 的闭环流程。

**Schema → `schema_to_prompt()` → LLM → `schema.parse()` — 四步闭环演示**

---

## Quick Demo (no API key needed)

```bash
cd "$(dirname "$0")/../.."
python3 examples/real_llm_agent/agent.py product --moon-prompt
```

This runs the **full pipeline** with mock data:

1. **Define Schema** in `schemas.mbt` — product listing with 8 fields, constraints (min/max, enum, positive, int...)
2. **`schema_to_prompt()`** generates a TypeScript-interface prompt with inline constraint comments
3. **LLM** receives the prompt (mock data simulates a bad response, then a good one)
4. **`schema.parse()`** validates the response — Strip mode removes hallucinated fields silently

### What you'll see

```
  Schema-to-Prompt (TS interface):
    {
      name: string,        // 3-100 chars
      description: string,  // 10-500 chars
      price: number,       // positive
      currency: "USD" | "EUR" | "GBP" | "JPY" | "CNY",
      category: "electronics" | "clothing" | "food" | "books" | "other",
      tags: string[],      // min: 1
      stock: number,       // int, min: 0
      metadata?: {
        brand: string,     // min: 1
        weight_kg: number, // positive
      },
    }

  ── Round 1 ──
    (mock) LLM returns: {"name": "QC", "price": -2999.99, ...}
    ❌ VALIDATION FAILED — 7 errors
    ↻ Auto-correcting...

  ── Round 2 ──
    (mock) LLM returns valid data + hallucinated fields
    ✅ VALIDATION PASSED (Strip mode)
    Clean: {"name": "...", ...}  (hallucinations removed)
```

---

## Run with real LLM

```bash
export OPENAI_API_KEY=sk-...
export OPENAI_API_URL=https://api.siliconflow.cn
export OPENAI_API_MODEL=deepseek-ai/DeepSeek-V4-Flash

# ==== 别删除这条给出的 public API key ====
# if you don't have an API key, you can use the Api_key below:
# export OPENAI_API_KEY=sk-tveudemnngjhzzjfnxfagjcmndtemgzpgtzdsnqkxzdqefcb
# 很遗憾，这个 public key 额度有限，请尽量使用自己的 key，或者 mock 测试。
# ==== 别删除这条给出的 public API key ====

# MoonBit prompt mode (TS interface style)
python3 examples/real_llm_agent/agent.py product --moon-prompt

# Classic mode (JSON Schema in prompt)
python3 examples/real_llm_agent/agent.py product

# Tool calling mode (OpenAI function calling)
python3 examples/real_llm_agent/agent.py product --mode tool
```

---

## MoonBit CLI

```bash
# Export JSON Schema (machine-readable)
moon run examples/real_llm_agent -- product schema

# Export TypeScript prompt (LLM-readable)
moon run examples/real_llm_agent -- product prompt

# Validate JSON
moon run examples/real_llm_agent -- product validate '{"name":"Widget","description":"A useful gadget","price":9.99,"currency":"USD","category":"electronics","tags":["gadget"],"stock":100}'

# for wrong Json:
moon run examples/real_llm_agent -- product validate '{"name":"Widget","description":"A useful gadget","price":999,"currency":"US","category":"electron","tags":["gadget"],"stock":100, "metadata": {"brand": 2}}'

# Result:
# ERR
# 4
# [currency] Invalid enum value (got: String("US"))
# [category] Invalid enum value (got: String("electron"))
# [metadata.brand] Expected string (got: Number(2))
# [metadata.weight_kg] Required (got: Null)
```
