///|
/// JSON null or an inline value. Unlike Option outside struct fields, values are
/// not encoded as singleton arrays. Used by generated nullable field/element types.
pub(all) enum JsonNullable[T] {
  JsonNull
  JsonValue(T)
} derive(Debug, Eq)

///|
/// Encode null or the wrapped value in its original JSON shape.
pub impl[T : ToJson] ToJson for JsonNullable[T] with fn to_json(self) {
  match self {
    JsonNull => Json::null()
    JsonValue(value) => value.to_json()
  }
}

///|
/// Decode null or an inline value without Option's singleton-array convention.
pub impl[T : @json.FromJson] @json.FromJson for JsonNullable[T] with fn from_json(
  value,
  path,
) {
  match value {
    Null => JsonNull
    _ => JsonValue(@json.from_json(value, path~))
  }
}

///|
/// Serialize a nullable value using JSON's inline null-or-value representation.
pub extend JsonNullable with ToJson::{to_json}
