#!/usr/bin/env python3
"""Ensure platform:linux-gtk-wayland matrix covers all catalog feature ids."""
from __future__ import annotations

import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("pip install pyyaml", file=sys.stderr)
    sys.exit(1)


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    data = yaml.safe_load((root / "features.yaml").read_text())
    feats = [x for x in data if isinstance(x, dict) and x.get("id") and x.get("kind") != "platform"]
    plat = next(x for x in data if x.get("id") == "platform:linux-gtk-wayland")
    impl = set(plat.get("implemented", []))
    pl = set(plat.get("planned", []))
    na = set(plat.get("not_applicable", []))
    add = set(plat.get("required_additive", []))
    all_ids = {x["id"] for x in feats}
    req = {x["id"] for x in feats if x.get("required")}
    missing_req = req - impl - pl - na
    uncovered = all_ids - impl - pl - na - add
    unknown = (impl | pl | na | add) - all_ids
    if missing_req:
        print("missing required:", sorted(missing_req))
    if uncovered:
        print("catalog ids not in matrix:", sorted(uncovered))
    if unknown:
        print("unknown matrix ids:", sorted(unknown))
    if missing_req or uncovered or unknown:
        return 1
    print(f"ok: {len(feats)} features, {len(impl)} implemented, {len(pl)} planned")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
