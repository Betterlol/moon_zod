"""Validate exported contracts with an independent JSON Schema engine."""

import json
from pathlib import Path
import tempfile

from jsonschema import Draft202012Validator
from check_generated_source import ROOT, SCRATCH, moon, package


PRODUCER = r'''///|
fn escaped_tree() -> @moon_zod.Schema {
  @moon_zod.recursive(fn() {
    @moon_zod.object({
      "value": @moon_zod.string(),
      "children": @moon_zod.array(@moon_zod.recursive(escaped_tree)).optional(),
    }).strict()
  }).name("Tree~/ %2F#树😀")
}
///|
fn main {
  let schemas = [
    @moon_zod.intersection([
      @moon_zod.object({"n": @moon_zod.object({"a": @moon_zod.string()})}),
      @moon_zod.object({"n": @moon_zod.object({"b": @moon_zod.number()})}),
    ]),
    @moon_zod.intersection([
      @moon_zod.array(@moon_zod.object({"a": @moon_zod.string()})),
      @moon_zod.array(@moon_zod.object({"b": @moon_zod.number()})),
    ]),
    @moon_zod.intersection([
      @moon_zod.tuple([@moon_zod.object({"a": @moon_zod.string()})]),
      @moon_zod.tuple([@moon_zod.object({"b": @moon_zod.number()})]),
    ]),
  ]
  let inputs = [
    @moon_zod.parse_json("{\"n\":{\"a\":\"x\",\"b\":1}}"),
    @moon_zod.parse_json("[{\"a\":\"x\",\"b\":1}]"),
    @moon_zod.parse_json("[{\"a\":\"x\",\"b\":1}]"),
  ]
  let fixtures : Array[Json] = []
  for i = 0; i < schemas.length(); i = i + 1 {
    guard schemas[i].parse(inputs[i]) is Ok(value) else { abort("invalid fixture") }
    guard @moon_zod.try_to_json_schema(schemas[i], view=OutputView) is Ok(contract) else { abort("unsupported fixture") }
    let invalid = if i == 0 {
      @moon_zod.parse_json("{\"n\":{\"a\":\"x\"}}")
    } else {
      @moon_zod.parse_json("[{\"a\":\"x\"}]")
    }
    fixtures.push(Json::object({
      "schema": contract,
      "valid": Json::array([value]),
      "invalid": Json::array([invalid]),
    }))
  }
  let views : Array[@moon_zod.SchemaView] = [InputView, OutputView]
  for view in views {
    let integer = @moon_zod.number().int()
    guard @moon_zod.try_to_json_schema(integer, view~) is Ok(contract) else {
      abort("unsupported integer fixture")
    }
    let valid = [-9007199254740991.0, 0.0, 9007199254740991.0]
    let invalid = [-9007199254740992.0, 9007199254740992.0, 1.5]
    for value in valid {
      guard integer.parse(Json::number(value)) is Ok(_) else { abort("invalid integer fixture") }
    }
    for value in invalid {
      guard integer.parse(Json::number(value)) is Err(_) else { abort("accepted unsafe integer") }
    }
    fixtures.push(Json::object({
      "schema": contract,
      "valid": Json::array(valid.map(fn(value) { Json::number(value) })),
      "invalid": Json::array(invalid.map(fn(value) { Json::number(value) })),
    }))
  }
  for name in ["A/B", "A~1B", "A%2FB", "A B#C", "é", "树😀"] {
    fixtures.push(Json::object({
      "schema": @moon_zod.to_json_schema_named(@moon_zod.string().name(name)),
      "valid": Json::array([Json::string("x")]),
      "invalid": Json::array([Json::number(1.0)]),
    }))
  }
  guard @moon_zod.try_to_json_schema(escaped_tree(), view=InputView) is Ok(contract) else {
    abort("unsupported recursive fixture")
  }
  fixtures.push(Json::object({
    "schema": contract,
    "valid": Json::array([
      @moon_zod.parse_json("{\"value\":\"a\",\"children\":[{\"value\":\"b\",\"children\":[{\"value\":\"c\"}]}]}"),
    ]),
    "invalid": Json::array([
      @moon_zod.parse_json("{\"value\":\"a\",\"children\":[{\"value\":1}]}"),
      @moon_zod.parse_json("{\"value\":\"a\",\"children\":[{\"value\":\"b\",\"extra\":1}]}"),
    ]),
  }))
  let optional_prefault = @moon_zod.object({
    "value": @moon_zod.string().min(3).prefault(Json::string("x")).optional(),
    "defaulted": @moon_zod.string().default(Json::string("ok")).optional(),
  })
  guard optional_prefault.parse(@moon_zod.parse_json("{}")) is Ok(value) else {
    abort("optional prefault did not allow absence")
  }
  guard @moon_zod.try_to_json_schema(optional_prefault, view=OutputView) is Ok(contract) else {
    abort("unsupported optional prefault fixture")
  }
  fixtures.push(Json::object({
    "schema": contract,
    "valid": Json::array([value]),
    "invalid": Json::array([
      @moon_zod.parse_json("{}"),
      @moon_zod.parse_json("{\"value\":\"x\",\"defaulted\":\"ok\"}"),
    ]),
  }))
  println(Json::array(fixtures).stringify())
}
'''


def main():
    with tempfile.TemporaryDirectory(prefix="output_contract_", dir=SCRATCH) as temp:
        task = Path(temp).resolve()
        assert task.parent == SCRATCH.resolve()
        producer = task / "producer"
        producer_path = package(producer)
        with (producer / "moon.pkg").open("a", encoding="utf-8") as config:
            config.write('options("is-main": true)\n')
        (producer / "main.mbt").write_text(PRODUCER, encoding="utf-8")
        for backend in ("wasm-gc", "js"):
            fixtures = json.loads(moon("run", producer_path, "--target", backend))
            for fixture in fixtures:
                Draft202012Validator.check_schema(fixture["schema"])
                validator = Draft202012Validator(fixture["schema"])
                for value in fixture["valid"]:
                    validator.validate(value)
                for value in fixture["invalid"]:
                    assert not validator.is_valid(value), (
                        f"contract accepted negative control: {value!r}"
                    )
            print(f"JSON Schema contracts ({backend}): {len(fixtures)} fixtures, boundary and reference controls passed")


if __name__ == "__main__":
    main()
