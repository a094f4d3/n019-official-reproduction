#!/usr/bin/env python3

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import socket
import sys
import threading
import time
import urllib.error
import urllib.request
from pathlib import Path


USER_AGENT = "n019-official-data/1.0"
CHUNK_READ = 1024 * 1024

_ORIGINAL_GETADDRINFO = socket.getaddrinfo


def _ipv4_getaddrinfo(*args, **kwargs):
    results = _ORIGINAL_GETADDRINFO(*args, **kwargs)
    ipv4_results = [
        result for result in results if result[0] == socket.AF_INET
    ]
    return ipv4_results or results


socket.getaddrinfo = _ipv4_getaddrinfo


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Parallel HTTP Range downloader with resumable chunk state."
    )
    parser.add_argument("--url", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--expected-md5")
    parser.add_argument("--expected-sha256")
    parser.add_argument("--connections", type=int, default=16)
    parser.add_argument("--retries", type=int, default=30)
    return parser.parse_args()


def request(url: str, start: int | None = None) -> urllib.request.addinfourl:
    headers = {"User-Agent": USER_AGENT, "Accept-Encoding": "identity"}
    if start is not None:
        headers["Range"] = f"bytes={start}-"
    req = urllib.request.Request(url, headers=headers)
    return urllib.request.urlopen(req, timeout=90)


def remote_size(url: str) -> int:
    with request(url, 0) as response:
        content_range = response.headers.get("Content-Range", "")
        if response.status == 206 and "/" in content_range:
            return int(content_range.rsplit("/", 1)[1])
        length = response.headers.get("Content-Length")
        if length is None:
            raise RuntimeError("Server did not provide Content-Length")
        return int(length)


def hash_file(path: Path, algorithm: str) -> str:
    digest = hashlib.new(algorithm)
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(16 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_state(path: Path, url: str, total: int, connections: int) -> dict:
    if path.is_file():
        state = json.loads(path.read_text(encoding="utf-8"))
        if (
            state.get("url") == url
            and state.get("total") == total
            and len(state.get("chunks", [])) == connections
        ):
            return state
    chunk_size = math.ceil(total / connections)
    chunks = []
    for index in range(connections):
        start = index * chunk_size
        end = min(total - 1, (index + 1) * chunk_size - 1)
        chunks.append({"start": start, "end": end, "done": 0})
    return {"url": url, "total": total, "chunks": chunks}


class Downloader:
    def __init__(
        self,
        url: str,
        part_path: Path,
        state_path: Path,
        state: dict,
        retries: int,
    ) -> None:
        self.url = url
        self.part_path = part_path
        self.state_path = state_path
        self.state = state
        self.retries = retries
        self.lock = threading.Lock()
        self.stop = threading.Event()
        self.error: BaseException | None = None
        self.fd = os.open(
            part_path,
            os.O_RDWR | os.O_CREAT,
            0o664,
        )
        os.ftruncate(self.fd, state["total"])

    def completed(self) -> int:
        with self.lock:
            return sum(chunk["done"] for chunk in self.state["chunks"])

    def save_state(self) -> None:
        with self.lock:
            temporary = self.state_path.with_suffix(
                self.state_path.suffix + ".tmp"
            )
            temporary.write_text(
                json.dumps(self.state, indent=2, ensure_ascii=True) + "\n",
                encoding="utf-8",
            )
            os.replace(temporary, self.state_path)

    def worker(self, index: int) -> None:
        try:
            while not self.stop.is_set():
                with self.lock:
                    chunk = self.state["chunks"][index]
                    start = chunk["start"]
                    end = chunk["end"]
                    done = chunk["done"]
                length = end - start + 1
                if done >= length:
                    return

                current = start + done
                for attempt in range(1, self.retries + 1):
                    if self.stop.is_set():
                        return
                    try:
                        with request(self.url, current) as response:
                            if response.status != 206:
                                raise RuntimeError(
                                    f"Expected HTTP 206, got {response.status}"
                                )
                            while current <= end and not self.stop.is_set():
                                data = response.read(
                                    min(CHUNK_READ, end - current + 1)
                                )
                                if not data:
                                    raise ConnectionError(
                                        "Unexpected end of response"
                                    )
                                os.pwrite(self.fd, data, current)
                                current += len(data)
                                with self.lock:
                                    chunk["done"] = current - start
                                if int(time.time()) % 5 == 0:
                                    self.save_state()
                            if current > end:
                                return
                    except Exception:
                        if attempt == self.retries:
                            raise
                        time.sleep(min(30, 2 ** min(attempt, 5)))
        except BaseException as exc:
            self.error = exc
            self.stop.set()

    def run(self) -> None:
        total = self.state["total"]
        print(
            f"total_bytes={total} connections={len(self.state['chunks'])}",
            flush=True,
        )
        threads = [
            threading.Thread(target=self.worker, args=(index,), daemon=True)
            for index in range(len(self.state["chunks"]))
        ]
        for thread in threads:
            thread.start()

        started = time.monotonic()
        try:
            while any(thread.is_alive() for thread in threads):
                if self.error is not None:
                    raise self.error
                time.sleep(10)
                completed = self.completed()
                elapsed = max(1e-6, time.monotonic() - started)
                rate = completed / elapsed
                percent = 100 * completed / total
                print(
                    f"progress={percent:.2f}% "
                    f"bytes={completed}/{total} "
                    f"rate_MBps={rate / 1024 / 1024:.2f}",
                    flush=True,
                )
        finally:
            self.stop.set()
            for thread in threads:
                thread.join(timeout=5)
            os.fsync(self.fd)
            os.close(self.fd)
            self.save_state()

        if self.error is not None:
            raise self.error
        if self.completed() != total:
            raise RuntimeError(
                f"Download incomplete: {self.completed()} != {total}"
            )


def main() -> int:
    args = parse_args()
    if bool(args.expected_md5) == bool(args.expected_sha256):
        raise ValueError("Provide exactly one of --expected-md5 or --expected-sha256")
    algorithm = "md5" if args.expected_md5 else "sha256"
    expected_hash = args.expected_md5 or args.expected_sha256
    args.output = args.output.resolve()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    part_path = args.output.with_suffix(args.output.suffix + ".parallel.part")
    state_path = args.output.with_suffix(
        args.output.suffix + ".parallel.state.json"
    )

    if args.output.is_file():
        actual = hash_file(args.output, algorithm)
        if actual == expected_hash:
            print(f"ALREADY_COMPLETE {algorithm}={actual}")
            return 0
        raise RuntimeError(
            f"Existing output has wrong {algorithm}: {actual} != {expected_hash}"
        )

    total = remote_size(args.url)
    state = load_state(
        state_path,
        args.url,
        total,
        args.connections,
    )
    downloader = Downloader(
        args.url,
        part_path,
        state_path,
        state,
        args.retries,
    )
    downloader.run()

    actual = hash_file(part_path, algorithm)
    if actual != expected_hash:
        raise RuntimeError(
            f"{algorithm} mismatch: {actual} != {expected_hash}"
        )
    os.replace(part_path, args.output)
    state_path.unlink(missing_ok=True)
    print(
        json.dumps(
            {
                "output": str(args.output),
                "size": total,
                algorithm: actual,
                "url": args.url,
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
