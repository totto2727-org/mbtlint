# mbtlint

`lint.mbtx` is the configuration and the entry point for this MoonBit source linter.
There is no `mbtlint` executable, config loader, JavaScript runtime dependency, or model call.
`@core.engine(config)` returns an Admiral `CliApp`.

| Import | What it provides |
| --- | --- |
| [`totto2727/mbtlint/core`](core/) | Configuration, rule authoring, the lint and fix engine, and the Admiral adapter |
| [`totto2727/mbtlint/rule`](rule/) | Individual built-in rule constructors, such as `@rule.no_mut()`, with one source file per rule ID |
| [`totto2727/mbtlint/preset`](preset/) | Recommended defaults and optional packs, with one source file per pack |

In a standalone script, put the module version before the package suffix, as in `"totto2727/mbtlint@0.1.0/core"`.

## Run the example

Run `nix develop` to enter the pinned environment, or use Moon `0.1.20261119`.
Pushes to main publish `totto2727/mbtlint` on Mooncakes.
Use the isolated fixture below to try an unreleased checkout.
This Moon version resolves standalone script imports through the registry, not through a neighboring `moon.work`.
Prepare the fixture from the repository root:

```sh
script_home=$(moon run --target native test/test_script.mbtx -- prepare-home)
MOON_HOME="$script_home" moon run lint.mbtx -- --help
MOON_HOME="$script_home" moon run lint.mbtx -- core/engine.mbt rule/no_mut.mbt
```

The preparation step packages the checkout and stages its resolved dependencies in a temporary Moon home.
It does not publish a package, install a launcher, or modify registry entries in your regular Moon home.
Prepare a fresh home after changing the library, and remove the temporary home when you no longer need it.
Once the script import is available from the registry you use, the ordinary invocation is `moon run lint.mbtx -- file.mbt`.

## Configure rules

The [example script](lint.mbtx) implements a project-specific `println` warning and sets the process exit status.
The library provides 31 distinct built-in rules, of which 17 are enabled in the recommended preset.
The core of a minimal script is:

```moonbit nocheck
///|
async fn main {
  let config = @preset.recommended()
  let app = @core.engine(config)
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
| `@preset.with_conventions(config)` | [MoonBit project conventions](docs/conventions.md), including public documentation, labelled parameters and error propagation. |
| `@preset.with_simplifications(config)` | [Boolean and control-flow simplifications](docs/simplifications.md). |
| `@preset.with_static_contracts(config)` | [Syntax-only subsets of Jev rules](docs/static-contracts.md). These do not claim to understand natural-language intent. |

`no-mut` reports `let mut`, mutable record fields, and mutable enum constructor fields.
It does not infer immutability through aliases or prohibit all calls to mutating methods.
Start with `@core.Config()` for an empty rule list, or use `without_rule("no-mut")` to remove a rule from a preset.
Use `@core.Config().with_rule(@rule.no_mut(), severity=Error)` to enable just the mutation check.
`with_rule(rule, severity=Warning)` replaces the previous registration of that ID without mutating the original configuration.

## Write a native rule

Create a rule with `@core.Rule` and return a fresh `@core.Listener` for each file.
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

Run `moon test` for parser-backed tests and `moon fmt --check` for library formatting.
Run `moon run --target native test/test_script.mbtx` from the repository root to exercise the actual `moon run lint.mbtx` entry point in a separate project.
Run `moon run --target native test/test_script.mbtx -- measure-cache` to compare disabled, empty, and populated caches on identical input and diagnostics.
See [performance](docs/performance.md) for the benchmark commands and measurement scope.
See [AGENTS.md](AGENTS.md) for development and CI commands.

## License

[MIT](LICENSE).
