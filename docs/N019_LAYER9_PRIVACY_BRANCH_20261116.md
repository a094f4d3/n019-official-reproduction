# N019 layer-9 privacy/MOS branch (2026-11-16)

## Why this branch

The completed target-pool, target-pooling, shrink, checkpoint-soup,
source-reconstruction, and S-attacker controls did not explain the remaining
E-VPC S and W-NT L gaps:

- formal E-VPC S: 29.7425%, paper: 34.8%;
- formal W-NT L: 39.7293478%, paper: 42.3%;
- fullmean1160/no-shrink W-NT L: 40.4301785%;
- source reconstruction, which supplies the source speaker embedding,
  reaches E-VPC S 0.0000%, proving that the unit/vocoder can preserve
  source identity when conditioning contains it.

The paper cites K=200 HuBERT units but does not publish the HuBERT layer.
The existing implementation uses layer 6 because one cited implementation
does so. A fixed-speaker, fixed-utterance, fixed-codebook-size screen was
therefore run for layers 6 and 9.

## Unit speaker-leakage screen

Job `1138511`: 80 speakers, 8 utterances per speaker, 5/3 speaker-disjoint
split, 400 train / 240 test, K=200, logistic regression on normalized unit
histograms.

| representation | speaker accuracy |
|---|---:|
| layer 6 raw mean+std | 77.92% |
| layer 6 unit histogram | 28.75% |
| layer 9 raw mean+std | 65.42% |
| layer 9 unit histogram | 17.08% |

Job `1138575` adds order-sensitive 1–3-gram TF-IDF classifiers:

| representation | 1–3-gram speaker accuracy |
|---|---:|
| layer 6 units | 28.33% |
| layer 9 units | 20.83% |

Layer 9 still retains less speaker identity after accounting for short
sequence statistics. This is a controlled screen, not an EER result.

## Layer-9 materials

Job `1138621` fitted K=200 on HuBERT layer 9 over 33,236 clean-100
utterances, then extracted units. The platform status was failed only because
the post-check expected a nonexistent `kmeans_fit.json`; the output itself was
complete and validated:

- records: 33,236;
- codebook: 200 x 768;
- `unit_records.jsonl` SHA256:
  `b334b9cd8a235c11ee716f5d6fba1956c4e3a47271d03f63de3eed084bb08e46`;
- codebook SHA256:
  `4ea8a5878de4d1431c98ba641cfa2b048443d4f8d5595af4c5066ad0e72b3f08`.

Job `1138800` aligned the layer-9 cluster labels to layer-6 labels by
Hungarian maximum frame co-occurrence. Cluster labels are arbitrary, so this
permutation is lossless for the layer-9 codebook and makes pretrained
conditioning reusable for the controlled adaptation branch:

- aligned records SHA256:
  `858a239f20262f799af88947e4b84ef6874e71aebe1c8c57e30b8efbe237a9ea`;
- aligned codebook SHA256:
  `a0159483843f952e5ac9ac88cb410ca517d7d437c4ddcaf49535ef4be0284c2b`;
- exact frame-token agreement on 2,000 utterances: 45.11%;
- deduplication-boundary agreement: 64.05%.

The agreement is far above a random 200-way permutation, but it confirms that
the adaptation must be measured rather than assumed.

## Evaluation units and training branch

Jobs `1138891`, `1139018`, and `1139051` exposed d7/d6 read-permission and
empty-partial-file issues. They are launch failures, not model failures.
Job `1139076` completed both evaluation unit sets:

- test: 1,934 records, SHA256
  `25df31e21b12971b951ea41f127ebc4c431d2f8ac34926a21023f6555fa76383`;
- speaker-disjoint 40-speaker dev: 100 records, SHA256
  `b267f825eb963c7392e4ea250b2712bd0126181de0726a8c1b167dbb479f952d`.

Job `1139262` (retry of `1139078`) is the layer-9 Unit HiFi-GAN
adaptation pilot:

- account/mode: `a094f4d10`, HPC/Slurm;
- partition: `hx1hdnormal`;
- resources: 1 DCU, 16 CPU / 60 GB;
- wall clock: 8 h; expected 4 h, worst 8 h;
- initialization: formal soup generator,
  SHA256 `ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6`;
- output:
  `/public/home/a094f4d10/voice_projects/runs/n019_official/vocoder_nt_layer9_aligned_pilot_20261116`;
- stop conditions: watchdog failure, non-finite loss, no log progress,
  missing aligned records, or wall-clock expiry.

The pilot snapshots every 2,000 steps. No snapshot is a formal replacement.
The next gate is the fixed 40-speaker dev comparison against the initialized
layer-6 model under the same layer-9 units, target map, target embeddings,
duration mode, and UTMOS/WhiSQA/WER evaluators. E-VPC S is not inferred from
test-only W-NT values; a candidate that passes the dev gate must still run
full LS360 anonymisation and official ECAPA S retraining.

Queued follow-ups:

- `1139289`: fixed 40-speaker dev-100 comparison of the formal soup baseline
  and all pilot snapshots, `afterany:1139262`; 1 DCU, 16 CPU / 60 GB, 2 h;
  UTMOS/WhiSQA `+0.05` and WER regression `<=0.25 pp`.
- `1139307`: unconditional duration predictor training on aligned layer-9
  units, `afterok:1139289`; 1 DCU, 16 CPU / 60 GB, 4 h. This is support for
  the candidate branch, not a second concurrent vocoder branch.

At step 4,000 the pilot's validation mel-L1 improved from `0.8198839` to
`0.7569795`; losses remained finite. This only establishes optimization
health, not perceptual quality.

## 8k full-test and E-VPC S screen

The 8k snapshot was evaluated on the complete official test set in Job
`1140835`:

| Metric | Layer-9 8k | Formal layer-6 soup | Paper |
|---|---:|---:|---:|
| W-NT L | **42.341645%** | 39.729348% | 42.3% |
| WER | 7.334056% | 6.223960% | 7.41% |
| UTMOS | 3.108420 | 3.525367 | 3.63 |
| WhiSQA | 2.907583 | 3.495759 | 3.69 |

The non-timbral privacy hypothesis is strongly supported: layer 9 closes the
W-NT L gap at only 8k adaptation steps. The checkpoint is still not a formal
candidate because both perceptual metrics are well below the formal model.

To test whether the same representation also closes the timbral S gap, Jobs
`1140990`, `1141771`, `1141872` and `1141930` now:

1. extract layer-9 units for all 104,014 LS360 utterances with the validated
   clean-100 layer-9 codebook;
2. anonymise the full LS360 set with the same 8k vocoder and matched layer-9
   duration predictor;
3. export the official VPC view and retrain ECAPA-TDNN with the official
   10-epoch S protocol.

This is a diagnostic. A high S EER cannot justify replacing the formal model
until a longer layer-9 vocoder recovers UTMOS/WhiSQA and all nine metrics are
rechecked.

The first 6-hour continuation attempt (`1141349`) was cancelled after 1m49s
while the export-only S retry was being prepared; it had not reached a new
training step. The continuation was resubmitted after `1141930` as `1142379`, resuming
the existing step-10,120 optimizer/discriminator state without changing the
recipe. The next gate compares its 10k–40k snapshots against the 8k snapshot
on the fixed speaker-disjoint dev set. No second training branch is authorized.

The completed 8k E-VPC S screen is 26.9275% (female 28.466%, male 25.389%),
below the formal layer-6 29.7425%. Layer 9 therefore addresses W-NT L but does
not by itself close the timbral S gap. The 6-hour continuation is still needed
to distinguish representation behavior from under-trained vocoder quality.

## E-VPC S decision logic after the layer-9 screen

The two privacy axes are now decoupled:

| Experiment | W-NT L | E-VPC S |
|---|---:|---:|
| formal layer-6 soup | 39.7293 | 29.7425 |
| layer-9 8k | **42.3416** | 26.9275 |
| paper DU-pred-nt | 42.3 | **34.8** |

This rules out the assumption that a single unit-layer change automatically
solves both attacks. The next evidence must come from the quality-restored
layer-9 checkpoint:

1. If UTMOS/WhiSQA recover and E-VPC S rises materially above 29.7, the 8k S
   result was dominated by under-training/artifacts.
2. If quality recovers but E-VPC S remains near 27, layer 9 improves
   non-timbral privacy while leaving source timbre accessible; the next
   experiment must target timbral conditioning rather than repeat target-map,
   shrink, pooling or checkpoint-soup searches.
3. If quality does not recover, layer 9 remains a diagnostic branch and the
   formal result stays unchanged.

No new S run should be submitted until the fixed-dev gate selects a
quality-competitive snapshot.

## W-PRO target-shift diagnostic (2026-11-17)

The fixed 40-speaker dev-100 target-shift diagnostic measured cosine similarity
between the anonymised W-PRO embedding and both the source-speaker centroid and
the assigned target-speaker centroid.

| condition | anon-source | anon-target | margin | closer to target |
|---|---:|---:|---:|---:|
| layer-9 units, matched duration, formal layer-6 vocoder | 0.428301 | 0.532548 | +0.104246 | 71% |
| layer-9 8k adapted vocoder | 0.559366 | 0.610671 | +0.051305 | 61% |

The 8k layer-9 model raises similarity to both centroids, but the
source-to-target margin falls by `0.052941` and the fraction closer to target
drops 10 percentage points. This is consistent with the full LS360 result:
layer 9 reduces the non-timbral cues exploited by W-NT, but the undertrained
vocoder output remains (or becomes) more similar to the source timbre used by
E-VPC. The result is diagnostic only, because the checkpoint is still
quality-rejected.

SHA256:

- baseline diagnostic: `1ac8bf17d820c40ca60d37ba90457df897841b0de284f0774f26ae48e7125341`
- layer-9 8k diagnostic: `640ba13fce8fff14ec88f8c05f213442d343c69f55d0565b022c79eb6f5c5c9a`

