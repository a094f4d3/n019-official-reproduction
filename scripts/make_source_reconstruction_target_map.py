#!/usr/bin/env python3
"""Build an identity-preserving target map for a privacy diagnostic."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-manifest", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--metadata", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    source = Path(args.source_manifest)
    rows = [
        json.loads(line)
        for line in source.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    if not rows:
        raise ValueError("Source manifest is empty")

    output = []
    seen: set[str] = set()
    for row in rows:
        identifier = str(row.get("id") or row.get("utterance_id") or "")
        speaker = str(row.get("speaker") or "")
        audio = str(row.get("audio") or "")
        if not identifier or not speaker or not audio:
            raise ValueError("Each source row needs id, speaker, and audio")
        if identifier in seen:
            raise ValueError(f"Duplicate source id: {identifier}")
        seen.add(identifier)
        output.append(
            {
                "source_id": identifier,
                "source_speaker": speaker,
                "source_audio": audio,
                "target_id": speaker,
                "target_speaker": speaker,
                "target_audio": audio,
                "target_selection": "source_reconstruction_diagnostic",
            }
        )

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(
        "".join(json.dumps(row, sort_keys=True) + "\n" for row in output),
        encoding="utf-8",
    )
    metadata = {
        "purpose": "source_reconstruction_diagnostic_only",
        "source_manifest": str(source.resolve()),
        "source_manifest_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "rows": len(output),
        "speakers": len({row["source_speaker"] for row in output}),
        "out": str(out.resolve()),
        "out_sha256": hashlib.sha256(out.read_bytes()).hexdigest(),
    }
    metadata_path = Path(args.metadata)
    metadata_path.parent.mkdir(parents=True, exist_ok=True)
    metadata_path.write_text(
        json.dumps(metadata, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(metadata, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
