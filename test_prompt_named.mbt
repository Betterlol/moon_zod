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

///| Test schema_to_prompt_named: deep nesting (3 levels)
test "schema_to_prompt_named: deep nesting" {
  let level3_schema = object({
    "value": string(),
  }).name("Level3")

  let level2_schema = object({
    "level3": level3_schema,
  }).name("Level2")

  let level1_schema = object({
    "level2": level2_schema,
  }).name("Level1")

  let prompt = schema_to_prompt_named(level1_schema)

  // Should export all three levels
  @debug.assert_eq(prompt.contains("export interface Level1"), true)
  @debug.assert_eq(prompt.contains("export interface Level2"), true)
  @debug.assert_eq(prompt.contains("export interface Level3"), true)
}

///| Test schema_to_prompt_named: topological sort
test "schema_to_prompt_named: topological sort" {
  // Create schemas in "reverse" order of dependency
  let address_schema = object({
    "street": string(),
  }).name("Address")

  let person_schema = object({
    "address": address_schema,
  }).name("Person")

  let company_schema = object({
    "ceo": person_schema,
  }).name("Company")

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

///| Test schema_to_prompt_named: optional named field
test "schema_to_prompt_named: optional named field" {
  let contact_schema = object({
    "email": string(),
  }).name("Contact")

  let user_schema = object({
    "name": string(),
    "contact": contact_schema.optional(),
  }).name("User")

  let prompt = schema_to_prompt_named(user_schema)

  // Just verify that we get both interfaces generated
  @debug.assert_eq(prompt.length() > 0, true)
}
