from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import pytest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "verify_training_data_marker.py"


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


@pytest.fixture
def workdir():
    root = SCRIPT.parents[1] / "tmp"
    root.mkdir(exist_ok=True)
    path = Path(tempfile.mkdtemp(prefix="test-marker-", dir=root))
    try:
        yield path
    finally:
        shutil.rmtree(path)


def test_marker_matches_current_inputs(workdir: Path) -> None:
    records = workdir / "unit_records.jsonl"
    embeddings = workdir / "speakers.npz"
    marker = workdir / "ready.json"
    records.write_text('{"id": "a"}\n{"id": "b"}\n', encoding="utf-8")
    embeddings.write_bytes(b"npz")
    marker.write_text(
        json.dumps(
            {
                "records_rows": 2,
                "records_sha256": _sha256(records),
                "embeddings_sha256": _sha256(embeddings),
            }
        ),
        encoding="utf-8",
    )
    completed = subprocess.run(
        [
            sys.executable,
            str(SCRIPT),
            "--records",
            str(records),
            "--embeddings",
            str(embeddings),
            "--marker",
            str(marker),
            "--expected-rows",
            "2",
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    assert completed.returncode == 0, completed.stderr
    assert '"records_rows": 2' in completed.stdout


def test_marker_rejects_changed_records(workdir: Path) -> None:
    records = workdir / "unit_records.jsonl"
    embeddings = workdir / "speakers.npz"
    marker = workdir / "ready.json"
    records.write_text('{"id": "a"}\n', encoding="utf-8")
    embeddings.write_bytes(b"npz")
    marker.write_text(
        json.dumps(
            {
                "records_rows": 1,
                "records_sha256": "stale",
                "embeddings_sha256": _sha256(embeddings),
            }
        ),
        encoding="utf-8",
    )
    completed = subprocess.run(
        [
            sys.executable,
            str(SCRIPT),
            "--records",
            str(records),
            "--embeddings",
            str(embeddings),
            "--marker",
            str(marker),
            "--expected-rows",
            "1",
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    assert completed.returncode != 0
    assert "does not match" in completed.stderr
