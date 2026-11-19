# N019 Soft-Cap 0.75 Metrics, 2026-11-19

## Recipe

- base DU-pred-nt soup: 84/88/92/96k = `40:30:20:10`
- target embedding: NT + ECAPA orthogonal residual `0.5`
- duration extrapolation: `0.5`
- preserve predicted total duration
- duration soft cap: `0.75`
- suffix: `_n019_softcap075_recovery_20261119`

## Complete Nine-Metric Result

| Metric | Result | Paper | Delta |
|---|---:|---:|---:|
| E-VPC I | 47.4375% | 47.2% | +0.2375 pp |
| E-VPC L | 48.9800% | 47.9% | +1.0800 pp |
| E-VPC S | 32.4120% | 34.8% | -2.3880 pp |
| W-NT I | 41.465054% | 39.9% | +1.565054 pp |
| W-NT L | 41.613377% | 42.3% | -0.686623 pp |
| W-NT S | 27.694513% | 24.6% | +3.094513 pp |
| WER | 7.705040% | 7.41% | +0.295040 pp |
| UTMOS | 3.629773 | 3.63 | -0.000227 |
| WhiSQA | 3.622379 | 3.69 | -0.067621 |

Higher EER is better for the privacy metrics. All nine values now come
from the same `_n019_softcap075_recovery_20261119` audio suffix.

The matching W-NT S attacker is:

- Job `2123316964176134146`, `n019_sc075_wnts_shm2_20261119_152617`
- a094f4d10, AI/model-training mode, 1 DCU, 15 CPU / 59 GB
- completed after caching all 104,014 anonymised WAVs in `/dev/shm`
- four epochs, frozen WavLM, AAM margin `0.05`, scale `10`, batch `16`
- female `26.642889%`, male `28.746137%`, mean `27.694513%`
- model SHA256 `8209eb42a52f6c473221ab4e25cca6c0c9efd89aa6a943ece2719396d576aebf`
- summary SHA256 `2147f9dc50f8c040502f1d78b40134f844b3505ed220bceed95c5f1ff57ed535`

Compared with the previous complete no-cap candidate, soft-cap 0.75
improves WER by `0.562182 pp`, UTMOS by `0.020932`, E-VPC I by
`0.6665 pp`, and W-NT S by `0.158719 pp`; it reduces E-VPC S by
`0.8430 pp` and W-NT L by `0.187902 pp`. Thus it is the closest WER /
UTMOS-aligned candidate, but it is not a strict Pareto improvement.

## Execution Note

HPC Job `1165727` completed the anonymisation, W-NT I scoring and E-VPC
scoring in `00:06:16`. Its final summary write failed because the public
output directory had been created earlier by an AI/root job. This is a
packaging permission failure, not a metric failure. Affected metrics were
recovered from:

`/public/home/a094f4d10/voice_projects/logs/n019_official/n019_sc075_missing_1165727.out`

SHA256:
`f20f6bcba5af1a840f8cbd2b544a06cced0213c714b984b381b9dede33c66250`.

E-VPC S was produced by HPC Job `1166106` in `02:47:12`, exit `0:0`.
Its `s_metrics.json` SHA256 is
`7d1d1c1394686bc2c97e5c2cc92ef9de6edd4832470f0a8447e7f42b894cf931`;
the combined summary SHA256 is
`5027f4f08b9e0314364e31e54bd05a8f4304a9c0931f4632bb60beeaac561d8e`.
