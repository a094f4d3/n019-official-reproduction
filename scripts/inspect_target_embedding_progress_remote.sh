#!/usr/bin/env bash

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

source "$ROOT/hpc/activate_n019_official.sh" >/dev/null

SHARD_ROOT="${1:-$N019_OFFICIAL_DATA/processed/embeddings/librispeech_train_clean_360_target_nt_utterance_shards}"
export SHARD_ROOT

python - <<'PY'
import json
import os
from pathlib import Path

import numpy as np

root = Path(os.environ["SHARD_ROOT"])
report = []
for shard in sorted(root.glob("shard_*")):
    partial = shard / "partial_embeddings.npz"
    complete = shard / "nt_utterance_embeddings.npz"
    if not partial.is_file() and not complete.is_file():
        report.append(
            {
                "shard": shard.name,
                "state": "missing",
            }
        )
        continue
    path = complete if complete.is_file() else partial
    archive = np.load(path, allow_pickle=False)
    keys = list(archive.files)
    last_shape = None
    last_finite = None
    last_norm = None
    if keys:
        last = archive[keys[-1]].astype(np.float32)
        last_shape = list(last.shape)
        last_finite = bool(np.isfinite(last).all())
        last_norm = float(np.linalg.norm(last))
    archive.close()
    report.append(
        {
            "shard": shard.name,
            "state": "complete" if complete.is_file() else "partial",
            "path": str(path),
            "bytes": path.stat().st_size,
            "mtime": path.stat().st_mtime,
            "count": len(keys),
            "first_id": keys[0] if keys else None,
            "last_id": keys[-1] if keys else None,
            "last_shape": last_shape,
            "last_finite": last_finite,
            "last_norm": last_norm,
        }
    )

print(json.dumps(report, ensure_ascii=False, indent=2))
PY
