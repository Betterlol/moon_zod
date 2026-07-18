# 错误系统重构决策文档

## 背景

`phase42_zod_error_map` 分支已有完整实现（23 文件，+989/-161 行），包含 IssueCode + ErrorMap + RawIssue/finalize 管线。本决策文档划定该实现的上线范围。

---

## ✅ 做：IssueCode + ErrorMap + ParseParams

### 1. IssueCode 枚举
```
InvalidType(String) | TooBig(String, Double, Bool) | TooSmall(String, Double, Bool)
| InvalidFormat(String) | NotMultipleOf(Double) | UnrecognizedKeys(Array[String])
| InvalidUnion(Array[String]) | MissingRequired(String) | InvalidKey(String)
| InvalidElement(String, Int) | InvalidValue(Array[Json]) | Custom
```

- 每个 Rule 携带 `code: IssueCode`
- `ValidationError` 新增 `code` 字段
- `to_string()` 输出包含 `(code: ...)`

### 2. ErrorMap 模式
```
type ErrorMap = (IssueCode, Array[String], Json) -> String?
```

- 通过 `ParseParams.error_map` 传入，**不设全局 error map**
- 不设全局 error map 的理由：
  - MoonBit 模块系统无局部可变全局状态
  - 调用点可自行封装 `fn my_error_map(code, path, input) -> String?` 复用以达到等效效果
  - 避免隐式全局状态带来的测试困难和意外行为

### 3. 优先级链（已实现）
```
1. ParseParams.error_map      ← 调用者上下文，最高优先级
2. Rule.message               ← 规则内联消息（含 .message() 覆盖）
3. Schema.invalid_type_error  ← 类型级别覆盖
   / Schema.required_error
4. default_message(code)      ← 硬编码英文回退
```

### 4. API 扩展
- `Schema::safe_parse(self, json, ParseParams)` — 主入口
- `Schema::parse(self, json, path?)` — 委托给 `safe_parse`，`error_map = None`
- `ParseParams::default()` — 快捷构造
- 所有 parse 内部函数返回 `RawSchemaResult`（即 `Result[Json, Array[RawIssue]]`），在顶层做 finalize

### 5. 生效范围
| 模块 | 改动 |
|---|---|
| `core/errors.mbt` | **新增** — IssueCode / RawIssue / Issue / ErrorMap / ParseParams / finalize_issue / collect_raw_errors |
| `core/types.mbt` | ValidationError 增加 `code: IssueCode` |
| `core/schema.mbt` | Rule 增加 `code`；parse_inner 返回 `RawSchemaResult`；新增 safe_parse；新增 type_origin |
| `core/*.mbt` | 各 rule 方法传入对应 IssueCode |
| `tests/test_issue_code.mbt` | **新增** — code 断言测试 |
| `tests/test_error_map.mbt` | **新增** — error_map 行为测试 |

---

## ❌ 不做：以下设计被排除

### 1. 不做全局 ErrorMap
- Zod 支持 `new Zod({errorMap})`，但 MoonBit 无全局可变状态
- 替代：调用者自行组织 `fn my_map(...)` 并传入每个 `safe_parse` 调用

### 2. 不做 Trait 化错误处理
- Rust 的 `thiserror`/`std::error::Error` 风格 trait 在 MoonBit 中需要：
  - 成熟的 error trait 生态（不存在）
  - 动态派发到错误类型
  - 比 IssueCode enum 更重的抽象
- MoonBit 的 `enum with payload` 已足够表达所有分类

### 3. 不做 ZodIssue 多层嵌套结构
- Zod 的 `ZodIssue` 支持 `path`、`code`、`expected`/`received`、`unionErrors` 等嵌套
- 本设计保持平面结构：`ValidationError { code, path, message, got }`
- 理由：LLM 场景需要平面列表以便一次全部返回，嵌套结构增加解析成本

### 4. 不做独立 error map 文件/配置
- 不设计 `.errorMap()` 链式方法（Zod 有但使用率低）
- 不设计 YAML/JSON 错误消息配置
- 保持入口单一：`ParseParams.error_map`

### 5. 不做异步/Zod 全量 IssueCode 覆盖
- 暂不实现 `async_parse` 相关 code（如 `ZodIssueCode.timeout`）
- 暂不实现 `ZodIssueCode.invalid_arguments`、`invalid_return_type` 等与 LLM 场景无关的 code
- 后续可按需添加新 IssueCode 变体（向后兼容）

---

## 合并策略

从 `phase42_zod_error_map` cherry-pick 到 `develop`：
```
git cherry-pick 384fb7a..48923d2  # 5 个提交
```
或 squash 合并。

需验证：
- [ ] `moon test` 全量通过（本地已有 265+180 行新测试）
- [ ] `moon info && moon fmt` 一致
- [ ] `.mbti` 正确反映新增的 `IssueCode`、`ErrorMap`、`ParseParams`、`RawIssue` 等
