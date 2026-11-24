# MoonBit conventions

Use `Config().with_conventions()` to enable the six rules on this page.
Each rule has a public constructor, so you can also enable it with `with_rule` or remove it from the pack with `without_rule`.
The rules report diagnostics and do not rewrite code.
They inspect the MoonBit parser's syntax tree without type checking or resolving package aliases.

## `require-public-docs`

Constructor: `require_public_docs()`.

Add a nonblank `///` comment to a public function, method, type, trait, or value declaration.
A standalone `///|` separator does not count as documentation.

```mbt
///|
/// Return the number of active connections.
pub fn Session::active_count(self : Session) -> Int {
  self.active.length()
}
```

This rule checks only the presence of attached text.
It does not evaluate the text or check individual fields, variants, or trait methods.
See [historical MoonBit style][style].

## `prefer-labelled-parameters`

Constructor: `prefer_labelled_parameters()`.

Label every caller-supplied parameter when a function takes four or more.
For a method, keep the receiver positional and exclude it from the count.
Both required and optional labels count toward the threshold.

```mbt
pub fn Rect::Rect(x~ : Int, y~ : Int, width~ : Int, height~ : Int) -> Rect {
  { x, y, width, height }
}
```

The rule checks top-level functions with MoonBit bodies, including type-associated functions.
It skips trait implementations, foreign stubs, local functions, and anonymous functions.
For a non-constructor, it recognizes the receiver when the first positional parameter is annotated with the same unqualified type name as the owner.
It does not resolve type aliases.
See [historical MoonBit style][style] and [constructor guidance][constructors].

## `prefer-arrow-callback`

Constructor: `prefer_arrow_callback()`.

Prefer `items.map(item => item.name)` to `items.map(fn(item) { item.name })`.
The rule checks function and method call arguments that are direct `fn` expressions with no explicit parameter types, return type, or effects.
It leaves named local functions, functions assigned to variables, and anonymous functions with explicit signatures alone.
See [historical MoonBit style][style].

## `no-manual-path-join`

Constructor: `no_manual_path_join()`.

Use a path API to join components before passing the resulting path to a filesystem operation.
For example, replace `@fs.read_file_to_string(parent + "/" + child)` with `@fs.read_file_to_string(join_path(parent, child))`, where `join_path` is your project's path API.

The rule checks a slash or escaped backslash literal between operands of `+` in the first positional argument of known `moonbitlang/x/fs` functions spelled `@fs`.
It does not check interpolations, separate bindings, custom wrappers, aliases other than `@fs`, or URI operations.
It cannot tell if `@fs` names a custom package.
See [historical path form invariants][paths] for choosing a typed internal path representation.

## `require-named-tests`

Constructor: `require_named_tests()`.

Give each test a nonblank name, such as `test "Widget create - with distinct inputs" { ... }` instead of `test { ... }`.
The rule checks for missing names, empty names, and names containing only unescaped whitespace.
It does not enforce the recommended title pattern or infer that a test expects a panic.
See [historical test naming guidance][names] for scenario descriptions, case IDs, and `panic_` titles.

## `no-redundant-rethrow`

Constructor: `no_redundant_rethrow()`.

Instead of `try { load() } catch { err => raise err }`, call `load()` directly in a function whose signature permits its error to propagate.
The rule checks a single unguarded catch arm that raises its simple bound error unchanged.
It skips catches with other arms, recovery, translation, other work such as logging, or a `noraise` branch.
It does not infer error types or prescribe when `Result` is the right API contract.
See [historical error guidance][errors] and [failure policy][failures].

[style]: https://github.com/totto2727-org/agent/blob/bc358bf0ca57a3d32077f3dc9373d69999ca021e/plugins/totto2727-mbt/skills/mbt-coding/references/style.md
[constructors]: https://github.com/totto2727-org/agent/blob/bc358bf0ca57a3d32077f3dc9373d69999ca021e/plugins/totto2727-mbt/skills/mbt-coding/references/constructors.md
[paths]: https://github.com/totto2727-org/agent/blob/bc358bf0ca57a3d32077f3dc9373d69999ca021e/plugins/totto2727-principle/skills/share-coding/references/domain-models.md#path-form-invariants
[names]: https://github.com/totto2727-org/agent/blob/bc358bf0ca57a3d32077f3dc9373d69999ca021e/plugins/totto2727-mbt/skills/mbt-test/references/names.md
[errors]: https://github.com/totto2727-org/agent/blob/bc358bf0ca57a3d32077f3dc9373d69999ca021e/plugins/totto2727-mbt/skills/mbt-coding/references/errors.md
[failures]: https://github.com/totto2727-org/agent/blob/bc358bf0ca57a3d32077f3dc9373d69999ca021e/plugins/totto2727-principle/skills/share-coding/references/domain-models.md#failures
