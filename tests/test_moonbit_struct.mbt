///|
test "schema_to_moonbit_struct emits root object struct" {
  let schema = object({ "name": string(), "age": number().int() }).name("User")
  let result = schema_to_moonbit_struct(schema)

  @debug.assert_eq(result.contains("pub struct User"), true)
  @debug.assert_eq(result.contains("name : String"), true)
  @debug.assert_eq(result.contains("age : Int64"), true)
}

///|
test "schema_to_moonbit_struct emits nested object structs" {
  let schema = object({
    "name": string(),
    "profile": object({ "city": string(), "score": number() }),
  }).name("User")
  let result = schema_to_moonbit_struct(schema)

  @debug.assert_eq(result.contains("pub struct UserProfile"), true)
  @debug.assert_eq(result.contains("city : String"), true)
  @debug.assert_eq(result.contains("score : Double"), true)
  @debug.assert_eq(result.contains("pub struct User"), true)
  @debug.assert_eq(result.contains("profile : UserProfile"), true)
}

///|
test "schema_to_moonbit_struct emits array element object structs" {
  let schema = object({
    "items": array(object({ "id": string(), "active": boolean() })),
  }).name("Catalog")
  let result = schema_to_moonbit_struct(schema)

  @debug.assert_eq(result.contains("pub struct CatalogItemsItem"), true)
  @debug.assert_eq(result.contains("id : String"), true)
  @debug.assert_eq(result.contains("active : Bool"), true)
  @debug.assert_eq(result.contains("items : Array[CatalogItemsItem]"), true)
}

///|
test "schema_to_moonbit_struct uses schema name only as type hint" {
  let schema = object({
    "shipping": object({ "city": string() }).name("Address"),
    "billing": object({ "city": string() }),
  }).name("Order")
  let result = schema_to_moonbit_struct(schema)

  @debug.assert_eq(result.contains("pub struct Address"), true)
  @debug.assert_eq(result.contains("shipping : Address"), true)
  @debug.assert_eq(result.contains("pub struct OrderBilling"), true)
  @debug.assert_eq(result.contains("billing : OrderBilling"), true)
}

///|
test "schema_to_moonbit_struct emits enum definitions for enum fields" {
  let schema = object({ "status": enum_values(["pending", "shipped", "404"]) }).name(
    "Order",
  )
  let result = schema_to_moonbit_struct(schema)

  @debug.assert_eq(result.contains("pub enum OrderStatus"), true)
  @debug.assert_eq(result.contains("Pending"), true)
  @debug.assert_eq(result.contains("Shipped"), true)
  @debug.assert_eq(result.contains("V404"), true)
  @debug.assert_eq(result.contains("status : OrderStatus"), true)
}

///|
test "schema_to_moonbit_struct handles optional default and nullable fields" {
  let schema = object({
    "email": string().optional(),
    "role": string().default(Json::string("user")),
    "note": union([string(), null()]),
  }).name("User")
  let result = schema_to_moonbit_struct(schema)

  @debug.assert_eq(result.contains("email? : String"), true)
  @debug.assert_eq(result.contains("role? : String"), true)
  @debug.assert_eq(result.contains("note? : String"), true)
}

///|
test "schema_to_moonbit_struct keeps constraint comments" {
  let schema = object({
    "name": string().min(2).max(50),
    "tags": array(string()).min(1),
  }).name("Product")
  let result = schema_to_moonbit_struct(schema)

  @debug.assert_eq(result.contains("name : String  // 2-50 chars"), true)
  @debug.assert_eq(
    result.contains("tags : Array[String]  // min: 1 items"),
    true,
  )
}

///|
test "schema_to_moonbit_struct_full emits static to_schema functions" {
  let schema = object({
    "profile": object({ "city": string() }),
    "status": enum_values(["active", "inactive"]),
  }).name("User")
  let result = schema_to_moonbit_struct_full(schema)

  @debug.assert_eq(result.contains("pub fn UserProfile::to_schema()"), true)
  @debug.assert_eq(result.contains("pub fn UserStatus::to_schema()"), true)
  @debug.assert_eq(result.contains("pub fn User::to_schema()"), true)
  @debug.assert_eq(result.contains("@moon_zod.object"), true)
  @debug.assert_eq(result.contains("@moon_zod.enum_values"), true)
  @debug.assert_eq(result.contains("from_json"), false)
}

///|
test "schema_to_moonbit_struct assigns Root to unnamed root object" {
  let result = schema_to_moonbit_struct(object({ "value": string() }))

  @debug.assert_eq(result.contains("pub struct Root"), true)
  @debug.assert_eq(result.contains("value : String"), true)
}

///|
test "schema_to_moonbit_struct reports unsupported root schemas" {
  let result = schema_to_moonbit_struct(string())

  @debug.assert_eq(result.contains("does not contain any object or enum"), true)
}
