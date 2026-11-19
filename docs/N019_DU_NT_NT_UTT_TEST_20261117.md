# N019 DU-nt-nt target-utterance test

Date: 2026-11-17

## Why this experiment is new

The completed `DU-nt-nt` diagnostic used target-speaker pooled embeddings for
both duration prediction and vocoder conditioning. Earlier target-embedding
experiments also changed only inference pooling while leaving the conditioning
model unchanged.

This experiment tests a different paper-aligned condition:

- the duration predictor is the existing NT-conditioned predictor;
- both duration prediction and the NT Unit HiFi-GAN receive the same randomly
  selected target-utterance embedding from LibriTTS `train-other-500`;
- no gender constraint, fixed source-target mapping, shrink, or source
  embedding is introduced.

The paper describes a randomly sampled target speaker embedding used by both
the duration predictor and vocoder. This is therefore a direct test of the
joint `DU-nt-nt` conditioning path, not a repeat of the earlier pooled-target
run.

## Inputs

Self-contained d10 bundle:

`/public/home/a094f4d10/voice_projects/data/n019_official/processed/selection_bundles/du_nt_nt_utt_test_20261117`

- 1,934 records
- 1,934 code files
- `target_map.jsonl`
- 1,924-key target-utterance W-PRO NPZ
- formal soup generator
- existing `duration_nt_main` predictor

Bundle SHA256 values:

| file | SHA256 |
|---|---|
| `units/unit_records.jsonl` | `b3cb1b68768eaf33c7ef8c48d8c8efe49ae9920c784a5d9a7bfd3e42d8ff8804` |
| `target_map.jsonl` | `c497769b4de43824d3a5840d3b497ecd71156222828a69e352140cebc9f4c383` |
| `assets/target_nt_utterance.npz` | `0c2a747220bac2a231cbde981a9d5dfca621750348f87f7ce18fab84994a58b7` |
| `assets/generator_soup2.pt` | `ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6` |
| `assets/duration_nt_main.pt` | `5fb1383660f738051f77b5dd6b4dd2fd52444be96803912d25ec8f5247c53be7` |

## Jobs

The completed AI evaluation was assembled from these jobs:

- `2122465687953358849`: completed anonymisation, VPC export, verification
  and WER; failed before MOS because the d10 UTMOS overlay was a cross-account
  symlink to d6.
- `2122474022949900289`: reused the complete WAV/VPC/WER, completed UTMOS and
  WhiSQA, then started W-NT.
- `2122480138102525953`: failed because the metadata-only VPC view lacked the
  original `data/libri_test/wav` files.
- `2122482465006592002`: completed W-NT female I and male I, then was stopped
  at `08:51:17` because the remaining L passes were too slow and the model was
  already quality-rejected.
- `1142507`: HPC fallback for W-NT I/L. It was cancelled at `08:59:31`
  without running because the completed quality and W-NT I evidence already
  rejected this model.

Five earlier AI-mode attempts failed before anonymisation:

- `2122447534302920705`: audit directory absent;
- `2122447776079368193`: AI container `$HOME` is `/root`, so the wrapper
  resolved the wrong code root;
- `2122448002453250050`: the 300-second watchdog passed on a healthy DCU, but
  the AI container cannot follow d10-home symlinks to d6
  `vendor`, `mos`, and `hf_cache/hub`. It stopped in input preflight.
- `2122457929743601666`: the container was made self-contained, but source
  test WAVs still resolved to d7. The 1,934 source WAVs were copied into the
  bundle and the record paths were rewritten.
- `2122459800839393282`: VPC metadata symlinks still resolved to d6. A local
  metadata-only `vpc_ai/data` view was built; no WAV directory was duplicated.

Do not resubmit the failed launches.

## Final test result

| Metric | Result | Formal | Paper |
|---|---:|---:|---:|
| WER | 6.449403572855431% | 6.2239598196% | 7.41% |
| UTMOS | 3.3327209665955286 | 3.5253666541 | 3.63 |
| WhiSQA | 3.30789153569117 | 3.4957589100 | 3.69 |
| W-NT I | 39.13377597928047% | 39.1678579152% | 39.9% |

W-NT L is intentionally not measured for this rejected row.

## Decision

The exact joint target-utterance conditioning does not improve either utility
or W-NT I. It is rejected and must not trigger the LS360 E-VPC S pipeline.
The formal `DU-pred-nt` result remains unchanged.
