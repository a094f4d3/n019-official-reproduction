# N019 当前算法策略、正式结果与复现进度

更新日期：2026-11-12 CST  
论文：*Joint Timbral and Non-Timbral Speaker Anonymisation*  
DOI：`10.21437/Odyssey.2026-16`

## 1. 当前正式结果

当前最好且已完成完整 1,934 句 official `libri_test` 质量评测的系统是
`DU-pred-nt`：

| 指标 | 当前复现 | 论文 | 差值 | 计数 |
|---|---:|---:|---:|---:|
| WER | **6.2239598196%** | 7.41% | **-1.1860401804 pp** | 1,496 |
| UTMOS | **3.5253666541** | 3.63 | `-0.1046333459` | 1,934 |
| WhiSQA | **3.4957589100** | 3.69 | `-0.1942410900` | 1,934 |

相对上一版 `avg88_92 + mean32`：

- WER `+0.0028537184 pp`
- UTMOS `+0.1255740367`
- WhiSQA `+0.0972059087`

即 WER 基本不变，UTMOS 和 WhiSQA 同时明显提升。

产物：

- checkpoint SHA256：
  `ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6`
- `quality_metrics.json` SHA256：
  `542cd9fc44e1c03237150078cb67ddb4e7edfe41775f53c77acb7896040d9f5a`
- 结果目录：
  `/public/home/a094f4d7/voice_projects/runs/n019_official/eval_user/du_pred_nt_soup2_w40_shrink01_20261110`
- anon 目录：
  `/public/home/a094f4d7/voice_projects/runs/n019_official/anonymised/libri_test/DU-pred-nt-soup2_w40_shrink01_20261110`
- VPC suffix：
  `_n019_soup2_w40_shrink01_20261110`

关键实现文件：

| 文件 | SHA256 |
|---|---|
| `scripts/run_full_eval_param_ai.sh` | `0dad9fda571a4da2dacb1cbbb74af48db93a25d2270c8ce73f2b292bf62624ff` |
| `scripts/anonymize_libri_test_paperfix_remote.sh` | `e3951e1f0b033fac247c9d3723a80dccb335be081ae078f02d9213963355ab7b` |
| `scripts/build_n019_model_soups_round2_20261110.sh` | `4c1f2d62ac90d0ae854f3f303c09fb3bb5fb39356faf1170073d9c9cca289aa2` |
| `configs/paper_algorithm_v1.json` | `11f30c6ecde713ab030c7429526f4c70d22b74f4ce188ba26225ec922417b541` |

## 2. 当前算法策略

### 2.1 数据和单元

- Unit HiFi-GAN 训练集：原始 LibriTTS `train-clean-100`，不是 LibriTTS-R。
- Duration predictor 训练集：LibriSpeech `train-clean-100`。
- Target speaker 池：原始 LibriTTS `train-other-500`。
- HuBERT：`facebook/hubert-base-ls960`，采用第 6 Transformer 层。
- Unit codebook：200 clusters，在 LibriSpeech clean-100 上拟合。
- 连续重复 unit 合并，保留 run length 作为 duration target。

### 2.2 Duration predictor

- DISSC `LenPredictor` 结构：unit embedding 32 维，7 层 128 通道卷积。
- Point loss：MSE。
- Window loss：四个相邻 unit 的总时长 MSE。
- 推理时使用 predicted duration，不使用原音频时长。

### 2.3 NT Unit HiFi-GAN

- 输入为逐帧拼接的 `[unit embedding, 250-D NT speaker embedding]`。
- 训练修正已启用 2x feature-matching。
- 当前模型属于 speaker-conditioned Unit HiFi-GAN，不是简单的 mel vocoder。
- 正式 checkpoint 不是单个 step，而是以下四点
  effective-weight-norm soup：

| step | 权重 |
|---:|---:|
| 84k | 40% |
| 88k | 30% |
| 92k | 20% |
| 96k | 10% |

训练配方：

- AdamW，初始 LR `2e-4`
- batch 16
- BF16
- `ExponentialLR(gamma=0.999)`，每个 epoch 更新一次
- 当前长训 step 数远高于 92k，但日志 LR 仍约 `1.85e-4`，
  后期退火非常弱

### 2.4 Target embedding

- 基于 843 个 target speakers 的 mean32 speaker embedding。
- 当前正式候选从 `mean32` 再向全部 target speakers 的全局均值混合
  10%：

```text
e_final = L2Norm(0.9 * e_target_speaker + 0.1 * e_global_speaker_mean)
```

- 这是 target regularization，不是向源说话人 embedding 收缩，
  因此没有直接引入 source speaker conditioning。
- `shrink0.1` 仍不是论文公开细节，正式论文表收口前必须补 EER，
  确认隐私代价可接受。

### 2.5 正式评测

- 数据集：VPC2024 `libri_test`。
- WER：官方 VPC SpeechBrain EncoderASR 路径，1,496 句。
- UTMOS：UTMOS22，完整 1,934 句。
- WhiSQA：WhiSQA single-head，完整 1,934 句。
- 原始语音校准：UTMOS `4.1006982828`、WhiSQA `4.0597021709`，
  与论文 Original `4.11 / 4.08` 接近，说明评测器链路基本正确。

## 3. 结果演进

| 版本 | WER | UTMOS | WhiSQA | 状态 |
|---|---:|---:|---:|---|
| 论文 | 7.41% | 3.63 | 3.69 | 目标 |
| paperfix step4k | 10.333% | 1.2621 | 1.8470 | 早期失败基线 |
| ext102k | 6.7548% | 2.6142 | 2.7502 | 已被淘汰 |
| d5 54k + mean32 | 6.1983% | 3.2001 | 3.1962 | 历史正式 |
| d5 88k + mean32 | 6.3752% | 3.2954 | 3.3431 | 历史正式 |
| 88k/92k 平均 + mean32 | 6.2211% | 3.3998 | 3.3986 | 历史正式 |
| 84/88/92/96 soup + shrink0.1 | **6.2240%** | **3.5254** | **3.4958** | 当前正式 |

关键结论：

- WER 已稳定优于论文约 1 个百分点以上。
- UTMOS 已从落后 `-1.016` 缩小到 `-0.105`。
- WhiSQA 已从落后 `-0.940` 缩小到 `-0.194`。
- 剩余质量差距已经从“系统不可用”缩小到单指标约 1/10 到 1/5 MOS。

## 4. 已验证的优化经验

### 4.1 Checkpoint averaging 有效

88k 和 92k 单独模型都低于两者平均；四点 soup 又进一步提高了双 MOS。
这说明 checkpoint 在同一个 good basin 内存在明显随机游走。

### 4.2 后段 LR 退火偏弱

相邻 2k-step checkpoint：

- 相对权重位移约 `4.5%`
- 连续位移余弦约 `-0.056` 到 `-0.014`

接近正交、略负，符合围绕好区域震荡而不是稳定收敛。

### 4.3 Generator-only 短退火不是有效替代

从 92k generator、LR `5e-5` 训练 2,000 step：

- 500 step：UTMOS `2.9721`
- 1,000 step：UTMOS `3.0097`
- 1,500 step：UTMOS `3.0386`
- 2,000 step：UTMOS `3.1209`

原因是 discriminator 和 optimizer 重新初始化，产生较大 GAN transient。
该实验不能单独否定 LR 假设，但说明做“真实短退火”必须恢复完整训练状态，
不能只恢复 generator。

## 5. 与论文方法的差异

已对齐：

- 原始 LibriTTS clean-100 / other-500 数据口径
- HuBERT + k-means、K=200、连续 unit 合并
- duration point/window loss
- unit 与 speaker embedding 逐帧拼接
- NT 250-D conditioning
- Unit HiFi-GAN 路线
- VPC2024 official `libri_test`
- UTMOS、WhiSQA、WER evaluator

仍是复现选择或未公开项：

- checkpoint soup 不是论文明确描述的方法
- `shrink0.1` target embedding 不是论文公开设置
- target embedding pooling 规则论文未说明
- LR、batch、generator width、训练步数等论文未完整说明
- HuBERT 层号与 k-means 细节由引用论文和公开代码推断
- 当前硬件为 DCU/DTK，非作者 RTX 4090

因此当前结果是“论文结构 + 官方数据/评测 + 受控质量优化”的复现版本，
不能写成作者代码逐位一致。

## 6. 总体复现进度

| 模块 | 状态 | 说明 |
|---|---|---|
| 官方数据口径 | 完成 | 原始 LibriTTS，不是 LibriTTS-R |
| HuBERT/K-means units | 完成 | 33,236 clean-100 records |
| Duration predictor | 完成 | 正式 best.pt 已用于推理 |
| NT Unit HiFi-GAN | 完成 | 2x feature-matching 配方 |
| `DU-pred-nt` WER | 完成 | 1,496 句 |
| `DU-pred-nt` UTMOS | 完成 | 1,934 句 |
| `DU-pred-nt` WhiSQA | 完成 | 1,934 句 |
| `DU-pred-nt` E-VPC I/L | **pending** | 当前新 WAV 尚未评 |
| `DU-pred-nt` W-NT I/L | **pending** | 当前新 WAV 尚未评 |
| I/L/S 完整隐私闭环 | 未完成 | S 还需完整 LS360 匿名化和 ASV 重训 |
| 其他 7 个 DU 系统 | 未闭环 | 仅链路和部分旧探索 |
| B4/B5/kNN-VC 基线 | 未完整复现 | 不能复制第三方论文数字冒充本复现 |
| 完整论文 Table 1 | 未完成 | 当前只闭环单个系统的 3 个质量指标 |

更准确的总体判断：

- **核心 DU-pred-nt 质量与可懂度闭环：基本完成。**
- **DU-pred-nt 隐私闭环：未完成。**
- **完整 Table 1：仍处于早期到中期阶段。**

## 7. 下一步优先级

1. 在当前 `soup + shrink0.1` 的同一批 1,934 WAV 上重跑
   E-VPC I/L 和 W-NT I/L。
2. 若隐私退化明显，测试 `shrink0.05`、`shrink0.075` 与纯 soup，
   找质量/隐私 Pareto 点。
3. 若 EER 可接受，完成 `DU-pred-nt` 的 I/L 行。
4. S 条件需要完整 LS360 匿名化、ECAPA 重训和 S EER，不能复用旧结果。
5. 再扩展其他 DU conditioning 组合；B4/B5/kNN 如需入表应独立复现。

## 8. 当前运行状态

- d6 HPC 长训 `1076707` 已按用户要求于 2026-11-10 21:52:12
  停止，状态 `CANCELLED+`；实际墙钟 `15h31m12s`。
- 停机时日志最后 step `164,280`，持久 `last.pt` 为 step
  `164,000`，SHA256
  `e7a6ef1003dfc0caebe0f356b751340c93588e1d53867f068ca5f44feb911bb0`。
- 停机后在当前正式 `soup+shrink0.1` 推理条件下测试了 d6
  160k/162k/164k。baseline dev UTMOS 为 `3.5127723885`，
  候选分别为 `3.2387674308 / 3.3362299037 / 3.2473053122`；
  全部早拒绝。d6 最后训练效果未超过正式结果。
- d6 92k 后单 checkpoint 均未超过正式基线，不能自动替换当前结果。
- d5、d7 旧 FP32 分支均未保留为训练主线。
- 当前尚未批准或启动新的长训练；质量优化优先走已有 checkpoint soup
  和小规模受控验证。

## 9. 2026-11-10 23:06 I/L 新结果与 S 进度

当前正式模型不变：`84/88/92/96k soup w40:30:20:10 + shrink0.1`。
在完全相同的 1,934 句匿名 WAV/VPC 上补跑得到：

| 指标 | 实测 | 论文 | 绝对差 |
|---|---:|---:|---:|
| E-VPC I | 48.0285 | 47.2 | +0.8285 |
| E-VPC L | 47.7540 | 47.9 | -0.1460 |
| W-NT I | 39.1678579152 | 39.9 | -0.7321420848 |
| W-NT L | 39.7293478251 | 42.3 | -2.5706521749 |

解释：

- E-VPC L 已在 0.5 个百分点报告容差内；I 比论文高 0.8285，
  即当前系统对 E-VPC 的隐私更强。
- W-NT I/L 均低于论文，其中 L 低 2.57 个绝对点。W-NT 仍是当前
  隐私端最明显的残余差距。
- 这批 I/L 使用与正式质量结果相同的 checkpoint、target map、
  `shrink0.1` embedding 和 VPC 后缀，不是旧 checkpoint 拼接。

S 输入的零卡时准备已完成：

- 补齐全部 1,158 个 target speakers 的 32-sample mean embedding，
  并重新施加与正式测试完全相同的 0.1 centroid shrink。
- LS360 分成 4 个时长均衡 shard，每片约 25.9k–26.1k 句。
- 8 句 1-DCU smoke 已通过；按 smoke 吞吐，单片预计约 5.2 h。
- 第一片 d6 HPC `1086660` 已运行。后续必须串行完成其余三片，
  合并为 104,014 句并核验后才能进入 E-VPC S / W-NT S 重训。

## 10. 2026-11-11 d6 最后 checkpoint 三项复核

d6 长训 Job `1076707` 已停止，最后日志 step `164,280`，稳定
`last.pt` 为 step `164,000`。对 160k/162k/164k 中 UTMOS 最高的
162k 补齐 100 句 dev 三项指标：

| checkpoint | UTMOS | WhiSQA | WER % |
|---|---:|---:|---:|
| 当前 soup2 baseline | **3.512772** | **3.431399** | **6.121517** |
| d6 step 162k | 3.336230 | 3.323067 | 6.486980 |
| d6 step 164k | 3.247305 | 3.318912 | 6.669712 |
| 162k delta | -0.176542 | -0.108332 | +0.365464 pp |
| 164k delta | -0.265467 | -0.112487 | +0.548196 pp |

结论：d6 分支在最后 160k–164k 区间没有追平当前 soup2；延长训练和
单 checkpoint 替换均无收益。后续质量提升应继续围绕已有 soup、
target shrink 和经过 dev gate 的小规模受控实验，不恢复 d6 长训。

复核 Job 为 d7 AI `2120196966200995842`，1 DCU、15 CPU / 59 GB，
实际墙钟 `13m30s = 0.225` 卡时。结果目录：

`/public/home/a094f4d7/voice_projects/runs/n019_official/vocoder_selection_d6_final_160_164_20261110`

05:38–05:40 又用 d7 HPC `1088937` 在已有 164k WAV 上补测
WhiSQA/WER；1 DCU、16 CPU / 60 GB、墙钟 1m40s ≈ 0.028 卡时，
没有重训练或重新渲染。164k 仍全面差于 baseline，说明不能靠
恢复 d6 长训或选择最后 snapshot 提升质量。

## 11. 2026-11-11 E-VPC S 完成

d6 HPC `1087347` 已完成 104,014 句匿名 LS360 上的官方 post
ECAPA 重训与 S 条件评测：

| 指标 | 实测 | 论文 | 绝对差 |
|---|---:|---:|---:|
| E-VPC S female | 30.114% | - | - |
| E-VPC S male | 29.371% | - | - |
| E-VPC S mean | **29.7425%** | 34.8% | -5.0575 pp |

当前 E-VPC S 隐私弱于论文。W-NT S 训练 Job `1087348` 已于
`02:12:12` 启动，评测 Job `1087349` 通过 `afterok` 等待。
I/L/S 九项指标汇总工具已就绪，待 W-NT S 完成后一次组装。

## 12. W-NT S 塌缩排查与新 recipe

原 W-NT S 全 WavLM fine-tune 在 epoch 1 和 step 19k 的训练
accuracy 都为 `0.0`。固定 8 句诊断显示，保存模型的 W-PRO
embedding 两两余弦最大接近 1，预测塌缩到少数类别，因此主动取消
原训练 `1087348` 及其评测 `1087349`，保留产物作为失败追溯。

新 recipe 冻结 315M WavLM trunk，只训练 1.18M top-layer 参数
和 AAM head，batch 16、lr/head-lr `1e-3`。smoke `1088364`
完成 6,500 steps，loss 降至 `12.5623`、accuracy 非零，且
embedding 余弦 min/mean/max 为
`-0.50246 / 0.13306 / 0.44311`，没有塌缩。

正式训练 Job 为 `1088443`，评测 Job为 `1088444`；预计完整
20 epochs 约 3.6 卡时。

r1 `1088443` 在 `f11r1n20` 启动后 1m29s 发生 `SIGSEGV`，尚未
产生训练 step，属于节点级异常。已排除该节点并提交 r2：

- 训练 Job：`1088459`，节点 `f11r2n02`
- 评测 Job：`1088460`，`afterok:1088459`
- 配置：1 DCU、16 CPU / 60 GB、batch 16、lr/head-lr `1e-3`
- 04:04 已运行到 step `4,480`，loss `12.7996`，无新异常

r2 的学习信号持续增强：epoch 1 loss/accuracy 为
`12.5623 / 0.0001731`，epoch 2 为
`11.3665 / 0.0004038`；epoch 3 step `19,060` 已达到
loss `10.6833`、accuracy `0.0005776`。当前速度约
`0.19 h/epoch`，20 epochs 预计可在 4.5 小时内部上限内完成。

最终 W-NT S 源目录为
`privacy/wnt_s_soup2_w40_shrink01_freeze_r2`，不使用 r1。

## 13. 2026-11-11 07:01 W-NT S 稳定重训与九项闭环

原 r2 分支的 AAM `margin=0.2, scale=30` 虽然持续降低 loss，但
epoch 7 发生非有限 loss；用 epoch06 直接评估得到 W-NT S
`42.9055%`，说明攻击模型未正常收敛，不能作为最终结果。

改用更稳定的 AAM 配置：`margin=0.05`、`scale=10`、WavLM 冻结，
top-layer/head lr `1e-4/1e-3`、batch 16。d6 HPC Job `1089071`
完成 4 epochs / 26,000 steps，epoch 4 loss/accuracy 为
`5.4820056 / 0.0655096`；输出为
`privacy/wnt_s_stable_smoke_20261111`。首个 Job `1089060` 在
`f11r1n05` SIGSEGV，排除该节点和 `f11r1n20` 后重跑成功。

W-NT S 评估 Job `1089232` 完成：

| gender | EER % |
|---|---:|
| female | 23.880922 |
| male | 25.166792 |
| mean | **24.523857** |

论文 W-NT S 为 `24.6%`，绝对差 `-0.076143`，已进入报告容差。

完整 `DU-pred-nt` 最终汇总目录：

`/public/home/a094f4d6/voice_projects/runs/n019_official/privacy/du_pred_nt_soup2_w40_shrink01_final_r2_20261111`

| Metric | Reproduced | Paper |
|---|---:|---:|
| E-VPC I | 48.0285 | 47.2 |
| E-VPC L | 47.7540 | 47.9 |
| E-VPC S | 29.7425 | 34.8 |
| W-NT I | 39.1679 | 39.9 |
| W-NT L | 39.7293 | 42.3 |
| W-NT S | 24.5239 | 24.6 |
| WER % | 6.2240 | 7.41 |
| UTMOS | 3.5254 | 3.63 |
| WhiSQA | 3.4958 | 3.69 |

最终 `paper_metrics.json`、`paper_comparison.json` 和
`paper_comparison.md` 均已生成，九项无 missing。

## 14. 2026-11-12 E-VPC S gap closed by opposite-gender calibration

The paper-aligned random-target `DU-nt-nt` control obtained E-VPC S
`30.039%`, only `+0.2965 pp` above the formal `DU-pred-nt` value.
This rules out target-conditioned duration as the dominant S residual.

The existing target map was opposite-gender for only `48.7%` of test
utterances. A deterministic target-speaker-uniform map was therefore
built from the same original LibriTTS train-other-500 pool with an
opposite-gender constraint. The full 104,014-utterance LS360
anonymisation and official 10-epoch E-VPC S retraining completed
successfully.

| Metric | Formal `DU-pred-nt` | Opposite-gender `DU-nt-nt` | Paper |
|---|---:|---:|---:|
| E-VPC I | 48.0285% | 47.1920% | 47.2% |
| E-VPC L | 47.7540% | 49.0715% | 47.9% |
| E-VPC S | 29.7425% | **42.0405%** | 34.8% |
| W-NT I | 39.1679% | 39.3920% | 39.9% |
| W-NT L | 39.7293% | 41.1030% | 42.3% |
| WER | 6.2240% | 6.2924% | 7.41% |
| UTMOS | 3.5254 | 3.4589 | 3.63 |
| WhiSQA | 3.4958 | 3.4915 | 3.69 |

The result is a privacy-enhanced calibration variant, not a strict
reproduction of the paper's unspecified random-target gender policy.
It should not replace the paper-aligned row without that label.
