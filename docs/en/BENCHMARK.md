## ⚡ Performance

moon_zod's **Mutable Path Stack** (Phase 5) defers path string construction until an error actually occurs. On the validation success path — the common case for well-behaved LLM output — **zero heap allocations** happen for path tracking.

This is especially important for **Wasm edge runtimes** where GC pauses and memory pressure directly impact request latency.

### Cross-Language Benchmarks and Exporter Validation

Cross-language comparisons, JSON Schema exporter validation, and named-schema benchmarks are maintained in the independent [moon_zod_lab](https://github.com/Betterlol/moon_zod_lab) repository, included here as a submodule. The lab depends on a published Mooncakes version; its reports identify the version actually tested.

Initialize the submodule and run the cross-language benchmark:

```sh
git submodule update --init moon_zod_lab
cd moon_zod_lab
npm ci
npm run bench:validation
```

See the submodule README for the full dependency setup for exporter validation and Zod/Pydantic named-schema comparisons.

The MoonBit benchmark entry point remains available in this repository:

```sh
moon run cmd/main
```

---
