# N019 Resource Transfer Audit

更新日期：2026-11-03

统计口径：

- “服务器直接下载”只统计一份唯一资源，不按三个账号重复计数。
- 大小使用文件的十进制 GB（1 GB = 10^9 bytes），同时列出 bytes。
- 受控 VPC SFTP 的 `libri_dev.tar.gz`、`libri_test.tar.gz` 没有公开的
  固定大小，当前不纳入总数；项目已有重建包作为替代。
- “本地中转”统计当前可复用的最小集合，不统计旧 `r1`–`r15` 代码包。

## 1. 服务器可直接下载

### OpenSLR 公共语料

| 资源 | bytes | GB |
|---|---:|---:|
| LibriSpeech `train-clean-100` | 6,387,309,499 | 6.387 |
| LibriSpeech `train-clean-360` | 23,049,477,885 | 23.049 |
| LibriTTS `train-clean-100` | 7,723,686,890 | 7.724 |
| LibriTTS `train-other-500` | 44,565,031,479 | 44.565 |
| LibriSpeech `dev-clean` | 337,926,286 | 0.338 |
| LibriSpeech `test-clean` | 346,663,984 | 0.347 |
| **合计** | **82,410,096,023** | **82.410** |

来源：

```text
https://www.openslr.org/resources/12/train-clean-100.tar.gz
https://www.openslr.org/resources/12/train-clean-360.tar.gz
https://www.openslr.org/resources/60/train-clean-100.tar.gz
https://www.openslr.org/resources/60/train-other-500.tar.gz
https://www.openslr.org/resources/12/dev-clean.tar.gz
https://www.openslr.org/resources/12/test-clean.tar.gz
```

### VPC2024 代码和 release

| 资源 | bytes | GB |
|---|---:|---:|
| `data.zip` | 10,119,867 | 0.010 |
| `data_test_tools.zip` | 120,506 | 0.000 |
| `asv_orig.zip` | 70,464,879 | 0.070 |
| `asr.zip` | 752,987,942 | 0.753 |
| **合计** | **833,693,194** | **0.834** |

VPC 代码应从 GitHub 的 pinned `v2` commit 直接 clone；这些 release
文件从官方 GitHub release 直接下载。不要上传本地
`vendor/vpc2024/asr.zip.part` 或不完整的旧下载。

### 模型与 MOS checkpoint

| 资源 | bytes | GB |
|---|---:|---:|
| W-NT / W-PRO `model.safetensors` | 1,266,588,504 | 1.267 |
| HuBERT `pytorch_model.bin` | 377,569,754 | 0.378 |
| UTMOS `model.ckpt` | 1,238,128,841 | 1.238 |
| UTMOS `wav2vec_small.pt` | 950,500,491 | 0.951 |
| WhiSQA single-head checkpoint | 364,031,990 | 0.364 |
| **合计** | **4,196,819,580** | **4.197** |

来源是 Hugging Face / HF mirror 的固定 revision；UTMOS 和 WhiSQA 的
代码也可以由服务器 clone GitHub 获取。

### 直接下载总计

```text
82,410,096,023 + 833,693,194 + 4,196,819,580
= 87,440,608,797 bytes
= 87.441 GB
= 81.435 GiB
```

这是“每个完整账号需要一份公开依赖”的基准。如果三个账号都下载完整
82 GB OpenSLR，三账号网络流量约 `262.322 GB`；但按角色只需要下载
对应语料，不应无条件三份全量下载。

按当前角色拆分，直接下载需求约为：

| 账号 | 需要的内容 | 约 GB |
|---|---|---:|
| d4 主账号 | LibriSpeech clean-100、LibriTTS clean-100/other-500、dev/test、VPC release、模型 | 64.391 |
| d3 第二训练账号 | 全量 OpenSLR、VPC release、模型 | 87.441 |
| d5 匿名化账号 | LibriSpeech train-clean-360、VPC release、模型 | 28.080 |
| **三账号合计** | 按角色下载，不是三份全量 | **179.912** |

## 2. 需要本地中转复用

### 最小复用集合

| 文件 | bytes | GB | 原因 |
|---|---:|---:|---|
| `VPC2024_LibriSpeech_rebuilt_v1.tar.zst` | 803,952,062 | 0.804 | 从公开 LibriSpeech 按 VPC utterance ID 重建，重新生成耗时且必须保持同一校验结果 |
| `artifacts/n019_processed_train_20261103.tar.gz` | 28,373,293 | 0.028 | 已生成的 clean-100 units 和 W-PRO embeddings，重算需要 GPU |
| `target_map_utterance.jsonl` | 46,436,373 | 0.046 | 完整 other-500、固定 seed 的 utterance 映射 |
| `target_manifest.jsonl` | 38,847,281 | 0.039 | 映射实际引用的 81,605 个 target utterances |
| `artifacts/n019_code_20261103_r18.tar.gz` | 约 0.55 MB | 0.001 | 当前本地代码，不在公开 GitHub 仓库中 |
| `artifacts/torchaudio_scnet_compat.tar.gz` | 8,625 | 0.000 | 已验证的 SCNet/DTK 兼容包 |
| **合计** | **918,166,770** | **0.918** | 不含尚在生成的目标 embedding 和模型 checkpoint |

如果只给两个从账号各上传一份，本地中转网络流量约为
`1.836 GB`；如果三个账号各上传一份，约 `2.755 GB`。

### 可选但非必要

| 文件 | bytes | 说明 |
|---|---:|---|
| `bootstrap_assets.tar.gz` | 80,749,782 | VPC 代码、脚本和文档的旧快捷包；可由 clone + r18 代码包重建 |
| `vendor/vpc2024/` | 203,389,216 | 公开 VPC 资产的本机副本，服务器可重新下载 |
| `vendor/Voice-Privacy-Challenge-2024/` | 1,477,452 | Git 源码，服务器可 clone |
| `vendor/papers/` | 4,952,125 | 本地阅读材料，不上传服务器 |
| 旧 `n019_code_*`、`scripts_remote.tar.gz` | 小型旧包 | 不应作为正式复用来源 |

### 尚未生成、以后也需要中转的内容

- 81,605 个 target utterance 的 final W-PRO NPZ：理论上约
  `81,605 × 250 × 4 ≈ 81.6 MB`，加 NPZ/元数据开销。
- duration 和 vocoder checkpoint：跨账号续训时需要本地中转。
- 完整 LS360 units、LS360 匿名化 WAV 和 S attack 模型：当前未完成，
  不作为本次“现有文件总量”计算。

## 3. 结论

- 公开来源直接下载基准：**约 87.44 GB / 单账号完整依赖**。
- 当前最小本地复用集合：**约 0.918 GB**。
- 若把旧 `bootstrap_assets.tar.gz` 也作为快捷包：**约 0.999 GB**。
- 大文件原则不变：OpenSLR、VPC release、HuBERT/W-NT、UTMOS/WhiSQA
  全部让各账号自己下载；只把重建数据、处理后 units/embeddings、映射、
  checkpoint、兼容包和代码通过本地中转。
