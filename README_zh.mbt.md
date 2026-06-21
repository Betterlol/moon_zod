# moon_zod

> 🌐 [English README](./README.mbt.md)

MoonBit 运行时 JSON Schema 校验库，受 [Zod](https://zod.dev) 和 [Pydantic](https://docs.pydantic.dev) 启发。

**专为 LLM Tool Calling 设计** — 对大语言模型的结构化 JSON 输出进行运行时校验，提供精确的错误报告与自修正支持。

---

## ✨ 为什么选择 MoonZod？（AI 优先）

| 特性 | moon_zod | 典型验证库 |
|---|---|---|
| **错误收集** | 一次性收集**所有**错误 | 大多数库在第一个错误处快速失败 |
| **幻觉防御** | 默认 **Strip 模式**静默移除未知字段 | 会通过幻觉数据 |
| **命名 Schema 导出** | `schema_to_prompt_named()` 生成模块化 TypeScript 接口，包含类型名称引用 | 内联展开 + 重复 |
| **JSON Schema 导出** | `to_json_schema()` 为 LLM API 生成标准 Schema | 手动维护 Schema |
| **路径精度** | 每个错误都包含精确的字段路径（`users[0].profile.age`） | 通常只是平面消息 |
| **Wasm 就绪** | 可变路径栈 — 成功路径上零堆分配 | 每次解析都大量字符串分配 |

在 LLM 工具调用中，模型经常会**同时产生多个错误**和**幻觉出额外字段**。moon_zod 在一次遍历中收集每个错误（这样你可以将它们全部发送回去进行自我修正），并且默认剥离未知字段（不会从幻觉键导致的无声数据损坏）。

---

## 🚀 快速开始

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

---

## 项目结构

```
moon_zod/
├── types.mbt           # 核心类型
├── schema.mbt          # Schema 枢纽 + 解析分发
├── string.mbt          # string() + 规则
├── number.mbt          # number() + 规则
├── boolean.mbt         # boolean()
├── null.mbt            # null()
├── array.mbt           # array() + parse_array
├── object.mbt          # object() + strict/passthrough/strip/pick/omit/partial
├── union.mbt           # optional / default / enum / union
├── intersection.mbt    # intersection() / intersect()
├── refine.mbt          # refine()
├── transform.mbt       # transform()
├── prompt.mbt          # schema_to_prompt() / schema_to_prompt_named() — LLM 提示生成
├── json_schema.mbt     # to_json_schema() / to_json_schema_skeleton()
│
├── test_*.mbt          # 15 个类型特定测试文件
├── test_prompt_named.mbt # 命名 Schema 导出测试（6 个）
├── moon_zod_wbtest.mbt # 白盒测试（4 个）
│
├── cmd/                # 基准测试 + CLI 工具
└── examples/           # LLM 代理演示
```

---

## 开发

```bash
moon test                # 运行所有测试（282 个总计，0 个警告）
moon build               # 构建库
moon run cmd/main        # 运行基准测试
moon run cmd/json2schema -- '{"hello":"world"}'  # 从 JSON 生成 Schema
moon run examples/llm_agent  # 运行 LLM 演示
moon run examples/real_llm_agent -- product prompt  # Schema → 提示
moon info && moon fmt    # 更新接口 + 格式化
```

---

## 特性

- **原始类型 Schema**：`string()`、`number()`、`boolean()`、`null()`
- **复合类型 Schema**：`object(Map)`、`array(Schema)`、`union(Array[Schema])`、`intersection(Array[Schema])`、`enum_values(Array[String])`
- **校验规则**：`.min(n)`、`.max(n)`、`.nonempty()`、`.email()`、`.url()`、`.regex(pattern)`、`.startsWith(prefix)`、`.endsWith(suffix)`、`.includes(substring)`、`.uuid()`、`.cuid()`、`.datetime()`、`.ip()`/`.ipv4()`/`.ipv6()`、`.ulid()`、`.length(n)`、`.int()`、`.positive()`、`.negative()`、`.multipleOf(n)`、`.finite()`、`.safe()` — 所有规则都支持可选的自定义错误消息 `msg?` 参数
- **可选 / 默认值**：`.optional()` 和 `.default(value)` 支持通过包装器正确的规则链接
- **Object 模式**：`.strict()` 拒绝额外字段；`.passthrough()` 允许它们；`.strip()`（默认）静默移除它们
- **Schema 组合**：`.pick(keys)`、`.omit(keys)`、`.partial()` 用于派生对象子 Schema
- **数据转换**：`.transform(fn)` 验证后转换输出
- **自定义规则**：`.refine(check, message)`
- **LLM 提示**：
  - `schema_to_prompt()` 自动生成内联 TypeScript 接口提示文本，带有约束注释
  - `schema_to_prompt_named()` 自动提取命名 Schema，进行拓扑排序，生成包含类型名称引用的模块化接口
- **字段描述**：`.describe(text)` 附加人类可读的描述，由 `schema_to_prompt()` 呈现
- **JSON Schema 导出**：`to_json_schema(schema)` 生成标准 JSON Schema 对象
- **类型级错误**：`.string(invalid_type_error="...", required_error="...")` — 在工厂级自定义类型不匹配和必填字段错误消息

## API 参考

### 工厂函数

| 函数 | 描述 |
|---|---|---|
| `string(required_error?, invalid_type_error?)` | 校验 JSON 字符串 |
| `number(required_error?, invalid_type_error?)` | 校验 JSON 数字 |
| `boolean(required_error?, invalid_type_error?)` | 校验 JSON 布尔值 |
| `null(required_error?, invalid_type_error?)` | 校验 JSON null |
| `array(Schema, required_error?, invalid_type_error?)` | 校验数组，递归检查元素 |
| `object(Map[String, Schema], required_error?, invalid_type_error?)` | 校验对象。**默认：Strip 模式** |
| `enum_values(Array[String], required_error?, invalid_type_error?)` | 固定的允许字符串值集合 |
| `union(Array[Schema], required_error?, invalid_type_error?)` | 联合类型 — 任意 schema 匹配即通过 |
| `intersection(Array[Schema], required_error?, invalid_type_error?)` | 交集 — 所有 schema 都匹配才通过；对象字段会合并 |

### Schema 方法

| 方法 | 适用于 | 描述 |
|---|---|---|
| `.parse(Json, path?)` | 全部 | 校验，返回 `Ok(Json)` 或 `Err(Array[ValidationError])` |
| `.min(n[, msg])` | string / number / array | 最小长度/值 |
| `.max(n[, msg])` | string / number / array | 最大长度/值 |
| `.nonempty([msg])` | string | 字符串不能为空 |
| `.email([msg])` | string | 完整的电子邮件校验（带引号的本地部分、IP 字面量、+标签、TLD≥2、单个 @） |
| `.url([msg])` | string | 完整的 URL 结构：`scheme://host[:port][/path][?query][#fragment]` |
| `.regex(pattern[, msg])` | string | 必须包含 `pattern` 作为子字符串 |
| `.startsWith(prefix[, msg])` | string | 必须以 `prefix` 开头 |
| `.endsWith(suffix[, msg])` | string | 必须以 `suffix` 结尾 |
| `.includes(substring[, msg])` | string | 必须包含 `substring` |
| `.uuid([msg])` | string | 必须是有效的 UUID v4 |
| `.cuid([msg])` | string | 必须是有效的 CUID（c + base36 哈希） |
| `.datetime([msg])` | string | 必须是 ISO 8601 日期时间（日期 + T + 时间 ± 偏移/Z） |
| `.ip([msg])` | string | 必须是有效的 IPv4 或 IPv6 地址 |
| `.ipv4([msg])` | string | 必须是有效的 IPv4 地址 |
| `.ipv6([msg])` | string | 必须是有效的 IPv6 地址（完整/缩写形式，支持 ::） |
| `.ulid([msg])` | string | 必须是有效的 ULID（26 字符 Crockford base32） |
| `.int([msg])` | number | 必须是整数（无小数部分） |
| `.positive([msg])` | number | 必须 > 0 |
| `.negative([msg])` | number | 必须 < 0 |
| `.multipleOf(n[, msg])` | number | 必须是 `n` 的倍数 |
| `.length(n[, msg])` | string / array | 必须恰好有长度 `n` |
| `.finite([msg])` | number | 必须是有限数（不是 NaN、不是 ±Infinity） |
| `.safe([msg])` | number | 必须是安全整数（不是 NaN、不是 ±Infinity、无小数部分） |
| `.optional()` | 任意 | null 或缺失值跳过校验 |
| `.default(value)` | 任意 | 用默认值替换 null |
| `.strict()` | object | 拒绝未定义的字段 |
| `.passthrough()` | object | 保持未定义的字段不变 |
| `.strip()` | object | 静默移除未定义的字段（默认） |
| `.describe(text)` | 任意 | 附加描述，由 `schema_to_prompt()` 为 LLM 提示而渲染 |
| `.message(text)` | 任意 | 覆盖最后一条规则的错误消息 |
| `.intersect(other)` | 任意 | 交集：输入必须匹配两个 schema；对象字段会合并 |
| `.pick(keys)` | object | 仅选择指定的字段 |
| `.omit(keys)` | object | 移除指定的字段 |
| `.partial()` | object | 使所有字段可选 |
| `.refine(check, msg)` | 任意 | 自定义校验谓词 |
| `.transform(fn)` | 任意 | 校验后通过 `(Json) -> Result[Json, String]` 转换输出 |

### 独立函数

| 函数 | 描述 |
|---|---|
| `schema_to_prompt(Schema)` | 为 LLM 生成 TypeScript 接口提示字符串（带约束注释） — 内联展开 |
| `schema_to_prompt_named(Schema)` | 从命名 schema 生成模块化 TypeScript 接口，包含拓扑排序和类型名称引用 — 用于复杂的嵌套 LLM 工具 schema |
| `to_json_schema(Schema)` | 导出标准 JSON Schema 对象，包含完整的约束注解 |
| `to_json_schema_skeleton(Schema)` | 导出轻量级 JSON Schema 框架（仅结构，无约束） |
| `format_path(Array[String])` | 将路径栈连接成点号记法字符串 |
| `ValidationError::to_string()` | 将错误格式化为 `[path] message (got: value)` |

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

### JSON-to-Schema 生成器 (CLI)

从任何 JSON 数据有效负载中即时生成 `@moon_zod` schema 代码 — 无需为真实世界的 API 数据手动编写 schema。

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


## ⚡ 性能

moon_zod 的**可变路径栈**（第 5 阶段）将路径字符串构造延迟到实际发生错误时。在验证成功路径上——这是格式良好的 LLM 输出的常见情况——路径跟踪**零堆分配**。

这对于 **Wasm 边缘运行时**尤其重要，因为垃圾回收暂停和内存压力直接影响请求延迟。

### 跨语言基准测试（100k 次迭代）

| 验证器 | 运行时 | 吞吐量 |
|---|---|---|
| **TS Zod** | In-process V8 | 243,178 ops/sec |
| **MoonZod** | Native (@bench) | **3,815,556 ops/sec** |

> 两个验证器都以进程内方式运行，无子进程开销。MoonZod 使用 MoonBit 的 `@bench` 库进行校准的迭代计数（ns/op → ops/sec）；TS Zod 在 100k 次手动 `parse()` 调用上使用挂钟计时。在此基准测试中，MoonZod 比 TS Zod 快约 15 倍，展示了专注、零分配验证路径（第 5 阶段可变路径栈）的优势。

运行基准测试：
```
moon run cmd/main                  # MoonZod 吞吐量（3 个基准测试）
cd bench_cross_lang && node bench.js  # 跨语言对比

# 演示：Schema → `schema_to_prompt()` → LLM → `schema.parse()`

**完整的 LLM 工具调用管道**分四步实现，**零手写提示词**：

```
define Schema  →  schema_to_prompt()  →  feed to LLM  →  schema.parse()
   (MoonBit)        (auto-generated         (model         (auto-validate
                     TS interface)           response)      + strip extra) fields)
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

## 了解更多

- [架构设计文档](./DESIGN.md) — 核心架构、设计决策与未来方向
- [发布日志](./CHANGELOG.md) — 版本发布历史
- [English README](./README.mbt.md) — English version
