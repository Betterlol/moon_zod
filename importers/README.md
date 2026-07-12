# importers

JSON Schema → moon_zod Schema 导入工具包。

本包提供 **JSON Schema draft-07 → moon_zod @core.Schema** 的运行时转换能力，是四层架构中的第一层（Input → IR）。转换结果可直接用于 `schema.parse()` 运行时校验，或送入 exporters 做进一步代码/Schema 导出。

---

## 公开 API

- `json_schema_to_schema(schema : Json) -> @core.Schema` — 将 JSON Schema 文档（draft-07）解析为 moon_zod 运行时 Schema 对象

> **注意**：`json_schema_to_moon_zod()` 定义在 `combinators/` 包，不在本包。它先调用本包的 `json_schema_to_schema()` 转为 Schema 对象，再调用 `exporters/schema_exporter.mbt` 生成源码。

---

## 文件结构

```
importers/
├── from_json_schema.mbt  # json_schema_to_schema() 单文件实现
├── moon.pkg              # 包声明（仅依赖 core + moonbitlang/core/json）
└── pkg.generated.mbti    # moon info 生成的接口描述（勿手动编辑）
```

---

## 实现说明

### 架构

本包采用**单文件、递归下降**解析器架构：

```
JSON Schema (Json)
    │
    ▼
extract_defs()          ── 提取 $defs / definitions
    │
    ▼
json_to_schema_impl()   ── 递归 match JSON Schema 关键字
    │                       分发到对应的 @core.Schema 工厂
    ▼
@core.Schema            ── 可直接用于 schema.parse() 的运行时对象
```

### 处理流程

`json_to_schema_impl()` 按以下优先级依次匹配：

1. **`$ref`** — 从 `$defs` / `definitions` 缓存或前向引用解析；循环引用用 `null().name(ref_name)` 占位
2. **`const`** — 直接映射为 `@core.literal(val)`
3. **`enum`** — 全字符串 → `enum_values(strs)`；全数字 → `number()` + 自定义规则校验；混合/布尔/null → `union(values.map(literal))`
4. **`type`** — 映射基础类型 + `properties` / `items` / `required` 递归处理
5. **`anyOf` / `allOf` / `oneOf`** — 映射为 `union()` / `intersection()`

### 类型映射

| JSON Schema type | moon_zod Schema | 备注 |
|-----------------|-----------------|------|
| `string` | `@core.string()` | |
| `number` | `@core.number()` | |
| `integer` | `@core.number().int()` | |
| `boolean` | `@core.boolean()` | |
| `null` | `@core.null()` | |
| `object` | `@core.object(fields)` | `required` 数组决定 optional |
| `array` | `@core.array(elem)` | `items` 指定元素类型 |
| `enum` (全字符串) | `@core.enum_values(strs)` | |
| `enum` (全数字) | `@core.number()` + 自定义规则 | |
| `enum` (混合/布尔/null) | `@core.union(values.map(literal))` | |
| `const` | `@core.literal(val)` | |
| `anyOf` | `@core.union(parts)` | |
| `allOf` | `@core.intersection(parts)` | |
| `oneOf` | `@core.union(parts)` | 与 anyOf 等价 |

### Object Mode 映射

| JSON Schema additionalProperties | moon_zod ObjectMode |
|--------------------------------|---------------------|
| `true` | `Passthrough` — 保留未知字段 |
| `false` | `Strip`（默认）— 剥离未知字段 |
| 省略 | `Strip`（默认） | |

### 约束关键字映射

| JSON Schema 关键字 | moon_zod 方法 | 备注 |
|--------------------|---------------|------|
| `minLength` | `.min(n)` | 字符串/数组长度 |
| `maxLength` | `.max(n)` | 字符串/数组长度 |
| `pattern` | `.regex(pattern)` | |
| `format: email` | `.email()` | |
| `format: uri` | `.url()` | |
| `format: date-time` | `.datetime()` | |
| `format: ipv4` | `.ipv4()` | |
| `format: ipv6` | `.ipv6()` | |
| `format: uuid` | `.uuid()` | |
| `minimum` | `.min(n)` | **⚠️ 浮点数截断为整数** |
| `maximum` | `.max(n)` | **⚠️ 浮点数截断为整数** |
| `exclusiveMinimum` | `.positive()` / `.min(n+1)` + 非整数精确规则 | |
| `exclusiveMaximum` | `.negative()` / `.max(n-1)` + 非整数精确规则 | |
| `multipleOf` | `.multipleOf(n)` | |
| `minItems` | `.min(n)` | 数组最小长度 |
| `maxItems` | `.max(n)` | 数组最大长度 |
| `default` | `.default(val)` | |

### 循环引用处理

- `$defs` 首次遍历时预填充缓存
- `$ref` 前向引用：递归处理目标定义后再返回
- 循环引用检测：`visiting` 数组记录当前 DFS 路径，重复访问时返回 `null().name(name)` 占位

---

## 已知限制

- **@moon_zod.enum_values() 限制**：`enum_values()` 目前仅支持全字符串的枚举，混合类型枚举会被降级为 `@core.union()`，并且数字枚举会被降级为 `@core.number()` + 自定义规则校验。
> 有点丑陋，但目前还能接受，后续实现升级即可。
- **`minimum` / `maximum` 浮点数截断**：`minimum: 1.5` 经 `.to_int()` 变为 `.min(1)`，允许 `1.0` 通过。与 `exclusiveMinimum` 不同，此处未做非整数精确规则补救。如需精确浮点边界，建议在 JSON Schema 中使用 `exclusiveMinimum` / `exclusiveMaximum` 配合整数边界，或手动用 `refine()` 补充校验。
- **`$ref` 引用缺失定义**：如果 `$ref` 指向的 key 在 `$defs` 中不存在，回退为 `@core.string()`，不报错。
- **复杂 `format`**：仅支持 `email` / `uri` / `date-time` / `ipv4` / `ipv6` / `uuid`，其余 format 关键字静默忽略。
- **`readOnly` / `writeOnly`**：未映射。
- **`$schema` / `$id` 等元数据**：忽略。
