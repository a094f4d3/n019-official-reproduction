import json
import sys
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from merge_wnt_attack_summaries import merge_summaries  # noqa: E402


def _write(path: Path, attacks: dict, suffix: str = "") -> Path:
    path.write_text(
        json.dumps({"attacks": attacks, "suffix": suffix}),
        encoding="utf-8",
    )
    return path


def _attack(female: float, male: float) -> dict:
    return {
        "female_eer_percent": female,
        "male_eer_percent": male,
        "mean_eer_percent": (female + male) / 2,
    }


def test_merge_i_l_and_s(tmp_path: Path) -> None:
    il = _write(
        tmp_path / "il.json",
        {"I": _attack(30.0, 40.0), "L": _attack(32.0, 42.0)},
        "_n019",
    )
    s = _write(
        tmp_path / "s.json",
        {"S": _attack(20.0, 28.0)},
        "_n019",
    )

    merged = merge_summaries([il, s], ["I", "L", "S"])

    assert list(merged["attacks"]) == ["I", "L", "S"]
    assert merged["attacks"]["S"]["mean_eer_percent"] == 24.0
    assert merged["suffixes"] == ["_n019"]
    assert len(merged["sources"]) == 2


def test_duplicate_identical_scores_are_allowed(tmp_path: Path) -> None:
    attack = {"S": _attack(20.0, 28.0)}
    first = _write(tmp_path / "first.json", attack)
    second = _write(tmp_path / "second.json", attack)

    merged = merge_summaries([first, second], ["S"])

    assert merged["attacks"]["S"]["mean_eer_percent"] == 24.0


def test_conflicting_duplicate_scores_fail(tmp_path: Path) -> None:
    first = _write(tmp_path / "first.json", {"S": _attack(20.0, 28.0)})
    second = _write(tmp_path / "second.json", {"S": _attack(21.0, 28.0)})

    with pytest.raises(ValueError, match="Conflicting scores"):
        merge_summaries([first, second], ["S"])


def test_missing_required_attack_fails(tmp_path: Path) -> None:
    il = _write(tmp_path / "il.json", {"I": _attack(30.0, 40.0)})

    with pytest.raises(ValueError, match="Missing required attacks: L S"):
        merge_summaries([il], ["I", "L", "S"])


def test_inconsistent_mean_fails(tmp_path: Path) -> None:
    bad = _write(
        tmp_path / "bad.json",
        {
            "S": {
                "female_eer_percent": 20.0,
                "male_eer_percent": 28.0,
                "mean_eer_percent": 25.0,
            }
        },
    )

    with pytest.raises(ValueError, match="female/male mean"):
        merge_summaries([bad], ["S"])
