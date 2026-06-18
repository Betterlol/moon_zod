
背景：当前 `schema_to_prompt()` 将所有嵌套对象内联展开，LLM 面对深嵌套时理解准确率下降。需要一种方式将命名的子 schema 提取为独立 `export interface`，引用处用名字替代内联。

## 场景展示

```mbt
fn user_schema() -> @moon_zod.Schema {
  @moon_zod.object({
    "name": @moon_zod.string().min(2).max(50),
    "age": @moon_zod.number().int().min(0).max(150),
  }).name("User")
}

fn product_schema() -> @moon_zod.Schema {
  @moon_zod.object({
    "name": @moon_zod.string().min(1),
    "price": @moon_zod.number().positive(),
  }).name("Product")
}

fn order_schema() -> @moon_zod.Schema {
  @moon_zod.object({ "user": user_schema(), "product": product_schema() }).name("Order")
}

fn main {
    let user = user_schema();
    let product = product_schema();
    let order = order_schema();
    
    let schema_names = ["User", "Product", "Order"];
    let prompt = schema_to_prompt_named(order, schema_names);
    println!(prompt);
}
```

```text
expected output:

export interface User {
  name: string; // [2-50 chars]
  age: number; // [int, 0-150]
}

export interface Product {
  name: string; // [min: 1]
  price: number; // [positive]
}

export interface Order {
  user: User;
  product: Product;
}
```

## 相关参考

1. ObjectType(Map[String, Schema], ObjectMode) -> ObjectType(Map[String, Schema], ObjectMode, string)
> ObjectType 增加一个 name 字段，表示这个 schema 的名字
2. Schema::name(name: string) -> Schema
> 给 schema 命名，返回一个 schema，schema 的 type 是原来的 type 加上 name 字段
3. pub fn schema_to_prompt(schema : Schema, schema_names? : Array[String]) -> String
> schema_names 为 空、undefined/null，退化为原来的 schema_to_prompt 行为
4. 其他改动...