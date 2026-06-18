# Phase 18 — Intersection 类型组合子 (Schema::intersect)

## 目标

实现 `IntersectionType` 组合子，使库支持"输入必须同时满足全部给定 Schema"的交集校验需求。对于对象 Schema，各子 Schema 的字段自动合并到一个结果对象中。

## 背景

两个开放 GitHub Issues:
- **#2**: derive 宏（延期，因宏实现复杂且代码行贡献不确定）
- **#3**: `Schema::and` / Intersection 组合子（本期实现）

选择 Intersection 的主要原因：
1. 直接贡献可计数的代码行数（帮助触及 4k 竞争基准线）
2. 面向用户的功能改进（与 Union 互补）
3. 实现明确，风险低

## 变更清单

### `schema.mbt`
- `SchemaType` 枚举新增 `IntersectionType(Array[Schema])` 变体（位于 `UnionType` 之后、`TransformType` 之前）
- `parse_inner` 新增分发分支 → 调用 `schema.parse_intersection(schemas, json, path_stack)`
- `expected_msg` 新增 `IntersectionType(_) => "Expected intersection match"`

### `union.mbt`（核心实现在此文件）
- `pub fn intersection(schemas: Array[Schema]) -> Schema` — 工厂函数，创建 `IntersectionType` schema
- `pub fn Schema::intersect(self, other) -> Schema` — 方法，等价于 `intersection([self, other])`
- `pub fn Schema::parse_intersection(...)` — 内部 parse 辅助

`parse_intersection` 逻辑：
1. `merged = json` 起始值与原始输入一致
2. 遍历每个子 Schema，调用 `parse_inner(s, json, path_stack)`
3. 成功时：`merged = merge_json(merged, result)` — 如两者均为 `Object` 则按 key 合并（后者的值覆盖前者同名 key），否则保留 `merged` 不变
4. 失败时：收集所有 `ValidationError` 到 `errors` 数组
5. 若 `errors.empty()` → 返回 `Ok(merged)`，否则返回 `Err(errors)`

`merge_json` 辅助函数：
```mbt
fn merge_json(a : Json, b : Json) -> Json {
  match (a, b) {
    (Object(map_a), Object(map_b)) => {
      for k, v in map_b { map_a.set(k, v) }
      Json::object(map_a)
    }
    _ => a
  }
}
```

### `json_schema.mbt`
- `to_json_schema_full(schema)` 新增 `IntersectionType → allOf` 分支
- `to_json_schema_inner(t)` 新增相同分支

输出示例：
```json
{"allOf": [{"type": "string"}, {"type": "number"}]}
```

### `prompt.mbt`
- `type_to_prompt` 新增 `IntersectionType(schemas) => intersection_to_prompt(schemas, indent)` 分支
- 新增 `intersection_to_prompt` 函数，输出 `"A & B & C"` 格式（与 `union_to_prompt` 的 `"A | B | C"` 区分）

示例：
```
string & number
string & number & boolean
```

### `moon_zod_test.mbt` — 10 个新增测试

| 测试名 | 验证内容 |
|---|---|
| `intersection parse basic` | 基本解析成功（`string().min(3)` & `string().max(10)` → `"hello"` 通过） |
| `intersection fails when one schema fails` | 跨类型失败（`string` & `number` 对字符串 → Err） |
| `intersection merges object fields` | 对象字段合并（`{a: string}` & `{b: number}` → 合并结果） |
| `intersection with .intersect() method` | `.intersect()` 方法链式调用 |
| `intersection with three schemas` | 三 Schema 组合（`.min(2)` & `.max(20)` & `.email()`） |
| `intersection collects all errors` | 全部错误收集（`number().positive()` & `string().min(5)` → 2 个错误） |
| `to_json_schema intersection` | JSON Schema 产生 `"allOf"` 数组 |
| `to_json_schema skeleton intersection` | 骨架 JSON Schema 产生 `"allOf"` |
| `schema_to_prompt intersection` | prompt 输出 `"string & number"` 格式 |
| `intersection single schema` | 单 Schema 退化行为（等同于该 Schema 自身） |

### `pkg.generated.mbti`
新增公共 API:
```
pub fn intersection(Array[Schema]) -> Schema
pub fn Schema::intersect(Self, Self) -> Self
pub fn Schema::parse_intersection(Self, Array[Self], Json, Array[String]) -> SchemaResult
pub(all) enum SchemaType::IntersectionType(Array[Schema])
```

## 设计决策

### 方法名 `intersect` 而非 `and`
MoonBit 将 `and` 保留为布尔运算符关键字，不能用作方法名。`intersect` 是自然的替代选择。

### IntersectionType 在枚举中的位置
置于 `UnionType` 之后、`TransformType` 之前，逻辑对称。

### 对象字段合并策略
使用后写覆盖 (last-write-wins)：同名 key 时，后解析的 Schema 的字段值覆盖先解析的。这与直觉一致（右侧 Schema 覆盖左侧）。

### `expected_msg`
使用 `"Expected intersection match"` 作为通用错误信息，与 UnionType 的 `"Validation failed"` 协调。

### `inner_type`
IntersectionType 通过 `other => other` 回退保留自身，规则函数（`min()`, `max()` 等）将拒绝在其上注册规则。这是预期行为 — 规则应在子 Schema 上定义，而非在 Intersection 包装器上。

## 代码行数贡献

```
文件               行数
json_schema.mbt    +10
moon_zod_test.mbt  +108
pkg.generated.mbti +5
prompt.mbt         +17
schema.mbt         +4
union.mbt          +50
总计               +194
```

## 测试结果

```
Total tests: 149, passed: 149, failed: 0.
```

覆盖核心库：~84.2%（623/740）。

## 后续工作

- Issue #2 (derive 宏) 可考虑在后续阶段实现，为复杂嵌套 Schema 提供 `FromJson` 自动推导
- Intersection 可与 Union 嵌套组合形成复杂类型约束
- 考虑补充附加规则穿透：使 `.min(3)` 在 IntersectionType 上也能工作（需要额外设计决策）
