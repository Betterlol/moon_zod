# moon_zod 设计文档

## 项目定位

MoonBit 版的 Zod/Pydantic——一个**运行时 JSON Schema 校验库**，核心场景是为 LLM Tool Calling 的输出做结构化校验和错误回溯。

> #### 设计哲学与战略优势
> `moon_zod` 不追求成为一个包罗万象的通用数据验证框架，而是致力于成为**最适合 LLM 智能体运行时的结构化数据引擎**。核心优势建立在三个不可妥协的架构基石之上：
> 1. **LLM 幻觉防御优先** — `object()` 默认 **Strip（清洗）模式**，以 $O(spec)$ 复杂度进行数据提取，确保下游接手干净、确定的数据。
> 2. **极致的性能与惰性路径格式化** — 共享可变路径栈 (`path_stack: Array[String]`)，成功校验路径上**零字符串格式化开销**。
> 3. **极简 API 与无缝组合** — `append_rule` 装饰器穿透机制使 `string().optional().min(3)` 符合直觉。

> #### 明确的非目标
> - **拒绝重型生态绑定**：不引入 ORM 或 GraphQL 转换，0 外部依赖。
> - **拒绝异步校验**：纯同步校验，保持 WASM 运行时速度和架构简单性。
> - **拒绝臃肿的类型推演**：在 MoonBit 宏系统成熟前，不强行模拟 `z.infer`。

---

## 核心架构设计

### 1. parse 路由 + 可变路径栈

```
Schema::parse(json)                   ← 公共入口，创建 path_stack
  └─ parse_inner(schema, json, stack) ← 内部转发枢纽（非 pub）
       ├─ parse_object()              ← push/pop 字段名
       ├─ parse_array()               ← push/pop [索引]
       ├─ parse_optional()            ← 直接传递 stack
       ├─ parse_default()             ← 直接传递 stack
       ├─ parse_transform()           ← 先校验 inner，再应用变换
       ├─ parse_enum()                ← format_path 后报错
       ├─ parse_union()               ← 直接传递 stack
       ├─ parse_intersection()        ← 直接传递 stack，合并对象字段
       └─ 基本类型检查                ← format_path 后报错
```

路径栈 (`Array[String]`) 在所有 parse helper 间共享，进入子结构 `push` / 返回 `let _ = pop()`。仅在产生 `ValidationError` 时调用 `format_path(stack)` 拼接字符串。**成功路径零堆分配**。

### 2. append_rule — 装饰器穿透

```
pub fn append_rule(schema, check, message) -> Schema {
  match schema.schema_type {
    OptionalType(inner)  => 递归到 inner，新建 OptionalType 包裹
    DefaultType(inner,_) => 递归到 inner，新建 DefaultType 包裹
    _ => 直接追加到 rules
  }
}
```

使 `string().optional().min(3)` 的 `min(3)` 规则穿透 OptionalType 落在 StringType 上。`description` 在穿透时正确保留。

### 3. Strip 默认模式

`object()` 默认 `Strip` 模式。parse 成功后只返回 spec 定义的字段（已递归校验清洗的值），未定义字段静默移除。嵌套对象递归剥离。

### 4. Union 错误聚合

所有分支失败时，聚合各分支第一个错误消息：
```
"Expected union type, but all branches failed. Branches: [Expected string, Expected number]"
```

### 5. Intersection 对象字段合并

`intersection()` 对 ObjectType 字段做 map-level 合并。非对象类型取第一个匹配值。

### 6. Schema 组合器 — pick / omit / partial

- `pick(keys)` — 按 key 列表过滤 Object spec，保留 mode / rules / description
- `omit(keys)` — 排除指定 key
- `partial()` — 将所有字段包裹在 `OptionalType` 中

均保持原 schema 的 object mode（Strip/Passthrough/Strict）。

### 7. JSON Schema 导出

`to_json_schema()` 递归遍历 SchemaType：
- OptionalType/DefaultType → 透明穿透（不产生 `oneOf`）
- Strip/Passthrough → `"additionalProperties": true`
- Strict → `"additionalProperties": false`
- 每个 Rule 的 `annotation` 字段作为约束注解合并到输出

---

## Demo/Example 编写规范

| 场景 | 方式 | 原因 |
|---|---|---|
| `examples/` 展示 | **Real LLM** | 给别人看的 demo，真实调用才有说服力 |
| 测试文件 | **Mock** | 确定性、快、不依赖网络 |
| CI / 回归测试 | **Mock** | 精确覆盖边界 case |
| Benchmarks | **Mock** | 控制变量，排除干扰 |

---

## 编码要点

1. **Block 风格**：每个公共函数/类型前用 `///|` 分隔，顺序无关。
2. **Result 模式**：`parse()` 返回 `Result[Json, Array[ValidationError]]`，绝不 raise。构造方法对类型误用允许 `abort()`，视为编程错误。
3. **pub 语义**：`pub` = 包内可见，`pub(all)` = 外部包可见。
4. **测试优先**：每个 rule 的实现 → 立即写 test。
5. **提交前**：`moon test && moon info && moon fmt`，检查 `.mbti` 变更。

---

## 参考

- [Zod](https://zod.dev/) — TypeScript 版参考 API
- [Pydantic](https://docs.pydantic.dev/) — Python 版参考
- MoonBit core `@json` 包 — 了解当前 JSON 类型系统


