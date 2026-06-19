///|
fn main {
  let ts_interface = show_ts_interface()
  let ts_interface_named = show_ts_interface_named()
  println("TypeScript Interface:\n\{ts_interface}")
  println("TypeScript Interface with Names:\n\{ts_interface_named}")
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
