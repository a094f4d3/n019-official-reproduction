# N019 Official Reproduction

Reproduction of:

> Bakari, Le Blouch, Gengembre, Evans. "Joint Timbral and Non-Timbral
> Speaker Anonymisation." Odyssey 2026, pp. 106-113.
> DOI: `10.21437/Odyssey.2026-16`.

This repository contains the runnable implementation, experiment
configuration, tests, implementation audit, and compact result evidence
for the `DU-pred-nt` speaker-anonymisation systems. It does not contain
raw corpora, model checkpoints, generated WAV files, or third-party model
weights.

## v0.4.0 selected candidate

The v0.4.0 release closes all nine metrics for the same-suffix
soft-cap 0.75 candidate:

- Base vocoder: four-point soup 84k / 88k / 92k / 96k =
  `40:30:20:10`
- Target embedding: NT + ECAPA orthogonal residual `0.5`
- Duration extrapolation: `0.5`, preserving total predicted duration
- Duration soft cap: `0.75`
- Vocoder SHA256:
  `ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6`

| Metric | Paper | Reproduced | Difference |
|---|---:|---:|---:|
| E-VPC I | 47.2% | **47.4375%** | +0.2375 pp |
| E-VPC L | 47.9% | **48.9800%** | +1.0800 pp |
| E-VPC S | 34.8% | **32.4120%** | -2.3880 pp |
| W-NT I | 39.9% | **41.4650537074%** | +1.5650537074 pp |
| W-NT L | 42.3% | **41.6133768857%** | -0.6866231143 pp |
| W-NT S | 24.6% | **27.6945129037%** | +3.0945129037 pp |
| WER | 7.41% | **7.7050396667%** | +0.2950396667 pp |
| UTMOS | 3.63 | **3.6297727519** | -0.0002272481 |
| WhiSQA | 3.69 | **3.6223786510** | -0.0676213490 |

WER uses 1,496 de-duplicated enroll/trial utterances. UTMOS and
WhiSQA each use all 1,934 official `libri_test` utterances.

This candidate gives the best WER/UTMOS alignment so far, but it is not
a strict Pareto improvement over the no-cap privacy candidate: E-VPC S
and W-NT L are higher in the no-cap version.

## Previous formal reference

System: `DU-pred-nt`

- Four-point effective-weight-norm soup: 84k / 88k / 92k / 96k
  with weights `40:30:20:10`
- Target embedding: `mean32 + shrink0.1`
- Checkpoint SHA256:
  `ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6`

| Metric | Paper | Reproduced | Difference |
|---|---:|---:|---:|
| E-VPC I | 47.2% | **48.0285%** | +0.8285 pp |
| E-VPC L | 47.9% | **47.7540%** | -0.1460 pp |
| E-VPC S | 34.8% | **29.7425%** | -5.0575 pp |
| W-NT I | 39.9% | **39.1678579152%** | -0.7321420848 pp |
| W-NT L | 42.3% | **39.7293478251%** | -2.5706521749 pp |
| W-NT S | 24.6% | **24.5238568634%** | -0.0761431366 pp |
| WER | 7.41% | **6.2239598196%** | -1.1860401804 pp |
| UTMOS | 3.63 | **3.5253666541** | -0.1046333459 |
| WhiSQA | 3.69 | **3.4957589100** | -0.1942410900 |

WER uses 1,496 de-duplicated enroll/trial utterances. UTMOS and
WhiSQA each use the complete 1,934-utterance official `libri_test`
set.

The main remaining difference is E-VPC S. See `RESULTS.md` for the
formal table, diagnostic controls, and explicit exclusions.

## Repository layout

- `src/n019/`: durations, units, Unit HiFi-GAN, anonymisation, VPC
  export, MOS/WER evaluation, W-NT attacks, and paper comparison.
- `scripts/`: preprocessing, training, evaluation, diagnostics, and
  remote orchestration.
- `hpc/`: Slurm entry points and environment activation.
- `configs/`: paper table, pinned sources, implementation choices, and
  evaluation plans.
- `tests/`: unit, integration, and paper-alignment checks.
- `docs/`: official asset manifest, implementation audit, job ledger,
  handoff, and experiment reports.
- `results/formal/`: formal nine-metric result and raw compact evidence.
- `results/experiments/`: diagnostic EER JSON.
- `RESULTS.md`, `RESULTS.csv`, and `results/n019_results.json`: release
  tables.

## Fixed evaluation protocol

- VPC2024 release `v2`, commit
  `7c80e86d3a4d58b81a2f3bdc01a3508c37018be4`
- Official VPC2024 Kaldi manifests
- Official `libri_test` subset for Table 1
- Official `ASV_eval` checkpoint for E-VPC
- Original LibriTTS, not LibriTTS-R
- Unit HiFi-GAN training: LibriTTS `train-clean-100`
- Target pool: LibriTTS `train-other-500`
- Duration predictor: LibriSpeech `train-clean-100`
- UTMOS22 and WhiSQA on complete 1,934-utterance output

Machine-readable source pins are in `configs/source_lock.json` and
`configs/reference_implementations.json`. Asset acquisition and hash
checks are documented in `docs/OFFICIAL_ASSET_MANIFEST.md` and
`docs/ACQUISITION_RUNBOOK.md`.

## Install and test

```powershell
$env:PYTHONPATH = "src"
python -m pytest tests -q
```

Editable package installation:

```bash
python -m pip install -e . --no-deps
```

Do not install public PyPI `torch` or `torchaudio` over the verified
SCNet DTK environment.

## Reproduction status

- Formal `DU-pred-nt` result: complete for all nine Table 1 metrics.
- v0.4.0 soft-cap 0.75 candidate: complete for all nine Table 1
  metrics with the same audio suffix.
- E-VPC I, E-VPC L, W-NT S, and WER are close to or better than the
  paper.
- E-VPC S and W-NT L remain below the paper.
- `DU-X-Y` system sweeps are not claimed as complete. See
  `docs/N019_SYSTEM_STATUS_20261119.md`.
- The model soup, target shrink, and several unpublished
  hyperparameter choices are reproduction enhancements, not
  author-confirmed settings.

See `RELEASE_NOTES.md` for the release scope and limitations.
