# moon_zod

[![CI](https://github.com/Betterlol/moon_zod/actions/workflows/ci.yml/badge.svg)](https://github.com/Betterlol/moon_zod/actions/workflows/ci.yml)
[![Mooncakes](https://img.shields.io/badge/mooncakes-published-blue)](https://mooncakes.io/docs/Betterlol/moon_zod)
[![doc](https://img.shields.io/badge/branch-doc-blue)](https://github.com/Betterlol/moon_zod/tree/doc)

> 🌏 [中文版 README](./README_zh.mbt.md)

---

## Documents

| Document | Description |
|---|---|
| [Design Document](./DESIGN.md) | Important! Core architecture, design decisions, and future directions |
| [API Reference](./docs/en/API.md) | Detailed API documentation |
| [CLI Reference](./docs/en/CLI.md) | Command-line usage |
| [Benchmark](./docs/en/BENCHMARK.md) | Performance comparison with other validation libraries |
| [Examples](./docs/en/EXAMPLES.md) | Practical usage examples |

---

## About

moon_zod is a **runtime Schema intermediate representation (IR)** — a validation contract layer decoupled from input sources and output targets. It provides runtime JSON schema validation with a fluent chainable API, designed primarily for **LLM Tool Calling**, and serves as a cross-format schema interoperability bridge. See [DESIGN.md](./DESIGN.md) for details.

A Schema IR core providing runtime validation, multi-source import, multi-format export, and LLM hallucination defense — closing the loop from JSON Schema to prompt generation.

---

@include "QUICK_START.md"

---

@include "INFO.md"

---

## Learn More

- [DESIGN.md](./DESIGN.md) for architecture, design decisions, and future directions.
- [CHANGELOG.md](./CHANGELOG.md) for release history.
- [中文 README](./README_zh.mbt.md) for Chinese documentation.
