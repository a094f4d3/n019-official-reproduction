"""Export anonymised WAVs in the directory layout expected by VPC2024."""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

from n019.manifest import iter_jsonl, utterance_id, write_json


METADATA_FILES = (
    "utt2spk",
    "spk2spk",
    "spk2gender",
    "spk2utt",
    "text",
    "text_no_norm",
    "utt2dur",
    "utt2emo",
    "trials",
    "enrolls",
    "spk2fold",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--vpc-data-dir", required=True)
    parser.add_argument("--anon-manifest", required=True)
    parser.add_argument("--suffix", required=True)
    parser.add_argument(
        "--dataset-prefix",
        action="append",
        default=[],
        help="Dataset prefix to export; repeat as needed.",
    )
    parser.add_argument(
        "--dataset-name",
        action="append",
        default=[],
        help="Exact dataset directory name to export; repeat as needed.",
    )
    parser.add_argument("--overwrite-missing", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    data_root = Path(args.vpc_data_dir).resolve()
    anon_rows = list(iter_jsonl(args.anon_manifest))
    anon = {
        utterance_id(row): Path(row["audio"]).resolve()
        for row in anon_rows
    }
    if len(anon) != len(anon_rows):
        raise ValueError("Anonymised manifest contains duplicate utterance IDs")
    missing = [key for key, path in anon.items() if not path.is_file()]
    if missing:
        raise FileNotFoundError(
            f"{len(missing)} anonymised WAVs are missing, first={missing[0]}"
        )
    exact_names = set(args.dataset_name)
    prefixes = args.dataset_prefix
    if not exact_names and not prefixes:
        prefixes = ["libri_test_", "train-clean-360"]
    exported = {}
    for dataset_dir in sorted(data_root.iterdir()):
        if not dataset_dir.is_dir():
            continue
        # The baseline setup uses symlinks such as libri_test_n019. They are
        # not independent datasets and must not be anonymised/exported twice.
        if dataset_dir.is_symlink():
            continue
        if args.suffix and dataset_dir.name.endswith(args.suffix):
            continue
        selected = (
            dataset_dir.name in exact_names
            if exact_names
            else any(
                dataset_dir.name.startswith(prefix)
                for prefix in prefixes
            )
        )
        if not selected:
            continue
        source_scp = dataset_dir / "wav.scp"
        if not source_scp.is_file():
            continue
        output_dir = data_root / f"{dataset_dir.name}{args.suffix}"
        if (
            output_dir.exists()
            and any(output_dir.iterdir())
            and not args.overwrite_missing
        ):
            raise FileExistsError(output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)
        for name in METADATA_FILES:
            source = dataset_dir / name
            if source.is_file():
                shutil.copy2(source, output_dir / name)
        rows = []
        with source_scp.open("r", encoding="utf-8") as handle:
            for line_number, raw_line in enumerate(handle, 1):
                line = raw_line.strip()
                if not line:
                    continue
                fields = line.split(maxsplit=1)
                if len(fields) != 2:
                    raise ValueError(
                        f"Invalid line {source_scp}:{line_number}"
                    )
                identifier = fields[0]
                if identifier not in anon:
                    raise KeyError(
                        f"Missing anonymised WAV for {dataset_dir.name}/{identifier}"
                    )
                rows.append(f"{identifier} {anon[identifier]}")
        (output_dir / "wav.scp").write_text(
            "\n".join(rows) + "\n",
            encoding="utf-8",
        )
        exported[dataset_dir.name] = {
            "output": str(output_dir),
            "utterances": len(rows),
        }
    if not exported:
        raise RuntimeError("No VPC datasets were exported")
    write_json(
        Path(args.anon_manifest).with_suffix(".vpc_export.json"),
        {
            "suffix": args.suffix,
            "datasets": exported,
        },
    )
    print(exported)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
