"""Parent regression tests: publication preparation must fail closed."""
import json
import unittest
import test_release_version as base
from test_release_version import run_cli, write_pubspec


class ParentRegressionTests(unittest.TestCase):
    setUp = base.CliTests.setUp
    tearDown = base.CliTests.tearDown
    def test_play_build_limit(self):
        write_pubspec(self.dir, "1.0.0+2100000001")
        proc = run_cli("--file", str(self.dir / "pubspec.yaml"), "show", "--json")
        self.assertEqual(proc.returncode, 1)
        self.assertEqual(json.loads(proc.stdout)["errors"][0]["code"], "build_overflow")

    def test_play_build_boundary(self):
        write_pubspec(self.dir, "1.0.0+2100000000")
        proc = run_cli("--file", str(self.dir / "pubspec.yaml"), "show", "--json")
        self.assertEqual(proc.returncode, 0, proc.stderr)

    def test_very_long_build_is_structured_error(self):
        write_pubspec(self.dir, "1.0.0+" + "9" * 5000)
        proc = run_cli("--file", str(self.dir / "pubspec.yaml"), "show", "--json")
        self.assertEqual(proc.returncode, 1)
        self.assertNotIn("Traceback", proc.stderr)
        self.assertFalse(json.loads(proc.stdout)["ok"])

    def test_tag_named_main_is_not_main_branch(self):
        write_pubspec(self.dir, "1.0.0+12")
        proc = run_cli("--file", str(self.dir / "pubspec.yaml"), "validate", "--require-main", "--ref", "refs/tags/main", "--json")
        self.assertEqual(proc.returncode, 1)

    def test_missing_ledger_is_not_publication_clearance(self):
        proc = run_cli("publish-guard", "--ledger", str(self.dir / "missing.json"), "--version", "1.0.0+12", "--sha", "a" * 40, "--json")
        self.assertEqual(proc.returncode, 1)
        self.assertFalse(json.loads(proc.stdout)["ok"])

    def test_malformed_ledger_is_structured_error(self):
        ledger = self.dir / "ledger.json"
        ledger.write_text(json.dumps({"schema": "wachbuch.release-ledger/v1", "entries": ["1.0.0+12"]}))
        proc = run_cli("publish-guard", "--ledger", str(ledger), "--version", "1.0.0+12", "--sha", "a" * 40, "--json")
        self.assertEqual(proc.returncode, 1)
        self.assertNotIn("Traceback", proc.stderr)
        self.assertFalse(json.loads(proc.stdout)["ok"])

    def test_docs_guard_rejects_missing_references(self):
        write_pubspec(self.dir, "1.0.0+12")
        contract = self.dir / "contract.json"
        contract.write_text("{}")
        proc = run_cli("--file", str(self.dir / "pubspec.yaml"), "--repo", str(self.dir), "docs-guard", "--contract", str(contract), "--json")
        self.assertEqual(proc.returncode, 1)
        self.assertFalse(json.loads(proc.stdout)["ok"])
