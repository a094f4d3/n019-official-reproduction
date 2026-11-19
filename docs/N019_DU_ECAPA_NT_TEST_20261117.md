# N019 DU-ecapa-nt test

Date: 2026-11-17

## Why this experiment is new

The completed `DU-pred-nt`, `DU-nt-nt`, target-pooling, shrink, checkpoint,
attacker-convergence and source-reconstruction controls do not provide a
convincing route to the remaining E-VPC S and W-NT L gap.

This experiment tests the distinct paper row `DU-ecapa-nt`:

- ECAPA-conditioned duration prediction;
- NT-conditioned Unit HiFi-GAN synthesis;
- the same randomly selected target identity on both sides.

The paper reports:

| Metric | Paper DU-ecapa-nt |
|---|---:|
| E-VPC S | 36.6% |
| W-NT I | 40.3% |
| W-NT L | 43.0% |
| WER | 7.59% |
| UTMOS | 3.60 |
| WhiSQA | 3.70 |

These are the two weakest paper-aligned targets in the current reproduction.

## New assets required by this row

1. LibriSpeech train-clean-100 ECAPA speaker embeddings for 251 speakers.
2. A 30-epoch ECAPA-conditioned duration predictor trained from the existing
   28,539 clean-100 unit records.
3. ECAPA target speaker means for 1,158 speakers using 32 deterministic
   utterances per speaker from the original LibriTTS train-other-500 pool.

Target sampling manifest:

`/public/home/a094f4d10/voice_projects/data/n019_official/processed/targets/target_speaker_mean32_all1158_20261117.jsonl`

- rows: 36,560
- requested speakers: 1,158
- group size min/mean/max: 1 / 31.5717 / 32
- SHA256:
  `712df414ca9ca7fbd394ae96b2cf6c85d9ca75582dbb393099dd09dfee08baa2`

The NT vocoder is the existing formal soup and is not retrained.
The official VPC ECAPA inference files are copied locally to d10. Source and
destination hashes match:

- `hyperparams.yaml`: `3590c9ffa105a9861e07fe532e3ac63f730541cdf20fc37eeea7cb34277ac8d0`
- `embedding_model.ckpt`: `d71e0dc0c2e4ae857dc57a59a8d9702655698adefe7b9d74a2b1b2dc5031eb8c`
- `classifier.ckpt`: `f5cb94bca53a8d8780988d396c7b12330eb0b80d8896cfad0354d6d277371552`
- `normalizer.ckpt`: `30f888cca75b7781af7c03ea4973c8caa1f070d60efb9d7500190fb425abc5e4`

The test target map contains 843 unique target speakers; the LS360 map covers
1,158. The union is fully covered by the new 1,158-speaker sample manifest.

## Job

- account/mode: `a094f4d10`, HPC/Slurm
- JobID: `1143063` (replacement for the 37-second launch failure `1142673`)
- name: `n019_du_ecapa_nt`
- partition: `hx1hdnormal`
- resources: 1 DCU, 16 CPU / 60 GB
- wall clock: 4 h
- expected/worst: 2.5 / 4.0 card-hours
- dependency: released by cancelling the rejected `DU-nt-nt` fallback
  `1142507` at `08:59:31`; now waiting only for the d10 allocation
- balance before submission: `49.5833333334`
- script SHA256:
  `253e60b73f744dbd7bb48ad194bc561994cb916190dc03eeb87b07f4739d70d2`

## Evaluation

The job evaluates the full official 1,934-sentence VPC `libri_test` set:

- WER: 1,496 utterances
- UTMOS: 1,934 utterances
- WhiSQA: 1,934 utterances
- W-NT I/L

Outputs:

- `data/n019_official/anonymised/libri_test/DU-ecapa-nt-20261117`
- `runs/n019_official/eval/du_ecapa_nt_20261117`
- `runs/n019_official/eval/du_ecapa_nt_20261117_wnt`

Before GPU work, the job runs:

`scripts/preflight_du_ecapa_nt_inputs_d10.sh`

The preflight passed with 1,934 test records, 843 test target speakers,
104,014 LS360 target rows, 1,158 LS360 target speakers, 1,158 NT target keys
and the exact formal vocoder SHA256. Report SHA256:
`3d4bd92e5e0004d8533ef2310d7d99ad816f7c7983cd98fc2f867ea8dba2bc8b`.

## ERA/ECAPA pipeline smoke

AI Job `2122496651045601281` passed a real 1-DCU smoke on d10:

- 8 unit records and 9 synthetic 192-D source/target embeddings;
- actual one-epoch ECAPA-conditioned duration training;
- train loss `2.364451946232857`;
- two end-to-end anonymisations using the formal NT soup and ECAPA duration
  mode;
- both output WAVs and both `anon.jsonl` rows verified.

Smoke artifact hashes:

- duration model:
  `5683f5e608e48afec1312d3a969a022520b2d00fad5bb21d043d7198f947047d`
- anonymised manifest:
  `1cdecb42591f12d516eba0a8e75a86c22b729a548743e3c9c037aaa19e605c9f`

## Decision rule

This is not a formal replacement during the test screen. A complete E-VPC S
run is only justified if:

1. W-NT L improves meaningfully over the formal `39.7293%`;
2. WER remains below the paper's `7.41%`;
3. UTMOS and WhiSQA remain competitive with the formal `3.5254 / 3.4958`.

The prepared LS360 S pipeline is:

`hpc/n019_ls360_du_ecapa_nt_s_pipeline_d10_hpc.slurm`

It is intentionally not submitted until the test gate passes.
