///|
fn parse_json(input : String) -> Json {
  @json.parse(input) catch {
    _ => abort("bad test json: " + input)
  }
}
