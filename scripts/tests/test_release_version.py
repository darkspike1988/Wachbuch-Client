#!/usr/bin/env python3
"""Deterministic negative/positive tests for the release versioning CLI.

Runs with the Python standard library only::

    python3 -m unittest discover -s scripts/tests -p 'test_*.py' -v

No network, no git, no third-party packages. Every case is fully deterministic.
"""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
CLI = REPO_ROOT / "scripts" / "release_version.py"

sys.path.insert(0, str(REPO_ROOT / "scripts"))
import release_version as rv  # noqa: E402


def write_pubspec(directory: Path, version: str) -> Path:
    path = directory / "pubspec.yaml"
    path.write_text(
        "name: wachbuch_mobile\npublish_to: \"none\"\nversion: %s\n" % version,
        encoding="utf-8",
    )
    return path


def run_cli(*args, cwd=None):
    proc = subprocess.run(
        [sys.executable, str(CLI), *args],
        capture_output=True,
        text=True,
        cwd=cwd,
    )
    return proc


class ParseUnitTests(unittest.TestCase):
    def test_parse_valid(self):
        self.assertEqual(rv.parse_version_string("1.0.0+12"), ("1.0.0", 12))

    def test_parse_missing_build(self):
        with self.assertRaises(rv.ContractError) as ctx:
            rv.parse_version_string("1.0.0")
        self.assertEqual(ctx.exception.code, "invalid_version_string")

    def test_parse_negative_build(self):
        with self.assertRaises(rv.ContractError) as ctx:
            rv.parse_version_string("1.0.0+-3")
        self.assertEqual(ctx.exception.code, "negative_build")

    def test_parse_leading_zero_build(self):
        with self.assertRaises(rv.ContractError) as ctx:
            rv.parse_version_string("1.0.0+012")
        self.assertEqual(ctx.exception.code, "leading_zero")

    def test_parse_prerelease_rejected(self):
        with self.assertRaises(rv.ContractError) as ctx:
            rv.parse_version_string("1.0.0-beta+12")
        self.assertEqual(ctx.exception.code, "invalid_semver")

    def test_parse_leading_zero_appversion(self):
        with self.assertRaises(rv.ContractError) as ctx:
            rv.parse_version_string("01.0.0+12")
        self.assertEqual(ctx.exception.code, "leading_zero")

    def test_build_overflow(self):
        with self.assertRaises(rv.ContractError) as ctx:
            rv.parse_build_number(str(2**64))
        self.assertEqual(ctx.exception.code, "build_overflow")


class CliTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self._tmp.name)

    def tearDown(self):
        self._tmp.cleanup()

    # --- show -------------------------------------------------------------
    def test_show_valid_json(self):
        write_pubspec(self.dir, "1.0.0+12")
        proc = run_cli("--file", str(self.dir / "pubspec.yaml"), "show", "--json")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        data = json.loads(proc.stdout)
        self.assertTrue(data["ok"])
        self.assertEqual(data["app_version"], "1.0.0")
        self.assertEqual(data["build_number"], 12)

    def test_show_invalid_returns_1(self):
        write_pubspec(self.dir, "1.0.0")
        proc = run_cli("--file", str(self.dir / "pubspec.yaml"), "show", "--json")
        self.assertEqual(proc.returncode, 1)
        self.assertFalse(json.loads(proc.stdout)["ok"])

    # --- validate ---------------------------------------------------------
    def test_validate_self_consistent_ok(self):
        # A plain CI syntax/format guard must NOT demand a version bump.
        write_pubspec(self.dir, "1.0.0+12")
        proc = run_cli("--file", str(self.dir / "pubspec.yaml"), "validate", "--json")
        self.assertEqual(proc.returncode, 0, proc.stderr)

    def test_validate_rerun_unchanged_ok(self):
        write_pubspec(self.dir, "1.0.0+12")
        for _ in range(2):
            proc = run_cli("--file", str(self.dir / "pubspec.yaml"), "validate", "--json")
            self.assertEqual(proc.returncode, 0)

    def test_validate_duplicate_mismatch(self):
        write_pubspec(self.dir, "1.0.0+12")
        proc = run_cli(
            "--file", str(self.dir / "pubspec.yaml"), "validate",
            "--expect-name", "1.0.0", "--expect-build", "13", "--json",
        )
        self.assertEqual(proc.returncode, 1)
        codes = [e["code"] for e in json.loads(proc.stdout)["errors"]]
        self.assertIn("pubspec_mismatch", codes)

    def test_validate_requires_main(self):
        write_pubspec(self.dir, "1.0.0+12")
        proc = run_cli(
            "--file", str(self.dir / "pubspec.yaml"), "validate",
            "--require-main", "--ref", "refs/heads/develop/x", "--json",
        )
        self.assertEqual(proc.returncode, 1)
        self.assertIn("not_main_ref", [e["code"] for e in json.loads(proc.stdout)["errors"]])

    def test_validate_main_ok(self):
        write_pubspec(self.dir, "1.0.0+12")
        proc = run_cli(
            "--file", str(self.dir / "pubspec.yaml"), "validate",
            "--require-main", "--ref", "main", "--json",
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)

    def test_validate_build_decrease_fails(self):
        write_pubspec(self.dir, "1.0.0+12")
        proc = run_cli(
            "--file", str(self.dir / "pubspec.yaml"), "validate", "--prev-build", "12", "--json",
        )
        self.assertEqual(proc.returncode, 1)
        self.assertIn("build_not_increasing",
                      [e["code"] for e in json.loads(proc.stdout)["errors"]])

    def test_validate_build_increase_ok(self):
        write_pubspec(self.dir, "1.0.0+13")
        proc = run_cli(
            "--file", str(self.dir / "pubspec.yaml"), "validate", "--prev-build", "12", "--json",
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)

    def test_validate_version_decrease_fails(self):
        write_pubspec(self.dir, "1.0.0+13")
        proc = run_cli(
            "--file", str(self.dir / "pubspec.yaml"), "validate",
            "--prev-name", "1.1.0", "--prev-build", "12", "--json",
        )
        self.assertEqual(proc.returncode, 1)
        self.assertIn("version_decrease",
                      [e["code"] for e in json.loads(proc.stdout)["errors"]])

    def test_validate_max_build(self):
        write_pubspec(self.dir, "1.0.0+12")
        proc = run_cli("--file", str(self.dir / "pubspec.yaml"), "validate",
                       "--max-build", "10", "--json")
        self.assertEqual(proc.returncode, 1)
        self.assertIn("build_exceeds_max",
                      [e["code"] for e in json.loads(proc.stdout)["errors"]])

    # --- next-build -------------------------------------------------------
    def test_next_build(self):
        proc = run_cli("next-build", "--prev", "12", "--json")
        self.assertEqual(proc.returncode, 0)
        self.assertEqual(json.loads(proc.stdout)["build_number"], 13)

    def test_next_build_consecutive(self):
        prev = 12
        for expected in (13, 14, 15):
            proc = run_cli("next-build", "--prev", str(prev), "--json")
            self.assertEqual(json.loads(proc.stdout)["build_number"], expected)
            prev = expected

    def test_next_build_overflow(self):
        proc = run_cli("next-build", "--prev", str(2**64 - 1), "--json")
        self.assertEqual(proc.returncode, 1)
        self.assertIn("build_overflow",
                      [e["code"] for e in json.loads(proc.stdout)["errors"]])

    # --- machine-readable contract ---------------------------------------
    def test_report_output_matches_schema(self):
        write_pubspec(self.dir, "1.0.0+12")
        out = self.dir / "report.json"
        proc = run_cli("--file", str(self.dir / "pubspec.yaml"), "validate", "--json")
        out.write_text(proc.stdout, encoding="utf-8")
        chk = run_cli("check", "--kind", "report", "--input", str(out), "--json")
        self.assertEqual(chk.returncode, 0, chk.stderr)
        self.assertTrue(json.loads(chk.stdout)["ok"])

    def test_checked_in_contract_matches_schema(self):
        chk = run_cli("check", "--kind", "contract", "--input",
                      str(REPO_ROOT / "release" / "release-contract.json"), "--json")
        self.assertEqual(chk.returncode, 0, chk.stderr)
        self.assertTrue(json.loads(chk.stdout)["ok"])

    def test_contract_schema_rejects_mutation(self):
        data = json.loads((REPO_ROOT / "release" / "release-contract.json").read_text())
        del data["publishing"]
        bad = self.dir / "bad-contract.json"
        bad.write_text(json.dumps(data), encoding="utf-8")
        chk = run_cli("check", "--kind", "contract", "--input", str(bad), "--json")
        self.assertEqual(chk.returncode, 1)
        self.assertFalse(json.loads(chk.stdout)["ok"])

    # --- publish-guard (build identity) -----------------------------------
    def test_publish_guard_new_version_ok_and_records(self):
        ledger = self.dir / "ledger.json"
        sha = "a" * 40
        proc = run_cli("publish-guard", "--ledger", str(ledger),
                       "--version", "1.0.0+12", "--sha", sha, "--write", "--json")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn(sha, ledger.read_text(encoding="utf-8"))

    def test_publish_guard_same_sha_ok(self):
        ledger = self.dir / "ledger.json"
        sha = "b" * 40
        run_cli("publish-guard", "--ledger", str(ledger), "--version", "1.0.0+12",
                "--sha", sha, "--write", "--json")
        proc = run_cli("publish-guard", "--ledger", str(ledger),
                       "--version", "1.0.0+12", "--sha", sha, "--json")
        self.assertEqual(proc.returncode, 0, proc.stderr)

    def test_publish_guard_different_sha_fails(self):
        ledger = self.dir / "ledger.json"
        run_cli("publish-guard", "--ledger", str(ledger), "--version", "1.0.0+12",
                "--sha", "c" * 40, "--write", "--json")
        proc = run_cli("publish-guard", "--ledger", str(ledger), "--version", "1.0.0+12",
                       "--sha", "d" * 40, "--json")
        self.assertEqual(proc.returncode, 1)
        self.assertIn("build_reuse_different_source",
                      [e["code"] for e in json.loads(proc.stdout)["errors"]])

    def test_publish_guard_invalid_sha(self):
        ledger = self.dir / "ledger.json"
        proc = run_cli("publish-guard", "--ledger", str(ledger), "--version", "1.0.0+12",
                       "--sha", "abc", "--json")
        self.assertEqual(proc.returncode, 1)
        self.assertIn("invalid_sha", [e["code"] for e in json.loads(proc.stdout)["errors"]])


class DocsGuardTests(unittest.TestCase):
    """Version-drift regression guard (docs vs pubspec)."""

    def _make_repo(self, directory: Path) -> Path:
        (directory / "release").mkdir(parents=True, exist_ok=True)
        write_pubspec(directory, "2.3.4+77")
        (directory / "release" / "release-contract.json").write_text(
            json.dumps({
                "currentVersionReferences": [
                    {"path": "README.md", "pattern": "App-Version\\*\\* \\| `([^`]+)`"},
                ]
            }),
            encoding="utf-8",
        )
        return directory

    def test_docs_guard_green(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = self._make_repo(Path(tmp))
            (d / "README.md").write_text("| **App-Version** | `2.3.4+77` |\n", encoding="utf-8")
            proc = run_cli("--repo", str(d), "docs-guard", "--json")
            self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)

    def test_docs_guard_drift_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = self._make_repo(Path(tmp))
            (d / "README.md").write_text("| **App-Version** | `2.3.4+76` |\n", encoding="utf-8")
            proc = run_cli("--repo", str(d), "docs-guard", "--json")
            self.assertEqual(proc.returncode, 1)
            self.assertIn("version_drift", [e["code"] for e in json.loads(proc.stdout)["errors"]])

    def test_docs_guard_missing_reference_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = self._make_repo(Path(tmp))
            (d / "README.md").write_text("keine Versionsangabe\n", encoding="utf-8")
            proc = run_cli("--repo", str(d), "docs-guard", "--json")
            self.assertEqual(proc.returncode, 1)
            self.assertIn("reference_missing", [e["code"] for e in json.loads(proc.stdout)["errors"]])

    def test_docs_guard_missing_file_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = self._make_repo(Path(tmp))  # README.md intentionally absent
            proc = run_cli("--repo", str(d), "docs-guard", "--json")
            self.assertEqual(proc.returncode, 1)
            self.assertIn("reference_file_missing",
                          [e["code"] for e in json.loads(proc.stdout)["errors"]])


if __name__ == "__main__":
    unittest.main()
