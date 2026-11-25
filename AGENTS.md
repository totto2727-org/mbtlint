# mbtlint development

## Repository structure

| Path | Purpose |
| --- | --- |
| `moon.mod`, `moon.pkg` | MoonBit library metadata and root package configuration |
| `engine.mbt`, `rule.mbt`, `fix.mbt` | Parser-backed rule traversal and in-memory lint and fix operations |
| `admiral.mbt`, `cache.mbt` | Script integration, argument handling, and cache I/O |
| `lint.mbtx` | Example consumer configuration and standalone entry point, not an installed executable |
| `*_test.mbt`, `test/` | Library tests, standalone script fixture, and cache measurements |
| `README.mbt.md`, `docs/` | Consumer documentation and rule reference |
| `flake.nix`, `.github/workflows/ci.yml` | Pinned development shell and validation |

## Development

Run commands from the repository root in `nix develop` or `nix develop .#ci`.
Read the `mbt-coding` skill before editing production code and `mbt-test` before editing MoonBit tests.
Keep `README.md` as a relative symlink to `README.mbt.md`.

| Command | Purpose |
| --- | --- |
| `moon update` | Update the local Mooncakes registry index |
| `moon fmt --check . lint.mbtx` | Check formatting of the library and standalone script |
| `moon check --deny-warn` | Type-check the library and fail on warnings |
| `moon build` | Build the library |
| `moon test` | Run the parser-backed library tests |
| `python3 -B -m unittest discover -s test -v` | Exercise `moon run lint.mbtx` through an isolated registry fixture |
| `moon info` | Regenerate the tracked package interface after public API changes |
| `moon package --list` | Review which files the package contains without publishing |

## Package boundaries

Keep the lint and fix engine in memory without filesystem or process access.
Put argument handling and optional cache I/O at the Admiral boundary.
When changing edits or cache behavior, preserve the invariants documented in [the README](README.mbt.md#lint-fix-and-cache) and [the cache guide](docs/cache.md).
Use the isolated script fixture for local registry resolution rather than publishing the package or changing the normal registry entry for `mbtlint`.

## CI and publication

Keep validation on pull requests and pushes to `main`.
Change inherited workflows only for an explicit request or a demonstrated project requirement.
Keep shared validation actions on `@main`.
Do not enable Mooncakes or FlakeHub publication without explicit approval.
If publication is later authorized, keep the template's main-push policy rather than replacing it with tag or release triggers.
