#!/usr/bin/env python3
"""Build WebNN object targets from a generated Windows WebKit Ninja tree."""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def discover_webnn_object_targets(build_dir: Path) -> list[str]:
    ninja_file = build_dir / "build.ninja"
    if not ninja_file.is_file():
        raise SystemExit(f"::error::Ninja build file missing: {ninja_file}")

    targets: list[str] = []
    for raw in ninja_file.read_text(encoding="utf-8", errors="replace").splitlines():
        if not raw.startswith("build "):
            continue
        target_blob = raw.removeprefix("build ").split(":", 1)[0]
        for target in target_blob.split():
            normalized = target.replace("\\", "/")
            if "/Modules/WebNN/" in normalized and normalized.endswith((".obj", ".o")):
                targets.append(target)

    # Keep stable order while removing duplicates.
    return list(dict.fromkeys(targets))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("build_dir", type=Path)
    args = parser.parse_args()

    build_dir = args.build_dir.resolve()
    targets = discover_webnn_object_targets(build_dir)
    if not targets:
        raise SystemExit("::error::No WebNN object targets found in generated Ninja graph")

    print(f"WEBNN_PROBE_TARGETS count={len(targets)}")
    for target in targets:
        print(f"WEBNN_PROBE_BUILD {target}")
        subprocess.run(["ninja", "-C", str(build_dir), target], check=True)

    print("WEBNN_COMPILE_PROBE_OK")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as exc:
        sys.exit(exc.returncode)
