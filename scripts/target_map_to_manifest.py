#!/usr/bin/env python3
"""Convert target-map rows into a unique target-utterance manifest."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target-map", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    rows: dict[str, dict] = {}
    for line in Path(args.target_map).read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        mapping = json.loads(line)
        identifier = str(mapping["target_id"])
        row = {
            "id": identifier,
            "utterance_id": identifier,
            "speaker": str(mapping["target_speaker"]),
            "audio": str(mapping["target_audio"]),
        }
        previous = rows.setdefault(identifier, row)
        if previous != row:
            raise ValueError(f"Conflicting target metadata for {identifier}")

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="utf-8") as handle:
        for identifier in sorted(rows):
            handle.write(json.dumps(rows[identifier], sort_keys=True) + "\n")
    print(json.dumps({"rows": len(rows), "out": str(out.resolve())}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
