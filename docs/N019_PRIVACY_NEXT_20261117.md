# N019 privacy follow-up

## Confirmed state

The formal result remains the layer-6 `DU-pred-nt` soup with
`mean32 + shrink0.1` target conditioning:

| metric | formal | paper |
|---|---:|---:|
| E-VPC S | 29.7425 | 34.8 |
| W-NT L | 39.7293478 | 42.3 |
| WER | 6.2239598% | 7.41% |
| UTMOS | 3.5253667 | 3.63 |
| WhiSQA | 3.4957589 | 3.69 |

## New results

### Layer-9 20k E-VPC S

Job `1144607` completed normally in `02:56:01`.

- female: 30.439%;
- male: 29.397%;
- mean: 29.918%;
- delta vs formal: +0.1755 pp;
- delta vs paper: -4.882 pp.

This closes the layer-9 branch for timbral privacy: even after its
quality-improving 20k adaptation, it does not materially improve E-VPC S.
Do not infer that another layer-9 checkpoint will solve S.

### Layer-9 from-scratch launch failure

AI Job `2122567216179675138` passed the 300-second DCU watchdog but failed in
`verify_local_unit_records.py` because all 33,236 `audio` paths still pointed
at d6. No training step ran. Do not resubmit this JobID. A future scratch run
requires a d10-local LibriTTS-clean-100 audio tree and rewritten records.

## Active experiment

d10 HPC Job `1147640` is retraining the unconditional duration predictor with
the DISSC-derived optimizer scale:

- 60 epochs;
- batch 64;
- learning rate `8e-4`;
- same LibriSpeech clean-100 records and architecture;
- output
  `/public/home/a094f4d10/voice_projects/runs/n019_official/duration_pred_strong_20261117`.

This is not a repeat of the completed duration/ECAPA/S-attacker experiments.
It isolates whether the unconditional average-rhythm predictor was
under-trained at the local `3e-4` optimizer setting, and therefore whether
stronger rhythm conversion can improve W-NT L without changing units or the
vocoder.

The training completed in 7m39s. The selected `best.pt` SHA256 is
`ba74d00cc7910bcb26b0a75ddb52ea33d8230526b3aeb321b92b6124018d31a2`.
On the first 200 test utterances, its global duration ratio is `0.993082`
versus formal `0.991049`; mean absolute total-duration error is `0.045332`
versus `0.044447`; per-unit predicted-duration correlation is `0.803011`.
The new model learned a different average-duration function, but the final
decision still requires the full quality/W-NT test.

Full test result:

| metric | strong duration | formal |
|---|---:|---:|
| WER | 6.203984% | 6.223960% |
| UTMOS | 3.531020 | 3.525367 |
| WhiSQA | 3.503066 | 3.495759 |
| W-NT I | 39.039445% | 39.167858% |
| W-NT L | 39.184537% | 39.729348% |

Quality is effectively unchanged, but both non-timbral privacy metrics
regress, especially L. Stronger MSE training is not the source of the W-NT
gap. The branch is rejected.

## Vocoder conditioning scale

The anonymiser now records and applies an explicit
`--speaker-embedding-scale` (default `1.0`). This supports a controlled
target-conditioning-strength test without changing checkpoint architecture.
No formal result uses a value other than `1.0`.

The first use of the parameter must compare `1.0`, `1.5`, and `2.0` on the
fixed speaker-disjoint dev-100 with the same source/unit/target assets. A full
test and LS360 S run is allowed only if the selected scale preserves the
quality gate and improves the target-shift diagnostic.

d10 HPC `1147683` has been submitted with `afterok:1147640`. It evaluates
`1.5x` and `2.0x` on the complete official test set using the formal units,
target map, `mean32 + shrink0.1` embeddings, unconditional duration and soup
vocoder. The formal `1.0x` quality/W-NT result is already known and is not
rerun. Only a scale satisfying the quality gate advances to LS360 E-VPC S.

The first scale submission `1147683` failed in embedding preflight because
the 1,158-key full archive did not exactly match the 843 test-map keys. It
produced no WAV or metric. Retry `1147832` uses the validated 843-key subset
SHA256 `5d00633b04e1ab4b70ebb40b657aa36c25f7809c64a5ce0333d1d2d5e14834c4`.

Retry `1147832` measured scale `1.5` before being stopped:

- WER `6.503624%`;
- UTMOS `3.057108`;
- WhiSQA `3.145502`;
- female W-NT L `43.428998%`, versus formal female `37.808798%`.

The target-conditioning axis is real, but direct amplified inference is too
far outside the trained distribution. Scale `2.0` was not run.

d10 HPC `1147727` is queued after `1147683` to evaluate the strong duration
predictor on the complete test set with units, target mapping, target
embedding and vocoder held fixed. This isolates the W-NT L hypothesis and
avoids a concurrent second card-hour job.

`1147727` was auto-cancelled by the failed dependency before starting.
Corrected Job `1147833` is queued after `1147832`; it produces no duplicate
work from the cancelled Job.

`1147940` then repeated the 1,158-key versus 843-key preflight mistake and
failed in 29 seconds with no output. Corrected Job `1147970` uses the same
validated 843-key subset and remains queued behind the calibration branch.

## Learned conditioning calibration

d10 HPC `1147969` trains from the formal soup for only 2,000 steps at
`5e-5`, with speaker conditioning scaled to `1.5` in both training and
inference. It evaluates the 1k and 2k snapshots on full quality and W-NT I/L.
The purpose is to preserve the W-NT gain seen from stronger conditioning while
removing its UTMOS/WhiSQA penalty. This is an explicit structural calibration,
not a paper-claimed parameter.

The 1k calibrated checkpoint still failed decisively:

- WER `6.372353%`;
- UTMOS `2.875843`;
- WhiSQA `2.996429`.

Validation mel-L1 improved, so this is not a failed optimization; it means
stronger speaker amplitude is intrinsically trading away perceptual quality
in the current generator. The job was stopped before 2k quality and W-NT.
Do not resubmit this calibration recipe.

## NT plus ECAPA residual

A 247-speaker paired ridge map from ECAPA to NT initially reached in-sample
`R2=0.880012`, but 5-fold CV was `R2=-3.382770`, so that map was rejected
before execution. Ridge weight `30000` gives train `R2=0.464867` and CV
`R2=0.195651`; this is the corrected conservative map. Instead of changing
the vector norm, the next screen adds only the component
of the ECAPA-predicted NT vector orthogonal to the observed NT vector:

- strength `0.25`: mean cosine to original NT `0.990815`;
- strength `0.5`: mean cosine to original NT `0.964894`.

Job `1148319` evaluates both on the full test set while holding units,
target map, duration, vocoder and inference scale `1.0` fixed. This is a
bounded test of whether target timbral information can be strengthened
without the quality collapse caused by amplitude scaling.

Corrected Job `1148332` uses the CV-selected ridge weight `30000`; Job
`1148319` was cancelled before start and must not be resubmitted.

`1148332` was auto-cancelled when the upstream duration Job failed only in
its compact summary parser. Final corrected retry `1148449` uses the CV-map
and the fixed W-NT parser.

Completed residual screen:

| strength | WER | UTMOS | WhiSQA | W-NT I | W-NT L |
|---:|---:|---:|---:|---:|---:|
| 0.25 | 6.164032% | 3.602459 | 3.585092 | 39.279869% | 39.873361% |
| 0.5 | 6.069859% | 3.672624 | 3.660854 | 38.582350% | 39.201399% |
| formal | 6.223960% | 3.525367 | 3.495759% | 39.167858% | 39.729348% |

Strength `0.25` is the balanced candidate and must be screened on full LS360
E-VPC S. Strength `0.5` is quality-strong but privacy-weaker on W-NT.

## Independent layer-9 from-scratch training

d10 HPC `1148888` is now the only long training branch. It uses the HPC
read-only cross-account path that already passed verification, training an
independent layer-9 Unit HiFi-GAN from scratch for at most 20 h. This follows
the paper's statement that the two vocoders are trained independently and is
not a repeat of the adapted layer-9 model.

The scratch Job was stopped after 24 seconds so the decisive residual0.25
E-VPC S evaluation could run first; it had not reached a meaningful step.
Job `1148911` now anonymises all 104,014 LS360 rows with residual0.25 and
retrains the official ECAPA S attacker. Its result determines whether this
candidate is viable.

## 2026-11-18 residual and duration closure

Residual0.25 official E-VPC S is `31.1355%` (female `30.655%`,
male `31.616%`), `+1.3930 pp` over the formal `29.7425%` but still
`-3.6645 pp` from the paper `34.8%`.

Adding duration extrapolation `0.5` with predicted total-duration
preservation produced:

| metric | residual0.25 + durextra0.5 | formal |
|---|---:|---:|
| WER | 8.104560% | 6.223960% |
| UTMOS | 3.545013 | 3.525367 |
| WhiSQA | 3.533804 | 3.495759 |
| W-NT I | 42.528977% | 39.167858% |
| W-NT L | 41.938851% | 39.729348% |
| E-VPC S | **30.5635%** | **29.7425%** |

The duration axis materially improves W-NT L, but its E-VPC S is
`-0.5720 pp` below residual0.25 and still `-4.2365 pp` below paper.
This branch is closed for timbral privacy.

The stronger residual0.5 target embedding was then combined with the same
duration extrapolation:

| metric | residual0.5 + durextra0.5 | paper |
|---|---:|---:|
| WER | 8.267222% | 7.41% |
| UTMOS | 3.608841 | 3.63 |
| WhiSQA | 3.606529 | 3.69 |
| W-NT I | 42.723927% | 39.9% |
| W-NT L | 41.801279% | 42.3% |

This is the strongest balanced candidate so far: it improves quality and
W-NT I relative to residual0.25 + durextra0.5 while keeping W-NT L within
`-0.498721 pp` of paper. Its matching official LS360 E-VPC S is running as
d10 HPC `1152779`; no metric from another suffix may be substituted.
