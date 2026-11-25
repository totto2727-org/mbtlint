"""Measure cache effects through the user's real `moon run lint.mbtx` entry point."""

import os
from pathlib import Path
import shutil
from statistics import median
import subprocess
import tempfile
from time import perf_counter


ROOT = Path(__file__).resolve().parents[1]


def main():
    home = subprocess.check_output(
        ["sh", "test/prepare-script-home.sh"], cwd=ROOT, text=True
    ).strip()
    try:
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temp:
            project = Path(temp)
            shutil.copyfile(ROOT / "lint.mbtx", project / "lint.mbtx")
            files = sorted(str(p.relative_to(ROOT)) for pkg in ("core", "rule", "preset")
                           for p in (ROOT / pkg).glob("*.mbt"))
            for name in files:
                (project / name).parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / name, project / name)
            times = {kind: [] for kind in ["uncached", "cold", "warm"]}
            reference = None

            def measure(kind, cache):
                nonlocal reference
                args = ["moon", "run", "lint.mbtx", "--"]
                if kind == "uncached":
                    args.append("--no-cache")
                start = perf_counter()
                result = subprocess.run(
                    args + files, capture_output=True, cwd=project,
                    env={**os.environ, "MOON_HOME": home, "XDG_CACHE_HOME": str(cache)},
                )
                elapsed = perf_counter() - start
                if result.returncode != 1 or b"[no-mut]" not in result.stdout:
                    raise RuntimeError(result.stderr.decode() + result.stdout.decode())
                if reference is None:
                    reference = result.stdout
                elif reference != result.stdout:
                    raise RuntimeError(f"{kind} changed the diagnostics")
                return elapsed * 1000

            populated = project / "warm-cache"
            measure("cold", populated)  # Compile the script and prepopulate the warm cache.
            before = {p: p.stat().st_mtime_ns for p in (populated / "mbtlint").iterdir()}
            if len(before) != len(files):
                raise RuntimeError("Expected one cache entry per input file")
            kinds = list(times)
            for i in range(9):
                for kind in kinds[i % 3:] + kinds[:i % 3]:
                    cache = populated if kind == "warm" else project / f"{kind}-{i}"
                    times[kind].append(measure(kind, cache))
                    if kind == "uncached" and cache.exists():
                        raise RuntimeError("--no-cache wrote a cache")
            if before != {p: p.stat().st_mtime_ns for p in (populated / "mbtlint").iterdir()}:
                raise RuntimeError("Warm run replaced an entry")
            print(f"{len(files)} files, {sum((project / p).stat().st_size for p in files)} bytes, "
                  f"{len(reference.splitlines())} diagnostic lines, 9 samples per mode")
            for kind, samples in times.items():
                print(f"{kind}: median {median(samples):.1f} ms (range {min(samples):.1f}..{max(samples):.1f})")
    finally:
        shutil.rmtree(home)  # The fixture returns a new, caller-owned temporary Moon home.


if __name__ == "__main__":
    main()
