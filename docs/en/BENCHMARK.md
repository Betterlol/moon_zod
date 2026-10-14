## ⚡ Performance

Historical benchmark: these measurements predate the core correctness changes. The current parser copies inputs and rebuilds containers, so these figures do not establish current allocation or performance characteristics.

This is especially important for **Wasm edge runtimes** where GC pauses and memory pressure directly impact request latency.

### Cross-Language Benchmark (100k iterations)

| Validator | Runtime | Ops/sec |
|---|---|---|
| **TS Zod** | In-process V8 | 243,178 ops/sec |
| **MoonZod** | Native (@bench) | **3,815,556 ops/sec** |

> Both validators run in-process with no subprocess overhead. MoonZod uses MoonBit's `@bench` library for calibrated iteration counts (ns/op → ops/sec); TS Zod uses wall-clock timing over 100k manual `parse()` calls. MoonZod is ~15x faster than TS Zod on this benchmark, This is historical data; remeasure before comparing the current parser.

Run the benchmarks:
```
moon run cmd/main                  # MoonZod throughput (3 benchmarks)
cd bench_cross_lang && node bench.js  # Cross-language comparison
```

---
