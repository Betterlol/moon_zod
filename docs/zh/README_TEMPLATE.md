# moon_zod

[![CI](https://github.com/Betterlol/moon_zod/actions/workflows/ci.yml/badge.svg)](https://github.com/Betterlol/moon_zod/actions/workflows/ci.yml)
[![Mooncakes](https://img.shields.io/badge/mooncakes-published-blue)](https://mooncakes.io/docs/Betterlol/moon_zod)
[![doc](https://img.shields.io/badge/branch-doc-blue)](https://github.com/Betterlol/moon_zod/tree/doc)

> 🌐 [English README](./README.mbt.md)

---

## 文档

| 文档 | 说明 |
|---|---|
| [设计文档](./DESIGN.md) | 重要！核心架构、设计决策与未来方向 |
| [API 参考](./docs/zh/API.md) | 详细的 API 文档 |
| [CLI 参考](./docs/zh/CLI.md) | 命令行使用说明 |
| [性能基准](./docs/zh/BENCHMARK.md) | 与其他校验库的性能对比 |
| [使用示例](./docs/zh/EXAMPLES.md) | 实际使用示例 |

---

## 关于项目

moon_zod 是一个**运行时 Schema 中间表示（IR）**——独立于输入来源和输出目标的校验契约层。它提供了流畅的链式调用 API 构建校验契约，核心场景是 **LLM Tool Calling**，同时也是一道跨格式的 Schema 互操作桥梁。详见[设计文档](./DESIGN.md)。

以 Schema IR 为内核提供运行时校验、多源导入、多格式导出及 LLM 幻觉防御，支撑从 JSON Schema 到 Prompt 的闭环。

---

@include "QUICK_START.md"

---

@include "INFO.md"

---

## 相关项目

- [vscode-moon-zod-schema](https://github.com/Betterlol/vscode-moon-zod-schema.git) - moon_zod 的 VSCode 插件。
> 网站: [extension](https://marketplace.visualstudio.com/items?itemName=Betterlol.vscode-moon-zod-schema).

---

## 了解更多

- [架构设计文档](./DESIGN.md) — 核心架构、设计决策与未来方向
- [发布日志](./CHANGELOG.md) — 版本发布历史
- [English README](./README.mbt.md) — English version
