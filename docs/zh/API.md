## API 参考

### 工厂函数

| 函数 | 描述 |
|---|---|
| `string(required_error?, invalid_type_error?)` | 校验 JSON 字符串 |
| `number(required_error?, invalid_type_error?)` | 校验 JSON 数字 |
| `boolean(required_error?, invalid_type_error?)` | 校验 JSON 布尔值 |
| `null(required_error?, invalid_type_error?)` | 校验 JSON null |
| `array(Schema, required_error?, invalid_type_error?)` | 校验数组，递归检查元素 |
| `tuple([Schema...], required_error?, invalid_type_error?)` | **Phase 38**：固定长度数组 — 按位置校验每个元素 |
| `object(Map[String, Schema], required_error?, invalid_type_error?)` | 校验对象。**默认：Strip 模式** |
| `enum_values(Array[String], required_error?, invalid_type_error?)` | 固定的允许字符串值集合 |
| `literal(Json, required_error?, invalid_type_error?)` | **Phase 32**：常量值校验 — 仅接受完全匹配的 JSON |
| `bigint(required_error?, invalid_type_error?)` | **Phase 37**：`number().int()` 的语义别名 — 表示大整数意图 |
| `any(required_error?, invalid_type_error?)` | **Phase 39**：接受任何 JSON 值（透传） |
| `unknown(required_error?, invalid_type_error?)` | **Phase 39**：接受任何 JSON 值作为未知类型（语义标记） |
| `preprocess((Json) -> Result[Json, String], Schema, required_error?, invalid_type_error?)` | **Phase 39**：先转换原始输入，再针对内部 schema 进行校验 |
| `union(Array[Schema], required_error?, invalid_type_error?)` | 联合类型 — 如果任何 schema 匹配则通过 |
| `intersection(Array[Schema], required_error?, invalid_type_error?)` | **Phase 18**：交集 — 如果所有 schema 都匹配则通过；对象字段合并 |

### Schema 方法

| 方法 | 适用范围 | 描述 |
|---|---|---|
| `.parse(Json, path?)` | 全部 | 校验，返回 `Ok(Json)` 或 `Err(Array[ValidationError])` |
| `.min(n[, msg])` | string / number / array | 最小长度 / 值 |
| `.max(n[, msg])` | string / number / array | 最大长度 / 值 |
| `.length(n[, msg])` | string / array / tuple | 精确长度 |
| `.nonempty([msg])` | string / array / tuple | 不能为空 |
| `.email([msg])` | string | 完整邮箱校验 |
| `.url([msg])` | string | 完整 URL 结构校验 |
| `.regex(pattern[, msg])` | string | 必须包含 `pattern` 作为子字符串 |
| `.startsWith(prefix[, msg])` | string | 必须以 `prefix` 开头 |
| `.endsWith(suffix[, msg])` | string | 必须以 `suffix` 结尾 |
| `.includes(substring[, msg])` | string | 必须包含 `substring` |
| `.trim()` | string | **Phase 37**：删除首尾空格 |
| `.to_lower()` | string | **Phase 37**：转换为小写 |
| `.to_upper()` | string | **Phase 37**：转换为大写 |
| `.uuid([msg])` | string | 必须是有效的 UUID v4 |
| `.cuid([msg])` | string | 必须是有效的 CUID |
| `.datetime([msg])` | string | 必须是 ISO 8601 日期时间 |
| `.ip([msg])` | string | 必须是有效的 IPv4 或 IPv6 |
| `.ipv4([msg])` | string | 必须是有效的 IPv4 |
| `.ipv6([msg])` | string | 必须是有效的 IPv6 |
| `.ulid([msg])` | string | 必须是有效的 ULID |
| `.int([msg])` | number | 必须是整数 |
| `.positive([msg])` | number | 必须 > 0 |
| `.negative([msg])` | number | 必须 < 0 |
| `.multipleOf(n[, msg])` | number | 必须是 `n` 的倍数 |
| `.finite([msg])` | number | 必须是有限数 |
| `.safe([msg])` | number | 必须是安全整数 |
| `.optional()` | any | Null 或缺失值跳过校验 |
| `.default(value)` | any | 用默认值替换 null |
| `.strict()` | object | 拒绝未定义的字段 |
| `.passthrough()` | object | 保持未定义的字段不变 |
| `.strip()` | object | 无声地删除未定义的字段（默认） |
| `.pick(keys)` | object | **Phase 21**：仅选择指定的字段 |
| `.omit(keys)` | object | **Phase 21**：删除指定的字段 |
| `.partial()` | object | **Phase 21**：使所有字段可选 |
| `.extend(Map[String, Schema])` | object | **Phase 38**：从 Map 中添加或覆盖字段 |
| `.merge(Schema)` | object | **Phase 38**：与另一个对象 schema 合并（右侧覆盖） |
| `.describe(text)` | any | **Phase 17**：为 LLM 提示附加描述 |
| `.name(text)` | any | **Phase 25**：为 schema 导出指定名称 |
| `.brand(text)` | any | **Phase 37**：为名义类型指定品牌标记 |
| `.message(text)` | any | **Phase 19**：覆盖最后一条规则的错误消息 |
| `.intersect(other)` | any | **Phase 18**：交集 — 输入必须同时匹配两个 schema |
| `.refine(check, msg)` | any | 自定义校验谓词 |
| `.transform(fn)` | any | **Phase 13**：校验后转换输出 |

### 独立函数

| 函数 | 描述 |
|---|---|
| `schema_to_prompt(Schema)` | **Phase 16**：为 LLM 工具调用生成 TypeScript 接口提示字符串 — 内联展开 |
| `schema_to_prompt_named(Schema, include_names?)` | **Phase 25, 34**：从命名 schema 生成模块化 TypeScript 接口 |
| `to_json_schema(Schema)` | **Phase 15**：导出包含完整约束注解的标准 JSON Schema |
| `to_json_schema_skeleton(Schema)` | **Phase 15**：导出轻量级 JSON Schema 骨架（仅结构） |
| `to_json_schema_named(Schema, include_names?)` | **Phase 26, 34**：将命名 schema 导出为 `$defs` 和 `$ref` |
| `json_schema_to_moon_zod(Json)` | **Phase 27, 36**：从 JSON Schema 反向生成 moon_zod 代码 |
| `schema_to_moonbit_struct(Schema)` | **Phase 28**：生成 MoonBit 结构体定义 |
| `schema_to_moonbit_struct_full(Schema)` | **Phase 29**：生成结构体 + `from_json()` 函数 |
| `schema_to_moonbit_struct_named(Schema, include_names?)` | **Phase 31**：从命名 schema 生成结构体 |
| `schema_to_moonbit_struct_named_full(Schema, include_names?)` | **Phase 31**：从命名 schema 生成结构体 + `from_json()` |
| `schema_to_moon_zod_code(Schema)` | 生成 moon_zod schema 源代码 |
| `schema_to_moon_zod_code_named(Schema, include_names?)` | 生成具有 `$defs` 和 `$ref` 的 moon_zod 代码 |
| `json_schema_to_schema(Json)` | 将 JSON Schema 反向解析为 moon_zod Schema |
| `json_infer_schema(Json)` | 从示例 JSON 值推断 moon_zod Schema |
| `append_rule(Schema, (Json) -> Bool, String)` | 追加原始校验规则 |
| `append_rule_with_annotation(Schema, (Json) -> Bool, String, Json)` | 追加具有注解载荷的规则 |
| `format_path(Array[String])` | 将路径栈连接为点号记法字符串 |
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

---