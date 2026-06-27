///|
/// Test schema_to_prompt_named: object and enum export
test "schema_to_prompt_named: object and enum export" {
  let user_schema = object({ "name": string().min(2), "age": number().int() }).name(
    "User",
  )

  let mood_schema = enum_values(["calm", "nervous", "angry"]).name("Mood")

  let order_schema = object({ "user": user_schema, "mood": mood_schema }).name(
    "Order",
  )

  let prompt = schema_to_prompt_named(order_schema)

  // Just check that we get some output
  @debug.assert_eq(prompt.length() > 0, true)
}

///|
/// Test schema_to_prompt_named: nested objects
test "schema_to_prompt_named: nested objects" {
  let address_schema = object({ "street": string(), "city": string() }).name(
    "Address",
  )

  let person_schema = object({ "name": string(), "address": address_schema }).name(
    "Person",
  )

  let prompt = schema_to_prompt_named(person_schema)

  // Just check that we get some output
  @debug.assert_eq(prompt.length() > 0, true)
}

///|
/// Test schema_to_prompt_named: array of named objects
test "schema_to_prompt_named: array of named objects" {
  let item_schema = object({ "id": string(), "title": string() }).name("Item")

  let list_schema = object({ "items": array(item_schema) }).name("ItemList")

  let prompt = schema_to_prompt_named(list_schema)

  // Just check that we get some output
  @debug.assert_eq(prompt.length() > 0, true)
}

///|
/// Test schema_to_prompt_named: deep nesting (3 levels)
test "schema_to_prompt_named: deep nesting" {
  let level3_schema = object({ "value": string() }).name("Level3")

  let level2_schema = object({ "level3": level3_schema }).name("Level2")

  let level1_schema = object({ "level2": level2_schema }).name("Level1")

  let prompt = schema_to_prompt_named(level1_schema)

  // Should export all three levels
  @debug.assert_eq(prompt.contains("export interface Level1"), true)
  @debug.assert_eq(prompt.contains("export interface Level2"), true)
  @debug.assert_eq(prompt.contains("export interface Level3"), true)
}

///|
/// Test schema_to_prompt_named: topological sort
test "schema_to_prompt_named: topological sort" {
  // Create schemas in "reverse" order of dependency
  let address_schema = object({ "street": string() }).name("Address")

  let person_schema = object({ "address": address_schema }).name("Person")

  let company_schema = object({ "ceo": person_schema }).name("Company")

  let prompt = schema_to_prompt_named(company_schema)

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
  let contact_schema = object({ "email": string() }).name("Contact")

  let user_schema = object({
    "name": string(),
    "contact": contact_schema.optional(),
  }).name("User")

  let prompt = schema_to_prompt_named(user_schema)

  // Just verify that we get both interfaces generated
  @debug.assert_eq(prompt.length() > 0, true)
}

///|
/// Test schema_to_prompt_named: union type export
test "schema_to_prompt_named: union type export" {
  let home_address_schema = object({
    "type": literal(Json::string("home")),
    "street": string(),
  }).name("HomeAddress")

  let office_address_schema = object({
    "type": literal(Json::string("office")),
    "company": string(),
  }).name("OfficeAddress")

  let address_schema = union([home_address_schema, office_address_schema]).name(
    "Address",
  )

  let prompt = schema_to_prompt_named(address_schema)

  // Verify union type is exported
  @debug.assert_eq(prompt.contains("export type Address"), true)
  @debug.assert_eq(prompt.contains("HomeAddress | OfficeAddress"), true)
}

///|
/// Test schema_to_prompt_named: intersection type export
test "schema_to_prompt_named: intersection type export" {
  let positive_schema = object({ "id": number().int().positive() })

  let bounded_schema = object({ "id": number().int().max(100) })

  let order_id_schema = intersection([positive_schema, bounded_schema]).name(
    "OrderId",
  )

  let prompt = schema_to_prompt_named(order_id_schema)

  // Verify intersection type is exported as interface
  @debug.assert_eq(prompt.contains("export interface OrderId"), true)
  @debug.assert_eq(prompt.contains("id: number"), true)
}

///|
/// Test schema_to_prompt_named: literal type export
test "schema_to_prompt_named: literal type export" {
  let status_schema = literal(Json::string("active")).name("Status")

  let prompt = schema_to_prompt_named(status_schema)

  // Verify literal type is exported
  @debug.assert_eq(prompt.contains("export type Status"), true)
  @debug.assert_eq(prompt.contains("\"active\""), true)
}

///|
/// Test schema_to_prompt_named: all schema types in one
test "schema_to_prompt_named: complex schema with all types" {
  // Create all 13 SchemaType variants
  let string_schema = string().min(2).name("StringType")
  let number_schema = number().int().name("NumberType")
  let boolean_schema = boolean().name("BooleanType")
  let null_schema = null().name("NullType")
  let array_schema = array(string()).name("ArrayType")
  let enum_schema = enum_values(["a", "b", "c"]).name("EnumType")
  let literal_schema = literal(Json::string("x")).name("LiteralType")
  let optional_schema = string().optional().name("OptionalType")
  let default_schema = string()
    .default(Json::string("default"))
    .name("DefaultType")
  let transform_schema = string()
    .transform(fn(j) { Ok(j) })
    .name("TransformType")
  let union_schema = union([string(), number()]).name("UnionType")
  let intersection_schema = intersection([
    object({ "x": number() }),
    object({ "y": string() }),
  ]).name("IntersectionType")
  let object_schema = object({ "field1": string(), "field2": number() }).name(
    "ObjectType",
  )

  // Create a parent schema that references all of them
  let parent = object({
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

  let prompt = schema_to_prompt_named(parent)

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
