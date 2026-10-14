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
