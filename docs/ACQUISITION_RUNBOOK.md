# Official Data Acquisition Runbook

更新日期：2026-11-02

本文件只准备官方文件和数据的获取。尚未绑定新的 SCNet 账号。

## 1. 本地固定官方代码

```bash
git clone \
  --branch v2 \
  --depth 1 \
  https://github.com/Voice-Privacy-Challenge/Voice-Privacy-Challenge-2024.git

git -C Voice-Privacy-Challenge-2024 rev-parse HEAD
```

期望：

```text
7c80e86d3a4d58b81a2f3bdc01a3508c37018be4
```

## 2. 下载公开 VPC 清单

```bash
wget \
  https://github.com/Voice-Privacy-Challenge/Voice-Privacy-Challenge-2024/releases/download/data.zip/data.zip
```

校验：

```bash
printf '%s  %s\n' \
  60C71B3F2F8FF8D7A35237CDA7D92FB2F6F5F1F2CB5C89CB91FC511A699860F7 \
  data.zip \
  | sha256sum -c -
```

解压：

```bash
unzip data.zip
```

## 3. 注册并获取受控 LibriSpeech 包

1. 用户本人打开 `https://forms.office.com/r/T2ZHD1p3UD` 完成注册。
2. 等待 organisers 返回 SFTP 密码。
3. 在交互式 shell 中下载，不把密码写入历史文件或脚本。

```bash
sftp -oStrictHostKeyChecking=no getdata@voiceprivacychallenge.univ-avignon.fr
```

进入 SFTP 后：

```text
cd /challengedata/corpora
get libri_dev.tar.gz
get libri_test.tar.gz
bye
```

如果已安装 `sshpass`，也可以交互输入环境变量后执行；执行结束立即
`unset`。不要将密码写进命令行参数或脚本。

## 4. 下载 OpenSLR 语料

在远端登录节点执行：

```bash
wget https://www.openslr.org/resources/12/train-clean-100.tar.gz
wget https://www.openslr.org/resources/12/train-clean-360.tar.gz
wget https://www.openslr.org/resources/60/train-clean-100.tar.gz
wget https://www.openslr.org/resources/60/train-other-500.tar.gz
```

注意两个 `train-clean-100.tar.gz` 同名，必须分目录保存。

校验：

```bash
md5sum train-clean-100.tar.gz
md5sum train-clean-360.tar.gz
md5sum train-clean-100.tar.gz
md5sum train-other-500.tar.gz
```

期望值见 `OFFICIAL_ASSET_MANIFEST.md`。

## 5. 下载官方评测模型

```bash
wget \
  https://github.com/Voice-Privacy-Challenge/Voice-Privacy-Challenge-2024/releases/download/pre_model.zip/asv_orig.zip

wget \
  https://github.com/Voice-Privacy-Challenge/Voice-Privacy-Challenge-2024/releases/download/pre_model.zip/asr.zip
```

校验和测试压缩包：

```bash
sha256sum asv_orig.zip asr.zip
unzip -t asv_orig.zip
unzip -t asr.zip
```

## 6. 下载 HuBERT 与 W-NT

建议在可联网的登录节点预下载，然后compute节点只读本地缓存：

```bash
export HF_ENDPOINT=https://hf-mirror.com
export HF_HOME="$HOME/voice_projects/models/n019_official/hf"

huggingface-cli download facebook/hubert-base-ls960 \
  --revision dba3bb02fda4248b6e082697eee756de8fe8aa8a \
  --local-dir "$HOME/voice_projects/models/n019_official/hubert"

huggingface-cli download Orange/Speaker-wavLM-pro \
  --revision 8451deb7b5019b9a99b1ed6a528dc75ba6b62b08 \
  --local-dir "$HOME/voice_projects/models/n019_official/speaker_wavlm_pro"
```

W-NT 权重必须满足：

```text
model.safetensors size = 1266588504
SHA256 = ad40a04ae6f0b46dbe6c7a6db71ff46f99775c59a0dccf61eb91f29216fbb2d4
```

## 7. SCNet 上传策略

新账号确定后：

1. 先在登录节点检查 `$HOME`、配额和已有环境。
2. 在本地打包固定 v2 仓库和 `data.zip`。
3. 用 `scp` / `sftp` 上传，不依赖 compute 节点联网。
4. 上传后逐项校验大小、SHA256、MD5 和 Kaldi 行数。
5. 不覆盖旧项目 `n019_repro` 的环境、数据或 checkpoint。

## 8. MOS 工具

```bash
git clone https://github.com/sarulab-speech/UTMOS22.git
git -C UTMOS22 checkout 2d6d612cdf5bc610fde1a1b913c2d6c6fac8e063

git clone https://github.com/leto19/WhiSQA.git
git -C WhiSQA checkout 0ad007e97093aa54c0c8cdac1af3e6ad6305af3f
git -C WhiSQA lfs pull --include="checkpoints/single_head_model.pt"
```

WhiSQA 单头 checkpoint 校验：

```text
size = 364031990
SHA256 = 2da43d59294c358bdd3f450d0aef5ce57ad20bed3beb34657ef3a795a4766810
```

UTMOS demo/strong learner 必须记录实际 snapshot revision。论文没有给出该
revision，因此最终报告中要明确写为“官方 UTMOS22 代码 + 下载时固定的
snapshot”，不能声称作者使用了同一 snapshot。

## 9. 数据验收门槛

只有以下条件全部满足，才允许开始匿名化和正式评测：

```text
VPC repo HEAD = 7c80e86d3a4d58b81a2f3bdc01a3508c37018be4
data.zip SHA256 correct
libri_test_enrolls wav.scp = 438 lines
libri_test_trials_f wav.scp = 734 lines, trials = 11744 lines
libri_test_trials_m wav.scp = 762 lines, trials = 9906 lines
all libri_test wav paths resolve
asv_orig.zip and asr.zip unzip -t pass
LibriSpeech/LibriTTS MD5 pass
W-NT weight size and SHA256 pass
HuBERT model snapshot recorded by commit
```

任何一项不满足，停止，不开始正式评测。
