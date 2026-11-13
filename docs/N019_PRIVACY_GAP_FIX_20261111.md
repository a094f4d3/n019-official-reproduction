# N019 E-VPC S and W-NT L gap diagnosis

Date: 2026-11-11

## Current formal result

| Metric | Current | Paper | Absolute gap |
|---|---:|---:|---:|
| E-VPC S | 29.7425 | 34.8 | -5.0575 |
| W-NT L | 39.7293478251 | 42.3 | -2.5706521749 |

All other privacy metrics are close or better than paper. W-NT S is
24.523857 against 24.6. This makes E-VPC S and W-NT L the two
remaining high-impact privacy residuals.

## Why these two need a targeted experiment

The formal inference target embedding is a sparse `mean32` per target
speaker with a 0.1 centroid shrink. The paper only says that a target
speaker embedding is randomly sampled from LibriTTS train-other-500;
it does not publish the pooling rule or shrink.

Earlier utterance-level inference improved W-NT L from 39.7293 to
40.5973, but lowered UTMOS by 0.154 and WhiSQA by 0.169. Therefore
the raw utterance vector is informative but too disruptive. A convex
mix can test whether part of that privacy gain is available at lower
quality cost.

The E-VPC S gap is larger and is measured by retraining the official
VPC ECAPA model on anonymised LibriSpeech train-clean-360. The current
run used the same random-target, speaker-mean/shrink path as formal
test inference. A previous diagnostic VPC view still contains an
utterance-target anonymisation of train-clean-360 and the corresponding
test suffix. Re-running only the official S model on that frozen data
cannot tell us about a new candidate checkpoint, but it can distinguish
whether the utterance-target path is a plausible cause.

## Running diagnostics

### Cancelled Job 1090683

`n019_paperfix_s_eval_r1` re-runs the official VPC post path on the
existing paperfix/utterance-target data view.

- account: a094f4d6
- mode: HPC/Slurm `hx1hdnormal`
- resources: 1 DCU, 16 CPU, 60 GB
- wall clock: 2 h
- expected/worst: 1.5 / 2.0 card-hours
- purpose: measure E-VPC S under the older utterance-target data path
- stop condition: missing VPC data, DCU watchdog failure, non-finite
  loss, timeout, or parse failure

The job was cancelled after 54m08s when the speaker-vs-utterance target
sampling mismatch was found. It had completed five training epochs, but
the result would have confounded the old checkpoint and target protocol.
No `s_metrics.json` was produced.

### Job 1090831

`n019_target_mix_wntl` evaluates three convex target-embedding mixes on
the full 1,934 official test utterances:

- base: current `mean32 + shrink0.1` speaker vector
- detail: utterance-level target vector
- mixture weights: 0.25, 0.50, and 0.75 utterance contribution
- each vector is L2-normalised after mixing
- metric: W-NT L female/male/mean EER
- account: a094f4d6
- mode: HPC/Slurm `hx1hdnormal`
- resources: 1 DCU, 16 CPU, 60 GB
- wall clock: 1 h
- expected/worst: 0.35 / 1.0 card-hours
- dependency: afterok:1090683
- stop condition: input SHA mismatch, incorrect official counts,
  watchdog failure, non-unit embedding, or timeout

This experiment does not retrain the vocoder. It only changes the
inference target vector, renders audio, and runs the official W-NT L
attack.

### Cancelled full-mean screen

Job 1090872 proposed to screen the complete 168,023-utterance speaker
mean. It remained pending and was cancelled after a higher-impact
target-sampling mismatch was found. The script remains available, but
the job spent no card time.

### Job 1091233

The paper text says that a target speaker embedding is randomly sampled
from LibriTTS train-other-500. The current test map instead samples
uniformly over target utterances. That gives 843 target speakers for
1,934 trials. Uniform sampling over the 1,158 target speakers with
available mean embeddings gives 954 target speakers and is better
aligned with the paper wording.

Job 1091143 evaluates this target-speaker sampling change with the same
checkpoint, speaker-mean/shrink embedding, durations, and official
W-NT L trials.

- account: a094f4d6
- mode: HPC/Slurm `hx1hdnormal`
- resources: 1 DCU, 16 CPU, 60 GB
- wall clock: 45 min
- expected/worst: 0.3 / 0.75 card-hours
- target map SHA256:
  `d88027cd85a9ef30b7926a6fe870e199b4095247212065109a7b563645174324`
- output:
  `/public/home/a094f4d6/voice_projects/runs/n019_official/privacy/speaker_sampling_wntl_20261111`

Result:

| W-NT L condition | mean EER |
|---|---:|
| current utterance-sampled target map | 39.7293478251 |
| speaker-sampled target map | **40.3585813940** |
| paper | 42.3 |

The speaker-sampling change improves W-NT L by **+0.6292335689
percentage points**. It is a real improvement but does not close the
gap by itself.

### Target-sampling distribution audit

The sampling mode changes the target distribution substantially:

| split | mode | target speakers | per-speaker maximum |
|---|---|---:|---:|
| test, 1,934 rows | utterance | 843 | 13 |
| test, 1,934 rows | speaker | 954 | 8 |
| LS360, 104,014 rows | utterance | 1,158 | 399 |
| LS360, 104,014 rows | speaker | 1,158 | 125 |

The paper phrase "a randomly sampled target speaker embedding" is
better aligned with uniform speaker sampling. The current implementation
instead samples target utterances uniformly, so speakers with many
utterances are over-represented. This is now the leading
paper-implementation mismatch for both privacy targets.

Two other500 speakers, `147` and `7683`, do not yet have mean32
embeddings in the 1,158-key archive. The test diagnostic excludes those
two speakers from its target manifest. Any formal adoption must compute
their embeddings before claiming full-pool coverage.

Prepared speaker-sampled LS360 target map:

`/public/home/a094f4d6/voice_projects/runs/n019_official/target_sampling_diag_20261111/librispeech_train_clean_360_target_map_speaker_available_seed20261102.jsonl`

SHA256:
`e57788b434df2d11ff288d7b0280918c592b7cea32932a9c7b60c74da5ab0b08`

This map has all 104,014 rows, all 1,158 available target speakers, and
63 to 125 rows per target speaker.

### Job 1091285

The controlled S pipeline is submitted as Job 1091285, dependent on the
target-mix screen Job 1091281.

- account: a094f4d6
- mode: HPC/Slurm `hx1hdnormal`
- resources: 1 DCU, 16 CPU, 60 GB
- wall clock: 4 h
- expected/worst: 3.0 / 4.0 card-hours
- data suffix: `_n019_spksamplediag_20261111`
- output:
  `/public/home/a094f4d6/voice_projects/runs/n019_official/privacy/du_pred_nt_spksamplediag_s_eval_20261111`
- stop condition: watchdog failure, missing inputs, non-finite loss,
  incorrect counts, timeout, or parse failure

## Predeclared selection rule

A mixture is only promoted to full quality and E-VPC S evaluation if:

1. W-NT L improves over the current 39.7293 formal result;
2. the candidate is not explained by a protocol or count mismatch;
3. full UTMOS/WhiSQA/WER are then measured on all official rows;
4. for any proposed formal replacement, UTMOS and WhiSQA should not
   regress by more than 0.05 absolute each, and WER should not regress
   by more than 0.25 percentage points without an explicit trade-off
   decision;
5. E-VPC S must be re-run on a candidate-specific anonymisation of
   full train-clean-360, not inferred from test-only W-NT results.

## Cancelled diagnostic

Job 1090842 proposed a fixed target speaker per source speaker. It was
cancelled while still pending. The direction is not a plausible fix:
keeping the target voice consistent across enrollment and trials makes
the W-NT L trial pair easier to link and should reduce EER, whereas the
paper value is higher than the current result. The scripts are retained
for audit but the job spent no card time and its output is not evidence.

## 2026-11-11 target-shrink and S follow-up

### E-VPC S with uniform target-speaker sampling

d6 HPC Job `1091285` completed the full 104,014-utterance LS360
anonymisation and the official 10-epoch ECAPA S retraining. The
evaluation itself produced the six EER rows and then the launcher
aborted while writing the summary because of a postprocessing
filesystem error. The official `results_anon.txt` is intact and
`s_metrics.json` was rebuilt from it on CPU.

| condition | current E-VPC S |
|---|---:|
| previous utterance-sampled map, shrink0.1 | 29.7425 |
| speaker-sampled map, shrink0.1 | **30.6420** |
| paper | 34.8 |

The target-sampling correction improves S by `+0.8995 pp`, but the
remaining gap is `-4.1580 pp`. Target sampling is therefore a real but
secondary cause of the S residual.

`s_metrics.json` SHA256:
`307f9366f7f46fe582de81f1c23ef84d51b3a70048d6ef91287eb992e158198a`.

The dependent shrink0.05 S Job `1092021` was cancelled automatically
when this parent job exited non-zero. It was resubmitted as d6 HPC Job
`1092755` with the same speaker-sampled map, shrink0.05 embeddings,
full LS360 anonymisation and official ECAPA retraining.

### E-VPC I/L target-shrink screen

The existing 1,934 WAV/VPC outputs at shrink0.05 and shrink0 were
evaluated with the original E-VPC model. The E-VPC output path now
copies `asv_orig` into the job directory before evaluation, avoiding
root-owned score directories inherited from AI-container runs.

| target shrink | E-VPC I | E-VPC L |
|---|---:|---:|
| formal shrink0.1 | 48.0285 | 47.7540 |
| shrink0.05 | **46.8930** | **47.6450** |
| shrink0 | **47.3850** | **47.6340** |
| paper | 47.2 | 47.9 |

shrink0 removes the large excess privacy in E-VPC I while keeping E-VPC
L within `0.27 pp` of the paper. This is a stronger paper-aligned
privacy configuration because no shrink toward a global centroid is
documented by the paper.

### W-NT I/L target-shrink screen

| target shrink | W-NT I | W-NT L |
|---|---:|---:|
| formal shrink0.1, old utterance-sampled map | 39.1679 | 39.7293 |
| shrink0.05, speaker-sampled map | 38.9625 | **41.0403** |
| shrink0, speaker-sampled map | **39.5045** | **41.2432** |
| paper | 39.9 | 42.3 |

Both lower-shrink settings close most of the W-NT L gap. shrink0 also
improves W-NT I relative to the formal result and paper (gap only
`-0.3955 pp`), whereas shrink0.05 lowers W-NT I. The remaining W-NT L
gap at shrink0 is `-1.0568 pp`.

The three-seed control changes that conclusion. With shrink0 and the
three independently generated speaker maps `20261103/04/05`, W-NT L is:

| seed | W-NT L |
|---:|---:|
| 20261103 | 40.0028 |
| 20261104 | 40.1629 |
| 20261105 | 40.1546 |

Mean `40.1068`, population standard deviation `0.0736`. On the same
seed 20261103 map, shrink0.1 gives `39.9580` and shrink0 gives
`40.0028`, only `+0.0447 pp`. The `41.2432` value at seed 20261102
is therefore a favorable target-map outcome, not a stable shrink
effect. The single-seed improvement must not be described as a general
fix for the W-NT L residual.

### Full 1,934-utterance quality

All UTMOS and WhiSQA values below cover exactly 1,934 utterances; WER
covers exactly 1,496 utterances.

| target shrink | WER | UTMOS | WhiSQA |
|---|---:|---:|---:|
| formal shrink0.1 | 6.22396% | 3.52537 | 3.49576 |
| shrink0.05 | 6.28389% | 3.48070 | 3.47421 |
| shrink0 | 6.25250% | 3.45550 | 3.44480 |
| paper | 7.41% | 3.63 | 3.69 |

shrink0.05 stays within the predeclared full-quality regression
threshold (`<=0.05` for each MOS metric and `<=0.25 pp` for WER).
shrink0 gives a larger privacy gain but its UTMOS/WhiSQA regression is
`-0.0699/-0.0510`, slightly outside the two-MOS threshold. It remains
useful as a privacy-oriented candidate if the E-VPC S improvement is
large enough to justify the quality trade-off.

### Interpretation

1. The paper wording supports uniform target-speaker sampling; the
   previous implementation sampled target utterances and over-weighted
   prolific target speakers.
2. Removing the undocumented 0.1 centroid shrink gives attractive
   single-seed E-VPC I/L and W-NT I/L numbers, but the new seed control
   shows that W-NT L is highly sensitive to the target map. Shrink is
   not a robust standalone fix.
3. The remaining E-VPC S gap is not explained by target sampling alone.
   The shrink0.05 S retraining is in progress to separate the shrink
   effect from other ECAPA/S-protocol factors.

### Later-checkpoint control

To rule out checkpoint selection, W-NT L was screened with the same
shrink0.05 embeddings and target-map seed on later generators:

| step | W-NT L |
|---:|---:|
| 100k | 40.1966 |
| 102k | 40.1175 |
| 106k | 40.9905 |
| 112k | 40.0386 |
| 134k | 40.6948 |
| 136k | 40.5316 |

There is no monotonic privacy gain and no checkpoint above the paper
value. The 106k peak remains `-1.3095 pp` below paper. Job `1093016`
completed 100k/102k/106k and then stopped because the 112k filename
was `generator_d5_step00112000.pt`; Job `1093169` used explicit
symlinks and completed the 112k/134k/136k controls.

The evidence now rules out three simple explanations for W-NT L:
target-map seed, centroid shrink, and more training. The remaining gap
must come from vocoder conditioning/leakage, duration allocation, or
an unpublished training/protocol choice.

## 2026-11-11 E-VPC S shrink control and utterance-target follow-up

The speaker-sampled shrink0.05 S Job `1094009` completed with female
`31.387%`, male `30.070%`, and mean `30.7285%`. This is only
`+0.0865 pp` over the speaker-sampled shrink0.1 result (`30.6420%`) and
still `-4.0715 pp` from the paper. The dependency on this job cancelled
the shrink0 S job `1094023`; reducing centroid shrink is therefore not
a meaningful E-VPC S lever.

The next controlled test uses one target utterance embedding per
source utterance, sampled uniformly over target speakers. The available
pool is the 81,605 unique target utterances already embedded for the
earlier full LS360 map; this avoids any new neural extraction. The test
and LS360 map hashes are `c139d91f...d24d7` and `4a94aed9...d19252`;
the corresponding unit-norm embedding subset hashes are
`20e09544...63415` and `fdf52668...594e4`.

On all 1,934 test utterances the pure utterance-target screen produced:

| condition | WER | UTMOS | WhiSQA |
|---|---:|---:|---:|
| formal mean32 + shrink0.1 | 6.22396% | 3.52537 | 3.49576 |
| speaker-uniform utterance | **6.18686%** | 3.35346 | 3.33034 |
| paper | 7.41% | 3.63 | 3.69 |

WER improves slightly, but both MOS values regress by more than the
usual 0.05 gate. The privacy value must therefore be measured directly.
d6 Job `1095367` is anonymising all 104,014 LS360 utterances with this
same target representation and running the official 10-epoch E-VPCA S
retraining. Only an S result near or above 34 would justify carrying this
trade-off forward; otherwise the mixed target representation or a
different source of identity leakage must be investigated.

The same test suffix gives W-NT L `41.018149%` (female `41.058850%`,
male `40.977447%`), versus `39.729348%` for the formal model and
`42.3%` in the paper. It is a real privacy gain of `+1.288801 pp`, but
the loss reaches only about half of the remaining W-NT L gap and costs
`-0.171911 / -0.165424` UTMOS/WhiSQA. The E-VPC S result is therefore
the deciding measurement.

## 2026-11-11 utterance-target E-VPC S result

Job `1095367` completed the 104,014-utterance LS360 anonymisation and
the official 10-epoch ECAPA retraining. The platform marked the job
failed only because MIOpen aborted during teardown after the six EER
rows had been written. Reconstruction from the complete
`results_anon.txt` gives E-VPC S female `30.109%`, male `31.828%`, and
mean `30.9685%`.

This is only `+1.2260 pp` over the formal `29.7425%` and remains
`3.8315 pp` below the paper. The same test audio also lowers UTMOS and
WhiSQA by `0.171911` and `0.165424`. The evidence now excludes target
sampling, target pooling level, and centroid shrink as the dominant
cause of the S gap.

The next no-long-training candidate is the paper's `DU-nt-nt` row:
the NT-conditioned duration predictor and the NT vocoder both receive
the same speaker-pooled target embedding. The paper reports E-VPC S
`34.1`, W-NT L `42.5`, WER `7.73`, UTMOS `3.63`, and WhiSQA `3.69`
for this system. The implementation now supports a separate
`--duration-embedding-key` so the speaker-level duration model can use
`target_speaker` at inference rather than an utterance key.

## 2026-11-12 opposite-gender privacy calibration

The paper-aligned random-target `DU-nt-nt` result is E-VPC S
female `29.563%`, male `30.515%`, mean `30.039%`. It improves the
formal result by only `+0.2965 pp`; target-conditioned duration is not
the dominant residual cause.

The source-target gender audit found that the existing target map is
opposite-gender for only `48.7%` of test utterances. A deterministic
target-speaker-uniform map was generated from the same original
LibriTTS train-other-500 pool with an opposite-gender constraint:

- test map SHA256 `96c3bb8f...6c205f493`;
- LS360 map SHA256 `8956628f...dfd6376b`.

The complete 104,014-utterance LS360 anonymisation completed in
`1:20:52`, with 104,014 WAV/VPC entries and all output checks passing.
The official 10-epoch E-VPC S retraining then completed in `1:27:36`.

| condition | result | formal baseline | paper |
|---|---:|---:|---:|
| E-VPC S | **42.0405** | 29.7425 | 34.8 |
| E-VPC I | 47.1920 | 48.0285 | 47.2 |
| E-VPC L | 49.0715 | 47.7540 | 47.9 |
| W-NT I | 39.3920 | 39.1679 | 39.9 |
| W-NT L | 41.1030 | 39.7293 | 42.3 |
| WER | 6.2924% | 6.2240% | 7.41% |
| UTMOS | 3.4589 | 3.5254 | 3.63 |
| WhiSQA | 3.4915 | 3.4958 | 3.69 |

The opposite-gender variant is a privacy-enhanced calibration, not a
strict reproduction of the paper's unspecified random-target seed and
gender policy. It brings E-VPC S well above the paper value while WER
remains better than the paper and MOS stays close to the formal model.
It should be reported as a separate variant rather than replacing the
paper-aligned `DU-nt-nt` row.

## 2026-11-12 source reconstruction and checkpoint controls

The source-reconstruction diagnostic (`1101644`) conditioned the vocoder on
each source speaker's own W-PRO mean. The official ECAPA S retraining reached
`AA EER = 0.000%` for both female and male test subsets, with final validation
speaker error rate `0.128%`. This shows that the current unit/vocoder path can
preserve source identity almost perfectly when supplied with the source
embedding. The low random-target S score is therefore not caused by an
inability of the vocoder to represent speaker identity.

The paper-aligned full-other500/no-shrink target still gives only `31.200%`
S. Replacing soup2 with the earlier `avg88_92` checkpoint (`1102767`) gives
`29.6955%`, lower than both fullmean soup2 and the formal shrink result. Thus
neither target-pool completeness nor checkpoint/soup selection explains the
remaining gap to the paper's `34.8%`.

The next control (`1103529`) keeps the exact fullmean1160 anonymised WAV set
and changes only the E-VPC S retraining schedule from the official
`lr=0.01, 10 epochs` to the same authors' prior published convergence
adjustment, `lr=0.001, 20 epochs`. This is deliberately labeled a diagnostic,
not the official paper configuration. It tests whether S-training convergence
explains the metric gap; it must not be mixed into the formal paper table
without explicit qualification.

The adjusted run completed with training loss `7.98` and validation speaker
error rate `89.7%`, versus loss `9.10` and error rate `85.3%` for the official
10-epoch run. Its E-VPC S was female `29.929%`, male `32.071%`, mean
`31.000%`, which is `0.200 pp` below the official-schedule result. S-training
convergence therefore does not explain the paper gap.
