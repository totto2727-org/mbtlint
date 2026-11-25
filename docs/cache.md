# Lint result cache

Admiral apps returned by `@core.engine(config)` cache diagnostics on disk by default.
Run `moon run lint.mbtx -- --no-cache file.mbt` to lint without reading or writing the cache.
`--fix` always bypasses the cache.
Calls to `Config::lint` and `Config::fix` do not use the disk cache.

The default directory uses the first absolute path configured through `XDG_CACHE_HOME`, `LOCALAPPDATA`, or `HOME`.
The resulting directories are `$XDG_CACHE_HOME/mbtlint`, `$LOCALAPPDATA/mbtlint`, and `$HOME/.cache/mbtlint`, respectively.
To override the location, build the app with `@core.engine(config, cache_dir="path/to/cache")`.
Use a directory controlled by the current user, not a directory writable by other users or untrusted projects.
Missing, unreadable, or corrupt cache entries never prevent linting.
You can remove the cache directory at any time.

A cache hit requires the same engine/parser revision, working directory, exact input path, source bytes, and ordered list of rule IDs, revisions, and severities.
The cache keeps one entry of up to 1 MiB per path and rule configuration, not one per source edit.
It stores diagnostics, including suggested edits, but does not store the source file or use cached edits to modify a file.

Custom rules created without `revision` run normally and disable caching for that configuration.
Supply `revision="1"` when registering a deterministic rule if you want it to participate in caching.
The revision must change when the rule's behavior or any setting that affects its output changes.
Leave the revision unset if a rule depends on changing external state that its revision does not identify, such as another file, environment variables, or a network service.
On a cache hit, rule callbacks do not run.

## Measured script invocation

`python3 -B test/measure_cache.py` times the entire `moon run lint.mbtx` process, not just hashing or a rule callback.
On macOS arm64 with Moon `0.1.20261119`, 22 project files (98,574 bytes) produced identical output and exit status across all three modes.
After one unmeasured compilation, nine samples per mode in rotating order gave these wall times:

| Mode | Median | Observed range |
| --- | ---: | ---: |
| Disabled (`--no-cache`) | 1,124 ms | 1,060 to 1,791 ms |
| Empty cache directory | 1,115 ms | 1,086 to 1,449 ms |
| Unchanged files, populated cache | 131 ms | 123 to 176 ms |

The benchmark also checks that the populated cache contains one entry per input and no warm run rewrites those entries.
These results include tool startup and diagnostic output on this corpus, not a speed guarantee for other projects or targets.
