# mbtlint

`lint.mbtx` is the configuration and the entry point for this MoonBit source linter.
There is no `mbtlint` executable, config loader, JavaScript runtime dependency, or model call.
[`engine(config)`](admiral.mbt) returns an Admiral `CliApp`.

## Run the example

Use Moon `0.1.20261119` or a compatible toolchain.
This checkout is not published on Mooncakes.
That Moon version resolves standalone script imports through the registry, not through a neighboring `moon.work`.
For local development, prepare an isolated registry fixture with `sh`, `jq`, and `shasum` from the repository root:

```sh
script_home=$(sh test/prepare-script-home.sh)
MOON_HOME="$script_home" moon run lint.mbtx -- --help
MOON_HOME="$script_home" moon run lint.mbtx -- rule.mbt recommended.mbt
```

The preparation step packages the checkout and stages only its resolved dependencies under `tmp/`.
It does not publish a package, install a launcher, or modify registry entries in your regular Moon home.
Prepare a fresh home after changing the library.
Once the script import is available from the registry you use, the ordinary invocation is `moon run lint.mbtx -- file.mbt`.

## Configure rules

The [example script](lint.mbtx) implements a project-specific `println` warning and sets the process exit status.
The library provides 31 distinct built-in rules, of which 17 are enabled in the recommended preset.
The core of a minimal script is:

```moonbit
async fn main {
  let config = @mbtlint.Config::recommended()
  let app = @mbtlint.engine(config)
  app.run()
}
```

`app.run(argv=Some(["a.mbt", "b.mbtx"]))` uses explicit arguments instead of the process arguments.
Pass individual source files, or expand globs in your script or shell.
The example exits with `0` for clean or warning-only input, `1` for lint errors, or `2` for invalid invocations or I/O errors.

| Policy | What it checks |
| --- | --- |
| Recommended errors | [Panic, unsafe unwraps, unchecked operations, and `try!`](docs/safety.md), explicit `mut`, `...` placeholders, duplicate named tests in a file, and variable self-assignment. |
| Recommended warnings | [Recognizable map, filter, transfer, search, and fold loops](docs/collections.md), explicit same-name record fields and labelled arguments. Other `for` loops are allowed. |
| `with_conventions()` | [MoonBit project conventions](docs/conventions.md), including public documentation, labelled parameters and error propagation. |
| `with_simplifications()` | [Boolean and control-flow simplifications](docs/simplifications.md). |
| `with_static_contracts()` | [Syntax-only subsets of Jev rules](docs/static-contracts.md). These do not claim to understand natural-language intent. |

`no-mut` reports `let mut`, mutable record fields, and mutable enum constructor fields.
It does not infer immutability through aliases or prohibit all calls to mutating methods.
Start with `Config()` for an empty rule list, or use `without_rule("no-mut")` to remove a rule from a preset.
`with_rule(rule, severity=Warning)` replaces the previous registration of that ID without mutating the original configuration.

## Write a native rule

A rule creates a fresh listener per file.
`on_decl` sees top-level declarations before their children, and `on_expr` sees nested expressions in preorder.
Both receive official [`moonbitlang/parser/syntax`](https://github.com/moonbitlang/parser) nodes, not JSON or token approximations.
`ctx.program`, `ctx.source`, and `ctx.text(loc)` are available for checks that need the full AST or exact source spelling.
Call `(ctx.report)(loc, message)` to report a finding, or `(ctx.report_fix)(loc, message, replacement)` to offer one replacement.
The engine supplies the rule ID, source path, severity, and range.
Parse errors have `rule_id=None` and prevent the rule callbacks from running on a recovered tree.

## Lint, fix and cache

`config.lint(path~, source~)` returns structured diagnostics without filesystem access.
`config.fix(path~, source~)` performs one pass in memory and returns the new source, applied count, remaining diagnostics, and whether the batch was rejected.
Only `moon run lint.mbtx -- --fix file.mbt` requests a file rewrite.
Edits are ordered by starting offset, then by reporting order for ties.
Overlapping edits are skipped, and the entire file's edit batch is rejected if the result does not parse.
This is not a type check: rules must establish that their own fixes preserve meaning.
The built-in fixes preserve comments or decline to edit, and no panic or mutation diagnostic rewrites the program.

The Admiral adapter uses a [local lint cache](docs/cache.md) by default.
Use `--no-cache` for a fresh check.
A custom rule without a `revision` prevents reuse of that configuration's results.
Only supply a revision when the rule is deterministic, and change it when the callback or its captured inputs change.

## Verify the library

Run `moon test` for parser-backed tests and `moon fmt --check . lint.mbtx` for formatting.
Run `python3 -B -m unittest discover -s test -v` to exercise the actual `moon run lint.mbtx` entry point in a separate project.
Run `python3 -B test/measure_cache.py` to compare disabled, empty, and populated caches on identical input and diagnostics.
See [performance](docs/performance.md) for the benchmark commands and measurement scope.
