///| Test schema_to_prompt_named: object and enum export
test "schema_to_prompt_named: object and enum export" {
  let user_schema = object({
    "name": string().min(2),
    "age": number().int(),
  }).name("User")

  let mood_schema = enum_values(["calm", "nervous", "angry"]).name("Mood")

  let order_schema = object({
    "user": user_schema,
    "mood": mood_schema,
  }).name("Order")

  let prompt = schema_to_prompt_named(order_schema)

  // Just check that we get some output
  @debug.assert_eq(prompt.length() > 0, true)
}

///| Test schema_to_prompt_named: nested objects
test "schema_to_prompt_named: nested objects" {
  let address_schema = object({
    "street": string(),
    "city": string(),
  }).name("Address")

  let person_schema = object({
    "name": string(),
    "address": address_schema,
  }).name("Person")

  let prompt = schema_to_prompt_named(person_schema)

  // Just check that we get some output
  @debug.assert_eq(prompt.length() > 0, true)
}

///| Test schema_to_prompt_named: array of named objects
test "schema_to_prompt_named: array of named objects" {
  let item_schema = object({
    "id": string(),
    "title": string(),
  }).name("Item")

  let list_schema = object({
    "items": array(item_schema),
  }).name("ItemList")

  let prompt = schema_to_prompt_named(list_schema)

  // Just check that we get some output
  @debug.assert_eq(prompt.length() > 0, true)
}
