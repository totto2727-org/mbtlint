# Safety rules

Enable all four rules with `config.with_safety()`.
Each rule defaults to error severity.
To opt in to a single rule or set its severity, pass its constructor to `config.with_rule(...)`.

The pack skips test declarations named `panic` or whose names start with `panic ` or `panic_` because these tests are expected to panic.
The exemption does not extend to a separate helper called from such a test.
These rules inspect syntax, not types, imports, control flow, or runtime behavior.

## `no-panic`

Constructor: `no_panic()`.

Reports explicit `abort` and `panic` calls, including `@builtin` and `@prelude` spellings, legacy `@abort.abort`, and a call such as `"invalid input" |> abort`.
Return or raise a recoverable error when callers can handle the failure.
The rule ignores bare references, unrelated package qualifiers, member methods, and unqualified calls shadowed by a top-level function or value in the same file.
It does not resolve local shadowing, renamed imports, or calls through function aliases.

## `no-unsafe-unwrap`

Constructor: `no_unsafe_unwrap()`.

Reports unchecked `Option` or `Result` unwraps such as `value.unwrap()`, `Result::unwrap_err(result)`, and `value |> Option::unwrap`.
Use pattern matching or an explicit fallback such as `value.unwrap_or(default_value)`.
The rule recognizes `unwrap()` and `unwrap_err()` member calls by name, so a custom type with the same zero-argument method can be reported.
Explicit type calls are checked only for the known `Option` and `Result` owners.

## `no-try-bang`

Constructor: `no_try_bang()`.

Reports `try! read_file(path)`, which converts a raised error into a panic.
Handle the failure with `try ... catch`, or let a caller handle a propagated error.
The rule checks the operator even if the expression cannot raise at runtime.

## `no-unsafe-operations`

Constructor: `no_unsafe_operations()`.

Reports calls to known unchecked core methods such as `items.unsafe_get(index)`, `@builtin.Array::unsafe_set(items, index, value)`, or `list |> @list.List::unsafe_tail`.
The rule covers selected unchecked indexing, writes, copying, views, range comparisons, list access, and regex construction methods from the core library.
Prefer an API that checks its preconditions, such as `items.get(index)`.
The rule does not match arbitrary `unsafe_` prefixes, custom package aliases, or operations invoked through a stored function value.
Member calls to a method with the same name as a known core operation can be reported on custom types.
