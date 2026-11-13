# Unit HiFi-GAN 收敛、Checkpoint 与跨账号续训

更新日期：2026-11-03

## 0. 当前正式结果（2026-11-04）

NT Unit HiFi-GAN 主训练已经收敛，不再需要跨账号续训：

- d3 continuation Job `2117804993484845057` 于 2026-11-04 13:09:40
  正常停止；
- 最后训练 step `106,000`，`validations_without_improvement=15`；
- 正式推理 checkpoint 固定为 `best.pt`：step `76,000`，validation
  mel L1 `0.7805652022361755`；
- final `best.pt` 为 `56,851,575` bytes，SHA256
  `32f8cbf064b48e1cedb2541c72b34916570e8d3a1da66c39de0ca04a2cfc1477`；
- 该文件已到 d5/d6/d7，三份 SHA256 一致，d5/d6/d7 均可实际加载。

本节以下的跨账号续训流程保留为故障恢复手册；当前正式流程不应再次启动
主 vocoder 训练或替换 `best.pt`。

## 1. 训练停止规则

主训练仍保留论文引用的 400,000-step 硬上限，但不再无条件跑满。

默认判据：

```text
验证间隔：2,000 steps
最少训练：20,000 steps
最小改善：validation mel L1 绝对下降 0.001
耐心：连续 15 次验证没有达到最小改善
```

满足耐心条件后写 `stop_reason=converged`，保存 `last.pt` 和
`training_log.jsonl` 中的 `event=converged`，然后正常退出。最大
400,000 steps 只作为安全上限，不是论文报告的设置。

默认验证集仍是训练记录中固定的 64 条监控样本。论文没有规定 vocoder
early stopping 协议，因此这是实现假设。可通过
`N019_VOCODER_VALIDATION_RECORDS` 和
`N019_VOCODER_VALIDATION_EMBEDDINGS` 换成显式的 speaker-disjoint
验证集。

## 2. Checkpoint 内容与体积

已用当前完整 Unit HiFi-GAN 配置在本机做实际 `torch.save` 往返测量：

| 组件 | 参数量 | FP32 参数体积 |
|---|---:|---:|
| Generator | 14,179,970 | 54.09 MiB |
| Multi-Period Discriminator | 41,105,770 | 156.81 MiB |
| Multi-Scale Discriminator | 29,618,821 | 112.99 MiB |
| 合计 | 84,904,561 | 323.89 MiB |

AdamW 训练一步后，每个可训练参数还保存两组 moments，因此完整
`last.pt` 实测为：

```text
1,019,490,959 bytes = 972.26 MiB = 1.0195 GB
```

这与现有远端 2,000-step pilot 的 `last.pt` 文件 `973 MiB` 一致。

文件用途：

- `last.pt`：generator、MPD、MSD、两个 optimizer、两个 scheduler、
  step、收敛计数和 `stop_reason`，约 1.02 GB；跨账号续训必须传它。
- `best.pt`：仅 generator 和推理所需配置，约 54 MiB；用于最终评测。
- `duration_*_main/best.pt`：约 4.1 MiB。

每 50,000 steps 另保留一个完整 checkpoint，约 1 GB。长时间训练的
磁盘预算至少按：

```text
last.pt 1 GB
+ best.pt 0.06 GB
+ 每 50k 一个 1 GB 归档
+ 至少 2 GB 临时写入余量
```

规划，建议至少预留 12–15 GB。

## 3. 换账号流程

训练前设置本窗口墙钟，例如：

```bash
N019_VOCODER_MAX_HOURS=8
```

达到窗口上限时训练器保存 `last.pt` 并写
`stop_reason=max_hours`。源账号任务完全停止后，在小中转机执行：

```powershell
python scripts/transfer_vocoder_run.py `
  --source-host scnet-a094f4d4 `
  --target-host scnet-a094f4d3 `
  --run-name vocoder_nt_main `
  --chunk-mib 64 `
  --retries 8 `
  --keep-local
```

脚本会：

1. 将 `last.pt`、`best.pt`、`meta.json`、`training_log.jsonl` 和
   `launch.txt` 打包；
2. 按 64 MiB 分块，通过本机逐块中转；
3. 对每个源块、下载块、目标块和最终文件分别校验 SHA256；
4. 在目标账号同名的
   `runs/n019_official/<run-name>` 下原子解包；
5. 目标已有 `last.pt` 时默认拒绝执行，除非显式传 `--overwrite`。

传输约 1.02 GB，峰值本地临时空间约 2.1 GB；脚本成功后默认删除临时
中转目录，`--keep-local` 用于保留审计副本。

## 4. 目标账号续训

使用同名 launcher：

```bash
N019_VOCODER_MAX_HOURS=8 \
  bash scripts/launch_vocoder_nt_main_ai.sh
```

或 ECAPA：

```bash
N019_VOCODER_MAX_HOURS=8 \
  bash scripts/launch_vocoder_ecapa_main_ai.sh
```

`last.pt` 中的 `step`、optimizer、scheduler、best metric 和 patience
都会恢复。世界大小可以变化；当前 DDP 约束仍保持全局 effective batch
为 32，因此 2 DCU 时每 rank 为 16。

若 `last.pt` 已记录 `stop_reason=converged`，再次启动会输出
`already_converged` 并立即退出，避免无意义重复训练。只有显式设置
`N019_VOCODER_RESUME_CONVERGED=1` 才允许继续。
