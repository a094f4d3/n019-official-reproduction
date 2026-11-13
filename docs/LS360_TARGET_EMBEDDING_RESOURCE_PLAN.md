# LS360 Target Embedding Resource Plan

更新日期：2026-11-03

## 0. 当前完成状态（2026-11-04）

LS360 NT target embedding 四片已经完成 canonical 合并，正式输入门禁已通过：

- `81,605` 条、`250` 维、全部 finite；
- L2 norm 范围 `0.9999998808–1.0000001192`；
- merged NPZ SHA256
  `274dd8012a59ff02a7bcc11921b1be2b731b2c4fcba50603428c7d5c2a047f1a`；
- target map SHA256
  `c9a182adfc4076087dc5144a85694b5900270a4fefee6b38459d720da228ee75`；
- 104,014 个 source ID、unit ID、target-map source ID 和 VPC
  `train-clean-360/wav.scp` ID 在 d6/d7 均已验证一致。

本文件以下的 pilot 和分片计划保留为历史资源记录；不要重新提取或重跑
已完成的四片 embedding。

本任务只提取 semi-informed S attack 匿名化完整 LS360 时实际引用的
LibriTTS train-other-500 目标说话人 embedding；不训练模型，不评测
Table 1。

## 1. 为什么需要重做

论文要求目标 embedding 从完整的 LibriTTS train-other-500 随机抽取。
旧 LS360 target map 使用了 `mode=speaker`，且抽样池只有 `libri_test`
已经用过的 1,924 个 target utterance。这会把 S 训练目标池错误缩小，
不能作为正式结果。

正式流程固定为：

```text
205,044 句完整 train-other-500 manifest
-> mode=utterance, seed=20261102
-> 104,014 条 LS360 source 映射
-> 选出实际引用的 target utterance
-> W-PRO 250-D utterance embedding
```

当前正式 target subset 共 `81,605` 句、`1,158` 人、`123.8027` 小时，
平均 `5.4615 s/句`，最长 `39.76 s`；W-PRO 还会按模型卡默认截断到
前 320,000 samples。这个统计用于 pilot 后估算主任务卡时。

## 2. 阶段 A：吞吐 pilot

```text
账号：a094f4d4
模式：人工智能/模型训练
资源组：hx1hgbwnormal
DCU：1
CPU：16
host RAM：40 GB
墙钟上限：00:15:00
最坏卡时：0.25
样本：target subset 前 256 句
输出：单独的 pilot 目录，不进入正式 embedding
停止：15 分钟、非有限 embedding、10 分钟无进度、DCU/存储错误
```

通过条件：

- 实际完成一句 embedding 并记录模型 SHA256；
- 根据完整样本数和音频时长估算主任务卡时；
- 若预计超过 6 小时，主任务必须分片并启用
  `partial_embeddings.npz` 续跑。

当前准备提交的 256 句 Slurm pilot：

```text
账号：a094f4d4
模式：HPC / Slurm
partition：hx1hdnormal
DCU：1
CPU：16
host RAM：40 GB
墙钟：00:10:00
最坏：0.1667 卡时
预计：0.05-0.12 卡时
```

输出单独放在
`runs/n019_official/ls360_target_embedding_pilot_<JobID>/`，不得与正式
embedding 目录混用。

## 3. 阶段 B：正式 embedding

```text
账号：a094f4d4
模式：人工智能/模型训练
资源组：hx1hgbwnormal
DCU：1（若 pilot 证明多 DCU I/O 切分正确，再单独申请 DDP/分片）
CPU：16
host RAM：40 GB
每分片墙钟上限：06:00:00
每分片最坏卡时：6.0
预计总卡时：由阶段 A 实测决定
```

输入：

```text
processed/targets/librispeech_train_clean_360_target_manifest.jsonl
models/n019_official/wpro/
corpora/libritts/LibriTTS/train-other-500/
```

输出：

```text
processed/embeddings/librispeech_train_clean_360_target_nt_utterance/
  partial_embeddings.npz
  nt_utterance_embeddings.npz
  nt_utterance_manifest.jsonl
  metadata.json
```

通过条件：

- embedding 数量等于 target subset 行数；
- 每个 target ID 都有条目；
- 全部为 250 维、有限值、L2 norm 约等于 1；
- model、manifest、npz 的 SHA256 写入 metadata。

停止条件：10 分钟无进度、非有限值、存储不足、达到墙钟。中断后运行
`scripts/extract_ls360_target_embeddings_remote.sh` 自动续跑。

## 4. 实测吞吐与正式分片

256 句 AI pilot（任务 `2117442203569016834`）已完成：

```text
rows: 256
elapsed including model load: 638.0 s
throughput: 0.4012539185 utterances/s
projection for 81605: 203374.9609 s = 56.4930 card-hours
embedding dimension: 250
norm range: 0.99999988-1.00000012
embeddings SHA256:
f271a655aab72b4fe8f539abd0133be0afd0280d82eaa3f41638279219abeced
```

AI 容器以 `root` 启动，`HOME=/root`，但
`/public/home/<account>` 正常挂载。根目录现在从脚本自身
`BASH_SOURCE` 推导，不再依赖 `id -un`。

正式提取拆成四份确定性、互斥、并集完全一致的 shard，每份约
`20401–20402` 句：

```text
账号：a094f4d4 shard 0/1；a094f4d3 shard 2/3
模式：人工智能/模型训练
资源组：113 组 / hx1hgbwnormal / BW
DCU：每个任务 1
CPU/RAM：15 CPU / 59 GB
墙钟：每个任务最多 18 小时
最坏：4 × 18 = 72 卡时；预计：总计约 56.5 卡时
```

d4 的 shard 0/1 已提交并运行；d3 的 shard 2/3 等本机
`train-other-500` SSH 解压完成后提交。合并前强制检查 81,605 个
ID、250 维、有限值和 L2 norm。合并后的 manifest 与 NPZ key 顺序必须
严格按 d4 的 canonical target source manifest 重建，不能按 shard
manifest 顺序拼接；否则 d3 改写后的绝对音频路径会混入共享输出。

正式合并命令必须同时锁定行数与源哈希：

```bash
python scripts/merge_target_embedding_shards.py \
  --shard-dir .../shard_000 \
  --shard-dir .../shard_001 \
  --shard-dir .../shard_002 \
  --shard-dir .../shard_003 \
  --manifest .../librispeech_train_clean_360_target_manifest.jsonl \
  --expected-rows 81605 \
  --expected-manifest-sha256 \
    f6986086fbf79e0555629ad31fe7acb5893b90db03cef44f60b27fa9e5cea76b \
  --out .../librispeech_train_clean_360_target_nt_utterance
```
