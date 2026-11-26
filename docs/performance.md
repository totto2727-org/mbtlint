# Lint performance

The engine skips the expression walk if no rule registers an expression callback.
When both callback kinds are present, it still calls declaration listeners before visiting each declaration's expressions and keeps registration order within each kind.
The collection builders and search rules now check the operation shape before recursively validating its source and callbacks.
On the seven matching build and search examples in the benchmark fixture, this reduces source validation from 21 to 7 top-level calls and callback validation from 27 to 9 top-level calls when the pack is enabled.
Those are control-flow counts for the matching examples, not timings.

## Run the benchmark

Use the same MoonBit toolchain on both sides.
The runner stages a private copy of each module, builds with `--target native --release`, and keeps the benchmark executable out of the published module.
Both modules must expose the same `core`, `rule`, and `preset` packages.
For example, compare the committed version with an uncommitted local optimization from the repository root:

```bash
mkdir -p tmp
base=$(mktemp -d "$PWD/tmp/mbtlint-perf-base.XXXXXX")
git archive HEAD | tar -x -C "$base"
if [ -d .mooncakes ]; then ln -s "$PWD/.mooncakes" "$base/.mooncakes"; fi
REPS=5 ROUNDS=16 TOOL_COPIES=16 \
  moon run --target native bench/compare.mbtx -- "$base" "$PWD" "$PWD/tmp/mbtlint-perf-results"
```

The results directory must not already exist.
The inputs are the baseline's `.mbt` files in the three packages, `lint.mbtx`, and a fixture that triggers each builtin at least once.
`core` cohorts read the sources once per sample and then call `Config::lint` repeatedly, including parsing on every pass.
They include parse-only, declaration-only, recommended, collection, all-rule, and each of the 31 builtin configurations in isolation.
`tool` launches the actual Admiral app with all builtins set to warnings and `--no-cache`, including argument handling, file reads, UTF-8 decoding, lint and diagnostic rendering.
`TOOL_COPIES` repeats the list of paths in one invocation, so it measures uncached linting on a warm filesystem rather than cold storage.

The script alternates baseline and candidate processes and writes wall, user and system seconds from the system `time -p` command to `samples.tsv`.
Use `nix develop` to make that executable available on `PATH`.
If the timing resolution is too low for the samples, increase `ROUNDS` and `TOOL_COPIES`.
It fails on process errors, parse diagnostics, missing per-rule findings, or a mismatch in output.
It compares the ordered findings, messages, ranges, and fix edits from one pass per core sample, as well as finding counts across all repeats.
It also checks that the tool's output equals one full diagnostic listing for every repetition of its path list.

## Observed results

**No measurable end-to-end speedup on this workload.**
These historical results predate the package split and used the same rules and a flat source layout.
The run used MoonBit v0.10.22, an Apple M1 Pro on macOS arm64, and five alternating samples per side across 37 cohorts.
The corpus contained 24 files and 99,764 bytes, with 384 file passes per sample.
All 370 invocations succeeded and produced matching output across both sides and all replicates.
The tool emitted 1,168 findings per invocation; the all-rule core cohort counted the same number.

Wall time in milliseconds, median (min to max):

| Cohort | Baseline | Candidate |
| --- | ---: | ---: |
| Parse only | 174 (165 to 234) | 172 (168 to 173) |
| Declaration only | 172 (170 to 178) | 176 (171 to 199) |
| Recommended | 179 (178 to 181) | 177 (175 to 183) |
| Collection pack | 173 (171 to 173) | 171 (169 to 173) |
| All builtins | 185 (183 to 187) | 184 (180 to 185) |
| Admiral, no cache | 201 (195 to 207) | 203 (199 to 215) |

The isolated collection-rule medians moved by 0 to 4 ms, and every baseline and candidate range overlapped.
These samples include parsing, so subtracting the parse-only median does not estimate a callback's cost reliably.
A separate macOS `sample` profile of the baseline showed lexer and parser stacks dominating, with the old AST walk visible in the declaration-only profile and `collection_build`, `collection_search` and `collection_callback` visible in the fixture-only collection profile.
The tool cohort also spent approximately 15 ms per invocation in system CPU time, compared with 3 to 4 ms in the core cohorts.
The shared machine was busy (load average 22.79 before profiling and 37.49 while the run was under way on 10 logical cores), and the ranges overlap.
These results do not measure standalone `.mbtx` startup or compilation, cache hits, autofix application, network rules, or the Wasm backend's performance.
