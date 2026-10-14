///|
/// **@core.Schema → moon_zod source code**
///
/// Convert representable schemas into moon_zod method chain source code.
/// Custom closures and opaque rules fail explicitly; use the checked API for errors.
/// Supports inline expansion and named schema references.

///|
/// Generate best-effort moon_zod source code from a @core.Schema @core.object (inline expansion).
///
/// # Example
/// ```mbt nocheck
/// let schema = @moon_zod.string().min(3).describe("username")
///
/// let code = schema_to_moon_zod_code(schema)
/// // "@moon_zod.string().min(3).describe(\"username\")"
/// ```
/// If root schema has no name, it is assigned the name "Root".
pub fn schema_to_moon_zod_code(schema : @core.Schema) -> String {
  match source_export_error(schema) {
    Some(message) => abort(message)
    None => ()
  }
  if contains_lazy(schema, Map([])) {
    return schema_to_moon_zod_code_named(schema)
  }
  let schema_name = if schema.name.is_empty() { "Root" } else { schema.name }
  let code = schema_to_moon_zod_code_inline(schema, None)
  let result = "let " +
    @core.escape_variable_name(schema_name) +
    " = " +
    code +
    ".name(\"" +
    @core.escape_mbt_string(schema_name) +
    "\")"
  result
}

///|
/// Generate best-effort inline code with optional named schema reference substitution.
///
/// If `include_names` is None, renders all schemas inline.
/// If `include_names` is Some(names), replaces references to named schemas with variable names.
///
/// For use with `schema_to_moon_zod_code_named()` which produces separate definitions.
pub fn schema_to_moon_zod_code_inline_with_refs(
  schema : @core.Schema,
  include_names : Array[String]?,
) -> String {
  match source_export_error(schema) {
    Some(message) => abort(message)
    None => ()
  }
  schema_to_moon_zod_code_inline(schema, include_names)
}

///|
/// Generate best-effort separate named schema definitions and return as newline-separated list.
///
/// # Example
/// ```
/// let named_list = schema_to_moon_zod_code_named(root_schema, None)
/// // Returns:
/// // "User: @moon_zod.object({ ... }).name(\"User\")\n
/// //  Profile: @moon_zod.object({ ... }).name(\"Profile\")"
/// ```
/// If root schema has no name, it is assigned the name "Root".
pub fn schema_to_moon_zod_code_named(
  schema : @core.Schema,
  include_names~ : Array[String]? = None,
) -> String {
  match source_export_error(schema) {
    Some(message) => abort(message)
    None => ()
  }
  let mut schema = schema
  if schema.name.is_empty() {
    schema = schema.name("Root")
  }
  let all_named = @core.collect_named_schemas(schema)
  let selected = @core.filter_named_schemas(all_named, include_names)
  let sorted = @core.topological_sort_schemas(selected)

  let defined_names = selected.map(fn(x) { x.name })
  let recursive_graph = contains_lazy(schema, Map([]))
  let mut result = ""
  for s in sorted {
    if !s.name.is_empty() {
      let code = schema_to_moon_zod_code_inline(
        s,
        Some(defined_names),
        inline_root=true,
      )
      if !result.is_empty() {
        result = result + "\n"
      }
      let line = if recursive_graph {
        "fn " +
        @core.escape_function_name(s.name) +
        "_schema() -> @moon_zod.Schema { " +
        code +
        ".name(\"" +
        @core.escape_mbt_string(s.name) +
        "\") }\nlet " +
        @core.escape_variable_name(s.name) +
        " = " +
        @core.escape_function_name(s.name) +
        "_schema()"
      } else {
        "let " +
        @core.escape_variable_name(s.name) +
        " = " +
        code +
        ".name(\"" +
        @core.escape_mbt_string(s.name) +
        "\")"
      }
      result = result + line
    }
  }
  result
}

///|
/// Internal: Generate code with optional named schema reference support.
fn schema_to_moon_zod_code_inline(
  schema : @core.Schema,
  include_names : Array[String]?,
  inline_root~ : Bool = false,
) -> String {
  let defined_names = match include_names {
    None => []
    Some(names) => names
  }

  // If this schema has a name and it's in the defined_names list, use reference
  if !inline_root &&
    !schema.name.is_empty() &&
    @core.value_in_array(schema.name, defined_names) {
    if schema.schema_type is LazyType(_) {
      return "@moon_zod.recursive(" +
        @core.escape_function_name(schema.name) +
        "_schema)"
    }
    return @core.escape_variable_name(schema.name)
  }

  let base = schema_type_to_code(schema.schema_type, defined_names, schema.name)
  let mut result = apply_rules_to_code(base, schema)

  // Apply description if present
  if !schema.brand.is_empty() {
    result = result +
      ".brand(\"" +
      @core.escape_mbt_string(schema.brand) +
      "\")"
  }
  if !schema.description.is_empty() {
    result = result +
      ".describe(\"" +
      @core.escape_mbt_string(schema.description) +
      "\")"
  }

  // Apply type-level error messages if present
  if !schema.required_error.is_empty() {
    result = result +
      ".required_error(\"" +
      @core.escape_mbt_string(schema.required_error) +
      "\")"
  }
  if !schema.invalid_type_error.is_empty() {
    result = result +
      ".invalid_type_error(\"" +
      @core.escape_mbt_string(schema.invalid_type_error) +
      "\")"
  }

  result
}

///|
/// Generate base type constructor code.
fn schema_type_to_code(
  schema_type : @core.SchemaType,
  defined_names : Array[String],
  wrapper_name : String,
) -> String {
  match schema_type {
    StringType => "@moon_zod.string()"
    NumberType => "@moon_zod.number()"
    BooleanType => "@moon_zod.boolean()"
    NullType => "@moon_zod.null()"
    AnyType => "@moon_zod.any()"
    UnknownType => "@moon_zod.unknown()"
    ObjectType(fields, mode) => {
      let base = if fields.length() == 0 {
        "@moon_zod.object({})"
      } else {
        let parts : Array[String] = []
        for key, field_schema in fields {
          let field_code = schema_to_moon_zod_code_inline(
            field_schema,
            Some(defined_names),
          )
          parts.push("\"" + @core.escape_mbt_string(key) + "\": " + field_code)
        }
        "@moon_zod.object({ " + join_with(parts, ", ") + " })"
      }

      // Apply @core.object mode if not default Strip
      match mode {
        Strip => base
        Passthrough => base + ".passthrough()"
        Strict => base + ".strict()"
      }
    }
    ArrayType(elem) => {
      let elem_code = schema_to_moon_zod_code_inline(elem, Some(defined_names))
      "@moon_zod.array(" + elem_code + ")"
    }
    TupleType(items) => {
      let parts : Array[String] = []
      for item in items {
        parts.push(schema_to_moon_zod_code_inline(item, Some(defined_names)))
      }
      "@moon_zod.tuple([" + join_with(parts, ", ") + "])"
    }
    NullableType(inner) =>
      schema_to_moon_zod_code_inline(
        if inner.name == wrapper_name {
          { ..inner, name: "", }
        } else {
          inner
        },
        Some(defined_names),
      ) +
      ".nullable()"
    PrefaultType(inner, value) =>
      schema_to_moon_zod_code_inline(
        if inner.name == wrapper_name {
          { ..inner, name: "", }
        } else {
          inner
        },
        Some(defined_names),
      ) +
      ".prefault(" +
      json_to_literal(value) +
      ")"
    OptionalType(inner) =>
      schema_to_moon_zod_code_inline(
        if inner.name == wrapper_name {
          { ..inner, name: "", }
        } else {
          inner
        },
        Some(defined_names),
      ) +
      ".optional()"
    DefaultType(inner, default_val) =>
      schema_to_moon_zod_code_inline(
        if inner.name == wrapper_name {
          { ..inner, name: "", }
        } else {
          inner
        },
        Some(defined_names),
      ) +
      ".default(" +
      json_to_literal(default_val) +
      ")"
    EnumType(values) => {
      let parts : Array[String] = []
      for v in values {
        parts.push("\"" + @core.escape_mbt_string(v) + "\"")
      }
      "@moon_zod.enum_values([" + join_with(parts, ", ") + "])"
    }
    UnionType(schemas) => {
      let parts : Array[String] = []
      for s in schemas {
        parts.push(schema_to_moon_zod_code_inline(s, Some(defined_names)))
      }
      "@moon_zod.union([" + join_with(parts, ", ") + "])"
    }
    IntersectionType(schemas) => {
      let parts : Array[String] = []
      for s in schemas {
        parts.push(schema_to_moon_zod_code_inline(s, Some(defined_names)))
      }
      "@moon_zod.intersection([" + join_with(parts, ", ") + "])"
    }
    PreprocessType(_, _) =>
      abort(
        "Custom preprocess cannot be serialized; use try_schema_to_moon_zod_code()",
      )
    LiteralType(val) => "@moon_zod.literal(" + json_to_literal(val) + ")"
    TransformType(inner, closure) => {
      let base = schema_to_moon_zod_code_inline(
        if inner.name == wrapper_name {
          { ..inner, name: "", }
        } else {
          inner
        },
        Some(defined_names),
      )
      let suffix = match closure.kind {
        TrimTransform => ".trim()"
        LowerTransform => ".to_lower()"
        UpperTransform => ".to_upper()"
        IdentityTransform => ""
        CustomTransform => abort("Custom transform cannot be serialized")
      }
      base + suffix
    }
    LazyType(resolve) => {
      let resolved = resolve()
      if !resolved.name.is_empty() && defined_names.contains(resolved.name) {
        "@moon_zod.recursive(" +
        @core.escape_function_name(resolved.name) +
        "_schema)"
      } else {
        "@moon_zod.recursive(fn() { " +
        schema_to_moon_zod_code_inline(
          resolved,
          Some(defined_names),
          inline_root=resolved.name == wrapper_name,
        ) +
        " })"
      }
    }
    DiscriminatedUnionType(disc, options) => {
      let parts : Array[String] = []
      for key, option in options {
        let opt_code = schema_to_moon_zod_code_inline(
          option,
          Some(defined_names),
        )
        parts.push("\"" + @core.escape_mbt_string(key) + "\": " + opt_code)
      }
      "@moon_zod.discriminated_union(\"" +
      @core.escape_mbt_string(disc) +
      "\", {" +
      join_with(parts, ", ") +
      "})"
    }
    PipeType(input, _, output) => {
      let input = if input.name == wrapper_name {
        { ..input, name: "", }
      } else {
        input
      }
      let input_code = schema_to_moon_zod_code_inline(
        input,
        Some(defined_names),
      )
      let output_code = schema_to_moon_zod_code_inline(
        output,
        Some(defined_names),
      )
      input_code + ".pipe(" + output_code + ")"
    }
  }
}

///|
/// Apply rules as method chain.
/// Note: Only outputs constraint annotations, not rule messages,
/// since rule.message may be auto-generated defaults.
fn apply_rules_to_code(base : String, schema : @core.Schema) -> String {
  let mut result = base
  for rule in schema.rules {
    let operation = match rule.constraint {
      Minimum(_, value, inclusive) =>
        if !inclusive && value == 0.0 {
          ".positive()"
        } else {
          (if inclusive { ".min(" } else { ".gt(" }) +
          format_mbt_number(value) +
          ")"
        }
      Maximum(_, value, inclusive) =>
        if !inclusive && value == 0.0 {
          ".negative()"
        } else {
          (if inclusive { ".max(" } else { ".lt(" }) +
          format_mbt_number(value) +
          ")"
        }
      ExactLength(_, value) => ".length(" + value.to_string() + ")"
      Multiple(value) => ".multipleOf(" + format_mbt_number(value) + ")"
      Integer => ".int()"
      SafeInteger => ".safe()"
      Finite => ".finite()"
      Pattern(value) => ".regex(\"" + @core.escape_mbt_string(value) + "\")"
      Prefix(value) => ".startsWith(\"" + @core.escape_mbt_string(value) + "\")"
      Suffix(value) => ".endsWith(\"" + @core.escape_mbt_string(value) + "\")"
      Contains(value) => ".includes(\"" + @core.escape_mbt_string(value) + "\")"
      Format(value) =>
        match value {
          "uri" => ".url()"
          "date-time" => datetime_to_code(rule.annotation)
          "email" => ".email()"
          "uuid" => ".uuid()"
          "ipv4" => ".ipv4()"
          "ipv6" => ".ipv6()"
          "ip" => ".ip()"
          "ulid" => ".ulid()"
          "cuid" => ".cuid()"
          _ => abort("Unsupported format in source export: " + value)
        }
      Opaque =>
        abort(
          "Opaque rule cannot be serialized; use try_schema_to_moon_zod_code()",
        )
    }
    result = result + operation
    if rule.explicit_message {
      result = result +
        ".message(\"" +
        @core.escape_mbt_string(rule.message) +
        "\")"
    }
  }
  result
}

///|
fn datetime_to_code(annotation : Json) -> String {
  guard annotation is Object(fields) &&
    fields.get("x-moon-zod-datetime") is Some(Object(params)) else {
    return ".datetime()"
  }
  let offset = params.get("offset") is Some(True)
  let allow_local = params.get("allow_local") is Some(True)
  let precision = match params.get("precision") {
    Some(Number(value, ..)) => value.to_int()
    _ => -2
  }
  if !offset && !allow_local && precision == -2 {
    ".datetime()"
  } else {
    ".datetime(offset=" +
    offset.to_string() +
    ", allow_local=" +
    allow_local.to_string() +
    ", precision=" +
    precision.to_string() +
    ")"
  }
}

///|
fn source_export_error(schema : @core.Schema) -> String? {
  let nodes = match @core.try_schema_nodes(schema) {
    Ok(nodes) => nodes
    Err(message) => return Some(message)
  }
  let identifiers : Map[String, String] = Map([])
  for node in nodes {
    if !node.name.is_empty() {
      let identifier = @core.escape_variable_name(node.name)
      match identifiers.get(identifier) {
        Some(previous) =>
          if previous != node.name {
            return Some(
              "Schema names collide after identifier escaping: " + node.name,
            )
          }
        None => identifiers.set(identifier, node.name)
      }
    }
    if node.schema_type is PreprocessType(_, _) {
      return Some("Custom preprocess callbacks cannot be serialized")
    }
    if node.schema_type is TransformType(_, closure) &&
      closure.kind is CustomTransform {
      return Some("Custom transform callbacks cannot be serialized")
    }
    if node.rules.any(fn(rule) { rule.constraint is Opaque }) {
      return Some("Opaque refinement callbacks cannot be serialized")
    }
  }
  if contains_lazy(schema, Map([])) {
    for node in nodes {
      if !node.name.is_empty() {
        let helper = @core.escape_function_name(node.name) + "_schema"
        if identifiers.contains(helper) {
          return Some(
            "Recursive helper name collides with schema variable: " + helper,
          )
        }
      }
    }
  }
  None
}

///|
/// Generate faithful source or return an explicit unsupported-schema error.
pub fn try_schema_to_moon_zod_code(
  schema : @core.Schema,
) -> Result[String, String] {
  match source_export_error(schema) {
    Some(message) => Err(message)
    None => Ok(schema_to_moon_zod_code(schema))
  }
}

///|
/// Convert a Json value to moon_zod @core.literal expression.
fn json_to_literal(val : Json) -> String {
  match val {
    String(s) => "Json::string(\"" + @core.escape_mbt_string(s) + "\")"
    Number(v, ..) => "Json::number(" + format_mbt_number(v) + ")"
    True => "true"
    False => "false"
    Null => "null"
    Array(arr) => {
      let parts = arr.map(fn(v) { json_to_literal(v) })
      "Json::array([" + join_with(parts, ", ") + "])"
    }
    Object(map) => {
      let parts : Array[String] = []
      for k, v in map {
        let lit = json_to_literal(v)
        parts.push("\"" + @core.escape_mbt_string(k) + "\": " + lit)
      }
      "Json::object({" + join_with(parts, ", ") + "})"
    }
  }
}

///|
fn join_with(parts : Array[String], sep : String) -> String {
  if parts.is_empty() {
    return ""
  }
  let mut result = parts[0]
  for i = 1; i < parts.length(); i = i + 1 {
    result = result + sep + parts[i]
  }
  result
}

///|
fn format_mbt_number(value : Double) -> String {
  let text = @core.format_double_simple(value)
  let parts = text.split("e").to_array()
  if parts.length() == 2 && !parts[0].contains(".") {
    parts[0].to_owned() + ".0e" + parts[1].to_owned()
  } else {
    text
  }
}
