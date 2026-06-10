# MoonBit 语法避坑指南

> 基于 `moon_zod` 项目开发过程中踩过的真实错误汇总。

## 1. 变量命名：PascalCase 是禁区

变量必须用小写 `snake_case`，PascalCase 是类型/枚举/构造器的保留命名规则。

```mbt
// ❌ 编译错误：unbound variable
let UserSchema = object({ ... })

// ✅ 正确
let user_schema = object({ ... })
```

## 2. `pub` vs `pub(all)` 各司其职

很多语言只有一个 `pub/public`，MoonBit 有层级可见性：

| 关键字 | 适用对象 | 说明 |
|---|---|---|
| `fn` | 函数 | 仅包内可见 |
| `pub fn` | 函数 | 外部包可见 |
| `pub fn Schema::method` | 方法 | 外部包可见 |
| `pub(all) enum` | 类型/枚举 | 外部包可见 |
| `pub(all) struct` | 结构体 | 字段全公开的 struct |

```mbt
// ❌ 错误：pub(all) 不能用于函数
pub(all) fn bench(n : Int) -> Bool { ... }

// ✅ 正确
pub fn bench(n : Int) -> Bool { ... }

// ✅ 类型和枚举可以用 pub(all)
pub(all) enum ObjectMode { Passthrough; Strict; Strip }
pub(all) struct Rule { check : (Json) -> Bool; message : String }
```

## 3. 子包中必须加 `@` 模块前缀

根目录的 `.mbt` 文件可以直接调用同包函数，但 **子包（如 `cmd/wasm/`）** 引用上层模块时必须加 `@模块名.` 前缀。

```mbt
// 在 cmd/wasm/main.mbt 中引用 moon_zod：
// ❌ 找不到 object, string 等
let schema = object({ ... })

// ✅ 正确
let schema = @moon_zod.object({ ... })
```

`moon.pkg` 中声明依赖：

```
// cmd/wasm/moon.pkg
import {
  "username/moon_zod",
  "moonbitlang/core/env",
}
```

## 4. 全局变量需要类型注解

顶层的 `let` 绑定（非函数内部）经常需要显式写出类型：

```mbt
// ❌ 类型推断失败
let schema = @moon_zod.object({ ... })

// ✅ 显式注解
let schema : @moon_zod.Schema = @moon_zod.object({ ... })

let large_input : Json = Json::object({ ... })
```

## 5. Match 分支返回值必须一致

所有 match arm 必须返回相同类型。一个常见的坑是 println(`Unit`) 和 Bool 混用：

```mbt
// ❌ 错误：match arm 类型不一致
match mode {
  "moonzod" => bench(n)        // 返回 Bool
  "startup" => println("done") // 返回 Unit
  _ => println("usage")
}

// ✅ 用 let _ = 消化不需要的返回值
match mode {
  "moonzod" => { let _ = bench(n) }
  "startup" => println("done")
  _ => println("usage")
}
```

## 6. Wasm 只导出 `_start`

MoonBit `--target wasm` 编译后，**只有 `_start` 和 `memory` 是 Wasm 导出项**，`pub fn` 不会成为独立 Wasm 导出函数。

**不要试图** 在 JS 中这样调用：

```js
// ❌ 不存在，只有 _start
wasm.exports.bench_moon_zod()
```

**解决方案**：CLI 参数分发模式。

```mbt
fn main {
  let args = @env.args()
  let mode = if args.length() > 1 { args[1] } else { "moonzod" }
  match mode {
    "moonzod" => { let _ = bench_moon_zod(n) }
    "handcrafted" => { let _ = bench_handcrafted_match(n) }
    "startup" => println("[DONE] startup")
    _ => println("usage")
  }
}
```

JS 端通过 `execFileSync(moonrun, [wasm_path, mode])` 传参。

## 7. 可变变量用 `let mut`

```mbt
// ❌ 错误：let 绑定不可变
let i = 0
i = i + 1

// ✅ 正确
let mut i = 0
i = i + 1
```

## 8. For 循环两种写法

```mbt
// C 风格
for i = 0; i < n; i = i + 1 {
  // ...
}

// 迭代器风格
for element in array {
  // ...
}

// 带索引
for i, element in array {
  // i 是索引
}
```

## 9. 字符串插值用 `\{ }`

```mbt
let n = 42
// ❌ 不会报错，但 `${n}` 被当作普通文本原样输出（不插值）
println("n = ${n}")  // 输出: n = ${n}

// ✅ 正确
println("n = \{n}")
println("\{n} iterations passed")
```

## 10. Map 取值返回 `Option`

```mbt
let map : Map[String, Json] = { "name": Json::string("Alice") }
match map.get("name") {
  Some(value) => // 存在
  None => // 不存在
}
```

## 11. 可执行包标记

`moon.pkg` 中需要标记 `is-main`：

```
options(
  "is-main": true,
)
```

否则 `moon run` 会找不到入口。

## 12. 结构体更新语法

```mbt
// 基于已有结构体创建新副本，覆盖部分字段
{ ..schema, rules: schema.rules + [new_rule] }
```

注意前面的 `..` 表示展开原有字段。

## 13. Json 模式匹配

```mbt
match json {
  Object(map) => // Json::object(...)
  Array(elements) => // Json::array(...)
  String(s) => // Json::string(...)
  Number(v, ..) => // Json::number(...)，.. 忽略额外字段
  True | False => // Json::boolean(...)
  Null => // Json::null()
}
```

注意 `Number(v, ..)` 中的 `, ..` 是必须的——MoonBit 的 `Number` 变体可能还有额外字段（如原文位置）。

## 14. 注释风格

公共项前用 `///|` 分隔，不要用 `//`：

```mbt
///|
/// 这是一个公开函数
pub fn my_func() { ... }

// 内部注释用 // 或 ///
```

## 15. 没有三元运算符

MoonBit 没有 `cond ? a : b`，但 `if-else` 是表达式，可以返回值：

```mbt
let label = if n > 0 { "positive" } else { "non-positive" }

// 相当于三元
```

## 16. `[]` 创建空数组需要类型注解

```mbt
// 空数组需要显式类型
let errors : Array[ValidationError] = []

// 有初始值的可以推断
let tags = ["rust", "wasm", "ai"]
```

## 17. `_` 消去未使用的返回值

```mbt
let _ = some_function()  // 忽略返回值
let _ = path_stack.pop() // 忽略 pop 返回值
```

## 18. `Json::object()` 是构造器，`Object()` 是模式匹配

这是 MoonBit 新手最容易踩的坑：**构造 JSON 对象用 `Json::object(map)`（小写 o），模式匹配用 `Object(map)`（大写 O）**。

```mbt
// ✅ 构造用 Json::object()
let data = Json::object({ "name": Json::string("Alice") })

// 模式匹配用 Object（大写）
match data {
  Object(map) => map.get("name")
  _ => None
}

// ❌ 错误：Cannot create values of the read-only type
let bad = Json::Object({ "name": Json::string("Alice") })
```

同理 `Json::array()`（小写）/ `Array(elements)`（大写）、`Json::string()` / `String(s)`。

## 19. 方法定义已弃用 `fn meth(self : Type)` 语法

MoonBit 早期允许 `fn method(self : Type, ...)` 定义方法，**新版已弃用**，必须用 `fn Type::method(self, ...)`：

```mbt
// ❌ 弃用警告：deprecated_syntax
pub fn append_rule(self : Schema, check : ...) -> Schema { ... }

// ✅ 正确
pub fn Schema::append_rule(self, check : ...) -> Schema { ... }
```

弃用语法虽然能编译（编译器产生 `deprecated_syntax` 警告），但在跨文件调用时必须使用方法调用语法 `a.f()` 而非 `f(a)`，否则可能引发「unbound identifier」错误。

## 20. `let mut` 对 Array/Map 的误区

Array 和 Map 的 **内容修改不需要 `mut`**，`mut` 只用于**重新绑定变量**：

```mbt
let errors : Array[ValidationError] = []

// ✅ 直接 push 不需要 mut
errors.push(ValidationError::{ path: "x", message: "bad", got: json })

// let props : Map[String, Json] = {}
props.set("type", Json::string("string"))

// ❌ 需要 mut 的场景：重新赋值
errors = []                 // ← 这需要 let mut
errors = collect_errors(...) // ← 这需要 let mut
```

编译器会提示 `unused_mut` 或缺少 `mut`，留意提示即可。

## 21. MoonBit 核心包无需在 `moon.pkg` 显式导入（旧版需要）

以前 `moonbitlang/core/json` 等核心包需要在 `moon.pkg` 的 `import` 中声明，否则会报 `Package not imported` 警告。**新版 MoonBit 已自动处理此导入**，删除 `moon.pkg` 中的核心包 import 也能正常编译和测试：

```toml
// moon.pkg — 新版不需要显式导入 core 包
import {
  // "moonbitlang/core/json",  ← 新版可省略
}
```

注意：**外部包**（如 `moonbitlang/x`、`username/moon_zod`）仍需在 `import` 中声明。

## 22. `Result` 是 `Ok`/`Err`，不是 `Ok`/`Error`

从 Rust/Go/TypeScript 过来的容易条件反射写 `Error`，MoonBit 的 Result 变体是 `Err`：

```mbt
// ❌ 错误：The type Result[Int, String] does not have the constructor Error
let r : Result[Int, String] = Error("bad")

// ✅ 正确
let r : Result[Int, String] = Err("bad")
// 用法：Ok(value) / Err(error)
```

## 23. 有载荷的 enum 变体用 `::{}` 构造

MoonBit 对带命名字段的 enum 变体使用 `EnumName::{ field: value }` 语法，不是 `EnumName(field: value)`：

```mbt
// ❌ 编译错误
ValidationError("x", "bad", json)

// ✅ 正确
ValidationError::{ path: "x", message: "bad", got: json }

// 带类型注解
let err: ValidationError = ValidationError::{
  path: "x",
  message: "bad",
  got: json,
}
```

如果用构造函数式语法 `ValidationError("x", "bad", json)` 也可，但需要按 struct 定义的字段顺序且不带字段名。

## 24. Array `pop()` 返回 `Option[T]`

`Array.pop()` 不会在空数组时 panic，而是返回 `None`：

```mbt
let stack: Array[String] = ["a", "b"]
let top = stack.pop()    // top: Option[String] = Some("b")
let empty: Array[String] = []
let top = empty.pop()    // top: Option[String] = None

// 项目中用于 path_stack 的 push/pop 模式：
path_stack.push("field_name")    // push 不需要处理返回值
let _ = path_stack.pop()         // pop 必须消去 Option
```

---

## 运行命令速查

```bash
moon test                          # 跑测试
moon build                         # 原生编译
moon build --target wasm --release # Wasm 编译（release）
moon run cmd/wasm -- moonzod       # 带参数运行
moon info && moon fmt              # 更新接口 + 格式化
moon add moonbitlang/x             # 添加依赖
```
