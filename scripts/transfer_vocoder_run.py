"""Transfer a complete vocoder run between SCNet accounts through local staging."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shlex
import shutil
import subprocess
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-host", required=True)
    parser.add_argument("--target-host", required=True)
    parser.add_argument("--run-name", required=True)
    parser.add_argument("--chunk-mib", type=int, default=64)
    parser.add_argument("--retries", type=int, default=8)
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--keep-local", action="store_true")
    return parser.parse_args()


def sha256_local(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(8 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def run_checked(
    command: list[str],
    *,
    retries: int,
    timeout: int = 3600,
) -> str:
    last_error = ""
    for attempt in range(1, retries + 1):
        completed = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        if completed.returncode == 0:
            return completed.stdout
        last_error = completed.stderr.strip() or completed.stdout.strip()
        if attempt < retries:
            time.sleep(min(5 * attempt, 20))
    raise RuntimeError(
        f"Command failed after {retries} attempts: {command[0]}; {last_error}"
    )


def ssh(host: str, command: str, *, retries: int) -> str:
    return run_checked(
        [
            "ssh",
            "-o",
            "ConnectTimeout=30",
            host,
            command,
        ],
        retries=retries,
    )


def scp(source: str, destination: str, *, retries: int) -> None:
    run_checked(
        [
            "scp",
            "-O",
            "-o",
            "ConnectTimeout=30",
            source,
            destination,
        ],
        retries=retries,
    )


def remote_user(host: str, *, retries: int) -> str:
    values = [
        line.strip()
        for line in ssh(host, "id -un", retries=retries).splitlines()
        if line.strip()
    ]
    if not values:
        raise RuntimeError(f"Cannot determine remote user for {host}")
    return values[-1]


def remote_sha(host: str, path: str, *, retries: int) -> str:
    output = ssh(
        host,
        f"sha256sum {shlex.quote(path)}",
        retries=retries,
    )
    fields = output.strip().split()
    if not fields or not re.fullmatch(r"[0-9a-f]{64}", fields[0]):
        raise RuntimeError(f"Unexpected sha256sum output for {host}:{path}")
    return fields[0]


def remote_size(host: str, path: str, *, retries: int) -> int:
    output = ssh(
        host,
        f"stat -c %s {shlex.quote(path)}",
        retries=retries,
    )
    return int(output.strip().splitlines()[-1])


def main() -> int:
    args = parse_args()
    if not re.fullmatch(r"[A-Za-z0-9._-]+", args.run_name):
        raise ValueError("run-name contains unsupported characters")
    if args.chunk_mib <= 0 or args.retries <= 0:
        raise ValueError("chunk-mib and retries must be positive")

    source_user = remote_user(args.source_host, retries=args.retries)
    target_user = remote_user(args.target_host, retries=args.retries)
    source_run = (
        f"/public/home/{source_user}/voice_projects/runs/"
        f"n019_official/{args.run_name}"
    )
    target_run = (
        f"/public/home/{target_user}/voice_projects/runs/"
        f"n019_official/{args.run_name}"
    )
    required = ["last.pt", "meta.json", "training_log.jsonl", "launch.txt"]
    files = list(required)
    best_path = f"{source_run}/best.pt"
    try:
        if remote_size(args.source_host, best_path, retries=1) > 0:
            files.append("best.pt")
    except RuntimeError:
        pass
    for name in required:
        path = f"{source_run}/{name}"
        try:
            size = remote_size(args.source_host, path, retries=args.retries)
        except RuntimeError as error:
            raise FileNotFoundError(f"Missing source file: {path}") from error
        if size <= 0:
            raise FileNotFoundError(f"Missing source file: {path}")

    if not args.overwrite:
        try:
            target_has_last = remote_size(
                args.target_host,
                f"{target_run}/last.pt",
                retries=1,
            ) > 0
        except RuntimeError:
            target_has_last = False
        if target_has_last:
            raise FileExistsError(
                f"Target already has last.pt: {target_run}; pass --overwrite"
            )

    source_hashes = {
        name: remote_sha(
            args.source_host,
            f"{source_run}/{name}",
            retries=args.retries,
        )
        for name in files
    }
    token = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    archive_name = f"{args.run_name}.{token}.resume.tar"
    source_stage = f"{source_run}/_transfer"
    source_archive = f"{source_stage}/{archive_name}"
    quoted_files = " ".join(shlex.quote(name) for name in files)
    ssh(
        args.source_host,
        (
            f"mkdir -p {shlex.quote(source_stage)} && "
            f"tar -cf {shlex.quote(source_archive)} "
            f"-C {shlex.quote(source_run)} {quoted_files}"
        ),
        retries=args.retries,
    )
    archive_sha = remote_sha(
        args.source_host,
        source_archive,
        retries=args.retries,
    )
    archive_bytes = remote_size(
        args.source_host,
        source_archive,
        retries=args.retries,
    )

    chunk_bytes = args.chunk_mib * 1024 * 1024
    ssh(
        args.source_host,
        (
            f"split -b {chunk_bytes} -d -a 4 "
            f"{shlex.quote(source_archive)} {shlex.quote(source_archive + '.part-')}"
        ),
        retries=args.retries,
    )
    listing = ssh(
        args.source_host,
        (
            f"find {shlex.quote(source_stage)} -maxdepth 1 -type f "
            f"-name {shlex.quote(archive_name + '.part-*')} "
            "-printf '%f %s\\n' | sort"
        ),
        retries=args.retries,
    )
    chunks = []
    for line in listing.splitlines():
        fields = line.split()
        if len(fields) == 2:
            chunks.append((fields[0], int(fields[1])))
    if not chunks or sum(size for _, size in chunks) != archive_bytes:
        raise RuntimeError("Split archive chunks are missing or have wrong sizes")

    local_root = Path(
        tempfile.mkdtemp(prefix=f"n019-{args.run_name}-")
    ).resolve()
    local_chunks = local_root / "chunks"
    local_chunks.mkdir()
    try:
        for name, expected_size in chunks:
            local_path = local_chunks / name
            remote_path = f"{source_stage}/{name}"
            expected_hash = remote_sha(
                args.source_host,
                remote_path,
                retries=args.retries,
            )
            for attempt in range(1, args.retries + 1):
                try:
                    scp(
                        f"{args.source_host}:{remote_path}",
                        str(local_path),
                        retries=1,
                    )
                except RuntimeError:
                    pass
                if (
                    local_path.is_file()
                    and local_path.stat().st_size == expected_size
                    and sha256_local(local_path) == expected_hash
                ):
                    break
                if attempt == args.retries:
                    raise RuntimeError(f"Failed to download chunk: {name}")
                time.sleep(min(5 * attempt, 20))

        local_archive = local_root / archive_name
        with local_archive.open("wb") as output:
            for name, _ in chunks:
                with (local_chunks / name).open("rb") as source:
                    shutil.copyfileobj(source, output)
        if sha256_local(local_archive) != archive_sha:
            raise RuntimeError("Assembled local archive SHA256 mismatch")

        target_stage = f"{target_run}/_transfer"
        ssh(
            args.target_host,
            (
                f"mkdir -p {shlex.quote(target_run)} "
                f"{shlex.quote(target_stage)}"
            ),
            retries=args.retries,
        )
        for name, expected_size in chunks:
            local_path = local_chunks / name
            remote_path = f"{target_stage}/{name}"
            expected_hash = sha256_local(local_path)
            for attempt in range(1, args.retries + 1):
                try:
                    scp(
                        str(local_path),
                        f"{args.target_host}:{remote_path}",
                        retries=1,
                    )
                except RuntimeError:
                    pass
                try:
                    actual_size = remote_size(
                        args.target_host,
                        remote_path,
                        retries=1,
                    )
                    actual_hash = remote_sha(
                        args.target_host,
                        remote_path,
                        retries=1,
                    )
                except RuntimeError:
                    actual_size = -1
                    actual_hash = ""
                if actual_size == expected_size and actual_hash == expected_hash:
                    break
                if attempt == args.retries:
                    raise RuntimeError(f"Failed to upload chunk: {name}")
                time.sleep(min(5 * attempt, 20))

        target_archive = f"{target_stage}/{archive_name}"
        concat_command = (
            f"cat {shlex.quote(target_stage)}/{archive_name}.part-* "
            f"> {shlex.quote(target_archive)} && "
            f"tar -xf {shlex.quote(target_archive)} "
            f"-C {shlex.quote(target_run)}"
        )
        ssh(args.target_host, concat_command, retries=args.retries)

        final_hashes = {}
        for name in files:
            actual = remote_sha(
                args.target_host,
                f"{target_run}/{name}",
                retries=args.retries,
            )
            if actual != source_hashes[name]:
                raise RuntimeError(f"Target SHA256 mismatch: {name}")
            final_hashes[name] = actual

        manifest = {
            "source_host": args.source_host,
            "source_user": source_user,
            "target_host": args.target_host,
            "target_user": target_user,
            "run_name": args.run_name,
            "archive_bytes": archive_bytes,
            "archive_sha256": archive_sha,
            "chunks": len(chunks),
            "files": final_hashes,
            "completed_at": datetime.now(timezone.utc).isoformat(),
        }
        manifest_path = local_root / "transfer_manifest.json"
        manifest_path.write_text(
            json.dumps(manifest, indent=2) + "\n",
            encoding="utf-8",
        )
        print(json.dumps(manifest, indent=2))
        if args.keep_local:
            print(f"LOCAL_STAGING={local_root}")
        return 0
    finally:
        if not args.keep_local:
            shutil.rmtree(local_root, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
