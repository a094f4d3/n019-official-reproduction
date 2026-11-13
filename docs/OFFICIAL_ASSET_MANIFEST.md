# Official Asset Manifest

更新日期：2026-11-02

## 1. 口径

本清单区分三件事：

- **官方文件一致**：代码、数据清单、音频、checkpoint、trial list 均使用
  VoicePrivacy Challenge 2024 官方版本。
- **论文协议一致**：只在 `libri_test` 上评测；EER 分 female/male 计算，
  WER 使用测试 trial 音频；I/L/S attack 定义与论文一致。
- **论文内部实现一致**：需要作者代码或补充材料。论文没有公开的部分不能在
  现有材料下证明一致。

前两项可以通过公开或注册资源完成。第三项目前无法完全证明。

## 2. 固定版本

| 项目 | 官方来源 | 固定值 |
|---|---|---|
| N019 论文 | ISCA Archive | DOI `10.21437/Odyssey.2026-16` |
| VPC2024 代码 | `Voice-Privacy-Challenge/Voice-Privacy-Challenge-2024` | tag `v2`, commit `7c80e86d3a4d58b81a2f3bdc01a3508c37018be4` |
| VPC2024 评测计划 | `VoicePrivacy_2024_Eval_Plan_v2.0.pdf` | Version 2.0, 2024-04-01 |
| W-NT 来源论文 | ISCA Archive | DOI `10.21437/SPSC.2025-6` |
| E-VPC 模型 | VPC release `pre_model.zip` | asset `asv_orig.zip` |
| ASR utility 模型 | VPC release `pre_model.zip` | asset `asr.zip` |
| NT 模型 | Hugging Face `Orange/Speaker-wavLM-pro` | revision `main`, snapshot `8451deb7b5019b9a99b1ed6a528dc75ba6b62b08` |
| HuBERT | Hugging Face `facebook/hubert-base-ls960` | snapshot `dba3bb02fda4248b6e082697eee756de8fe8aa8a` |

不要使用 VPC2024 仓库当前的 `main` 代替 `v2`。两者评测代码和配置可能已变化。

## 3. 已下载并校验的文件

| 文件 | 大小（bytes） | 校验值 | 状态 |
|---|---:|---|---|
| VPC `data.zip` | 10,119,867 | SHA256 `60C71B3F2F8FF8D7A35237CDA7D92FB2F6F5F1F2CB5C89CB91FC511A699860F7` | 完整 |
| VPC `data_test_tools.zip` | 120,506 | SHA256 `6270EBA200A8986EEE96B7E4CA9828BE3000678073985C15273A5B34B3D4F304` | 完整 |
| VPC `asv_orig.zip` | 70,464,879 | SHA256 `F0ABF60E569CB60A6F945A1A0A48E1A7D1AABE973F956DC3A872A3E686A7BF5E` | 完整 |
| VPC `asr.zip` | 752,987,942 | 下载后执行 `unzip -t` 并记录 SHA256 | 未下载 |
| W-NT `model.safetensors` | 1,266,588,504 | SHA256 `ad40a04ae6f0b46dbe6c7a6db71ff46f99775c59a0dccf61eb91f29216fbb2d4` | 已在旧项目验证 |

`data.zip` 只有 Kaldi 元数据，没有 `libri_dev` / `libri_test` 音频。

## 4. 注册后必须获取的数据

注册入口：

```text
https://forms.office.com/r/T2ZHD1p3UD
```

注册由用户本人完成。不要把收到的密码写进仓库、脚本、日志或聊天记录。

取得密码后，从官方 SFTP 下载：

```text
Host: voiceprivacychallenge.univ-avignon.fr
User: getdata
Directory: /challengedata/corpora
Files: libri_dev.tar.gz
       libri_test.tar.gz
```

下载后必须验证：

```bash
tar -tzf libri_dev.tar.gz >/dev/null
tar -tzf libri_test.tar.gz >/dev/null
sha256sum libri_dev.tar.gz libri_test.tar.gz
```

官方包的大小和 SHA256 只有在取得文件后才能记录。不得使用来源不明的镜像。

## 5. OpenSLR 公共语料

| 语料 | 官方 URL | MD5 |
|---|---|---|
| LibriSpeech `train-clean-100` | `https://www.openslr.org/resources/12/train-clean-100.tar.gz` | `2a93770f6d5c6c964bc36631d331a522` |
| LibriSpeech `train-clean-360` | `https://www.openslr.org/resources/12/train-clean-360.tar.gz` | `c0e676e450a7ff2f54aeade5171606fa` |
| LibriTTS `train-clean-100` | `https://www.openslr.org/resources/60/train-clean-100.tar.gz` | `4a8c202b78fe1bc0c47916a98f3a2ea8` |
| LibriTTS `train-other-500` | `https://www.openslr.org/resources/60/train-other-500.tar.gz` | `7b181dd5ace343a5f38427999684aa6f` |

用途：

- LibriSpeech `train-clean-100`：duration predictor 训练。
- LibriSpeech `train-clean-360`：官方 `ASV_eval` 训练，以及 S attack 的
  `ASV_eval^anon` 重训。
- LibriTTS `train-clean-100`：两个 Unit HiFi-GAN 训练。
- LibriTTS `train-other-500`：目标说话人池。

必须使用原始 LibriTTS。`LibriTTS-R` 不是论文使用的数据。

## 6. VPC Kaldi 数据清单

`data.zip` 解压后，Table 1 相关的 official test 数据为：

| 清单 | wav entries | trial pairs |
|---|---:|---:|
| `libri_test_enrolls` | 438 | 438 enrollment entries |
| `libri_test_trials_f` | 734 | 11,744 |
| `libri_test_trials_m` | 762 | 9,906 |

合计：

- test enrollment audio：438 条。
- test trial audio：1,496 条。
- test trial pairs：21,650 条。
- enrollment 涉及 29 名 speaker。
- female trial subset 涉及 20 名 speaker，male trial subset 涉及 20 名 speaker。

`libri_dev_*` 保留用于检查官方脚本，但不进入论文 Table 1 的主数值。

IEMOCAP 不进入 N019 Table 1。论文没有报告 UAR，因此复现 Table 1 不需要
申请或下载 IEMOCAP。

## 7. VPC 预训练模型

官方下载命令等价于：

```bash
wget \
  https://github.com/Voice-Privacy-Challenge/Voice-Privacy-Challenge-2024/releases/download/pre_model.zip/asv_orig.zip

wget \
  https://github.com/Voice-Privacy-Challenge/Voice-Privacy-Challenge-2024/releases/download/pre_model.zip/asr.zip
```

解压后：

```text
exp/asv_orig/
exp/asr/
```

`asv_orig` 的关键 checkpoint：

| 文件 | 大小（bytes） | SHA256 |
|---|---:|---|
| `embedding_model.ckpt` | 24,946,382 | `D71E0DC0C2E4AE857DC57A59A8D9702655698ADEFE7B9D74A2B1B2DC5031EB8C` |
| `classifier.ckpt` | 708,216 | `F5CB94BCA53A8D8780988D396C7B12330EB0B80D8896CFAD0354D6D277371552` |
| `normalizer.ckpt` | 1,153 | `30F888CCA75B7781AF7C03EA4973C8CAA1F070D60EFB9D7500190FB425ABC5E4` |

超参数记录：

- ECAPA channels: `[512, 512, 512, 512, 1536]`
- embedding size: `192`
- 分类器类别数：`921`
- 训练 seed：`1234`

不要从 SpeechBrain Hub 重新下载 `spkrec-ecapa-voxceleb` 代替
`exp/asv_orig`。

## 8. W-NT 模型

论文脚注指向：

```text
https://huggingface.co/Orange/Speaker-wavLM-pro
```

模型卡定义：

- 输入：16 kHz mono。
- 输出：250 维、L2-normalized embedding。
- 评分：embedding cosine similarity。
- 官方的等价计算函数默认截断超过 320,000 samples 的音频，即 20 秒。

注意：N019 论文没有写出截断长度。模型卡的教程代码默认
`max_size=320000`，即 20 秒；模型卡文字又提到实验中曾使用“max 30
seconds”，而 30 秒对应 480,000 samples。两者并不完全一致。为保证代码可
追踪，当前选择模型卡代码的默认值 320,000 samples，并记录该选择；不能写成
“论文明确给出 30 秒”。

## 9. MOS 工具

论文只给引用，没有给代码 commit 或 checkpoint 文件名。为保证可追踪，当前
固定如下版本：

| 工具 | 来源 | 固定值 |
|---|---|---|
| UTMOS | `sarulab-speech/UTMOS22` | commit `2d6d612cdf5bc610fde1a1b913c2d6c6fac8e063` |
| WhiSQA | `leto19/WhiSQA` | commit `0ad007e97093aa54c0c8cdac1af3e6ad6305af3f` |

WhiSQA 的 checkpoint 使用 Git LFS：

- 默认单头 MOS：`checkpoints/single_head_model.pt`
- LFS SHA256：`2da43d59294c358bdd3f450d0aef5ce57ad20bed3beb34657ef3a795a4766810`
- 文件大小：364,031,990 bytes

`get_score.py` 默认 `model_type=single`，输出时乘 5 得到 MOS。论文没有写明
single/multi head，因此 single head 是基于官方默认行为的重建选择。

UTMOS 的论文引用对应 UTMOS22。官方 README 推荐从
`sarulab-speech/UTMOS-demo` 的 Space 获取 strong learner。论文没有写具体
snapshot，必须记录实际下载到的 revision。

## 10. 最终资产目录

建议在新的远端项目中固定为：

```text
voice_projects/
  code/n019_official/
    vendor/Voice-Privacy-Challenge-2024/   # pinned v2
    src/n019/
    configs/
  data/n019_official/
    corpora/libri_dev.tar.gz
    corpora/libri_test.tar.gz
    corpora/LibriSpeech/train-clean-100/
    corpora/LibriSpeech/train-clean-360/
    corpora/LibriTTS/train-clean-100/
    corpora/LibriTTS/train-other-500/
    vpc/data/                              # official data.zip
    processed/
  models/n019_official/
    vpc/asv_orig/
    vpc/asr/
    hubert/
    speaker_wavlm_pro/
  exp/n019_official/
```
