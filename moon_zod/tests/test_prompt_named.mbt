///|
/// Test schema_to_prompt_named: object and enum export
test "schema_to_prompt_named: object and enum export" {
  let user_schema = @core.object({
    "name": @core.string().min(2),
    "age": @core.number().int(),
  }).name("User")

  let mood_schema = @core.enum_values(["calm", "nervous", "angry"]).name("Mood")

  let order_schema = @core.object({ "user": user_schema, "mood": mood_schema }).name(
    "Order",
  )

  let prompt = @exporters.schema_to_prompt_named(order_schema)

  // Just check that we get some output
  @debug.assert_eq(prompt.length() > 0, true)
  @debug.assert_eq(prompt.contains("export interface User"), true)
  @debug.assert_eq(prompt.contains("name: string"), true)
  @debug.assert_eq(prompt.contains("age: number"), true)
  @debug.assert_eq(prompt.contains("type Mood"), true)
  @debug.assert_eq(prompt.contains("\"calm\" | \"nervous\" | \"angry\""), true)
  @debug.assert_eq(prompt.contains("user: User"), true)
  @debug.assert_eq(prompt.contains("mood: Mood"), true)
}

///|
/// Test schema_to_prompt_named: nested objects
test "schema_to_prompt_named: nested objects" {
  let address_schema = @core.object({
    "street": @core.string(),
    "city": @core.string(),
  }).name("Address")

  let person_schema = @core.object({
    "name": @core.string(),
    "address": address_schema,
  }).name("Person")

  let prompt = @exporters.schema_to_prompt_named(person_schema)

  // Just check that we get some output
  @debug.assert_eq(prompt.length() > 0, true)
  @debug.assert_eq(prompt.contains("export interface Address"), true)
  @debug.assert_eq(prompt.contains("street: string"), true)
  @debug.assert_eq(prompt.contains("city: string"), true)
  @debug.assert_eq(prompt.contains("address: Address"), true)
}

///|
/// Test schema_to_prompt_named: array of named objects
test "schema_to_prompt_named: array of named objects" {
  let item_schema = @core.object({
    "id": @core.string(),
    "title": @core.string(),
  }).name("Item")

  let list_schema = @core.object({ "items": @core.array(item_schema) }).name(
    "ItemList",
  )

  let prompt = @exporters.schema_to_prompt_named(list_schema)

  // Just check that we get some output
  @debug.assert_eq(prompt.length() > 0, true)
  @debug.assert_eq(prompt.contains("export interface Item"), true)
  @debug.assert_eq(prompt.contains("export interface ItemList"), true)
  @debug.assert_eq(prompt.contains("items: Item[]"), true)
}

///|
/// Test schema_to_prompt_named: deep nesting (3 levels)
test "schema_to_prompt_named: deep nesting" {
  let level3_schema = @core.object({ "value": @core.string() }).name("Level3")

  let level2_schema = @core.object({ "level3": level3_schema }).name("Level2")

  let level1_schema = @core.object({ "level2": level2_schema }).name("Level1")

  let prompt = @exporters.schema_to_prompt_named(level1_schema)

  // Should export all three levels
  @debug.assert_eq(prompt.contains("export interface Level1"), true)
  @debug.assert_eq(prompt.contains("export interface Level2"), true)
  @debug.assert_eq(prompt.contains("export interface Level3"), true)
}

///|
/// Test schema_to_prompt_named: topological sort
test "schema_to_prompt_named: topological sort" {
  // Create schemas in "reverse" order of dependency
  let address_schema = @core.object({ "street": @core.string() }).name(
    "Address",
  )

  let person_schema = @core.object({ "address": address_schema }).name("Person")

  let company_schema = @core.object({ "ceo": person_schema }).name("Company")

  let prompt = @exporters.schema_to_prompt_named(company_schema)

  // Address should appear before Person, Person before Company
  let address_pos = prompt.find("export interface Address")
  let person_pos = prompt.find("export interface Person")
  let company_pos = prompt.find("export interface Company")

  @debug.assert_eq(address_pos is Some(_), true)
  @debug.assert_eq(person_pos is Some(_), true)
  @debug.assert_eq(company_pos is Some(_), true)

  // Verify ordering: Address before Person before Company
  match (address_pos, person_pos, company_pos) {
    (Some(a), Some(p), Some(c)) => {
      @debug.assert_eq(a < p, true)
      @debug.assert_eq(p < c, true)
    }
    _ => @debug.assert_eq(true, false) // Should not happen
  }
}

///|
/// Test schema_to_prompt_named: optional named field
test "schema_to_prompt_named: optional named field" {
  let contact_schema = @core.object({ "email": @core.string() }).name("Contact")

  let user_schema = @core.object({
    "name": @core.string(),
    "contact": contact_schema.optional(),
  }).name("User")

  let prompt = @exporters.schema_to_prompt_named(user_schema)

  // Just verify that we get both interfaces generated
  @debug.assert_eq(prompt.length() > 0, true)
}

///|
test "schema_to_prompt_named uses named primitive references" {
  let username_schema = @core.string().min(3).name("Username")
  let user_schema = @core.object({ "name": username_schema }).name("User")

  let prompt = @exporters.schema_to_prompt_named(user_schema)

  @debug.assert_eq(prompt.contains("export type Username = string"), true)
  @debug.assert_eq(prompt.contains("name: Username"), true)
}

///|
test "schema_to_prompt_named emits named aliases for wrappers and containers" {
  let tags_schema = @core.array(@core.string().min(2)).name("Tags")
  let optional_schema = @core.string().optional().name("MaybeText")
  let default_schema = @core.number()
    .int()
    .default(Json::number(1))
    .name("Count")
  let transform_schema = @core.string()
    .transform(fn(j) { Ok(j) })
    .name("Transformed")
  let tuple_schema = @core.tuple([@core.string(), @core.number()]).name("Pair")
  let any_schema = @core.any().name("Anything")
  let unknown_schema = @core.unknown().name("Mystery")
  let preprocessed_schema = @core.preprocess(fn(j) { Ok(j) }, @core.string()).name(
    "Preprocessed",
  )
  let parent = @core.object({
    "tags": tags_schema,
    "maybe": optional_schema,
    "count": default_schema,
    "transformed": transform_schema,
    "pair": tuple_schema,
    "anything": any_schema,
    "mystery": unknown_schema,
    "preprocessed": preprocessed_schema,
  }).name("Parent")

  let prompt = @exporters.schema_to_prompt_named(parent)

  @debug.assert_eq(prompt.contains("export type Tags = string[]"), true)
  @debug.assert_eq(
    prompt.contains("export type MaybeText = string | undefined"),
    true,
  )
  @debug.assert_eq(prompt.contains("export type Count = number"), true)
  @debug.assert_eq(prompt.contains("export type Transformed = string"), true)
  @debug.assert_eq(prompt.contains("export type Pair = [string, number]"), true)
  @debug.assert_eq(prompt.contains("export type Anything = any"), true)
  @debug.assert_eq(prompt.contains("export type Mystery = unknown"), true)
  @debug.assert_eq(prompt.contains("export type Preprocessed = string"), true)
  @debug.assert_eq(prompt.contains("tags: Tags"), true)
  @debug.assert_eq(prompt.contains("maybe?: MaybeText"), true)
  @debug.assert_eq(prompt.contains("count?: Count"), true)
  @debug.assert_eq(prompt.contains("pair: Pair"), true)
}

///|
test "schema_to_prompt_named references named optional object wrappers" {
  let metadata_schema = @core.object({
      "description": @core.string().max(2000).optional(),
      "images": @core.array(@core.string().url()).max(10),
    })
    .optional()
    .name("ProductMetadata")
  let product_schema = @core.object({ "metadata": metadata_schema }).name(
    "Product",
  )

  let prompt = @exporters.schema_to_prompt_named(product_schema)

  @debug.assert_eq(
    prompt.contains("export type ProductMetadata = {") &&
    prompt.contains("} | undefined"),
    true,
  )
  @debug.assert_eq(prompt.contains("metadata?: ProductMetadata"), true)
}

///|
/// Test schema_to_prompt_named: union type export
test "schema_to_prompt_named: union type export" {
  let home_address_schema = @core.object({
    "type": @core.literal(Json::string("home")),
    "street": @core.string(),
  }).name("HomeAddress")

  let office_address_schema = @core.object({
    "type": @core.literal(Json::string("office")),
    "company": @core.string(),
  }).name("OfficeAddress")

  let address_schema = @core.union([home_address_schema, office_address_schema]).name(
    "Address",
  )

  let prompt = @exporters.schema_to_prompt_named(address_schema)

  // Verify union type is exported
  @debug.assert_eq(prompt.contains("export type Address"), true)
  @debug.assert_eq(prompt.contains("HomeAddress | OfficeAddress"), true)
}

///|
/// Test schema_to_prompt_named: intersection type export
test "schema_to_prompt_named: intersection type export" {
  let positive_schema = @core.object({ "id": @core.number().int().positive() }).name(
    "PositiveId",
  )
  let bounded_schema = @core.object({ "id": @core.number().int().max(100) }).name(
    "BoundedId",
  )
  let order_id_schema = @core.intersection([positive_schema, bounded_schema]).name(
    "OrderId",
  )

  let prompt = @exporters.schema_to_prompt_named(order_id_schema)

  @debug.assert_eq(prompt.contains("export interface PositiveId"), true)
  @debug.assert_eq(
    prompt.contains("id: number,  // [int, > 0, max: 9007199254740991]"),
    true,
  )
  @debug.assert_eq(prompt.contains("export interface BoundedId"), true)
  @debug.assert_eq(
    prompt.contains("id: number,  // [int, -9007199254740991-100]"),
    true,
  )
  @debug.assert_eq(
    prompt.contains("export type OrderId = PositiveId & BoundedId"),
    true,
  )
  @debug.assert_eq(prompt.contains("export interface OrderId"), false)
}

///|
test "schema_to_prompt_named: non-object intersection stays type expression" {
  let text_schema = @core.string().min(2).name("Text")
  let branded_schema = @core.string().brand("Brand")
  let combined_schema = @core.intersection([text_schema, branded_schema]).name(
    "BrandedText",
  )

  let prompt = @exporters.schema_to_prompt_named(combined_schema)

  @debug.assert_eq(prompt.contains("export type Text = string"), true)
  @debug.assert_eq(
    prompt.contains("export type BrandedText = Text & string"),
    true,
  )
  @debug.assert_eq(prompt.contains("export interface BrandedText"), false)
}

///|
/// Test schema_to_prompt_named: literal type export
test "schema_to_prompt_named: literal type export" {
  let status_schema = @core.literal(Json::string("active")).name("Status")

  let prompt = @exporters.schema_to_prompt_named(status_schema)

  // Verify literal type is exported
  @debug.assert_eq(prompt.contains("export type Status"), true)
  @debug.assert_eq(prompt.contains("\"active\""), true)
}

///|
/// Test schema_to_prompt_named: all schema types in one
test "schema_to_prompt_named: complex schema with all types" {
  // Create all 13 SchemaType variants
  let string_schema = @core.string().min(2).name("StringType")
  let number_schema = @core.number().int().name("NumberType")
  let boolean_schema = @core.boolean().name("BooleanType")
  let null_schema = @core.null().name("NullType")
  let array_schema = @core.array(@core.string()).name("ArrayType")
  let enum_schema = @core.enum_values(["a", "b", "c"]).name("EnumType")
  let literal_schema = @core.literal(Json::string("x")).name("LiteralType")
  let optional_schema = @core.string().optional().name("OptionalType")
  let default_schema = @core.string()
    .default(Json::string("default"))
    .name("DefaultType")
  let transform_schema = @core.string()
    .transform(fn(j) { Ok(j) })
    .name("TransformType")
  let union_schema = @core.union([@core.string(), @core.number()]).name(
    "UnionType",
  )
  let intersection_schema = @core.intersection([
    @core.object({ "x": @core.number() }),
    @core.object({ "y": @core.string() }),
  ]).name("IntersectionType")
  let object_schema = @core.object({
    "field1": @core.string(),
    "field2": @core.number(),
  }).name("ObjectType")

  // Create a parent schema that references all of them
  let parent = @core.object({
    "str": string_schema,
    "num": number_schema,
    "bool": boolean_schema,
    "null": null_schema,
    "arr": array_schema,
    "enum": enum_schema,
    "literal": literal_schema,
    "optional": optional_schema,
    "default": default_schema,
    "transform": transform_schema,
    "union": union_schema,
    "intersection": intersection_schema,
    "obj": object_schema,
  }).name("Parent")

  let prompt = @exporters.schema_to_prompt_named(parent)

  // Verify all named types are exported (except wrapper types like Optional/Default/Transform)
  @debug.assert_eq(prompt.contains("StringType"), true)
  @debug.assert_eq(prompt.contains("NumberType"), true)
  @debug.assert_eq(prompt.contains("BooleanType"), true)
  @debug.assert_eq(prompt.contains("NullType"), true)
  @debug.assert_eq(prompt.contains("ArrayType"), true)
  @debug.assert_eq(prompt.contains("EnumType"), true)
  @debug.assert_eq(prompt.contains("LiteralType"), true)
  @debug.assert_eq(prompt.contains("UnionType"), true)
  @debug.assert_eq(prompt.contains("IntersectionType"), true)
  @debug.assert_eq(prompt.contains("ObjectType"), true)
}

///|
/// Test schema_to_prompt_named with include_names: default (None)
test "schema_to_prompt_named with include_names: default (None)" {
  let user_schema = @core.object({
    "name": @core.string(),
    "age": @core.number(),
  }).name("User")
  let product_schema = @core.object({
    "name": @core.string(),
    "price": @core.number(),
  }).name("Product")
  let order_schema = @core.object({
    "user": user_schema,
    "product": product_schema,
  }).name("Order")

  // Default behavior: include_names not provided (exports all)
  let prompt_all = @exporters.schema_to_prompt_named(order_schema)

  // Both should contain all three names
  @debug.assert_eq(prompt_all.contains("export interface User"), true)
  @debug.assert_eq(prompt_all.contains("export interface Product"), true)
  @debug.assert_eq(prompt_all.contains("export interface Order"), true)
}

///|
/// Test schema_to_prompt_named with include_names: selective export
test "schema_to_prompt_named with include_names: selective export" {
  let user_schema = @core.object({ "name": @core.string() }).name("User")
  let product_schema = @core.object({ "name": @core.string() }).name("Product")
  let order_schema = @core.object({
    "user": user_schema,
    "product": product_schema,
  }).name("Order")

  // Selective export: only Order
  let prompt_only_order = @exporters.schema_to_prompt_named(
    order_schema,
    include_names=Some(["Order"]),
  )

  // Should only contain Order, not User or Product
  @debug.assert_eq(prompt_only_order.contains("export interface Order"), true)
  @debug.assert_eq(prompt_only_order.contains("export interface User"), false)
  @debug.assert_eq(
    prompt_only_order.contains("export interface Product"),
    false,
  )
}

///|
/// Test schema_to_prompt_named with include_names: partial export
test "schema_to_prompt_named with include_names: partial export" {
  let user_schema = @core.object({ "name": @core.string() }).name("User")
  let product_schema = @core.object({ "name": @core.string() }).name("Product")
  let order_schema = @core.object({
    "user": user_schema,
    "product": product_schema,
  }).name("Order")

  // Selective export: Order and User, but not Product
  let prompt_order_user = @exporters.schema_to_prompt_named(
    order_schema,
    include_names=Some(["Order", "User"]),
  )

  // Should contain Order and User, but not Product
  @debug.assert_eq(prompt_order_user.contains("export interface Order"), true)
  @debug.assert_eq(prompt_order_user.contains("export interface User"), true)
  @debug.assert_eq(
    prompt_order_user.contains("export interface Product"),
    false,
  )
}

///|
/// Test schema_to_prompt_named with include_names: empty list
test "schema_to_prompt_named with include_names: empty list" {
  let user_schema = @core.object({ "name": @core.string() }).name("User")
  let order_schema = @core.object({ "user": user_schema }).name("Order")

  // Selective export: empty list
  let prompt_empty = @exporters.schema_to_prompt_named(
    order_schema,
    include_names=Some([]),
  )

  // Should not contain any interface definitions (empty export)
  @debug.assert_eq(prompt_empty.contains("export interface"), false)
}

///|
/// Test schema_to_prompt_named with include_names: non-existent name
test "schema_to_prompt_named with include_names: non-existent name" {
  let user_schema = @core.object({ "name": @core.string() }).name("User")
  let order_schema = @core.object({ "user": user_schema }).name("Order")

  // Selective export: non-existent name
  let prompt_non_existent = @exporters.schema_to_prompt_named(
    order_schema,
    include_names=Some(["NonExistent"]),
  )

  // Should not contain any of the actual schemas
  @debug.assert_eq(prompt_non_existent.contains("export interface User"), false)
  @debug.assert_eq(
    prompt_non_existent.contains("export interface Order"),
    false,
  )
}

///|
/// Test schema_to_prompt_named with include_names: multiple valid names
test "schema_to_prompt_named with include_names: multiple valid names" {
  let address_schema = @core.object({ "street": @core.string() }).name(
    "Address",
  )
  let user_schema = @core.object({
    "name": @core.string(),
    "address": address_schema,
  }).name("User")
  let product_schema = @core.object({ "name": @core.string() }).name("Product")
  let order_schema = @core.object({
    "user": user_schema,
    "product": product_schema,
  }).name("Order")

  // Export: User, Address, Order (skip Product)
  let prompt_filtered = @exporters.schema_to_prompt_named(
    order_schema,
    include_names=Some(["User", "Address", "Order"]),
  )

  // Verify includes and excludes
  @debug.assert_eq(prompt_filtered.contains("export interface User"), true)
  @debug.assert_eq(prompt_filtered.contains("export interface Address"), true)
  @debug.assert_eq(prompt_filtered.contains("export interface Order"), true)
  @debug.assert_eq(prompt_filtered.contains("export interface Product"), false)
}
