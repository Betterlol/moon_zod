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
- **详细错误**：每个字段都有路径、消息和接收值