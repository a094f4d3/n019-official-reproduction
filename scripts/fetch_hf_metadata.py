#!/usr/bin/env python3
"""Fetch selected Hugging Face files into the configured local cache."""

from __future__ import annotations

import argparse

from huggingface_hub import snapshot_download


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    parser.add_argument("--revision", default=None)
    parser.add_argument("--pattern", action="append", required=True)
    parser.add_argument("--cache-dir", default=None)
    args = parser.parse_args()
    path = snapshot_download(
        repo_id=args.repo,
        revision=args.revision,
        allow_patterns=args.pattern,
        cache_dir=args.cache_dir,
    )
    print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
