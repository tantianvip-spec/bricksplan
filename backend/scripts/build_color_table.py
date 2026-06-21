"""
One-shot: pull Rebrickable colors and emit colors.json with normalized aliases.

Usage:
    REBRICKABLE_API_KEY=xxx python scripts/build_color_table.py

Writes to src/brickfinder/colors/colors.json. Run only when the upstream
color list changes (rarely).
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

import httpx

OUT = Path(__file__).resolve().parents[1] / "src" / "brickfinder" / "colors" / "colors.json"


def _alias(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", name.lower()).strip()


def main() -> int:
    key = os.environ.get("REBRICKABLE_API_KEY")
    if not key:
        print("REBRICKABLE_API_KEY required", file=sys.stderr)
        return 2

    headers = {"Authorization": f"key {key}"}
    colors: list[dict[str, object]] = []
    url = "https://rebrickable.com/api/v3/lego/colors/?page_size=1000"
    with httpx.Client(timeout=30) as client:
        while url:
            r = client.get(url, headers=headers)
            r.raise_for_status()
            data = r.json()
            for c in data["results"]:
                aliases = {_alias(c["name"])}
                # Brickognize tends to return space-stripped lowercase
                aliases.add(c["name"].lower().replace(" ", ""))
                colors.append({"id": c["id"], "name": c["name"], "aliases": sorted(aliases)})
            url = data.get("next")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"colors": colors}, indent=2, sort_keys=True))
    print(f"wrote {len(colors)} colors to {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
