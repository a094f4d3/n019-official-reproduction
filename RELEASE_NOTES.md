# N019 Official Reproduction v0.3.0

Release date: 2026-11-13

This release packages the runnable N019 implementation, experiment
configuration, checks, documentation, and compact evidence for the
paper-aligned `DU-pred-nt` result.

## Included

- `src/n019/`: units, duration predictor, Unit HiFi-GAN vocoder,
  anonymisation, VPC export, MOS/WER evaluation, W-NT attacks, and
  paper comparison.
- `scripts/` and `hpc/`: reproducible preprocessing, training,
  evaluation, diagnostics, and Slurm entry points.
- `configs/`: paper table, algorithm choices, evaluation plans, and
  transfer manifests.
- `tests/`: unit and alignment tests.
- `docs/`: implementation audit, official-asset manifest, job ledger,
  handoff, and experiment reports.
- `results/formal/`: formal nine-metric JSON, raw WER/MOS/EER JSON,
  comparison report, and source hashes.
- `results/experiments/`: compact EER JSON for the principal controls.
- `RESULTS.md`, `RESULTS.csv`, and `results/n019_results.json`.

## Not included

- Original LibriTTS/LibriSpeech audio
- VPC2024 corpora or generated Kaldi indexes
- Vocoder checkpoints and optimizer states
- Anonymised WAV files
- UTMOS22 or WhiSQA model weights

The official asset locations, upstream commits, licenses, and SHA256
pins are documented in `docs/OFFICIAL_ASSET_MANIFEST.md` and
`configs/source_lock.json`.

## Formal result

`DU-pred-nt` is evaluated on the official VPC2024 `libri_test`
protocol:

- WER: 1,496 de-duplicated enroll/trial utterances
- UTMOS: 1,934 utterances
- WhiSQA: 1,934 utterances
- E-VPC and W-NT: official VPC2024 I/L/S conditions

The complete table is in `RESULTS.md`.

## Important limitations

- The paper does not publish every implementation detail. HuBERT layer
  6 with K=200, duration-predictor hyperparameters, vocoder training
  length, target-pooling behavior, and attack-training details contain
  paper-to-code assumptions.
- The formal checkpoint is a four-point effective-weight-norm model
  soup with a shrunk target embedding. These are reproduction
  enhancements and are not claimed as exact author settings.
- E-VPC I, E-VPC L, and W-NT S are close to the paper; WER is better
  than the paper. E-VPC S and W-NT L remain below the paper.
- Diagnostic results, including opposite-gender target selection, are
  labeled separately and are not part of the formal reproduction.

## Verification

```powershell
$env:PYTHONPATH='src'
python -m pytest tests -q
Get-FileHash -Algorithm SHA256 .\n019-official-v0.3.0.tar.gz
```
