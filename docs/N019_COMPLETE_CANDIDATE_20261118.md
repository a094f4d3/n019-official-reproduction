# N019 Complete Candidate, 2026-11-18

This document records the first same-suffix nine-metric `DU-pred-nt`
candidate that closes the previous missing W-NT S result. It is a strong
candidate, not yet a replacement for the long-standing formal row.

## Recipe

- Vocoder: layer-6 soup `84/88/92/96k = 40:30:20:10`
- Vocoder SHA256:
  `ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6`
- Target representation: NT + ECAPA orthogonal timbral residual, strength
  `0.5`
- Full target archive SHA256:
  `117fb0f1fc2fc9593e7668dbcad46abcbe22a0fa363bab803f68e8f1a612b9f2`
- Test target archive SHA256:
  `7a015304bebdcd12bcb4deda5792ea1941159650eff4c97367716b0748e690ef`
- Duration model SHA256:
  `8d5153c920058204fe13ebb75b0744703bc0523e70f3a83fbd8b194245a3ba1c`
- Local-rhythm duration extrapolation: `0.5`, preserving the predicted
  total duration
- VPC suffix: `_n019_ntecres0p5_durextra0p5_20261118`

## Nine Metrics

| Metric | Paper | Candidate | Delta |
|---|---:|---:|---:|
| E-VPC I | 47.2% | 46.771% | -0.429 pp |
| E-VPC L | 47.9% | 49.235% | +1.335 pp |
| E-VPC S | 34.8% | **33.255%** | **-1.545 pp** |
| W-NT I | 39.9% | 42.723927% | +2.823927 pp |
| W-NT L | 42.3% | **41.801279%** | **-0.498721 pp** |
| W-NT S | 24.6% | 27.535794% | +2.935794 pp |
| WER | 7.41% | 8.267222% | +0.857222 pp |
| UTMOS | 3.63 | 3.608841 | -0.021159 |
| WhiSQA | 3.69 | 3.606529 | -0.083471 |

Higher EER is stronger privacy, so the positive W-NT I/S deltas are not
quality regressions. The remaining material gap is WER `+0.857 pp`;
E-VPC S is within `1.545 pp` of the paper.

## Comparison With the Formal Layer-6 Row

| Metric | Formal | Candidate | Delta |
|---|---:|---:|---:|
| E-VPC I | 48.0285% | 46.771% | -1.2575 pp |
| E-VPC L | 47.7540% | 49.235% | +1.4810 pp |
| E-VPC S | 29.7425% | 33.255% | +3.5125 pp |
| W-NT I | 39.167858% | 42.723927% | +3.556069 pp |
| W-NT L | 39.729348% | 41.801279% | +2.071931 pp |
| W-NT S | 24.523857% | 27.535794% | +3.011937 pp |
| WER | 6.223960% | 8.267222% | +2.043262 pp |
| UTMOS | 3.525367 | 3.608841 | +0.083475 |
| WhiSQA | 3.495759 | 3.606529 | +0.110770 |

The candidate substantially improves E-VPC S and both W-NT I/L, and also
improves both MOS metrics, at the cost of about `2.04 pp` WER.

## Artifact Hashes

- E-VPC S metrics:
  `/public/home/a094f4d10/voice_projects/runs/n019_official/privacy/ntecres0p5_durextra0p5_20261118_s/s_eval/s_metrics.json`
  SHA256 `eb9a4253f8f76cf49d661b5736f0ed705f4aeae1b4a0b299753080cd2bd82c87`
- E-VPC I/L:
  `/public/home/a094f4d10/voice_projects/runs/n019_official/eval_user/ntecres0p5_durextra0p5_il_20261118/privacy_il_metrics.json`
  SHA256 `748efdc50a5908bf0ba4ca6106f5ebeb3697937b5ecf65976cb29821d616d864`
- Quality:
  `/public/home/a094f4d10/voice_projects/runs/n019_official/ntecres05_durextra05_screen_20261118/eval/quality_metrics.json`
  SHA256 `d79f9344e6ac9fb381940bfe566acca50cef2c8b8b6525736e26a0a38c8c1ff7`
- W-NT I/L:
  `/public/home/a094f4d10/voice_projects/runs/n019_official/ntecres05_durextra05_screen_20261118/wnt_il/summary.json`
  SHA256 `7b60ce488c2f27b2c53abd338019eab8bc89b8151fd2ca02b556cc57aa1cfccd`
- W-NT S:
  Job `1158175`, summary SHA256
  `97bd5fdc81ece40eb67360396000a18360b3dd8536c0ecfbd0dd2db2d4140894`
- Combined pre-S summary:
  `04d27323b2531b8c456af1b55f6ae2d9c6c5e68dd235c8f049f469b4d0cc33b8`

The W-NT S model delta and metadata are retained locally at:

`artifacts/wnt_s_1158175_model/`

The frozen-base delta SHA256 is:

`f54ddd518896ff0b1372e56aa0747f6ebb19ee2e9d75e77cd89e76ebd82ed20c`

## Rejected Neighbor

Residual strength `0.75` plus duration extrapolation `0.5` improved WER,
UTMOS, and WhiSQA, but reduced W-NT L to `41.067906%`, moving farther from
the paper's `42.3%`. It is retained only as a control and is not promoted.
