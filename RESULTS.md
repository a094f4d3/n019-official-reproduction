# N019 Reproduction Results

This file separates the v0.4.0 selected soft-cap candidate, the previous
formal reference, and diagnostic experiments. Every row below is kept
separate; values from different audio suffixes must not be concatenated.

## v0.4.0 selected candidate

System: `DU-pred-nt` soft-cap 0.75

- Vocoder soup: 84k / 88k / 92k / 96k with weights 40:30:20:10
- Target embedding: NT + ECAPA orthogonal residual 0.5
- Duration extrapolation: 0.5, preserving total predicted duration
- Duration soft cap: 0.75
- Vocoder checkpoint SHA256:
  `ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6`
- WER count: 1,496
- UTMOS / WhiSQA count: 1,934 each

| Metric | Paper | Reproduced | Absolute difference |
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

The exact machine-readable record is
`results/softcap075_complete_20261119.json`.

Compared with the complete no-cap candidate:

- WER improves by `0.562182 pp`;
- UTMOS improves by `0.020932`;
- WhiSQA improves by `0.015850`;
- E-VPC I improves by `0.6665 pp`;
- E-VPC S decreases by `0.8430 pp`;
- W-NT L decreases by `0.187902 pp`.

This is therefore a better WER/MOS-aligned result, not a strict Pareto
improvement over the no-cap candidate.

## Previous formal reference

System: `DU-pred-nt`

- Vocoder soup: 84k / 88k / 92k / 96k with weights 40:30:20:10
- Target embedding: `mean32 + shrink0.1`
- Checkpoint SHA256: `ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6`
- `quality_metrics.json` SHA256: `542cd9fc44e1c03237150078cb67ddb4e7edfe41775f53c77acb7896040d9f5a`
- WER count: 1,496
- UTMOS / WhiSQA count: 1,934 each

| Metric | Paper | Reproduced | Absolute difference | Relative difference |
|---|---:|---:|---:|---:|
| E-VPC I | 47.2% | **48.0285%** | +0.8285 pp | +1.76% |
| E-VPC L | 47.9% | **47.7540%** | -0.1460 pp | -0.30% |
| E-VPC S | 34.8% | **29.7425%** | -5.0575 pp | -14.53% |
| W-NT I | 39.9% | **39.1678579152%** | -0.7321420848 pp | -1.83% |
| W-NT L | 42.3% | **39.7293478251%** | -2.5706521749 pp | -6.08% |
| W-NT S | 24.6% | **24.5238568634%** | -0.0761431366 pp | -0.31% |
| WER | 7.41% | **6.2239598196%** | -1.1860401804 pp | -16.01% |
| UTMOS | 3.63 | **3.5253666541** | -0.1046333459 | -2.88% |
| WhiSQA | 3.69 | **3.4957589100** | -0.1942410900 | -5.26% |

Interpretation:

- Higher is better for EER and MOS; lower is better for WER.
- E-VPC I, E-VPC L, and W-NT S are close to the paper.
- WER is better than the paper value.
- The main remaining gap is E-VPC S (`-5.0575 pp`), followed by
  W-NT L (`-2.5707 pp`).
- The tolerance status in `paper_comparison.json` is an internal
  reporting threshold defined by this project, not a threshold from the
  paper.

## Diagnostic and rejected experiments

These experiments are not part of the formal paper-aligned result and
must not be concatenated with it.

| Experiment | E-VPC S | Relation to formal system | Conclusion |
|---|---:|---|---|
| Formal `mean32 + shrink0.1` | 29.7425% | Formal result | Reference point |
| Full 1,160-speaker mean, no shrink | 31.2000% | Target embedding ablation | `+1.4575 pp`, but UTMOS/WhiSQA regressed |
| S attacker: 20 epochs, lr `1e-3` | 31.0000% | Attack-training ablation | Attack convergence is not the main gap |
| `avg88_92 + full mean` | 29.6955% | Checkpoint ablation | Lower than soup2 full mean |
| Speaker-sampled target pool | 30.6420% | Sampling-policy audit | Not sufficient to close the gap |
| Single utterance target embedding | 30.9685% | Target representation audit | Not sufficient; MOS regressed |
| `DU-nt-nt`, random target | 30.0390% | Duration-conditioning audit | Target-conditioned duration is not the main cause |
| Source-speaker reconstruction | 0.0000% | Leakage diagnostic | The vocoder retains source identity when conditioned on it |
| Opposite-gender target | 42.0405% | Privacy-enhanced diagnostic | Not the paper's unspecified random-target method; excluded from formal result |

## Evidence files

The compact authoritative files are under:

- `results/formal/`: nine formal metrics, MOS/WER JSON, raw EER/MOS
  summaries, and source SHA256 values.
- `results/experiments/`: diagnostic EER JSON files.
- `results/n019_results.json`: normalized machine-readable release table.
- `RESULTS.csv`: flat table suitable for spreadsheets.

The full data, model checkpoints, generated WAV files, and VPC index
files are intentionally not part of this repository release.

## Remote formal result paths

- EER and assembled nine-metric table:
  `/public/home/a094f4d6/voice_projects/runs/n019_official/privacy/du_pred_nt_soup2_w40_shrink01_final_r2_20261111`
- WER, UTMOS, and WhiSQA:
  `/public/home/a094f4d7/voice_projects/runs/n019_official/eval_user/du_pred_nt_soup2_w40_shrink01_20261110`
