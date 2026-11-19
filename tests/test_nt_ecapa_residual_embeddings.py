from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np


def test_builds_normalized_residual_embeddings() -> None:
    rng = np.random.default_rng(7)
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        source_nt = root / "source_nt.npz"
        source_ecapa = root / "source_ecapa.npz"
        target_nt = root / "target_nt.npz"
        target_ecapa = root / "target_ecapa.npz"
        out = root / "out"

        source_keys = [f"s{index}" for index in range(40)]
        np.savez(
            source_nt,
            **{
                key: rng.normal(size=8).astype(np.float32)
                for key in source_keys
            },
        )
        np.savez(
            source_ecapa,
            **{
                key: rng.normal(size=5).astype(np.float32)
                for key in source_keys
            },
        )
        target_keys = [f"t{index}" for index in range(12)]
        np.savez(
            target_nt,
            **{
                key: rng.normal(size=8).astype(np.float32)
                for key in target_keys
            },
        )
        np.savez(
            target_ecapa,
            **{
                key: rng.normal(size=5).astype(np.float32)
                for key in target_keys
            },
        )

        result = subprocess.run(
            [
                sys.executable,
                str(
                    Path(__file__).parents[1]
                    / "scripts"
                    / "build_nt_ecapa_residual_embeddings.py"
                ),
                "--source-nt",
                str(source_nt),
                "--source-ecapa",
                str(source_ecapa),
                "--target-nt",
                str(target_nt),
                "--target-ecapa",
                str(target_ecapa),
                "--out-dir",
                str(out),
                "--ridge-weight",
                "10",
                "--strengths",
                "0.25",
                "0.5",
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, result.stderr
        report = json.loads((out / "mapping_report.json").read_text())
        assert report["paired_source_speakers"] == 40
        assert report["target_speakers"] == 12
        assert set(report["strengths"]) == {
            "residual_0p25",
            "residual_0p5",
        }
        for strength in ("0p25", "0p5"):
            archive = np.load(out / f"residual_{strength}.npz")
            assert set(archive.files) == set(target_keys)
            for key in target_keys:
                value = archive[key]
                assert value.shape == (8,)
                assert np.isfinite(value).all()
                assert abs(float(np.linalg.norm(value)) - 1.0) < 1e-5
            archive.close()
