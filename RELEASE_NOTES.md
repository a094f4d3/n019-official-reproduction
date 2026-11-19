# N019 Official Reproduction v0.4.0

Release date: 2026-11-19

This release packages the complete soft-cap 0.75 `DU-pred-nt` candidate,
the runnable implementation, experiment configuration, tests, audit
documentation, and compact result evidence.

## Selected candidate

- layer-6 vocoder soup: 84/88/92/96k = `40:30:20:10`
- target embedding: NT + ECAPA orthogonal residual `0.5`
- duration extrapolation: `0.5`, preserving predicted total duration
- duration soft cap: `0.75`
- vocoder SHA256:
  `ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6`

Complete same-suffix results:

| Metric | Paper | Reproduced |
|---|---:|---:|
| E-VPC I | 47.2% | 47.4375% |
| E-VPC L | 47.9% | 48.9800% |
| E-VPC S | 34.8% | 32.4120% |
| W-NT I | 39.9% | 41.4650537074% |
| W-NT L | 42.3% | 41.6133768857% |
| W-NT S | 24.6% | 27.6945129037% |
| WER | 7.41% | 7.7050396667% |
| UTMOS | 3.63 | 3.6297727519 |
| WhiSQA | 3.69 | 3.6223786510 |

Counts: WER 1,496; UTMOS and WhiSQA 1,934 each. The matching W-NT S
model has SHA256
`8209eb42a52f6c473221ab4e25cca6c0c9efd89aa6a943ece2719396d576aebf`.

## Included

- `src/n019/`: units, duration predictors, Unit HiFi-GAN, anonymisation,
  VPC export, MOS/WER evaluation, W-NT attacks, and paper comparison.
- `scripts/` and `hpc/`: preprocessing, training, evaluation,
  diagnostics, Slurm entry points, and the `/dev/shm` W-NT S workflow.
- `configs/`: paper table, implementation choices, evaluation plans,
  soft-cap recipes, and transfer manifests.
- `tests/`: unit and paper-alignment checks.
- `docs/`: implementation audit, asset manifest, handoff, job ledger,
  soft-cap report, and system-status table.
- `results/`: compact result JSON, including
  `results/softcap075_complete_20261119.json`.
- `RESULTS.md`, `RESULTS.csv`, and `results/n019_results.json`.

## Not included

- Original LibriTTS/LibriSpeech audio
- VPC2024 corpora or generated Kaldi indexes
- Vocoder checkpoints and optimizer states
- Anonymised WAV files
- UTMOS22 or WhiSQA model weights
- SCNet login credentials or tokens

The official asset locations, upstream commits, licenses, and SHA256
pins are documented in `docs/OFFICIAL_ASSET_MANIFEST.md` and
`configs/source_lock.json`.

## Other DU systems

The other seven DU rows in the paper are duration/vocoder conditioning
combinations. Their current status is documented in
`docs/N019_SYSTEM_STATUS_20261119.md`. Only `DU-ecapa-nt` has a current
partial full-test screen, and its missing E-VPC I/L prevent a nine-metric
row. The remaining combinations do not have current corrected-pipeline
results and must not be filled with old checkpoint values.

## Verification

```powershell
$env:PYTHONPATH='src'
python -m pytest tests -q
Get-FileHash -Algorithm SHA256 .\n019-official-v0.4.0.tar.gz
```

## Limitations

- The paper does not publish every implementation detail.
- The soft-cap candidate is a reproduction enhancement, not an
  author-confirmed setting.
- WER and UTMOS are close to the paper, while E-VPC S and W-NT L remain
  the largest privacy gaps.
- Values from different suffixes or attack checkpoints must not be
  concatenated.
