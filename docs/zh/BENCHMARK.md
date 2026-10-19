## ⚡ 性能

历史基准：以下测量早于本次 core 正确性修复。当前解析器复制输入并重建容器，这些数字不能代表当前版本的分配或性能特征。

这对于 **Wasm 边缘运行时**尤其重要，因为垃圾回收暂停和内存压力直接影响请求延迟。

### 跨语言基准测试（100k 次迭代）

| 验证器 | 运行时 | 吞吐量 |
|---|---|---|
| **TS Zod** | In-process V8 | 243,178 ops/sec |
| **MoonZod** | Native (@bench) | **3,815,556 ops/sec** |

> 两个验证器都以进程内方式运行，无子进程开销。MoonZod 使用 MoonBit 的 `@bench` 库进行校准的迭代计数（ns/op → ops/sec）；TS Zod 在 100k 次手动 `parse()` 调用上使用挂钟计时。在此基准测试中，MoonZod 比 TS Zod 快约 15 倍，此为历史数据，比较当前解析器前应重新测量。

运行基准测试：
```
moon run cmd/main                  # MoonZod 吞吐量（3 个基准测试）
cd bench_cross_lang && node bench.js  # 跨语言对比
```
