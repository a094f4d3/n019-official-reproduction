# N019 cross-speaker conditioning fine-tune

## Why this experiment

The completed target-pool, pooling, shrink, checkpoint-soup, layer-9,
S-attacker, duration, source-reconstruction and conditioning-scale controls
leave one training-recipe difference that has not been tested:

> The official vocoder is trained to reconstruct each waveform using its own
> source speaker embedding, while anonymisation inference replaces that
> embedding with a random target speaker.

The source-reconstruction diagnostic reaches E-VPC S `0%`, proving that the
generator follows speaker conditioning when it contains source identity. The
formal random-target model still reaches only `29.7425%`, so the generator may
also retain source-speaker shortcuts from the unit sequence. Target pooling or
post-hoc scaling cannot remove those shortcuts. They must be regularised
during training.

The new branch therefore fine-tunes the formal generator with a mixture of
same-source and cross-speaker conditioning. It is an explicit structural
improvement, not a paper-confirmed setting. The default remains the original
same-speaker training recipe.

## Design

- Initialize from the formal layer-6 soup generator:
  `ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6`.
- Preserve the already-trained MPD/MSD weights and discriminator optimizer
  state from the d5 long-run `last.pt`:
  `89768a4b94a7a326c02eeaf216022df2341abe36312149b6dac18c5048558c23`.
- Reset only the generator optimizer for a low-LR fine-tune at `5e-5`.
- For 50% of training examples, replace the source-speaker embedding with a
  speaker mean sampled from the exact inference target distribution
  (the 1,158-speaker NT+ECAPA residual0.25 archive). This keeps
  the source waveform as the reconstruction target while forcing the
  generator to rely on the supplied target condition instead of only the
  source-corpus conditioning distribution. Validation always uses the
  original same-speaker embedding.
- Train 4,000 steps, saving generator snapshots every 1,000 steps.
- Keep the original units, target map, duration predictor, target embedding,
  feature-matching factor, optimizer family and GAN architecture unchanged.

Preserving the trained discriminators avoids the transient observed in the
earlier generator-only `5e-5` annealing attempt, where a newly initialized
discriminator drove UTMOS down at 2,000 steps.

## Gate

The fixed 40-speaker dev-100 must satisfy, relative to the residual0.25
baseline evaluated with the same target archive:

- UTMOS at least `+0.05` over the formal soup;
- WhiSQA at least `+0.05` over the formal soup;
- WER regression no more than `0.25 pp`.

No snapshot is a formal replacement merely because it passes this quality
gate. A passing candidate must also improve the source-to-target W-PRO
diagnostic and then be evaluated on the complete 1,934-sentence official test
set for WER, UTMOS, WhiSQA and W-NT I/L. Only a candidate competitive on those
privacy measures can advance to full LS360 E-VPC S.

## Prepared resources

- Account/mode: `a094f4d10`, HPC/Slurm.
- Partition: `hx1hdnormal`; 1 DCU, 16 CPU / 60 GB; 2 h outer wall.
- Expected/worst training cost: `0.8/2.0` card-hours.
- Fixed-dev selection adds at most `1.5` card-hours.
- Training script:
  `hpc/n019_cross_speaker_ft_d10_hpc.slurm`.
- Selection script:
  `hpc/n019_cross_speaker_select_d10_hpc.slurm`.
- Privacy diagnostic:
  `hpc/n019_cross_speaker_privacy_diag_d10_hpc.slurm`; 1 DCU, 16 CPU /
  60 GB, 1 h, expected/worst `0.2/1.0` card-hours.
- Output:
  `runs/n019_official/vocoder_nt_crossspeaker_ft_20261117`.

The experiment is prepared but must not be duplicated. It can run only after
the currently active residual0.25 E-VPC S job releases the d10 DCU.
