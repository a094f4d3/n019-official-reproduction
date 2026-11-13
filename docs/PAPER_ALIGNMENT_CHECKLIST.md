# Paper Alignment Checklist

更新日期：2026-11-02

## 0. 数据集口径核验（2026-11-09）

论文使用的是**原始 LibriTTS**，不是 LibriTTS-R：

- Unit HiFi-GAN：LibriTTS `train-clean-100`；
- target speaker embedding 池：LibriTTS `train-other-500`；
- duration predictor：LibriSpeech `train-clean-100`；
- 最终评测：VPC2024 的 LibriSpeech `libri_test`。

当前正式训练与推理遵循这一口径。d6 的 LibriTTS
`train-clean-100.tar.gz` 已按官方 OpenSLR 包核验：
size `7,723,686,890` bytes、MD5
`4a8c202b78fe1bc0c47916a98f3a2ea8`、解压后 `33,236` 个 WAV；
target pool 来自原始 LibriTTS `train-other-500`。不得用
LibriTTS-R、旧 checkpoint 或替代 speaker map 替换这些输入。

## 1. 论文明确给出的内容

以下项目必须锁定：

| 项目 | 论文要求 | 执行要求 |
|---|---|---|
| 离散单元 | HuBERT + k-means | `facebook/hubert-base-ls960` |
| 单元词表 | `K=200` | 200 clusters，另设 padding |
| 帧移 | 约 20 ms | 50 Hz |
| 去重 | 连续重复 unit 合并 | 保留 run length 作为 duration |
| duration loss | MSE + 四个相邻 unit 的总时长 MSE | 两项均保留 |
| duration 条件 | ECAPA 192 维或 NT 250 维 | 对应 vocoder 使用同一类型 |
| 目标说话人池 | LibriTTS train-other-500 | 原始 LibriTTS，不是 LibriTTS-R |
| duration 训练集 | LibriSpeech train-clean-100 | 官方 OpenSLR |
| vocoder 训练集 | LibriTTS train-clean-100 | 官方 OpenSLR |
| vocoder 输入 | 每帧 `[unit_embedding, speaker_embedding]` | 不得改成相加或其他融合 |
| E-VPC | VPC2024 官方 ASV | 官方 `exp/asv_orig` |
| W-NT | WavLM non-timbral ASV | `Orange/Speaker-wavLM-pro` |
| WER | 官方 wav2vec2-large-960h-lv60-self ASR | 官方 `exp/asr` |
| I attack | original enrollment + anon trial | 官方 `oa` |
| L attack | anon enrollment + anon trial | 官方 `aa` |
| S attack | anon enrollment + anon trial + retrained ASV | 官方 `aa` after retraining |
| S 训练集 | anonymised LibriSpeech train-clean-360 | 必须完整匿名化 |
| S 重训 | 官方 ECAPA pipeline, 10 epochs, lr 0.01, batch 256 | 不修改 |
| MOS | UTMOS 与 WhiSQA | 两个都必须有 |
| 主表数据 | LibriSpeech test set | `libri_test` only |

## 2. 官方评测细节

### E-VPC

官方 `evaluation/privacy/asv/asv.py` 的实现是：

1. 每条音频先做 loudness normalization，目标 `-30 LUFS`，随后按峰值归一化；
   送入 SpeechBrain extractor 前再去掉首尾零值。
2. enrollment 每条音频提取 utterance embedding。
3. 同一个 speaker 的 enrollment embeddings 做算术平均，形成 speaker-level
   enrollment vector。
4. trial 使用 utterance-level embedding。
5. 使用 cosine similarity。
6. 使用 SpeechBrain 0.5.16 的 `EER` 实现。

不得用“每条 trial 只配一个 enrollment 文件”的简化协议。

### W-NT

模型卡和代码给出：

1. 16 kHz mono 输入。
2. 先做 waveform MVN。
3. WavLM-large 最后一层 hidden state。
4. 对时间维做 mean 和 standard deviation 拼接。
5. 两层 `1x1 Conv1d + BatchNorm + ReLU`。
6. 输出 250 维并 L2 normalize。
7. cosine similarity。

评测时 enrollment 仍按官方 VPC 的 speaker-level mean 规则聚合。模型卡代码
默认截断超过 320,000 samples 的音频；论文没有显式写该参数，因此必须记录
这一差异。

## 3. EER 和 WER 聚合

论文 Table 1 的数值与 VPC release `v2` 的 `libri_test` 结果一致，而不是
`libri_dev + libri_test` 的四行简单平均。证据：

- 官方 B5 `ASV_eval^anon` test female = `33.946`。
- 官方 B5 `ASV_eval^anon` test male = `34.729`。
- 两个 test 子集算术平均为 `34.3375`，论文写 `34.3`。
- 若把 dev 两行也算入，平均约为 `34.35`，不能得到论文写法。
- 官方 B5 test anon WER = `4.369`，论文写 `4.37`。

因此主表必须：

1. 只使用 `libri_test_trials_f` 和 `libri_test_trials_m`。
2. 分别计算 female/male EER。
3. 对两个 EER 做算术平均，再按论文一位小数报告。
4. WER 使用 `libri_test` 的 trial 音频语料级 WER。

在正式收口前，还要用女/男 score 文件验证：

- “先算两个 EER 再平均”；
- “合并两个 score set 后统一算 EER”。

两种结果在实际数据上可能略有差异。论文当前证据支持前者，但在原始 score
可得后必须显式核对。

## 4. 匿名化目标选择

VPC2024 要求 utterance-level anonymization：

- 每条 enrollment/trial 独立选择目标。
- 同一源说话人的不同 utterance 不共享固定目标。
- 不得按 speaker 固定映射目标。
- 目标池必须来自 LibriTTS `train-other-500` 全量。

论文没有给出：

- 是否排除源说话人本人；
- 是否控制目标性别；
- 随机数 seed；
- 目标 embedding 是取单条 utterance 还是多条平均。

当前实现若要保留“随机目标”，必须使用固定 seed 并记录。不能声称 seed 与
作者一致。

## 5. 论文无法唯一复原的模型细节

以下内容论文没有给出，公开材料也没有作者代码：

| 项目 | 状态 | 处理方式 |
|---|---|---|
| HuBERT 具体层号 | N019 未给出；K=200 引用的 [26] 明写 layer 6 | 当前 layer 6 与 [26] 一致；[32] 的 layer 9 是次级可能，不再是首要风险 |
| k-means 拟合语料 | [26] 明写 LibriSpeech train-clean-100 | 当前语料一致；样本数、迭代数、seed 仍是本地选择 |
| duration predictor 卷积层数/通道 | 论文指向 [17] DISSC，但未展开参数 | 采用 DISSC `LenPredictor` 七层 128 通道并记录 |
| duration optimizer/lr/batch/epochs | 未给出 | 记录本地选择；不得声称论文一致 |
| unit embedding 维度 | 未给出 | 记录本地选择 |
| speaker projection 维度 | 未给出 | 记录本地选择 |
| vocoder generator width | 未给出 | 记录本地选择 |
| vocoder optimizer/steps | 未给出 | 记录本地选择 |
| 目标 embedding 聚合方式 | 未给出 | 记录本地选择 |
| 目标采样 seed | 未给出 | 记录本地选择 |

因此可以完成“官方数据 + 官方评测 + 论文结构”的严格复现，但不能仅凭论文
声称每个神经网络内部选择和作者完全相同。

### 5.1 Unit HiFi-GAN 学习率的公开实现冲突（2026-11-10）

- DISSC 官方仓库 commit `4b6160bd3c1733ef01527bf2edaf575788ca60f8`
  的 `sr/configs/VCTK/hubert100_lut.json` 明确使用 `learning_rate=0.0008`、
  `batch_size=64`、`num_gpus=2`。
- 当前复现使用 `learning_rate=0.0002`、`batch_size=16`、1 DCU。
  证据来自 speech-resynthesis 的公开配置；论文 [27,32] 的代码链也与
  `0.0002` 相容，但论文没有报告该参数。
- N019 对 vocoder 引用的是 [27,32]，不是 DISSC [17]；因此不能仅因
  作者也参与了 DISSC 就断定 N019 使用 `8e-4`。同理，也不能把当前
  `2e-4` 写成作者确认值。
- 后续若当前长训在目标 step 仍明显低于论文 MOS，应对
  `2e-4/batch16` 与 `8e-4/batch64` 做成对诊断；在没有该证据前不切换。

## 6. 公开材料自身的不一致

Table 1 的 B4 行不能由论文正文和引用 [7] 唯一推出：

- N019 Table 1 的 B4 I/L 为 `47.8 / 49.5`，与 [7] 的 B4 I/L 一致。
- N019 Table 1 的 B4 S 为 `27.3`，与 [7] 的 B3 S 一致，而 [7] 的 B4 S
  为 `30.3`。
- N019 Table 1 的 B4 W-NT 为 `38.2 / 34.7 / 17.4`，与 [7] 的 B3 W-NT
  一致；[7] 的 B4 W-NT 为 `34.2 / 32.0 / 14.8`。

因此 B4 行同时混合了 [7] 的 B4 I/L 与 B3 的 S/W-NT。仅凭公开论文无法判断
这是排版错误、复跑结果，还是 N019 使用了未说明的 B4 版本。若要逐格复现
Table 1，必须向作者确认 B4 行的来源。

另外，N019 正文有一处写 `DU-pred-nt` 的 W-NT L 为 `42.4%`，Table 1 和
6.2 节写 `42.3%`。最终对表时以 Table 1 为主，但应保留该正文不一致记录。

## 7. 完整 Table 1 的收口条件

以下全部完成前，不能写“完整复现论文 Table 1”：

- 12 个匿名化系统和 Original 基线。
- E-VPC I/L/S。
- W-NT I/L/S。
- WER。
- UTMOS。
- WhiSQA。
- 所有数值只来自 `libri_test`。
- 每条结果保存原始 score、embedding、命令、配置和运行环境。
- 表内数值同时保存未舍入值和论文格式舍入值。

## 8. 环境差异

论文写“two RTX 4090 GPUs”，但未给 CUDA/PyTorch 版本。官方 VPC2024
安装脚本默认：

```text
CUDA 11.7
PyTorch 2.0.1
Python 3.11
SpeechBrain 0.5.16
```

SCNet 的 DCU/DTK 环境不是 NVIDIA 环境。可以使用相同数据和权重重跑，
但不能声称浮点结果或运行环境与作者 GPU 逐位一致。
