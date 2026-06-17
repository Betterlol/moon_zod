///|
fn main {
  let result = validate_schemas()
  let ts_interface = show_ts_interface()
  println("Validation Result:\n\{result}")
  println("TypeScript Interface:\n\{ts_interface}")
}

///|
fn validate_schemas() -> String {
  let user_schema = user_schema()
  let product_schema = product_schema()
  let order_schema = order_schema()

  // Valid user
  let user_json = Json::object({
    "name": Json::string("Alice"),
    "age": Json::number(30),
  })
  match user_schema.parse(user_json) {
    Err(_) => println("User is invalid!")
    Ok(clean) => {
      println("User is valid!")
      let user = User::from_json(clean)
      println("  name: \{user.name}, age: \{user.age}")
    }
  }

  println("---")

  // Valid product
  let product_json = Json::object({
    "name": Json::string("Laptop"),
    "price": Json::number(999.99),
  })
  match product_schema.parse(product_json) {
    Err(_) => println("Product is invalid!")
    Ok(clean) => {
      println("Product is valid!")
      let product = Product::from_json(clean)
      println("  name: \{product.name}, price: \{product.price}")
    }
  }

  println("---")

  // Nested order
  let order_json = Json::object({
    "user": Json::object({
      "name": Json::string("Bob"),
      "age": Json::number(25),
    }),
    "product": Json::object({
      "name": Json::string("Mouse"),
      "price": Json::number(29.99),
    }),
  })
  match order_schema.parse(order_json) {
    Err(errors) => {
      println("Order is invalid:")
      for e in errors {
        println("  \{e.to_string()}")
      }
    }
    Ok(clean) => {
      println("Order is valid!")
      let order = Order::from_json(clean)
      println("  user: \{order.user.name}, product: \{order.product.name}")
    }
  }

  println("---")

  // Invalid user (age negative, name too short)
  let bad_json = Json::object({
    "name": Json::string("A"),
    "age": Json::number(-5),
  })
  match user_schema.parse(bad_json) {
    Err(errors) => {
      println("Validation errors:")
      for e in errors {
        println("  \{e.to_string()}")
      }
    }
    Ok(_) => println("OK")
  }
  ""
}

///|
fn show_ts_interface() -> String {
  let order_schema = order_schema()
  @moon_zod.schema_to_prompt(order_schema)
}
