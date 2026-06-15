# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

You can browse and install extra skills here:
<https://github.com/moonbitlang/skills>

## Project Structure

- MoonBit packages are organized per directory; each directory contains a
  `moon.pkg` file listing its dependencies. Each package has its files and
  blackbox test files (ending in `_test.mbt`) and whitebox test files (ending in
  `_wbtest.mbt`).

- In the toplevel directory, there is a `moon.mod` file listing module
  metadata.

## MoonBit pitfalls

See [`moonbit_syntax_pitfalls.md`](./moonbit_syntax_pitfalls.md) for common syntax errors and
anti-patterns gathered from real development experience in this project. Read
this before writing any MoonBit code.

## Coding convention

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.

- Try to keep deprecated blocks in file called `deprecated.mbt` in each
  directory.

- Every public item needs `///|` doc comment.

- `pub` = package-visible, `pub(all)` = external. Be conservative with `pub`.

- Result pattern: `parse()` returns `Result`, never raise. Constructor methods
  may `abort()` on type misuse (programming error, not runtime data error).

- One factory function per `.mbt` file, rule methods in the same file.

## Workflow

1. Before writing code: understand the existing patterns first.
2. After making changes: run `moon test` to verify.
3. Before commit: `moon info && moon fmt` to regenerate `.mbti` and format code.
4. Check `.mbti` diff — if nothing changed, the refactoring is likely safe.
5. Never commit unrelated user changes. Never use `git add .`.

## Tooling

- `moon fmt` is used to format your code properly.

- `moon ide` provides project navigation helpers like `peek-def`, `outline`, and
  `find-references`. See $moonbit-agent-guide for details.

- `moon info` is used to update the generated interface of the package, each
  package has a generated interface file `.mbti`, it is a brief formal
  description of the package. If nothing in `.mbti` changes, this means your
  change does not bring the visible changes to the external package users, it is
  typically a safe refactoring.

- In the last step, run `moon info && moon fmt` to update the interface and
  format the code. Check the diffs of `.mbti` file to see if the changes are
  expected.

- Run `moon test` to check tests pass. MoonBit supports snapshot testing; when
  changes affect outputs, run `moon test --update` to refresh snapshots.

- Prefer `assert_eq` or `assert_true(pattern is Pattern(...))` for results that
  are stable or very unlikely to change. For snapshot tests that record
  structured debugging output, derive `Debug` and use `debug_inspect`, rather
  than deriving `Show` for debugging. For solid, well-defined results (e.g.
  scientific computations), prefer assertion tests. You can use
  `moon coverage analyze > uncovered.log` to see which parts of your code are
  not covered by tests.
