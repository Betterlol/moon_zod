///|
struct User {
  name : String
  age : Int
}

///|
fn User::from_json(json : Json) -> User {
  match json {
    Json::Object(map) => {
      let name = match map.get("name") {
        Some(Json::String(s)) => s
        _ => abort("missing name")
      }
      let age = match map.get("age") {
        Some(Json::Number(n, ..)) => n.to_int()
        _ => abort("missing age")
      }
      { name, age }
    }
    _ => abort("expected object")
  }
}

///|
fn user_schema() -> @moon_zod.Schema {
  @moon_zod.object({
    "name": @moon_zod.string().min(2).max(50),
    "age": @moon_zod.number().int().min(0).max(150),
  })
}

///|
struct Product {
  name : String
  price : Double
}

///|
fn Product::from_json(json : Json) -> Product {
  match json {
    Json::Object(map) => {
      let name = match map.get("name") {
        Some(Json::String(s)) => s
        _ => abort("missing name")
      }
      let price = match map.get("price") {
        Some(Json::Number(n, ..)) => n
        _ => abort("missing price")
      }
      { name, price }
    }
    _ => abort("expected object")
  }
}

///|
fn product_schema() -> @moon_zod.Schema {
  @moon_zod.object({
    "name": @moon_zod.string().min(1),
    "price": @moon_zod.number().positive(),
  })
}

///|
struct Order {
  user : User
  product : Product
}

///|
fn Order::from_json(json : Json) -> Order {
  match json {
    Json::Object(map) => {
      let user = match map.get("user") {
        Some(v) => User::from_json(v)
        _ => abort("missing user")
      }
      let product = match map.get("product") {
        Some(v) => Product::from_json(v)
        _ => abort("missing product")
      }
      { user, product }
    }
    _ => abort("expected object")
  }
}

///|
fn order_schema() -> @moon_zod.Schema {
  @moon_zod.object({ "user": user_schema(), "product": product_schema() })
}
