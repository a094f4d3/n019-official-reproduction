# Pilot End-to-End Resource Plan

更新日期：2026-11-03

此任务使用已经过链路验收的 2,000-step vocoder pilot，只用于验证完整
`DU-pred-nt` 官方评测链路和得到可诊断的中间指标。结果不得写入
N019 Table 1，也不得称为论文复现。

```text
账号：a094f4d4
模式：HPC / Slurm
任务名：n019_pilot_e2e
partition：hx1hdnormal
节点数：1
DCU 数：1
CPU：12
host RAM：40 GB
墙钟上限：00:25:00
最坏卡时：0.4167 DCU-hours
预计卡时：0.20-0.30 DCU-hours
```

输入：

```text
runs/n019_official/vocoder_nt_pilot_1020953/last.pt
runs/n019_official/duration_pred_main/best.pt
processed/manifests/libri_test.jsonl
processed/units/libri_test/unit_records.jsonl
processed/targets/target_map.jsonl
processed/embeddings/libri_test_target_nt_utterance/nt_utterance_embeddings.npz
```

输出：

```text
runs/n019_official/pilot_e2e/
  anonymised/DU-pred-nt/
  evpc/
  eval/wnt/
  pilot_metrics_summary.json
```

工作：

1. 对官方 `libri_test` 1,934 句生成 DU-pred-nt WAV；
2. 导出 VPC `libri_test*_n019_pilot`；
3. 运行官方 E-VPC pre 评测（OO/OA/AA）和官方 WER；
4. 运行 W-NT I/L；
5. 汇总中间指标。

停止条件：

- 25 分钟墙钟；
- 非有限 duration/vocoder 输出；
- WAV 数不是 1,934；
- 官方 ASV/ASR/W-NT 依赖或路径失败；
- 个人存储不足。

预算：HPC 估算已用 `49.027` 卡时，按 50 卡时估算剩余 `0.973`；
本计划最坏 `0.4167`，仍有约 `0.556` 卡时裕量。

当前状态：`COMPLETED`，Slurm JobID `1021278`（2026-11-03），
ExitCode `0:0`，实际墙钟 `10m50s`，实际卡时 `0.1806`。
不得用本结果替代主 vocoder 400k-step 的正式 Table 1 结果。
