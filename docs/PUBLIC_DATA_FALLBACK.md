# Public Data Fallback

更新日期：2026-11-02

## 结论

目前没有找到可信的 GitHub、Hugging Face、Zenodo 或 Internet Archive
镜像，直接提供 VPC2024 的原始 `libri_dev.tar.gz` / `libri_test.tar.gz`。
官方 GitHub release 的 `data.zip` 只有 Kaldi 清单、文本和 trial list，没有
评测音频。

但是，VPC2024 Evaluation Plan v2.0 明确写明：LibriSpeech development 和
evaluation sets 是 LibriSpeech `dev-clean` / `test-clean` 的子集，并沿用前几届
VoicePrivacy Challenge 的 protocol。因此不需要把整个 `test-clean` 当作 VPC
数据集，也不必依赖注册 SFTP 才能获得相同源音频：

```text
VPC libri_dev  = LibriSpeech dev-clean  的官方指定 utterance 子集
VPC libri_test = LibriSpeech test-clean 的官方指定 utterance 子集
```

`data.zip` 已经给出精确的 `wav.scp`、`utt2spk`、`spk2gender`、`text` 和
`trials`。所以可以用公开 LibriSpeech 音频按 utterance ID 重建 VPC 所需的
目录，trial 关系不会改变。

## 公开音频来源

OpenSLR 官方文件仍在线：

| 文件 | 大小（bytes） | MD5 |
|---|---:|---|
| `https://www.openslr.org/resources/12/dev-clean.tar.gz` | 337,926,286 | `42e2234ba48799c1f50f24a7926300a1` |
| `https://www.openslr.org/resources/12/test-clean.tar.gz` | 346,663,984 | `32fa31d27d2e1cad72775fee3f4849a9` |

Hugging Face 还有 `openslr/librispeech_asr` 的 Parquet 镜像：

```text
dataset: openslr/librispeech_asr
revision: 71cacbfb7e2354c4226d01e70d77d5fca3d04ba1
clean/validation: 2,703 utterances
clean/test: 2,620 utterances
```

优先使用 OpenSLR 原始 tar 包。Hugging Face 镜像适合只想抽取少量 utterance
的场景，但其 Parquet 中音频容器是 FLAC，不能把 Parquet 文件本身当成
VPC 的 WAV 目录。

## 与 VPC data.zip 的对应关系

当前 `data.zip` 的 test 清单统计：

| split | 唯一 wav IDs |
|---|---:|
| `libri_test_enrolls` | 438 |
| `libri_test_trials_f` | 734 |
| `libri_test_trials_m` | 762 |
| 三者去重后 | 1,934 |

这些 ID 全部采用 LibriSpeech 的
`speaker-chapter-utterance` 格式，例如：

```text
121-123852-0000
1089-134686-0002
```

重建时必须在 `test-clean/SPEAKER/CHAPTER/UTT.flac` 找到对应文件，再将
`wav.scp` 保留为原始 VPC 路径，并生成：

```text
data/libri_test/wav/UTT.wav
data/libri_dev/wav/UTT/UTT.wav
```

`libri_dev` 使用 `dev-clean`，`libri_test` 使用 `test-clean`。不能把
`test-clean` 全量内容无筛选地送进评测。

## 验证要求

在把该重建数据用于 N019 Table 1 之前，必须完成以下检查：

1. `data.zip` SHA256 与官方值一致。
2. 两个 LibriSpeech tar 包的 MD5 与 OpenSLR `md5sum.txt` 一致。
3. `libri_test` 的 438 / 734 / 762 行数不变，全部 1,934 个唯一 ID
   都能在 `test-clean` 找到。
4. 解出的 WAV 与 `utt2dur` 的时长误差在容器/解码误差范围内。
5. 使用官方 `asv_orig` 对重建的 original `libri_test` 跑一次 evaluator，
   核对 female/male EER 和 WER 的量级与 trial 数。
6. 记录每个重建 WAV 的 SHA256、解码命令、LibriSpeech tar 的 MD5 和
   `data.zip` SHA256。

在完成第 5 步前，只能写“按官方 protocol 从公开 LibriSpeech 重建”，不能
写“与组织者 tar 包逐字节相同”。如果第 5 步复现出官方基线数值，可以把
数据层面的一致性标为已验证；仍然不能把作者未公开的模型内部超参数称作
完全一致。

## 不能替代的东西

- 不能用 VPC2020 或 VPC2022 的 trials 代替 VPC2024 trials。
- 不能只拿 `test-clean` 全量数据直接跑 VPC evaluator。
- 不能用 `LibriTTS-R` 代替论文使用的原始 LibriTTS。
- 不能用来源不明的网盘、种子或未授权镜像。

