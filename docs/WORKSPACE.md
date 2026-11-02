# Workspace development and publishing

The repository uses `moon.work` to develop five independently publishable
modules together. Module and package names intentionally preserve the existing
import paths; no compatibility packages or chains of re-exports are needed.

| Directory | Module | Module dependencies |
| --- | --- | --- |
| `core/` | `Betterlol/moon_zod/core` | `moonbitlang/regexp` |
| `async/` | `Betterlol/moon_zod/async` | core, `moonbitlang/async` |
| `exporters/` | `Betterlol/moon_zod/exporters` | core |
| `importers/` | `Betterlol/moon_zod/importers` | core |
| `moon_zod/` | `Betterlol/moon_zod` | core, exporters, importers |

The main module owns the public facade, `moon_zod/combinators/`, CLI tools,
examples, and integration tests. It does not depend on async or its runtime.
The async module depends only on core and `moonbitlang/async`, and owns its
benchmark at `async/benchmarks/`. Core has no dependency on the facade, IO,
importers, or exporters. Combinators remain a small composition layer in the
main module.

## Dependencies and imports

Declare the module in `moon.mod` and the package in `moon.pkg`. For example, a
consumer that needs only synchronous validation can use:

```moonbit
// moon.mod
import {
  "Betterlol/moon_zod/core@0.10.0",
}
```

```moonbit
// moon.pkg
import {
  "Betterlol/moon_zod/core" @core,
}
```

Consumers that need the unified API continue to depend on `Betterlol/moon_zod`
and use `@moon_zod`. After publishing this split, consumers importing the old
subpackages directly must also declare their owning modules in `moon.mod`.
Package import paths and the `Schema` type identity are unchanged.

Async consumers declare `Betterlol/moon_zod/async` as a separate module
dependency. They can import it alongside core without installing the facade,
importers, or exporters. See the [async guide](../async/README.mbt.md).

Inside this workspace, dependencies on member modules resolve to local source.
Outside it, dependencies resolve to published Mooncakes versions. The versions
shown here describe the workspace manifests; new modules must be published
before an external consumer can install them.

## Development

Run these commands from the repository root:

```sh
moon check --deny-warn
moon test
moon check async --target native --deny-warn
moon test async --target native
moon info
moon fmt
```

Use a path to select a member package, such as `moon test core`. Workspace-wide
commands check all members, including the shared integration tests in `moon_zod/tests/`.
Those tests reference `@core`, `@exporters`, `@importers`, and `@combinators`
directly. They do not maintain a second public API in a test re-export file.
`moon_zod/api_test.mbt` checks the unified facade from a consumer's perspective.
Only `moon_zod/reexporter.mbt` maintains the unified public API.

Package import paths are unchanged. CLI and example paths are now relative to
their member directory: from the repository root, use
`moon run moon_zod/cmd/validate` or `moon run moon_zod/examples/mock/llm_agent`.
Alternatively, run `moon -C moon_zod run cmd/validate`.

The `moon_zod_lab` submodule is an external consumer and is not a workspace
member. Its Git revision and manifests are managed separately.

## Release checks

Each member has its own `moon.mod`. Bump a module's version when releasing it,
then run `moon work sync` to align local member dependency declarations. Review
the resulting manifests; workspace source resolution alone does not prove that
the declared published versions are compatible.

Preview archives before publishing:

```sh
moon -C core package --list
moon -C async package --list
moon -C exporters package --list
moon -C importers package --list
moon -C moon_zod package --list
python .github/scripts/check_workspace_archives.py
```

Each archive contains only its member directory's implementation, manifest,
README, and license. Sibling modules and the repository's `moon.work` are
outside its archive root. The main archive depends on the other modules rather
than shipping duplicate implementations.

Publish changed modules in dependency order: core, then async/importers/exporters,
then the main module. Run `moon publish` from each module directory. Publishing
is a separate release action; workspace migration does not publish anything.

After the dependency versions are available on Mooncakes, validate a fresh
consumer with workspace resolution disabled:

```sh
MOON_WORK=off moon check --deny-warn
MOON_WORK=off moon test
```

In PowerShell, set `$env:MOON_WORK = "off"` before these checks and remove it
afterwards with `Remove-Item Env:MOON_WORK`. Use an extracted archive or a clean
checkout so local member source cannot conceal missing release files.
