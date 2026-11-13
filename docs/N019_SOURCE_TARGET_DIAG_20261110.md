# N019 Source-vs-Target Conditioning Diagnostic

Date: 2026-11-10  
Job: `2119924762827333633`  
Checkpoint: d5 step 54000  
SHA256: `732ba853041fa981bca7d7e2693fcab759de862227dde01a869316cd6cc9372e`

## Protocol

- Fixed VPC `libri_dev` selection set: 100 utterances from 40 speakers.
- Source condition: each utterance is synthesized with its own source-speaker
  W-PRO centroid.
- Target condition: the same 100 utterances are synthesized with 96 randomly
  assigned LibriTTS `train-other-500` target-speaker centroids.
- Both variants use the same unit records, vocoder, original durations,
  UTMOS22, WhiSQA, and VPC2024 EncoderASR WER.

## Results

| Condition | UTMOS | WhiSQA | WER |
|---|---:|---:|---:|
| Source speaker | 3.3275684786 | 3.3236708373 | 4.4312471448% |
| Random target speaker | 3.1768457067 | 3.1102414072 | 4.5682960256% |
| Target - source | -0.1507227719 | -0.2134294301 | +0.1370488808 pp |

Paired target-minus-source standard errors:

- UTMOS: `0.0507637393`
- WhiSQA: `0.0472097746`

## Interpretation

The result separates the residual MOS gap into two measurable components:

1. Even source-speaker reconstruction remains below the paper's
   `3.63 / 3.69` by UTMOS `0.3024315214` and WhiSQA `0.3663291627`.
   This is a vocoder/unit/recipe ceiling, not target mapping.
2. Replacing the source embedding with a random target embedding lowers MOS
   further by UTMOS `0.1507227719` and WhiSQA `0.2134294301`.
   Target conditioning therefore explains a smaller but material part of the
   gap.
3. WER changes only `0.137 pp`; the quality loss is primarily perceptual rather
   than intelligibility.

Future work should first improve the vocoder/unit branch (training budget,
layer/k-means alignment, and optimizer recipe) while retaining the corrected
40-speaker validation protocol. Target-embedding changes alone cannot close the
remaining gap.

## Artifacts

Output:

`/public/home/a094f4d7/voice_projects/runs/n019_official/source_target_diag40_retry1_20261110`

- `comparison.json` SHA256:
  `abb94def914b384353754f789575ad639b98ff55d53078bd7561b594a441b2bf`
- `comparison.md` SHA256:
  `c6069cb3581113118a8955e0f7ab0f13540b1b7ff28e1b9adbd4e128f7c6968d`

The platform marked the retry completed. Actual retry wall time was
`45m11s` (`0.753` card-hour). The earlier path-error attempt ran
`1m15s` (`0.021` card-hour), for approximately `0.774` card-hour total.
