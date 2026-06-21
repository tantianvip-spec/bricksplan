from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

_NORMALIZE_RE = re.compile(r"[^a-z0-9]+")


def _normalize(s: str) -> str:
    return _NORMALIZE_RE.sub(" ", s.lower()).strip()


class ColorTable:
    def __init__(self, name_to_id: dict[str, int]) -> None:
        self._lookup: dict[str, int] = name_to_id

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> ColorTable:
        name_to_id: dict[str, int] = {}
        for entry in data["colors"]:
            cid = int(entry["id"])
            keys = [entry["name"], *entry.get("aliases", [])]
            for k in keys:
                name_to_id[_normalize(k)] = cid
                name_to_id[k.lower().replace(" ", "")] = cid
        return cls(name_to_id)

    def lookup(self, name: str) -> int:
        if not name:
            return -1
        candidates = (_normalize(name), name.lower().replace(" ", ""))
        for c in candidates:
            if c in self._lookup:
                return self._lookup[c]
        return -1


_DEFAULT_PATH = Path(__file__).with_name("colors.json")


def load_default() -> ColorTable:
    return ColorTable.from_dict(json.loads(_DEFAULT_PATH.read_text()))
