"""Metrics used by the local N019 evaluation ladder."""

from __future__ import annotations

from collections import Counter

import numpy as np


def equal_error_rate(labels: np.ndarray, scores: np.ndarray) -> dict:
    """Compute EER and threshold for binary labels (1 = same speaker)."""
    labels = np.asarray(labels, dtype=np.int64)
    scores = np.asarray(scores, dtype=np.float64)
    if labels.shape != scores.shape:
        raise ValueError("labels and scores must have equal shape")
    if not np.any(labels == 1) or not np.any(labels == 0):
        raise ValueError("EER requires positive and negative trials")

    thresholds = np.unique(scores)
    thresholds = np.concatenate(
        [
            [thresholds[0] - 1e-8],
            (thresholds[:-1] + thresholds[1:]) / 2,
            [thresholds[-1] + 1e-8],
        ]
    )
    best = None
    for threshold in thresholds:
        predictions = scores >= threshold
        far = np.mean(predictions[labels == 0])
        frr = np.mean(~predictions[labels == 1])
        gap = abs(far - frr)
        if best is None or gap < best[0]:
            best = (gap, far, frr, threshold)
    _, far, frr, threshold = best
    return {
        "eer": float((far + frr) / 2),
        "far": float(far),
        "frr": float(frr),
        "threshold": float(threshold),
        "positive_trials": int(labels.sum()),
        "negative_trials": int((labels == 0).sum()),
    }


def edit_distance(reference: list[str], hypothesis: list[str]) -> int:
    previous = list(range(len(hypothesis) + 1))
    for i, ref_word in enumerate(reference, start=1):
        current = [i]
        for j, hyp_word in enumerate(hypothesis, start=1):
            substitution = previous[j - 1] + (ref_word != hyp_word)
            insertion = current[j - 1] + 1
            deletion = previous[j] + 1
            current.append(min(substitution, insertion, deletion))
        previous = current
    return previous[-1]


def corpus_wer(references: list[str], hypotheses: list[str]) -> dict:
    errors = 0
    words = 0
    for reference, hypothesis in zip(references, hypotheses):
        ref_tokens = reference.upper().split()
        hyp_tokens = hypothesis.upper().split()
        errors += edit_distance(ref_tokens, hyp_tokens)
        words += len(ref_tokens)
    return {
        "wer": float(errors / max(1, words)),
        "errors": errors,
        "words": words,
        "utterances": len(references),
    }


def token_frequency(text: str) -> Counter:
    return Counter(text.upper().split())
