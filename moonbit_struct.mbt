///|
/// Convert a moon_zod Schema into a MoonBit struct definition.
///
/// The schema must have a name (set via `.name("MyName")`).
/// Only `ObjectType` and `EnumType` produce struct/enum definitions;
/// other types produce a TODO comment.
///
/// # Example
/// ```mbt nocheck
/// let s = object({ "name": string(), "age": number().int() }).name("User")
///
/// let code = schema_to_moonbit_struct(s)
/// // pub struct User {
/// //   name : String
/// //   age : Int64
/// // }
/// ```
pub fn schema_to_moonbit_struct(schema : Schema) -> String {
  if schema.name.is_empty() {
    return "// schema_to_moonbit_struct: schema has no name\n" +
      "// Use .name(\"MyName\") to name the schema"
  }
  match schema.schema_type {
    ObjectType(spec, _) => object_to_struct_definition(spec, 0, schema.name)
    EnumType(values) => enum_to_moonbit(values, schema.name)
    _ =>
      "// TODO: " +
      schema.name +
      " is not an ObjectType or EnumType — cannot produce a struct definition"
  }
}

///|
/// Collect all named schemas from the input schema tree and generate
/// separate MoonBit struct/enum definitions, topologically sorted.
///
/// Dependencies appear before dependents so the generated code
/// compiles without forward declarations.
///
/// # Example
/// ```mbt nocheck
/// let address = object({ "city": string() }).name("Address")
///
/// let person = object({ "addr": address }).name("Person")
///
/// let code = schema_to_moonbit_struct_named(person)
/// // pub struct Address {
/// //   city : String
/// // }
/// //
/// // pub struct Person {
/// //   addr : Address
/// // }
/// ```
pub fn schema_to_moonbit_struct_named(schema : Schema) -> String {
  let named_schemas = collect_named_schemas(schema)
  generate_struct_definitions(named_schemas)
}

///|
/// Render a Schema type to a MoonBit type expression string.
/// Non-named ObjectTypes and complex UnionTypes may produce
/// placeholder comments.
fn type_to_moonbit(schema : Schema, indent : Int) -> String {
  match schema.schema_type {
    StringType => "String"
    NumberType => if has_int_rule(schema) { "Int64" } else { "Double" }
    BooleanType => "Bool"
    NullType => "Unit"
    OptionalType(inner) => type_to_moonbit(inner, indent) + "?"
    DefaultType(inner, _) => type_to_moonbit(inner, indent)
    TransformType(inner, _) => type_to_moonbit(inner, indent)
    EnumType(_values) => "String /* TODO: define enum */"
    ArrayType(elem) => "Array[" + type_to_moonbit(elem, indent) + "]"
    UnionType(schemas) => union_to_moonbit(schemas, indent)
    IntersectionType(schemas) => intersection_to_moonbit(schemas, indent)
    ObjectType(_spec, _) =>
      if !schema.name.is_empty() {
        schema.name
      } else {
        "Json /* TODO: define nested struct */"
      }
  }
}

///|
/// Named-aware version of type_to_moonbit.
/// If a schema has a name that appears in `named_schemas`,
/// renders just the name (a type reference) instead of inlining.
fn type_to_inline_moonbit(
  schema : Schema,
  indent : Int,
  named_schemas : Array[Schema],
) -> String {
  if !schema.name.is_empty() {
    for ns in named_schemas {
      if ns.name == schema.name {
        return schema.name
      }
    }
  }

  match schema.schema_type {
    StringType => "String"
    NumberType => if has_int_rule(schema) { "Int64" } else { "Double" }
    BooleanType => "Bool"
    NullType => "Unit"
    OptionalType(inner) =>
      type_to_inline_moonbit(inner, indent, named_schemas) + "?"
    DefaultType(inner, _) =>
      type_to_inline_moonbit(inner, indent, named_schemas)
    TransformType(inner, _) =>
      type_to_inline_moonbit(inner, indent, named_schemas)
    EnumType(_values) => "String /* TODO: define enum */"
    ArrayType(elem) =>
      "Array[" + type_to_inline_moonbit(elem, indent, named_schemas) + "]"
    UnionType(schemas) =>
      union_to_inline_moonbit(schemas, indent, named_schemas)
    IntersectionType(schemas) =>
      intersection_to_inline_moonbit(schemas, indent, named_schemas)
    ObjectType(spec, _) => object_to_inline_moonbit(spec, indent, named_schemas)
  }
}

///|
/// Generate a struct definition for an object schema.
fn object_to_struct_definition(
  spec : Map[String, Schema],
  indent : Int,
  struct_name : String,
) -> String {
  if spec.length() == 0 {
    return "pub struct " + struct_name + " {}"
  }

  let mut result = "pub struct " + struct_name + " {\n"
  let inner_indent = indent + 1

  for key, val_schema in spec {
    let key_is_optional = is_optional_schema(val_schema)
    let inner = if key_is_optional {
      match val_schema.schema_type {
        OptionalType(s) => s
        DefaultType(s, _) => s
        _ => val_schema
      }
    } else {
      val_schema
    }

    let field_type = type_to_moonbit(inner, inner_indent)
    let opt_mark = if key_is_optional { "?" } else { "" }
    let comment = struct_comment(val_schema)

    let line = indent_str(inner_indent) + key + opt_mark + " : " + field_type

    if comment.is_empty() {
      result = result + line + "\n"
    } else {
      result = result + line + "  // " + comment + "\n"
    }
  }

  result = result + indent_str(indent) + "}"
  result
}

///|
/// Inline object renderer for the named-aware pipeline.
fn object_to_inline_moonbit(
  spec : Map[String, Schema],
  indent : Int,
  named_schemas : Array[Schema],
) -> String {
  if spec.length() == 0 {
    return "{} /* TODO: empty object */"
  }

  let mut result = "{\n"
  let inner_indent = indent + 1

  for key, val_schema in spec {
    let key_is_optional = is_optional_schema(val_schema)
    let inner = if key_is_optional {
      match val_schema.schema_type {
        OptionalType(s) => s
        DefaultType(s, _) => s
        _ => val_schema
      }
    } else {
      val_schema
    }

    let field_type = type_to_inline_moonbit(inner, inner_indent, named_schemas)
    let opt_mark = if key_is_optional { "?" } else { "" }
    let comment = struct_comment(val_schema)

    let line = indent_str(inner_indent) + key + opt_mark + " : " + field_type

    if comment.is_empty() {
      result = result + line + "\n"
    } else {
      result = result + line + "  // " + comment + "\n"
    }
  }

  result = result + indent_str(indent) + "}"
  result
}

///|
/// Render an enum schema as a MoonBit enum definition.
fn enum_to_moonbit(values : Array[String], enum_name : String) -> String {
  let mut result = "pub enum " + enum_name + " {\n"
  for v in values {
    let variant = moonbit_type_name(v)
    result = result + indent_str(1) + variant + "\n"
  }
  result = result + "}"
  result
}

///|
/// Render a union type to a MoonBit type comment.
/// Simple unions (e.g. Boolean | Null) are rendered as nullable types;
/// complex unions get a TODO comment.
fn union_to_moonbit(schemas : Array[Schema], indent : Int) -> String {
  if schemas.length() == 2 {
    let (s0, s1) = (schemas[0], schemas[1])
    let null_at = if is_null_type(s0) {
      0
    } else if is_null_type(s1) {
      1
    } else {
      -1
    }
    if null_at >= 0 {
      let other = if null_at == 0 { s1 } else { s0 }
      let base = type_to_moonbit(other, indent)
      return base + "?"
    }
  }

  "Json /* TODO: union type — requires manual definition */"
}

///|
/// Named-aware union renderer.
fn union_to_inline_moonbit(
  schemas : Array[Schema],
  indent : Int,
  named_schemas : Array[Schema],
) -> String {
  if schemas.length() == 2 {
    let (s0, s1) = (schemas[0], schemas[1])
    let null_at = if is_null_type(s0) {
      0
    } else if is_null_type(s1) {
      1
    } else {
      -1
    }
    if null_at >= 0 {
      let other = if null_at == 0 { s1 } else { s0 }
      let base = type_to_inline_moonbit(other, indent, named_schemas)
      return base + "?"
    }
  }

  "Json /* TODO: union type — requires manual definition */"
}

///|
/// Render an intersection type.
/// If all members are ObjectTypes, merge their fields into one struct body.
/// Otherwise, emit a TODO comment.
fn intersection_to_moonbit(schemas : Array[Schema], indent : Int) -> String {
  let all_objects = schemas.all(fn(s) {
    match s.schema_type {
      ObjectType(_, _) => true
      _ => false
    }
  })
  if all_objects {
    let merged : Map[String, Schema] = {}
    for s in schemas {
      match s.schema_type {
        ObjectType(fields, _) =>
          for key, val in fields {
            merged.set(key, val)
          }
        _ => ()
      }
    }
    object_to_struct_definition(merged, indent, "IntersectedStruct")
  } else {
    "Json /* TODO: intersection type — requires manual definition */"
  }
}

///|
/// Named-aware intersection renderer.
fn intersection_to_inline_moonbit(
  schemas : Array[Schema],
  indent : Int,
  named_schemas : Array[Schema],
) -> String {
  let all_objects = schemas.all(fn(s) {
    match s.schema_type {
      ObjectType(_, _) => true
      _ => false
    }
  })
  if all_objects {
    let merged : Map[String, Schema] = {}
    for s in schemas {
      match s.schema_type {
        ObjectType(fields, _) =>
          for key, val in fields {
            merged.set(key, val)
          }
        _ => ()
      }
    }
    object_to_inline_moonbit(merged, indent, named_schemas)
  } else {
    "Json /* TODO: intersection type — requires manual definition */"
  }
}

///|
/// Generate struct definitions for all named schemas, topologically sorted.
fn generate_struct_definitions(named_schemas : Array[Schema]) -> String {
  if named_schemas.is_empty() {
    return "// No named schemas found"
  }

  let sorted_schemas = topological_sort_schemas(named_schemas)

  let mut result = ""
  for schema in sorted_schemas {
    if !result.is_empty() {
      result = result + "\n\n"
    }

    let def = schema_to_struct_definition_with_names(schema, sorted_schemas)
    if !def.is_empty() {
      result = result + def
    }
  }

  result
}

///|
/// Generate a single struct/enum definition for a named schema,
/// using the named schema list for type references.
fn schema_to_struct_definition_with_names(
  schema : Schema,
  named_schemas : Array[Schema],
) -> String {
  if schema.name.is_empty() {
    return ""
  }

  match schema.schema_type {
    ObjectType(spec, _) =>
      struct_definition_with_names(spec, schema.name, named_schemas)
    EnumType(values) => enum_to_moonbit(values, schema.name)
    _ => ""
  }
}

///|
/// Render an object spec as a struct definition, using named references.
fn struct_definition_with_names(
  spec : Map[String, Schema],
  struct_name : String,
  named_schemas : Array[Schema],
) -> String {
  if spec.length() == 0 {
    return "pub struct " + struct_name + " {}"
  }

  let mut result = "pub struct " + struct_name + " {\n"
  let inner_indent = 1

  for key, val_schema in spec {
    let key_is_optional = is_optional_schema(val_schema)
    let inner = if key_is_optional {
      match val_schema.schema_type {
        OptionalType(s) => s
        DefaultType(s, _) => s
        _ => val_schema
      }
    } else {
      val_schema
    }

    let field_type = type_to_inline_moonbit(inner, inner_indent, named_schemas)
    let opt_mark = if key_is_optional { "?" } else { "" }
    let comment = struct_comment(val_schema)

    let line = indent_str(inner_indent) + key + opt_mark + " : " + field_type

    if comment.is_empty() {
      result = result + line + "\n"
    } else {
      result = result + line + "  // " + comment + "\n"
    }
  }

  result = result + "}"
  result
}

///|
/// Build a constraint doc comment for a schema.
/// Reuses constraint comment functions from prompt.mbt.
fn struct_comment(schema : Schema) -> String {
  let unwrapped = unwrap_schema(schema)

  match unwrapped.schema_type {
    StringType => string_constraint_comment(unwrapped.rules)
    NumberType => number_constraint_comment(unwrapped.rules)
    ArrayType(_) => array_constraint_comment(unwrapped.rules)
    _ => fallback_constraint_comment(unwrapped.rules)
  }
}

///|
/// Check if a number schema has an int() rule by scanning annotations.
fn has_int_rule(schema : Schema) -> Bool {
  for rule in schema.rules {
    match rule.annotation {
      Object(m) =>
        match m.get("type") {
          Some(String(v)) if v == "integer" => return true
          _ => ()
        }
      _ => ()
    }
  }
  false
}

///|
/// Check if a schema is NullType.
fn is_null_type(schema : Schema) -> Bool {
  match schema.schema_type {
    NullType => true
    _ => false
  }
}

///|
/// Convert an arbitrary string to a valid MoonBit PascalCase identifier.
fn moonbit_type_name(s : String) -> String {
  let arr = s.to_array()
  let mut result = ""
  let mut capitalize_next = true
  for i = 0; i < arr.length(); i = i + 1 {
    let c = arr[i]
    if (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') {
      if capitalize_next {
        if c >= 'a' && c <= 'z' {
          result = result + chr_to_upper(c)
        } else {
          result = result + c.to_string()
        }
        capitalize_next = false
      } else {
        result = result + c.to_string()
      }
    } else if c == '_' || c == '-' || c == ' ' {
      capitalize_next = true
    }
  }

  if result.is_empty() {
    result = "Variant"
    return result
  }

  let first = result[0]
  if !((first >= 'a' && first <= 'z') || (first >= 'A' && first <= 'Z')) {
    result = "V" + result
  }

  result
}

///|
/// Convert a lowercase char to uppercase.
fn chr_to_upper(c : Char) -> String {
  let code = c.to_int()
  if code >= 97 && code <= 122 {
    let upper_char = (code - 32).to_char()
    match upper_char {
      Some(ch) => ch.to_string()
      None => c.to_string()
    }
  } else {
    c.to_string()
  }
}

// ─── Phase 29: from_json() code generation ───

///|
/// Generate a MoonBit struct definition plus a `from_json()` standalone
/// function that validates and extracts typed values from a Json value.
///
/// The schema must have a name (set via `.name("MyName")`) and must be
/// an ObjectType.
///
/// # Example
/// ```mbt nocheck
/// let s = object({ "name": string(), "age": number().int() }).name("User")
///
/// let code = schema_to_moonbit_struct_full(s)
/// // pub struct User { name : String; age : Int64 }
/// // pub fn user_from_json(json : Json) -> Result[User, Array[ValidationError]] { ... }
/// ```
pub fn schema_to_moonbit_struct_full(schema : Schema) -> String {
  if schema.name.is_empty() {
    return "// schema_to_moonbit_struct_full: schema has no name\n" +
      "// Use .name(\"MyName\") to name the schema"
  }
  match schema.schema_type {
    ObjectType(spec, _) => {
      let struct_def = object_to_struct_definition(spec, 0, schema.name)
      let from_json_fn = generate_from_json_fn(schema, schema.name, 0, [])
      struct_def + "\n\n" + from_json_fn
    }
    EnumType(values) =>
      enum_to_moonbit(values, schema.name) +
      "\n\n" +
      "// TODO: from_json for enum " +
      schema.name
    _ =>
      "// TODO: " +
      schema.name +
      " is not an ObjectType or EnumType — cannot produce a struct definition"
  }
}

///|
/// Collect all named schemas and generate struct definitions plus
/// `from_json()` functions for each, topologically sorted so that
/// dependencies appear before dependents.
pub fn schema_to_moonbit_struct_named_full(schema : Schema) -> String {
  let named_schemas = collect_named_schemas(schema)
  if named_schemas.is_empty() {
    return "// No named schemas found"
  }

  let sorted_schemas = topological_sort_schemas(named_schemas)

  let mut result = ""
  for s in sorted_schemas {
    if !result.is_empty() {
      result = result + "\n\n"
    }

    let block = schema_to_full_block(s, sorted_schemas)
    if !block.is_empty() {
      result = result + block
    }
  }

  result
}

///|
/// Generate struct + from_json block for one schema in named mode.
fn schema_to_full_block(
  schema : Schema,
  named_schemas : Array[Schema],
) -> String {
  if schema.name.is_empty() {
    return ""
  }

  match schema.schema_type {
    ObjectType(spec, _) => {
      let struct_def = struct_definition_with_names(
        spec,
        schema.name,
        named_schemas,
      )
      let from_json_fn = generate_from_json_fn(
        schema,
        schema.name,
        0,
        named_schemas,
      )
      struct_def + "\n\n" + from_json_fn
    }
    EnumType(values) =>
      enum_to_moonbit(values, schema.name) +
      "\n\n" +
      "// TODO: from_json for enum " +
      schema.name
    _ => ""
  }
}

///|
/// Generate a complete `fn struct_name_from_json(json) -> Result[Struct, ...]`
/// function that validates and extracts typed values.
fn generate_from_json_fn(
  schema : Schema,
  struct_name : String,
  _indent : Int,
  named_schemas : Array[Schema],
) -> String {
  let fn_name = struct_name_to_fn_prefix(struct_name)

  match schema.schema_type {
    ObjectType(spec, _) => {
      let mut result = "pub fn " +
        fn_name +
        "(json : Json) -> Result[" +
        struct_name +
        ", Array[ValidationError]] {\n"
      result = result + "  match json {\n" + "    Object(map) => {\n"

      // Generate field extraction for each field
      for key, val_schema in spec {
        let field_block = extract_field(
          key, val_schema, 4, struct_name, named_schemas,
        )
        result = result + field_block
      }

      // Generate struct literal with field names
      result = result + "      Ok({\n"
      for key, _ in spec {
        result = result + "        " + key + ":\n"
      }
      result = result +
        "      })\n" +
        "    }\n" +
        "    _ => Err([ValidationError::{ path: \"\", message: \"expected object\", got: json }])\n" +
        "  }\n" +
        "}"
      result
    }
    _ => "// TODO: from_json for " + struct_name
  }
}

///|
/// Generate the extraction code for a single struct field.
/// Returns a string containing the `let` binding and match expressions.
fn extract_field(
  key : String,
  schema : Schema,
  indent : Int,
  _parent_struct : String,
  named_schemas : Array[Schema],
) -> String {
  let key_escaped = escape_mbt_string(key)
  let key_is_optional = is_optional_schema(schema)
  let ind = indent_str(indent)

  if key_is_optional {
    let inner = match schema.schema_type {
      OptionalType(s) => s
      DefaultType(s, _) => s
      _ => schema
    }
    let inner_type_name = type_to_inline_moonbit(inner, indent, named_schemas)
    let extract_expr = extract_type_expr("v", inner, named_schemas)

    ind +
    "let " +
    key +
    " = match map.get(\"" +
    key_escaped +
    "\") {\n" +
    ind +
    "  Some(Null) | None => None\n" +
    ind +
    "  Some(v) => {\n" +
    ind +
    "    let result : " +
    inner_type_name +
    " = " +
    extract_expr +
    "\n" +
    ind +
    "    Some(result)\n" +
    ind +
    "  }\n" +
    ind +
    "}\n"
  } else {
    ind +
    "let " +
    key +
    " = match map.get(\"" +
    key_escaped +
    "\") {\n" +
    ind +
    "  Some(v) => " +
    extract_type_expr("v", schema, named_schemas) +
    "\n" +
    ind +
    "  None => return Err([ValidationError::{ path: \"" +
    key_escaped +
    "\", message: \"required\", got: Null }])\n" +
    ind +
    "}\n"
  }
}

///|
/// Generate an extraction expression for a given schema type.
/// Returns something like: `match v { String(s) => s; _ => return Err(...) }`
fn extract_type_expr(
  json_var : String,
  schema : Schema,
  named_schemas : Array[Schema],
) -> String {
  match schema.schema_type {
    StringType =>
      "match " +
      json_var +
      " { String(s) => s; _ => return Err([ValidationError::{ path: \"" +
      schema.name +
      "\", message: \"expected string\", got: " +
      json_var +
      " }]) }"
    NumberType =>
      if has_int_rule(schema) {
        "match " +
        json_var +
        " { Number(v, ..) => v.to_int(); _ => return Err([ValidationError::{ path: \"" +
        schema.name +
        "\", message: \"expected integer\", got: " +
        json_var +
        " }]) }"
      } else {
        "match " +
        json_var +
        " { Number(v, ..) => v; _ => return Err([ValidationError::{ path: \"" +
        schema.name +
        "\", message: \"expected number\", got: " +
        json_var +
        " }]) }"
      }
    BooleanType =>
      "match " +
      json_var +
      " { True => true; False => false; _ => return Err([ValidationError::{ path: \"" +
      schema.name +
      "\", message: \"expected boolean\", got: " +
      json_var +
      " }]) }"
    NullType =>
      "match " +
      json_var +
      " { Null => (); _ => return Err([ValidationError::{ path: \"" +
      schema.name +
      "\", message: \"expected null\", got: " +
      json_var +
      " }]) }"
    EnumType(values) => {
      let mut arms = ""
      let mut first = true
      for v in values {
        let variant = moonbit_type_name(v)
        if first {
          arms = "\"" + v + "\" => " + variant
          first = false
        } else {
          arms = arms + "; \"" + v + "\" => " + variant
        }
      }
      "match " +
      json_var +
      " { String(s) => match s { " +
      arms +
      "; _ => return Err([ValidationError::{ path: \"" +
      schema.name +
      "\", message: \"unexpected enum value\", got: " +
      json_var +
      " }]) }; _ => return Err([ValidationError::{ path: \"" +
      schema.name +
      "\", message: \"expected string\", got: " +
      json_var +
      " }]) }"
    }
    ArrayType(elem) => {
      let elem_type = type_to_inline_moonbit(elem, 0, named_schemas)
      "match " +
      json_var +
      " { Array(elems) => { let mut items : Array[" +
      elem_type +
      "] = []; for item in elems { items.push(" +
      extract_type_expr("item", elem, named_schemas) +
      ") }; items }; _ => return Err([ValidationError::{ path: \"" +
      schema.name +
      "\", message: \"expected array\", got: " +
      json_var +
      " }]) }"
    }
    OptionalType(inner) => {
      let inner_type = type_to_inline_moonbit(inner, 0, named_schemas)
      "match " +
      json_var +
      " { Null => None; v => { let result : " +
      inner_type +
      " = " +
      extract_type_expr("v", inner, named_schemas) +
      "; Some(result) } }"
    }
    DefaultType(inner, _) =>
      // Transparent: extract as normal type (no Option wrapping)
      extract_type_expr(json_var, inner, named_schemas)
    TransformType(inner, _) =>
      // Transparent
      extract_type_expr(json_var, inner, named_schemas)
    ObjectType(_, _) => {
      // Check if this schema has a name and is in named_schemas
      let is_named = !schema.name.is_empty() &&
        schema_in_list(schema.name, named_schemas)
      if is_named {
        let fn_prefix = struct_name_to_fn_prefix(schema.name)
        "match " +
        json_var +
        " { Object(_) => { match " +
        fn_prefix +
        "(" +
        json_var +
        ") { Ok(val) => val; Err(e) => return Err(e) } }; _ => return Err([ValidationError::{ path: \"" +
        schema.name +
        "\", message: \"expected object\", got: " +
        json_var +
        " }]) }"
      } else {
        "match " +
        json_var +
        " { Object(_) => " +
        json_var +
        "; _ => return Err([ValidationError::{ path: \"" +
        schema.name +
        "\", message: \"expected object\", got: " +
        json_var +
        " }]) }"
      }
    }
    UnionType(schemas) =>
      if schemas.length() == 2 {
        let (s0, s1) = (schemas[0], schemas[1])
        let null_at = if is_null_type(s0) {
          0
        } else if is_null_type(s1) {
          1
        } else {
          -1
        }
        if null_at >= 0 {
          let inner = if null_at == 0 { s1 } else { s0 }
          let inner_type = type_to_inline_moonbit(inner, 0, named_schemas)
          "match " +
          json_var +
          " { Null => None; v => { let result : " +
          inner_type +
          " = " +
          extract_type_expr("v", inner, named_schemas) +
          "; Some(result) } }"
        } else {
          "json_var /* TODO: union type extraction */"
        }
      } else {
        "json_var /* TODO: union type extraction */"
      }
    IntersectionType(schemas) => {
      let all_objects = schemas.all(fn(s) {
        match s.schema_type {
          ObjectType(_, _) => true
          _ => false
        }
      })
      if all_objects {
        // Try to delegate to the first named object
        let mut found_fn = false
        let mut fn_call = "json_var /* TODO: intersection extraction */"
        for s in schemas {
          if !s.name.is_empty() && schema_in_list(s.name, named_schemas) {
            let fn_prefix = struct_name_to_fn_prefix(s.name)
            fn_call = "match " +
              json_var +
              " { Object(_) => { match " +
              fn_prefix +
              "(" +
              json_var +
              ") { Ok(val) => val; Err(e) => return Err(e) } }; _ => return Err([ValidationError::{ path: \"\", message: \"expected object\", got: " +
              json_var +
              " }]) }"
            found_fn = true
            break
          }
        }
        if found_fn {
          fn_call
        } else {
          "json_var /* TODO: intersection of unnamed objects */"
        }
      } else {
        "json_var /* TODO: intersection type extraction */"
      }
    }
  }
}

///|
/// Check if a schema name exists in a list of named schemas.
fn schema_in_list(name : String, named_schemas : Array[Schema]) -> Bool {
  for s in named_schemas {
    if s.name == name {
      return true
    }
  }
  false
}

///|
/// Convert a PascalCase struct name to a snake_case function prefix.
/// "User" → "user"
/// "ItemList" → "item_list"
/// "HTTPServer" → "http_server"
fn struct_name_to_fn_prefix(name : String) -> String {
  let arr = name.to_array()
  let mut result = ""
  for i = 0; i < arr.length(); i = i + 1 {
    let c = arr[i]
    if c >= 'A' && c <= 'Z' {
      if i > 0 {
        result = result + "_"
      }
      // Convert to lowercase
      let code = c.to_int() + 32
      let lower_char = code.to_char()
      match lower_char {
        Some(ch) => result = result + ch.to_string()
        None => result = result + c.to_string()
      }
    } else {
      result = result + c.to_string()
    }
  }
  result + "_from_json"
}
