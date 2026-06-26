### multiple_schemas
> 展示如何在一个项目中使用嵌套的多个 Schema，以及 moon zod 支持导出 'named' prompt 和 完整 prompt 的能力。（此外，还有 'named' json schema 和 'inline' json schema 的能力）

```bash
moon run examples/multiple_schemas
```

> 具体来说：
> 1. 'named' prompt 示例：
```ts
export interface User {
  name: string,  // [2-50 chars]
  age: number,  // [int, 0-150]
}

export interface Product {
  name: string,  // [min: 1]
  price: number,  // [positive]
}

type OrderStatus = "pending" | "shipped" | "delivered" | "cancelled"

export interface Order {
  user: User,
  product: Product,
  status: OrderStatus,  // The status of an order
}
```
> 2. 'inline' prompt 示例：
```ts
export interface Order {
  user: {
    name: string,  // [2-50 chars]
    age: number,  // [int, 0-150]
  },
  product: {
    name: string,  // [min: 1]
    price: number,  // [positive]
  },
  status: "pending" | "shipped" | "delivered" | "cancelled",  // The status of an order
}
```