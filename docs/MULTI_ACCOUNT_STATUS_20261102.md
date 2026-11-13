# N019 Multi-Account Status

更新时间：2026-11-02 18:50（Asia/Shanghai）

## 1. 环境状态

三个账号均使用：

```text
Python 3.11.17
DTK 26.04
torch 2.9.0
torchaudio 2.9.0+scnet-compat
Transformers 4.46.3
SpeechBrain 0.5.16
kaldiio 2.18.0
FFmpeg 7.0.2
```

`d3` 和 `d5` 的 `torchaudio` 来自主账号导出的 8,625-byte
`compat/torchaudio` 包，SHA256：

```text
6513f89b82011655c34c4bb24b53fad53612e9befa62634be86f507250965b4f
```

没有在公共 PyPI 安装或覆盖 `torch`。

## 2. `a094f4d4`

主账号完整环境和资产已经就绪。

`LibriTTS train-other-500` 当前正式目录仍只有 1,272 个 WAV；两个旧 partial
目录被保留。全量 tar 的 MD5 已通过。

解压任务已经准备但尚未提交：

```text
scripts/multi_account/extract_all_d4.slurm
scripts/multi_account/extract_all_d4_remote.sh
```

`sbatch --test-only` 通过，输出已保存到：

```text
/public/home/a094f4d4/voice_projects/code/n019_official/audit/extract_job_test_only.txt
```

`--test-only` 不分配资源，不消耗卡时。正式提交仍等待用户确认资源计划。
测试输出预计资源最早在 `2026-11-07T22:04:17` 开始；这是队列模拟，
不表示已经有作业或已保留资源。

## 3. `a094f4d3`

项目已建立：

```text
/public/home/a094f4d3/voice_projects/code/n019_official
/public/home/a094f4d3/voice_projects/data/n019_official
/public/home/a094f4d3/voice_projects/models/n019_official
```

已完成服务器侧公开下载：

```text
VPC2024 v2 source
data.zip
data_test_tools.zip
asv_orig.zip
asr.zip
HuBERT
W-NT
UTMOS22
WhiSQA repository and checkpoint
UTMOS mirror
LibriSpeech dev-clean
LibriSpeech test-clean
```

大规模训练语料已使用独立 worker 继续下载：

```text
LibriSpeech train-clean-100
LibriSpeech train-clean-360
LibriTTS train-clean-100
LibriTTS train-other-500
```

worker 脚本：

```text
scripts/multi_account/run_one_openslr_download_remote.sh
scripts/multi_account/download_corpora_parallel_remote.sh
```

每个文件使用 16 个 HTTP Range 连接，失败后 60 秒重试；完成时以官方 MD5
校验，未完成文件保留 `.parallel.part` 和 `.parallel.state.json`。

最后一次运行中检查确认恰好有 4 个 worker，没有重复写入。当时进度：

```text
LibriSpeech train-clean-100   35.23%
LibriSpeech train-clean-360    1.98%
LibriTTS train-clean-100       5.70%
LibriTTS train-other-500       1.05%
```

服务器侧合计速度约 2 MB/s，全量语料预计仍需约 18-22 小时。过程可断点续跑；
已完成 tar 会先通过官方 MD5 才改成正式文件名。

## 4. `a094f4d5`

个人存储快照在下载前约为 188/200 GB，因此只建立评测工作集，没有放入
82 GB 全量 OpenSLR 语料。`df` 显示的是共享卷总量，不能单独作为个人配额
依据。

已完成服务器侧下载：

```text
VPC release ZIP
HuBERT
W-NT
UTMOS22
WhiSQA + single-head checkpoint
UTMOS mirror
```

最终审计已验证：

```text
torchaudio 2.9.0+scnet-compat
SpeechBrain 0.5.16
W-NT SHA256 ad40a04a...b2d4
WhiSQA SHA256 2da43d59...6810
```

## 5. 重建包中转

主账号正式包：

```text
VPC2024_LibriSpeech_rebuilt_v1.tar.zst
size   803952062
SHA256 5c446fefe41e58fc749f5cc6e2931d858de2e58a73e4feb74c4a721ec7fad217
```

已通过本机中转，并在 `d3`、`d5` 各自复算 SHA256 与 `zstd -t`：

```text
d3: verified
d5: verified
```

## 6. 尚未完成

- `d3` 的四个全量语料下载仍在进行；
- `d4` 的 `train-other-500` 尚未全量解压；
- `d4` 的 Slurm 解压作业尚未提交；
- 论文 original/VPC 基线尚未开始，因此还不能声称复现了论文指标。
