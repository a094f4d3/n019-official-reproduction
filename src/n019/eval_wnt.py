"""Score VPC trials with the official orange/Speaker-wavLM-pro model."""

from __future__ import annotations

import argparse
import csv
import json
from collections import defaultdict
from pathlib import Path

import torch
import torch.nn.functional as F

from n019.metrics import equal_error_rate
from n019.speaker import SpeakerEmbedder


def read_kaldi_map(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    with path.open(encoding="utf-8") as handle:
        for line_number, raw in enumerate(handle, 1):
            fields = raw.strip().split(maxsplit=1)
            if len(fields) != 2:
                raise ValueError(f"Invalid mapping at {path}:{line_number}")
            result[fields[0]] = fields[1]
    return result


def resolve_audio(
    directory: Path,
    value: str,
    *,
    vpc_data_root: Path,
) -> Path:
    path = Path(value)
    candidates = [
        path,
        directory / path,
        vpc_data_root / path,
    ]
    for candidate in candidates:
        if candidate.is_file():
            return candidate.resolve()
    raise FileNotFoundError(f"Cannot resolve {value} from {directory}")


def read_trials(path: Path) -> list[tuple[str, str, str]]:
    trials = []
    with path.open(encoding="utf-8") as handle:
        for line_number, raw in enumerate(handle, 1):
            fields = raw.strip().split()
            if len(fields) != 3:
                raise ValueError(f"Invalid trial at {path}:{line_number}")
            enrollment, trial, label = fields
            if label not in {"target", "nontarget"}:
                raise ValueError(f"Invalid label at {path}:{line_number}")
            trials.append((enrollment, trial, label))
    if not trials:
        raise ValueError(f"Empty trial file: {path}")
    return trials


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--vpc-data-root", required=True)
    parser.add_argument("--enroll-dir", required=True)
    parser.add_argument("--trial-dir", required=True)
    parser.add_argument("--trials", required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--device", default="cuda")
    parser.add_argument(
        "--attack-label",
        choices=["I", "L", "S"],
        default="I",
        help="VPC attack label recorded with the score file.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    device = torch.device(args.device)
    enroll_dir = Path(args.enroll_dir).resolve()
    trial_dir = Path(args.trial_dir).resolve()
    trials_path = Path(args.trials).resolve()
    data_root = Path(args.vpc_data_root).resolve()

    enroll_wavs = read_kaldi_map(enroll_dir / "wav.scp")
    enroll_utt2spk = read_kaldi_map(enroll_dir / "utt2spk")
    trial_wavs = read_kaldi_map(trial_dir / "wav.scp")
    trials = read_trials(trials_path)
    required_speakers = {row[0] for row in trials}
    required_trials = {row[1] for row in trials}

    embedder = SpeakerEmbedder("nt", args.model, device)
    speaker_vectors: dict[str, list[torch.Tensor]] = defaultdict(list)
    for utterance, speaker in enroll_utt2spk.items():
        if speaker not in required_speakers:
            continue
        if utterance not in enroll_wavs:
            raise KeyError(f"Missing enrollment wav.scp entry: {utterance}")
        audio = resolve_audio(
            enroll_dir,
            enroll_wavs[utterance],
            vpc_data_root=data_root,
        )
        speaker_vectors[speaker].append(embedder.embed_file(audio))
    missing_speakers = sorted(required_speakers - set(speaker_vectors))
    if missing_speakers:
        raise KeyError(f"Missing enrollment speakers: {missing_speakers[:10]}")
    speaker_means = {
        speaker: F.normalize(torch.stack(vectors).mean(dim=0), dim=0)
        for speaker, vectors in speaker_vectors.items()
    }

    trial_vectors: dict[str, torch.Tensor] = {}
    for utterance in sorted(required_trials):
        if utterance not in trial_wavs:
            raise KeyError(f"Missing trial wav.scp entry: {utterance}")
        audio = resolve_audio(
            trial_dir,
            trial_wavs[utterance],
            vpc_data_root=data_root,
        )
        trial_vectors[utterance] = embedder.embed_file(audio)

    labels = []
    scores = []
    details = []
    for enrollment, trial, label in trials:
        score = float(
            torch.dot(speaker_means[enrollment], trial_vectors[trial]).cpu()
        )
        labels.append(1 if label == "target" else 0)
        scores.append(score)
        details.append(
            {
                "enrollment": enrollment,
                "trial": trial,
                "label": label,
                "score": score,
            }
        )
    from speechbrain.utils.metric_stats import EER

    er_metrics = equal_error_rate(labels, scores)
    positive_scores = torch.tensor(
        [score for label, score in zip(labels, scores) if label == 1],
        dtype=torch.float32,
    )
    negative_scores = torch.tensor(
        [score for label, score in zip(labels, scores) if label == 0],
        dtype=torch.float32,
    )
    eer_tensor, eer_threshold = EER(positive_scores, negative_scores)
    eer = float(eer_tensor)
    metrics = {
        "eer": eer,
        "eer_percent": eer * 100.0,
        "eer_threshold": float(eer_threshold),
        "eer_implementation": "speechbrain_0.5.16",
        "eer_crosscheck": er_metrics,
        "trials": len(trials),
        "enrollment_speakers": len(speaker_means),
        "trial_utterances": len(trial_vectors),
        "model": str(Path(args.model).resolve()),
        "attack": args.attack_label,
        "enroll_dir": str(enroll_dir),
        "trial_dir": str(trial_dir),
        "trials_file": str(trials_path),
    }
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(metrics, indent=2), encoding="utf-8")
    score_path = out.with_suffix(".scores.tsv")
    with score_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["enrollment", "trial", "label", "score"],
            delimiter="\t",
        )
        writer.writeheader()
        writer.writerows(details)
    print(json.dumps(metrics, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
