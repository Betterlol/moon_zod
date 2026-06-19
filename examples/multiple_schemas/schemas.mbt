///|
fn user_schema() -> @moon_zod.Schema {
  @moon_zod.object({
    "name": @moon_zod.string().min(2).max(50),
    "age": @moon_zod.number().int().min(0).max(150),
  }).name("User")
}

///|
fn product_schema() -> @moon_zod.Schema {
  @moon_zod.object({
    "name": @moon_zod.string().min(1),
    "price": @moon_zod.number().positive(),
  }).name("Product")
}

///|
fn order_status_schema() -> @moon_zod.Schema {
  @moon_zod.enum_values(["pending", "shipped", "delivered", "cancelled"])
  .name("OrderStatus")
  .describe("The status of an order")
}

///|
fn order_schema() -> @moon_zod.Schema {
  @moon_zod.object({
    "user": user_schema(),
    "product": product_schema(),
    "status": order_status_schema(),
  }).name("Order")
}
