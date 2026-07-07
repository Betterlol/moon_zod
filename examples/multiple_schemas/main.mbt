///|
fn main {
  let args = @env.args()
  let mut command = ""
  if args.length() < 2 {
    println("Usage: moon run examples/multiple_schemas -- [json|ts|moonbit]")
    println("Default command is 'ts'")
    command = "ts"
  } else {
    command = args[1]
  }
  match command {
    "json" => show_json()
    "ts" => show_ts()
    "moonbit" => show_moonbit()
    "moon_zod" => show_moon_zod()
    _ => {
      println("ERR")
      println("1")
      println("Unknown command: \{command}")
      println("Usage: moon run examples/multiple_schemas -- [json|ts|moonbit]")
      return
    }
  }
}

///|
/// to show 3 different ways to generate json schema
fn show_json() -> Unit {
  let json_schema = show_json_schema()
  let json_schema_named = show_json_schema_named()
  let json_schema_named_selected = show_json_schema_named_selected()
  println("JSON Schema:\n\{json_schema.stringify(indent=2)}\n")
  println("\n======================\n")
  println("JSON Schema with Names:\n\{json_schema_named.stringify(indent=2)}\n")
  println("\n======================\n")
  println(
    "JSON Schema with Names (Selected):\n\{json_schema_named_selected.stringify(indent=2)}\n",
  )
  println("\n======================\n")
}

///|
/// to show 3 different ways to generate TypeScript interface
fn show_ts() -> Unit {
  let ts_interface = show_ts_interface()
  let ts_interface_named = show_ts_interface_named()
  let ts_interface_named_selected = show_ts_interface_named_selected()
  println("TypeScript Interface:\n\{ts_interface}\n")
  println("\n======================\n")
  println("TypeScript Interface with Names:\n\{ts_interface_named}\n")
  println("\n======================\n")
  println(
    "TypeScript Interface with Names (Selected):\n\{ts_interface_named_selected}\n",
  )
  println("\n======================\n")
}

///|
/// to show MoonBit struct generation with and without schema functions
fn show_moonbit() -> Unit {
  let moonbit_struct = show_moonbit_struct()
  let moonbit_struct_full = show_moonbit_struct_full()
  println("Moonbit Struct:\n\{moonbit_struct}\n")
  println("\n======================\n")
  println("Moonbit Struct Full:\n\{moonbit_struct_full}\n")
  println("\n======================\n")
}

///|
/// to show MoonZod code generation with and without schema functions
fn show_moon_zod() -> Unit {
  let moon_zod_code = show_moon_zod_code()
  let moon_zod_code_named = show_moon_zod_code_named()
  println("MoonZod Code:\n\{moon_zod_code}\n")
  println("\n======================\n")
  println("MoonZod Code Named:\n\{moon_zod_code_named}\n")
  println("\n======================\n")
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
fn show_ts_interface_named_selected() -> String {
  let order_schema = order_schema()
  @moon_zod.schema_to_prompt_named(
    order_schema,
    include_names=Some([
      "Order", "OrderStatus", "User", "Product", "HomeAddress", "OfficeAddress",
    ]),
  )
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

///|
fn show_json_schema_named_selected() -> Json {
  let order_schema = order_schema()
  @moon_zod.to_json_schema_named(
    order_schema,
    include_names=Some([
      "Order", "OrderStatus", "User", "Product", "HomeAddress", "OfficeAddress",
    ]),
  )
}

///|
fn show_moonbit_struct() -> String {
  let order_schema = order_schema()
  @moon_zod.schema_to_moonbit_struct(order_schema)
}

///|
fn show_moonbit_struct_full() -> String {
  let order_schema = order_schema()
  @moon_zod.schema_to_moonbit_struct_full(order_schema)
}

///|
fn show_moon_zod_code() -> String {
  let order_schema = order_schema()
  @moon_zod.schema_to_moon_zod_code(order_schema)
}

///|
fn show_moon_zod_code_named() -> String {
  let order_schema = order_schema()
  @moon_zod.schema_to_moon_zod_code_named(order_schema)
}
