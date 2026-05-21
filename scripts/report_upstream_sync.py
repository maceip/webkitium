#!/usr/bin/env python3
"""
Report how far Webkitium's pinned WebKit and Dawn inputs are from upstream.

This script is read-only. It does not update the matrix, re-cut webkit-pin, or
touch the runner cache. Use it before opening a WebKit pin bump branch.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MATRIX = REPO_ROOT / "config" / "webkit-build-matrix.json"
DEFAULT_VCPKG_CONFIG = REPO_ROOT / "config" / "vcpkg-configuration.json"

OFFICIAL_WEBKIT_URL = "https://github.com/WebKit/WebKit.git"
OFFICIAL_WEBKIT_API = "https://api.github.com/repos/WebKit/WebKit"
GOOGLE_DAWN_URL = "https://github.com/google/dawn.git"
MICROSOFT_VCPKG_URL = "https://github.com/microsoft/vcpkg.git"
VCPKG_DAWN_PORT_RAW = "https://raw.githubusercontent.com/microsoft/vcpkg/{ref}/ports/dawn/vcpkg.json"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def normalize_repo_url(url: str) -> str:
    value = url.strip().rstrip("/")
    if value.endswith(".git"):
        value = value[:-4]
    return value.lower()


def run_git(args: list[str]) -> str:
    try:
        return subprocess.check_output(["git", *args], stderr=subprocess.STDOUT, text=True)
    except subprocess.CalledProcessError as exc:
        raise SystemExit(exc.output) from exc


def ls_remote(url: str, ref: str) -> str | None:
    output = run_git(["ls-remote", url, ref])
    candidates: list[tuple[str, str]] = []
    for line in output.splitlines():
        parts = line.split()
        if len(parts) == 2:
            candidates.append((parts[0], parts[1]))
    if not candidates:
        return None
    peeled = [sha for sha, name in candidates if name.endswith("^{}")]
    if peeled:
        return peeled[0]
    return candidates[0][0]


def github_json(url: str) -> dict[str, Any] | None:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "webkitium-upstream-sync",
    }
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return None
        raise


def raw_json(url: str) -> dict[str, Any] | None:
    request = urllib.request.Request(url, headers={"User-Agent": "webkitium-upstream-sync"})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return None
        raise


def vcpkg_port_version(port: dict[str, Any] | None) -> str | None:
    if not port:
        return None
    for key in ("version-date", "version-semver", "version-string", "version"):
        if key in port:
            value = f"{key}={port[key]}"
            port_version = port.get("port-version")
            if port_version:
                value += f" port-version={port_version}"
            return value
    return None


def build_report(matrix_path: Path, vcpkg_config_path: Path) -> dict[str, Any]:
    matrix = load_json(matrix_path)
    vcpkg_config = load_json(vcpkg_config_path)

    webkit = matrix["webkit"]
    webkit_upstream = webkit.get("upstream") or {}
    webkit_pin = webkit["expectedCommit"]
    webkit_branch = webkit_upstream.get("defaultBranch") or "main"
    webkit_head = ls_remote(OFFICIAL_WEBKIT_URL, f"refs/heads/{webkit_branch}")
    webkit_commit = github_json(f"{OFFICIAL_WEBKIT_API}/commits/{webkit_pin}")
    webkit_compare = github_json(f"{OFFICIAL_WEBKIT_API}/compare/{webkit_pin}...{webkit_branch}")

    dawn = matrix["dawn"]
    dawn_tag = dawn["versionTag"]
    dawn_pin = dawn["commit"]
    dawn_head = ls_remote(GOOGLE_DAWN_URL, "refs/heads/main")
    dawn_tag_commit = ls_remote(GOOGLE_DAWN_URL, f"refs/tags/{dawn_tag}")

    vcpkg_baseline = dawn["vcpkgBaseline"]
    configured_vcpkg_baseline = (vcpkg_config.get("default-registry") or {}).get("baseline")
    vcpkg_head = ls_remote(MICROSOFT_VCPKG_URL, "refs/heads/master")
    vcpkg_dawn_at_pin = raw_json(VCPKG_DAWN_PORT_RAW.format(ref=vcpkg_baseline))
    vcpkg_dawn_at_head = raw_json(VCPKG_DAWN_PORT_RAW.format(ref="master"))

    return {
        "webkit": {
            "configuredUrl": webkit_upstream.get("url"),
            "configuredPreset": webkit_upstream.get("preset"),
            "officialUrl": OFFICIAL_WEBKIT_URL,
            "isOfficialUrl": normalize_repo_url(webkit_upstream.get("url", "")) == normalize_repo_url(OFFICIAL_WEBKIT_URL),
            "pin": webkit_pin,
            "pinExistsInOfficialRepo": webkit_commit is not None,
            "pinDate": ((webkit_commit or {}).get("commit") or {}).get("committer", {}).get("date"),
            "pinUrl": (webkit_commit or {}).get("html_url"),
            "branch": webkit_branch,
            "branchHead": webkit_head,
            "comparePinToBranch": {
                "status": (webkit_compare or {}).get("status"),
                "branchAheadBy": (webkit_compare or {}).get("ahead_by"),
                "pinBehindBy": (webkit_compare or {}).get("ahead_by"),
                "pinAheadBy": (webkit_compare or {}).get("behind_by"),
                "mergeBase": ((webkit_compare or {}).get("merge_base_commit") or {}).get("sha"),
            },
        },
        "dawn": {
            "upstreamUrl": GOOGLE_DAWN_URL,
            "versionTag": dawn_tag,
            "pin": dawn_pin,
            "tagCommit": dawn_tag_commit,
            "tagMatchesPin": dawn_tag_commit == dawn_pin,
            "branchHead": dawn_head,
            "vcpkgBaseline": vcpkg_baseline,
            "vcpkgConfigBaseline": configured_vcpkg_baseline,
            "vcpkgBaselineMatchesConfig": vcpkg_baseline == configured_vcpkg_baseline,
            "vcpkgMasterHead": vcpkg_head,
            "vcpkgDawnPortAtPin": vcpkg_port_version(vcpkg_dawn_at_pin),
            "vcpkgDawnPortAtMaster": vcpkg_port_version(vcpkg_dawn_at_head),
        },
    }


def print_text(report: dict[str, Any]) -> None:
    webkit = report["webkit"]
    print("WebKit")
    print(f"  configured upstream: {webkit['configuredUrl']} ({webkit['configuredPreset']})")
    print(f"  official upstream:   {webkit['officialUrl']}")
    print(f"  official URL:        {'yes' if webkit['isOfficialUrl'] else 'no'}")
    print(f"  pinned commit:       {webkit['pin']}")
    print(f"  pin in official:     {'yes' if webkit['pinExistsInOfficialRepo'] else 'no'}")
    if webkit.get("pinDate"):
        print(f"  pin date:            {webkit['pinDate']}")
    print(f"  {webkit['branch']} head:          {webkit['branchHead']}")
    compare = webkit["comparePinToBranch"]
    if compare.get("branchAheadBy") is not None:
        print(f"  pin -> {webkit['branch']}:        {compare['branchAheadBy']} commits behind upstream head")
    if webkit.get("pinUrl"):
        print(f"  pin URL:             {webkit['pinUrl']}")

    dawn = report["dawn"]
    print()
    print("Dawn / vcpkg")
    print(f"  Dawn upstream:       {dawn['upstreamUrl']}")
    print(f"  pinned tag:          {dawn['versionTag']}")
    print(f"  pinned commit:       {dawn['pin']}")
    print(f"  tag commit:          {dawn['tagCommit']}")
    print(f"  tag matches pin:     {'yes' if dawn['tagMatchesPin'] else 'no'}")
    print(f"  Dawn main head:      {dawn['branchHead']}")
    print(f"  vcpkg baseline:      {dawn['vcpkgBaseline']}")
    print(f"  vcpkg config match:  {'yes' if dawn['vcpkgBaselineMatchesConfig'] else 'no'}")
    print(f"  vcpkg master head:   {dawn['vcpkgMasterHead']}")
    print(f"  dawn port at pin:    {dawn['vcpkgDawnPortAtPin']}")
    print(f"  dawn port at master: {dawn['vcpkgDawnPortAtMaster']}")


def drift_failures(report: dict[str, Any]) -> list[str]:
    failures: list[str] = []
    webkit = report["webkit"]
    compare = webkit["comparePinToBranch"]
    if not webkit["isOfficialUrl"]:
        failures.append("WebKit upstream URL is not official WebKit/WebKit")
    if not webkit["pinExistsInOfficialRepo"]:
        failures.append(f"WebKit pin is not present in official WebKit: {webkit['pin']}")
    if (compare.get("branchAheadBy") or 0) > 0:
        failures.append(
            f"WebKit pin is {compare['branchAheadBy']} commits behind official {webkit['branch']} "
            f"({webkit['branchHead']})"
        )

    dawn = report["dawn"]
    if not dawn["tagMatchesPin"]:
        failures.append(f"Dawn tag {dawn['versionTag']} does not resolve to configured commit {dawn['pin']}")
    if not dawn["vcpkgBaselineMatchesConfig"]:
        failures.append("Dawn vcpkg baseline differs between matrix and vcpkg configuration")
    if dawn["vcpkgDawnPortAtPin"] != dawn["vcpkgDawnPortAtMaster"]:
        failures.append(
            "vcpkg master has a different dawn port version "
            f"({dawn['vcpkgDawnPortAtMaster']}) than the configured baseline ({dawn['vcpkgDawnPortAtPin']})"
        )
    return failures


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--matrix", type=Path, default=DEFAULT_MATRIX)
    parser.add_argument("--vcpkg-config", type=Path, default=DEFAULT_VCPKG_CONFIG)
    parser.add_argument("--json", action="store_true", help="Emit machine-readable JSON")
    parser.add_argument(
        "--fail-on-drift",
        action="store_true",
        help="Exit nonzero when WebKit or Dawn/vcpkg is behind the tracked upstream tuple",
    )
    args = parser.parse_args()

    report = build_report(args.matrix.resolve(), args.vcpkg_config.resolve())
    if args.json:
        json.dump(report, sys.stdout, indent=2)
        print()
    else:
        print_text(report)

    if args.fail_on_drift:
        failures = drift_failures(report)
        if failures:
            for failure in failures:
                print(f"::error::{failure}", file=sys.stderr)
            raise SystemExit(1)


if __name__ == "__main__":
    main()
