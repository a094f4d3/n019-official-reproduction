#!/usr/bin/env python3

from __future__ import annotations

import argparse
import concurrent.futures
import os
import subprocess
import tarfile
import threading
import time
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Stream a gzip tar through parallel file writers."
    )
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--dest", type=Path, required=True)
    parser.add_argument("--workers", type=int, default=16)
    parser.add_argument("--pending", type=int, default=128)
    return parser.parse_args()


def safe_target(root: Path, name: str) -> Path:
    target = (root / name).resolve()
    try:
        target.relative_to(root)
    except ValueError as exc:
        raise ValueError(f"Unsafe tar path: {name}") from exc
    return target


def write_file(
    target: Path,
    data: bytes,
    mode: int,
    mtime: int,
) -> tuple[bool, int]:
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.is_file() and target.stat().st_size == len(data):
        return True, len(data)
    temporary = target.with_name(
        f".{target.name}.part.{threading.get_ident()}"
    )
    with temporary.open("wb") as handle:
        handle.write(data)
    os.chmod(temporary, mode)
    os.replace(temporary, target)
    os.utime(target, (mtime, mtime), follow_symlinks=False)
    return False, len(data)


def main() -> int:
    args = parse_args()
    archive = args.archive.resolve()
    destination = args.dest.resolve()
    destination.mkdir(parents=True, exist_ok=True)

    process = subprocess.Popen(
        ["pigz", "-dc", "-p", str(args.workers), str(archive)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if process.stdout is None:
        raise RuntimeError("Failed to open pigz stdout")

    semaphore = threading.Semaphore(args.pending)
    lock = threading.Lock()
    stop_progress = threading.Event()
    errors: list[str] = []
    counters = {"processed": 0, "written": 0, "skipped": 0, "bytes": 0}
    started = time.monotonic()

    def progress() -> None:
        while not stop_progress.wait(10):
            elapsed = max(1e-6, time.monotonic() - started)
            with lock:
                snapshot = dict(counters)
            print(
                f"processed={snapshot['processed']} "
                f"written={snapshot['written']} "
                f"skipped={snapshot['skipped']} "
                f"MB={snapshot['bytes'] / 1024 / 1024:.1f} "
                f"rate_MBps={snapshot['bytes'] / 1024 / 1024 / elapsed:.2f}",
                flush=True,
            )

    progress_thread = threading.Thread(target=progress, daemon=True)
    progress_thread.start()

    executor = concurrent.futures.ThreadPoolExecutor(
        max_workers=args.workers
    )
    futures: list[concurrent.futures.Future] = []

    def finished(future: concurrent.futures.Future) -> None:
        semaphore.release()
        try:
            skipped, size = future.result()
        except BaseException as exc:
            with lock:
                errors.append(repr(exc))
            return
        with lock:
            counters["processed"] += 1
            counters["bytes"] += size
            counters["skipped" if skipped else "written"] += 1

    try:
        with tarfile.open(fileobj=process.stdout, mode="r|") as tar:
            for member in tar:
                target = safe_target(destination, member.name)
                if member.isdir():
                    target.mkdir(parents=True, exist_ok=True)
                elif member.isfile():
                    source = tar.extractfile(member)
                    if source is None:
                        raise RuntimeError(
                            f"Cannot read member: {member.name}"
                        )
                    data = source.read()
                    semaphore.acquire()
                    if errors:
                        semaphore.release()
                        break
                    future = executor.submit(
                        write_file,
                        target,
                        data,
                        member.mode,
                        member.mtime,
                    )
                    future.add_done_callback(finished)
                    futures.append(future)
                elif member.issym():
                    target.parent.mkdir(parents=True, exist_ok=True)
                    if not target.exists():
                        target.symlink_to(member.linkname)
                elif member.islnk():
                    link_target = safe_target(destination, member.linkname)
                    target.parent.mkdir(parents=True, exist_ok=True)
                    if not target.exists():
                        os.link(link_target, target)
    finally:
        stop_progress.set()
        executor.shutdown(wait=True)
        if process.poll() is None:
            process.terminate()
        stderr = process.stderr.read().decode("utf-8", errors="replace") \
            if process.stderr is not None else ""
        return_code = process.wait()
        progress_thread.join(timeout=2)

    if errors:
        raise RuntimeError("\n".join(errors))
    if return_code != 0:
        raise RuntimeError(
            f"pigz exited with {return_code}: {stderr[-4000:]}"
        )

    with lock:
        snapshot = dict(counters)
    print(
        f"complete processed={snapshot['processed']} "
        f"written={snapshot['written']} skipped={snapshot['skipped']} "
        f"MB={snapshot['bytes'] / 1024 / 1024:.1f}",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
