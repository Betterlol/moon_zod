## ⚡ Performance

moon_zod's **Mutable Path Stack** (Phase 5) defers path string construction until an error actually occurs. On the validation success path — the common case for well-behaved LLM output — **zero heap allocations** happen for path tracking.

This is especially important for **Wasm edge runtimes** where GC pauses and memory pressure directly impact request latency.

### Cross-Language Benchmark (100k iterations)

| Validator | Runtime | Ops/sec |
|---|---|---|
| **TS Zod** | In-process V8 | 243,178 ops/sec |
| **MoonZod** | Native (@bench) | **3,815,556 ops/sec** |

> Both validators run in-process with no subprocess overhead. MoonZod uses MoonBit's `@bench` library for calibrated iteration counts (ns/op → ops/sec); TS Zod uses wall-clock timing over 100k manual `parse()` calls. MoonZod is ~15x faster than TS Zod on this benchmark, demonstrating the advantage of a focused, zero-allocation validation path (Phase 5 Mutable Path Stack).

Run the benchmarks:
```
moon run cmd/main                  # MoonZod throughput (3 benchmarks)
cd bench_cross_lang && node bench.js  # Cross-language comparison
```

---