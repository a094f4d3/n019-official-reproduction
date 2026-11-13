#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT/hpc/activate_n019_official.sh"
cd "$ROOT"

MANIFEST="${N019_TARGET_SMOKE_MANIFEST:?Set N019_TARGET_SMOKE_MANIFEST}"
test -f "$MANIFEST"

python - "$MANIFEST" <<'PY'
import json
import os
import sys
from pathlib import Path

import soundfile as sf

rows = []
with Path(sys.argv[1]).open(encoding="utf-8") as handle:
    for line in handle:
        if line.strip():
            rows.append(json.loads(line))
        if len(rows) == 20:
            break
if len(rows) != 20:
    raise SystemExit("Need 20 manifest rows")

failures = 0
for index, row in enumerate(rows, 1):
    path = Path(row["audio"])
    try:
        stat = path.stat()
        with path.open("rb") as handle:
            prefix = handle.read(4).hex()
        audio, sample_rate = sf.read(
            str(path),
            dtype="float32",
            always_2d=True,
        )
        print(
            json.dumps(
                {
                    "index": index,
                    "path": str(path),
                    "size": stat.st_size,
                    "prefix": prefix,
                    "soundfile_shape": list(audio.shape),
                    "sample_rate": sample_rate,
                    "status": "ok",
                }
            ),
            flush=True,
        )
    except Exception as exc:
        failures += 1
        print(
            json.dumps(
                {
                    "index": index,
                    "path": str(path),
                    "uid": os.getuid(),
                    "status": "error",
                    "error": repr(exc),
                }
            ),
            flush=True,
        )

if failures:
    raise SystemExit(f"soundfile failures={failures}")
print("TARGET_AUDIO_MOUNT_SMOKE_OK")
PY
