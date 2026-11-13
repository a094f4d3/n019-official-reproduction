#!/usr/bin/env python3
"""Check that the SpeechBrain ASR frontend can resolve its Wav2Vec2 metadata."""

from __future__ import annotations

import argparse
import os

from transformers import Wav2Vec2FeatureExtractor


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cache-dir", default=None)
    args = parser.parse_args()
    print("HF_HOME", os.environ.get("HF_HOME"))
    print(
        "offline",
        os.environ.get("HF_HUB_OFFLINE"),
        os.environ.get("TRANSFORMERS_OFFLINE"),
    )
    extractor = Wav2Vec2FeatureExtractor.from_pretrained(
        "facebook/wav2vec2-large-960h-lv60-self",
        cache_dir=args.cache_dir,
    )
    print("feature_extractor_ok", extractor.sampling_rate)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
