///|
/// **JSON @core.Schema → moon_zod source code**
///
/// Generates MoonBit source code by:
/// 1. Converting JSON @core.Schema to @core.Schema objects (Layer 1, from importers)
/// 2. Converting @core.Schema objects to code (Layer 2, from exporters)
///
/// This module serves as the composition layer that bridges importers and exporters.
///
/// # Example
/// ```mbt nocheck
/// let schema = @json.parse("{\"type\":\"@core.string\",\"minLength\":3}").unwrap()
///
/// let code = json_schema_to_moon_zod(schema)
/// // "let root = @moon_zod.string().min(3).name(\"Root\")"
/// ```

///|
/// **JSON @core.Schema → moon_zod source code**
pub fn json_schema_to_moon_zod(schema : Json) -> String {
  let schema_obj = @importers.json_schema_to_schema(schema)
  let named_defs = @exporters.schema_to_moon_zod_code_named(schema_obj)
  named_defs
}

///|
/// **JSON @core.Schema → prompt**
pub fn json_schema_to_prompt(schema : Json) -> String {
  let schema_obj = @importers.json_schema_to_schema(schema)
  let prompt = @exporters.schema_to_prompt_named(schema_obj)
  prompt
}
