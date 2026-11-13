#!/usr/bin/env python3

from __future__ import annotations

import argparse
import os
import shutil
import tarfile
import threading
import time
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract a plain tar archive with parallel file writes."
    )
    parser.add_argument("--tar", type=Path, required=True)
    parser.add_argument("--dest", type=Path, required=True)
    parser.add_argument("--workers", type=int, default=16)
    return parser.parse_args()


def safe_target(root: Path, name: str) -> Path:
    target = (root / name).resolve()
    try:
        target.relative_to(root)
    except ValueError as exc:
        raise ValueError(f"Unsafe tar path: {name}") from exc
    return target


def main() -> int:
    args = parse_args()
    tar_path = args.tar.resolve()
    destination = args.dest.resolve()
    destination.mkdir(parents=True, exist_ok=True)

    with tarfile.open(tar_path, mode="r:") as archive:
        members = archive.getmembers()

    directories = [member for member in members if member.isdir()]
    files = [
        member
        for member in members
        if member.isfile() or member.islnk() or member.issym()
    ]
    for member in directories:
        safe_target(destination, member.name).mkdir(parents=True, exist_ok=True)

    completed = 0
    skipped = 0
    lock = threading.Lock()
    stop = threading.Event()
    errors: list[str] = []

    def worker(items: list[tarfile.TarInfo]) -> None:
        nonlocal completed, skipped
        try:
            with tar_path.open("rb") as source:
                for member in items:
                    if stop.is_set():
                        return
                    target = safe_target(destination, member.name)
                    target.parent.mkdir(parents=True, exist_ok=True)

                    if member.isfile():
                        if target.is_file() and target.stat().st_size == member.size:
                            with lock:
                                skipped += 1
                            continue
                        temporary = target.with_name(
                            f".{target.name}.part.{os.getpid()}"
                        )
                        source.seek(member.offset_data)
                        remaining = member.size
                        with temporary.open("wb") as output:
                            while remaining:
                                block = source.read(min(1024 * 1024, remaining))
                                if not block:
                                    raise EOFError(
                                        f"Unexpected EOF extracting {member.name}"
                                    )
                                output.write(block)
                                remaining -= len(block)
                        os.chmod(temporary, member.mode)
                        os.replace(temporary, target)
                        os.utime(
                            target,
                            (member.mtime, member.mtime),
                            follow_symlinks=False,
                        )
                    elif member.issym():
                        if not target.exists():
                            target.symlink_to(member.linkname)
                    elif member.islnk():
                        link_target = safe_target(destination, member.linkname)
                        if not target.exists():
                            os.link(link_target, target)

                    with lock:
                        completed += 1
        except BaseException as exc:
            errors.append(repr(exc))
            stop.set()

    partitions: list[list[tarfile.TarInfo]] = [
        [] for _ in range(args.workers)
    ]
    for index, member in enumerate(files):
        partitions[index % args.workers].append(member)

    print(
        f"members={len(members)} files={len(files)} workers={args.workers}",
        flush=True,
    )
    threads = [
        threading.Thread(target=worker, args=(partition,), daemon=True)
        for partition in partitions
    ]
    started = time.monotonic()
    for thread in threads:
        thread.start()
    while any(thread.is_alive() for thread in threads):
        if errors:
            stop.set()
            break
        time.sleep(5)
        with lock:
            current = completed + skipped
        elapsed = max(1e-6, time.monotonic() - started)
        print(
            f"progress={current}/{len(files)} "
            f"rate_files_s={current / elapsed:.1f}",
            flush=True,
        )
    for thread in threads:
        thread.join()

    if errors:
        raise RuntimeError("\n".join(errors))
    if completed + skipped != len(files):
        raise RuntimeError(
            f"Incomplete: {completed + skipped} != {len(files)}"
        )
    print(
        f"complete files={len(files)} created={completed} skipped={skipped}",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
