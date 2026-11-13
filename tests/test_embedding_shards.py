from __future__ import annotations

import os
import hashlib
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np

from n019.manifest import read_json, read_jsonl, write_jsonl


class EmbeddingShardTests(unittest.TestCase):
    def test_canonical_merge_accepts_identical_overlap_and_missing_shard_rows(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest = root / "canonical.jsonl"
            rows = [
                {"id": f"utt-{index}", "speaker": "spk", "audio": f"/x/{index}.wav"}
                for index in range(4)
            ]
            write_jsonl(manifest, rows)

            def vector(index: int) -> np.ndarray:
                value = np.zeros(250, dtype=np.float32)
                value[index] = 1.0
                return value

            first = root / "first.npz"
            with first.open("wb") as handle:
                np.savez(handle, **{rows[index]["id"]: vector(index) for index in [0, 1]})
            second = root / "second.npz"
            with second.open("wb") as handle:
                np.savez(handle, **{rows[index]["id"]: vector(index) for index in [1, 2, 3]})

            merged = root / "merged"
            subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "scripts.merge_utterance_embedding_sources",
                    "--canonical-manifest",
                    str(manifest),
                    "--input",
                    str(first),
                    "--input",
                    str(second),
                    "--expected-rows",
                    "4",
                    "--out",
                    str(merged),
                ],
                check=True,
                env=os.environ.copy(),
                capture_output=True,
                text=True,
            )
            result = read_json(merged / "metadata.json")
            self.assertEqual(result["rows"], 4)
            self.assertEqual(result["dimension"], 250)
            self.assertEqual(result["identical_overlap_keys"], 1)
            self.assertEqual(read_jsonl(merged / "nt_utterance_manifest.jsonl"), rows)
            with np.load(merged / "nt_utterance_embeddings.npz") as archive:
                self.assertEqual(list(archive.files), [row["id"] for row in rows])

    def test_canonical_merge_rejects_conflicting_overlap(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest = root / "canonical.jsonl"
            row = {"id": "utt-0", "speaker": "spk", "audio": "/x/0.wav"}
            write_jsonl(manifest, [row])
            first = root / "first.npz"
            second = root / "second.npz"
            with first.open("wb") as handle:
                value = np.zeros(250, dtype=np.float32)
                value[0] = 1.0
                np.savez(handle, **{row["id"]: value})
            with second.open("wb") as handle:
                value = np.zeros(250, dtype=np.float32)
                value[1] = 1.0
                np.savez(handle, **{row["id"]: value})

            result = subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "scripts.merge_utterance_embedding_sources",
                    "--canonical-manifest",
                    str(manifest),
                    "--input",
                    str(first),
                    "--input",
                    str(second),
                    "--out",
                    str(root / "merged"),
                ],
                env=os.environ.copy(),
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Conflicting duplicate embedding", result.stderr)

    def test_ecapa_merge_uses_ecapa_archive_and_dimension(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest = root / "targets.jsonl"
            rows = [
                {"id": f"utt-{index}", "speaker": "spk", "audio": f"/x/{index}.wav"}
                for index in range(2)
            ]
            write_jsonl(manifest, rows)
            shard_args = []
            for index, row in enumerate(rows):
                shard = root / f"shard_{index:03d}"
                shard.mkdir()
                vector = np.zeros(192, dtype=np.float32)
                vector[index] = 1.0
                with (shard / "ecapa_utterance_embeddings.npz").open("wb") as handle:
                    np.savez(handle, **{row["id"]: vector})
                write_jsonl(
                    shard / "ecapa_utterance_manifest.jsonl",
                    [
                        {
                            **row,
                            "embedding_key": row["id"],
                            "embedding_level": "utterance",
                            "dimension": 192,
                        }
                    ],
                )
                shard_args.extend(["--shard-dir", str(shard)])

            merged = root / "merged"
            subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "scripts.merge_target_embedding_shards",
                    *shard_args,
                    "--manifest",
                    str(manifest),
                    "--kind",
                    "ecapa",
                    "--expected-rows",
                    "2",
                    "--out",
                    str(merged),
                ],
                check=True,
                env=os.environ.copy(),
                capture_output=True,
                text=True,
            )
            result = read_json(merged / "metadata.json")
            self.assertEqual(result["kind"], "ecapa")
            self.assertEqual(result["dimension"], 192)
            self.assertTrue((merged / "ecapa_utterance_embeddings.npz").is_file())
            self.assertTrue((merged / "ecapa_utterance_manifest.jsonl").is_file())

    def test_prepare_and_merge_round_trip(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest = root / "targets.jsonl"
            rows = [
                {
                    "id": f"utt-{index}",
                    "speaker": f"spk-{index % 2}",
                    "audio": f"/old/root/{index}.wav",
                }
                for index in range(8)
            ]
            write_jsonl(manifest, rows)

            shard_manifest_dir = root / "shard_manifests"
            subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "scripts.prepare_target_embedding_shards",
                    "--manifest",
                    str(manifest),
                    "--out-dir",
                    str(shard_manifest_dir),
                    "--shards",
                    "3",
                    "--audio-prefix-from",
                    "/old/root/",
                    "--audio-prefix-to",
                    "/new/root/",
                ],
                check=True,
                env=os.environ.copy(),
                capture_output=True,
                text=True,
            )
            metadata = read_json(shard_manifest_dir / "shards.json")
            self.assertEqual(
                [item["rows"] for item in metadata["shards"]],
                [3, 3, 2],
            )
            shard_ids = []
            for index in range(3):
                path = shard_manifest_dir / f"shard_{index:03d}.jsonl"
                values = read_jsonl(path)
                shard_ids.extend(row["id"] for row in values)
                self.assertTrue(
                    all(row["audio"].startswith("/new/root/") for row in values)
                )
            self.assertEqual(sorted(shard_ids), sorted(row["id"] for row in rows))

            shard_outputs = []
            for index in range(3):
                path = shard_manifest_dir / f"shard_{index:03d}.jsonl"
                values = read_jsonl(path)
                output_dir = root / "embeddings" / f"shard_{index:03d}"
                output_dir.mkdir(parents=True)
                embeddings = {}
                output_rows = []
                for row_index, row in enumerate(values):
                    vector = np.zeros(250, dtype=np.float32)
                    vector[(index + row_index) % 250] = 1.0
                    embeddings[row["id"]] = vector
                    output_rows.append(
                        {
                            **row,
                            "embedding_key": row["id"],
                            "embedding_level": "utterance",
                            "dimension": 250,
                        }
                    )
                with (output_dir / "nt_utterance_embeddings.npz").open("wb") as handle:
                    np.savez(handle, **embeddings)
                write_jsonl(
                    output_dir / "nt_utterance_manifest.jsonl",
                    output_rows,
                )
                shard_outputs.extend(["--shard-dir", str(output_dir)])

            merged = root / "merged"
            subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "scripts.merge_target_embedding_shards",
                    *shard_outputs,
                    "--manifest",
                    str(manifest),
                    "--expected-rows",
                    "8",
                    "--expected-manifest-sha256",
                    hashlib.sha256(manifest.read_bytes()).hexdigest(),
                    "--out",
                    str(merged),
                ],
                check=True,
                env=os.environ.copy(),
                capture_output=True,
                text=True,
            )
            result = read_json(merged / "metadata.json")
            self.assertEqual(result["rows"], 8)
            self.assertEqual(result["dimension"], 250)
            self.assertEqual(result["source_manifest"], str(manifest.resolve()))
            merged_rows = read_jsonl(merged / "nt_utterance_manifest.jsonl")
            self.assertEqual(merged_rows, rows)
            archive = np.load(merged / "nt_utterance_embeddings.npz")
            self.assertEqual(list(archive.files), [row["id"] for row in rows])
            archive.close()


if __name__ == "__main__":
    unittest.main()
