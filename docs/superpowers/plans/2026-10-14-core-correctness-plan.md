# Core correctness implementation plan

Spec: ../specs/2026-10-14-core-correctness-design.md
Base: 8f72dc5 (origin/main). Branch: codex/core-semantics-fixes.

1. Repair parsed container outputs, node refinements, message targeting,
   recursive intersection merge and effect-stage callbacks.
2. Introduce missing-input handling and Zod 4 optional/nullable/nullish/default/
   prefault semantics; update reexports, exporters, importers and existing tests.
3. Repair number semantics, wider numeric bounds/multiples and inference.
4. Correct string formats, built-in effect chains and constraint representation.
5. Repair complete schema traversal, recursive exports, mutable collection
   isolation and discriminated union contracts.
6. Improve escaped paths, union diagnostics, error message precedence and
   consistent wrapper custom errors; document public API and migration.
7. Run full tests on Wasm and JS, generated interface and formatting checks,
   independent whole-branch review, then push and create a PR.

For each task: write regressions, observe failure, implement, observe green full
suite, run moon info then moon fmt, inspect interface diff, commit explicit files.
Expected: targeted regressions fail before the fix; full suite passes after it.

Shared interfaces: task 1's post-parse checks are reused by missing parsing in
task 2; task 2's wrapper kinds must be covered by effects, traversal and exporters
in tasks 3-6; constraint metadata in task 4 feeds task 5's export validation.

Review focus: refine on every kind including wrappers; failure branch input
mutation; nested parsed values; missing vs null with effects/defaults; numeric
precision and invalid constructor arguments; recursive references and duplicate
names; custom-effect export failures; special path keys and nested unions;
schema-vs-parse error precedence; generated source compiles and preserves checks.

## Execution record

Tasks 1–6 completed in separate commits:

| Task | Commit(s) | Verified full suite |
| --- | --- | --- |
| Parsed values / refinements / intersection | 6c41166 | green |
| Missing / null / defaults | 6228510 | green |
| Numeric contracts | ed7f700 | 595 passed |
| Formats / constraints / effects | c3aa566, 0257413 | green |
| Graph identity / recursive exports / checked views | 1ba096d, 470b156 | 619 passed |
| Structured paths / precedence | 22a8f88 | 627 passed |
| Refined shapes / compiled source / roundtrip | 431c0bd | 638 passed |

Final fresh-context review reported 11 actionable findings. All entered a single
regression/fix pass; tests/test_review_regressions.mbt initially failed every one
of its 12 tests, then passed all 12 (the extra test prevents missing JSON callbacks
from observing a null sentinel). Full suite: 653/653. No deferred minor findings.

Fixed: refinement identity; completed duplicate lazy names; productive anchored
recursion; inherited pipeline names; union/lazy defaults under optional; lazy
optionality; absence-versus-present intersection conflict; transformed optional
output; strict intersection checked input; outer required messages; enum message
origin. Compiling the added anchored recursion fixture also caught an unbound
forward variable, repaired with a lazy helper reference. Scientific literals
initially failed compilation (1e-7); source now emits valid 1.0e-7 notation.
Three further regressions verified Zod 4 union branch selection, missing-union
fallback diagnostics and inhibition of output callbacks after failed effect input;
all three failed before repair. Present and missing unions share one selection
protocol.
Generated source: 7/7 compiled-and-executed cases on each of Wasm GC and JS.

Ruling: missing values never invoke a Json callback, including refine — Json has
no undefined value, and null cannot stand in for absence — callers needing to
reject absence must use a required schema rather than inspecting a Json sentinel.

Ruling: strict object intersection and unsupported recursive input projections
return Err from checked export — merging the legacy generation shapes would lie
about independent branch validation — callers must supply a separate structural
input contract for those cases.

Final gates: moon info; moon fmt; moon fmt --check; moon check --deny-warn; moon
build; moon build --target wasm --release; moon test; moon test --target js;
python scripts/check_generated_source.py. Public metadata/error/wrapper interface
changes are expected and documented. Generated .mbti files remain ignored per
repository policy. Source changes are staged by explicit path lists.
