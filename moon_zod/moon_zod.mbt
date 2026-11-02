///|
/// moon_zod — A runtime JSON schema validation library for MoonBit.
///
/// Inspired by [Zod](https://zod.dev) (TypeScript) and [Pydantic](https://docs.pydantic.dev) (Python).
///
/// Designed for LLM Tool Calling: validate structured JSON output from large
/// language models at runtime, with precise error reporting.
///
/// # Quick start
///
/// ```mbt
/// let schema = @moon_zod.object({
///   "name": @moon_zod.string().min(2).max(50),
///   "age": @moon_zod.number().int().min(0).max(150),
/// })
///
/// match schema.parse(some_json) {
///   Ok(valid) => // use valid
///   Err(errors) => // report errors back to the LLM
/// }
/// ```
