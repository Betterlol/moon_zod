## ⚡ 性能

moon_zod 的**可变路径栈**（第 5 阶段）将路径字符串构造延迟到实际发生错误时。在验证成功路径上——这是格式良好的 LLM 输出的常见情况——路径跟踪**零堆分配**。

这对于 **Wasm 边缘运行时**尤其重要，因为垃圾回收暂停和内存压力直接影响请求延迟。

### 跨语言基准与导出验证

跨语言对比、JSON Schema 导出验证和命名 Schema 基准由独立仓库 [moon_zod_lab](https://github.com/Betterlol/moon_zod_lab) 维护，并作为本仓库的子模块提供。实验室通过 Mooncakes 依赖发布版本，运行结果中的版本号标明实际待测版本。

初始化并运行跨语言基准：

```sh
git submodule update --init moon_zod_lab
cd moon_zod_lab
npm ci
npm run bench:validation
```

导出验证和 Zod/Pydantic 命名 Schema 对比的完整依赖安装步骤见子模块的 README。

本仓库仍保留 MoonBit 基准入口：

```sh
moon run cmd/main
```
