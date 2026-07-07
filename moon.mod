// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "Betterlol/moon_zod"

version = "0.7.5"

readme = "README.mbt.md"

repository = "https://github.com/Betterlol/moon_zod"

license = "Apache-2.0"

keywords = [ "json", "schema", "validation", "zod", "llm", "tool-calling" ]

description = "A runtime JSON schema validation library for MoonBit, inspired by Zod and Pydantic"

import {
  "moonbitlang/regexp@0.3.5",
}

options(
  exclude: [
    "branch_doc/",
    "doc/",
    "doc_utils/",
    "bench_cross_lang/",
    "moonbit_syntax_pitfalls.md",
    "AGENTS.md",
    "_build/",
    "target/",
    ".mooncakes/",
    ".moonagent/",
    ".claude/",
  ],
)
