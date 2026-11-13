"""Compute official VPC WER from an exported Kaldi-style dataset."""

from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path

import torch
import torchaudio
from torch.utils.data import DataLoader, Dataset


class LazyASRDataset(Dataset):
    """Load and normalize each VPC utterance only when it is fetched.

    The upstream ``ASRDataset`` eagerly loads every file in its constructor.
    On the NFS-backed 1,496-utterance evaluation set that takes long enough
    to consume the whole 1 h job window before inference starts. This
    dataset keeps the same preprocessing and collate behavior while
    streaming the audio through the DataLoader.
    """

    def __init__(self, wav_scp_file: Path, asr_model):
        from utils import read_kaldi_format

        self.items = list(read_kaldi_format(wav_scp_file).items())
        self.asr_model = asr_model

    def __len__(self) -> int:
        return len(self.items)

    def __getitem__(self, index: int):
        utt_id, wav_file = self.items[index]
        signal, sample_rate = torchaudio.load(str(wav_file))
        waveform = self.asr_model.audio_normalizer(
            signal.squeeze(), sample_rate
        )
        return waveform, utt_id, len(waveform.squeeze())

    @staticmethod
    def collate_fn(batch):
        waveforms, utterance_ids, lengths = zip(*batch)
        batch_waveforms = torch.nn.utils.rnn.pad_sequence(
            list(waveforms),
            batch_first=True,
            padding_value=0.0,
        )
        relative_lengths = (
            torch.tensor(lengths, dtype=torch.float32)
            / batch_waveforms.shape[1]
        )
        return utterance_ids, batch_waveforms, relative_lengths


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--vpc-data-root", required=True)
    parser.add_argument("--dataset", required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--device", default="cuda")
    parser.add_argument("--batch-size", type=int, default=8)
    parser.add_argument("--expected-count", type=int, default=1934)
    args = parser.parse_args()

    project_root = Path(__file__).resolve().parents[2]
    vendor = project_root / "vendor" / "Voice-Privacy-Challenge-2024"
    sys.path.insert(0, str(vendor))

    inference_path = (
        vendor
        / "evaluation"
        / "utility"
        / "asr"
        / "speechbrain_asr"
        / "inference.py"
    )
    inference_spec = importlib.util.spec_from_file_location(
        "n019_vpc_speechbrain_asr_inference",
        inference_path,
    )
    if inference_spec is None or inference_spec.loader is None:
        raise ImportError(f"Cannot load VPC ASR inference module: {inference_path}")
    inference_module = importlib.util.module_from_spec(inference_spec)
    sys.modules[inference_spec.name] = inference_module
    inference_spec.loader.exec_module(inference_module)
    InferenceSpeechBrainASR = inference_module.InferenceSpeechBrainASR
    from utils import read_kaldi_format  # noqa: E402

    torch.multiprocessing.set_sharing_strategy("file_system")
    data_root = Path(args.vpc_data_root)
    dataset_root = data_root / args.dataset
    wav_scp = dataset_root / "wav.scp"
    references_path = dataset_root / "text"
    if not wav_scp.is_file() or not references_path.is_file():
        raise FileNotFoundError(
            f"Missing VPC dataset files: {wav_scp} or {references_path}"
        )

    device = torch.device(args.device)
    model = InferenceSpeechBrainASR(
        model_path=Path(args.model),
        asr_hparams="hyperparams.yaml",
        model_type="EncoderASR",
        device=device,
    )
    dataset = LazyASRDataset(wav_scp_file=wav_scp, asr_model=model.asr_model)
    loader = DataLoader(
        dataset,
        batch_size=args.batch_size,
        shuffle=False,
        # The lazy dataset holds the SpeechBrain normalizer; forked workers
        # cannot serialize its parametrized modules. Loading in the main
        # process still keeps the job streaming and avoids the eager 1,496
        # file startup pass.
        num_workers=0,
        collate_fn=dataset.collate_fn,
    )
    references = read_kaldi_format(references_path, values_as_string=True)
    out = Path(args.out)
    hypothesis_path = out.parent / "vpc_asr" / "text"
    wer_path = out.parent / "vpc_asr" / "wer"
    hypotheses = model.transcribe_audios(data=loader, out_file=hypothesis_path)
    scores = model.compute_wer(
        ref_texts=references,
        hyp_texts=hypotheses,
        out_file=wer_path,
    )
    # VPC2024's SpeechBrain ErrorRateStats reports percentages (e.g. 7.41),
    # not 0-1 fractions. Keep that convention in wer_percent and expose a
    # conventional fraction in wer for downstream comparisons.
    error_rate_percent = float(scores.summarize("error_rate"))
    result = {
        "backend": "vpc2024_speechbrain_EncoderASR",
        "dataset": args.dataset,
        "utterances": len(hypotheses),
        "references": len(references),
        "wer": error_rate_percent / 100.0,
        "wer_percent": error_rate_percent,
        "model": str(Path(args.model).resolve()),
        "hypotheses": str(hypothesis_path),
        "wer_file": str(wer_path),
    }
    if (
        result["utterances"] != args.expected_count
        or result["references"] != args.expected_count
    ):
        raise RuntimeError(
            f"Expected {args.expected_count} references/hypotheses, got {result}"
        )
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
