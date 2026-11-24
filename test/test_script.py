"""Black-box checks for the example configuration, not a lint launcher."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class ScriptTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.home = subprocess.check_output(
            ["sh", "test/prepare-script-home.sh"], cwd=ROOT, text=True
        ).strip()
        cls.addClassCleanup(shutil.rmtree, cls.home)
        cls.temp = tempfile.TemporaryDirectory(dir=ROOT / "tmp")
        cls.addClassCleanup(cls.temp.cleanup)
        cls.project = Path(cls.temp.name)
        shutil.copyfile(ROOT / "lint.mbtx", cls.project / "lint.mbtx")

    def lint(self, *args, expected=0):
        result = subprocess.run(
            ["moon", "run", "lint.mbtx", "--", *args],
            cwd=self.project,
            env={**os.environ, "MOON_HOME": self.home,
                 "XDG_CACHE_HOME": str(self.project / "cache")},
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result.stdout

    def test_admiral_interface(self):
        help_text = self.lint("--help")
        self.assertIn("--fix", help_text)
        self.assertIn("--no-cache", help_text)
        self.lint("missing.mbt", expected=2)
        self.lint(expected=2)

    def test_cached_findings_and_changed_source(self):
        path = self.project / "source.mbt"
        path.write_text('fn demo() { let mut value = 1; println(value) }\n')
        cold = self.lint(path.name, expected=1)
        self.assertIn("error [no-mut]", cold)
        self.assertIn("warning [project/no-println]", cold)
        cache = self.project / "cache" / "mbtlint"
        slots = {f: f.stat().st_mtime_ns for f in cache.iterdir() if f.is_file()}
        self.assertTrue(slots)
        self.assertEqual(self.lint(path.name, expected=1), cold)
        self.assertEqual({f: f.stat().st_mtime_ns for f in slots}, slots)
        path.write_text('fn demo() { println(1) }\n')
        self.assertNotIn("no-mut", self.lint(path.name))

    def test_fix_is_explicit_and_preserves_unicode_and_line_endings(self):
        path = self.project / "fix.mbtx"
        original = '\ufeff---\r\n// 🌙\r\n---\r\nfn f(x : Int) { check(x=x) }\r\n'.encode()
        path.write_bytes(original)
        self.assertIn("warning [prefer-label-pun]", self.lint(path.name))
        self.assertEqual(path.read_bytes(), original)
        self.assertEqual(self.lint("--fix", path.name), "")
        self.assertEqual(path.read_bytes(), original.replace(b"x=x", b"x~"))
        self.assertEqual(self.lint("--fix", path.name), "")

    def test_malformed_inputs_are_never_rewritten(self):
        path = self.project / "invalid.mbt"
        for content, code in [(b"fn f() {", 1), (b"//\xff\nlet x = 1", 2)]:
            path.write_bytes(content)
            self.lint("--fix", path.name, expected=code)
            self.assertEqual(path.read_bytes(), content)
