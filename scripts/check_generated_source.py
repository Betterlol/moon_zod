"""Compile and execute source emitted by the exporters (requires moon and Node)."""

import json
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
SCRATCH = ROOT / "tmp"
SCRATCH.mkdir(exist_ok=True)

PRODUCER = r'''///|
fn tree() -> @moon_zod.Schema {
  @moon_zod.recursive(fn() {
    @moon_zod.object({
      "value": @moon_zod.number(),
      "children": @moon_zod.array(@moon_zod.recursive(tree)).optional(),
    })
  }).name("Tree")
}
///|
fn anchored() -> @moon_zod.Schema {
  let anchor : Ref[@moon_zod.Schema?] = Ref(None)
  let schema = @moon_zod.recursive(fn() {
    @moon_zod.object({"children": @moon_zod.array(anchor.val.unwrap())})
  }).name("Anchor")
  anchor.val = Some(schema)
  schema
}
///|
fn main {
  let schemas = [
    @moon_zod.string().trim().length(3).message("three"),
    @moon_zod.object({
      "n": @moon_zod.number().gt(-1.5).default(Json::number(42.0)),
      "v": @moon_zod.literal(Json::number(9007199254740991.0)),
    }),
    tree(),
    anchored(),
    @moon_zod.string().name("Text").pipe(@moon_zod.string()),
    @moon_zod.number().min(1.0e-7).multipleOf(1.0e-7).default(Json::number(1.0e-7)),
    @moon_zod.number().min(9007199254740991.0),
    @moon_zod.number().max(-9007199254740991.0),
    @moon_zod.number().gt(2147483648.0),
    @moon_zod.number().lt(-2147483649.0),
    @moon_zod.number().multipleOf(2147483649.0),
  ]
  println(Json::array(schemas.map(fn(s) {
    Json::string(@moon_zod.schema_to_moon_zod_code(s))
  })).stringify())
  println(Json::string(@moon_zod.schema_to_moonbit_struct_full(tree())).stringify())
  let rows = [
    @moon_zod.object({"items": @moon_zod.array(@moon_zod.string().nullable())}).name("NullableRow"),
    @moon_zod.object({
      "items": @moon_zod.array(@moon_zod.array(@moon_zod.string().nullable()).nullable()).nullable(),
      "note": @moon_zod.string().nullish(),
      "pair": @moon_zod.array(@moon_zod.tuple([@moon_zod.string(), @moon_zod.number()])),
    }).name("NestedRow"),
    @moon_zod.object({"value": @moon_zod.string().default(Json::string("x")).optional()}).name("DefaultRow"),
  ]
  let values = [
    @moon_zod.parse_json("{\"items\":[null,\"x\"]}"),
    @moon_zod.parse_json("{\"items\":[null,[null,\"x\"]],\"note\":null,\"pair\":[[\"a\",1]]}"),
    @moon_zod.parse_json("{}"),
  ]
  let fixtures : Array[Json] = []
  for i = 0; i < rows.length(); i = i + 1 {
    guard rows[i].parse(values[i]) is Ok(output) else { abort("invalid fixture") }
    fixtures.push(Json::object({
      "name": Json::string(rows[i].name),
      "code": Json::string(@moon_zod.schema_to_moonbit_struct(rows[i])),
      "value": output,
    }))
  }
  println(Json::array(fixtures).stringify())
}
'''


def moon(*args):
    return subprocess.run(
        ["moon", *args], cwd=ROOT, check=True, capture_output=True,
        encoding="utf-8",
    ).stdout


def package(directory):
    directory.mkdir()
    (directory / "moon.pkg").write_text(
        'import { "Betterlol/moon_zod" }\n', encoding="utf-8",
    )
    return directory.relative_to(ROOT).as_posix()


def main():
    # The temporary directory is confined to this repository's ignored scratch area.
    with tempfile.TemporaryDirectory(prefix="core_export_", dir=SCRATCH) as temp:
        task = Path(temp).resolve()
        assert task.parent == SCRATCH.resolve()
        producer = task / "producer"
        producer_path = package(producer)
        with (producer / "moon.pkg").open("a", encoding="utf-8") as config:
            config.write('options("is-main": true)\n')
        (producer / "main.mbt").write_text(PRODUCER, encoding="utf-8")
        lines = moon("run", producer_path, "--target", "js").splitlines()
        codes, struct = json.loads(lines[0]), json.loads(lines[1])
        decode_fixtures = json.loads(lines[2])
        consumer = task / "consumer"
        consumer_path = package(consumer)
        (consumer / "moon.pkg").write_text('import { "Betterlol/moon_zod", "moonbitlang/core/json" }\n', encoding="utf-8")
        inputs = ['" abc "', '{"v":9007199254740991}',
                  '{"value":1,"children":[{"value":2}]}',
                  '{"children":[{"children":[]}]}', '"text"', '3e-7',
                  '9007199254740991', '-9007199254740991',
                  '2147483649', '-2147483650', '4294967298']
        expected = ['"abc"', '{"n":42,"v":9007199254740991}', *inputs[2:]]
        tests = []
        for index, (code, data, result) in enumerate(zip(codes, inputs, expected)):
            variable = ["root", "root", "tree", "anchor", "text", *(["root"] * 6)][index]
            lines = "\n".join("  " + line for line in code.splitlines())
            tests.append(
                f'///|\ntest "generated schema {index}" {{\n{lines}\n'
                f'  let input = @moon_zod.parse_json({json.dumps(data)})\n'
                f'  let expected = @moon_zod.parse_json({json.dumps(result)})\n'
                f'  assert_true({variable}.parse(input) is Ok(value) && value == expected)\n}}\n'
            )
        tests.append(struct)
        tests.append(
            '///|\ntest "generated recursive struct" {\n'
            f'  let input = @moon_zod.parse_json({json.dumps(inputs[2])})\n'
            '  assert_true(Tree::to_schema().parse(input) is Ok(value) && value == input)\n}\n'
        )
        for fixture in decode_fixtures:
            tests.append(fixture["code"])
            data = json.dumps(json.dumps(fixture["value"], ensure_ascii=True))
            tests.append(
                f'///|\ntest "decode generated {fixture["name"]}" {{\n'
                f'  let value = @moon_zod.parse_json({data})\n'
                f'  let decoded : {fixture["name"]} = @json.from_json(value) catch {{ _ => fail("generated type rejected legal output") }}\n'
                '  assert_true(ToJson::to_json(decoded) == value)\n'
                '}\n'
            )
        (consumer / "generated_test.mbt").write_text("\n".join(tests), encoding="utf-8")
        for backend in ("wasm-gc", "js"):
            print(f"Generated source ({backend}): " + moon(
                "test", consumer_path, "--target", backend,
            ).strip())


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        print(error.stdout)
        print(error.stderr)
        raise SystemExit(error.returncode)
