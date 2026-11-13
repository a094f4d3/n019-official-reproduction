# N019 Quality Gap Optimization Plan

## Current evidence

- ext102k full WER: `6.7547514411%` (paper `7.41%`).
- ext102k full UTMOS: `2.6142479994` (paper `3.63`,
  absolute gap `-1.015752`).
- ext102k full WhiSQA: `2.7501946269` (paper `3.69`,
  absolute gap `-0.939805`).
- GPU and CPU WhiSQA differ by only `2.769e-6`; the remaining gap is
  model/audio quality, not evaluator or node behavior.
- d7's deployed `feature_matching_loss` was still 1x when step 4k,
  76k and 102k were trained. The local 2x correction has now been
  synchronized to d7.
- The duration A/B changes MOS by only about `0.02-0.05`; it is not
  the primary cause.
- Training uses clean-100 speaker-level W-PRO embeddings while
  inference uses other-500 target utterance-level W-PRO embeddings.
  The paper does not specify the pooling rule, so this needs an A/B.

## Ordered experiments

### E1: target embedding pooling A/B (first)

- Fixed inputs: ext102k vocoder, predicted durations, same 100
  libri_test utterances and target map.
- Variant A: existing utterance-level target embeddings.
- Variant B: target-speaker mean obtained by averaging the available
  selected target embeddings per `target_speaker`, then L2-normalizing.
- Generate both WAV sets, then score both with UTMOS and WhiSQA on a
  healthy DCU.
- Gate: keep the variant only if the paired mean improves by at least
  a predeclared meaningful margin and does not damage WER.
- Resource: 1 DCU, 15 CPU / 59 GB, 45 minutes; estimated `0.2`, worst
  `0.75` card-hour.

### E2: checkpoint/MOS selection sweep

- Reuse existing 34k, 76k and 102k checkpoints on the same fixed
  sample set.
- Evaluate UTMOS and WhiSQA on GPU, then report paired means and
  standard errors.
- Do not select by mel L1 alone.
- Resource: 1 DCU, 15 CPU / 59 GB, 45 minutes; estimated `0.2`, worst
  `0.75` card-hour.

### E3: short 2x fine-tune diagnostic

- Resume ext102k under the corrected 2x feature-matching loss for a
  short, bounded run.
- Save frequent checkpoints and score several of them on the fixed
  sample set.
- This is a diagnostic only; it is not an official from-scratch 2x run.
- Resource: 2 DCU, 15 CPU / 59 GB per card, 2 hours; estimated `4.0`,
  worst `4.0` card-hours.

### E4: full 2x NT vocoder retrain

- Only start if E3 shows a repeatable MOS gain.
- Train from step 0 with the corrected 2x loss and a speaker-disjoint
  MOS validation subset.
- Use resumable jobs and save enough checkpoints to compare selection
  metrics.
- Resource and account must be planned separately from the measured
  throughput and current balance.

## Stop rules

- No 1,934-sentence run before a small-sample gain clears the noise
  gate.
- Any DCU task starts with the 300-second tiny-matmul watchdog.
- Do not overwrite step4k/76k/102k checkpoints or completed official
  outputs.
