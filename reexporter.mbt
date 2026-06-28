///|
/// Wrapper: null() factory can't be re-exported via pub using (keyword conflict)
pub fn null(
  required_error? : String = "",
  invalid_type_error? : String = "",
) -> Schema {
  @core.null(required_error~, invalid_type_error~)
}

///|
/// Re-export core types, factory functions, and utilities.
pub using @core {
  type Schema,
  type SchemaType,
  type Rule,
  type ObjectMode,
  type TransformClosure,
  type ValidationError,
  type SchemaResult,
  type ConstraintInfo,
  string,
  number,
  boolean,
  object,
  array,
  enum_values,
  union,
  intersection,
  literal,
  unwrap_schema,
  peel_optional,
  indent_str,
  format_double_simple,
  join_parts,
  collect_named_schemas,
  topological_sort_schemas,
  filter_named_schemas,
  is_optional_schema,
  value_in_array,
  format_path,
  sub_path,
  sub_index,
  inner_type,
  append_rule,
  append_rule_with_annotation,
  json_infer_schema,
  extract_constraints,
  constraint_info_default,
  constraint_info_to_string_comment,
  constraint_info_to_number_comment,
  constraint_info_to_array_comment,
  constraint_info_to_fallback_comment,
  constraint_comment,
  escape_mbt_string,
  escape_ident,
  parse_json,
  schema_to_moon_zod_code,
  schema_to_moon_zod_code_with_names,
}

///|
pub using @exporters {
  trait JsonSchemaRenderer,
  trait MoonBitStructRenderer,
  trait StringRenderer,
  to_json_schema,
  to_json_schema_skeleton,
  to_json_schema_named,
  schema_to_moonbit_struct,
  schema_to_moonbit_struct_full,
  schema_to_moonbit_struct_named,
  schema_to_moonbit_struct_named_full,
  schema_to_prompt,
  schema_to_prompt_named,
}

///|
pub using @importers {json_schema_to_moon_zod, json_schema_to_schema}
