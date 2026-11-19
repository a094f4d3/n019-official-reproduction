# N019 Paper Table 1 System Status

Date: 2026-11-19

The paper reports eight `DU-X-Y` combinations. The first token describes
the duration source and the second describes the timbral representation
used by the vocoder:

- `orig`: original utterance duration
- `pred`: predicted duration without a target identity
- `nt`: NT/target-speaker-conditioned duration
- `ecapa`: ECAPA/target-speaker-conditioned duration
- vocoder `nt`: NT-conditioned Unit HiFi-GAN
- vocoder `ecapa`: ECAPA-conditioned vocoder

## Current status

| Paper system | Duration | Vocoder | Current status |
|---|---|---|---|
| DU-pred-nt | pred | nt | Complete nine-metric soft-cap 0.75 candidate in this release |
| DU-nt-nt | nt | nt | Partial only: random-target E-VPC S `30.039%`; a separate utterance-conditioned screen obtained WER/UTMOS/WhiSQA and W-NT I but was quality-rejected and lacks a complete row |
| DU-ecapa-nt | ecapa | nt | Partial only: WER `6.383768%`, UTMOS `3.510845`, WhiSQA `3.489686`, W-NT I `39.095412%`, W-NT L `39.454734%`, E-VPC S `31.1915%`; E-VPC I/L and W-NT S are missing |
| DU-orig-nt | orig | nt | No current corrected-pipeline nine-metric result. An early LS360 anonymisation exists, but it is not a valid replacement for the current paperfix/2x/soft-cap pipeline |
| DU-orig-ecapa | orig | ecapa | Not run under the current corrected pipeline |
| DU-pred-ecapa | pred | ecapa | Not run under the current corrected pipeline |
| DU-ecapa-ecapa | ecapa | ecapa | Not run under the current corrected pipeline |
| DU-nt-ecapa | nt | ecapa | Not run under the current corrected pipeline |

## Interpretation

Only `DU-pred-nt` has a complete same-suffix nine-metric result in this
release. `DU-nt-nt` and `DU-ecapa-nt` have useful partial screens but
cannot be placed in the final Table 1 as complete rows. The remaining
five systems must not be filled with old checkpoint values or metrics
from another suffix.

The paper's ECAPA-vocoder rows require an ECAPA-conditioned vocoder that
is not the same as attaching an ECAPA duration predictor to the NT
vocoder. Therefore `DU-ecapa-nt` partial results do not establish
`DU-*-ecapa` results.
