# SCNet Primary Node Setup

更新日期：2026-11-02

主账号：`a094f4d4`  
模式：HPC 登录节点，零卡时  
正式远端项目：

```text
/public/home/a094f4d4/voice_projects/code/n019_official
/public/home/a094f4d4/voice_projects/data/n019_official
/public/home/a094f4d4/voice_projects/models/n019_official
/public/home/a094f4d4/voice_projects/logs/n019_official
/public/home/a094f4d4/voice_projects/runs/n019_official
```

## 1. 环境

激活脚本：

```text
/public/home/a094f4d4/voice_projects/code/n019_official/hpc/activate_n019_official.sh
```

已验证：

```text
Python 3.11.17
DTK 26.04
torch 2.9.0
HIP 6.3.26093
torchaudio 2.9.0+scnet-compat
Transformers 4.46.3
SpeechBrain 0.5.16
FFmpeg 7.0.2
```

登录节点 `torch.cuda.is_available()` 为 `False` 属于正常现象。

## 2. 官方资产

以下资源已完成下载和校验：

```text
VPC2024 tag v2
commit 7c80e86d3a4d58b81a2f3bdc01a3508c37018be4

data.zip SHA256
60c71b3f2f8ff8d7a35237cda7d92fb2f6f5f1f2cb5c89cb91fc511a699860f7

asv_orig.zip SHA256
f0abf60e569cb60a6f945a1a0a48e1a7d1aabe973f956dc3a872a3e686a7bf5e

asr.zip
752987942 bytes
SHA256 28e9a67cb7319fedc61080f2d56e9bdf00f653d7ec665fc07c0db40ae66de106
```

模型：

```text
HuBERT
377569754 bytes
SHA256 062249fffb353eab67547a2fbc129f7c31a2f459faf641b19e8fb007cc5c48ad

W-NT
1266588504 bytes
SHA256 ad40a04ae6f0b46dbe6c7a6db71ff46f99775c59a0dccf61eb91f29216fbb2d4
```

MOS：

```text
WhiSQA single head
364031990 bytes
SHA256 2da43d59294c358bdd3f450d0aef5ce57ad20bed3beb34657ef3a795a4766810

UTMOS demo mirror
mosmodels/utmos
revision 65956d677bd502519c30c0f4bfda97a749d63009
```

UTMOS 镜像模型卡明确说明其文件来自 `sarulab-speech/UTMOS-demo`。
作者论文没有公开 UTMOS snapshot，因此最终报告中必须保留此来源说明。

## 3. 训练语料

已下载并通过官方 MD5：

```text
LibriSpeech train-clean-100
MD5 2a93770f6d5c6c964bc36631d331a522

LibriSpeech train-clean-360
23049477885 bytes
MD5 c0e676e450a7ff2f54aeade5171606fa

LibriTTS train-clean-100
MD5 4a8c202b78fe1bc0c47916a98f3a2ea8

LibriTTS train-other-500
44565031479 bytes
MD5 7b181dd5ace343a5f38427999684aa6f
```

已完整解压：

```text
LibriSpeech train-clean-100
28,539 FLAC

LibriSpeech train-clean-360
104,014 FLAC

LibriTTS train-clean-100
33,236 WAV
```

`LibriTTS train-other-500` 官方 tar 已完整且校验通过，但未完成全量解压。
登录节点在写入大量小文件时，多次在约一分钟后终止后台解压任务；该问题
不影响 tar 的完整性，也不影响当前 VPC 评测集重建。后续训练前应在计算任务
中解压，或改为从 tar 流式生成目标说话人 embedding。

## 4. 官方评测集重建

唯一正式重建制品：

```text
/public/home/a094f4d4/voice_projects/data/n019_official/rebuilt/VPC2024_LibriSpeech_rebuilt_v1.tar.zst
```

校验：

```text
size   803952062
SHA256 5c446fefe41e58fc749f5cc6e2931d858de2e58a73e4feb74c4a721ec7fad217
```

重建内容：

```text
test WAV                 1,934
dev WAV                  2,321
总计                     4,255
格式                     16000 Hz / mono / PCM16
trial pairs              21,650
female trials            11,744
male trials              9,906
```

已完成：

- 每条 WAV 的来源 FLAC 路径记录；
- 每条源 FLAC 和目标 WAV 的 SHA256；
- 目标 WAV 与官方 `utt2dur` 的时长一致性检查；
- 包内 `SHA256SUMS` 的完整展开复验；
- VPC Kaldi 清单行数复核。

## 5. 软件验收

```text
CPU probe: PASS
HuBERT layer 6 输出 [1, 331, 768]
W-NT 输出 [1, 250]，L2 norm = 1.0
unit tests: 7/7 PASS
VPC run_evaluation.py --help: PASS
```

验收文件位于：

```text
/public/home/a094f4d4/voice_projects/code/n019_official/audit/
```

其中 `PRIMARY_SETUP_STATUS` 是当前机器可读状态。

## 6. 后续账号转移

已从 `a094f4d3` 和 `a094f4d5` 测试读取主账号的正式数据包，结果均为
`Permission denied`。因此其他账号不能直接从 `/public/home/a094f4d4`
读取该数据。后续转移必须使用：

- 本机 Windows 中转到目标账号；或
- 平台提供的双方可访问共享目录。

目标账号只需解压并校验同一个数据包，不得重新执行 FFmpeg 或重新按 ID
筛选音频。

## 7. 尚未执行

- 未提交 Slurm 或人工智能训练任务，卡时为 0。
- 未运行 original 语音基线，因此尚未进行论文指标对比。
- UTMOS22 的运行依赖（尤其 fairseq）未装入 N019 的 DTK 环境，避免破坏
  已验证的 torch；真正运行 MOS 前应建立独立环境或容器。
