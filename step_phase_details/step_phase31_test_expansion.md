# Phase 31 — 测试扩展

**目标**: 补充 moonbit_struct 模块的测试覆盖，新增 17 个测试用例，覆盖边缘场景。

**Commit**: (待提交)

---

## 背景

Phase 28-30 完成了 `schema_to_moonbit_struct`、`schema_to_moonbit_struct_full`、Validate CLI 工具，但测试覆盖不足。Phase 31 补充关键场景的测试，确保代码质量。

---

## 新增测试用例

### 深度嵌套对象 (Phase 28 struct 定义)

| 测试 | 描述 |
|---|---|
| `schema_to_moonbit_struct deeply nested 3 levels` | 3 层嵌套对象，验证中间层引用正确 |
| `schema_to_moonbit_struct_named multiple sibling references` | 多个兄弟节点引用同一子 schema，验证无重复定义 |

### 数组类型

| 测试 | 描述 |
|---|---|
| `schema_to_moonbit_struct array of optional strings` | `Array[String?]` 类型生成 |
| `schema_to_moonbit_struct object with only optional fields` | 全 optional 字段，对象类型正确性 |
| `schema_to_moonbit_struct array of arrays` | 多维数组 `Array[Array[Int64]]` |
| `schema_to_moonbit_struct object with all field types` | 7 种类型混合（String/Int64/Double/Bool/Unit/Array/Json） |
| `full array of objects from_json uses named schema` | 数组元素为命名 schema 时，`from_json` 委托调用 |

### 可选字段

| 测试 | 描述 |
|---|---|
| `schema_to_moonbit_struct optional object field` | optional 包装的对象字段类型为 `Json` |
| `schema_to_moonbit_struct optional array field` | optional 包装的数组字段类型为 `Array[T]?` |
| `full optional array field from_json` | optional array 字段的 `Some(Null) | None => None` 分支 |
| `full default number field` | `default()` 字段的 `Some(Null) | None => None` 模式 |

### 特殊场景

| 测试 | 描述 |
|---|---|
| `full deeply nested from_json` | 深度嵌套使用 `schema_to_moonbit_struct_named_full` 正确生成多 struct + 多 fn |
| `full all field types extraction` | 7 种类型的 from_json 提取代码生成 |
| `full empty object` | 空对象 struct `pub struct Empty {}` + `Ok({)` 构造 |
| `full null type extraction` | `null()` 字段生成 `expected null` + `data: ()` |

---

## 关键发现

### 1. NullType → Unit 而非 Json

```moonbit
// moonbit_struct.mbt 行为
NullType => "Unit"  // type_to_moonbit() 第 69 行
```

测试修正：`data : Unit` 而非 `data : Json`

### 2. 深度嵌套必须用 `_named_full` 函数

```moonbit
// 错误用法
let result = schema_to_moonbit_struct_full(l1)  // 仅生成 Level1

// 正确用法
let result = schema_to_moonbit_struct_named_full(l1)  // 生成 Level1 + Level2 + Level3
```

### 3. 数组元素 from_json 委托

当数组元素为命名 schema 时，生成的代码为：
```moonbit
items.push(item_from_json(item))
```

而非内联展开。

---

## 文件变更

| 文件 | 变更 |
|---|---|
| `test_moonbit_struct.mbt` | +17 个测试用例 |

---

## 测试结果

```
moon build  ✓ 0 errors 0 warnings
moon test   ✓ 377 tests passed (360 → 377, +17)
moon info   ✓ up to date
moon fmt    ✓ no changes
```

---

## CLI 测试限制

Validate CLI (`cmd/validate`) 和 gen-struct CLI (`cmd/gen-struct`) 无法通过 MoonBit 单元测试框架直接测试，原因：

- MoonBit 标准库**不支持** `@os.execute()` 或 `@process` 等 shell 执行接口
- `fn main` 是 `is-main` 入口，无法被其他测试文件 import 调用
- 测试文件无法使用 `import { ... }` 语法（仅包根目录 `.mbt` 文件支持）

**替代方案**：
1. 手动测试：`moon run cmd/validate -- '<sample>' '<data>'`
2. Shell 脚本集成测试：外部脚本调用 CLI 并验证输出/退出码
3. 将 CLI 核心逻辑提取为可测试函数（如 `json_to_schema` 已通过单元测试覆盖）

---

## 价值

- 覆盖深度嵌套、数组、optional、默认值等多种场景
- 发现并修正了 `NullType → Unit` 的错误预期
- 明确了 `_named_full` vs `_full` 的适用场景
- 377 测试覆盖确保后续重构安全性