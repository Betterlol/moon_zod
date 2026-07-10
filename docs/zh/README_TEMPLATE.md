# moon_zod

[![CI](https://github.com/Betterlol/moon_zod/actions/workflows/ci.yml/badge.svg)](https://github.com/Betterlol/moon_zod/actions/workflows/ci.yml)
[![Mooncakes](https://img.shields.io/badge/mooncakes-published-blue)](https://mooncakes.io/docs/Betterlol/moon_zod)

> 🌐 [English README](./README.mbt.md)

---

## 文档

| 文档 | 说明 |
|---|---|
| [API 参考](./docs/zh/API.md) | 详细的 API 文档 |
| [CLI 参考](./docs/zh/CLI.md) | 命令行使用说明 |
| [性能基准](./docs/zh/BENCHMARK.md) | 与其他校验库的性能对比 |
| [使用示例](./docs/zh/EXAMPLES.md) | 实际使用示例 |

---

## 关于项目

moon_zod 是 [Zod](https://zod.dev) / [Pydantic](https://docs.pydantic.dev) 的 MoonBit 移植版，专为 AI 时代而生。它提供了流畅的链式调用 API，用于运行时 JSON Schema 校验，核心场景是 **LLM Tool Calling** —— 校验大模型生成的结构化 JSON 输出，一次性收集所有错误，并默认防御幻觉字段。

- **AI 优先** — 单次遍历收集所有错误，供 LLM 自我纠错
- **幻觉防御** — Strip 模式默认静默删除未知字段
- **完整路径错误** — 每个错误精确定位到字段路径（`users[0].profile.age`）
- **多格式导出** — 生成 LLM Prompt、JSON Schema、MoonBit 结构体和 moon_zod 源码

---

@include "QUICK_START.md"

---

@include "INFO.md"

---

## 了解更多

- [架构设计文档](./DESIGN.md) — 核心架构、设计决策与未来方向
- [发布日志](./CHANGELOG.md) — 版本发布历史
- [English README](./README.mbt.md) — English version
