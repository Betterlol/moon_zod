# moon_zod vs Zod v4 — Error Handling 架构差异与 Gap 分析

> 对标对象：`zod/packages/zod/src/`（已分析）  
> 审查对象：`moon_zod/core/`（26 个 .mbt 文件）  
> 生成时间：2025-07-17

---

## 一、moon_zod 当前 Error 实现全景

### 1.1 核心类型

```moonbit
// core/types.mbt
pub(all) struct ValidationError {
  path : String       // 字段路径，如 "name" 或 "address.city"
  message : String    // 错误描述
  got : Json          // 实际传入的值
}

pub type SchemaResult = Result[Json, Array[ValidationError]]
```

### 1.2 错误消息载体

```moonbit
// core/schema.mbt
pub(all) struct Rule {
  check : (Json) -> Bool
  message : String              // 单条规则的错误消息（构造时固定）
  annotation : Json             // JSON Schema 约束元数据
}

pub(all) struct Schema {
  schema_type : SchemaType
  rules : Array[Rule]
  description : String
  required_error : String       // 字段缺失时的错误消息
  invalid_type_error : String   // 类型不匹配时的错误消息
  name : String
  brand : String
}
```

### 1.3 消息解析时机

**关键差异**：moon_zod 在 **Schema 构造时** 解析并固化所有错误消息，而 Zod v4 在 **parse finalize 时** 延迟解析。

```moonbit
// moon_zod: 构造时立即解析
fn type_error_msg(schema : Schema) -> String {
  if !schema.invalid_type_error.is_empty() {
    schema.invalid_type_error        // 直接返回已固化的字符串
  } else {
    expected_msg(schema.schema_type)  // 硬编码英文兜底
  }
}

fn expected_msg(schema_type : SchemaType) -> String {
  match schema_type {
    StringType => "Expected string"
    NumberType => "Expected number"
    ...
  }
}
```

### 1.4 自定义消息机制

```moonbit
// 工厂参数
pub fn string(required_error? : String = "", invalid_type_error? : String = "") -> Schema

// 链式方法
pub fn Schema::required_error(self : Schema, text : String) -> Schema
pub fn Schema::invalid_type_error(self : Schema, text : String) -> Schema
pub fn Schema::message(self : Schema, text : String) -> Schema   // 覆盖最后一条规则

// refine
pub fn Schema::refine(self : Schema, check : (Json) -> Bool, message : String) -> Schema
```

### 1.5 错误产生流程

```
Schema::parse(json)
  → parse_inner(schema, json, path_stack)
    → 类型匹配失败 → type_error_msg() → 立即生成 ValidationError
    → 规则匹配失败 → rule.message → 立即生成 ValidationError
    → 字段缺失 → required_error → 立即生成 ValidationError
  → Err(Array[ValidationError])
```

---

## 二、逐项 Gap 分析

### Gap 1：全局 Error Map 单例 ❌ 完全缺失

| 维度 | Zod v4 | moon_zod |
|------|--------|----------|
| 全局配置对象 | `$ZodConfig` + `globalConfig` 单例挂载在 `globalThis` | 无 |
| 设置方式 | `config({ customError: map })` / `config({ localeError: map })` | 无对应 API |
| 生命周期 | 进程级全局，影响后续所有 parse | 无全局状态 |
| 优先级 | 第 4/5 层（parse 时动态查找） | 不适用（消息已固化） |

**影响**：无法实现"全局替换所有错误消息"或"运行时切换 locale"。

---

### Gap 2：Contextual Error Map（parse 时传入） ❌ 完全缺失

| 维度 | Zod v4 | moon_zod |
|------|--------|----------|
| parse 时传入 | `schema.safeParse(data, { error: myMap })` | `Schema::parse(json, path? : String = "")` |
| 优先级 | 第 3 层（高于全局，低于 inline） | 不适用 |
| 类型 | `ParseContext.error : $ZodErrorMap` | 无 |

**影响**：无法在单次 parse 调用中临时覆盖错误消息，例如：
```typescript
// Zod v4: 仅在本次调用中使用中文错误消息
schema.safeParse(data, { error: chineseErrorMap })
```

---

### Gap 3：Schema-Bound Error Map ❌ 完全缺失

| 维度 | Zod v4 | moon_zod |
|------|--------|----------|
| schema 级 map | `z.string({ error: (iss) => "bound" })` → `def.error` | 无对应概念 |
| 优先级 | 第 2 层（高于 contextual，低于 inline） | 不适用 |

moon_zod 当前最接近的是工厂参数 `invalid_type_error` 和链式方法 `.invalid_type_error()`，但：
- 仅影响类型错误，不影响规则错误（如 `min`、`max`）
- 是固定字符串，不是函数（无法根据 issue 动态生成消息）
- 没有统一的 `error` 字段

---

### Gap 4：Deferred Message Resolution（延迟解析） ❌ 架构级缺失

| 维度 | Zod v4 | moon_zod |
|------|--------|----------|
| 解析时机 | parse finalize 阶段（运行时） | Schema 构造时（编译期） |
| 机制 | `finalizeIssue()` 在 parse 后调用 | 消息直接写在 `Rule.message` 中 |
| 灵活性 | 可根据 parse 上下文动态选择消息 | 消息固化，不可变 |
| Raw Issue | `$ZodRawIssue`（无 message）→ `finalizeIssue()` → `$ZodIssue`（有 message） | 直接构造 `ValidationError`（消息已存在） |

**这是最根本的架构差异**。Zod v4 的错误消息是"可插拔的"，moon_zod 的错误消息是"固定的"。

---

### Gap 5：Issue Codes（问题类型码） ❌ 完全缺失

| 维度 | Zod v4 | moon_zod |
|------|--------|----------|
| 类型系统 | Discriminated union of 11 issue types | 无 |
| 字段 | `code: "invalid_type"`, `code: "too_big"`, `code: "too_small"`, ... | 无 |
| 用途 | Error map 根据 code 分发处理 | 无对应机制 |

Zod v4 的 issue codes：
```
invalid_type | too_big | too_small | invalid_format |
not_multiple_of | unrecognized_keys | invalid_union |
invalid_key | invalid_element | invalid_value | custom
```

moon_zod 没有结构化的问题类型码，错误消息仅靠字符串匹配。

---

### Gap 6：Locale / i18n 系统 ❌ 完全缺失

| 维度 | Zod v4 | moon_zod |
|------|--------|----------|
| Locale 文件 | 50+ 语言（`locales/en.ts`, `fr.ts`, ...） | 无 |
| 安装方式 | `config(en())` / `config(fr())` | 无 |
| 消息来源 | Locale factory 返回 `{ localeError: $ZodErrorMap }` | 硬编码英文 |
| 切换时机 | 运行时全局切换 | 不适用 |

所有 moon_zod 错误消息均为英文硬编码：
```
"Expected string" / "Expected number" / "Required" / "Unexpected field"
```

---

### Gap 7：Rich Error Class ❌ 完全缺失

| 维度 | Zod v4 | moon_zod |
|------|--------|----------|
| 错误类 | `$ZodError` / `ZodError`（classic） | 无（使用 `Result` 类型） |
| 结构化输出 | `.flatten()` / `.format()` / `.treeify()` | 无 |
| 动态添加 | `.addIssue()` | 无 |
| 属性 | `.issues` / `.name` / `.message` | 无 |

moon_zod 使用 MoonBit 的 `Result[T, E]` 类型，错误是简单的 `Array[ValidationError]`，没有统一的错误类。

---

### Gap 8：Error Map 优先级链 ❌ 完全缺失

Zod v4 的优先级链（`finalizeIssue`）：

```
1. inline message          → iss.message
2. schema-bound error map  → iss.inst._zod.def.error(iss)
3. contextual error map    → ctx.error(iss)
4. customError (global)    → config.customError(iss)
5. localeError (global)    → config.localeError(iss)
6. fallback                → "Invalid input"
```

moon_zod 的消息来源是扁平的：
- `Rule.message`（构造时固定）
- `Schema.required_error`（构造时固定）
- `Schema.invalid_type_error`（构造时固定）
- `type_error_msg()` 硬编码兜底

**没有优先级，没有覆盖关系**。

---

### Gap 9：v3 兼容层 ❌ 不需要（全新设计）

Zod v4 提供了 `classic/compat.ts` 以兼容 v3 API：
- `setErrorMap(map)` → `config({ customError: map })`
- `getErrorMap()` → `config({ customError })`

moon_zod 作为新库，无需 v3 兼容，但应提供清晰、一致的 API 设计。

---

## 三、已有功能与 Zod v4 的对齐情况

| 功能 | moon_zod | Zod v4 对应 | 对齐度 |
|------|----------|-------------|--------|
| Inline message（规则级） | `Rule.message` / `.min(3, msg="...")` | `z.string().min(3, "too short")` | ✅ 基本对齐 |
| `.message()` 链式覆盖 | `Schema::message(text)` | `.message("...")` | ✅ 对齐 |
| `required_error` | `Schema.required_error` + `.required_error()` | 无直接对应（用 error map 实现） | ⚠️ 部分对齐 |
| `invalid_type_error` | `Schema.invalid_type_error` + `.invalid_type_error()` | 无直接对应（用 error map 实现） | ⚠️ 部分对齐 |
| `refine()` 自定义验证 | `Schema::refine(check, message)` | `.refine(check, message)` | ✅ 对齐 |
| 类型错误兜底消息 | `expected_msg()` 硬编码 | Locale error map | ⚠️ 英文硬编码 |
| 路径构建 | `format_path()` / `sub_path()` / `sub_index()` | `_zod.def.errorMap` + path | ✅ 功能对齐 |

---

## 四、缺失功能的优先级评估

### P0 — 必须实现（核心架构）

| # | 功能 | 理由 |
|---|------|------|
| 1 | **Issue Codes  discriminated union** | 结构化错误分类的基础，所有高级功能的前置 |
| 2 | **Deferred Message Resolution** | 实现全局/上下文 error map 的前提 |
| 3 | **Global Config Singleton** | 全局 error map / locale 的载体 |
| 4 | **Raw Issue → Finalized Issue 分离** | 延迟解析的必要数据结构 |

### P1 — 重要（实用性）

| # | 功能 | 理由 |
|---|------|------|
| 5 | **Error Map 优先级链** | 提供 Zod v4 级别的消息定制灵活性 |
| 6 | **Contextual Error Map（parse 参数）** | 单次调用临时覆盖消息 |
| 7 | **Locale 工厂接口** | i18n 支持，当前全英文硬编码 |
| 8 | **Schema-Bound Error Map** | 工厂级 `error` 参数 |

### P2 — 增强（体验优化）

| # | 功能 | 理由 |
|---|------|------|
| 9 | **ZodError 错误类** | 替代 `Array[ValidationError]`，提供 `.flatten()` 等工具 |
| 10 | **`set_error_map()` / `get_error_map()` API** | 简洁的全局设置接口 |
| 11 | **异步 parse 支持** | Zod v4 的 `DEFAULT_ASYNC` 机制 |

---

## 五、建议的 moon_zod Error 架构设计

### 5.1 核心类型（建议）

```moonbit
// core/types.mbt — 扩展

/// Issue 码（discriminated union）
pub(all) enum IssueCode {
  InvalidType(expected : String)
  TooBig(origin : String, maximum : Double, inclusive : Bool)
  TooSmall(origin : String, minimum : Double, inclusive : Bool)
  InvalidFormat(format : String)
  NotMultipleOf(divisor : Double)
  UnrecognizedKeys(keys : Array[String])
  InvalidUnion(branches : Array[String])
  InvalidKey(origin : String)
  InvalidElement(origin : String, key : Int)
  InvalidValue(values : Array[Json])
  Custom(params : Json?)
} derive(Debug)

/// Raw Issue（parse 过程中收集，无 message）
pub(all) struct RawIssue {
  code : IssueCode
  path : Array[String]    // 使用 path stack 而非字符串
  input : Json
  inst? : Schema           // 起源的 schema
  continue? : Bool
}

/// Finalized Issue（message 解析后）
pub(all) struct Issue {
  code : IssueCode
  path : String            // format_path 后的字符串
  message : String
  input : Json
}

/// Error Map 类型
pub(all) type ErrorMap = Fn[IssueCode, Array[String], Json] -> String?

/// Global Config
pub(all) struct ZodConfig {
  custom_error : ErrorMap?
  locale_error : ErrorMap?
}

// global singleton
let global_config : ZodConfig = { custom_error: None, locale_error: None }
```

### 5.2 延迟解析流程（建议）

```moonbit
// core/util.mbt — 新增

pub fn finalize_issue(
  raw : RawIssue,
  ctx? : ParseContext,
  config : ZodConfig,
) -> Issue {
  let path = format_path(raw.path)
  let message =
    // 1. inline message（Rule.message 已存储，需在 RawIssue 中携带）
    raw.inline_message?
    ?? schema_error_map(raw.inst?, raw)?
    ?? ctx?.error_map?(raw)
    ?? config.custom_error?(raw)
    ?? config.locale_error?(raw)
    ?? default_message(raw.code)
  Issue::{ code: raw.code, path, message, input: raw.input }
}
```

### 5.3 parse 签名扩展（建议）

```moonbit
// 当前
pub fn Schema::parse(self : Schema, json : Json, path? : String = "") -> SchemaResult

// 建议
pub fn Schema::parse(
  self : Schema,
  json : Json,
  params? : ParseParams,
) -> SchemaResult

pub(all) struct ParseParams {
  path? : String = ""
  error_map? : ErrorMap = None   // 本次调用的 contextual error map
}
```

### 5.4 Locale 接口（建议）

```moonbit
// locales/en.mbt
pub fn en() -> ZodConfig {
  {
    custom_error: None,
    locale_error: fn(code, path, input) {
      match code {
        InvalidType(expected) => Some("Expected " + expected)
        TooBig(_, max, inc) => ...
        _ => None
      }
    },
  }
}

// 使用
zod_config(locales::en())   // 全局设置
schema.parse(json, { error_map: my_map })  // 单次覆盖
```

---

## 六、moon_zod 当前实现的优势

1. **简洁性**：消息在构造时固化，无运行时解析开销
2. **MoonBit 惯用**：使用 `Result[T, E]` 而非自定义错误类，符合 MoonBit 风格
3. **类型安全**：`Schema` 是普通 struct，无 trait/class 复杂性
4. **路径高效**：使用共享可变 `path_stack` 避免字符串分配（white-box test 验证）

---

## 七、总结

moon_zod 当前的 error 实现是 **"构造时固化消息"** 模型，适合简单场景，但缺少 Zod v4 的 **"运行时延迟解析 + 多层优先级链"** 架构。

核心差距：
1. ❌ 无全局 error map / config 单例
2. ❌ 无 contextual error map（parse 时传入）
3. ❌ 无 schema-bound error map（动态函数）
4. ❌ 无 deferred message resolution
5. ❌ 无 issue codes（结构化问题分类）
6. ❌ 无 locale/i18n 系统
7. ❌ 无 Error Map 优先级链

如果目标是做一个"面向 LLM tool calling 的轻量校验库"，当前的实现已经足够；如果目标是"对标 Zod v4 的完整校验库"，则需要从 P0 开始逐步补齐上述能力。
