## 安装

```bash
moon add Betterlol/moon_zod
```

或在 `moon.mod` 中添加依赖：

```toml
import {
  "Betterlol/moon_zod",
}
```

---

## 快速开始

```moonbit nocheck
let schema = @moon_zod.object({
  "name": @moon_zod.string().min(2).max(50),
  "age": @moon_zod.number().int().min(0).max(150),
  "email": @moon_zod.string().email(),
})

match schema.parse(input_json) {
  Ok(valid) => {
    println("Valid")
    println(@debug.to_string(valid))
  }
  Err(errors) => {
    println("Invalid")
    println(errors.length().to_string())
    for e in errors {
      println(e.to_string())
    }
  }
}
```

**零代码 CLI 校验：**
```bash
# 从样本推断 Schema，校验数据
moon run cmd/validate -- '{"name":"Alice","age":30}' '{"name":"Bob","age":25}'
# PASS

# 使用 JSON Lines 批量校验
moon run cmd/validate -- '{"name":"Alice"}' '{"name":"Bob"}\n{"name":"Eve"}'
# 结果：2 通过，0 失败
```
