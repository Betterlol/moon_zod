"""Validate successful parse outputs with an independent JSON Schema engine."""

import json
from pathlib import Path
import tempfile

from jsonschema import Draft202012Validator
from check_generated_source import ROOT, SCRATCH, moon, package


PRODUCER = r'''///|
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
    fixtures.push(Json::object({"schema": contract, "value": value}))
  }
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
                validator.validate(fixture["value"])
                bad = {"n": {"a": "x"}} if isinstance(fixture["value"], dict) else [{"a": "x"}]
                assert not validator.is_valid(bad), "required merged property was lost"
            print(f"Output contracts ({backend}): {len(fixtures)} accepted outputs and negative controls passed")


if __name__ == "__main__":
    main()
