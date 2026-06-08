# moon_zod — 项目交接文档

## 1. 项目概述

**moon_zod** 是一个 MoonBit 运行时 JSON Schema 校验库，受 Zod (TypeScript) 和 Pydantic (Python) 启发。核心场景是 LLM Tool Calling 的输出结构化校验与精确错误回溯。

- **语言**: MoonBit
- **模块名**: `Betterlol/moon_zod`
- **版本**: 0.2.2（含 v0.2.1 hotfix + JSON Schema 完整约束导出）
- **依赖**: 仅 `moonbitlang/core/json`、`moonbitlang/core/debug`
- **测试**: 95 个测试（91 黑盒 + 4 白盒），全部通过
- **编译器警告**: 0
- **CI**: GitHub Actions (ubuntu-latest)，覆盖 fmt check → native build → wasm build → test
- **发布**: https://github.com/Betterlol/moon_zod/releases/tag/v0.2.2

---

## 2. 文件结构与职责

```
moon_zod/
├── moon.mod                  # 包元信息（模块名/版本/描述）
├── moon.pkg                  # 包声明（导入 @json + @debug）
├── AGENTS.md                 # Agent 工作指南
├── DESIGN.md                 # 架构设计文档
├── README.mbt.md             # 用户 README（含 API 参考、Benchmark 数据、LLM 自愈示例）
├── summary_handover.md       # 本文件
├── step_phase_summary.md     # Phase 1-13 合并总结
├── step_phase_details/       # 各阶段详细总结（13 个 .md）
│
├── .github/workflows/
│   └── ci.yml                # CI: checkout → setup-moonbit → install → fmt → build → test
│
├── types.mbt                 # ValidationError / SchemaResult 类型
├── schema.mbt                # 核心枢纽：SchemaType / Schema / ObjectMode / Rule / parse 入口
├── string.mbt                # string() 工厂 + 所有规则方法
├── number.mbt                # number() 工厂 + 所有规则方法
├── boolean.mbt               # boolean() 工厂
├── null.mbt                  # null() 工厂
├── array.mbt                 # array() 工厂 + parse_array helper
├── object.mbt                # object() 工厂 + strict/passthrough/strip 方法 + parse_object helper
├── union.mbt                 # optional / default / enum_values / union 工厂 + parse helpers
├── refine.mbt                # refine() 自定义规则
├── transform.mbt             # transform() 数据变换管线
├── json_schema.mbt           # to_json_schema() 导出标准 JSON Schema
├── moon_zod.mbt              # 包级文档（doc comment）
│
├── moon_zod_test.mbt         # 黑盒测试（81 tests）
├── moon_zod_wbtest.mbt       # 白盒测试（4 tests）
│
├── cmd/main/
│   ├── moon.pkg              # Benchmark 可执行包声明
│   └── main.mbt              # 性能 Benchmark（3 项：Valid / Adversarial / Redundancy）
│
├── cmd/wasm/
│   ├── moon.pkg              # Wasm benchmark 可执行包声明（导入 env）
│   └── main.mbt              # Wasm 三路对比：moonzod / handcrafted / verify / startup
│
├── cmd/json2schema/
│   ├── moon.pkg              # JSON-to-Schema 生成器可执行包声明
│   └── main.mbt              # CLI：JSON 输入 → @moon_zod 源码输出（含 safe escaping）
│
├── bench_cross_lang/
│   ├── package.json           # Node 包声明 + zod 依赖
│   └── bench.js              # JS 编排器：TS Zod vs MoonZod vs Handcrafted（100k 迭代）
│
├── examples/llm_agent/
│   ├── moon.pkg              # LLM Demo 可执行包声明
│   └── main.mbt              # LLM 自愈闭环：schema 定义 → mock 错误 → 校验 → 重试 → Strip
│
├── examples/educational_agent/
│   ├── moon.pkg              # 教育 Agent 可执行包声明
│   └── main.mbt              # 3 轮自纠正：类型错误 → 规则违例 → Strip 清洗
│
├── examples/real_llm_agent/
│   ├── schemas.mbt           # 真实 LLM API 调用示例（含 API Key 配置）
│   └── validator.mbt         # LLM 输出的结构化校验与重试逻辑
│
├── examples/json2schema/
│   ├── main.mbt              # JSON → Schema 代码生成示例（从文件读取 JSON）
│   ├── moon.pkg
│   └── test_*.json           # 测试用 JSON 数据文件
│
├── examples/schema2json/
│   ├── schemas.mbt           # Schema → JSON 反向转换示例
│   └── run.sh                # 运行脚本
│
└── pkg.generated.mbti        # 自动生成的接口描述，**勿手动编辑**
```

---

## 3. 公共 API 完整参考

### 工厂函数

| 函数 | 说明 |
|---|---|
| `string() -> Schema` | 校验 JSON 字符串 |
| `number() -> Schema` | 校验 JSON 数字 |
| `boolean() -> Schema` | 校验 JSON 布尔值 |
| `null() -> Schema` | 校验 JSON null |
| `array(Schema) -> Schema` | 校验 JSON 数组，元素按给定 schema 递归校验 |
| `object(Map[String, Schema]) -> Schema` | 校验 JSON 对象。**默认 Strip 模式**（静默移除未定义字段）|
| `enum_values(Array[String]) -> Schema` | 固定枚举值 |
| `union(Array[Schema]) -> Schema` | 联合类型：任一通过即成功 |

### Schema 方法

| 方法 | 适用类型 | 说明 |
|---|---|---|
| `.parse(Json, path?: String) -> SchemaResult` | 所有 | 执行校验，返回 `Ok(Json)` 或 `Err(Array[ValidationError])` |
| `.min(n)` | string / number / array | 最小长度/最小值 |
| `.max(n)` | string / number / array | 最大长度/最大值 |
| `.nonempty()` | string | 字符串非空 |
| `.email()` | string | 类似 email 格式（含 @ 和 .）|
| `.url()` | string | 以 `http://` 或 `https://` 开头 |
| `.regex(pattern)` | string | 包含子串 pattern |
| `.int()` | number | 整数值（无小数部分）|
| `.positive()` | number | > 0 |
| `.negative()` | number | < 0 |
| `.multipleOf(n)` | number | n 的整数倍 |
| `.optional()` | 任意 | null 或缺失时跳过校验。**规则链穿透**：`.optional().min(3)` 正确工作 |
| `.default(value)` | 任意 | null 时替换为默认值。**规则链穿透** |
| `.strict()` | object | 拒绝未定义字段 |
| `.passthrough()` | object | 允许未定义字段原样保留 |
| `.strip()` | object | 静默移除未定义字段（默认行为）|
| `.refine(check, msg)` | 任意 | 自定义校验谓词 |
| `.transform(fn)` | 任意 | 校验通过后变换输出值，`fn: (Json) -> Result[Json, String]` |

### 独立函数

| 函数 | 说明 |
|---|---|
| `to_json_schema(Schema) -> Json` | 导出为标准 JSON Schema 对象 |
| `format_path(Array[String]) -> String` | 将路径栈拼接为点号路径字符串 |

> 内部辅助函数（`append_rule`, `inner_type`, `is_optional_schema`, `value_in_array`, `sub_path`, `sub_index` 等）**未暴露**在公有 API 中。`parse_inner` 已在 v0.1.0 发布时从公共接口移除。

### 核心类型

```mbt
pub(all) enum ObjectMode { Passthrough; Strict; Strip }
pub(all) enum SchemaType { StringType; NumberType; BooleanType; NullType;
    ObjectType(Map[String, Schema], ObjectMode); ArrayType(Schema);
    OptionalType(Schema); DefaultType(Schema, Json);
    EnumType(Array[String]); UnionType(Array[Schema]);
    TransformType(Schema, TransformClosure) }
pub(all) struct TransformClosure { f: (Json) -> Result[Json, String] }
pub(all) struct Rule { check: (Json) -> Bool; message: String }
pub struct Schema { schema_type: SchemaType; rules: Array[Rule] }
pub struct ValidationError { path: String; message: String; got: Json }
pub type SchemaResult = Result[Json, Array[ValidationError]]
```

---

## 4. 架构设计关键决策

### 4.1 parse 路由 + 路径栈 (Phase 4-5)

**数据流**：
```
Schema::parse(json, path?)          ← 公共入口，创建 path_stack
  └─ parse_inner(schema, json, stack)  ← 内部转发枢纽（非 pub）
       ├─ parse_object()                ← push/pop 字段名
       ├─ parse_array()                 ← push/pop [索引]
       ├─ parse_optional()              ← 直接传递 stack
       ├─ parse_default()               ← 直接传递 stack
       ├─ parse_enum()                  ← format_path 后在当前层级报错
       ├─ parse_union()                 ← 直接传递 stack
       └─ 基本类型检查                   ← format_path 后在当前层级报错
```

**路径栈设计** (Phase 5)：
- 所有内部 parse helper 接受 `path_stack: Array[String]` 而非 `path: String`
- 进入子结构前 `push()`，返回后 `let _ = pop()`
- 仅在真正产生 `ValidationError` 时才调用 `format_path(stack)` 拼接字符串
- **收益**: 成功路径零字符串分配

### 4.2 append_rule — 装饰器穿透 (Phase 4)

核心技巧：
```mbt
pub fn append_rule(schema, check, message) -> Schema {
  match schema.schema_type {
    OptionalType(inner)  => 递归到 inner，新建 OptionalType 包裹
    DefaultType(inner,_) => 递归到 inner，新建 DefaultType 包裹
    _ => 直接追加到 rules
  }
}
```
使得 `string().optional().min(3)` 的 `min(3)` 规则正确落在内部的 StringType 上，而非被 OptionalType 隔离。

### 4.3 inner_type — 类型擦除 (Phase 4)

用在规则方法的类型守卫中（如 `min()` 检查是 StringType/NumberType/ArrayType），确保装饰器不干扰类型判断。

### 4.4 Strip 默认模式 (Phase 5)

`object()` 默认创建 `Strip` 模式，而非 `Passthrough`：
- 校验成功时，`parse_object` 收集 `parsed_fields: Map[String, Json]`（已递归校验/剥离的值）
- 返回 `Json::object(parsed_fields)`，只包含 spec 定义的字段
- 嵌套对象也能正确递归剥离，因为存储的是递归 parse 后的值

### 4.5 Union 错误聚合 (Phase 5)

所有分支失败时，收集每个分支的第一个错误 message，拼接为：
```
"Expected union type, but all branches failed. Branches: [Expected string, Expected number]"
```
而非只返回最后一个分支的错误。

### 4.6 JSON Schema 导出 (Phase 4)

`to_json_schema()` 递归遍历 `SchemaType`，生成标准 JSON Schema：
- OptionalType/DefaultType → 透明穿透（不产生 `oneOf`）
- Strip/Passthrough → 映射为 `"additionalProperties": true`
- Strict → 映射为 `"additionalProperties": false`

### 4.7 Wasm 跨语言 Benchmark (Phase 7)

由于 MoonBit wasm target 只导出 `_start` 和 `memory`，采用 CLI 参数分发模式：
- `main()` 读取 `@env.args()[1]` 分派到 moonzod / handcrafted / verify / startup
- Node.js 编排器通过 `execFileSync(moonrun, [wasm_path, mode])` 调用
- Startup 模式测量 moonrun 进程启动开销（~12.8ms），从原始 Wasi 时间中扣除

---

## 5. 各阶段提交摘要

| Phase | Commit | 内容 |
|---|---|---|
| init | `6466b60` | 项目初始化 |
| 1 | (合并到 init) | 核心类型 + 基础校验器 |
| 2 | `bf6b00a` | object schema + strict/passthrough 模式 |
| 3 | `fdc9741` | array, optional, default, enum, union, refine |
| 4 | `99cd546` | append_rule/inner_type 穿透、parse 分派重构、to_json_schema、benchmark |
| 5 | `2c333ad` | 可变路径栈、Strip 模式、union 错误聚合 |
| 6 | `9e309d4` | LLM 自愈 Demo、复杂 Benchmark（100k × 嵌套对象）、README 全面翻新 |
| 7 | `ead55a6` | 跨语言 Benchmark：TS Zod vs MoonZod Wasm vs Handcrafted Match |
| 8 | `c5c44fd` | parse_inner 隐藏、README 补全 Benchmark 数据、v0.1.0 发布封板 |
| 9 | `b5a2d1e` | 健壮性基准套件（Valid/Adversarial/Redundancy）+ 教育 Agent 3 轮自纠正 |
| 10 | `545fbd5` | JSON-to-Schema 代码生成器 CLI（递归 AST 遍历 + `@moon_zod` 源码输出）|
| 11 | `ef93d1a` | 生产级 CLI 升级（`@env.args()` + 键名安全转义 + 优雅错误处理）|
| 12 | `aee6143` | 零警告清理 + `ValidationError::to_string()` + README 完善 |
| 13 (v0.2.0) | `f6f4bf5` | 路径栈白盒测试 + `Schema::transform()` 数据变换管线 |
| 14 (v0.2.1) | `97b526a` | Bench 重构：迁移到 `@bench` 标准库（Valid/Adversarial/Redundancy 三场景）|
| 15 (v0.2.2) | `e320010` | JSON Schema 完整约束导出 + `to_json_schema_skeleton()` |

---

## 6. 测试概况

- **91 个黑盒测试**（`moon_zod_test.mbt`）+ **4 个白盒测试**（`moon_zod_wbtest.mbt`）= **95 个测试**
- 无外部依赖测试框架，使用 MoonBit 内建 `test` 块
- `parse_json()` 辅助函数用于从字符串构造 JSON（避免 `@json.parse` 的异常处理）
- 测试覆盖：
  - 每种 Schema 类型的正常/异常路径
  - 所有规则方法的通过/拒绝
  - 嵌套对象/数组的路径正确性
  - 装饰器穿透（`.optional().min()` 等）
  - Strip 模式行为
  - Path stack 白盒验证（成功/错误路径长度归零）
  - Transform 数据变换管线（成功、失败、链式组合）
  - 错误消息内容
  - to_json_schema 输出

**运行测试**: `moon test`（需在项目目录下）

---

## 7. 编码规范

1. **Block 风格**: 每个公共项前用 `///|` 分隔；block 间顺序无关
2. **Result 模式**: 所有校验返回 `Result[Json, Array[ValidationError]]`，**绝不 raise**
3. **pub 语义**: `pub` = 包内可见，`pub(all)` = 外部包可见。慎用 `pub` 暴露内部函数
4. **提交前**: 必须运行 `moon test && moon info && moon fmt`
5. **文件组织**: 每个工厂函数一个 `.mbt` 文件，对应规则方法写在同文件

---

## 8. 已知问题 / 未来方向

### 已知
- Wasm 基准通过子进程 + 启动开销抵扣估算，而非进程内精确计时（MoonBit wasm target 的限制）

> 编译器警告已在 Phase 12 全部消除（unused self × 4、unreachable_code × 1、Show deprecation × 30+）。  
> 白盒测试已在 Phase 13 新增（4 个 path_stack 不变性测试）。  
> 原生 Benchmark 已在 Phase 14 迁移至 `@bench` 标准库（校准 ns/op 指标）。

### 建议下一步
1. **多平台 CI**: 扩展 GitHub Actions 到 macos-latest / windows-latest
2. **refine 类型安全**: 允许用户定义 `refine<T>(fn(T) -> Bool)` 而不是 `fn(Json) -> Bool`
3. **Schema 组合器**: `Schema::or()`, `Schema::and()` 等
4. **错误本地化**: Error message 支持多语言模板
5. **derive 宏**: `derive(ZodSchema)` 从 MoonBit struct 自动生成 schema
6. **wasm-gc target**: 验证 `--target wasm-gc` 的兼容性并优化 instantiation 开销

---

## 9. 快速命令

```bash
moon test                          # 运行全部测试（85 tests, 0 warnings）
moon build                         # 编译库（0 warnings）
moon build --target wasm --release # 编译 Wasm benchmark
moon run cmd/main                  # 运行 MoonZod 吞吐 Benchmark（3 项）
moon run cmd/json2schema -- '{"hello":"world"}'  # JSON → @moon_zod 源码生成
moon run examples/llm_agent        # 运行 LLM 自愈 Demo
moon run examples/educational_agent # 运行教育 Agent 3 轮自纠正 Demo
moon run cmd/wasm -- moonzod       # Wasm 模式 moonzod 基准
moon run cmd/wasm -- handcrafted   # Wasm 模式手写 Match 基准
moon run cmd/wasm -- verify        # 验证两种实现输出一致
cd bench_cross_lang && node bench.js  # 三方语言对比 Benchmark
moon info && moon fmt              # 更新接口 + 格式化
```

---

*最后更新: 2026-06-09 | v0.2.2 发布 — Phase 1-15 全部完成*
