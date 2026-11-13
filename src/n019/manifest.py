"""Stable JSONL manifest and provenance helpers."""

from __future__ import annotations

import hashlib
import json
import os
import re
import tempfile
import time
from pathlib import Path
from typing import Iterable, Iterator


def iter_jsonl(path: str | Path) -> Iterator[dict]:
    with Path(path).open("r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, 1):
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError as exc:
                raise ValueError(f"Invalid JSON at {path}:{line_number}") from exc


def read_jsonl(path: str | Path) -> list[dict]:
    return list(iter_jsonl(path))


def _temporary_sibling(destination: Path) -> Path:
    """Create a unique temporary file beside an atomic-write destination."""
    destination.parent.mkdir(parents=True, exist_ok=True)
    descriptor, path = tempfile.mkstemp(
        prefix=f".{destination.name}.",
        suffix=".tmp",
        dir=destination.parent,
    )
    os.close(descriptor)
    return Path(path)


def _replace_with_retry(temporary: Path, destination: Path) -> None:
    """Retry short Windows sharing violations during concurrent publishes."""
    for attempt in range(10):
        try:
            os.replace(temporary, destination)
            return
        except PermissionError:
            if attempt == 9:
                raise
            time.sleep(0.01 * (attempt + 1))


def write_jsonl(path: str | Path, rows: Iterable[dict]) -> None:
    destination = Path(path)
    temporary = _temporary_sibling(destination)
    try:
        with temporary.open("w", encoding="utf-8") as handle:
            for row in rows:
                handle.write(
                    json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n"
                )
        _replace_with_retry(temporary, destination)
    except BaseException:
        temporary.unlink(missing_ok=True)
        raise


def append_jsonl(handle, rows: Iterable[dict]) -> None:
    """Append records and make them durable before returning."""
    for row in rows:
        handle.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")
    handle.flush()
    os.fsync(handle.fileno())


def read_json(path: str | Path) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def write_json(path: str | Path, value: dict) -> None:
    destination = Path(path)
    temporary = _temporary_sibling(destination)
    try:
        temporary.write_text(
            json.dumps(value, indent=2, ensure_ascii=True, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        _replace_with_retry(temporary, destination)
    except BaseException:
        temporary.unlink(missing_ok=True)
        raise


def sha256_file(path: str | Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for block in iter(lambda: handle.read(16 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def utterance_id(row: dict) -> str:
    value = row.get("id") or row.get("utterance_id") or Path(row["audio"]).stem
    return str(value)


def speaker_id(row: dict) -> str:
    value = row.get("speaker") or row.get("speaker_id")
    if value is None:
        raise KeyError("Manifest row has neither speaker nor speaker_id")
    return str(value)


def safe_filename(identifier: str, suffix: str = "") -> str:
    """Return a cross-platform filename that still encodes the full ID."""
    digest = hashlib.sha256(identifier.encode("utf-8")).hexdigest()[:12]
    stem = re.sub(r"[^A-Za-z0-9._-]+", "_", identifier).strip("._-")
    if not stem:
        stem = "utterance"
    return f"{stem[:160]}_{digest}{suffix}"
