# moon_zod

> 🌐 [English README](./README.mbt.md)

MoonBit 运行时 JSON Schema 校验库，受 [Zod](https://zod.dev) 和 [Pydantic](https://docs.pydantic.dev) 启发。

**专为 LLM Tool Calling 设计** — 对大语言模型的结构化 JSON 输出进行运行时校验，提供精确的错误报告与自修正支持。

---

## ✨ 为什么选择 MoonZod？（AI 优先）

| 特性 | moon_zod | 传统校验库 |
|---|---|---|
| **错误收集** | 一次遍历收集 **所有** 错误 | 多数库遇第一个错误就中止 |
| **幻觉防御** | 默认 **Strip** 模式静默移除未知字段 | 会放行幻觉数据 |
| **JSON Schema 导出** | `to_json_schema()` 为 LLM API 生成标准 Schema | 需手动维护 Schema |
| **路径精度** | 每个错误包含精确字段路径（`users[0].profile.age`） | 通常只有扁平消息 |
| **Wasm 就绪** | 可变路径栈 — 成功路径零堆分配 | 每次 parse 都做字符串分配 |

在 LLM Tool Calling 场景中，模型经常**一次产生多个错误**并**幻觉出多余字段**。moon_zod 一次性收集所有错误（可全部发回给 LLM 自修正），默认 Strip 模式清除未知字段（幻觉键不会无声污染数据）。

---

## 🚀 快速开始

```mbt nocheck
let schema = @moon_zod.object({
  "name": @moon_zod.string().min(2).max(50),
  "age": @moon_zod.number().int().min(0).max(150),
  "email": @moon_zod.string().email(),
})

match schema.parse(input_json) {
  Ok(valid) => // 使用清洗后的数据
  Err(errors) => // 将所有错误反馈给 LLM
}
```

---

##  Demo: Schema → `schema_to_prompt()` → LLM → `schema.parse()`

**完整的 LLM Tool Calling 管线**，四步完成，**无需手写 prompt**：

```
定义 Schema  →  schema_to_prompt()  →  喂给 LLM  →  schema.parse()
   (MoonBit)       (自动生成          (模型响应      (自动校验
                    TS 接口)                            + Strip 清洗)
```

```bash
python3 examples/real_llm_agent/agent.py product --mock --moon-prompt
```

> 无需 API Key — Mock 模式模拟两轮自修正循环。
> 完整细节和真实 LLM 用法见 [`examples/real_llm_agent/README.md`](./examples/real_llm_agent/README.md)。

**执行过程：**
1. `schemas.mbt` 定义商品 Schema（8 个字段，含 min/max/positive/enum/int 等约束）
2. `schema_to_prompt()` 自动生成带 `//` 约束注释的 TypeScript 接口 prompt — **无需手写 prompt**
3. LLM 接收 prompt 并返回 JSON（mock 模拟了"错误→重试"的过程）
4. `schema.parse()` 校验，**Strip 模式静默移除幻觉字段**

**输出摘要：**
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
    Object({
      "name": String("Quantum Computing Starter Kit"),
      "description": String("A beginner-friendly kit to explore quantum computing..."),
      "price": Number(299.99),
      ...
    })

  ✅ Self-correction loop completed in 1 round(s)
```

---

## 功能特性

- **基本类型**: `string()`, `number()`, `boolean()`, `null()`
- **复合类型**: `object(Map)`, `array(Schema)`, `union(Array[Schema])`, `enum_values(Array[String])`
- **校验规则**: `.min(n)`, `.max(n)`, `.nonempty()`, `.email()`, `.url()`, `.regex(pattern)`, `.startsWith(prefix)`, `.endsWith(suffix)`, `.includes(substring)`, `.uuid()`, `.int()`, `.positive()`, `.negative()`, `.multipleOf(n)` — 全部支持可选 `msg?` 自定义错误消息
- **可选/默认值**: `.optional()` 和 `.default(value)`，规则链正确穿透包装类型
- **对象模式**: `.strict()` 拒绝多余字段；`.passthrough()` 保留多余字段；`.strip()`（默认）静默移除
- **数据变换**: `.transform(fn)` 校验通过后变换输出
- **自定义规则**: `.refine(check, message)`
- **LLM Prompt**: `schema_to_prompt()` 自动生成带约束注释的 TypeScript 接口文本
- **字段描述**: `.describe(text)` 附加人类可读描述，由 `schema_to_prompt()` 渲染
- **JSON Schema 导出**: `to_json_schema(schema)` 生成标准 JSON Schema 对象
- **详细错误**: 每个错误含字段路径、消息、实际接收值

---

## 🔄 LLM 自修正示例

moon_zod 专为**错误反馈循环**设计——这是让 AI Agent 可靠运行的关键模式：

```mbt nocheck
///|
/// 重试循环：校验 → 收集错误 → 反馈 → 重试
fn call_llm_with_retry(schema : @moon_zod.Schema, times : Int) {
  var attempt = 0
  while attempt < times {
    let raw = llm_call(schema)  // LLM 返回 JSON
    match schema.parse(raw) {
      Ok(clean) => return clean   // Strip 模式清除幻觉字段
      Err(errors) => {
        // 将所有错误格式化为修正 prompt
        var msg = "Fix these errors:\n"
        for e in errors {
          msg = msg + "  - \{e.path}: \{e.message}\n"
        }
        llm_feedback(msg)         // 发送错误给 LLM
      }
    }
    attempt = attempt + 1
  }
}
```

**没有 moon_zod**: LLM 幻觉出多余字段 → 数据污染。LLM 犯多个错误 → 多次往返修正。

**有了 moon_zod**: Strip 模式清洗幻觉。全量错误收集让一次重试修复所有错误。

完整可运行示例见 [`examples/llm_agent/`](./examples/llm_agent/)：
```
moon run examples/llm_agent
```

---

## ⚡ 性能

moon_zod 的**可变路径栈**（Phase 5）将路径字符串构建推迟到实际发生错误时才执行。在校验成功路径上（LLM 输出质量良好时的常见情况），路径追踪**零堆分配**。

这对 **Wasm 边缘运行时**尤为重要——GC 暂停和内存压力直接影响请求延迟。

### 跨语言基准测试（100k 次迭代）

| 校验器 | 运行时 | Ops/sec |
|---|---|---|
| **TS Zod** | In-process V8 | 243,178 ops/sec |
| **MoonZod** | Native (@bench) | **3,815,556 ops/sec** |

> 两者均在进程中运行，无子进程开销。MoonZod 使用 MoonBit 的 `@bench` 库进行校准迭代计数（ns/op → ops/sec）；TS Zod 使用挂钟计时（100k 次手动 `parse()` 调用）。MoonZod 在此基准中比 TS Zod 快约 **15x**，展示了零分配校验路径（Phase 5 可变路径栈）的优势。

运行基准：
```
moon run cmd/main                  # MoonZod 吞吐量（3 个基准）
cd bench_cross_lang && node bench.js  # 跨语言对比
```

---

## API 参考

### 工厂函数

| 函数 | 说明 |
|---|---|
| `string()` | 校验 JSON 字符串 |
| `number()` | 校验 JSON 数字 |
| `boolean()` | 校验 JSON 布尔值 |
| `null()` | 校验 JSON null |
| `array(Schema)` | 校验 JSON 数组，元素按给定 schema 递归校验 |
| `object(Map[String, Schema])` | 校验 JSON 对象。**默认: Strip 模式** |
| `enum_values(Array[String])` | 固定枚举值集合 |
| `union(Array[Schema])` | 联合类型 — 任一 schema 匹配即通过 |

### Schema 方法

| 方法 | 适用类型 | 说明 |
|---|---|---|
| `.parse(Json, path?)` | 所有 | 校验，返回 `Ok(Json)` 或 `Err(Array[ValidationError])` |
| `.min(n[, msg])` | string / number / array | 最小长度/最小值 |
| `.max(n[, msg])` | string / number / array | 最大长度/最大值 |
| `.nonempty([msg])` | string | 字符串非空 |
| `.email([msg])` | string | 校验 email 格式（改进版：恰好一个 @、local 无首尾点、domain 至少一个点）|
| `.url([msg])` | string | 须以 `http://` 或 `https://` 开头 |
| `.regex(pattern[, msg])` | string | 须包含 `pattern` 子串 |
| `.startsWith(prefix[, msg])` | string | 以特定前缀开始 |
| `.endsWith(suffix[, msg])` | string | 以特定后缀结束 |
| `.includes(substring[, msg])` | string | 包含特定子串 |
| `.uuid([msg])` | string | UUID v4 格式校验 |
| `.int([msg])` | number | 须为整数（无小数部分） |
| `.positive([msg])` | number | 须 > 0 |
| `.negative([msg])` | number | 须 < 0 |
| `.multipleOf(n[, msg])` | number | 须是 n 的整数倍 |
| `.optional()` | 任意 | null 或缺失时跳过校验。**规则链穿透**：`.optional().min(3)` 正确工作 |
| `.default(value)` | 任意 | null 时替换为默认值。**规则链穿透** |
| `.strict()` | object | 拒绝未定义字段 |
| `.passthrough()` | object | 保留未定义字段原样 |
| `.strip()` | object | 静默移除未定义字段（默认行为）|
| `.describe(text)` | 任意 | 附加人类可读描述，由 `schema_to_prompt()` 渲染到 LLM prompt |
| `.message(text)` | 任意 | 覆写上一条规则的消息 |
| `.intersect(other)` | 任意 | 交集组合：输入须同时满足两个 Schema；对象字段自动合并 |
| `.refine(check, msg)` | 任意 | 自定义校验谓词 |
| `.transform(fn)` | 任意 | 校验通过后变换输出值，`fn: (Json) -> Result[Json, String]` |

### 独立函数

| 函数 | 说明 |
|---|---|
| `schema_to_prompt(Schema)` | 生成 TypeScript-interface 风格 prompt 字符串（含约束注释 + 描述）|
| `to_json_schema(Schema)` | 导出为标准 JSON Schema 对象（含完整约束注解）|
| `to_json_schema_skeleton(Schema)` | 导出轻量 JSON Schema 骨架（仅结构，无约束）|
| `format_path(Array[String])` | 将路径栈拼接为点号路径字符串 |
| `ValidationError::to_string()` | 格式化错误为 `[path] message (got: value)` |

### 核心类型

```mbt nocheck
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

## 项目结构

```
moon_zod/
├── types.mbt           # 核心类型
├── schema.mbt          # Schema 枢纽 + parse 分派
├── string.mbt          # string() + 规则链
├── number.mbt          # number() + 规则链
├── boolean.mbt         # boolean()
├── null.mbt            # null()
├── array.mbt           # array() + parse_array
├── object.mbt          # object() + strict/passthrough/strip
├── union.mbt           # optional / default / enum / union
├── refine.mbt          # refine()
├── transform.mbt       # transform()
├── prompt.mbt          # schema_to_prompt() — LLM prompt 生成
├── json_schema.mbt     # to_json_schema() / to_json_schema_skeleton()
├── cmd/main/           # 基准测试
├── examples/llm_agent/ # LLM 自修正演示
├── examples/real_llm_agent/ # 真实 LLM Agent — 完整管线演示
├── moon_zod_test.mbt   # 黑盒测试（185）
└── moon_zod_wbtest.mbt # 白盒测试（4）
```

---

## 开发

```bash
moon test                # 运行全部测试（共 189 项）
moon build               # 构建库
moon run cmd/main        # 运行基准测试
moon run cmd/json2schema -- '{"hello":"world"}'  # 从 JSON 生成 Schema
moon run examples/llm_agent  # 运行 LLM 演示
moon run examples/real_llm_agent -- product prompt  # Schema → prompt
moon info && moon fmt    # 更新接口 + 格式化
```

### JSON-to-Schema 生成器 (CLI)

从任意 JSON 数据即时生成 `@moon_zod` Schema 代码——无需为真实 API 数据手动编写 Schema。

```bash
moon run cmd/json2schema -- '{"hello": "world"}'
```

输出：
```
── Input JSON ──
Object({hello: String(world)})

── Generated moon_zod Schema (copy-paste ready) ──
@moon_zod.object({
  "hello": @moon_zod.string(),
})

── End ──
```

该生成器递归推断类型（`string`, `number`, `boolean`, `null`, `array`, `object`）并安全转义对象键中的特殊字符。空数组会生成 `/* TODO: specify exact type */` 注释，提醒你类型推断缺乏数据。

---

## 了解更多

- [架构设计文档](./DESIGN.md) — 核心架构与开发历程
- [开发历程回顾](./DEVELOPMENT_RETROSPECTIVE.md) — 完整开发回顾与心得体会
- [English README](./README.mbt.md) — English version
