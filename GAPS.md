# Moon_Zod API 缺口分析与实现指南

**完整性评分: 85-90% (相比 Zod)**

---

## 📊 执行摘要

| 优先级 | 功能 | 影响 | 工作量 | 状态 |
|--------|------|------|--------|------|
| 🔴 **高** | 异步 parse 支持 | API 集成 | 中 | ❌ |
| 🟡 **中** | Lazy 类型 | 递归结构 | 中 | ❌ |
| 🟢 **低** | Discriminated Union 优化 | 性能 | 中 | ❌ |

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

### Lazy 类型 (`z.lazy()`)

**描述:** 延迟求值 Schema，支持递归和自引用

**在 Zod 中的用法:**
```typescript
type TreeNode = {
  value: number
  children?: TreeNode[]
}

const treeSchema: z.ZodType<TreeNode> = z.lazy(() =>
  z.object({
    value: z.number(),
    children: z.array(treeSchema).optional()
  })
)
```

**在 Moon_Zod 中的用法 (建议):**
```mbt nocheck
let rec tree_schema : @moon_zod.Schema = 
  @moon_zod.lazy(fn() {
    @moon_zod.object({
      "value": @moon_zod.number(),
      "children": @moon_zod.array(tree_schema).optional()
    })
  })

match tree_schema.parse(recursive_json) {
  Ok(tree) => // ...
  Err(errors) => // ...
}
```

**当前状态:**
- ❌ 无 `z.lazy()` 工厂函数
- ❌ 无递归 Schema 支持
- ⚠️ 可能通过 `refine()` 模拟，但不优雅

**实现要点:**
- [ ] 创建 `ZodLazy` 类型 (lazy.mbt)
- [ ] 延迟调用闭包直到 parse 时
- [ ] 支持自引用 Schema
- [ ] 循环引用检测 (可选，防止无限递归)
- [ ] 路径精度保持
- [ ] 导出支持 (JSON Schema 中 $ref 自引用)

**实现位置:** 新文件 `core/lazy.mbt`

**影响范围:**
- 树结构 (文件系统, DOM, AST)
- 图结构 (关系网络)
- 递归数据 (JSON 深嵌套)
- 语言语法定义

**估计工作量:** 150-250 行代码 + 测试

**参考文件:**
- `zod/src/types.ts` (ZodLazy)

---

### Discriminated Union 优化

**描述:** 带判别字段的 Union 快速路径，避免尝试所有选项

**在 Zod 中的用法:**
```typescript
const dogSchema = z.object({
  type: z.literal("dog"),
  bark: z.boolean()
})

const catSchema = z.object({
  type: z.literal("cat"),
  meow: z.boolean()
})

const petSchema = z.discriminatedUnion("type", [
  dogSchema,
  catSchema
])

// 直接根据 type 字段选择相应 schema，而不是尝试所有选项
petSchema.parse({ type: "dog", bark: true })
```

**在 Moon_Zod 中的当前实现:**
```mbt nocheck
let pet_schema = @moon_zod.union([
  dog_schema,
  cat_schema
])
// ❌ 尝试每个选项直到成功
```

**建议的改进:**
```mbt nocheck
let pet_schema = @moon_zod.discriminated_union("type", [
  ("dog", dog_schema),
  ("cat", cat_schema)
])
// ✓ 根据 type 字段直接查找对应 schema
```

**当前状态:**
- ✓ `union()` 已实现 (但无优化)
- ❌ `discriminated_union()` 未实现

**实现要点:**
- [ ] 创建 `ZodDiscriminatedUnion` 类型 (discriminated_union.mbt)
- [ ] 构建判别字段→Schema 映射
- [ ] 在 parse 时提取判别字段
- [ ] 根据值直接查找对应 Schema
- [ ] 错误消息改进 (说明预期的判别值)
- [ ] JSON Schema 导出支持

**性能改进:**
```
union([A, B, C, D])
  尝试数: 平均 2.5 (失败后才回退)
  
discriminated_union("type", [...])
  尝试数: 恒定 1 (直接查找)
```

**影响范围:**
- API 响应多态 (成功/错误/进度)
- LLM 多输出格式
- 事件流处理 (不同事件类型)

**估计工作量:** 200-300 行代码 + 测试

**参考文件:**
- `zod/src/types.ts` (ZodDiscriminatedUnion)

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

**全局 error map**
> `ZodErrorMap` 支持自定义错误消息
**JSON 高级类型支持**
> `z.date()`, `z.promise()`, `z.function()`, `z.map()`, `z.set()`
**object方法增强**
> `.deepPartial()`
**解析增强**
> `.safeParse()`, `.safeParseAsync()`
**验证增强**
> `.superRefine()`

**最后更新:** 2026-07-10
**文档版本:** 2.0
