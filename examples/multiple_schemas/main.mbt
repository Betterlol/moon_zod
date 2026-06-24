///|
fn main {
  let ts_interface = show_ts_interface()
  let ts_interface_named = show_ts_interface_named()
  let json_schema = show_json_schema()
  let json_schema_named = show_json_schema_named()
  println("TypeScript Interface:\n\{ts_interface}")
  println("TypeScript Interface with Names:\n\{ts_interface_named}")
  println("JSON Schema:\n\{json_schema.stringify(indent=2)}")
  println("JSON Schema with Names:\n\{json_schema_named.stringify(indent=2)}")
}

///|
fn show_ts_interface() -> String {
  let order_schema = order_schema()
  @moon_zod.schema_to_prompt(order_schema)
}

///|
fn show_ts_interface_named() -> String {
  let order_schema = order_schema()
  @moon_zod.schema_to_prompt_named(order_schema)
}

///|
fn show_json_schema() -> Json {
  let order_schema = order_schema()
  @moon_zod.to_json_schema(order_schema)
}

///|
fn show_json_schema_named() -> Json {
  let order_schema = order_schema()
  @moon_zod.to_json_schema_named(order_schema)
}
