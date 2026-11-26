# mbtlint development

## Repository structure

| Path | Purpose |
| --- | --- |
| `moon.mod` | Module metadata for the three importable packages |
| `core/` | Config, listener and rule types, parser traversal, fixes, cache, and the Admiral adapter |
| `rule/` | Built-in rule constructors, one file per rule ID |
| `preset/` | Recommended defaults and optional rule packs, one file per pack |
| `lint.mbtx` | Example consumer configuration and standalone entry point, not an installed executable |
| `<package>/*_test.mbt`, `test/` | Library tests, standalone script fixture, and cache measurements |
| `README.mbt.md`, `docs/` | Consumer documentation and rule reference |
| `flake.nix`, `.github/workflows/ci.yml` | Pinned development shell and validation |

## Development

Run commands from the repository root in `nix develop` or `nix develop .#ci`.
Read the `mbt-coding` skill before editing production code and `mbt-test` before editing MoonBit tests.
Keep `README.md` as a relative symlink to `README.mbt.md`.

| Command | Purpose |
| --- | --- |
| `moon update` | Update the local Mooncakes registry index |
| `moon fmt --check` | Check library formatting |
| `moon fmt --check README.mbt.md lint.mbtx test/test_script.mbtx` | Check the README and standalone scripts |
| `moon check --deny-warn` | Type-check the library and fail on warnings |
| `moon build` | Build the library |
| `moon test` | Run the parser-backed library tests |
| `moon run --target native test/test_script.mbtx` | Exercise `moon run lint.mbtx` through an isolated registry fixture |
| `moon info` | Regenerate the tracked package interfaces after public API changes |
| `moon package --list` | Review which files the package contains without publishing |

## Package boundaries

Keep imports in this direction: `preset` depends on `rule` and `core`, and `rule` depends on `core`.
Do not add a root package that re-exports these packages.
Keep `core` lint and fix operations in memory without filesystem or process access.
Put argument handling and optional cache I/O at the Admiral boundary inside `core`.
When changing edits or cache behavior, preserve the invariants documented in [the README](README.mbt.md#lint-fix-and-cache) and [the cache guide](docs/cache.md).
Use the isolated script fixture for local registry resolution rather than publishing the package or changing the normal registry entry for `mbtlint`.

## CI and publication

Keep validation on pull requests and pushes to `main`.
Change inherited workflows only for an explicit request or a demonstrated project requirement.
Keep shared validation actions on `@main`.
Keep the Mooncakes publish workflow enabled on pushes to `main`.
The release artifact is `totto2727/mbtlint`, not a CLI executable.
The shared publishing action uses the `MOONCAKES_TOKEN` GitHub Actions secret and skips versions already on Mooncakes.
Review `moon publish --dry-run` before merging a new module version.
Use Moon for project tests and test scripts; do not introduce another runner.
