from __future__ import annotations

import json
import tempfile
import threading
import unittest
from pathlib import Path

from n019.manifest import read_json, read_jsonl, write_json, write_jsonl


class ManifestWriteTests(unittest.TestCase):
    def test_writers_create_missing_parent_directories(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "nested" / "manifests"
            jsonl_path = root / "rows.jsonl"
            json_path = root / "metadata.json"

            write_jsonl(jsonl_path, [{"id": "b"}, {"id": "a"}])
            write_json(json_path, {"rows": 2})

            self.assertEqual(
                [row["id"] for row in read_jsonl(jsonl_path)],
                ["b", "a"],
            )
            self.assertEqual(read_json(json_path), {"rows": 2})
            self.assertEqual(list(root.glob("*.tmp")), [])

    def test_concurrent_writers_do_not_share_temporary_files(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "rows.jsonl"
            barrier = threading.Barrier(2)
            errors: list[BaseException] = []

            def write_marker(marker: str) -> None:
                try:
                    barrier.wait()
                    write_jsonl(
                        destination,
                        ({"id": marker, "row": index} for index in range(5_000)),
                    )
                except BaseException as exc:
                    errors.append(exc)

            threads = [
                threading.Thread(target=write_marker, args=("a",)),
                threading.Thread(target=write_marker, args=("b",)),
            ]
            for thread in threads:
                thread.start()
            for thread in threads:
                thread.join()

            self.assertEqual(errors, [])
            rows = read_jsonl(destination)
            self.assertEqual(len(rows), 5_000)
            self.assertEqual(len({row["id"] for row in rows}), 1)
            self.assertIn(rows[0]["id"], {"a", "b"})
            self.assertEqual(
                [row["row"] for row in rows],
                list(range(5_000)),
            )
            self.assertEqual(list(destination.parent.glob(".*.tmp")), [])


if __name__ == "__main__":
    unittest.main()
