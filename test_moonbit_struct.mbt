///|
test "schema_to_moonbit_struct unnamed schema returns comment" {
  let result = schema_to_moonbit_struct(string())
  @debug.assert_eq(result.contains("no name"), true)
}

///|
test "schema_to_moonbit_struct non-object type returns comment" {
  let result = schema_to_moonbit_struct(string().name("MyString"))
  @debug.assert_eq(result.contains("not an ObjectType"), true)
}

///|
test "schema_to_moonbit_struct object with string field" {
  let s = object({ "name": string() }).name("User")
  let result = schema_to_moonbit_struct(s)
  let expected = "pub struct User {\n" + "  name : String\n" + "}"
  @debug.assert_eq(result, expected)
}

///|
test "schema_to_moonbit_struct object with int64 field" {
  let s = object({ "age": number().int() }).name("Person")
  let result = schema_to_moonbit_struct(s)
  @debug.assert_eq(result.contains("age : Int64"), true)
}

///|
test "schema_to_moonbit_struct object with double field" {
  let s = object({ "score": number() }).name("Score")
  let result = schema_to_moonbit_struct(s)
  @debug.assert_eq(result.contains("score : Double"), true)
}

///|
test "schema_to_moonbit_struct object with boolean field" {
  let s = object({ "active": boolean() }).name("Status")
  let result = schema_to_moonbit_struct(s)
  @debug.assert_eq(result.contains("active : Bool"), true)
}

///|
test "schema_to_moonbit_struct object with optional field" {
  let s = object({ "email": string().optional() }).name("Contact")
  let result = schema_to_moonbit_struct(s)
  @debug.assert_eq(result.contains("email? : String"), true)
}

///|
test "schema_to_moonbit_struct object with default field" {
  let s = object({ "role": string().default(Json::string("user")) }).name(
    "Config",
  )
  let result = schema_to_moonbit_struct(s)
  @debug.assert_eq(result.contains("role? : String"), true)
}

///|
test "schema_to_moonbit_struct object with array field" {
  let s = object({ "tags": array(string()) }).name("Tagged")
  let result = schema_to_moonbit_struct(s)
  @debug.assert_eq(result.contains("tags : Array[String]"), true)
}

///|
test "schema_to_moonbit_struct object with nullable field" {
  let s = object({ "note": union([string(), null()]) }).name("Nullable")
  let result = schema_to_moonbit_struct(s)
  @debug.assert_eq(result.contains("note : String?"), true)
}

///|
test "schema_to_moonbit_struct empty object" {
  let s = object({}).name("Empty")
  let result = schema_to_moonbit_struct(s)
  @debug.assert_eq(result, "pub struct Empty {}")
}

///|
test "schema_to_moonbit_struct enum" {
  let s = enum_values(["calm", "nervous", "angry"]).name("Mood")
  let result = schema_to_moonbit_struct(s)
  let expected = "pub enum Mood {\n" +
    "  Calm\n" +
    "  Nervous\n" +
    "  Angry\n" +
    "}"
  @debug.assert_eq(result, expected)
}

///|
test "schema_to_moonbit_struct union type comment" {
  let s = object({ "mixed": union([string(), number()]) }).name("Mixed")
  let result = schema_to_moonbit_struct(s)
  @debug.assert_eq(result.contains("TODO: union type"), true)
}

///|
test "schema_to_moonbit_struct_named nested objects" {
  let address = object({ "city": string() }).name("Address")
  let person = object({ "name": string(), "addr": address }).name("Person")
  let result = schema_to_moonbit_struct_named(person)

  @debug.assert_eq(result.contains("pub struct Address"), true)
  @debug.assert_eq(result.contains("pub struct Person"), true)
  @debug.assert_eq(result.contains("addr : Address"), true)
}

///|
test "schema_to_moonbit_struct_named enum export" {
  let mood = enum_values(["calm", "nervous"]).name("Mood")
  let state = object({ "mood": mood }).name("State")
  let result = schema_to_moonbit_struct_named(state)

  @debug.assert_eq(result.contains("pub enum Mood"), true)
  @debug.assert_eq(result.contains("mood : Mood"), true)
}

///|
test "schema_to_moonbit_struct_named topological sort" {
  let address = object({ "street": string() }).name("Address")
  let person = object({ "address": address }).name("Person")
  let company = object({ "ceo": person }).name("Company")

  let result = schema_to_moonbit_struct_named(company)

  // Address should appear before Person, Person before Company
  let pos_addr = result.find("pub struct Address")
  let pos_person = result.find("pub struct Person")
  let pos_company = result.find("pub struct Company")

  match (pos_addr, pos_person, pos_company) {
    (Some(a), Some(p), Some(c)) => {
      @debug.assert_eq(a < p, true)
      @debug.assert_eq(p < c, true)
    }
    _ => @debug.assert_eq(true, false)
  }
}

///|
test "schema_to_moonbit_struct_named deep nesting" {
  let level3 = object({ "value": string() }).name("Level3")
  let level2 = object({ "level3": level3 }).name("Level2")
  let level1 = object({ "level2": level2 }).name("Level1")

  let result = schema_to_moonbit_struct_named(level1)

  @debug.assert_eq(result.contains("pub struct Level1"), true)
  @debug.assert_eq(result.contains("pub struct Level2"), true)
  @debug.assert_eq(result.contains("pub struct Level3"), true)
}

///|
test "schema_to_moonbit_struct_named array of named" {
  let item = object({ "id": string() }).name("Item")
  let list = object({ "items": array(item) }).name("ItemList")

  let result = schema_to_moonbit_struct_named(list)

  @debug.assert_eq(result.contains("pub struct Item"), true)
  @debug.assert_eq(result.contains("pub struct ItemList"), true)
  @debug.assert_eq(result.contains("items : Array[Item]"), true)
}

///|
test "schema_to_moonbit_struct object with constraint comment" {
  let s = object({ "name": string().min(2).max(50) }).name("Constrained")
  let result = schema_to_moonbit_struct(s)

  @debug.assert_eq(result.contains("name : String"), true)
  @debug.assert_eq(result.contains("2-50 chars"), true)
}

///|
test "schema_to_moonbit_struct multiple fields" {
  let s = object({
    "name": string(),
    "age": number().int(),
    "active": boolean(),
    "score": number(),
    "email": string().optional(),
  }).name("FullStruct")

  let result = schema_to_moonbit_struct(s)

  @debug.assert_eq(result.contains("name : String"), true)
  @debug.assert_eq(result.contains("age : Int64"), true)
  @debug.assert_eq(result.contains("active : Bool"), true)
  @debug.assert_eq(result.contains("score : Double"), true)
  @debug.assert_eq(result.contains("email? : String"), true)
}

///|
test "schema_to_moonbit_struct_named no named schemas" {
  let s = object({ "x": string() })
  let result = schema_to_moonbit_struct_named(s)
  @debug.assert_eq(result, "// No named schemas found")
}

///|
test "schema_to_moonbit_struct_named empty comment for unnamed root" {
  let s = object({ "x": string() }).name("Root")
  let result = schema_to_moonbit_struct_named(s)
  @debug.assert_eq(result.contains("pub struct Root"), true)
  @debug.assert_eq(result.contains("x : String"), true)
}

// ─── Phase 29: schema_to_moonbit_struct_full tests ───

///|
test "full unnamed schema returns comment" {
  let result = schema_to_moonbit_struct_full(string())
  @debug.assert_eq(result.contains("no name"), true)
}

///|
test "full output contains struct and fn" {
  let s = object({ "name": string() }).name("User")
  let result = schema_to_moonbit_struct_full(s)
  @debug.assert_eq(result.contains("pub struct User"), true)
  @debug.assert_eq(result.contains("pub fn user_from_json"), true)
  @debug.assert_eq(
    result.contains("Result[User, Array[ValidationError]]"),
    true,
  )
}

///|
test "full string field extraction" {
  let s = object({ "name": string() }).name("User")
  let result = schema_to_moonbit_struct_full(s)
  @debug.assert_eq(result.contains("String(s) => s"), true)
  @debug.assert_eq(result.contains("expected string"), true)
}

///|
test "full int64 field extraction" {
  let s = object({ "age": number().int() }).name("Person")
  let result = schema_to_moonbit_struct_full(s)
  @debug.assert_eq(result.contains("Number(v, ..) => v.to_int()"), true)
  @debug.assert_eq(result.contains("expected integer"), true)
}

///|
test "full double field extraction" {
  let s = object({ "score": number() }).name("Score")
  let result = schema_to_moonbit_struct_full(s)
  @debug.assert_eq(result.contains("Number(v, ..) => v"), true)
  @debug.assert_eq(result.contains("expected number"), true)
}

///|
test "full bool field extraction" {
  let s = object({ "active": boolean() }).name("Status")
  let result = schema_to_moonbit_struct_full(s)
  @debug.assert_eq(result.contains("True => true"), true)
  @debug.assert_eq(result.contains("False => false"), true)
  @debug.assert_eq(result.contains("expected boolean"), true)
}

///|
test "full optional field extraction" {
  let s = object({ "email": string().optional() }).name("Contact")
  let result = schema_to_moonbit_struct_full(s)
  @debug.assert_eq(result.contains("Some(Null) | None => None"), true)
}

///|
test "full default field transparent" {
  let s = object({ "role": string().default(Json::string("user")) }).name(
    "Config",
  )
  let result = schema_to_moonbit_struct_full(s)
  @debug.assert_eq(result.contains("Some(Null) | None => None"), true)
}

///|
test "full array field extraction" {
  let s = object({ "tags": array(string()) }).name("Tagged")
  let result = schema_to_moonbit_struct_full(s)
  @debug.assert_eq(result.contains("Array(elems) =>"), true)
  @debug.assert_eq(result.contains("let mut items : Array[String] = []"), true)
}

///|
test "full top-level object match" {
  let s = object({ "name": string() }).name("User")
  let result = schema_to_moonbit_struct_full(s)
  @debug.assert_eq(result.contains("match json {"), true)
  @debug.assert_eq(result.contains("Object(map) =>"), true)
}

///|
test "full required field error" {
  let s = object({ "name": string() }).name("User")
  let result = schema_to_moonbit_struct_full(s)
  @debug.assert_eq(result.contains("None => return Err("), true)
  @debug.assert_eq(result.contains("required"), true)
}

///|
test "full wrong type error" {
  let s = object({ "name": string() }).name("User")
  let result = schema_to_moonbit_struct_full(s)
  @debug.assert_eq(result.contains("return Err([ValidationError::"), true)
}

///|
test "full named export nested delegation" {
  let address = object({ "city": string() }).name("Address")
  let person = object({ "addr": address }).name("Person")
  let result = schema_to_moonbit_struct_named_full(person)

  @debug.assert_eq(result.contains("pub struct Address"), true)
  @debug.assert_eq(result.contains("pub struct Person"), true)
  @debug.assert_eq(result.contains("pub fn address_from_json"), true)
  @debug.assert_eq(result.contains("pub fn person_from_json"), true)
  @debug.assert_eq(result.contains("address_from_json(v)"), true)
}

///|
test "full named export topological sort" {
  let address = object({ "street": string() }).name("Address")
  let person = object({ "address": address }).name("Person")
  let company = object({ "ceo": person }).name("Company")

  let result = schema_to_moonbit_struct_named_full(company)

  let pos_addr = result.find("pub struct Address")
  let pos_person = result.find("pub struct Person")
  let pos_company = result.find("pub struct Company")

  match (pos_addr, pos_person, pos_company) {
    (Some(a), Some(p), Some(c)) => {
      @debug.assert_eq(a < p, true)
      @debug.assert_eq(p < c, true)
    }
    _ => @debug.assert_eq(true, false)
  }
}

///|
test "full no named schemas" {
  let s = object({ "x": string() })
  let result = schema_to_moonbit_struct_named_full(s)
  @debug.assert_eq(result, "// No named schemas found")
}

///|
test "full multiple fields extraction" {
  let s = object({
    "name": string(),
    "age": number().int(),
    "active": boolean(),
    "score": number(),
    "email": string().optional(),
  }).name("FullStruct")

  let result = schema_to_moonbit_struct_full(s)

  @debug.assert_eq(result.contains("String(s) => s"), true)
  @debug.assert_eq(result.contains("Number(v, ..) => v.to_int()"), true)
  @debug.assert_eq(result.contains("True => true"), true)
  @debug.assert_eq(result.contains("Some(Null) | None => None"), true)
  @debug.assert_eq(
    result.contains("Result[FullStruct, Array[ValidationError]]"),
    true,
  )
}
