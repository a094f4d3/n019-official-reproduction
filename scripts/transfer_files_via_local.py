"""Transfer generated files between SCNet accounts through local staging.

The transfer is deliberately file-oriented: source and target SHA256 values
must match the checksums declared in the JSON configuration before a target
path is replaced.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shlex
import subprocess
import tempfile
import time
import uuid
from pathlib import Path

import paramiko


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(8 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def ssh_config(host: str) -> dict[str, str]:
    completed = subprocess.run(
        ["ssh", "-G", host],
        check=True,
        capture_output=True,
        text=True,
    )
    values: dict[str, list[str]] = {}
    for line in completed.stdout.splitlines():
        key, _, value = line.partition(" ")
        if value:
            values.setdefault(key.lower(), []).append(value)
    required = {"hostname", "user", "port", "identityfile"}
    if not required.issubset(values):
        missing = ", ".join(sorted(required - values.keys()))
        raise RuntimeError(f"SSH config for {host} is missing: {missing}")
    identity = next(
        (
            str(Path(value).expanduser())
            for value in values["identityfile"]
            if Path(value).expanduser().is_file()
        ),
        None,
    )
    if identity is None:
        raise FileNotFoundError(f"No readable identity file for {host}")
    return {
        "hostname": values["hostname"][0],
        "user": values["user"][0],
        "port": values["port"][0],
        "identity": identity,
    }


def connect(host: str) -> paramiko.SSHClient:
    config = ssh_config(host)
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(
        hostname=config["hostname"],
        port=int(config["port"]),
        username=config["user"],
        key_filename=config["identity"],
        allow_agent=False,
        look_for_keys=False,
        timeout=30,
        banner_timeout=30,
        auth_timeout=30,
    )
    return client


def remote_sha256(client: paramiko.SSHClient, path: str) -> str:
    _, stdout, stderr = client.exec_command(
        f"sha256sum {shlex.quote(path)}",
        timeout=120,
    )
    output = stdout.read().decode("utf-8", errors="replace").strip()
    error = stderr.read().decode("utf-8", errors="replace").strip()
    if stdout.channel.recv_exit_status() != 0:
        raise RuntimeError(f"Cannot hash {path}: {error}")
    fields = output.split()
    if not fields or not re.fullmatch(r"[0-9a-f]{64}", fields[0]):
        raise RuntimeError(f"Unexpected sha256sum output for {path}: {output}")
    return fields[0]


def remote_exists(client: paramiko.SSHClient, path: str) -> bool:
    sftp = client.open_sftp()
    try:
        sftp.stat(path)
        return True
    except FileNotFoundError:
        return False
    finally:
        sftp.close()


def ensure_remote_dir(sftp: paramiko.SFTPClient, path: str) -> None:
    directory = path.rstrip("/")
    missing: list[str] = []
    while directory and directory != "/":
        try:
            sftp.stat(directory)
            break
        except FileNotFoundError:
            missing.append(directory)
            directory = directory.rsplit("/", 1)[0]
    for item in reversed(missing):
        sftp.mkdir(item)


def transfer_entry(
    entry: dict[str, str],
    staging: Path,
    overwrite: bool,
) -> dict[str, str]:
    source = (
        None
        if entry["source_host"] == "local"
        else connect(entry["source_host"])
    )
    target = connect(entry["target_host"])
    try:
        source_path = entry["source_path"]
        target_path = entry["target_path"]
        expected = entry["sha256"].lower()
        if not re.fullmatch(r"[0-9a-f]{64}", expected):
            raise ValueError(f"Invalid expected SHA256 for {source_path}")

        if source is None:
            local_source = Path(source_path).resolve()
            source_stat = local_source.stat()
            if source_stat.st_size <= 0:
                raise RuntimeError(f"Empty source file: {local_source}")
            source_sha = sha256_file(local_source)
            local_path = local_source
        else:
            sftp = source.open_sftp()
            try:
                source_stat = sftp.stat(source_path)
                if source_stat.st_size <= 0:
                    raise RuntimeError(f"Empty source file: {source_path}")
            finally:
                sftp.close()
            source_sha = remote_sha256(source, source_path)
        if source_sha != expected:
            raise RuntimeError(f"Source SHA256 mismatch: {source_path}")

        if source is not None:
            local_path = staging / entry["local_name"]
            local_path.parent.mkdir(parents=True, exist_ok=True)
            if (
                not local_path.is_file()
                or local_path.stat().st_size != source_stat.st_size
                or sha256_file(local_path) != expected
            ):
                temporary = local_path.with_name(local_path.name + ".incoming")
                source_sftp = source.open_sftp()
                try:
                    source_sftp.get(source_path, str(temporary))
                finally:
                    source_sftp.close()
                if (
                    temporary.stat().st_size != source_stat.st_size
                    or sha256_file(temporary) != expected
                ):
                    raise RuntimeError(
                        f"Downloaded SHA256 mismatch: {source_path}"
                    )
                os.replace(temporary, local_path)

        if remote_exists(target, target_path):
            target_sha = remote_sha256(target, target_path)
            if target_sha == expected:
                return {
                    "source_path": source_path,
                    "target_path": target_path,
                    "sha256": expected,
                    "bytes": str(source_stat.st_size),
                    "action": "unchanged",
                }
            if not overwrite:
                raise FileExistsError(
                    f"Target exists with a different SHA256: {target_path}"
                )

        target_sftp = target.open_sftp()
        temporary = f"{target_path}.incoming.{uuid.uuid4().hex}"
        try:
            ensure_remote_dir(target_sftp, target_path.rsplit("/", 1)[0])
            target_sftp.put(str(local_path), temporary)
            target_sftp.chmod(temporary, 0o664)
        finally:
            target_sftp.close()

        uploaded_sha = remote_sha256(target, temporary)
        if uploaded_sha != expected:
            target.exec_command(f"rm -f {shlex.quote(temporary)}", timeout=30)
            raise RuntimeError(f"Uploaded SHA256 mismatch: {target_path}")

        target_sftp = target.open_sftp()
        try:
            if remote_exists(target, target_path) and not overwrite:
                raise FileExistsError(
                    f"Target appeared during transfer: {target_path}"
                )
            target_sftp.posix_rename(temporary, target_path)
        finally:
            target_sftp.close()

        final_sha = remote_sha256(target, target_path)
        if final_sha != expected:
            raise RuntimeError(f"Final target SHA256 mismatch: {target_path}")
        return {
            "source_path": source_path,
            "target_path": target_path,
            "sha256": expected,
            "bytes": str(source_stat.st_size),
            "action": "replaced" if overwrite else "created",
        }
    finally:
        if source is not None:
            source.close()
        target.close()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    parser.add_argument("--staging-root")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--retries", type=int, default=3)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    config = json.loads(Path(args.config).read_text(encoding="utf-8"))
    entries = config.get("files", [])
    if not entries:
        raise ValueError("Transfer config contains no files")

    if args.staging_root:
        staging = Path(args.staging_root).resolve()
    else:
        stamp = time.strftime("%Y%m%d_%H%M%S")
        staging = Path(tempfile.gettempdir()) / f"n019-transfer-{stamp}"
    staging.mkdir(parents=True, exist_ok=True)

    results = []
    for entry in entries:
        last_error: Exception | None = None
        for attempt in range(1, args.retries + 1):
            try:
                result = transfer_entry(entry, staging, args.overwrite)
                results.append(result)
                last_error = None
                break
            except Exception as error:
                last_error = error
                if attempt < args.retries:
                    time.sleep(min(5 * attempt, 15))
        if last_error is not None:
            raise RuntimeError(
                f"Transfer failed for {entry['source_path']}: {last_error}"
            )

    manifest = {
        "config": str(Path(args.config).resolve()),
        "staging_root": str(staging),
        "files": results,
    }
    manifest_path = staging / "transfer_manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(manifest, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
