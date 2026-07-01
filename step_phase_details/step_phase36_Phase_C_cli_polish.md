# Phase 36 - Part C: CLI 工具易用性整理

**Date**: 2026-07-02  
**Status**: ✅ 完成  
**Scope**: `cmd/json2schema`、`cmd/validate` 及对应 `cli.sh` 包装脚本

---

## 执行摘要

本阶段对两个命令行工具做了轻量收口：不改变 core/importers/exporters 的语义，只让 CLI 输出更适合脚本使用，错误处理更稳定，文件输入脚本更直观。

| 工具 | 改进 |
|---|---|
| `cmd/json2schema` | 默认只输出 copy-paste ready 代码；新增 `--verbose` 显示解析输入；修复 wrapper 参数转发 |
| `cmd/validate` | 移除 `try!` abort 路径；统一 JSON parse 错误输出；简化 `--schema` 语义 |
| `cli.sh` | `json2schema` 与 `validate` 的文件输入用法更清晰，保留兼容旧写法 |

---

## 背景问题

### `cmd/json2schema`

- 原默认输出包含 `Input` / `Generated` / `End` 标题，更像 demo，不方便 shell 管道消费。
- `cmd/json2schema/cli.sh --from-json-schema <json>` 会把 flag 重复转发，参数语义不够干净。
- help 文案偏长，核心用法不够突出。

### `cmd/validate`

- help 曾承诺 exit code，但 MoonBit `core/env` 当前没有进程退出码 API，实际实现无法兑现。
- schema/data JSON 解析使用 `try!`，非法 JSON 会 abort，而不是给出稳定 CLI 错误。
- `--schema` 与 `--inline-schema` 完全等价，增加理解成本。
- `cmd/validate/cli.sh` 注释仍写着 `json2schema`，属于复制残留。

---

## 代码变更

### `cmd/json2schema/main.mbt`

- 默认输出从演示格式改为纯 schema 代码：

```text
let root = @moon_zod.object({ ... }).name("Root")
```

- 新增 `--verbose` / `-v`：
  - 打印解析后的输入 JSON。
  - 打印生成标题。
  - 仍以生成代码作为核心输出。

- 新增小型参数 helper：
  - `has_flag(args, flag)`
  - `last_value_arg(args)`
  - `print_result(json, code, verbose, input_label)`

### `cmd/json2schema/cli.sh`

- 支持：

```bash
sh cmd/json2schema/cli.sh --file data.json
sh cmd/json2schema/cli.sh --from-json-schema --file schema.json
sh cmd/json2schema/cli.sh --from-json-schema '{"type":"string"}'
```

- 修复 `--from-json-schema` 非文件模式下重复传 flag 的问题。

### `cmd/validate/main.mbt`

- `--schema` 明确表示“内联 JSON Schema 字符串”。
- 移除 `--inline-schema` 分支，避免两个名字表达同一件事。
- 所有 JSON parse 改为 `catch`：
  - invalid schema → `ERROR: invalid JSON Schema`
  - invalid sample → `ERROR: invalid sample JSON`
  - invalid data → `ERROR: invalid data JSON`
- `validate()` / `validate_single()` / `validate_jsonl()` 返回 `Bool`，为未来接入 exit code API 留出接口。
- help 不再承诺当前无法实现的 exit code。

### `cmd/validate/cli.sh`

- 新增直观文件模式：

```bash
sh cmd/validate/cli.sh --schema-file schema.json --file data.json
sh cmd/validate/cli.sh --sample-file sample.json --file data.json
```

- 保留兼容旧写法：

```bash
sh cmd/validate/cli.sh --file schema.json --file data.json
```

---

## 文档更新

更新了两个示例说明：

- `examples/json2schema/README.md`
- `examples/validate_cli/README.md`

文档只覆盖示例目录，不改主 README/API 文档。

---

## 验证

执行结果：

```text
moon check
Finished. moon: ran 4 tasks, now up to date

moon test
Warning: regex() is not fully implemented; it only checks for substring match.
Total tests: 426, passed: 426, failed: 0.
```

手动 smoke tests 覆盖：

- `moon run cmd/json2schema -- '{"name":"Alice","age":30}'`
- `moon run cmd/json2schema -- --from-json-schema '{"type":"string","minLength":2}'`
- `moon run cmd/json2schema -- --verbose '{"name":"Alice"}'`
- `moon run cmd/validate -- '{"name":"Alice"}' '{"name":"Bob"}'`
- `moon run cmd/validate -- --schema '{"type":"string","minLength":2}' '"x"'`
- `sh cmd/json2schema/cli.sh --file /tmp/moon_zod_sample.json`
- `sh cmd/json2schema/cli.sh --from-json-schema --file /tmp/moon_zod_schema.json`
- `sh cmd/validate/cli.sh --schema-file /tmp/moon_zod_schema.json --file /tmp/moon_zod_data.json`
- `sh cmd/validate/cli.sh --sample-file /tmp/moon_zod_sample.json --file /tmp/moon_zod_data.json`

---

## 后续注意

- 若未来 MoonBit `core/env` 增加 exit-code API，可直接利用当前 `Bool` 返回值把 `validate` 接入 `0/1/2` 退出码。
- `cmd/gen-struct` 仍是演示风格输出，后续如统一 CLI 风格，可单独处理。
