# N019 Metric Comparison

论文 Table 1 的机器可读副本固定在 `configs/paper_table1.json`，不得在
代码里另抄一份或临时修正 B4、`DU-pred-nt` W-NT L 等公开不一致。

每次完成一个系统后，写一个只含实测值的 JSON：

```json
{
  "system": "DU-pred-nt",
  "values": {
    "E-VPC I": 47.2,
    "E-VPC L": 47.9,
    "E-VPC S": 34.8,
    "W-NT I": 39.9,
    "W-NT L": 42.3,
    "W-NT S": 24.6,
    "WER": 7.41,
    "UTMOS": 3.63,
    "WhiSQA": 3.69
  }
}
```

也可以直接从各原始结果组装，缺项会写入 `missing`，不会补值：

```bash
python -m n019.assemble_paper_metrics \
  --system DU-pred-nt \
  --evpc runs/.../evpc_metrics.json \
  --s-eval runs/.../s_metrics.json \
  --wnt-summary runs/.../wnt/summary.json \
  --wer-json runs/.../evpc_metrics.json \
  --wer-condition anon \
  --utmos runs/.../mos/UTMOS.json \
  --whisqa runs/.../mos/WhiSQA.json \
  --out runs/.../paper_metrics.json
```

运行：

```bash
python -m n019.compare_paper \
  --paper-table configs/paper_table1.json \
  --system DU-pred-nt \
  --metrics runs/.../paper_metrics.json \
  --out-json runs/.../paper_comparison.json \
  --out-md runs/.../paper_comparison.md
```

输出保留未舍入复现值、论文值、绝对差、相对差、容差和状态。缺少的指标
标成 `pending`，论文本来没有报告的格子标成
`not_reported_by_paper`；两者都不能填猜测值。

当前容差是为复现讨论设定的报告阈值，论文没有定义：EER/WER 为 0.5 个
百分点，MOS 为 0.05。最终是否算“基本一致”要同时看多个指标的差值、
官方 baseline 和实现假设，不能只凭单个格子过阈值。

机器可读论文表是 `configs/paper_table1.json`。改表必须给出论文页码或
勘误证据，不能为了让复现值通过而修改论文值。

## 当前正式结果（2026-11-10 21:35）

`DU-pred-nt`、84k/88k/92k/96k 四点 effective-weight-norm soup
（权重 40:30:20:10）、shrink-0.1 target embedding，完整 official
`libri_test`：

| Metric | Paper | Reproduced | Abs. diff | Rel. diff |
|---|---:|---:|---:|---:|
| WER | 7.41% | **6.2239598196%** | -1.1860401804 pp | -16.01% |
| UTMOS | 3.63 | **3.5253666541** | -0.1046333459 | -2.88% |
| WhiSQA | 3.69 | **3.4957589100** | -0.1942410900 | -5.26% |

WER 计数为 1,496，UTMOS/WhiSQA 各 1,934。checkpoint SHA256
`ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6`。
`quality_metrics.json` SHA256
`542cd9fc44e1c03237150078cb67ddb4e7edfe41775f53c77acb7896040d9f5a`。
结果目录
`runs/n019_official/eval_user/du_pred_nt_soup2_w40_shrink01_20261110`。

相对上一版 `avg88_92 + mean32`：UTMOS `+0.1255740367`、
WhiSQA `+0.0972059087`、WER `+0.0028537184 pp`，即 MOS
明显提升而 WER 基本不变。

同一套 soup+shrink WAV 的九项正式结果：

| Metric | Paper | Reproduced | Abs. diff |
|---|---:|---:|---:|
| E-VPC I | 47.2% | **48.0285%** | +0.8285 pp |
| E-VPC L | 47.9% | **47.7540%** | -0.1460 pp |
| E-VPC S | 34.8% | **29.7425%** | -5.0575 pp |
| W-NT I | 39.9% | **39.1678579%** | -0.7321421 pp |
| W-NT L | 42.3% | **39.7293478%** | -2.5706522 pp |
| W-NT S | 24.6% | **24.523857%** | -0.076143 pp |
| WER | 7.41% | **6.2239598%** | -1.1860402 pp |
| UTMOS | 3.63 | **3.5253667** | -0.1046333 |
| WhiSQA | 3.69 | **3.4957589** | -0.1942411 |

## Privacy-enhanced opposite-gender target variant (2026-11-12)

This variant keeps the same `DU-nt-nt` model, original LibriTTS
other-500 target pool, speaker-mean/shrink embeddings and official VPC
evaluation, but constrains target sampling to the opposite gender. It
is not the paper's unspecified random-target policy and must be
reported separately.

| Metric | Paper | Formal DU-pred-nt | Opposite-gender DU-nt-nt |
|---|---:|---:|---:|
| E-VPC I | 47.2% | 48.0285% | 47.1920% |
| E-VPC L | 47.9% | 47.7540% | 49.0715% |
| E-VPC S | 34.8% | 29.7425% | **42.0405%** |
| W-NT I | 39.9% | 39.1679% | 39.3920% |
| W-NT L | 42.3% | 39.7293% | **41.1030%** |
| WER | 7.41% | 6.2240% | **6.2924%** |
| UTMOS | 3.63 | 3.5254 | 3.4589 |
| WhiSQA | 3.69 | 3.4958 | 3.4915 |

The complete random-target `DU-nt-nt` control is E-VPC S
`30.039%`, showing that target-conditioned duration alone does not
explain the S gap.

## 修正版口径

2026-11-04 的 duration loss 和 feature-matching 修正会改变训练目标。
修正前已生成的 LS360 输出只能作为工程 v1；短期正式结果只接受
`DU-pred-nt-paperfix` 及其重新生成的 libri_test 分数。其他 7 个 DU
系统在单体闭环通过前统一标为 `pending`，不得用旧 checkpoint 补表。

UTMOS22 和 WhiSQA 必须对完整 1,934 句 `libri_test` 最终音频评分；
`libri_test_trials_f/m` 去重后的 1,496 句不是完整 test set，不能代替
Table 1 的 MOS 样本。

## DU-pred-nt-paperfix 当前结果

| Metric | Paper | Reproduced | Abs. diff | Rel. diff |
|---|---:|---:|---:|---:|
| E-VPC I | 47.20% | 47.4730% | +0.2730 | +0.58% |
| E-VPC L | 47.90% | 45.8775% | -2.0225 | -4.22% |
| W-NT I | 39.90% | 41.1284% | +1.2284 | +3.08% |
| W-NT L | 42.30% | 42.8748% | +0.5748 | +1.36% |
| WER | 7.41% | 10.3330% | +2.9230 | +39.45% |
| UTMOS | 3.63 | 1.2620579278580035 | -2.3679421 | -65.23% |
| WhiSQA | 3.69 | 1.847028814125209 | -1.8429712 | -49.95% |

E-VPC S 和 W-NT S 仍为 `pending`，需要完整匿名 LS360 训练。
WhiSQA 完整 1,934 句结果由 d7 Job `2118528804410613762`
于 2026-11-06 10:21:54 完成。

## ext102000 当前部分结果（2026-11-07）

ext102k 的 WER、UTMOS、WhiSQA 已经从同一套 1,934 句匿名 WAV
重新评测；E-VPC I/L 和 W-NT I/L 尚未在这套 ext102k WAV 上重算，
仍不能把下表与旧 step4k 的 E-VPC/W-NT 拼成一个完整系统表。

| Metric | Paper | ext102k reproduced | Abs. diff | Rel. diff |
|---|---:|---:|---:|---:|
| WER | 7.41% | 6.7547514411% | -0.6552485589 | -8.84% |
| UTMOS | 3.63 | 2.6142479994 | -1.0157520006 | -27.98% |
| WhiSQA | 3.69 | 2.7501946269 | -0.9398053731 | -25.47% |

WER 已优于论文；UTMOS 和 WhiSQA 仍明显偏低。GPU 与 CPU 的
WhiSQA 全量结果只差 `2.769e-6`，说明剩余差距来自音频/模型质量，
不是 DCU 或数值实现。

**重要代码事实：**d7 原训练代码的 `feature_matching_loss` 仍为
1x；step 4k、76k、102k 都是在缺少 2x 的训练目标下得到的。
本地修正版（`return loss * 2`）已同步 d7，但这意味着需要新训练，
不能用现有 checkpoint 评价 2x 配方。

## 差距归因（2026-11-06）

当前全量结果来自 `vocoder_nt_paperfix/best.pt` step `4,000`，
`run_meta.json` 已记录 `vocoder_version=4000`。同一批 25 句上：

| Checkpoint / condition | UTMOS | WhiSQA |
|---|---:|---:|
| paperfix step 4k, predicted duration | 1.248995 | 1.848322 |
| paperfix step 33,999, predicted duration | 2.237067 | 2.419048 |
| main step 76k, predicted duration | 2.544487 | 2.643822 |
| ext step 102k, predicted duration | 2.469762 | 2.703620 |
| main step 76k, original duration | 2.496909 | 2.665299 |
| main step 76k, seen-train reconstruction | 2.704474 | 2.589972 |

- 正式全量 `UTMOS 1.262 / WhiSQA 1.847` 与 step 4k 的 25 句诊断
  几乎一致，说明首要已知问题是 checkpoint 选得过早，不是打分器或
  指标协议失效。
- 把预测时长换成原时长，两个 MOS 指标基本不变，说明时长预测不是
  主要 MOS 来源。
- 即使对已见训练语音做 source-speaker 重建，main step 76k 仍只有
  `2.704 / 2.590`，因此残差主要是 vocoder 本身的训练/重建质量。
- 代码审计发现 `feature_matching_loss` 漏掉了引用实现的总 `2x`
  系数；这会把 GAN 的 feature-matching 约束削弱一半。该问题已修正，
  但必须重新训练才能评价。
- 现有 `best.pt` 由 64 条训练记录上的 log-mel L1 选出并早停；
  论文没有公开该选模协议，引用实现默认训练到 400,000 steps。
  延长到 102k 的 UTMOS 反而略低于 76k，说明“单纯加步数”不是充分修复。

102k 与 76k 在相同 25 句上的配对差为 UTMOS
`-0.074724`（`t=-0.895`）和 WhiSQA `+0.059798`（`t=+0.914`），
均在一倍标准误附近，不能判定谁更好。两者可视为基本打平，而 102k
相对当前正式 step 4k 明显更好。因此 102k 应作为完整 I/WER/MOS
复评候选，而不是被排除；只有 25 句时不能直接替换正式全量表。

因此当前优先级不是改评测指标，而是：

1. 用修正后的 feature-matching `2x` 损失重新训练 NT Unit HiFi-GAN；
2. 取消 4k/76k 这种与 MOS 弱相关的过早选模，保存并盲测多个 checkpoint；
3. 新 checkpoint 通过同批 25 句门槛后，再重跑完整 1,934 句
   E-VPC/WER/UTMOS/WhiSQA。
