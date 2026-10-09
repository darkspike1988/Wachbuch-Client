#!/usr/bin/env python3
"""Wachbuch release versioning CLI (Python standard library only).

Single source of truth for the app version triple that both the Android and
the iOS store pipelines consume. The version string lives in ``pubspec.yaml`` as
``version: MAJOR.MINOR.PATCH+BUILD``.

Design rules encoded here (see release/release-contract.json):

* App version is SemVer *core* ``MAJOR.MINOR.PATCH`` (no leading zeros, no
  pre-release / build metadata). This is what App Store Connect and Google Play
  expect for the human-visible version string.
* Build number is a positive integer without leading zeros.
* The build number is shared by all app versions and never resets. A later
  app version never gets a lower build number than an earlier one.
* Flutter/CI retry attempts or run numbers are NOT a stable store build
  identity and are never used as the build number.

Commands::

    release_version.py show          [--json]
    release_version.py validate      [--expect-name X] [--expect-build N]
                                     [--ref REF] [--require-main]
                                     [--prev-name X] [--prev-build N]
                                     [--max-build N] [--json]
    release_version.py next-build    [--prev N] [--step K] [--json]
    release_version.py schema        [--json]
    release_version.py check         --input FILE [--json]

Exit codes: 0 = ok, 1 = release contract violation, 2 = usage / IO error.
Machine-readable envelope: schema ``wachbuch.release-version/v1``.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

SCHEMA_ID = "wachbuch.release-version/v1"

# Shared iOS/Android build: Google Play versionCode ceiling.
# https://developer.android.com/studio/publish/versioning
BUILD_MAX = 2100000000

# SemVer core only: MAJOR.MINOR.PATCH, no leading zeros, no prerelease/build.
SEMVER_CORE_RE = re.compile(r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$")
BUILD_RE = re.compile(r"^[1-9][0-9]*$")
ANY_DIGITS_RE = re.compile(r"^[0-9]+$")
LEADING_ZERO_RE = re.compile(r"^0[0-9]+$")

CONTRACT_SCHEMA_PATH = "release/release-contract.schema.json"

# Embedded JSON schema for this CLI's machine-readable report envelope.
REPORT_SCHEMA = {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "$id": SCHEMA_ID,
    "title": "Wachbuch release version report",
    "type": "object",
    "required": [
        "schema",
        "ok",
        "app_version",
        "build_number",
        "version_string",
        "source",
        "checks",
        "errors",
    ],
    "properties": {
        "schema": {"type": "string", "enum": [SCHEMA_ID]},
        "ok": {"type": "boolean"},
        "app_version": {"type": ["string", "null"]},
        "build_number": {"type": ["integer", "null"]},
        "version_string": {"type": ["string", "null"]},
        "source": {"type": "string"},
        "ref": {"type": ["string", "null"]},
        "checks": {
            "type": "array",
            "items": {
                "type": "object",
                "required": ["name", "ok"],
                "properties": {
                    "name": {"type": "string"},
                    "ok": {"type": "boolean"},
                },
            },
        },
        "errors": {
            "type": "array",
            "items": {
                "type": "object",
                "required": ["code", "message"],
                "properties": {
                    "code": {"type": "string"},
                    "message": {"type": "string"},
                },
            },
        },
    },
}

# Embedded JSON schema for the checked-in policy contract.
CONTRACT_SCHEMA = {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "$id": "wachbuch.release-contract/v1",
    "title": "Wachbuch release contract",
    "type": "object",
    "required": [
        "schema",
        "versionScheme",
        "appVersion",
        "buildNumber",
        "versionStringFormat",
        "tagFormat",
        "refs",
        "identities",
        "publishing",
        "limits",
        "server",
    ],
    "properties": {
        "schema": {"type": "string", "enum": ["wachbuch.release-contract/v1"]},
        "versionScheme": {"type": "string"},
        "appVersion": {"type": "object"},
        "buildNumber": {"type": "object"},
        "versionStringFormat": {"type": "string"},
        "tagFormat": {"type": "string"},
        "refs": {"type": "object"},
        "identities": {"type": "object"},
        "publishing": {"type": "object"},
        "limits": {"type": "object"},
        "server": {"type": "object"},
    },
}


class ContractError(Exception):
    """A release-contract violation, mapped to exit code 1."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


def _fail(code: str, message: str) -> ContractError:
    return ContractError(code, message)


def parse_version_string(raw: str) -> tuple[str, int]:
    """Split ``MAJOR.MINOR.PATCH+BUILD`` into (app_version, build_number)."""
    raw = raw.strip()
    if "+" not in raw:
        raise _fail(
            "invalid_version_string",
            f"version must be MAJOR.MINOR.PATCH+BUILD, got {raw!r}",
        )
    name, _, build = raw.partition("+")
    name = name.strip()
    build = build.strip()
    if not SEMVER_CORE_RE.match(name):
        if LEADING_ZERO_RE.match(name.split(".")[0]) or any(
            LEADING_ZERO_RE.match(p) for p in name.split(".")
        ):
            raise _fail("leading_zero", f"app version has a leading zero: {name!r}")
        raise _fail(
            "invalid_semver",
            f"app version must be MAJOR.MINOR.PATCH without prerelease, got {name!r}",
        )
    build_number = parse_build_number(build)
    return name, build_number


def parse_build_number(raw: str) -> int:
    raw = str(raw).strip()
    if raw.startswith("-"):
        raise _fail("negative_build", f"build number must be positive, got {raw!r}")
    if LEADING_ZERO_RE.match(raw):
        raise _fail("leading_zero", f"build number has a leading zero: {raw!r}")
    if not BUILD_RE.match(raw):
        raise _fail("invalid_build_number", f"build number must be a positive integer, got {raw!r}")
    if not ANY_DIGITS_RE.match(raw):
        raise _fail("invalid_build_number", f"build number must be numeric, got {raw!r}")
    if len(raw) > len(str(BUILD_MAX)):
        raise _fail("build_overflow", "build number exceeds Google Play limit")
    value = int(raw)
    if value > BUILD_MAX:
        raise _fail("build_overflow", "build number exceeds Google Play limit")
    return value


def read_pubspec_version(pubspec_path: Path) -> str:
    if not pubspec_path.is_file():
        raise _fail("pubspec_missing", f"pubspec not found: {pubspec_path}")
    for line in pubspec_path.read_text(encoding="utf-8").splitlines():
        if line.startswith("version:"):
            return line.split(":", 1)[1].strip()
    raise _fail("pubspec_missing_version", f"no version: line in {pubspec_path}")


def semver_key(name: str) -> tuple[int, int, int]:
    major, minor, patch = (int(p) for p in name.split("."))
    return (major, minor, patch)


def _ref_name(ref: str) -> str:
    ref = ref.strip()
    for prefix in ("refs/heads/", "refs/tags/"):
        if ref.startswith(prefix):
            return ref[len(prefix):]
    return ref


def _envelope(
    *,
    ok: bool,
    app_version,
    build_number,
    version_string,
    source,
    ref,
    checks,
    errors,
) -> dict:
    return {
        "schema": SCHEMA_ID,
        "ok": ok,
        "app_version": app_version,
        "build_number": build_number,
        "version_string": version_string,
        "source": source,
        "ref": ref,
        "checks": checks,
        "errors": errors,
    }


def _emit_report(env: dict, as_json: bool) -> None:
    if as_json:
        print(json.dumps(env, indent=2, sort_keys=False))
        return
    if env["ok"]:
        print(f"ok: {env['version_string']} (source: {env['source']})")
    else:
        print(f"FAILED: {env['version_string'] or env['source']}", file=sys.stderr)
        for err in env["errors"]:
            print(f"  - {err['code']}: {err['message']}", file=sys.stderr)


def cmd_show(args: argparse.Namespace) -> int:
    source = str(args.file)
    try:
        raw = read_pubspec_version(args.file)
        name, build = parse_version_string(raw)
    except ContractError as exc:
        _emit_report(
            _envelope(
                ok=False,
                app_version=None,
                build_number=None,
                version_string=None,
                source=source,
                ref=None,
                checks=[],
                errors=[{"code": exc.code, "message": exc.message}],
            ),
            args.json,
        )
        return 1
    _emit_report(
        _envelope(
            ok=True,
            app_version=name,
            build_number=build,
            version_string=f"{name}+{build}",
            source=source,
            ref=None,
            checks=[{"name": "parse", "ok": True}],
            errors=[],
        ),
        args.json,
    )
    return 0


def cmd_validate(args: argparse.Namespace) -> int:
    source = str(args.file)
    checks: list[dict] = []
    errors: list[dict] = []

    def check(name: str, ok: bool, code: str | None = None, message: str = "") -> None:
        checks.append({"name": name, "ok": ok})
        if not ok:
            errors.append({"code": code or name, "message": message})

    try:
        raw = read_pubspec_version(args.file)
        src_name, src_build = parse_version_string(raw)
        parse_ok = True
    except ContractError as exc:
        src_name = src_build = None
        raw = None
        check("pubspec_version_parses", False, exc.code, exc.message)
        parse_ok = False

    if parse_ok:
        check("pubspec_version_parses", True)

    expect_name = args.expect_name or src_name
    expect_build = args.expect_build if args.expect_build is not None else src_build

    # 4. expected app version validity
    if expect_name is None or not SEMVER_CORE_RE.match(str(expect_name)):
        check("expected_app_version_valid", False, "invalid_semver",
              f"expected app version must be MAJOR.MINOR.PATCH, got {expect_name!r}")
    else:
        check("expected_app_version_valid", True)

    # 5. expected build number validity
    if expect_build is None:
        check("expected_build_number_valid", False, "invalid_build_number",
              "no build number available")
    else:
        try:
            parse_build_number(str(expect_build))
            check("expected_build_number_valid", True)
        except ContractError as exc:
            check("expected_build_number_valid", False, exc.code, exc.message)

    # 6. pubspec matches the requested triple
    if parse_ok and expect_name is not None and expect_build is not None:
        expected_string = f"{expect_name}+{expect_build}"
        check(
            "pubspec_matches_expected",
            raw == expected_string,
            "pubspec_mismatch",
            f"pubspec version {raw!r} does not match expected {expected_string!r}",
        )

    # 7. main-only guard
    ref_value = args.ref
    if args.require_main:
        main_ok = ref_value in ("main", "refs/heads/main")
        check(
            "release_ref_is_main",
            main_ok,
            "not_main_ref",
            f"store releases must run on main, got ref={ref_value!r}",
        )

    # 8. build must strictly increase vs previous build (never reset)
    if args.prev_build is not None:
        try:
            prev = parse_build_number(str(args.prev_build))
        except ContractError as exc:
            check("prev_build_valid", False, exc.code, exc.message)
        else:
            check("prev_build_valid", True)
            if expect_build is not None:
                try:
                    cur = parse_build_number(str(expect_build))
                except ContractError:
                    cur = None
                if cur is not None:
                    check(
                        "build_strictly_increasing",
                        cur > prev,
                        "build_not_increasing",
                        f"build {cur} must be greater than previous build {prev}",
                    )

    # 9. app version must never decrease
    if args.prev_name is not None:
        if SEMVER_CORE_RE.match(str(args.prev_name)):
            check("prev_app_version_valid", True)
            if expect_name is not None and SEMVER_CORE_RE.match(str(expect_name)):
                check(
                    "app_version_not_decreasing",
                    semver_key(expect_name) >= semver_key(str(args.prev_name)),
                    "version_decrease",
                    f"app version {expect_name} is lower than previous {args.prev_name}",
                )
        else:
            check("prev_app_version_valid", False, "invalid_semver",
                  f"previous app version must be MAJOR.MINOR.PATCH, got {args.prev_name!r}")

    # 10. optional store ceiling
    if args.max_build is not None and expect_build is not None:
        try:
            ceiling = int(str(args.max_build))
        except ValueError:
            check("max_build_valid", False, "invalid_max_build", f"bad --max-build {args.max_build!r}")
        else:
            check("max_build_valid", True)
            try:
                cur = parse_build_number(str(expect_build))
            except ContractError:
                cur = None
            if cur is not None:
                check(
                    "build_within_ceiling",
                    cur <= ceiling,
                    "build_exceeds_max",
                    f"build {cur} exceeds ceiling {ceiling}",
                )

    ok = not errors
    version_string = (
        f"{expect_name}+{expect_build}" if expect_name is not None and expect_build is not None else raw
    )
    _emit_report(
        _envelope(
            ok=ok,
            app_version=expect_name,
            build_number=expect_build,
            version_string=version_string,
            source=source,
            ref=ref_value,
            checks=checks,
            errors=errors,
        ),
        args.json,
    )
    return 0 if ok else 1


def cmd_next_build(args: argparse.Namespace) -> int:
    try:
        prev = parse_build_number(str(args.prev))
        step = int(str(args.step))
        if step < 1:
            raise _fail("invalid_step", f"step must be >= 1, got {step}")
        nxt = prev + step
        if nxt > BUILD_MAX:
            raise _fail("build_overflow", f"next build {nxt} exceeds unsigned 64-bit")
    except ContractError as exc:
        _emit_report(
            _envelope(
                ok=False, app_version=None, build_number=None, version_string=None,
                source="argparse", ref=None, checks=[],
                errors=[{"code": exc.code, "message": exc.message}],
            ),
            args.json,
        )
        return 1
    _emit_report(
        _envelope(
            ok=True, app_version=None, build_number=nxt, version_string=str(nxt),
            source="argparse", ref=None,
            checks=[{"name": "next_build", "ok": True}], errors=[],
        ),
        args.json,
    )
    return 0


def cmd_schema(args: argparse.Namespace) -> int:
    if args.kind == "contract":
        print(json.dumps(CONTRACT_SCHEMA, indent=2))
    else:
        print(json.dumps(REPORT_SCHEMA, indent=2))
    return 0


def cmd_docs_guard(args: argparse.Namespace) -> int:
    """Fail closed when a doc/workflow still advertises a stale app version.

    The references to check are declared in the release contract as
    ``currentVersionReferences`` (path + regex). Every match in every listed
    file must equal the pubspec version, otherwise the guard fails. This is the
    regression guard for version drift between pubspec.yaml and the docs.
    """
    repo = Path(args.repo)
    contract_path = Path(args.contract)
    if not contract_path.is_absolute():
        contract_path = repo / contract_path

    checks: list[dict] = []
    errors: list[dict] = []
    app_version = None
    build_number = None
    version_string = None

    try:
        raw = read_pubspec_version(args.file)
        name, build = parse_version_string(raw)
    except ContractError as exc:
        _emit_report(
            _envelope(ok=False, app_version=None, build_number=None, version_string=None,
                      source=str(args.file), ref=contract_path.as_posix(), checks=[],
                      errors=[{"code": exc.code, "message": exc.message}]),
            args.json,
        )
        return 1

    app_version, build_number = name, build
    version_string = f"{name}+{build}"

    if not contract_path.is_file():
        errors.append({"code": "contract_missing",
                       "message": f"release contract not found: {contract_path}"})
        refs = []
    else:
        try:
            contract = json.loads(contract_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            errors.append({"code": "contract_invalid",
                           "message": f"cannot parse {contract_path}: {exc}"})
            contract = {}
        refs = contract.get("currentVersionReferences", []) if isinstance(contract, dict) else []

    if not isinstance(refs, list) or not refs:
        errors.append({"code": "contract_references_missing",
                       "message": "nonempty currentVersionReferences required"})
        refs = []

    for ref in refs:
        if not isinstance(ref, dict) or "path" not in ref or "pattern" not in ref:
            errors.append({"code": "contract_reference_invalid",
                           "message": f"invalid currentVersionReferences entry: {ref!r}"})
            continue
        target = repo / ref["path"]
        label = ref["path"]
        if not target.is_file():
            checks.append({"name": f"reference_file:{label}", "ok": False})
            errors.append({"code": "reference_file_missing",
                           "message": f"{label} referenced by contract does not exist"})
            continue
        try:
            found = re.findall(ref["pattern"], target.read_text(encoding="utf-8"), re.MULTILINE)
        except re.error as exc:
            errors.append({"code": "reference_pattern_invalid",
                           "message": f"bad pattern for {label}: {exc}"})
            continue
        if not found:
            checks.append({"name": f"reference:{label}", "ok": False})
            errors.append({"code": "reference_missing",
                           "message": f"no version reference matched in {label}"})
            continue
        drifted = [v for v in found if v != version_string]
        ok = not drifted
        checks.append({"name": f"reference:{label}", "ok": ok})
        if drifted:
            errors.append({
                "code": "version_drift",
                "message": f"{label} advertises {', '.join(sorted(set(drifted)))} "
                           f"but pubspec is {version_string}",
            })

    ok = not errors
    _emit_report(
        _envelope(ok=ok, app_version=app_version, build_number=build_number,
                  version_string=version_string, source=str(args.file),
                  ref=contract_path.as_posix(), checks=checks, errors=errors),
        args.json,
    )
    return 0 if ok else 1


SHA_RE = re.compile(r"^[0-9a-f]{40}$")


def cmd_publish_guard(args: argparse.Namespace) -> int:
    """Fail closed when the same version+build would be published from new source.

    Only *publishing* a given ``MAJOR.MINOR.PATCH+BUILD`` from a different commit
    than the one already recorded is a violation. Reruns and normal commits on
    other development branches with an unchanged version are allowed.
    """
    source = "argparse"
    try:
        name, build = parse_version_string(args.version)
    except ContractError as exc:
        _emit_report(
            _envelope(ok=False, app_version=None, build_number=None, version_string=None,
                      source=source, ref=None, checks=[],
                      errors=[{"code": exc.code, "message": exc.message}]),
            args.json,
        )
        return 1

    version_string = f"{name}+{build}"
    sha = args.sha.strip()
    checks: list[dict] = []
    errors: list[dict] = []

    sha_ok = bool(SHA_RE.match(sha))
    checks.append({"name": "sha_is_full_commit", "ok": sha_ok})
    if not sha_ok:
        errors.append({"code": "invalid_sha",
                       "message": f"expected full 40-char commit SHA, got {sha!r}"})

    entries: dict = {}
    ledger = args.ledger
    if ledger.is_file():
        try:
            data = json.loads(ledger.read_text(encoding="utf-8"))
            if (not isinstance(data, dict)
                    or data.get("schema") != "wachbuch.release-ledger/v1"
                    or not isinstance(data.get("entries"), dict)):
                raise ValueError("ledger schema/entries invalid")
            entries = data["entries"]
            for identity, entry in entries.items():
                parse_version_string(identity)
                recorded = entry if isinstance(entry, str) else entry.get("sha") if isinstance(entry, dict) else None
                if not isinstance(recorded, str) or not SHA_RE.fullmatch(recorded):
                    raise ValueError("ledger entry SHA invalid")
        except (json.JSONDecodeError, ValueError, ContractError) as exc:
            entries = {}
            errors.append({"code": "ledger_invalid", "message": f"cannot parse {ledger}: {exc}"})
    elif ledger.exists():
        errors.append({"code": "ledger_invalid", "message": f"{ledger} is not a regular file"})
    elif not args.write:
        errors.append({"code": "ledger_missing", "message": "missing ledger is not publication clearance"})

    recorded_sha = None
    if version_string in entries:
        entry = entries[version_string]
        recorded_sha = entry if isinstance(entry, str) else entry.get("sha")

    if errors:
        ok = False
    elif recorded_sha is None:
        ok = True
        checks.append({"name": "version_unpublished", "ok": True})
        if args.write:
            entries[version_string] = sha
            try:
                ledger.parent.mkdir(parents=True, exist_ok=True)
                ledger.write_text(
                    json.dumps(
                        {"schema": "wachbuch.release-ledger/v1", "entries": entries},
                        indent=2,
                        sort_keys=True,
                    )
                    + "\n",
                    encoding="utf-8",
                )
            except OSError as exc:
                del entries[version_string]
                ok = False
                checks.append({"name": "ledger_written", "ok": False})
                errors.append({"code": "ledger_write_failed",
                               "message": f"cannot write {ledger}: {exc}"})
            else:
                checks.append({"name": "ledger_written", "ok": True})
    elif recorded_sha == sha:
        ok = True
        checks.append({"name": "version_matches_recorded_source", "ok": True})
    else:
        ok = False
        checks.append({"name": "version_matches_recorded_source", "ok": False})
        errors.append({
            "code": "build_reuse_different_source",
            "message": (
                f"{version_string} already published from {recorded_sha}; "
                f"refusing to publish it again from {sha}"
            ),
        })

    _emit_report(
        _envelope(ok=ok, app_version=name, build_number=build, version_string=version_string,
                  source=source, ref=recorded_sha, checks=checks, errors=errors),
        args.json,
    )
    return 0 if ok else 1


# --------------------------------------------------------------------------
# Minimal JSON Schema (subset) validator: stdlib-only.
# Supports: type, required, properties, enum, pattern, minimum, items.
# --------------------------------------------------------------------------
def _json_type(value) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "boolean"
    if isinstance(value, int):
        return "integer"
    if isinstance(value, float):
        return "number"
    if isinstance(value, str):
        return "string"
    if isinstance(value, list):
        return "array"
    if isinstance(value, dict):
        return "object"
    return "unknown"


def validate_against_schema(instance, schema: dict, path: str = "$") -> list[str]:
    problems: list[str] = []
    expected = schema.get("type")
    if expected is not None:
        allowed = expected if isinstance(expected, list) else [expected]
        actual = _json_type(instance)
        if actual not in allowed and not (actual == "integer" and "number" in allowed):
            return [f"{path}: expected type {allowed}, got {actual}"]

    if "enum" in schema and instance not in schema["enum"]:
        problems.append(f"{path}: value {instance!r} not in enum {schema['enum']}")

    if isinstance(instance, str) and "pattern" in schema:
        if not re.search(schema["pattern"], instance):
            problems.append(f"{path}: {instance!r} does not match pattern {schema['pattern']}")

    if isinstance(instance, int) and not isinstance(instance, bool) and "minimum" in schema:
        if instance < schema["minimum"]:
            problems.append(f"{path}: {instance} < minimum {schema['minimum']}")

    if isinstance(instance, dict):
        for key in schema.get("required", []):
            if key not in instance:
                problems.append(f"{path}: missing required property {key!r}")
        for key, subschema in schema.get("properties", {}).items():
            if key in instance:
                problems.extend(validate_against_schema(instance[key], subschema, f"{path}.{key}"))

    if isinstance(instance, list) and "items" in schema:
        for idx, item in enumerate(instance):
            problems.extend(validate_against_schema(item, schema["items"], f"{path}[{idx}]"))

    return problems


def cmd_check(args: argparse.Namespace) -> int:
    schema = CONTRACT_SCHEMA if args.kind == "contract" else REPORT_SCHEMA
    try:
        data = json.loads(args.input.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"cannot read {args.input}: {exc}", file=sys.stderr)
        return 2
    problems = validate_against_schema(data, schema)
    if args.json:
        print(json.dumps({"schema": schema.get("$id"), "ok": not problems, "problems": problems}, indent=2))
    else:
        if problems:
            for problem in problems:
                print(problem, file=sys.stderr)
        else:
            print(f"contract check ok: {args.input}")
    return 0 if not problems else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Wachbuch release versioning CLI")
    parser.add_argument("--repo", default=".", help="repository root (default: cwd)")
    parser.add_argument("--file", default=None, help="pubspec path (default: <repo>/pubspec.yaml)")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    # Allow --json after the subcommand too. default=SUPPRESS keeps the value
    # from the top-level parser unless explicitly given here as well.
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--json", action="store_true", default=argparse.SUPPRESS,
                        help="machine-readable output")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("show", parents=[common], help="print the version from pubspec.yaml")

    p_val = sub.add_parser("validate", parents=[common], help="fail-closed release validation")
    p_val.add_argument("--expect-name")
    p_val.add_argument("--expect-build", type=int)
    p_val.add_argument("--ref")
    p_val.add_argument("--require-main", action="store_true")
    p_val.add_argument("--prev-name")
    p_val.add_argument("--prev-build", type=int)
    p_val.add_argument("--max-build", type=int)

    p_next = sub.add_parser("next-build", parents=[common],
                            help="compute the next strictly increasing build number")
    p_next.add_argument("--prev", required=True)
    p_next.add_argument("--step", default="1")

    p_schema = sub.add_parser("schema", parents=[common], help="print an embedded JSON schema")
    p_schema.add_argument("--kind", choices=["report", "contract"], default="report")

    p_check = sub.add_parser("check", parents=[common],
                             help="validate a JSON document against an embedded schema")
    p_check.add_argument("--input", required=True, type=Path)
    p_check.add_argument("--kind", choices=["report", "contract"], default="contract")

    p_pub = sub.add_parser("publish-guard", parents=[common],
                           help="refuse publishing a version+build from new source")
    p_pub.add_argument("--ledger", required=True, type=Path)
    p_pub.add_argument("--version", required=True, help="NAME+BUILD, e.g. 1.0.0+12")
    p_pub.add_argument("--sha", required=True, help="full 40-char commit SHA")
    p_pub.add_argument("--write", action="store_true", help="record the new version+sha in the ledger")

    p_docs = sub.add_parser("docs-guard", parents=[common],
                            help="fail when docs advertise a stale app version")
    p_docs.add_argument("--contract", default="release/release-contract.json",
                        help="release contract declaring currentVersionReferences")

    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.file is None:
        args.file = Path(args.repo) / "pubspec.yaml"
    else:
        args.file = Path(args.file)
    handlers = {
        "show": cmd_show,
        "validate": cmd_validate,
        "next-build": cmd_next_build,
        "schema": cmd_schema,
        "check": cmd_check,
        "publish-guard": cmd_publish_guard,
        "docs-guard": cmd_docs_guard,
    }
    return handlers[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
