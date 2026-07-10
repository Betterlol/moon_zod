# moon_zod

[![CI](https://github.com/Betterlol/moon_zod/actions/workflows/ci.yml/badge.svg)](https://github.com/Betterlol/moon_zod/actions/workflows/ci.yml)
[![Mooncakes](https://img.shields.io/badge/mooncakes-published-blue)](https://mooncakes.io/docs/Betterlol/moon_zod)

> 🌏 [中文版 README](./README_zh.mbt.md)

---

## Documents

| Document | Description |
|---|---|
| [API Reference](./docs/en/API.md) | Detailed API documentation |
| [CLI Reference](./docs/en/CLI.md) | Command-line usage |
| [Benchmark](./docs/en/BENCHMARK.md) | Performance comparison with other validation libraries |
| [Examples](./docs/en/EXAMPLES.md) | Practical usage examples |

---

## About

moon_zod is a MoonBit port of [Zod](https://zod.dev) / [Pydantic](https://docs.pydantic.dev), purpose-built for the AI era. It provides runtime JSON schema validation with a fluent chainable API, designed primarily for **LLM Tool Calling** — validating structured JSON outputs from large language models, collecting all errors in one pass, and defending against hallucinated fields by default.

- **AI-first** — collect every error in a single pass for LLM self-correction loops
- **Hallucination defense** — Strip mode silently removes unknown fields by default
- **Full-path errors** — every error pinpoints the exact field path (`users[0].profile.age`)
- **Multi-format export** — generate LLM prompts, JSON Schema, MoonBit structs, and moon_zod source code

---

@include "QUICK_START.md"

---

@include "INFO.md"

---

## Learn More

- [DESIGN.md](./DESIGN.md) for architecture, design decisions, and future directions.
- [CHANGELOG.md](./CHANGELOG.md) for release history.
- [中文 README](./README_zh.mbt.md) for Chinese documentation.
