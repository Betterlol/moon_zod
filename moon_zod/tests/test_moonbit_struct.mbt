///|
test "schema_to_moonbit_struct emits root object struct" {
  let schema = @core.object({
    "name": @core.string(),
    "age": @core.number().int(),
  }).name("User")
  let result = @exporters.schema_to_moonbit_struct(schema)

  @debug.assert_eq(result.contains("pub struct User"), true)
  @debug.assert_eq(result.contains("name : String"), true)
  @debug.assert_eq(result.contains("age : Int64"), true)
}

///|
test "schema_to_moonbit_struct emits nested object structs" {
  let schema = @core.object({
    "name": @core.string(),
    "profile": @core.object({ "city": @core.string(), "score": @core.number() }),
  }).name("User")
  let result = @exporters.schema_to_moonbit_struct(schema)

  @debug.assert_eq(result.contains("pub struct UserProfile"), true)
  @debug.assert_eq(result.contains("city : String"), true)
  @debug.assert_eq(result.contains("score : Double"), true)
  @debug.assert_eq(result.contains("pub struct User"), true)
  @debug.assert_eq(result.contains("profile : UserProfile"), true)
}

///|
test "schema_to_moonbit_struct emits array element object structs" {
  let schema = @core.object({
    "items": @core.array(
      @core.object({ "id": @core.string(), "active": @core.boolean() }),
    ),
  }).name("Catalog")
  let result = @exporters.schema_to_moonbit_struct(schema)

  @debug.assert_eq(result.contains("pub struct CatalogItemsItem"), true)
  @debug.assert_eq(result.contains("id : String"), true)
  @debug.assert_eq(result.contains("active : Bool"), true)
  @debug.assert_eq(result.contains("items : Array[CatalogItemsItem]"), true)
}

///|
test "schema_to_moonbit_struct uses schema name only as type hint" {
  let schema = @core.object({
    "shipping": @core.object({ "city": @core.string() }).name("Address"),
    "billing": @core.object({ "city": @core.string() }),
  }).name("Order")
  let result = @exporters.schema_to_moonbit_struct(schema)

  @debug.assert_eq(result.contains("pub struct Address"), true)
  @debug.assert_eq(result.contains("shipping : Address"), true)
  @debug.assert_eq(result.contains("pub struct OrderBilling"), true)
  @debug.assert_eq(result.contains("billing : OrderBilling"), true)
}

///|
test "schema_to_moonbit_struct emits enum definitions for enum fields" {
  let schema = @core.object({
    "status": @core.enum_values(["pending", "shipped", "404"]),
  }).name("Order")
  let result = @exporters.schema_to_moonbit_struct(schema)

  @debug.assert_eq(result.contains("pub enum OrderStatus"), true)
  @debug.assert_eq(result.contains("Pending"), true)
  @debug.assert_eq(result.contains("Shipped"), true)
  @debug.assert_eq(result.contains("V404"), true)
  @debug.assert_eq(result.contains("status : OrderStatus"), true)
}

///|
test "schema_to_moonbit_struct handles optional default and nullable fields" {
  let schema = @core.object({
    "email": @core.string().optional(),
    "role": @core.string().default(Json::string("user")),
    "note": @core.union([@core.string(), @core.null()]),
  }).name("User")
  let result = @exporters.schema_to_moonbit_struct(schema)

  @debug.assert_eq(result.contains("email : String?"), true)
  @debug.assert_eq(result.contains("role : String"), true)
  @debug.assert_eq(
    result.contains("note : @moon_zod.JsonNullable[String]"),
    true,
  )
}

///|
test "schema_to_moonbit_struct keeps constraint comments" {
  let schema = @core.object({
    "name": @core.string().min(2).max(50),
    "tags": @core.array(@core.string()).min(1),
  }).name("Product")
  let result = @exporters.schema_to_moonbit_struct(schema)

  @debug.assert_eq(result.contains("name : String  // 2-50 chars"), true)
  @debug.assert_eq(
    result.contains("tags : Array[String]  // min: 1 items"),
    true,
  )
}

///|
test "schema_to_moonbit_struct_full emits static to_schema functions" {
  let schema = @core.object({
    "profile": @core.object({ "city": @core.string() }),
    "status": @core.enum_values(["active", "inactive"]),
  }).name("User")
  let result = @exporters.schema_to_moonbit_struct_full(schema)

  @debug.assert_eq(result.contains("pub fn UserProfile::to_schema()"), true)
  @debug.assert_eq(result.contains("pub fn UserStatus::to_schema()"), true)
  @debug.assert_eq(result.contains("pub fn User::to_schema()"), true)
  @debug.assert_eq(result.contains("@moon_zod.object"), true)
  @debug.assert_eq(result.contains("@moon_zod.enum_values"), true)
  @debug.assert_eq(result.contains("from_json"), false)
}

///|
test "schema_to_moonbit_struct assigns Root to unnamed root object" {
  let result = @exporters.schema_to_moonbit_struct(
    @core.object({ "value": @core.string() }),
  )

  @debug.assert_eq(result.contains("pub struct Root"), true)
  @debug.assert_eq(result.contains("value : String"), true)
}

///|
test "schema_to_moonbit_struct reports unsupported root schemas" {
  let result = @exporters.schema_to_moonbit_struct(@core.string())

  @debug.assert_eq(result.contains("does not contain any object or enum"), true)
}
