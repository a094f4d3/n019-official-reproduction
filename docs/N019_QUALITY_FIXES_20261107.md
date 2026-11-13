# N019 Quality Fixes and Selection Protocol

日期：2026-11-07

## 当前正式结果（2026-11-09 更新）

DU-pred-nt hpclong6k + 完整 other-500 mean32 target embeddings、
完整 1,934 句：

| 指标 | 复现 | 论文 | 差值 |
|---|---:|---:|---:|
| WER | 6.0784201815% | 7.41% | -1.3315798185 pp |
| UTMOS | 3.0965501278 | 3.63 | -0.5334498722 |
| WhiSQA | 3.0177116493 | 3.69 | -0.6722883507 |

WER 已优于论文；UTMOS/WhiSQA 仍低约 0.5–0.7。新的 target
embedding 使用每位 target speaker 在完整 other-500 中抽 32 句的
确定性均值，而非旧版 1–13 条 utterance 代理。更长的 BF16/FP32
训练和完整 speaker mean 仍在验证。不得把旧 checkpoint 或
CPU/GPU 评测差异解释为新配方结果。

## 已落实的代码修复

### 1. Feature matching 2x

- `src/n019/hifigan.py` 使用 `FEATURE_MATCHING_SCALE = 2.0`。
- `src/n019/training_recipe.py` 对损失函数做可计算 probe，期望值 4.0。
- `configs/training_recipe_lock.json` 锁定 `hifigan.py` 和
  `training_recipe.py` 的 SHA256。
- 任何训练 launcher 先运行 `scripts/verify_n019_training_recipe.py`；
  d6/d7 旧 1x 代码已同步为同一版本并验证通过。

### 2. MOS-aware checkpoint selection

- 新增 `--selection-policy mos_offline`。该模式关闭 mel L1 early stopping，
  不自动写 `best.pt`，只保存 `last.pt` 和 compact
  `snapshots/generator_stepXXXXXXXX.pt`。
- 新增 `--generator-snapshot-interval`，默认 10,000 steps。
- 新增 `src/n019/reconstruct_vocoder.py`：在 speaker-disjoint
  LibriTTS clean-100 dev 子集上做固定样本源说话人重建。
- 新增 `scripts/run_vocoder_snapshot_selection_ai.sh`：
  同一批 100 句、同一时长预测器、同一 checkpoint family，评分
  UTMOS22、WhiSQA 和 VPC2024 EncoderASR WER。
- 新增 `src/n019/rank_vocoder_snapshots.py`：以 baseline 为参照，
  要求 UTMOS 和 WhiSQA 同时达到最小增益，WER 回归不超过阈值，
  再按两项 MOS 平均增益排序。默认门槛为
  `+0.05/+0.05`，最大 WER 回归 `0.25` 个百分点。
- 该选模协议是论文未公开细节的实现偏离，不能写成论文参数。

### 3. Target embedding 口径

- 新增 `src/n019/target_embedding_pooling.py`：按 `target_speaker`
  对选定 target utterance embeddings 求均值，再做 L2 归一化。
- 新增 `--target-embedding-key {target_id,target_speaker}` 和
  `--target-embedding-mode`，并把口径写入 `anon.jsonl` 和
  `run_meta.json`。
- 已生成 d7 目标说话人均值代理：
  `nt_target_speaker_embeddings.npz`，843 个 key，250 维，
  SHA256 `72e360948e3e8f49fe12c7e6082d67ded9d1477b8dd528745698cb9b0a00f13c`。
  这组只有目标池中被选中的 target utterances，不是完整 other-500
  speaker 均值；metadata 明确记录 group-size 分布。
- 新增 `scripts/run_target_embedding_ab_ai.sh`：固定 100 句、
  同一 checkpoint/时长，只切换 target embedding 口径，配对比较
  UTMOS、WhiSQA、WER。

### 4. Duration predictor

- `diagnose_duration.py` 现在同时报告原始预测、负值/clamp、整数舍入、
  单位 MAE/RMSE、总时长相对误差、WAV 时长误差。
- duration checkpoint 默认按 `total_duration_relative_error` 选模，
  不再只看单位 MAE；旧配置仍可显式使用 `mae`。
- 已验证的现有 25 句 A/B 表明：预测时长与原始时长的 MOS 差只有
  约 `-0.048 UTMOS / +0.021 WhiSQA`，不是主要缺口；新诊断只用于
  判断是否存在异常时长/舍入问题，不能无证据重训。

## 零卡时数据准备

speaker-disjoint LibriTTS clean-100 split（seed 20261102）：

- train: 31,245 句
- dev: 1,991 句
- unit records train SHA256
  `a37302a91ce56d9dc8728193c2326333be59256605d9a139e989aed0df529529`
- unit records dev SHA256
  `037c24ce5deafb7196e67a08dbc2296fb7174e96a685de278637bc4c34645856`
- manifest train SHA256
  `9522322b0494f6004cfc45982f3427346ed0f56d3b35f27de243c0e3bad8ba4f`
- manifest dev SHA256
  `963d2146a77910e8356bc6ea98b3be972242a6cbf3fc3221cba96aa3f164c811`

## Target embedding A/B 结果

Job `2119055643385360385`，固定 100 句、ext102k checkpoint、同一
duration predictor、同一 UTMOS22/WhiSQA/ASR：

| 口径 | UTMOS | WhiSQA | WER |
|---|---:|---:|---:|
| target utterance embedding | 2.4527917790 | 2.6547999933 | 8.1640780566% |
| target-speaker mean + L2 | 2.5831683111 | 2.7459385157 | 7.9649542015% |
| 配对差 | +0.1303765321 | +0.0911385223 | -0.1991238550 pp |

配对标准误：UTMOS `0.0431365228`、WhiSQA `0.0305995695`；
100 句中 UTMOS 改善/恶化句数 `50/33`，WhiSQA `51/32`。方向和
WER 同向，支持“训练是 speaker-level、推理应使用 speaker-mean”
这一口径修正；但绝对增益不足以单独填平论文差距。输出
`runs/n019_official/target_embedding_ab_20261107_211652`，
`comparison.json` SHA256
`bdc43eca3869e18c02ed4aafa4664b58b8f4b29b1d2f6d9712d66e4739ba6bf3`。

## 后续实验顺序

1. `d7-target-embedding-speaker-mean-ab`：100 句 target embedding A/B，
   1 DCU、1 h，最坏 1.0 卡时。
2. `d4-vocoder-2x-diagnostic`：从 ext102k generator 初始化新的
   discriminator/优化器，按 2x 配方训练最多 20k steps，2 DCU、2 h，
   最坏 4.0 卡时；保存每 2k step snapshot，不覆盖旧 checkpoint。
3. `d7-vocoder-snapshot-selection`：在 1,991 句 speaker-disjoint dev
   子集取固定 100 句，按上述 MOS/WER 协议选模，1 DCU、1 h，
   最坏 1.0 卡时。
4. 只有候选 checkpoint 在固定 dev 样本上达到预声明门槛，才允许做
   完整 1,934 句匿名化和正式评测；不得直接在论文测试集上反复调参。

d7 的三个 2x 尝试均因跨账号 unit-record 路径不可读而在训练前
失败，没有产生有效结果。2026-11-07 22:22 改由数据所属账号
d4 提交 Job `2119073031535542274`，名称
`n019_voc2x_diag_d4_20261107_222229`；d4、2 DCU、2 h，
最坏 4.0 卡时。提交前已验证 33,236 条记录全部本地可读、
2x probe `4.0`、初始化 checkpoint SHA256 固定。输出独立目录，
不覆盖 ext102k。

同账号已生成相同的 speaker-disjoint split，train 31,245 / dev
1,991，manifest/dev SHA256 与 d7 完全一致。由于 d7 无权读取
d4 的音频/codes，选模也改在 d4 执行：
`d4-vocoder-snapshot-selection`，1 DCU、1 h，最坏 1.0 卡时。
Whisper-small、Wav2Vec2 配置、WhiSQA、ASR 和 duration 输入正在
d4 本账号离线准备，不跨账号读取或经本机中转公开大文件。

2026-11-07 22:48 选模资产已全部就绪，关键 SHA256：

- Whisper-small `config.json`
  `e6a2b489da1b5aed65a8eb8d1e7466fa867ad5643a8bc138ba708bd56b2875c4`
- Whisper-small `model.safetensors`
  `1d7734884874f1a1513ed9aa760a4f8e97aaa02fd6d93a3a85d27b2ae9ca596b`
- Whisper tokenizer
  `27fc476bfe7f17299480be2273fc0608e4d5a99aba2ab5dec5374b4482d1a566`
- WhiSQA `2da43d59294c358bdd3f450d0aef5ce57ad20bed3beb34657ef3a795a4766810`
- UTMOS `44c57e3e4135a243b43d2c82b6a693fcd56f15f9ad0e1eb2a8b31fdecd3a49b8`

与 d7 固定版本一致，公开资产均由 d4 自行下载。

全量 1,934 句 duration 诊断（CPU、0 卡时）显示：

- negative / zero / nonfinite = `0 / 0 / 0`
- total-duration relative error mean `0.0477569`、p95 `0.1259830`
- WAV duration absolute error mean `0.3618411 s`、p95 `1.0635 s`

因此 duration 确实有约 5% 总时长误差，但与此前 25 句语音质量
A/B 一致，不能作为 MOS 差约 1 分的主要解释。保持现有 duration
checkpoint，不先重训。

## 资源与安全门禁

- 仅使用 `a094f4d3`–`a094f4d7`；禁止实验室 A6000 和
  `/mnt/data/lihaopeng`。
- 所有 GPU 任务先运行
  `scripts/gpu_tiny_matmul_watchdog.sh`，300 秒 SIGKILL；
  10.6.15.32 若卡死只会快速失败，不切 CPU。
- 运行中的任务不重复提交；任何新任务必须记录账号、任务名、模式、
  资源、DCU/CPU/RAM、墙钟、最坏/预计卡时、输入输出和停止条件。
- 不重跑已完成的 ext102k WER/UTMOS/WhiSQA，不覆盖 step4k/76k/102k
  或已锁定的原始 checkpoint。
