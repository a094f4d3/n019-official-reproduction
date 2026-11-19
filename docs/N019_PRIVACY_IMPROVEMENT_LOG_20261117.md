# N019 privacy improvement experiment log

Updated: 2026-11-17

The formal baseline remains:

| Metric | Reproduced | Paper |
|---|---:|---:|
| E-VPC I / L / S | 48.0285 / 47.7540 / 29.7425 | 47.2 / 47.9 / 34.8 |
| W-NT I / L / S | 39.1678579 / 39.7293478 / 24.523857 | 39.9 / 42.3 / 24.6 |
| WER | 6.2239598% | 7.41% |
| UTMOS / WhiSQA | 3.5253667 / 3.4957589 | 3.63 / 3.69 |

## Closed experiments

| Direction | Result | Decision |
|---|---|---|
| target shrink 0.1 -> 0.05 | E-VPC S `30.7285%`, only `+0.0865 pp` | closed |
| complete fullmean target pool, no shrink | E-VPC S `31.200%`; MOS regressed | closed as replacement |
| speaker-sampled targets | E-VPC S `30.642%`; W-NT L `40.359%` | useful diagnostic only |
| single target-utterance embedding | E-VPC S `30.9685%`; MOS regressed | closed |
| `DU-nt-nt` random target | E-VPC S `30.039%` | target-conditioned duration is not the main S cause |
| checkpoint soup / late snapshots | no robust S gain | do not repeat |
| S attacker 20 epochs / `1e-3` | E-VPC S `31.000%` versus `31.200%` | closed |
| source reconstruction | E-VPC S `0%` | proves conditioning is followed when source identity is supplied |
| layer-9 8k / 20k | W-NT L improves, S and MOS do not | closed for formal replacement |
| direct conditioning scale `1.5x` | high privacy, severe MOS loss | closed |
| train-time conditioning-scale calibration | still MOS `2.876/2.996` | closed |
| stronger duration predictor | W-NT L `39.185%` | closed |
| NT + ECAPA residual 0.25 | quality `3.602/3.585`, W-NT L `39.873%` | full S currently running |
| NT + ECAPA residual 0.5 | quality stronger, W-NT weaker | not selected |
| opposite-gender target | S `42.0405%`, W-NT L `41.103%` | diagnostic only; not a paper-aligned method |

## Current decisive measurement

d10 HPC `1148911` is measuring E-VPC S for NT+ECAPA residual strength `0.25`
on the complete 104,014-utterance LS360 set with the official 10-epoch ECAPA
attacker. This is the first residual candidate that improves full-test quality
and both W-NT I/L, so its S result decides whether the representation is worth
carrying forward.

## Next non-duplicate experiment

The formal vocoder is trained with the source speaker's own embedding but used
at inference with a random target embedding. A bounded fine-tune will replace
50% of training conditions with target speakers sampled from the actual
train-other-500 inference distribution while preserving the source waveform
reconstruction target and the trained discriminators.

This targets the source-speaker shortcut directly and was not covered by target
pooling, shrink, inference scaling, duration or unit-layer experiments.

Resources: d10 HPC, 1 DCU, 16 CPU / 60 GB, 2 h; expected/worst
`0.8/2.0` card-hours. The fixed 40-speaker dev gate requires UTMOS and WhiSQA
each at least `+0.05`, with WER regression no more than `0.25 pp`. A passing
snapshot still needs full W-NT and LS360 E-VPC S evaluation; dev quality alone
cannot replace the formal model.
