# Collection rules

`@preset.with_collections(@core.Config())` enables these rules as warnings.
Each rule is also available as an individual constructor, such as `@rule.prefer_collection_map()`.
The rules report at the loop and do not change source code.

## Rule reference

The examples use `xs : Array[Int]` and omit the enclosing function.
In the construction and fold examples, the final line is the block result.

| Rule ID | Reported pattern | Consider |
| --- | --- | --- |
| `prefer-collection-map` | `let out = []; for x in xs { out.push(x * 2) }; out` | `xs.map(x => x * 2)` |
| `prefer-collection-filter` | `let out = []; for x in xs { if x > 0 { out.push(x) } }; out` | `xs.filter(x => x > 0)` |
| `prefer-collection-filter` | `let out = []; for x in xs { if x > 0 { out.push(x * 2) } }; out` | `xs.filter_map(x => if x > 0 { Some(x * 2) } else { None })` |
| `prefer-collection-transfer` | `let out = []; for x in xs { out.push(x) }; out` | `xs.copy()` for an array, or `to_array()` on an iterator |
| `prefer-collection-any` | `for x in xs { if x > 0 { break true } } nobreak { false }` | `xs.any(x => x > 0)` |
| `prefer-collection-all` | `for x in xs { if x <= 0 { break false } } nobreak { true }` | `xs.all(x => !(x <= 0))` |
| `prefer-collection-find` | `for x in xs { if x > 0 { break Some(x) } } nobreak { None }` | `xs.iter().find_first(x => x > 0)` |
| `prefer-collection-fold` | `let mut sum = 0; for x in xs { sum += x }; sum` | `xs.fold(init=0, (sum, x) => sum + x)` |
| `prefer-collection-fold` | `for x in xs; sum = 0 { continue sum + x } nobreak { sum }` | `xs.fold(init=0, (sum, x) => sum + x)` |

## What the rules leave alone

The construction rules require a fresh empty array immediately before the loop, one direct `push` action, and the array as the block result immediately after the loop.
They skip prefilled or caller-provided arrays, extra statements, and expressions that refer to the output array.
The transfer rule detects unmodified items only.
Returning an input array directly is not equivalent to returning a new array when either can be mutated.

The search rules require a single conditional `break` and a matching `nobreak` value.
They skip `return`, additional exits, and searches that return a transformed item.
The fold rule requires one unconditionally updated accumulator that is returned unchanged as the block or loop result.
It skips multiple accumulators, conditional updates, and an assignment that ignores the previous value.

The rules accept a single named item binding, with no labels or `where` clauses.
They check collection names, array or iterator literals, and direct `.iter()` calls on those forms, but not ranges or arbitrary source expressions.
They do not flag general effectful traversal or stateful algorithms.

The parser does not resolve types, callbacks, effects, or custom methods.
Before replacing a loop, check that the collection and callback support the proposed operation, that evaluation and iteration order stay the same, and that short-circuiting or ownership does not change.
For an iterator result that must be materialized as an array, use an appropriate terminal operation such as `to_array()`.
