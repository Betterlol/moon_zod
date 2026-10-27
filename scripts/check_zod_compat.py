"""Compare shared JSON behavior and pin intentional differences against local Zod.

Requires Python 3.10+, MoonBit and Node 24+. No npm dependencies are installed.
The oracle reads the local Zod source, not a separately installed npm package.
Error codes/paths are retained as diagnostics in each implementation's protocol;
messages and error representation are deliberately excluded from comparison.
"""

import argparse
from dataclasses import dataclass
import json
from pathlib import Path
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
ORACLE = Path(__file__).with_name("zod_compat_oracle.mjs")
ZOD_VERSION = "4.6.7"


def ok(data, **extra):
    return {"success": True, "data": data, **extra}


def bad(**extra):
    return {"success": False, **extra}


@dataclass(frozen=True)
class Case:
    name: str
    moon: str
    expected: dict
    zod_expected: dict | None = None

    @property
    def group(self):
        return "expected-divergence" if self.zod_expected is not None else "shared"


def literal(value):
    """MoonBit accepts these JSON-compatible string literals, including Unicode."""
    return json.dumps(value, ensure_ascii=False)


def parse_case(name, schema, value, expected, zod_expected=None):
    # Escape fixture text as JSON first: U+2028/U+0085 must not become source lines.
    source = f'record(results, {literal(name)}, ({schema}).parse(j({literal(json.dumps(value))})))'
    return Case(name, source, expected, zod_expected)


# Keep IDs and fixtures explicit; the independent oracle has the matching ID list.
CASES = [
    Case("intersection.prefault-missing", r'''
let fallback = j("{\"a\":\"x\",\"b\":\"y\"}")
let schema = @moon_zod.intersection([@moon_zod.object({"a": @moon_zod.string()}).strict().prefault(fallback), @moon_zod.object({"b": @moon_zod.string()}).strict().prefault(fallback)])
let result = match schema.parse_missing() { Ok(Some(value)) => Ok(value); Ok(None) => Ok(Json::null()); Err(errors) => Err(errors) }
record(results, "intersection.prefault-missing", result)
''', ok({"a": "x", "b": "y"})),
    parse_case("intersection.defaults-required-field", '@moon_zod.object({"v": @moon_zod.intersection([@moon_zod.string().default(Json::string("a")), @moon_zod.string().default(Json::string("a"))])})', {}, bad()),
    parse_case("intersection.defaults-outer-optional", '@moon_zod.object({"v": @moon_zod.intersection([@moon_zod.string().default(Json::string("a")), @moon_zod.string().default(Json::string("a"))]).optional()})', {}, ok({})),
    Case("tuple.overlong-callbacks", r'''
let calls = Ref(0)
let field = @moon_zod.tuple([@moon_zod.string()]).refine(fn(_) { calls.val += 1; true }, "tuple")
let schema = @moon_zod.object({"v": field}).refine(fn(_) { calls.val += 1; true }, "parent")
record(results, "tuple.overlong-callbacks", schema.parse(j("{\"v\":[\"a\",\"b\"]}")), extra={"calls": Json::number(calls.val.to_double())})
''', bad(calls=0)),
    parse_case("intersection.strict", '@moon_zod.intersection([@moon_zod.object({"a": @moon_zod.string()}).strict(), @moon_zod.object({"b": @moon_zod.string()}).strict()])', {"a": "x", "b": "y"}, ok({"a": "x", "b": "y"})),
    parse_case("intersection.unknown-keys", '@moon_zod.intersection([@moon_zod.object({"a": @moon_zod.string()}).strict(), @moon_zod.object({"b": @moon_zod.string()}).strict()])', {"a": "x", "b": "y", "c": 1, "d": 2}, bad()),
    parse_case("intersection.strict-strip", '@moon_zod.intersection([@moon_zod.object({"a": @moon_zod.string()}).strict(), @moon_zod.object({"b": @moon_zod.string()})])', {"a": "x", "b": "y", "c": 1}, ok({"a": "x", "b": "y"})),
    parse_case("intersection.nested-strict", '@moon_zod.intersection([@moon_zod.object({"inner": @moon_zod.object({"a": @moon_zod.string()}).strict()}), @moon_zod.object({"other": @moon_zod.string()})])', {"inner": {"a": "x", "extra": 1}, "other": "y"}, bad()),
    Case("intersection.effects", r'''
let calls = Ref(0)
let left = @moon_zod.object({"a": @moon_zod.string()}).strict().transform(fn(v) { calls.val += 1; Ok(v) }).pipe(@moon_zod.object({"a": @moon_zod.string().to_upper()}))
let right = @moon_zod.object({"b": @moon_zod.string()}).strict().transform(fn(v) { calls.val += 1; Ok(v) })
let result = @moon_zod.intersection([left, right]).parse(j("{\"a\":\"x\",\"b\":\"y\"}"))
record(results, "intersection.effects", result, extra={"calls": Json::number(calls.val.to_double())})
''', ok({"a": "X", "b": "y"}, calls=2)),
    Case("intersection.nested-effects", r'''
let calls = Ref(0)
let left = @moon_zod.object({"inner": @moon_zod.object({"a": @moon_zod.string()}).strict()}).transform(fn(v) { calls.val += 1; Ok(v) })
let result = @moon_zod.intersection([left, @moon_zod.object({"other": @moon_zod.string()})]).parse(j("{\"inner\":{\"a\":\"x\",\"extra\":1},\"other\":\"y\"}"))
record(results, "intersection.nested-effects", result, extra={"calls": Json::number(calls.val.to_double())})
''', bad(calls=1)),
    Case("intersection.refinement-blocks-transform", r'''
let calls = Ref(0)
let left = @moon_zod.object({"a": @moon_zod.string()}).strict().refine(fn(_) { false }, "boom").transform(fn(v) { calls.val += 1; Ok(v) })
let result = @moon_zod.intersection([left, @moon_zod.object({"b": @moon_zod.string()}).strict()]).parse(j("{\"a\":\"x\",\"b\":\"y\"}"))
record(results, "intersection.refinement-blocks-transform", result, extra={"calls": Json::number(calls.val.to_double())})
''', bad(calls=0)),
    Case("int.fractional-callbacks", r'''
let calls = Ref(0)
let integer = @moon_zod.number().int().refine(fn(_) { calls.val += 1; true }, "child")
let schema = @moon_zod.object({"n": integer}).refine(fn(_) { calls.val += 1; true }, "parent")
let result = schema.parse(j("{\"n\":1.5}"))
record(results, "int.fractional-callbacks", result, extra={"calls": Json::number(calls.val.to_double())})
''', bad(calls=0)),
    Case("int.unsafe-positive-continuation", r'''
let calls = Ref(0)
let result = @moon_zod.number().int().refine(fn(_) { calls.val += 1; true }, "later").parse(Json::number(9007199254740992.0))
record(results, "int.unsafe-positive-continuation", result, extra={"calls": Json::number(calls.val.to_double())})
''', bad(calls=1)),
    Case("int.unsafe-negative-continuation", r'''
let calls = Ref(0)
let result = @moon_zod.number().int().refine(fn(_) { calls.val += 1; true }, "later").parse(Json::number(-9007199254740992.0))
record(results, "int.unsafe-negative-continuation", result, extra={"calls": Json::number(calls.val.to_double())})
''', bad(calls=1)),
    Case("effects.builtin-dirty-trim", r'''
let observed : Array[Json] = []
let result = @moon_zod.string().min(3).trim().refine(fn(v) { observed.push(v); false }, "later").parse(Json::string(" x"))
record(results, "effects.builtin-dirty-trim", result, extra={"observed": Json::array(observed)})
''', bad(observed=["x"])),
    Case("effects.custom-dirty-blocked", r'''
let calls = Ref(0)
let result = @moon_zod.string().min(3).transform(fn(v) { calls.val += 1; Ok(v) }).parse(Json::string(" x"))
record(results, "effects.custom-dirty-blocked", result, extra={"calls": Json::number(calls.val.to_double())})
''', bad(calls=0)),
    parse_case("optional.invalid-prefault-absent", '@moon_zod.object({"a": @moon_zod.string().min(3).prefault(Json::string("x")).optional()})', {}, ok({})),
    parse_case("optional.invalid-prefault-present", '@moon_zod.object({"a": @moon_zod.string().min(3).prefault(Json::string("x")).optional()})', {"a": "x"}, bad()),
    parse_case("optional.valid-prefault", '@moon_zod.object({"a": @moon_zod.string().min(3).prefault(Json::string("abc")).optional()})', {}, ok({"a": "abc"})),
    Case("optional.preprocess-default", r'''
let calls = Ref(0)
let field = @moon_zod.preprocess(fn(v) { calls.val += 1; Ok(v) }, @moon_zod.string().default(Json::string("fallback"))).optional()
let result = @moon_zod.object({"a": field}).parse(j("{}"))
record(results, "optional.preprocess-default", result, extra={"calls": Json::number(calls.val.to_double())})
''', ok({}, calls=0)),
    parse_case("pipe.default-direct", '@moon_zod.object({"a": @moon_zod.string().optional().pipe(@moon_zod.string().default(Json::string("x")))})', {}, ok({"a": "x"})),
    parse_case("pipe.default-outer-optional", '@moon_zod.object({"a": @moon_zod.string().optional().pipe(@moon_zod.string().default(Json::string("x"))).optional()})', {}, ok({})),
    parse_case("pipe.default-partial", '@moon_zod.object({"a": @moon_zod.string().optional().pipe(@moon_zod.string().default(Json::string("x")))}).partial()', {}, ok({})),
    parse_case("tuple.default", '@moon_zod.tuple([@moon_zod.string().default(Json::string("x"))])', [], ok(["x"])),
    parse_case("tuple.trailing-optional", '@moon_zod.tuple([@moon_zod.string(), @moon_zod.string().optional()])', ["a"], ok(["a"])),
    parse_case("tuple.minimum-prefix", '@moon_zod.tuple([@moon_zod.string(), @moon_zod.string().optional()])', [], bad()),
    parse_case("tuple.overlong-invalid-element", '@moon_zod.tuple([@moon_zod.string()])', [1, 2], bad()),
    parse_case("unicode.lower", '@moon_zod.string().to_lower()', "ÉCOLE ΣΊΣΥΦΟΣ İ ẞ 𐐀 Ꭰ", ok("école σίσυφος i\u0307 ß 𐐨 ꭰ")),
    parse_case("unicode.upper", '@moon_zod.string().to_upper()', "straße ﬃ ǰ ΐ 𐐨 ꭰ", ok("STRASSE FFI J\u030c Ι\u0308\u0301 𐐀 Ꭰ")),
    parse_case("unicode.sigma-context", '@moon_zod.string().to_lower()', "ΟΣ ΟΣΑ ΣΣ AΣ'A AΣ'! AΣ1A ⅠΣ", ok("ος οσα σς aσ'a aς'! aς1a ⅰς")),
    parse_case("unicode.trim-whitespace", '@moon_zod.string().trim()', "\ufeff\u00a0\u2028 x \u3000\u2029", ok("x")),
    parse_case("unicode.trim-nonwhitespace", '@moon_zod.string().trim()', "\u0085\u180e\u200b\u2060", ok("\u0085\u180e\u200b\u2060")),
    parse_case("datetime.minute-offset", '@moon_zod.string().datetime(precision=-1, offset=true)', "2024-01-01T12:34+08:00", ok("2024-01-01T12:34+08:00")),
    parse_case("datetime.minute-reject-seconds", '@moon_zod.string().datetime(precision=-1, offset=true)', "2024-01-01T12:34:00+08:00", bad()),
    parse_case("datetime.zero-local-reject-minutes", '@moon_zod.string().datetime(precision=0, allow_local=true)', "2024-01-01T12:34", bad()),
    parse_case("datetime.zero-local-seconds", '@moon_zod.string().datetime(precision=0, allow_local=true)', "2024-01-01T12:34:00", ok("2024-01-01T12:34:00")),
    parse_case("datetime.default-local-minutes", '@moon_zod.string().datetime(allow_local=true)', "2024-01-01T12:34", ok("2024-01-01T12:34")),
    parse_case("ulid.lower", '@moon_zod.string().ulid()', "01arz3ndektsv4rrffq69g5fav", ok("01arz3ndektsv4rrffq69g5fav")),
    parse_case("ulid.mixed", '@moon_zod.string().ulid()', "01ArZ3nDeKtSv4rRfFq69g5FaV", ok("01ArZ3nDeKtSv4rRfFq69g5FaV")),
    parse_case("ulid.invalid-alphabet", '@moon_zod.string().ulid()', "01ARZ3NDEKTSV4RRFFQ69G5FAi", bad()),
    Case("int.schema-input-bounds", r'''
let contract = @moon_zod.try_to_json_schema(@moon_zod.number().int(), view=InputView).unwrap()
record(results, "int.schema-input-bounds", Ok(bounds(contract)))
''', ok({"type": "integer", "minimum": -9007199254740991, "maximum": 9007199254740991})),
    Case("int.schema-output-bounds", r'''
let contract = @moon_zod.try_to_json_schema(@moon_zod.number().int(), view=OutputView).unwrap()
record(results, "int.schema-output-bounds", Ok(bounds(contract)))
''', ok({"type": "integer", "minimum": -9007199254740991, "maximum": 9007199254740991})),
    parse_case("divergence.uri-profile", '@moon_zod.string().url()', " https://example.com ", bad(), ok("https://example.com")),
    parse_case("divergence.cuid-profile", '@moon_zod.string().cuid()', "c123456", bad(), ok("c123456")),
    parse_case("divergence.email-profile", '@moon_zod.string().email()', "a'@example.com", ok("a'@example.com"), bad()),
    parse_case("divergence.exact-decimal-multiple", '@moon_zod.number().multipleOf(0.1)', 0.30000000000000004, bad(), ok(0.30000000000000004)),
    Case("divergence.missing-json-callback", r'''
let calls = Ref(0)
let field = @moon_zod.string().optional().transform(fn(_) { calls.val += 1; Ok(Json::string("filled")) })
let result = @moon_zod.object({"a": field}).parse(j("{}"))
record(results, "divergence.missing-json-callback", result, extra={"calls": Json::number(calls.val.to_double())})
''', ok({}, calls=0), ok({"a": "filled"}, calls=1)),
]

for name, value, count in [("astral", "😀", 1), ("mixed", "a😀b", 3), ("combining", "e\u0301", 2), ("zwj", "🧑‍🍼", 3)]:
    CASES.append(parse_case(f"unicode.length-{name}", f"@moon_zod.string().length({count})", value, ok(value)))
    CASES.append(parse_case(f"unicode.min-{name}", f"@moon_zod.string().min({count + 1})", value, bad()))


PREAMBLE = r'''///|
fn j(text : String) -> Json { @moon_zod.parse_json(text) }
///|
fn bounds(contract : Json) -> Json {
  guard contract is Object(source) else { abort("expected object contract") }
  let fields : Map[String, Json] = Map([])
  for key in ["type", "minimum", "maximum"] {
    fields.set(key, source.get(key).unwrap_or(Json::null()))
  }
  Json::object(fields)
}
///|
fn record(results : Map[String, Json], name : String, result : @moon_zod.SchemaResult, extra~ : Map[String, Json] = Map([])) -> Unit {
  let row = extra.copy()
  match result {
    Ok(value) => { row.set("success", Json::boolean(true)); row.set("data", value) }
    Err(errors) => {
      row.set("success", Json::boolean(false))
      row.set("diagnostics", Json::array(errors.map(fn(error) {
        Json::object({"code": Json::string(@debug.to_string(error.code)), "path": Json::string(error.path)})
      })))
    }
  }
  results.set(name, Json::object(row))
}
'''


def run(command, cwd=ROOT):
    result = subprocess.run(command, cwd=cwd, capture_output=True, encoding="utf-8")
    if result.returncode:
        raise RuntimeError(f"{' '.join(map(str, command))}\n{result.stdout}\n{result.stderr}")
    return result.stdout


def find_zod(explicit):
    if explicit:
        candidates = [Path(explicit).expanduser().resolve()]
    else:
        candidates = [ancestor / ".compare" / "zod" for ancestor in (ROOT, *ROOT.parents)]
    for candidate in candidates:
        if (candidate / "packages/zod/src/v4/classic/external.ts").is_file():
            return candidate.resolve()
    raise RuntimeError("Local Zod source was not found; pass --zod-path PATH.")


def comparable(row):
    return {key: value for key, value in row.items() if key != "diagnostics"}


def check_rows(rows, side, failures):
    names = {case.name for case in CASES}
    if set(rows) != names:
        failures.append(f"{side}: case IDs differ: missing={sorted(names-set(rows))}, extra={sorted(set(rows)-names)}")
    for case in CASES:
        if case.name not in rows:
            continue
        expected = case.zod_expected if side == "zod" and case.zod_expected is not None else case.expected
        actual = comparable(rows[case.name])
        if actual != expected:
            failures.append(f"{side} {case.group} {case.name}: expected={json.dumps(expected, ensure_ascii=False)} actual={json.dumps(rows[case.name], ensure_ascii=False)}")


def revision(path):
    result = subprocess.run(["git", "-C", str(path), "rev-parse", "--short", "HEAD"], capture_output=True, encoding="utf-8")
    return result.stdout.strip() if result.returncode == 0 else "unknown"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--zod-path", help="Zod repository root (default: nearest ancestor .compare/zod)")
    parser.add_argument("--target", choices=("wasm-gc", "js", "both"), default="both")
    parser.add_argument("--verbose", action="store_true", help="Print every checked case ID")
    args = parser.parse_args()
    zod_path = find_zod(args.zod_path)
    zod_version = json.loads((zod_path / "packages/zod/package.json").read_text(encoding="utf-8"))["version"]
    if zod_version != ZOD_VERSION:
        raise RuntimeError(f"Expected Zod {ZOD_VERSION}, found {zod_version}; review fixtures before changing the pin.")
    oracle = json.loads(run(["node", "--experimental-transform-types", str(ORACLE), str(zod_path)]))
    if oracle["version"] != ZOD_VERSION:
        raise RuntimeError("Oracle version does not match its source checkout.")
    failures = []
    check_rows(oracle["cases"], "zod", failures)
    scratch = ROOT / "tmp"
    scratch.mkdir(exist_ok=True)
    targets = ("wasm-gc", "js") if args.target == "both" else (args.target,)
    counts = {group: sum(case.group == group for case in CASES) for group in ("shared", "expected-divergence")}
    print(f"BASELINE Zod {zod_version} {revision(zod_path)}; Moon {revision(ROOT)} (current working files)")
    with tempfile.TemporaryDirectory(prefix="zod_compat_", dir=scratch) as temp:
        producer = Path(temp) / "producer"
        producer.mkdir()
        (producer / "moon.pkg").write_text('import { "Betterlol/moon_zod", "moonbitlang/core/debug" }\noptions("is-main": true)\n', encoding="utf-8")
        blocks = ["  {\n" + "\n".join("    " + line for line in case.moon.strip().split("\n")) + "\n  }" for case in CASES]
        source = PREAMBLE + '\n///|\nfn main {\n  let results : Map[String, Json] = Map([])\n' + "\n".join(blocks) + '\n  println(Json::object(results).stringify())\n}\n'
        (producer / "main.mbt").write_text(source, encoding="utf-8")
        for target in targets:
            rows = json.loads(run(["moon", "run", producer.relative_to(ROOT).as_posix(), "--target", target]))
            before = len(failures)
            check_rows(rows, f"moon-{target}", failures)
            for case in CASES:
                if case.group == "shared" and case.name in rows and case.name in oracle["cases"]:
                    if comparable(rows[case.name]) != comparable(oracle["cases"][case.name]):
                        failures.append(f"DIFF {target} {case.name}: moon={json.dumps(rows[case.name], ensure_ascii=False)} zod={json.dumps(oracle['cases'][case.name], ensure_ascii=False)}")
                if args.verbose:
                    print(f"CASE {target} {case.group} {case.name}")
            outcome = "PASS" if len(failures) == before else "FAIL"
            print(f"{outcome} {target}: {counts['shared']} shared, {counts['expected-divergence']} expected-divergence cases")
    for failure in failures:
        print(f"FAIL {failure}", file=sys.stderr)
    if failures:
        print(f"FAIL {len(failures)} expectation/differential mismatches", file=sys.stderr)
        return 1
    print("PASS all local Zod expectations, Moon expectations and shared JSON comparisons")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, ValueError, KeyError) as error:
        print(f"ERROR {error}", file=sys.stderr)
        sys.exit(1)
