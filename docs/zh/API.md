## API 参考

### 工厂函数

| 函数 | 描述 |
|---|---|
| `string(required_error?, invalid_type_error?)` | 校验 JSON 字符串 |
| `number(required_error?, invalid_type_error?)` | 校验 JSON 数字 |
| `boolean(required_error?, invalid_type_error?)` | 校验 JSON 布尔值 |
| `null(required_error?, invalid_type_error?)` | 校验 JSON null |
| `array(Schema, required_error?, invalid_type_error?)` | 校验数组，递归检查元素 |
| `object(Map[String, Schema], required_error?, invalid_type_error?)` | 校验对象。**默认：Strip 模式** |
| `enum_values(Array[String], required_error?, invalid_type_error?)` | 固定的允许字符串值集合（混合类型请使用 `literal()` + `union()`） |
| `literal(Json, required_error?, invalid_type_error?)` | **Phase 32**: 常量值校验 — 仅接受精确的 JSON 匹配（字符串、数字、布尔值、null、数组或对象） |
| `union(Array[Schema], required_error?, invalid_type_error?)` | 联合类型 — 如果任何 schema 匹配则通过 |
| `intersection(Array[Schema], required_error?, invalid_type_error?)` | **Phase 18**: 交集 — 如果所有 schema 都匹配则通过；对象字段被合并 |

### Schema 方法

| 方法 | 适用于 | 描述 |
|---|---|---|
| `.parse(Json, path?)` | 全部 | 校验，返回 `Ok(Json)` 或 `Err(Array[ValidationError])` |
| `.min(n[, msg])` | string / number / array | 最小长度 / 值 |
| `.max(n[, msg])` | string / number / array | 最大长度 / 值 |
| `.length(n[, msg])` | string / array | 精确长度 |
| `.nonempty([msg])` | string | 字符串不能为空 |
| `.email([msg])` | string | 完整邮箱校验（引号本地部分、IP 字面量、+tag、TLD≥2、单个 @） |
| `.url([msg])` | string | 完整 URL 结构：`scheme://host[:port][/path][?query][#fragment]` |
| `.regex(pattern[, msg])` | string | 必须包含 `pattern` 作为子字符串 |
| `.startsWith(prefix[, msg])` | string | 必须以 `prefix` 开头 |
| `.endsWith(suffix[, msg])` | string | 必须以 `suffix` 结尾 |
| `.includes(substring[, msg])` | string | 必须包含 `substring` |
| `.uuid([msg])` | string | 必须是有效的 UUID v4 |
| `.cuid([msg])` | string | 必须是有效的 CUID（c + base36 哈希） |
| `.datetime([msg])` | string | 必须是 ISO 8601 日期时间（date + T + time ± offset/Z） |
| `.ip([msg])` | string | 必须是有效的 IPv4 或 IPv6 地址 |
| `.ipv4([msg])` | string | 必须是有效的 IPv4 地址 |
| `.ipv6([msg])` | string | 必须是有效的 IPv6 地址（完整/简写形式，支持 ::） |
| `.ulid([msg])` | string | 必须是有效的 ULID（26 字符 Crockford base32） |
| `.int([msg])` | number | 必须是整数（无小数部分） |
| `.positive([msg])` | number | 必须 > 0 |
| `.negative([msg])` | number | 必须 < 0 |
| `.multipleOf(n[, msg])` | number | 必须是 `n` 的倍数 |
| `.finite([msg])` | number | 必须是有限数（不是 NaN，不是 ±Infinity） |
| `.safe([msg])` | number | 必须是安全整数（不是 NaN，不是 ±Infinity，无小数部分） |
| `.optional()` | 任意 | null 或缺失值跳过校验 |
| `.default(value)` | 任意 | 用默认值替换 null |
| `.strict()` | object | 拒绝未定义的字段 |
| `.passthrough()` | object | 保持未定义的字段不变 |
| `.strip()` | object | 无声地移除未定义的字段（默认） |
| `.describe(text)` | 任意 | **Phase 17**: 附加描述，由 `schema_to_prompt()` 为 LLM 提示渲染 |
| `.message(text)` | 任意 | **Phase 19**: 覆盖最后一条规则的错误消息 |
| `.name(text)` | 任意 | **Phase 25**: 为 schema 导出和代码生成分配名称 |
| `.intersect(other)` | 任意 | **Phase 18**: 交集：输入必须匹配两个 schema；对象字段被合并 |
| `.pick(keys)` | object | **Phase 21**: 仅选择指定字段 |
| `.omit(keys)` | object | **Phase 21**: 移除指定字段 |
| `.partial()` | object | **Phase 21**: 使所有字段可选 |
| `.refine(check, msg)` | 任意 | 自定义校验谓词 |
| `.transform(fn)` | 任意 | **Phase 13**: 校验然后通过 `(Json) -> Result[Json, String]` 转换输出 |

### 独立函数

| 函数 | 描述 |
|---|---|
| `schema_to_prompt(Schema)` | **Phase 16**: 为 LLM 生成 TypeScript 接口提示字符串（含约束注释）— 内联展开 |
| `schema_to_prompt_named(Schema, include_names?)` | **Phase 25, 34**: 从命名 schema 生成模块化 TypeScript 接口，含拓扑排序和类型名称引用 |
| `to_json_schema(Schema)` | **Phase 15**: 导出标准 JSON Schema 对象，含完整约束注解 |
| `to_json_schema_skeleton(Schema)` | **Phase 15**: 导出轻量级 JSON Schema 骨架（仅结构，无约束） |
| `to_json_schema_named(Schema, include_names?)` | **Phase 26, 34**: 导出命名 schema 为独立的 JSON Schema 定义，含 `$defs` 和 `$ref` |
| `json_schema_to_moon_zod(Json)` | **Phase 27, 36**: 反向生成 moon_zod Schema 源代码；支持 `$defs`、`$ref`、约束、格式验证 |
| `schema_to_moonbit_struct(Schema)` | **Phase 28**: 从 ObjectType/EnumType 生成 MoonBit 结构体定义（类型名、字段、约束） |
| `schema_to_moonbit_struct_full(Schema)` | **Phase 29**: 生成结构体定义 + `from_json()` 函数用于类型安全的 JSON → 结构体转换 |
| `schema_to_moonbit_struct_named(Schema, include_names?)` | **Phase 31**: 同 `schema_to_moonbit_struct()`，但提取并拓扑排序所有嵌套命名 schema |
| `schema_to_moonbit_struct_named_full(Schema, include_names?)` | **Phase 31**: 同 `schema_to_moonbit_struct_full()`，但提取所有嵌套命名 schema |
| `schema_to_moon_zod_code(Schema)` | 从 Schema 生成 moon_zod schema 源代码 |
| `schema_to_moon_zod_code_named(Schema, include_names?)` | 生成带命名 `$defs` 和 `$ref` 引用的 moon_zod schema 源代码 |
| `json_schema_to_schema(Json)` | 反向解析 JSON Schema 对象为 moon_zod Schema |
| `json_infer_schema(Json)` | 从样本 JSON 值推断 moon_zod Schema |
| `append_rule(Schema, (Json) -> Bool, String)` | 向 schema 追加原始验证规则 |
| `append_rule_with_annotation(Schema, (Json) -> Bool, String, Json)` | 追加带注解负载的验证规则 |
| `format_path(Array[String])` | 将路径栈连接为点号记号字符串 |
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
```