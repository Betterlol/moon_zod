# Moon_Zod API 缺口分析与实现指南

**完整性评分: 90-95% (相比 Zod)**

---

## 📊 执行摘要

| 优先级 | 功能 | 影响 | 工作量 | 状态 |
|--------|------|------|--------|------|
| 🔴 **高** | 异步 parse 支持 | API 集成 | 中 | ❌ |
| 🟡 **中** | ~~Lazy 类型~~ | 递归结构 | 中 | ✅ Phase 43 |
| 🟢 **低** | ~~Discriminated Union~~ | 性能 | 中 | ✅ Phase 43 |

---

## 🔴 高优先级缺口

### 异步 Parse 支持

**描述:** 支持异步验证和转换 (Promise-returning refine/transform)

**在 Zod 中的用法:**
```typescript
const schema = z.object({
  username: z.string().refine(async (val) => {
    const exists = await checkUsernameExists(val)
    return !exists
  }, "Username already taken")
})

const result = await schema.parseAsync({ username: "john" })
```

**在 Moon_Zod 中的用法 (建议):**
```mbt nocheck
let schema = @moon_zod.object({
  "username": @moon_zod.string()
    .refine_async(fn(username) {
      // 返回 Future[Result[Unit, String]]
      check_username_exists(username)
    }, "Username already taken")
})

match schema.parse_async(json_obj) {
  Ok(data) => // 等待所有异步验证
  Err(errors) => // 收集错误
}
```

**当前状态:**
- ❌ `.refine()` 返回 `(Json) -> Bool`
- ❌ `.transform()` 返回 `Result[Json, String]`
- ❌ 无 `.parse_async()` 方法

**实现要点:**
- [ ] 扩展 Schema 支持异步效果
- [ ] `refine_async()` 方法: `(Json) -> Future[Result[Unit, String]]`
- [ ] `transform_async()` 方法: `(Json) -> Future[Result[Json, String]]`
- [ ] `parse_async()` 方法: 并发执行异步检查
- [ ] `safe_parse_async()` 方法: 返回 Result
- [ ] 错误聚合: 收集所有异步错误

**实现策略:**
1. 添加 `AsyncEffect` 类型到 Schema enum
2. 扩展 `_parse_impl()` 以支持 async 路径
3. 创建 async parse 实现 (async_parse.mbt)
4. 使用 MoonBit 的 Future/Async 库

**影响范围:**
- API 验证 (检查重复的 username/email)
- 外部服务调用 (地理编码、费率检查)
- 数据库查询 (外键验证)
- LLM 代理工作流

**估计工作量:** 400-600 行代码 + 测试

**参考文件:**
- `zod/src/types.ts` (ZodType._parseAsync)

---

## 🟡 中优先级缺口

### ~~Lazy 类型 (`z.lazy()`)~~ ✅ Phase 43 已交付

**描述:** 延迟求值 Schema，支持递归和自引用

**当前状态:**
- ✅ `pub fn recursive(fn() -> Schema)` 工厂（别名 `recursive`，因 `lazy` 是 MoonBit 保留字）
- ✅ `LazyType(() -> Schema)` SchemaType 变体
- ✅ 支持自引用树结构（函数式模式：`fn tree() -> Schema { recursive(fn() { object({...}) }) }`）
- ✅ 路径精度保持
- ✅ 导出支持（解析闭包后递归渲染）
- ✅ 5 个测试，524/524 通过

**已知限制:**
- 无 memoization，每次 parse O(depth) 创建新 Schema 对象（MoonBit `lazy` 关键字已预留但未实现）
- 导出时 JSON Schema 自引用（`$ref`）需用户通过 `.name()` 手动标记

---

### ~~Discriminated Union 优化~~ ✅ Phase 43 已交付

**描述:** 带判别字段的 Union 快速路径，避免尝试所有选项

**当前状态:**
- ✅ `pub fn discriminated_union(discriminator, options: Map[String, Schema])` 工厂
- ✅ `DiscriminatedUnionType(String, Map)` SchemaType 变体
- ✅ O(1) 分支分发（Map 直接查找）
- ✅ 精确错误码：`MissingRequired` / `InvalidValue` / `InvalidType`
- ✅ 5 个测试，524/524 通过

**已知限制:**
- JSON Schema/Prompt 导出退化为普通 union，丢失判别信息（需 renderer trait 扩展，独立工程量）

---

## ⚪ 低优先级缺口 (可选)

### Date 类型 (`z.date()`)

**描述:** 本机日期对象验证

**为什么 Moon_Zod 中低优先级:**
- JSON 标准不支持日期类型 (仅字符串)
- 已有 `.datetime()` 字符串验证
- 跨语言 JSON 交换中无价值

**当前替代方案:**
```mbt nocheck
@moon_zod.string().datetime()  // ISO 8601 验证
```

**如果需要实现:**
- [ ] `date()` 工厂函数
- [ ] JSON 解析: 字符串 → 日期对象
- [ ] JSON 导出: 日期对象 → ISO 字符串
- [ ] 日期范围验证 (min/max)

**估计工作量:** 150-200 行代码

---

### Promise 类型 (`z.promise()`)

**描述:** 验证 Promise 对象本身 (不是其解决值)

**为什么不适用:**
- JSON 无法表示 Promise
- LLM 输出永远不会是 Promise
- `parseAsync()` 已覆盖异步需求

---

### Function 类型 (`z.function()`)

**描述:** 验证函数签名

**为什么不适用:**
- JSON 无法表示函数
- LLM 不生成函数代码
- 可通过字符串代码验证 + eval (危险)

---

### Map / Set 类型

**描述:** JSON 不原生支持的类型

**为什么不建议实现:**
- JSON 标准不包含这些类型
- 跨语言序列化困难
- 使用字符串或对象表示替代

---

## 🧪 测试策略

每个新功能都应包括:

1. **正常路径测试** - 有效输入
2. **错误路径测试** - 无效输入、类型错误
3. **路径精度测试** - 错误位置正确 (`path` 字段)
4. **边界测试** - 空、嵌套、大数据
5. **导出测试** - JSON Schema, TypeScript 接口
6. **性能测试** - 基准对比

---

## 📚 参考资源

### Zod 源代码参考
- **Tuple 实现**: `zod/src/types.ts` → `class ZodTuple`
- **Lazy 实现**: 同上 → `class ZodLazy`
- **Discriminated Union**: 同上 → `class ZodDiscriminatedUnion`
- **Async parse**: 同上 → `_parseAsync()` 方法

### Moon_Zod 现有模式参考
- **对象实现**: `core/object.mbt` (mode 处理、pick/omit 模式)
- **Union 实现**: `core/union.mbt` (多选项尝试)
- **String 验证**: `core/string.mbt` (规则链、错误消息)
- **导出系统**: `exporters/json_schema.mbt` (模式遍历)

---

## 其他缺口

**☑ IssueCode + ErrorMap — Phase 42 已交付**
> `ValidationError.code: IssueCode` (12 variants), `Schema::safe_parse(json, ParseParams)` with context `ErrorMap`. No global error map by design (MoonBit module idiom: pass fn explicitly). See `branch_doc/DECISION_ERROR_SYSTEM.md`.
**JSON 高级类型支持**
> `z.date()`, `z.promise()`, `z.function()`, `z.map()`, `z.set()`
**object方法增强**
> `.deepPartial()`
**解析增强**
> `.safeParse()`, `.safeParseAsync()`
**验证增强**
> `.superRefine()`

**最后更新:** 2026-07-18
**文档版本:** 2.1
