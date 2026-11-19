#!/usr/bin/env python3
"""Summarize billable SCNet HPC elapsed time for the fixed d10 account."""

from __future__ import annotations

import argparse
import subprocess


def elapsed_seconds(value: str) -> int:
    days, _, clock = value.partition("-")
    if not clock:
        days = "0"
        clock = value
    hours, minutes, seconds = (int(part) for part in clock.split(":"))
    return (
        int(days) * 86400
        + hours * 3600
        + minutes * 60
        + seconds
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="scnet-a094f4d10")
    parser.add_argument("--starttime", default="2026-11-16T00:00:00")
    args = parser.parse_args()

    result = subprocess.run(
        [
            "ssh",
            args.host,
            "sacct",
            "-u",
            "a094f4d10",
            f"--starttime={args.starttime}",
            "--format=JobID,AllocTRES,Elapsed",
            "-P",
        ],
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )

    jobs = 0
    total_seconds = 0
    for line in result.stdout.splitlines():
        if not line or line.startswith("JobID|"):
            continue
        job_id, allocation, elapsed = line.split("|")
        if "." in job_id or "billing=" not in allocation:
            continue
        jobs += 1
        total_seconds += elapsed_seconds(elapsed)

    total_hours = total_seconds / 3600
    print(f"jobs={jobs}")
    print(f"elapsed_seconds={total_seconds}")
    print(f"elapsed_hours={total_hours:.4f}")
    print(f"remaining_hours_of_50={50.0 - total_hours:.4f}")


if __name__ == "__main__":
    main()
