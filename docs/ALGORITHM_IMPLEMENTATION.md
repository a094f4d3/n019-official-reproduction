# N019 Algorithm Implementation

更新日期：2026-11-02

本文记录正式代码对论文 *Joint Timbral and Non-Timbral Speaker
Anonymisation* 的逐项实现。代码入口位于 `src/n019`。
参考实现 commit 固定在 `configs/reference_implementations.json`。

## 1. 论文明确给出的主链路

```text
16 kHz waveform
-> HuBERT continuous features
-> K-means with K=200
-> frame-wise discrete units (about 50 Hz)
-> collapse consecutive repeated units
-> collapsed unit sequence dc + run-length durations
-> target-speaker-conditioned duration predictor
-> predicted integer durations
-> expand dc
-> Unit HiFi-GAN with [unit_embedding, speaker_embedding] at every frame
-> anonymised waveform
```

论文明确要求：

1. 一个 unit 约对应 20 ms，因此 HuBERT 特征和 vocoder 都以 320 samples
   为一帧。
2. K=200。
3. 连续重复 unit 必须合并，重复次数就是训练时长。
4. duration predictor 同时使用 unit-wise MSE 和四个相邻 unit 的累计时长
   MSE。
5. 推理时对预测时长取整，并传播累计舍入余量。
6. duration predictor 可以使用 NT 250 维或 ECAPA 192 维 speaker embedding；
   也可以完全不用 speaker embedding。
7. Unit HiFi-GAN 每帧输入是 unit embedding 和 speaker embedding 的拼接，
   不能改成相加、乘性调制或单一 speaker ID。
8. NT 与 ECAPA 分别训练独立 vocoder。
9. duration predictor 的训练数据是 LibriSpeech train-clean-100。
10. vocoder 的训练数据是原始 LibriTTS train-clean-100。
11. 匿名化目标来自原始 LibriTTS train-other-500。

## 2. 论文没有公开、代码中显式配置的部分

以下参数无法仅凭论文恢复。默认值来自论文引用实现或保守工程选择，并在
`configs/paper_algorithm_v1.json` 中单列，报告时不得写成作者设置：

| 项目 | 默认值 | 依据 |
|---|---:|---|
| HuBERT 层号 | 6 | SSL-SAS 的 `output_layer=6` |
| duration unit embedding | 32 | DISSC `LenPredictor`（论文引用 [17]） |
| duration speaker projection | 32 | DISSC 的 speaker embedding 宽度；N019 论文未写连续 embedding 的投影方式 |
| duration hidden / layers / kernel | 128 / 7 / 3 | DISSC `LenPredictor` |
| duration unit masking | 0.2 | DISSC 训练时对 unit embedding 随机置零 |
| duration window-loss weight | 0.5 | DISSC `LenSumLoss` |
| duration output | linear + 训练集均值/标准差归一化 | DISSC `LenPredictor` |
| K-means | MiniBatchKMeans，全部可用帧流式拟合 | 论文未给拟合细节 |
| K-means seed | 20261102 | 本项目固定 seed |
| speaker 输入 | 直接拼接，无投影 | 按论文 Eq. (1) |
| vocoder unit embedding | 128 | speech-resynthesis HuBERT unit 配置 |
| vocoder 初始通道 | 512 | HiFi-GAN 标准配置 |
| upsample | 5,4,4,2,2 | 合计 320 samples/frame |
| segment | 28 frames = 8,960 samples | speech-resynthesis 配置 |
| vocoder optimizer | AdamW，2e-4，betas 0.8/0.99 | speech-resynthesis commit `dbb92c8d` / DISSC 配置 |
| gradient clipping | 关闭 | speech-resynthesis `train.py` 未裁剪；旧 5.0 为未记录实现选择 |
| training steps | 400,000 | 参考实现默认值，不是论文值 |

## 3. Duration predictor

实现文件：`src/n019/duration.py`

论文 3.1 的引用 [17] 是 Maimon 与 Adi 的 DISSC，不是 Private
kNN-VC。实现因此采用 DISSC 的 `LenPredictor` 结构，而不是只保留两层
卷积的简化版本。DISSC 原始模型用可训练的 speaker-ID embedding；N019
要求 NT/ECAPA 连续向量，所以代码把该向量投影到与 unit embedding 相同的
32 维后再逐 unit 拼接。这个投影是适配 N019 的实现选择，论文未给维度。

模型结构：

```text
unit ID
-> learned 32-D unit embedding
-> project speaker embedding to 32-D and concatenate at every unit
-> 7 x [Conv1d(k=3) + BatchNorm1d + LeakyReLU]
-> Conv1d(k=3, out_channels=1)
-> de-normalise using the training-set duration mean/std
```

损失（与 DISSC `LenSumLoss` 的训练归一化一致）：

```text
L = (
      sum_t (y_t - d_t)^2
    + 0.5 * sum_w (sum_{i in w} y_i - sum_{i in w} d_i)^2
    ) / N_valid_units
```

第二个损失按 DISSC 的方式切成不重叠的四元窗口，例如长度 10 的序列只
计算前两个窗口，余下两个 unit 不另成窗。padding 不进入任一损失。默认
`lambda=0.5`。point 项与 window 项都先求和，最终统一除以有效 unit
数，不能分别按有效 unit 数和有效窗口数取均值。训练时仅对有效 unit 的
embedding 做 0.2 概率置零；该细节来自 DISSC，论文 N019 正文未展开。

训练条件使用该训练 utterance 所属 source speaker 的 embedding。这样模型
学习“给定说话人时，该说话人的单元时长分布”。推理时换成随机目标说话人，
完成 rhythm conversion。

`DU-pred` 使用 `speaker_dim=0` 的独立无条件下模型；不会把未知 target
embedding 填零来冒充论文配置。

`DU-pred` 仍保留 DISSC 的七层卷积回归器，只删除 speaker 投影和输入拼接。
这比把有条件下模型直接填空 embedding 更接近 Table 1 的消融定义。

duration checkpoint 的新默认选模指标是
`total_duration_relative_error`，因为实际推理更关心总时长稳定性；
`mae` 仍可显式选择。`diagnose_duration.py` 同时报告原始值、负值、
clamp、整数舍入和 WAV 时长误差，不能把单一 MAE 当成 MOS 代理。

DISSC 的回归头是线性的，因此预测值理论上可能出现负数。正式推理在
rounding 前把负值 clamp 到 0，并把发生次数逐句写入 `anon.partial.jsonl`
和 `run_meta.json` 的 `negative_duration_values`；终端也逐条打印，不能静默
隐藏。论文没有说明这一数值保护，因此最终报告列为实现假设。若负数比例异常，
仍应检查训练收敛和 duration 均值/方差，而不是把它当成正常结果。

## 4. Unit HiFi-GAN

实现文件：`src/n019/hifigan.py`、`src/n019/vocoder.py`

生成器保留完整 HiFi-GAN 结构：

- 5 层 transposed convolution，上采样倍率 `5 x 4 x 4 x 2 x 2 = 320`；
- 每层三个 residual blocks，kernel 为 3/7/11，dilation 为 1/3/5；
- 初始通道 512；
- 输出 tanh。

条件输入逐帧计算：

```text
h_t = UnitEmbedding(d_t)
e_t = concat(h_t, z_spk)
```

默认不做 speaker projection，因为论文明确写的是拼接。只有显式配置
`speaker_projection_dim` 时才允许改变该结构。

训练目标保留 HiFi-GAN 的：

- multi-period discriminator LSGAN loss；
- multi-scale discriminator LSGAN loss；
- feature matching loss；
- 45 倍 mel L1 reconstruction loss；
- generator LSGAN loss。

feature matching 按 speech-resynthesis 和 DISSC 的训练代码：先累加
所有 MPD/MSD 特征图的 L1，再对每个判别器的总 feature loss 乘 `2`。
旧实现漏掉了该 `2x` 系数，使生成器的 feature-matching 项只有引用实现的
一半；修正前的 NT vocoder 只能保留为历史工程结果。

优化器使用引用实现的 AdamW、学习率 `2e-4`、betas `0.8/0.99` 和
`0.999` 指数衰减。片段长度固定为 8,960 samples，训练前按 speech-resynthesis
的做法做 `librosa.util.normalize * 0.95`。

2026-11-08 的零卡时审计发现此前误写、误用了 `8e-4`。论文引用的
speech-resynthesis 主配置、VCTK 配置和 Expresso 配置均使用
`learning_rate=0.0002`，其余 `batch_size=16` per GPU、
`segment_size=8960`、`adam_b1=0.8`、`adam_b2=0.99`、
`lr_decay=0.999` 与本实现一致。旧 step 4k/76k/102k 和 2x
step 14k–24k 都是高 4 倍的学习率训练的，只保留为历史/诊断结果；
新的论文对齐训练必须使用 `2e-4`。证据 commit：
`dbb92c8ddeb081e711adbe9a75714027cd447532`。
旧实现还额外对 generator 做 `5.0` 梯度裁剪，而引用训练循环没有这一
步骤。新默认已改为 `grad_clip_norm=0`（关闭）；只有诊断任务可显式设置
正值，并在结果中标注。

SCNet DTK 的部分 2-DCU 节点对 `torch.stft` 和 `torch.fft.rfft`
都会报 `HIPFFT_PARSE_ERROR`。`n019.spectral` 因此使用等价实现：
显式 Hann 分帧后，与预计算的 cos/sin 实数 DFT 基矩阵相乘，再乘 mel
滤波器组。该路径不使用 hipFFT，数学上仍是相同的 45 倍 mel L1 loss，
并保留梯度；回归测试要求其与 `torch.stft` 的 mel 输出在浮点容差内一致。

论文没有给出 Unit HiFi-GAN 的停止步数或 early stopping 协议。
400,000 steps 只是引用实现配置中的安全上限，不应写成论文值。当前正式
新任务默认使用 `mos_offline` 选模：每 2,000 steps 保存一个
generator snapshot，训练不按 mel L1 提前停止；随后在 speaker-disjoint
clean-100 dev 子集上用固定 100 句重建结果比较 UTMOS/WhiSQA，并设置
WER 回归门槛。只有显式指定 `selection_policy=mel_l1` 的旧配置才保留
固定的 mel L1 监控/早停行为。所有候选 checkpoint 都必须记录
recipe hash 和输入 hash。

`last.pt` 保存 generator、两个判别器、AdamW optimizer 状态、scheduler、
step、best metric、patience 和 `stop_reason`，用于换账号精确恢复；
`best.pt` 只保存 generator，用于最终推理。完整与精简 checkpoint 的
用途和实测体积见 `docs/VOCODER_TRAINING_RESUME.md`。

## 5. 数据与匿名化

- `n019.prepare_data`：从官方 OpenSLR 解压目录建立 manifest；
- `n019.units`：全量 HuBERT 特征、K-means 编码和 unit record；
- `n019.extract_speakers`：NT/W-PRO 或官方 VPC ECAPA embedding；
- `n019.split_manifest`：speaker-disjoint 的 train/dev manifest；
- `n019.targets`：固定 seed 的 utterance 到 target utterance 映射；
- `n019.anonymize`：执行全部 `DU-X-Y` 配置。

目标映射在只生成一次后复用于所有系统，保证配对比较。映射保存 target
utterance ID 和 target speaker ID，因此 `X` 与 `Y` 使用不同 embedding
类型时仍指向同一个目标身份。

target embedding 的 pooling 规则论文未给出。正式默认仍是
target-utterance embedding；新增的
`n019.target_embedding_pooling` 支持按 target speaker 对选中 utterance
embedding 求均值并 L2 归一化，用于受控 A/B。该 proxy 的 group-size、
源 NPZ SHA256 和 target-map SHA256 写入 metadata；不得把它说成完整
other-500 speaker-level embedding。

`libri_test` 和匿名化 LS360 必须使用同一抽样口径。正式映射以完整
LibriTTS train-other-500 manifest（205,044 句）为池，使用
`mode=utterance` 和固定 seed；不得先把池缩成 `libri_test` 已引用的
target 子集，再给 LS360 复用。旧 LS360 `mode=speaker` 映射只保留为
偏离记录，不进入正式 S attack。

## 6. 运行入口

准备 manifest：

```bash
python -m n019.prepare_data \
  --librispeech-train /path/to/LibriSpeech/train-clean-100 \
  --libritts-train /path/to/LibriTTS/train-clean-100 \
  --libritts-target /path/to/LibriTTS/train-other-500 \
  --out /path/to/manifests
```

提取 unit 和拟合 K-means：

```bash
python -m n019.units \
  --manifest /path/to/manifests/librispeech_train_clean_100.jsonl \
  --out /path/to/units/librispeech_train_clean_100 \
  --hubert-model /path/to/models/hubert \
  --device cuda
```

长数据集提取时，每个 batch 的 code 落盘后会把对应记录追加并 `fsync` 到
`unit_records.partial.jsonl`。中断后必须复用同一个 K-means codebook，并加
`--resume`；已完成且 code 文件存在的 utterance 不会再次经过 HuBERT：

```bash
python -m n019.units \
  --manifest /path/to/manifests/librispeech_train_clean_360.jsonl \
  --out /path/to/units/librispeech_train_clean_360 \
  --hubert-model /path/to/models/hubert \
  --codebook /path/to/units/librispeech_train_clean_100/kmeans_k200_seed20261102.npz \
  --resume \
  --device cuda
```

`--resume` 会校验记录中的 K、HuBERT 层号、确定性 code 路径、帧数以及 code
文件是否真实存在；任何不一致都直接停止，不静默重算或拼接错误数据。

提取 speaker embedding：

```bash
python -m n019.extract_speakers \
  --manifest /path/to/manifests/librispeech_train_clean_100.jsonl \
  --model /path/to/models/wpro \
  --kind nt \
  --level speaker \
  --out /path/to/embeddings/librispeech_train_clean_100_nt
```

W-PRO 的官方 `compute_embedding` 默认只保留前 320,000 samples（20 s）。
当前 extractor 复现这一模型卡行为，并把 `nt_max_samples=320000` 写入
`metadata.json`。论文正文没有说明这一截断规则，因此对表时把它列为
公开实现假设，而不是论文明示参数。

目标池使用同一 extractor，但按 utterance 保存，推理时由 target map 指向：

```bash
python -m n019.extract_speakers \
  --manifest /path/to/manifests/libritts_train_other_500.jsonl \
  --model /path/to/models/wpro \
  --kind nt \
  --level utterance \
  --out /path/to/embeddings/libritts_train_other_500_nt_utterance
```

训练 duration predictor：

```bash
python -m n019.duration \
  --records /path/to/units/librispeech_train_clean_100/unit_records.jsonl \
  --embeddings /path/to/embeddings/librispeech_train_clean_100_nt/nt_speaker_embeddings.npz \
  --speaker-dim 250 \
  --embedding-kind nt \
  --out /path/to/runs/duration_nt
```

无条件 `DU-pred`：

```bash
python -m n019.duration \
  --records /path/to/units/librispeech_train_clean_100/unit_records.jsonl \
  --speaker-dim 0 \
  --embedding-kind none \
  --out /path/to/runs/duration_pred
```

训练 Unit HiFi-GAN：

```bash
python -m n019.vocoder \
  --records /path/to/units/libritts_train_clean_100/unit_records.jsonl \
  --embeddings /path/to/embeddings/libritts_train_clean_100_nt/nt_speaker_embeddings.npz \
  --speaker-dim 250 \
  --out /path/to/runs/vocoder_nt
```

不传 validation 参数时，只用训练记录前 64 条做监控，不把它们从训练集剔除。
如果要单独的 pilot 验证集，再同时传入 `--validation-records` 和
`--validation-embeddings`。

生成固定目标映射：

```bash
python -m n019.targets \
  --source-manifest /path/to/manifests/libri_test.jsonl \
  --target-manifest /path/to/manifests/libritts_train_other_500.jsonl \
  --seed 20261102 \
  --out /path/to/target_map.jsonl
```

匿名化：

```bash
python -m n019.anonymize \
  --source-manifest /path/to/libri_test.jsonl \
  --unit-records /path/to/unit_records.jsonl \
  --target-map /path/to/target_map.jsonl \
  --duration-mode pred \
  --duration-model /path/to/runs/duration_pred/best.pt \
  --vocoder /path/to/runs/vocoder_nt/best.pt \
  --vocoder-type nt \
  --vocoder-embeddings /path/to/target_nt_utterance_embeddings.npz \
  --out-dir /path/to/anonymised/DU-pred-nt
```

完整 LS360 匿名化使用 `--resume`：每 25 条（可配置 `--flush-every`）把
输出记录追加并 `fsync` 到 `anon.partial.jsonl`。重启时只跳过记录存在且
WAV 文件确实存在的 utterance，并校验 duration mode、vocoder type 和确定性
输出路径；中断前未登记的最后一批最多重算一次：

```bash
python -m n019.anonymize \
  --source-manifest /path/to/manifests/librispeech_train_clean_360.jsonl \
  --unit-records /path/to/units/librispeech_train_clean_360/unit_records.jsonl \
  --target-map /path/to/targets/librispeech_train_clean_360_target_map_utterance.jsonl \
  --duration-mode pred \
  --duration-model /path/to/runs/duration_pred/best.pt \
  --vocoder /path/to/runs/vocoder_nt/best.pt \
  --vocoder-type nt \
  --vocoder-embeddings /path/to/target_nt_utterance_embeddings.npz \
  --out-dir /path/to/anonymised/DU-pred-nt-ls360 \
  --resume \
  --device cuda
```

上例中的 LS360 target map 必须由完整 other-500 manifest 以
`mode=utterance` 生成；对应 target embedding 目录应使用
`librispeech_train_clean_360_target_nt_utterance`，不能复用只有 1,924
个测试 target 的 `libri_test_target_nt_utterance`。

匿名化在写 WAV 前会按源 manifest 的 `seconds` 估算 PCM16 单声道
16 kHz 输出大小，默认乘 1.10 安全系数并与目标目录所在文件系统剩余空间
比较。空间不足时直接停止，不会先生成一半再耗尽磁盘。当前完整 LS360
理论输出约 42 GB；d4 当时只剩约 44 GB，因此正式 LS360 匿名化不能盲目
在 d4 启动，应使用 d5 或先经过确认的存储清理/迁移方案。

导出 VPC2024 可读取的数据目录：

```bash
python -m n019.export_vpc_anon \
  --vpc-data-dir /path/to/vpc/data \
  --anon-manifest /path/to/anonymised/DU-pred-nt/anon.jsonl \
  --suffix _n019_official \
  --dataset-name libri_test \
  --dataset-name libri_test_enrolls \
  --dataset-name libri_test_trials_f \
  --dataset-name libri_test_trials_m
```

## 7. 论文声明与代码位置

| 论文声明 | 代码位置 | 处理 |
|---|---|---|
| HuBERT + K-means，`K=200`，约 20 ms/unit | `src/n019/units.py`、`src/n019/audio.py` | 16 kHz、320 samples/frame、K=200 |
| 连续重复 unit 合并，重复次数作 duration | `collapse_consecutive` | 保留 |
| duration predictor 跟随 [17] | `src/n019/duration.py` | 完整 DISSC 七层结构 |
| unit MSE + 四个相邻 unit 总时长 MSE | `duration_objective` | 非重叠 4-unit 窗口 |
| inference round 并传播舍入余量 | `round_durations_with_residual` | 累计和取整 |
| `DU-pred` 不使用 speaker embedding | `DurationModelConfig(speaker_dim=0)` | 独立无条件下模型 |
| Unit HiFi-GAN 每帧拼接 unit/speaker | `UnitSpeakerHiFiGAN.forward` | 默认不做 speaker 投影 |
| NT 250 维和 ECAPA 192 维分别训练 vocoder | `speaker.py`、`vocoder.py` | 配置中强制维度 |
| duration 用 LibriSpeech clean-100 | `prepare_data.py` | manifest 固定数据集名 |
| vocoder 用 LibriTTS clean-100 | `prepare_data.py` | 禁止 LibriTTS-R |
| target 来自 LibriTTS other-500 | `targets.py` | 固定 seed 的逐 utterance 映射 |

## 8. 官方 MOS 与 S 攻击入口

Table 1 的 UTMOS 和 WhiSQA 现在由 `n019.eval_mos` 批量执行。UTMOS
直接加载 `vendor/UTMOS22-demo/score.py` 的作者推理类和官方镜像权重；
WhiSQA 直接实例化 `vendor/WhiSQA` 的
`whisperMetricPredictorEncoderLayersTransformerSmall`，按官方
`get_score.py` 的 `score * 5` 规则输出 0–5 MOS。两者均要求 16 kHz
单声道输入，且逐文件记录 SHA256。正式脚本以完整
`libri_test$SUFFIX/wav.scp` 为输入，要求 1,934 句全部评分；不能只取
female/male trial 去重后的 1,496 句子集，也不能用 dev 音频补足。

E-VPC S 使用 VPC2024 官方 `eval_post.yaml`：先将完整 LS360 用同一个
DU 系统匿名化，再以匿名化 LS360 重训 ECAPA 10 epochs，最后只在
`libri_test` 的 AA trial 条件计算 EER。`scripts/run_s_eval_remote.sh`
负责该官方流程。W-NT S 必须从对应预训练 W-NT 模型开始在匿名化 LS360
上单独 fine-tune；I/L 模型不能替代 S。

VPC 原始结果必须按 enrollment/trial 轨迹解释，不能按列名猜测论文条件：

| VPC 轨迹 | 原始 E-VPC 模型 | 匿名化重训 E-VPC 模型 |
|---|---|---|
| `OO` | 原始数据基线 | 不是论文 Table 1 的 I/L/S |
| `OA` | N019 的 I | 不是论文 Table 1 的 I/L/S |
| `AA` | N019 的 L | N019 的 S |

`n019.parse_vpc_results` 默认只保留中性的 `OO/OA/AA` key；调用方必须用
`--model-role original` 或 `--model-role anon` 显式生成论文条件映射。

W-NT S 的实现入口是 `n019.wnt_attack`。它严格检查匿名化 LS360 必须
包含 104,014 句和 921 个说话人，然后以 W-PRO 250 维模型为初始化，
使用 AAM-Softmax 在匿名化数据上 fine-tune 20 epochs。论文没有给出
S fine-tune 的学习率、batch size、裁剪长度、优化器和 AAM 参数，当前
实现采用与原 W-NT/语音验证训练一致的 AAM
`margin=0.2, scale=30`，以及 `lr=1e-4`、`batch=8`、3 秒随机片段；
这些必须列为实现假设。训练完成后导出可被 `load_wpro` 直接读取的
`model/`，再通过
`N019_WNT_S_MODEL=<run>/model N019_WNT_ATTACKS=S scripts/evaluate_wnt_remote.sh`
计算匿名 enrollment + 匿名 trial 的 EER。

`scripts/train_wnt_s_remote.sh` 通过
`python -m torch.distributed.run --standalone` 支持多 DCU；
默认 4 DCU、全局 batch 8（每 rank 2），因此不改变论文未公开的全局 batch
假设。W-PRO 编码器与 AAM head 被封在同一个 DDP module 中，optimizer、
gradient clipping、checkpoint、loss/accuracy 聚合和 rank-0 导出均按同一
训练语义处理。`last.pt` 可在相同 world size 或单 rank 下继续加载。

## 9. 不得引入的简化

- 不得只取少量 utterance 拟合 K-means 后声称使用 train-clean-100。
- 不得跳过连续重复 unit 合并。
- 不得只保留 unit MSE 而删除四邻域总时长损失。
- 不得用普通四舍五入替代累计余量传播。
- 不得把 speaker embedding 相加、广播到通道或替换成 speaker ID。
- 不得用 LibriTTS-R 生成正式 vocoder 或 target embedding。
- 不得复用探索实验的 duration/vocoder checkpoint。

## 10. LS360 的系统配置参数

`scripts/anonymize_ls360_remote.sh` 不再把 NT 写死。外部配置为：

```text
N019_DURATION_MODE       orig | pred | nt | ecapa
N019_VOCODER_TYPE        nt | ecapa
N019_DURATION_MODEL      duration checkpoint
N019_DURATION_EMBEDDINGS duration 条件 embedding
N019_VOCODER             Unit HiFi-GAN checkpoint
N019_VOCODER_EMBEDDINGS  vocoder 条件 embedding
N019_ANON_OUT            输出目录
```

每一组 `DU-X-Y` 必须使用同一 target map 的 target utterance ID：

- X=`nt` 时，duration 使用 250-D W-PRO utterance embedding；
- X=`ecapa` 时，duration 使用 192-D 官方 VPC ECAPA utterance embedding；
- X=`pred` 时，duration 不接收 speaker embedding；
- X=`orig` 时，不加载 duration model，直接使用单元 collapse 后的原始时长；
- Y=`nt` 或 `ecapa` 时，vocoder 必须分别使用对应的 250-D 或 192-D
  checkpoint 和同一 target ID 的 embedding。

默认路径随类型自动切换：

```text
target_nt_utterance/nt_utterance_embeddings.npz
target_ecapa_utterance/ecapa_utterance_embeddings.npz
runs/vocoder_nt_main/best.pt
runs/vocoder_ecapa_main/best.pt
```

ECAPA target utterance 提取入口为
`scripts/run_ls360_target_ecapa_shard_ai.sh`。它使用官方 VPC
`asv_orig` 的 `hyperparams.yaml`、`embedding_model.ckpt` 和
`classifier.ckpt`，输出 192 维逐句 embedding；四个 shard 完成后用
`scripts/merge_target_embedding_shards.py --kind ecapa` 合并，并强制
校验完整 ID 集合、维度、有限值和 L2 norm。
