# Async stream benchmark

Run from the repository root:

```sh
moon run examples/async_bench --target native --release
```

The benchmark measures the complete in-memory read, UTF-8 decode, JSON parse,
and schema validation pipeline. It checks record counts, discards two warmups,
and reports the median of seven runs. Payload construction is outside timing;
reader creation and input encoding are included. No network or remote checks
are involved. It is a manual benchmark, not a timing assertion in the test suite.
Elapsed time uses the core monotonic clock and converts microseconds to
milliseconds, so system clock adjustments cannot change the measured duration.

One Windows run with MoonBit toolchain `0.1.20261012` compared the same workload
before and after replacing per-byte accumulation with chunk views:

| Workload | Before | After |
|---|---:|---:|
| JSONL, 20,000 short records | 81 ms | 57 ms |
| SSE, 20,000 short frames | 66 ms | 49 ms |
| JSONL, 500 records with 16 KiB strings | 556 ms | 154 ms |

These are local observations, not portable performance guarantees. Use the same
workload, build mode, machine, and runtime when comparing changes.
