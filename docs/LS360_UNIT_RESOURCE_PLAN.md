# LS360 Unit Extraction Resource Plan

更新日期：2026-11-03

此任务只提取官方 LibriSpeech train-clean-360 的 HuBERT units，为
semi-informed S attack 准备匿名化训练数据；不训练 duration predictor 或
vocoder，不进行 Table 1 评测。

```text
账号：a094f4d4
模式：人工智能/模型训练
任务名：n019_ls360_units
资源组：hx1hgbwnormal
节点数：1
DCU 数：1
CPU：16
host RAM：40 GB
墙钟上限：06:00:00
最坏卡时：6.0 DCU-hours
预计卡时：2.5-4.5 DCU-hours
```

输入：

```text
data/n019_official/processed/manifests/librispeech_train_clean_360.jsonl
data/n019_official/processed/units/librispeech_train_clean_100/kmeans_k200_seed20261102.npz
models/n019_official/hubert/
```

输出：

```text
data/n019_official/processed/units/librispeech_train_clean_360/
  unit_records.partial.jsonl
  unit_records.jsonl
  units_metadata.json
  verification.json
  codes/
```

启动入口：

```text
scripts/extract_ls360_units_remote.sh
hpc/n019_ls360_units.slurm（仅作相同命令的 Slurm 模板）
```

通过条件：

- `104,014` 条唯一 utterance；
- `921` 个 speaker；
- record ID 与官方 VPC `train-clean-360/wav.scp` 完全一致；
- 每条 code 文件存在、帧数一致、label 在 `[0, 199]`；
- codebook SHA256 为
  `a5cc08f707301a1c05da4ab4b00cd280dec66533796a976c3ac4743287eaf446`；
- `verification.json` 生成且无缺失文件或 shape/value mismatch。

停止条件：

- HuBERT/DCU 初始化失败；
- 任何非有限 forward 结果；
- 连续 10 分钟没有新的 `extracted=` 进度；
- 个人存储不足；
- 达到 6 小时墙钟；
- manifest 与 VPC ID 集合不一致。

中断后使用 `scripts/extract_ls360_units_remote.sh` 重跑。脚本发现
`unit_records.partial.jsonl` 后会自动加 `--resume`；已完成且 code 文件存在
的 utterance 不再经过 HuBERT。不得在没有 partial 记录的另一个输出目录中
拼接前一次结果。

当前状态：`READY_ON_A094F4D5`。2026-11-03 13:42 实时模型训练余额为
`24.9066666666` 卡时。启动脚本新增默认 21,600 秒硬超时，中断后使用
同一命令从 `unit_records.partial.jsonl` 续跑。HPC 估算余额仅剩约
`0.973` 卡时，不足以承担本任务，禁止提交到 `hx1hdnormal`。
