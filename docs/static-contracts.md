# Static contracts

Enable these checks with `@mbtlint.Config().with_static_contracts()`.
The pack is opt-in and registers all three rules at error severity without automatic fixes.
Use `with_rule` with the corresponding constructor to enable rules individually or override their severity.

| Rule ID | Constructor | What it reports |
| --- | --- | --- |
| `catch-hides-failure` | `catch_hides_failure()` | An unguarded `_` catch arm that substitutes a string, integer, empty array, or unit literal, optionally with `return`. The surrounding function must explicitly return `String`, `Int`, `Int64`, `UInt`, `UInt64`, `Unit`, or `Array[...]`. |
| `safe-name-is-safe` | `safe_name_is_safe()` | A direct call to core `abort` or `panic` in a function named `safe`, `try`, `safe_*`, `try_*`, or ending in `_or_default`, `_or_none`, or `_or_else`. |
| `pure-name-is-pure` | `pure_name_is_pure()` | A direct call to core `println`, or a field assignment rooted at a named parameter, in a function named `compute`, `calculate`, `derive`, `format`, `to`, `parse`, or starting with one of those words followed by `_`. |

For methods declared as `Type::method`, the rules match the method name, not the type name.
The catch rule skips the names `safe`, `try`, `maybe`, their underscore prefixes, and names ending in `_or_null`, `_or_default`, `_or_else`, `_or_none`, or `_or`.
It also skips Boolean, optional, and `Result` return types because they can deliberately represent failure as a value.
The catch rule cannot decide whether a literal fallback is appropriate, for example during best-effort cleanup.

The call checks recognize bare names and the `@builtin` and `@prelude` spellings.
Bare calls are skipped if the same file declares or imports that name, or any parameter or local binder in the function has that name.
Similarly, the field check skips a parameter name that is rebound elsewhere in the function.
The engine only parses the current file, so it cannot resolve a bare name against definitions in another file of the same package.

These checks examine function bodies but do not follow calls into helpers, inspect local function or closure bodies, or prove that an expression is reachable.
They do not check indirect I/O, mutation through aliases or collection methods, unchecked indexing or division, or loop termination.
Absence of a diagnostic does not establish safe execution, purity, or correct error handling.

## Provenance

The rule IDs and conventions come from Jev Lint's MoonBit [rule definitions and fixtures](https://github.com/mizchi/jev-lint/tree/346e5346250f64b31f91527851e55b6777078457/rules/moonbit) at commit `346e5346250f64b31f91527851e55b6777078457`.
The `catch-hides-failure` fixture contrasts an empty-string fallback with an optional return or a re-raise.
The `safe-name-is-safe` fixtures include an `abort` call, unchecked arithmetic, and a loop that can fail to advance.
The `pure-name-is-pure` fixtures distinguish direct output and parameter field writes from local accumulation.
These parser checks implement only the explicit patterns above, not the semantic model's criteria, judgments, or fixture coverage.
