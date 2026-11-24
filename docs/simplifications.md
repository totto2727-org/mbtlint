# Simplification rules

Use `Config().with_simplifications()` to enable this group, or register a single rule with `Config::with_rule`.
These rules use the MoonBit parser AST, not type checking or constant evaluation.

| Rule ID | Constructor | Reports | Fix |
| --- | --- | --- | --- |
| `simplify-bool-if` | `simplify_bool_if()` | An `if` with a nonliteral test and two opposite Boolean literal branches. | Uses the test or its negation. |
| `simplify-bool-match` | `simplify_bool_match()` | A two-arm `match` on explicit `true` and `false` patterns that returns opposite Boolean literals. | Uses the scrutinee or its negation. |
| `redundant-bool-pattern` | `redundant_bool_pattern()` | A Boolean literal after `is`. | Uses the tested expression or its negation. |
| `constant-condition` | `constant_condition()` | A literal condition in `if`, `guard`, or a C-style `for`, and `while false`. | None. |
| `redundant-bool-operand` | `redundant_bool_operand()` | `true` on either side of `&&` or `false` on either side of `||`, when the other operand is not a literal. | None. |
| `no-self-assignment` | `no_self_assignment()` | A plain assignment of an unqualified variable to itself. | None. |

The first three rules preserve the original operand exactly once and enforce its Boolean type through a type annotation or built-in `!`.
They add parentheses to preserve surrounding precedence.
They report without editing when the source range contains comment or multiline literal markers.
The `if` rule also withholds the fix for an `else if` or a sole nested `if` inside a braced `else` arm, since the parser can give them the same shape.
Guarded match arms and patterns that bind names are not simplified.
`while true` can be an intentional infinite loop, so `constant-condition` does not report it.
`no-self-assignment` does not inspect field writes, indexing, or augmented assignments.
