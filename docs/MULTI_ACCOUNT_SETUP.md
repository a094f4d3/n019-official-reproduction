# N019 五账号配置与资产流

更新日期：2026-11-02

这份文档固定主账号验证通过后的迁移流程。目标是让三个账号各自具备可追溯的
代码、环境和公开资产，同时避免把大文件反复经过本机。

## 1. 分工

| 账号 | 定位 | 公开大语料 | 评测重建包 | 用途 |
|---|---|---:|---:|---|
| `a094f4d4` | 主账号 | 已下载 | 已生成 | 主训练、主评测、最终解压 |
| `a094f4d3` | 第二训练账号 | 各账号自行下载 | 本机中转 | 第二训练或对照实验 |
| `a094f4d5` | 备用账号 | 按剩余空间裁剪 | 本机中转 | 短任务；不挤占主数据和训练结果 |
| `a094f4d6` | 新增备用算力 | 待按需下载 | 待中转 | r24 环境 ready；audit 与 `104 tests OK` 通过 |
| `a094f4d7` | 新增备用算力 | 待按需下载 | 待中转 | r24 环境 ready；audit 与 `104 tests OK` 通过 |

`a094f4d5` 的历史快照仅约 12 GB 可用。除非实时 `df`/控制台确认空间足够，
否则只下载 VPC、HuBERT、W-NT、MOS 和重建包，不下载 82 GB OpenSLR 全量
压缩包。`a094f4d6` / `a094f4d7` 的浏览器持久化会话、E-Shell SSH key、
`py311` 迁移、`conda-unpack`、venv 和 audit 已完成。d6/d7 同步 r24
后均通过 `104 tests OK`。正式下载语料或提交卡时任务前仍需按角色检查
实时空间和余额。

## 2. 数据边界

可以直接在各账号服务器下载：

- VPC2024 `v2` 代码和 release 文件；
- OpenSLR 的 LibriSpeech/LibriTTS 压缩包；
- Hugging Face 的 HuBERT、W-NT checkpoint；
- UTMOS22、WhiSQA 代码和 checkpoint。

必须走本机中转：

- 主账号生成且经过校验的
  `VPC2024_LibriSpeech_rebuilt_v1.tar.zst`；
- 主账号验证过的 `torchaudio 2.9.0+scnet-compat` 包；
- 兼容包固定保存在
  `artifacts/torchaudio_scnet_compat.tar.gz`，并附 `SHA256SUMS.txt`；
- 项目自己的脚本、配置和不大的审计文件。

不得把受控 VPC SFTP 音频或凭据提交到仓库，也不得用本地实验产物代替官方
公开下载。

## 3. 新账号环境

目标环境不是重新安装 `torch`。流程使用：

```text
base: ~/voice_projects/miniconda3/envs/py311
venv: ~/voice_projects/envs/n019
```

`venv` 带 `--system-site-packages`，继承 DTK 已验证的 `torch`，再用
`--no-deps` 补 SpeechBrain、HyperPyYAML 和 kaldiio。若 `py311` 中没有
`torchaudio`，只安装主账号导出的兼容包，不从公网 PyPI 覆盖 PyTorch。

激活脚本：

```text
~/voice_projects/code/n019_official/hpc/activate_n019_official.sh
```

## 4. 执行顺序

每个账号只建立一个项目：

```text
~/voice_projects/code/n019_official
~/voice_projects/data/n019_official
~/voice_projects/models/n019_official
~/voice_projects/logs/n019_official
~/voice_projects/runs/n019_official
```

步骤：

1. 上传 `configs/`、`docs/`、`scripts/` 和 `README.md`。
2. 运行 `scripts/multi_account/provision_account_remote.sh`。
3. 若缺少 `torchaudio`，先放入主账号导出的兼容包，再重跑环境检查。
4. 运行 `audit_account_remote.sh`，确认 Python、DTK、存储和导入状态。
5. 按角色运行 `download_public_assets_remote.sh`：
   - `N019_ASSET_MODE=full`：公开大语料和全部小资产；
   - `N019_ASSET_MODE=eval`：只下载评测/模型小资产。
6. 校验所有 MD5、SHA256 和 `unzip -t`。
7. 将主账号重建包经本机分别上传到其他账号，并逐账号复算 SHA256。

## 5. `a094f4d4` 解压任务

解压任务只做三件事：

- 校验并解压 VPC ZIP；
- 校验并解压 804 MB 评测重建包；
- 校验并完整解压 LibriTTS `train-other-500`，保留旧 partial 目录。

任务不训练、不评测、不修改论文结果。`train-other-500` 必须在计算节点解压，
不能回到登录节点反复创建十几万小文件。

提交前仍需独立打印资源计划并获得确认。当前脚本默认：

```text
partition: hx1hdnormal
DCU: 1
CPU: 16
RAM: 32G
wall time: 01:30:00
worst case: 1.5 DCU-hours
scope: extraction and integrity checks only
```

## 6. 验收

新账号至少满足：

```text
torch 2.9.0 can import
DTK 26.04 can load
torchaudio version recorded
SpeechBrain 0.5.16 can import
HuBERT snapshot commit recorded
W-NT size 1266588504 and SHA256 match
rebuilt package SHA256 match
VPC Kaldi list counts match
```

`a094f4d3` 的完整语料只能在空间预算内下载；`a094f4d5` 不得因下载语料而
删除旧项目。任何清理都必须先列清单并获得用户确认。
