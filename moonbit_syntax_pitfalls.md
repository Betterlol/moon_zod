# MoonBit 语法避坑指南

> 基于 `moon_zod` 项目开发过程中踩过的真实错误汇总。

---

## 目录

- [类型与变量](#1-类型与变量)
- [函数与流程控制](#2-函数与流程控制)
- [数据结构与集合](#3-数据结构与集合)
- [Json 处理](#4-json-处理)
- [模块与包](#5-模块与包)
- [测试](#6-测试)
- [Wasm 特定](#7-wasm-特定)
- [附录：运行命令](#附录运行命令)

---

## 1. 类型与变量

### PascalCase 是禁区

变量必须用小写 `snake_case`，PascalCase 是类型/枚举/构造器的保留命名规则。

```mbt
// ❌ 编译错误：unbound variable
let UserSchema = object({ ... })

// ✅ 正确
let user_schema = object({ ... })
```

### 全局变量需要类型注解

顶层的 `let` 绑定（非函数内部）经常需要显式写出类型：

```mbt
// ❌ 类型推断失败
let schema = @moon_zod.object({ ... })

// ✅ 显式注解
let schema : @moon_zod.Schema = @moon_zod.object({ ... })
```

### `pub` vs `pub(all)`

| 关键字 | 适用对象 | 说明 |
|---|---|---|
| `fn` | 函数 | 仅包内可见 |
| `pub fn` | 函数 | 外部包可见 |
| `pub(all) enum/struct` | 类型 | 外部包可见 |

```mbt
// ❌ pub(all) 不能用于函数
pub(all) fn bench(n : Int) -> Bool { ... }

// ✅ 正确
pub fn bench(n : Int) -> Bool { ... }
```

### 没有三元运算符

MoonBit 没有 `cond ? a : b`，用 `if-else` 表达式替代：

```mbt
let label = if n > 0 { "positive" } else { "non-positive" }
```

### `[]` 创建空数组需要类型注解

```mbt
let errors : Array[ValidationError] = []  // 需要类型
let tags = ["rust", "wasm", "ai"]          // 有初始值可推断
```

### Result 是 `Ok`/`Err`，不是 `Ok`/`Error`

```mbt
// ❌ Error 不是 MoonBit 的 Result 变体
let r : Result[Int, String] = Error("bad")

// ✅ 正确
let r : Result[Int, String] = Err("bad")
```

---

## 2. 函数与流程控制

### `fn main` 中不能使用 Result-returning 函数

`fn main` 是 `is-main` 入口，**不支持** `Result` 返回类型的函数（如 `@json.parse()`）。必须通过 `catch` 语法处理：

```mbt
// ❌ 错误：Function with error is not allowed in `fn main`
let json = @json.parse(raw) match {
  Ok(v) => v
  Err(_) => return
}

// ✅ 正确：用 catch 处理
let json = @json.parse(raw) catch {
  _ => {
    println("Error: invalid JSON")
    return
  }
}
```

### Match 分支返回值必须一致

所有 match arm 必须返回相同类型：

```mbt
// ❌ 类型不一致
match mode {
  "moonzod" => bench(n)        // 返回 Bool
  "startup" => println("done") // 返回 Unit
}

// ✅ 用 let _ = 消化不需要的返回值
match mode {
  "moonzod" => { let _ = bench(n) }
  "startup" => println("done")
}
```

### 方法定义已弃用旧语法

**新版已弃用** `fn method(self : Type, ...)`，必须用 `fn Type::method(self, ...)`：

```mbt
// ❌ deprecated_syntax 警告
pub fn append_rule(self : Schema, check : ...) -> Schema { ... }

// ✅ 正确
pub fn Schema::append_rule(self, check : ...) -> Schema { ... }
```

---

## 3. 数据结构与集合

### 可变变量用 `let mut`

```mbt
let mut i = 0
i = i + 1  // 重新绑定需要 mut
```

### `let mut` 对 Array/Map 的误区

Array/Map 的**内容修改不需要 `mut`**，只有**重新绑定变量**才需要：

```mbt
let errors : Array[ValidationError] = []

// ✅ push 不需要 mut（修改内容）
errors.push(ValidationError::{ ... })

// ❌ 重新赋值需要 mut
errors = []  // ← 需要 let mut errors
```

### Map 取值返回 `Option`

```mbt
match map.get("name") {
  Some(value) => // 存在
  None => // 不存在
}
```

### Array `pop()` 返回 `Option[T]`

```mbt
let top = stack.pop()    // Option[String]
let _ = stack.pop()      // 忽略 None
```

### 有载荷的 enum 变体用 `::{}` 构造

```mbt
// ❌ 编译错误
ValidationError("x", "bad", json)

// ✅ 正确
ValidationError::{ path: "x", message: "bad", got: json }
```

### 结构体更新用 `..` 展开

```mbt
{ ..schema, rules: schema.rules + [new_rule] }
```

### For 循环两种写法

```mbt
for i = 0; i < n; i = i + 1 { ... }     // C 风格
for element in array { ... }             // 迭代器风格
for i, element in array { ... }          // 带索引
```

---

## 4. Json 处理

### 构造器 vs 模式匹配

**最容易踩的坑**：构造用小写 `Json::object()`，模式匹配用大写 `Object()`。

```mbt
// ✅ 构造
let data = Json::object({ "name": Json::string("Alice") })

// ✅ 模式匹配
match data {
  Object(map) => map.get("name")
  _ => None
}

// ❌ 错误：Cannot create values of the read-only type
let bad = Json::Object({ ... })
```

同理 `Json::array()`/`Array()`、`Json::string()`/`String()`。

### Json 模式匹配注意 `..`

```mbt
match json {
  Number(v, ..) => // .. 必须，忽略额外字段
  Object(map) => ...
  Array(elements) => ...
}
```

### 字符串插值用 `\{ }`

```mbt
// ❌ ${n} 被当作普通文本
println("n = ${n}")  // 输出: n = ${n}

// ✅ 正确
println("n = \{n}")
```

---

## 5. 模块与包

### 子包必须加 `@` 模块前缀

子包（如 `cmd/wasm/`）引用上层模块时必须加前缀：

```mbt
// ❌ 找不到 object
let schema = object({ ... })

// ✅ 正确
let schema = @moon_zod.object({ ... })
```

### `is-main` 包不能被 import

`moon.pkg` 中标记 `is-main: true` 的包是独立可执行入口，不能被其他包 import。

### MoonBit 核心包无需显式导入

`moonbitlang/core/json` 等核心包**新版已自动处理**，不需要在 `moon.pkg` 中声明。

```toml
// moon.pkg — 核心包可省略
import {
  // "moonbitlang/core/json",  ← 新版可省略
  "Betterlol/moon_zod",  // 外部包仍需声明
}
```

---

## 6. 测试

### test 文件不能写 import

测试文件（`test_*.mbt`）**不能使用 `import { ... }` 语法**。依赖需在 `moon.pkg` 中声明：

```mbt
// ❌ test_xxx.mbt 中不能写 import
import { "Betterlol/moon_zod" }  // 编译错误

// ✅ 在 moon.pkg 中声明依赖
```

### `@debug.assert_eq` 只有两个参数

```mbt
// ❌ 错误：given 3 positional arguments
@debug.assert_eq(a, b, "custom message")

// ✅ 正确
@debug.assert_eq(a, b)
```

### `moon test` 只能发现根目录的 `test_*.mbt`

子目录（如 `cmd/validate/`）中的测试文件不会被自动发现。

### 没有 `@os.execute()` / `@process`

无法在单元测试中执行外部命令。CLI 功能需通过外部 shell 脚本验证。

---

## 7. Wasm 特定

### 只导出 `_start`

MoonBit `--target wasm` 编译后，**只有 `_start` 和 `memory` 是导出项**，`pub fn` 不会成为独立 Wasm 导出函数。

```js
// ❌ 不存在
wasm.exports.some_function()

// ✅ 只有 _start
wasm.exports._start()
```

**解决方案**：CLI 参数分发模式。

```mbt
fn main {
  let args = @env.args()
  let mode = args.get(1).unwrap_or("default")
  match mode {
    "bench" => { let _ = run_benchmark() }
    _ => println("usage")
  }
}
```

---

## 附录：运行命令

```bash
moon test                          # 跑测试
moon build                         # 原生编译
moon build --target wasm --release # Wasm 编译
moon run cmd/validate -- --help    # 运行 CLI
moon info && moon fmt              # 更新接口 + 格式化
moon add moonbitlang/x             # 添加依赖
```