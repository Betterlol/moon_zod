# moon_zod 设计文档

## 项目定位

MoonBit 版的 Zod/Pydantic——一个**运行时 JSON Schema 校验库**，核心场景是为 LLM Tool Calling 的输出做结构化校验和错误回溯。

---

## API 设计目标

```mbt
// 最终用户代码风格
let schema = @moon_zod.object({
  "name": @moon_zod.string().min(2).max(50),
  "age": @moon_zod.number().int().min(0).max(150),
  "email": @moon_zod.string().email(),
})

let result = schema.parse(json_data)
// result: Result[Json, Array[ValidationError]]
```

---

## 实施阶段

### Phase 1：核心类型 + 基础校验器

**文件**: `schema.mbt` / `types.mbt`

定义核心类型系统：

```
Schema[T]     — 校验器 trait/struct，携带校验规则
ValidationError — 错误类型，包含 field path + message + 期望值/实际值
SchemaResult[T] — type alias for Result[T, Array[ValidationError]]
```

基础校验器工厂函数：

| 函数 | 规则链方法 |
|---|---|
| `string()` | `.min(n)` `.max(n)` `.email()` `.url()` `.regex(pattern)` `.nonempty()` |
| `number()` | `.min(n)` `.max(n)` `.int()` `.positive()` `.negative()` `.multipleOf(n)` |
| `boolean()` | (无链式规则) |
| `null()` | — |
| `array(schema)` | `.min(n)` `.max(n)` `.nonempty()` |
| `object(spec)` | 见下 |

**关键设计决策**：
- 每个 Schema 是一个 struct，内部存储 `rules: Array[Rule]`。Rule 是一个函数类型 `(Json) -> Result[Json, ValidationError]`。
- 链式调用 `.min(2).max(10)` 只是往 rules 里 push 新 rule，返回 self。
- `parse(json)` 遍历 rules 依次执行。

### Phase 2：Object Schema 与字段级错误

**文件**: `object.mbt`

```mbt
pub fn object(spec: Map[String, Schema]) -> Schema
```

- parse 时遍历 spec 的每个 key，用对应 Schema 校验。
- 收集所有字段的错误，而非 fail-fast（一次性返回所有错误，方便 LLM 修正）。
- 支持 `.strict()`（拒绝未在 spec 中定义的字段）和 `.passthrough()`（默认，保留额外字段）。

### Phase 3：高级特性

- **可选字段**：`.optional()` → 值为 Null 或缺失时跳过校验。
- **默认值**：`.default(value)` → 缺失时填充默认值。
- **枚举校验**：`.enum(["a", "b", "c"])`。
- **联合类型**：`.union([schema1, schema2])` → 任一通过即成功。
- **自定义规则**：`.refine(fn) →` 用户注入自定义校验逻辑。
- **JSON Schema 导出**：`schema.to_json_schema()` → 输出标准 JSON Schema 字符串，可供 LLM 直接使用。

### Phase 4：Polish（竞赛加分项）

- **错误信息人类可读**：错误路径用 `"name"`, `"address.city"` 格式。
- **性能 Benchmark**：对比手写 `match` 校验 + 对比 TypeScript Zod（展示 MoonBit 优势）。
- **README 文档**：完整的中英文 Example + API 文档 + 设计思路。
- **测试覆盖**：每个规则独立测试 + RFC 官方 JSON Schema 测试套件子集。

---

## 项目结构建议

```
moon_zod/
├── moon_zod.mbt          # re-export 所有公开 API
├── types.mbt              # Schema, ValidationError, SchemaResult
├── string.mbt             # string() schema + 规则链
├── number.mbt             # number() schema + 规则链
├── boolean.mbt            # boolean() schema
├── null.mbt               # null() schema
├── array.mbt              # array() schema + 规则链
├── object.mbt             # object() schema + 规则链
├── union.mbt              # union() / optional() / default()
├── refine.mbt             # .refine() 自定义规则
├── json_schema.mbt        # to_json_schema() 导出
├── deprecated.mbt         # 废弃的旧 API
├── moon_zod_test.mbt      # 黑盒测试
├── moon_zod_wbtest.mbt    # 白盒测试
└── cmd/main/main.mbt      # CLI demo / 调试入口
```

---

## MoonBit 编码要点

1. **Block 风格**：每个公共函数/类型前用 `///|` 分隔，顺序无关。
2. **Result 模式**：所有可能失败的校验返回 `Result[Json, Array[ValidationError]]`，不要 raise。
3. **Trait 扩展**：利用 MoonBit 的 `derive` 机制，未来可考虑 `derive(ZodSchema)` 的宏（Phase 5+）。
4. **测试优先**：每个 rule 的实现 → 立即写 test（`_test.mbt` 测公开 API，`_wbtest.mbt` 测内部 helper）。
5. **提交前**：始终 `moon info && moon fmt`，检查 `.mbti` 变更是否符合预期。

---

## 参考

- [Zod](https://zod.dev/) — TypeScript 版参考 API
- [Pydantic](https://docs.pydantic.dev/) — Python 版参考
- MoonBit core `@json` 包 — 了解当前 JSON 类型系统
