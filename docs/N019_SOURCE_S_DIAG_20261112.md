# N019 source-reconstruction E-VPC S diagnostic

Date: 2026-11-12  
Job: `1101644` (`n019_source_s_diag`, d7 HPC)

## Purpose

This diagnostic asks whether the current Unit HiFi-GAN and HuBERT units can
represent source-speaker identity at all. It is not a paper method and is not
a formal candidate. Every other setting is held to the current DU-pred-nt
pipeline: soup2 checkpoint, predicted duration, full LS360 anonymisation,
official ECAPA scratch S retraining, and the same test protocol.

The only changed input is the vocoder conditioning embedding. Instead of a
random target speaker, each source utterance uses its own source-speaker
W-PRO mean.

## Result

| condition | female EER | male EER | mean EER |
|---|---:|---:|---:|
| source-conditioned, retrained S attack | 0.000% | 0.000% | **0.000%** |
| original enrollment vs source-conditioned trial | 36.902% | 47.437% | 42.1695% |

The S attacker's final validation speaker error rate was `0.128%`; epoch 2
was already `0.451%`.

For comparison:

| random-target condition | E-VPC S |
|---|---:|
| soup2 + shrink0.1 | 29.7425% |
| soup2 + fullmean1160, no shrink | 31.200% |
| paper | 34.8% |

## Interpretation

The unit/vocoder path preserves source identity almost perfectly when the
source embedding is supplied. Therefore the low random-target S result is not
explained by a vocoder that inherently discards speaker identity. The residual
gap is associated with how much stable source identity remains after random
target conditioning and/or with checkpoint-specific behavior.

This result does not justify changing the paper's target-sampling rule. It
also does not support continuing to tune only shrink values or target-pool
completeness.

## Integrity

- test rows: 1,934
- LS360 rows: 104,014
- LS360 WAVs: 104,014
- VPC LS360 rows: 104,014
- all verification checks: passed
- test anon SHA256: `d4cad5ea0253a457fb549f7bfb8a8a180c0147d515104cbf2f2fe05e88322798`
- LS360 anon SHA256: `9f0bbdb314e947a8e50ecf60d05fdd0788033a680124ba74c7d0d09eeaf50bcd`
- S metrics SHA256: `b04a16aae2d178c9b192df677769a72aa7ef92806a6a0bfd048f31c9cd3c5d51`
- walltime: `03:10:28 = 3.1744` card-hours

Output root:

`/public/home/a094f4d7/voice_projects/runs/n019_official/source_reconstruction_diag_20261112`
