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
