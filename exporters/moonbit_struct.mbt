///|
/// Convert a moon_zod schema into MoonBit type definitions.
///
/// Every `ObjectType` in the schema tree is emitted as a standalone `pub struct`.
/// Schema names are treated only as type-name hints; anonymous nested objects are
/// named from their owner and field path.
pub fn schema_to_moonbit_struct(schema : @core.Schema) -> String {
  let root_name = schema_type_name(schema, "Root")
  let defs : Array[StructDef] = []
  collect_type_defs(schema, root_name, defs)
  render_defs(defs, include_to_schema=false)
}

///|
/// Convert a moon_zod schema into MoonBit type definitions plus static
/// `Type::to_schema() -> @moon_zod.Schema` functions for each generated type.
pub fn schema_to_moonbit_struct_full(schema : @core.Schema) -> String {
  let root_name = schema_type_name(schema, "Root")
  let defs : Array[StructDef] = []
  collect_type_defs(schema, root_name, defs)
  render_defs(defs, include_to_schema=true)
}

///|
priv enum StructDef {
  StructDef(String, @core.Schema)
  EnumDef(String, Array[String])
}

///|
fn collect_type_defs(
  schema : @core.Schema,
  type_hint : String,
  defs : Array[StructDef],
) -> Unit {
  match schema.schema_type {
    ObjectType(spec, _) => {
      let type_name = schema_type_name(schema, type_hint)
      for key, field_schema in spec {
        collect_field_defs(field_schema, child_type_name(type_name, key), defs)
      }
      push_struct_def(defs, type_name, schema)
    }
    EnumType(values) =>
      push_enum_def(defs, schema_type_name(schema, type_hint), values)
    OptionalType(inner) | DefaultType(inner, _) | TransformType(inner, _) =>
      collect_type_defs(inner, type_hint, defs)
    PreprocessType(_, inner) => collect_type_defs(inner, type_hint, defs)
    ArrayType(elem) => collect_type_defs(elem, type_hint + "Item", defs)
    UnionType(schemas) | IntersectionType(schemas) =>
      for item in schemas {
        collect_type_defs(item, type_hint, defs)
      }
    LazyType(f) => collect_type_defs(f(), type_hint, defs)
    DiscriminatedUnionType(_, options) =>
      for _key, option in options {
        collect_type_defs(option, type_hint, defs)
      }
    PipeType(input, _, output) => {
      collect_type_defs(input, type_hint, defs)
      collect_type_defs(output, type_hint, defs)
    }
    _ => ()
  }
}

///|
fn collect_field_defs(
  schema : @core.Schema,
  type_hint : String,
  defs : Array[StructDef],
) -> Unit {
  match schema.schema_type {
    OptionalType(inner) | DefaultType(inner, _) | TransformType(inner, _) =>
      collect_field_defs(inner, type_hint, defs)
    PreprocessType(_, inner) => collect_field_defs(inner, type_hint, defs)
    ArrayType(elem) => collect_field_defs(elem, type_hint + "Item", defs)
    UnionType(schemas) | IntersectionType(schemas) =>
      for item in schemas {
        collect_field_defs(item, type_hint, defs)
      }
    LazyType(f) => collect_field_defs(f(), type_hint, defs)
    DiscriminatedUnionType(_, options) =>
      for _key, option in options {
        collect_field_defs(option, type_hint, defs)
      }
    PipeType(input, _, output) => {
      collect_field_defs(input, type_hint, defs)
      collect_field_defs(output, type_hint, defs)
    }
    ObjectType(_, _) | EnumType(_) => collect_type_defs(schema, type_hint, defs)
    _ => ()
  }
}

///|
fn push_struct_def(
  defs : Array[StructDef],
  type_name : String,
  schema : @core.Schema,
) -> Unit {
  if !def_exists(defs, type_name) {
    defs.push(StructDef(type_name, schema))
  }
}

///|
fn push_enum_def(
  defs : Array[StructDef],
  type_name : String,
  values : Array[String],
) -> Unit {
  if !def_exists(defs, type_name) {
    defs.push(EnumDef(type_name, values))
  }
}

///|
fn def_exists(defs : Array[StructDef], type_name : String) -> Bool {
  for def in defs {
    match def {
      StructDef(name, _) | EnumDef(name, _) =>
        if name == type_name {
          return true
        }
    }
  }
  false
}

///|
fn render_defs(defs : Array[StructDef], include_to_schema~ : Bool) -> String {
  if defs.is_empty() {
    return "// TODO: schema does not contain any object or enum definitions"
  }
  let parts : Array[String] = []
  for def in defs {
    match def {
      StructDef(type_name, schema) => {
        parts.push(render_struct_def(type_name, schema))
        if include_to_schema {
          parts.push(render_to_schema_fn(type_name, schema))
        }
      }
      EnumDef(type_name, values) => {
        parts.push(render_enum_def(type_name, values))
        if include_to_schema {
          parts.push(render_enum_to_schema_fn(type_name, values))
        }
      }
    }
  }
  parts.join("\n\n")
}

///|
fn render_struct_def(type_name : String, schema : @core.Schema) -> String {
  match schema.schema_type {
    ObjectType(spec, _) => {
      let escaped_type = @core.escape_type_name(type_name)
      if spec.is_empty() {
        return "pub struct " + escaped_type + " {} derive(ToJson, FromJson)"
      }
      let mut result = "pub struct " + escaped_type + " {\n"
      for key, field_schema in spec {
        let field_name = @core.escape_variable_name(key)
        let field_type = field_to_moonbit_type(
          field_schema,
          child_type_name(escaped_type, key),
        )
        let opt_mark = if is_optional_field(field_schema) { "?" } else { "" }
        let comment = @core.constraint_comment(field_schema)
        let line = "  " + field_name + " : " + field_type + opt_mark
        if comment.is_empty() {
          result = result + line + "\n"
        } else {
          result = result + line + "  // " + comment + "\n"
        }
      }
      result + "} derive(ToJson, FromJson)"
    }
    _ => "// TODO: " + type_name + " is not an object schema"
  }
}

///|
fn render_enum_def(type_name : String, values : Array[String]) -> String {
  let escaped_type = @core.escape_type_name(type_name)
  let mut result = "pub enum " + escaped_type + " {\n"
  for value in values {
    result = result + "  " + moonbit_variant_name(value) + "\n"
  }
  result + "} derive(ToJson, FromJson)"
}

///|
fn render_to_schema_fn(type_name : String, schema : @core.Schema) -> String {
  let escaped_type = @core.escape_type_name(type_name)
  let code = schema_to_moon_zod_code(schema.name(escaped_type))
  let var_name = @core.escape_variable_name(escaped_type)
  "pub fn " +
  escaped_type +
  "::to_schema() -> @moon_zod.Schema {\n" +
  "  " +
  code +
  "\n" +
  "  " +
  var_name +
  "\n" +
  "}"
}

///|
fn render_enum_to_schema_fn(
  type_name : String,
  values : Array[String],
) -> String {
  let escaped_type = @core.escape_type_name(type_name)
  let var_name = @core.escape_variable_name(escaped_type)
  let parts = values.map(fn(value) {
    "\"" + @core.escape_mbt_string(value) + "\""
  })
  "pub fn " +
  escaped_type +
  "::to_schema() -> @moon_zod.Schema {\n" +
  "  let " +
  var_name +
  " = @moon_zod.enum_values([" +
  parts.join(", ") +
  "]).name(\"" +
  @core.escape_mbt_string(escaped_type) +
  "\")\n" +
  "  " +
  var_name +
  "\n" +
  "}"
}

///|
fn field_to_moonbit_type(schema : @core.Schema, type_hint : String) -> String {
  match schema.schema_type {
    OptionalType(inner) | DefaultType(inner, _) =>
      field_to_moonbit_type(inner, type_hint)
    TransformType(inner, _) => field_to_moonbit_type(inner, type_hint)
    PreprocessType(_, inner) => field_to_moonbit_type(inner, type_hint)
    StringType => "String"
    NumberType => if has_int_rule(schema) { "Int64" } else { "Double" }
    BooleanType => "Bool"
    NullType => "Unit"
    AnyType | UnknownType => "Json"
    ObjectType(_, _) => schema_type_name(schema, type_hint)
    ArrayType(elem) =>
      "Array[" + field_to_moonbit_type(elem, type_hint + "Item") + "]"
    TupleType(_) => "Json // TODO: tuple type"
    EnumType(_) => schema_type_name(schema, type_hint)
    UnionType(schemas) => union_to_moonbit_type(schemas, type_hint)
    IntersectionType(schemas) =>
      intersection_to_moonbit_type(schemas, type_hint)
    LiteralType(value) => literal_to_moonbit_type(value)
    LazyType(f) => field_to_moonbit_type(f(), type_hint)
    DiscriminatedUnionType(_, options) => {
      let schemas : Array[@core.Schema] = []
      for _key, option in options {
        schemas.push(option)
      }
      union_to_moonbit_type(schemas, type_hint)
    }
    PipeType(_, _, output) => field_to_moonbit_type(output, type_hint)
  }
}

///|
fn union_to_moonbit_type(
  schemas : Array[@core.Schema],
  type_hint : String,
) -> String {
  if schemas.length() == 2 {
    let left = schemas[0]
    let right = schemas[1]
    if is_null_schema(left) {
      return field_to_moonbit_type(right, type_hint)
    }
    if is_null_schema(right) {
      return field_to_moonbit_type(left, type_hint)
    }
  }
  "Json // TODO: union type"
}

///|
fn intersection_to_moonbit_type(
  schemas : Array[@core.Schema],
  type_hint : String,
) -> String {
  if schemas.length() == 1 {
    return field_to_moonbit_type(schemas[0], type_hint)
  }
  "Json // TODO: intersection type"
}

///|
fn is_optional_field(schema : @core.Schema) -> Bool {
  match schema.schema_type {
    OptionalType(_) | DefaultType(_, _) => true
    UnionType(schemas) => schemas.any(fn(item) { is_null_schema(item) })
    _ => false
  }
}

///|
fn is_null_schema(schema : @core.Schema) -> Bool {
  match schema.schema_type {
    NullType => true
    _ => false
  }
}

///|
fn schema_type_name(schema : @core.Schema, fallback : String) -> String {
  if schema.name.is_empty() {
    @core.escape_type_name(fallback)
  } else {
    @core.escape_type_name(schema.name)
  }
}

///|
fn child_type_name(parent_type : String, field_name : String) -> String {
  @core.escape_type_name(parent_type + pascal_name(field_name))
}

///|
fn has_int_rule(schema : @core.Schema) -> Bool {
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
fn literal_to_moonbit_type(json : Json) -> String {
  match json {
    String(_) => "String"
    Number(_) => "Double"
    True | False => "Bool"
    Null => "Unit"
    Array(_) => "Array[Json]"
    Object(_) => "Json"
  }
}

///|
fn moonbit_variant_name(value : String) -> String {
  pascal_name(value)
}

///|
fn pascal_name(value : String) -> String {
  let chars = value.to_array()
  let mut result = ""
  let mut capitalize_next = true
  for char in chars {
    if (char >= 'a' && char <= 'z') ||
      (char >= 'A' && char <= 'Z') ||
      (char >= '0' && char <= '9') {
      if capitalize_next {
        result = result + char_to_upper_string(char)
        capitalize_next = false
      } else {
        result = result + char.to_string()
      }
    } else {
      capitalize_next = true
    }
  }
  if result.is_empty() {
    "Variant"
  } else if result[0] >= '0' && result[0] <= '9' {
    "V" + result
  } else {
    result
  }
}

///|
fn char_to_upper_string(char : Char) -> String {
  if char >= 'a' && char <= 'z' {
    match (char.to_int() - 32).to_char() {
      Some(upper) => upper.to_string()
      None => char.to_string()
    }
  } else {
    char.to_string()
  }
}
