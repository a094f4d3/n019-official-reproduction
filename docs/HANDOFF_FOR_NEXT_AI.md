# N019 官方复现：下游 AI 完整交接文档

更新日期：2026-11-12  
论文：*Joint Timbral and Non-Timbral Speaker Anonymisation*  
DOI：`10.21437/Odyssey.2026-16`

## 0.0.58 2026-11-13 03:36 E-VPC S 训练收敛机制对照完成

- 已完成的两项对照排除了 target pool completeness 和 checkpoint/soup
  作为主因：fullmean1160 把正式 S 从 `29.7425%` 提到 `31.200%`，
  但替换 `avg88_92` 后又降到 `29.6955%`。
- 同一作者的 SPSC 2025 论文明确记录：官方 VPC E-VPC S 训练在
  `lr=1e-2, 10 epochs` 下不能正确收敛；其后续系统改用
  `lr=1e-3, 20 epochs`。N019 未报告是否沿用该调整，因此不能把
  20 epoch 当作作者确认配置，必须保留为诊断。
- 已提交 d7 HPC Job `1103529`（`n019_fullmean_adj20_s`）：
  `hx1hdnormal`、1 DCU、16 CPU / 60 GB、3 h；预计 `2.8`、
  最坏 `3.0` 卡时。提交前按 50 h HPC 额度估算余额
  `3.117744 h`（`6.159444 - 3.0417`）。
- 输入完全复用已完成的 fullmean1160 104,014 WAV/VPC，不重新渲染。
  新旧配置逐行 diff 只有 `lr 0.01 -> 0.001` 和
  `epochs 10 -> 20`；batch 256、`num_workers=10`、ECAPA scratch、
  921 speakers、`spk-diverse-sess` 均未改。输出：
  `runs/n019_official/privacy/fullmean1160_du_pred_nt_s_20261112/s_eval_adj20_lr1e3`。
- 配置 SHA256 `ec69c22504d8d8eb6f3f57e2547b8b9ae0176c5a3c68d1c1de427781b115e859`；
  SLURM wrapper SHA256
  `7f58b322a9f04b202dfd528cf723bdae2297f85ccd1a6edd1dd13cfd5821b59c`。
  当前 `PENDING/Priority`。停止条件：写出完整 `s_metrics.json`；
  或训练/评分错误、非有限 loss、节点故障；或达到 3 h。
- 该结果只用于判断 E-VPC S 的训练收敛机制是否解释论文差距。
  EER 没有改善，因此不得把 20-epoch 结果混入正式论文表。
- Job `1103529` 已正常完成：
  `00:48:45-03:33:22`，墙钟 `02:44:37 = 2.7436` 卡时，
  `ExitCode=0:0`。20-epoch 最终训练 loss `7.98`、valid error
  `89.7%`（官方 10-epoch 为 train `9.10`、valid error `85.3%`）；
  但 E-VPC S 只有 female `29.929%`、male `32.071%`、
  mean **`31.000%`**，相对官方 10-epoch fullmean `31.200%`
  还低 `0.200 pp`。`s_metrics.json` SHA256
  `940017ed664ec67f586997d72c73491755e4d85e178513abcf02628ee59ab214`。
- 结论：S attacker 收敛程度不是论文差距来源。按 50 h HPC 估算，
  d7 剩余约 `0.3741 h`；d7 不再安排 3 h 级任务。正式最优结果仍为
  `E-VPC S 29.7425%` 的 soup2+shrink0.1；没有新的候选达到替换门槛。

## 0.0.57 2026-11-13 00:43 avg88_92 checkpoint 对照失败

- d7 HPC Job `1102767`（`n019_avg8892_fullmean_s`）正常完成：
  `21:37:06-00:39:36`，墙钟 `03:02:30 = 3.0417` 卡时，
  `ExitCode=0:0`。test 1,934 和 LS360 104,014 的 WAV/VPC
  均通过验证。
- 固定 fullmean1160/no-shrink、paper random full-pool target map、
  `duration=pred` 后，`avg88_92` 的 E-VPC S 为
  female `28.823%`、male `30.568%`、mean **`29.6955%`**。
  这比 soup2 fullmean 的 `31.200%` 低 `1.5045 pp`，比正式
  soup2 shrink0.1 的 `29.7425%` 低 `0.0470 pp`。
- 结论：较早、按正确 40-speaker dev 选出的 `avg88_92` 既没有
  恢复 S，也不是更好的隐私候选。soup/checkpoint 选择不是剩余
  S 差距的主因。`s_metrics.json` SHA256
  `7165b66520da6780922a53032c0f67c726feaf8572a0399db83144c54060917c`。
- 该 Job 不替换正式结果，也不再提交旧 `1102715`。剩余 HPC 估算
  约 `3.1177` h（按 50 h 额度；提交前 `6.1594`，本次用 `3.0417`）。

## 0.0.56 2026-11-12 21:25 source S 完成；提交 avg88_92 S 对照

- d7 HPC Job `1101644`（`n019_source_s_diag`）正常完成：
  `17:57:21-21:07:49`，墙钟 `03:10:28 = 3.1744` 卡时，
  `ExitCode=0:0`。1,934 test、104,014 LS360、104,014 VPC
  和全部完整性检查均通过；没有 failed check。
- source-reconstruction E-VPC S：
  female `0.0%`、male `0.0%`、mean **`0.0%`**。
  在同一原始 enrollment 下 `OA=42.1695%`。攻击训练最终验证
  speaker error rate 仅 `0.128%`；第 2 epoch 已降到 `0.451%`。
  `s_metrics.json` SHA256
  `b04a16aae2d178c9b192df677769a72aa7ef92806a6a0bfd048f31c9cd3c5d51`。
- 该诊断说明当前 Unit HiFi-GAN 在给定源 NT embedding 时几乎完整保留
  源身份；随机目标条件下从 `0.0%` 变为正式 `29.7425%` /
  fullmean no-shrink `31.200%`，证明问题不是“声码器天然不保留音色”，
  而是随机目标条件后仍能被 S attacker 利用的残余身份。
- 下一项零训练候选对照 Job `1102767`
  （`n019_avg8892_fullmean_s`，d7 HPC）已完成；结果见 0.0.57。
  规格：`hx1hdnormal`、1 DCU、
  16 CPU / 60 GB、4 h，预计 `3.2`、最坏 `4.0` 卡时。
  按 d7 HPC 50 h 免费额度及 `sacct` 91 个历史作业估算，提交前
  已用 `43.840556 h`、余额约 `6.159444 h`。
- 输入固定为 `generator_avg_88_92_effnorm.pt`
  SHA256 `fafe5982588bea492dd761f1c2d51cc925474503a4f158cf1680667b2286ded8`、
  full-other500 1,160-key mean SHA256
  `576e72f72d536f8e24ce4add26abe46da6c426c121d9fa83bb0d7a7645c4bcb4`、
  test/LS360 full-pool maps SHA256
  `0215470094e36b98d6dd4b082f1e0edbf839711f236b2d9ee84c5c35dd2a96f3` /
  `53058fdbede1bd46ee1fe8013e46c535af58787e5c90182cfa355f351198e6b8`。
  target 仍为论文原始 random speaker、no gender constraint、no shrink、
  `duration=pred`，只把 checkpoint 从 soup2 换成正确 40-speaker dev
  选出的 `avg88_92`。
- 输出：
  `runs/n019_official/privacy/avg8892_fullmean_s_20261112`。
  停止条件：完整写出 104,014 LS360/VPC 和 `s_eval/s_metrics.json`；
  或出现数据/SHM/OOM/非有限 loss/节点异常；或达到 4 h。该任务仅用于
  checkpoint 隐私对照，未通过完整质量与 S 门槛前不替换正式结果。
- 首次提交 `1102715` 在 watchdog 后 30 秒失败，原因仅为 test map
  的 941 个 key 与 full 1,160-key embedding 做严格集合比较；
  `test_941.npz` SHA256
  `983f9d85f08783842d31755b2a0189904c06ea0e1159b388cafcd3f53dbdb14e`
  已在重试中供 test 使用，LS360 继续使用 full 1,160-key NPZ。
  未生成 WAV 或指标，不能把 `1102715` 记为模型实验失败。
- 零卡时复核 speech-resynthesis 审计 commit
  `dbb92c8ddeb081e711adbe9a75714027cd447532`：其 `train.py`
  对 generator 和 discriminators 都使用 `torch.optim.AdamW`。
  当前训练的 AdamW 口径与引用实现一致；此前交接中“上游用 Adam”
  的记录已纠正。`Adam` 仅保留为显式诊断选项，不再标为
  reference-aligned。对应代码/配置已修正，相关测试 `10 passed`。

## 0.0.55 2026-11-12 16:54 fullmean1160 S 完成，source diagnostic 启动

- d7 HPC Job `1100544` 正常完成：
  `15:18:29-16:50:51`，墙钟 `01:32:22 = 1.5394` 卡时，
  `ExitCode=0:0`。短 `TMPDIR=/dev/shm/n019_s_${SLURM_JOB_ID}`
  解决了 `torch_shm_manager ... Invalid argument`；官方 `num_workers=10`
  正常进入并完成 10 个 epoch。
- fullmean1160/no-shrink 的 E-VPC S：
  female `32.113%`、male `30.287%`、mean **`31.200%`**。
  相对正式 shrink0.1 的 `29.7425%` 提高 `+1.4575 pp`，相对论文
  `34.8%` 仍差 `-3.6000 pp`。
- 同一 WAV 集质量此前为 WER `6.152617%`、UTMOS `3.440497`、
  WhiSQA `3.429525`；相对正式结果 WER 改善 `0.071343 pp`，
  但 UTMOS/WhiSQA 回归 `-0.084870/-0.066234`。因此 fullmean1160
  **不替换**正式 shrink0.1 结果；它只证明补全 speaker pool 和取消
  shrink 可提高 S，但仍不足以解释论文差距。
- `s_metrics.json` SHA256
  `c7106d956870874c5d1ff67c99f5ad839a9cca141528b0034cb22cf034d6e06e`；
  `results_anon.txt` SHA256
  `6657510d16d93f6f015f01993f9d6d7ed86fc9251dab24af682758a0cd9371d0`。
- 下一步不是继续调 target pooling/shrink，而是验证 vocoder/unit 是否残留
  **源说话人**的稳定线索。已零卡时生成 source-reconstruction target maps：
  test 1,934 行/40 speakers，SHA256
  `7cde8b3eb7f6a894d47a519f5dc283a233699aebebecbc3350acfe8ecc4f1cd7`；
  LS360 104,014 行/921 speakers，SHA256
  `98519aa3d632706cc604d54796799b0c18160a3a4c5f57d5752ef52ad96f8f35`。
- d7 HPC Job `1101189`（`n019_source_nt_diag`）已完成 test
  source embeddings，但随后读取 LS360 原始 FLAC 时失败：
  d7 home 没有该 LibriSpeech corpus。Job
  实际 `16:57:59-17:00:44 = 2m45s`，`ExitCode=1:0`；
  test NPZ 有效，LS360 需换源，不是 embedding 算法失败。
- d5 持有原始 LS360 和 W-PRO；其 HPC `hx1hdnormal` test-only
  返回 `Invalid account or account/partition combination`。d5 AI
  Job `2120806846710960129` 于 17:12 启动但在 2 秒内失败，原因是
  d5 代码树缺少 `scripts/gpu_tiny_matmul_watchdog.sh`；未进入
  watchdog、模型加载或音频读取，不能算 embedding 失败。
- 复核确认 d7 登录节点可读 d5 的原始 FLAC，且 d7 已有
  `librispeech_train_clean_360_d5read_20261111.jsonl`。因此不再
  使用 d5 AI，改为 d7 HPC Job `1101373`
  （`n019_source_nt_ls360`）：1 DCU、16 CPU / 60 GB、1 h，
  预计 0.3、最坏 1.0 卡时；只提取 921 个 LS360 source speakers
  的 W-PRO means（每 speaker 至多 32 条），不训练模型。
- 该诊断仅用于判断 vocoder/unit 是否残留稳定源说话人线索，
  不是论文方法，也不是正式候选。完成后仍需走同一
  vocoder/duration/S 协议做 source-reconstruction E-VPC S。
- d7 HPC Job `1101373` 已完成 LS360 source embedding：
  `17:22:32-17:51:02 = 28m30s = 0.475` 卡时，`ExitCode=0:0`；
  921 speakers、250-D、finite、unit norm，NPZ SHA256
  `fdd6d6837dacd40c520d60fa18a1957943a6ab6341a812051828dbbf0793e660`。
  test 40-speaker NPZ SHA256
  `902abc3fb8c8b12d13d54380d597777ec1d3311972fe8856c86acb15f5ec76d6`。
  两套 source map/embedding 的 key 集合已逐项精确匹配。
- 已提交 d7 HPC Job `1101644`（`n019_source_s_diag`）：
  1 DCU、16 CPU / 60 GB、4 h，预计 3.2、最坏 4.0 卡时；
  实际 `17:57:21` 在 `f11r3n11` 开始，输出
  `runs/n019_official/source_reconstruction_diag_20261112/s_eval`。
  它使用固定 soup2、`duration=pred`、source-speaker mean 条件，
  在 1,934 test + 104,014 LS360 上执行与正式 DU-pred-nt 完全相同的
  官方 S 重训，仅用于判断源身份残留，不作为正式方法或候选。

## 0.0.54 2026-11-12 15:17 定位并修复 S DataLoader 的长 TMPDIR shm 错误

- 复核 Slurm 后确认交接摘要中的 `1100489` 并不存在：
  `squeue/sacct/scontrol` 均无记录；它不能作为已提交 Job。
  `sbatch --test-only` 的节点预测也不代表真实提交。
- d7 HPC 的第一次正式重试 Job `1100497`
  （`n019_fullmean1160_s_nw10`）在 `f11r2n13` 运行 14m50s。
  数据准备完成后，官方多 worker DataLoader 再次报
  `torch_shm_manager ... Invalid argument`，没有进入训练；已于
  `15:14:25` 主动停止。
- 根因已定位到长路径，而不是节点：旧
  `TMPDIR=/public/home/a094f4d7/voice_projects/runs/n019_official/privacy/fullmean1160_du_pred_nt_s_20261112/tmp/s_eval_nw10`
  长度为 114 字符，超过 `torch_shm_manager` 可接受的共享内存名长度。
  这与 `1098744` 在另一节点、同一长路径下的报错一致。
- 修复后 Job `1100544`（`n019_fullmean1160_s_nw10st`）于
  `15:17:22` 提交，当前排队。`TMPDIR` 改为短路径
  `/dev/shm/n019_s_${SLURM_JOB_ID}`，并排除
  `f11r1n01,f11r2n13`。输出改到 `s_eval_nw10st`，避免混入失败目录。
- 规格：d7 HPC、`hx1hdnormal`、1 DCU、16 CPU / 60 GB、2 h，
  预计 1.5、最坏 2.0 卡时；排除已知 shm 异常节点 `f11r1n01`。
  输入是已完成的 1,934 test + 104,014 LS360 WAV/VPC，不重新渲染。
  输出
  `/public/home/a094f4d7/voice_projects/runs/n019_official/privacy/fullmean1160_du_pred_nt_s_20261112/s_eval_nw10`。
- 使用官方 `configs/eval_paper_test_only_post.yaml`，恢复
  `num_workers=10`；ECAPA scratch、10 epochs、lr `0.01`、batch
  `256`、`spk-diverse-sess`、921 speakers 和 retrain 均未改。
  `TMPDIR` 显式放在该 run 的 NFS 目录，避免计算节点 `/tmp` 满。
- 远端修复版 SLURM wrapper SHA256
  `0c7e04930bbe1224de33f4e591e096ba2e4c452974ceca69e705602a649e352c`，
  `run_s_eval_remote.sh` 为
  `0630e0b655f8fbaab22d7fd1e4080de32225b2f9a32dc52775a632e79797ba46`。
- 这是诊断性 S-only 复评：只有 E-VPC S 明显接近论文 `34.8%`，
  且 fullmean/no-shrink 的 UTMOS/WhiSQA 回归可以接受时，才考虑替换
  正式 shrink0.1 结果。不得在结果出来前改写正式指标。

## 0.0.53 2026-11-12 14:10 诊断 S 失败并在 d6 重跑官方 S-only 链路

- `1098744` 的 104,014 条 LS360 匿名化、VPC export 和完整性验证均已完成：
  - `anon.jsonl` 104,014 行，SHA256
    `2980f12e1e93ea97244b440df63244c6e54638c5b78fb7e1adb34f883a1f5abf`；
  - `verification.json` 全部 checks 为 true，104,014 WAV、
    `wav_bytes=41,940,252,136`，VPC `wav.scp` 104,014 行；
  - 该阶段实际约 4,701 秒。
- S 阶段在 `f11r1n01` 的官方 ECAPA 训练 DataLoader 报
  `torch_shm_manager ... Invalid argument`，随后进程持续等待至 4 小时
  墙钟上限；`1098744` 最终为 `TIMEOUT`，没有 `s_metrics.json`。
  这不是匿名化或模型失败。
- 新增 `configs/eval_paper_test_only_post_nw0.yaml`，除
  `privacy.asv.training.num_workers: 0` 外保持论文/VPC 配置不变；
  官方 ECAPA scratch、10 epochs、lr `0.01`、batch `256`、
  `spk-diverse-sess`、921 speakers 均不变。
- d6 AI 容器不能读取 d7 home，因此已将 1,160-key full mean 和 LS360
  target map 复制到 d6 并核对 SHA256；soup2 checkpoint 与 duration
  model 本来就在 d6。新 Job 从 d6 自己的数据重跑 LS360 + VPC + S，
  不复用 d7 容器不可见的路径。
- d6 AI 的两次快速重试都未进入训练：
  `2120761326156005378` 因容器 `HOME=/root` 找不到 wrapper；
  `2120761815004876802` 因非 Slurm 容器没有 `SLURM_JOB_ID`；
  `2120762690334326785` 又因补变量后激活脚本要求 `TMPDIR`。三者均在
  DCU watchdog 前失败，没有音频或卡时意义上的训练。
- r3 Job `2120762893529796609`
  （`n019_fm1160_s_nw0_r3_20261112_141722`）：
  1 DCU、15 CPU / 59 GB、4 h，预计 3.0、最坏 4.0 卡时；
  提交前 d6 余额 `4.9927777776`。输入是完整 other-500 full mean、
  soup2 checkpoint、duration predictor 和原始 LS360；
  输出 `runs/n019_official/privacy/fullmean1160_du_pred_nt_s_20261112/s_eval`。
  启动环境显式设置 `HOME`、`SLURM_JOB_ID` 占位值和 `TMPDIR`，
  已通过 watchdog 并开始合成。但实测首个 shard 仅约
  `441/26054` 句/78 秒（约 `5.6 utt/s`），四片顺序执行会先耗尽
  4 h 墙钟，无法进入 S 重训；已在 14:26 左右主动停止，未等它拖满。
- 改为 d7 HPC S-only Job `1100375`
  （`n019_fullmean1160_s_nw0`）：1 DCU、16 CPU / 60 GB、2 h，
  预计 1.5、最坏 2.0 卡时。它直接复用 d7 已完成且验证通过的
  104,014 条 WAV/VPC，只重跑官方 ECAPA S 重训和评分；
  把 pending TimeLimit 从 2.5 h 收紧到 2 h 后，调度器给出
  `StartTime=2026-11-12 14:34:29`、节点 `f11r3n12`。
  使用 `num_workers=0`，其余科学参数不变。

## 0.0.52 2026-11-12 08:40 回到论文随机 target，补齐 full speaker mean

- 用户明确否决强制异性别 target。该实验只保留为 privacy-enhanced
  diagnostic，不能作为 `DU-pred-nt` 的正式复现方法，也不能继续沿性别约束
  调参。
- 当前正式口径仍是原始 LibriTTS `train-other-500` 内随机 target
  speaker，不做性别约束、不固定 source-target 映射。为了更严格对齐
  论文的 “target speaker embedding”，本轮补的是此前未闭环的 pool
  精度，而不是修改采样规则。
- 原始 LibriTTS `train-other-500` manifest 为 205,044 条、1,160 个
  speaker，SHA256
  `c482d1e37b9fabe64006fc97dc1c108d3f866d746e94e97af383275c8396c437`。
  已有 full-utterance speaker mean 覆盖 843 个 speaker、168,023 条
  utterance；当前正式 `mean32` 只是稀疏代理。
- 零卡时审计发现 test/LS360 speaker-sampled maps 共覆盖 1,158 个
  target speaker；其余 315 个 speaker 共 37,015 条 utterance 尚无
  full mean。另有 speaker `147`、`7683` 未进入旧 map，二者合计仅
  6 条 utterance，待前 315 个完成后单独补齐。
- d5/d6 当前对 `hx1hdnormal + 1 DCU` 的 sbatch test 返回
  `Invalid account or account/partition combination`；d7 通过
  `sbatch --test-only`，因此本轮使用 d7，未使用 d8/d9。
- d7 HPC Job `1098620` 已启动：`hx1hdnormal`、1 DCU、
  16 CPU / 60 GB、2 h，预计 0.6、最坏 2.0 卡时；实际节点
  `f11r1n15`。先执行 300 秒 SIGKILL tiny-matmul watchdog，然后对
  37,015 条 utterance 提取 full speaker mean。输入 manifest SHA256
  `eeb097cfdcd99a2f7e4f9676dcb851392d01b23b48519f8ff7a8837583793438`；
  输出
  `/public/home/a094f4d7/voice_projects/data/n019_official/processed/embeddings/target_speaker_fullmean315_hpc_20261112`。
- 已用 `afterok:1098620` 提交 d7 HPC Job `1098659`
  （`n019_fullmean1160_prep`）：1 DCU、16 CPU / 60 GB、1 h，
  预计 0.15、最坏 1.0 卡时。它将补 speaker `147`、`7683` 的 6 条
  utterance，合并 843+315+2 为 1,160-key full speaker mean，并生成
  941-key test subset。
- 全 pool target maps 已零卡时生成：
  - test：1,934 行、941 target speakers，SHA256
    `0215470094e36b98d6dd4b082f1e0edbf839711f236b2d9ee84c5c35dd2a96f3`；
  - LS360：104,014 行、1,160 target speakers，SHA256
    `53058fdbede1bd46ee1fe8013e46c535af58787e5c90182cfa355f351198e6b8`。
  两者均为 seed `20261102`、target-speaker uniform、无性别约束。
- 已追加依赖链，前序成功前不占用 DCU：
  - `1098670`（`n019_fullmean1160_eval`，`afterok:1098659`）：
    1 DCU、16 CPU / 60 GB、2 h，预计 0.25、最坏 2.0 卡时；
    完整 1,934 句匿名化 + WER/UTMOS/WhiSQA。
  - `1098672`（`n019_fullmean1160_s`，`afterok:1098670`）：
    1 DCU、16 CPU / 60 GB、4 h，预计 3.0、最坏 4.0 卡时；
    完整 104,014 句 LS360 匿名化 + 官方 10-epoch ECAPA S 重训。
  两个 wrapper 均使用当前 soup2 checkpoint、`duration=pred`、
  fullmean1160 target embedding，不使用异性别或固定 source-target 映射。
- fullmean 资产已验证：full 1,160 keys / 250-D / finite / unit-norm，
  SHA256 `576e72f72d536f8e24ce4add26abe46da6c426c121d9fa83bb0d7a7645c4bcb4`；
  test subset 941 keys，SHA256
  `983f9d85f08783842d31755b2a0189904c06ea0e1159b388cafcd3f53dbdb14e`。
- `1098620` 正常完成：37,015/37,015 条，墙钟 26m28s；315-key
  NPZ SHA256 `5e414c996e24a3a688bd01f703b1855b0c03edde758deee8410cdfeb5dec06a6`。
  afterok 的 `1098659` 在 47 秒内完成 6 条补提取、1160-key 合并
  和 test subset 验证。
- 首次 `1098670` 在输出预检时 21 秒失败：旧
  `data/n019_official/anonymised/libri_test` 父目录不可写，未生成
  WAV 或指标；依赖的 `1098672` 随之取消。已把匿名化输出移到
  `runs/n019_official/privacy/fullmean1160_du_pred_nt_20261112`
  并重新提交 `1098697`（eval）→ `1098699`（S，`afterok`）。
- `1098697` 已完成并核验全部 1,934 WAV/VPC、1,496 行 ASR 视图，
  但随后在创建 `runs/n019_official/eval/du_pred_nt_fullmean1160_20261112`
  时因 root-managed 父目录权限失败；没有 WER/MOS 输出。
  `1098699` 又被依赖取消。已将 eval 输出移到候选 privacy run 内，
  复用现有 WAV/VPC 重提 `1098721`（metrics-only）→ `1098723`
  （S，`afterok`）；不要重跑已完成的匿名化。
- `1098721` 在 watchdog 启动前因计算节点默认 `/tmp` 满而秒失败，
  `1098723` 又被取消；没有新的 WAV 或指标。两个 wrapper 现都在
  source 环境后显式设置候选 run 内的 `TMPDIR`，重提
  `1098741`（metrics-only）→ `1098744`（S，`afterok`）。
- fullmean1160/no-shrink `DU-pred-nt` 的完整 1,934 句质量已完成
  （Job `1098741`，墙钟 6m37s）：

| Metric | fullmean1160 | 当前正式 shrink0.1 | 论文 |
|---|---:|---:|---:|
| WER | **6.152617%** | 6.223960% | 7.41% |
| UTMOS | 3.440497 | **3.525367** | 3.63 |
| WhiSQA | 3.429525 | **3.495759** | 3.69 |

  WER 改善 `-0.071343 pp`，但 UTMOS/WhiSQA 回归
  `-0.084870/-0.066234`，单看质量不满足替换门槛。
  `quality_metrics.json` SHA256
  `a723ee9da979d1d5bec4fcc8ee9f4a2c0db9081e9cf1e9f5b89850034ea3c5d9`。
- S Job `1098744` 已于 09:22:28 在 `f11r1n01` 运行；它只用于判断
  full speaker mean 能否显著提高 E-VPC S。即使 S 改善，也必须结合
  上述 MOS 回归决定是否替换，不能只按 S 选型。
- 任务完成后必须合并为 1,158/1,160-key、250-D、finite、unit-norm
  的 full speaker mean；随后重建全 other-500 target speaker map，
  在同一 soup2 checkpoint、duration、vocoder 和官方 VPC S 流程上
  做 no-shrink A/B。只有 E-VPC S 接近或达到论文 `34.8`，且完整
  1,934 句 WER/UTMOS/WhiSQA 没有超门槛回归，才替换正式结果。

## 0.0.51 2026-11-12 04:45 DU-nt-nt S 仍不足，异性别采样进入全量 S

- `DU-nt-nt` 的完整 LS360、官方 10-epoch E-VPC S 重训 Job `1097898`
  已完成，墙钟 `01:32:59 = 1.5497` 卡时。结果 female `29.563%`、
  male `30.515%`、mean **`30.039%`**；仅比正式模型 `29.7425%`
  提高 `+0.2965 pp`，仍比论文 `34.8%` 低 `4.761 pp`。因此
  target-conditioned duration 不是主要残差。
- `s_metrics.json` SHA256
  `2d6daa038fa2471ed1932c59ff276951ef430303d5b23f742a8c4a77e1668673`；
  `results_anon.txt` SHA256
  `5ec05e2e01cfe4952d46979b022c31d969ed3795edb334cb2c3735a988760366`。
  不得重跑该 S 评测。
- 现有 speaker-uniform target map 中只有约 `48.7%` 的 target 与 source
  异性别。新增
  `scripts/make_opposite_gender_target_map.py`，对 test/LS360 在论文原始
  other-500 target 池内强制异性别、按 target speaker 均匀采样：
  - test map SHA256
    `96c3bb8f9042db0409d5db2b1b050e34ca8abca3e80311307fcfdc56c205f493`；
  - LS360 map SHA256
    `8956628fa84fdfbebdcf906a4f59a869a6c91ab93189a08e7de12614dfd6376b`。
- 异性别 full-test Job `1098238` 完成，复用 1,934 WAV/VPC：
  WER `6.292449%`、UTMOS `3.458855`、WhiSQA `3.491496`。
  相对正式模型 WER `+0.068489 pp`、UTMOS `-0.066512`、
  WhiSQA `-0.004263`；质量代价有限且 WER 仍优于论文。
- 同一 test audio 的 W-NT L Job `1098241` 完成：female `41.424432%`、
  male `40.781495%`、mean **`41.102964%`**，相对正式
  `39.729348%` 提高 `+1.373616 pp`。`summary.json` SHA256
  `0f2aa85332de2ac320255147f7a10bd9fde36e3a21c3d090928c59cd862ad5cf`。
- 已提交完整异性别 LS360 和官方 S 依赖链：
  - anonymisation Job `1098250`：d7 HPC、1 DCU、16 CPU / 60 GB、
    3 h；预计 1.5、最坏 3.0 卡时；
  - S eval Job `1098251`：`afterok:1098250`，3 h；预计 1.5、
    最坏 3.0 卡时；
  - 输出
    `runs/n019_official/privacy/opposite_gender_du_nt_nt_20261112`。
  配置 `configs/scnet_d7_opposite_gender_full_s_20261112.json` 已记录。
  禁止重复提交或重新渲染已完成的 test 音频。
- `1098250` 已完成：104,014 个 WAV、`wav_bytes=42,536,030,056`，
  VPC `wav.scp=104,014`，验证 JSON 通过；`anon.jsonl`、
  `run_meta.json`、`verification.json`、VPC `wav.scp` SHA256 分别为
  `41a8e361...a37981`、`bcfebe03...26b6c`、
  `b73e4776...e4648c`、`07a6f390...92bb01`。
  `1098251` 已自动启动官方 S 重训，不能重提。
- `1098251` 已完成，墙钟 `01:27:36 = 1.46` 卡时。异性别
  DU-nt-nt 的 E-VPC S：female `40.874%`、male `43.207%`、
  mean **`42.0405%`**。相对正式 `29.7425%` 提高
  `+12.2980 pp`，相对论文 `34.8%` 高 `+7.2405 pp`，
  相对随机 target 的 DU-nt-nt `30.039%` 高 `+12.0015 pp`。
  `s_metrics.json` SHA256
  `27b1d55e4a3328c35f483a7382f94e19d2874a04a31caa0794131e5128eb3e09`；
  `results_anon.txt` SHA256
  `48cb9cab4ac2790afc93728c689db5b50e0d8959a3584b06bcf196affd5819c5`。
  这是**隐私增强校准变体**，不是严格随机 target 的论文原方法；必须与
  `DU-nt-nt=30.039%` 分表报告，不能混写。
- 已提交低成本的 E-VPC I/L + W-NT I/L 闭环 Job `1098557`：
  d7 HPC、1 DCU、16 CPU / 60 GB、1 h，预计 0.2、最坏 1.0 卡时。
  输出
  `privacy/opposite_gender_du_nt_nt_20261112/privacy_il`。
- `1098557` 在 W-NT I 的原始 enroll 相对路径解析处快速失败；补
  `data -> ..` 兼容链接后 Job `1098566` 完成，墙钟 `8m09s`。
  E-VPC I/L 为 `47.192 / 49.0715`，W-NT I/L 为
  `39.391970 / 41.102964`。对照正式 `48.0285 / 47.7540` 与
  `39.167858 / 39.729348`，说明 privacy-enhanced 变体的主要收益
  集中在 E-VPC S 和 W-NT L，E-VPC I 仅回退 `0.8365 pp`。
  `privacy_il_metrics.json` SHA256
  `6dcb75252095155538621ab3c055c0efca3615ababde89703febfcbc95418776`。
- 快速失败追溯：`1098216` target-map/embedding key 集合不精确相等，
  814-key 子集生成后修复；`1098220` 写入 root-owned anonymised 父目录
  失败；`1098226` 生成并核验全部 1,934 WAV/VPC，仅写 root-owned eval
  父目录失败，`1098238` 复用音频完成质量指标。没有有效模型失败。

## 0.0.50 2026-11-11 22:30 utterance target 关闭，转测 DU-nt-nt

- d6 Job `1095367` 的匿名化、104,014 句 LS360 导出和官方
  10-epoch ECAPA S 重训全部完成；评分结束后 MIOpen 析构异常使平台
  状态为 `FAILED`，但 `results_anon.txt` 完整。CPU 重建
  `s_metrics.json` 后确认 E-VPC S：female `30.109%`、male `31.828%`、
  mean **`30.9685%`**。
- 相对正式 mean32/shrink0.1 的 `29.7425%` 仅提高 `+1.2260 pp`，
  仍比论文 `34.8%` 低 `3.8315 pp`；同一 utterance-target test 音频的
  UTMOS/WhiSQA 还分别下降 `0.171911/0.165424`。因此单 utterance
  target embedding、target sampling、shrink 都不是 E-VPC S 主因。
- `s_metrics.json` SHA256
  `7db0eff5036bc65c174f083a1bd9d6dbcf988961b2286adb692e2203368d05c2`；
  `results_anon.txt` SHA256
  `a46156d21b891d2dee7b72315f3b031c256a440373e7a85eb1355da8dd6b1a87`。
- 下一项改为论文 Table 1 中同一族、且更适合当前资产与目标的
  `DU-nt-nt`：时长预测器和 NT vocoder 都使用 target speaker
  embedding。论文对应 E-VPC S `34.1`、W-NT L `42.5`、WER `7.73`、
  UTMOS/WhiSQA `3.63/3.69`。该实验不需要继续长训练；只做完整
  LS360/1,934 句推理和官方 S 重训。
- 新增 `--duration-embedding-key target_id|target_speaker`，允许
  speaker-level duration model 在推理时使用真正的 speaker-pooled
  target embedding，避免训练/推理层级不一致。相关测试 `11 passed`。
- d7 4 句 `DU-nt-nt` GPU smoke Job `1097145` 已完成，4/4 WAV、
  `anon.jsonl` 和 `run_meta.json` 完整，墙钟 `54s`。正式全量
  Job `1097354` 已提交：d6 HPC、1 DCU、16 CPU / 60 GB、5 h，
  预计 3.2、最坏 5.0 卡时；输入 104,014 句 LS360 和 1,934 句
  test，使用 954/1,158 speaker-sampled maps、mean32+shrink0.1、
  `duration_nt_main` 和 soup2 vocoder。输出
  `runs/n019_official/privacy/du_nt_nt_s_20261111`，suffix
  `_n019_du_nt_nt_20261111`。配置
  `configs/scnet_d6_du_nt_nt_s_20261112.json` 已回写 JobID 并设
  `submit:false`，严禁重复提交。
- 两次快速失败均无音频产出：`1097330` 是 staging 长文件名缺失；
  `1097336` 是 test map 只有 954 个 target speakers，而全量
  embedding 有 1,158 个 key。已生成 954-key test 子集
  `test_target_speaker_mean32_954_shrink01.npz`，SHA256
  `75f445857cbb02c245937ba5b2f4a355e43b4715486a42fc10e0f470df5f8f52`；
  LS360 继续用完整 1,158-key embedding。
- Job `1097354` 已进入正式运行。1,934 句 test 在 `99.7s` 内完成，
  WAV/VPC/count/owner/duration-mode 全部校验通过；test
  `anon.jsonl` SHA256
  `f8f10024298fe5731d7b83b736e3db7b716aab23cf11c192ff8118002eb9688d`，
  验证 JSON SHA256
  `78d363246789c9e4ea926a7183340a3aaadd76ad5ede8f5bdb5d341f27876976`。
  LS360 第一片实测约 18–19 句/s，四片预计约 1.5 h，之后自动进入
  官方 S 重训。

## 0.0.49 2026-11-11 19:20 E-VPC S：shrink 排除，转测 utterance target

- `shrink=0.05` + speaker-sampled target map 的完整 LS360 E-VPC S
  Job `1094009` 已完成评分，但官方流程末尾在 MIOpen 析构阶段异常退出。
  `results_anon.txt` 完整，CPU 重建 `s_metrics.json` SHA256
  `d0003d98229a1e44efff6034043f104ebb0eacb684edfccedb20d16f8050aa3a`。
- 结果：female `31.387%`、male `30.070%`、mean `30.7285%`。相对
  speaker-sampled shrink0.1 的 `30.6420%` 仅提高 `+0.0865 pp`，仍比
  论文 `34.8%` 低 `4.0715 pp`。因此继续减小 shrink 不是 E-VPC S
  的主要修复方向，依赖它的 shrink0 全流程 Job `1094023` 已取消。
- 为检验“论文 target speaker embedding 可能是单条 target utterance，
  而不是 mean32”，新增 speaker-uniform / utterance-level target map：
  - test map:
    `runs/n019_official/utterance_target_maps_20261111/libri_test_speaker_uniform_utterance_seed20261102.jsonl`
    SHA256 `c139d91f69d85e7c7b325d5658a3dfe548363c1689972abfe4adc831d8dd24d7`；
  - test embedding subset SHA256
    `20e0954447831b8c00ca0556e768f05e887b032365062c864e6423de32163415`；
  - full LS360 map SHA256
    `4a94aed9d96053312ec8142777a0cd9304696c5a9e01dbdb8a851bdcead19252`；
  - full LS360 embedding subset SHA256
    `fdf52668d8a4f955ce2029ea24f0cbdc007dda615f6485691504326db9b594e4`。
- 完整 1,934 句纯 utterance-target A/B，Job `1094954` 完成，实际
  `7m17s`：WER `6.186861%`、UTMOS `3.353455`、WhiSQA `3.330335`。
  相对正式 mean32/shrink0.1，WER 改善 `-0.037099 pp`，但 UTMOS/WhiSQA
  回归 `-0.171911/-0.165424`，质量代价明显。`quality_metrics.json`
  SHA256 `9a64c58641864a86dcc6ebc7c460d9276fdd5e4d9d8fc01631e9d3a9024f7aa3`。
- 同一 utterance-target test 音频的 W-NT L Job `1095473` 完成，实际
  `3m18s`：female `41.058850%`、male `40.977447%`、mean
  `41.018149%`。相对正式 `39.729348%` 提高 `+1.288801 pp`，相对
  speaker-sampled mean32 的 `40.358581%` 提高 `+0.659567 pp`，但仍比
  论文 `42.3%` 低 `1.281851 pp`。`summary.json` SHA256
  `58f8a79761351f9e2a56cf104e5061e529b4f459a528109674d7706cbe6111aa`。
- 仍需直接测完整 LS360 E-VPC S，不能由质量 screen 推断。d6 Job
  `1095367` 正在用同一 utterance target 配方匿名化 104,014 句并跑官方
  10-epoch ECAPA S。规格：d6 HPC、1 DCU、16 CPU / 60 GB、4 h；预计
  3.0、最坏 4.0 卡时。输出
  `runs/n019_official/utterance_target_maps_20261111/full_s_r2`。
  d6 观测约 19.5 句/s，预计匿名化约 1.5 h。
- 失败追溯：`1095051/1095097` 使用了 d7 上旧版
  `anonymize_ls360_remote.sh`，错误读取旧 utterance map；已同步新版并
  改用环境变量。`1095259` 在 d7 慢节点仅约 4.6 句/s，主动取消；
  `1095304` 因 d6 缺 soup checkpoint 快速失败。都不是模型失败。

## 0.0.48 2026-11-11 15:05 E-VPC S / W-NT L 残差修复

- formal 结果仍是 soup2+shrink0.1：E-VPC S `29.7425%`、W-NT L
  `39.7293%`。论文为 `34.8% / 42.3%`。
- 两个已确认实现偏差：目标应按 paper wording 做 target-speaker
  sampling，而不是 target-utterance sampling；`shrink0.1` 是论文
  没有公开的本地质量启发项。
- speaker-sampled map、shrink0.1 的 full S Job `1091285` 得到
  `30.6420%`，仅改善 `+0.8995 pp`。评分完整，postprocess 异常后
  已用官方 `results_anon.txt` 重建 `s_metrics.json`。
- 无训练交叉结果：

| 配置 | E-VPC I | E-VPC L | W-NT I | W-NT L |
|---|---:|---:|---:|---:|
| formal shrink0.1 | 48.0285 | 47.7540 | 39.1679 | 39.7293 |
| speaker map + shrink0.05 | 46.8930 | 47.6450 | 38.9625 | 41.0403 |
| speaker map + shrink0 | 47.3850 | 47.6340 | 39.5045 | 41.2432 |
| paper | 47.2 | 47.9 | 39.9 | 42.3 |

- shrink0 是更强的 zero-training privacy 修复：E-VPC I/L 已接近
  论文，W-NT L gap 从 `-2.57` 缩到 `-1.06 pp`；代价是 full
  UTMOS/WhiSQA `3.4555/3.4448`，相对 formal 回归
  `-0.0699/-0.0510`。shrink0.05 回归为
  `-0.0447/-0.0216`，WER `+0.0599 pp`，满足预声明质量门槛。
- 但 W-NT L 对 target-map seed 很敏感。shrink0 的三个新 seeds
  `20261103/04/05` 为 `40.0028/40.1629/40.1546`，均值
  `40.1068`、std `0.0736`；同 seed03 下 shrink0.1 为
  `39.9580`，shrink0 只提升 `+0.0447 pp`。因此 `41.2432` 是
  seed20261102 的有利样本，不能把 shrink0 表述为稳定 W-NT L 修复。
- 后段 checkpoint 也没有解决 W-NT L：100k/102k/106k 为
  `40.1966/40.1175/40.9905`，112k/134k/136k 为
  `40.0386/40.6948/40.5316`。无单调关系，且均低于 42.3。
- E-VPC S 的 shrink 效应仍不能由 test I/L 外推。d6 `1092783`
  正在跑 shrink0.05 full-LS360 + official 10-epoch ECAPA；完成后
  `1092786` 自动跑 shrink0。每个 1 DCU、16 CPU / 60 GB、4 h，
  预计 3.0、最坏 4.0 卡时。d7 `1092779` 正在做 shrink0
  target-map 3-seed W-NT L 稳定性。
- 详细记录：
  `docs/N019_PRIVACY_GAP_FIX_20261111.md`；
  台账：`configs/scnet_privacy_gap_followup_20261111.json` 与
  `docs/JOB_LEDGER.md` 顶部。

## 0.0.47 2026-11-11 07:01 W-NT S 修复完成，DU-pred-nt 九项闭环

- 此前 `freeze_r2` 的 AAM `margin=0.2, scale=30` 分支虽然持续降低
  loss，但训练 accuracy 仍接近 0；用 epoch06 导出的 W-PRO 计算
  W-NT S 得到 `42.9055%`，明显高于论文 `24.6%`，说明攻击模型本身
  未正常收敛，不能作为最终 S 结果。
- d6 新受控 smoke `1089071`（首轮 `1089060` 在
  `f11r1n05` 发生 SIGSEGV，因此排除 `f11r1n05/f11r1n20` 后重跑）
  使用 `margin=0.05`、`scale=10`、WavLM 冻结、top-layer/head
  lr `1e-4/1e-3`、batch 16，训练 4 epochs / 26,000 steps。
  epoch loss/accuracy 为 `5.4820 / 0.06551`，模型正常学习。
- W-NT S 评估 Job `1089232` 使用
  `wnt_s_stable_smoke_20261111/model`，在官方 AA trial 上完成：

| gender | EER |
|---|---:|
| female | 23.880922% |
| male | 25.166792% |
| mean | **24.523857%** |

  论文 W-NT S 为 `24.6%`，绝对差 `-0.076143`，在
  `0.5` 个百分点报告容差内。
- 训练模型 `model.safetensors` SHA256
  `cbd6762b757a12260868009c07c31993b9f75391b2b800233caff23eae338e0e`；
  `summary.json` SHA256
  `cd9cb2f2031554e1dde0960731e841b77f0b223a9197cb0958ef47f43f2ff132`。
- 已生成完整九项最终结果目录：
  `privacy/du_pred_nt_soup2_w40_shrink01_final_r2_20261111`。
  九项为 E-VPC I/L/S、W-NT I/L/S、WER、UTMOS、WhiSQA；
  `paper_metrics.json` 无 missing，WER=1,496，UTMOS/WhiSQA=1,934。
- 最终指标：

| Metric | Reproduced | Paper | Abs. diff |
|---|---:|---:|---:|
| E-VPC I | 48.0285 | 47.2 | +0.8285 |
| E-VPC L | 47.7540 | 47.9 | -0.1460 |
| E-VPC S | 29.7425 | 34.8 | -5.0575 |
| W-NT I | 39.1679 | 39.9 | -0.7321 |
| W-NT L | 39.7293 | 42.3 | -2.5707 |
| W-NT S | 24.5239 | 24.6 | -0.0761 |
| WER % | 6.2240 | 7.41 | -1.1860 |
| UTMOS | 3.5254 | 3.63 | -0.1046 |
| WhiSQA | 3.4958 | 3.69 | -0.1942 |

- 最终汇总哈希：`wnt_summary_ils`
  `12198f340f981440198616201d7bfcacb616af8e89352befa6ad22fef17b3126`，
  `paper_metrics` `5ade74a7d1486b258b80062638d1fe0c39c2f5b8b6005cc3828e31d328fd07d6`，
  `paper_comparison.json`
  `9e51fafca0a245dcbecd406c66eea9ae7f4c4c0255c4f5af82a12984493b5010`。
- 最终结论：`DU-pred-nt` 的九项均已产生可追溯分数；W-NT S 已对齐
  论文，剩余主要残差是 E-VPC S（隐私偏弱）、W-NT I/L（隐私偏强）
  以及 UTMOS/WhiSQA 的小幅质量差距。

## 0.0.46 2026-11-11 05:41 d6 长训保持停止，补齐 164k 三项指标

- d6 HPC 长训 Job `1076707` 仍为停止状态，`sacct` 为
  `CANCELLED+`，墙钟 `15:31:12`；d6 当前队列为空，没有新的长训。
  最后稳定 checkpoint 仍为 step `164,000`，
  SHA256 `e7a6ef1003dfc0caebe0f356b751340c93588e1d53867f068ca5f44feb911bb0`。
- 为核对“现在”的最后一个 d6 checkpoint，d7 HPC Job `1088937`
  在固定 40-speaker dev-100 上复用已生成的 164k WAV 和 UTMOS，
  只补 WhiSQA/WER；没有重新训练或重新渲染。
- 任务规格：d7、HPC/Slurm `hx1hdnormal`、1 DCU、16 CPU / 60 GB、
  外层 40 分钟；预计约 0.05、最坏 0.667 卡时。实际
  `05:38:51–05:40:31 = 1m40s ≈ 0.028` 卡时，Job 状态 `COMPLETED`。
- 新增 164k 结果：

| checkpoint | UTMOS | WhiSQA | WER % |
|---|---:|---:|---:|
| 当前 soup2 baseline | **3.512772** | **3.431399** | **6.121517** |
| d6 step 162k | 3.336230 | 3.323067 | 6.486980 |
| d6 step 164k | 3.247305 | 3.318912 | 6.669712 |

  162k/164k 的 `dUTMOS` 分别为 `-0.176542/-0.265467`，
  `dWhiSQA` 为 `-0.108332/-0.112487`，WER 回归
  `+0.365464/+0.548196 pp`，均未通过预声明 gate。
  `selection.json` 继续选择 baseline，SHA256
  `f6043028387b28c437195f200683ac29c304ba0baf2300de7bb625f8f532afa4`。
  164k candidate SHA256
  `890e8711a3e5b1d2f2ab481ce0b1de0d06a9c8bf250acb6333a60365495ca6af`。
- 因此 d6 长训不应恢复；当前正式模型保持 soup2+shrink0.1 不变。

## 0.0.45 2026-11-10 22:02 停止 d6 并测试最后 checkpoint

- 已按用户要求于 21:52:12 停止 d6 HPC Job `1076707`；
  `sacct` 状态 `CANCELLED+`，实际墙钟 `15:31:12`。
  日志最后 step `164,280`，持久 `last.pt` 为 step `164,000`，
  SHA256
  `e7a6ef1003dfc0caebe0f356b751340c93588e1d53867f068ca5f44feb911bb0`。
  d6 队列现已清空。
- 将 160k/162k/164k 经本机中转至 d7，源/本机/d7 SHA256 一致：
  160k `700eaeb2d46c40ff2d94a33cee33e4e80c89ac98d064746b564e7cacd0af945c`，
  162k `388ac611ad75ab87c7774ab0818a6df6da69bf79b5e605dd4758f98d67407892`，
  164k `3a6cceca9de8fe7c3992bbe60a88e16242b7509338016c14199adfe520dbbb1a`。
- d7 HPC Job `1085907` 完成，历时 5m45s。固定当前正式推理
  `soup+shrink0.1`、正确 40-speaker dev-100：
  baseline UTMOS `3.5127723885`；
  160k `3.2387674308`（`-0.2740049577`）；
  162k `3.3362299037`（`-0.1765424848`）；
  164k `3.2473053122`（`-0.2654670763`）。
  三者均早拒绝，正式结果保持 `soup+shrink0.1` 不变。
- 输出
  `runs/n019_official/vocoder_selection_d6_final_160_164_20261110`；
  配置见
  `configs/scnet_d7_hpc_d6_final_160_164_20261110.json`。

## 0.0.44 2026-11-10 21:50 当前策略与总体复现进度归档

- 新增
  `docs/N019_CURRENT_STRATEGY_AND_RESULTS_20261110.md`，集中记录：
  - 当前正式 `DU-pred-nt` soup+shrink 策略和数据/模型/评测口径；
  - 新正式结果及全部哈希；
  - 历代结果演进；
  - 与论文的已对齐项、未公开项和复现增强项；
  - 单体质量、隐私和完整 Table 1 的分层完成度；
  - E-VPC/W-NT、S 条件和其余系统的下一步。
- 当前不能把“DU-pred-nt 的 WER/UTMOS/WhiSQA 完成”写成完整论文复现：
  新音频上的 E-VPC/W-NT EER 仍未计算，其他 DU 系统和第三方基线也未闭环。

## 0.0.43 2026-11-10 21:36 soup+shrink 完整复评刷新正式 MOS

- 完整 official `libri_test` Job `1085663`
  （`n019_eval_soup2_w40_shrink01_r4`）已完成，实际墙钟 5m31s。
  新正式结果：

| 指标 | 新结果 | 旧 `avg88_92+mean32` | 论文 |
|---|---:|---:|---:|
| WER | **6.2239598196%** | 6.2211061012% | 7.41% |
| UTMOS | **3.5253666541** | 3.3997926173 | 3.63 |
| WhiSQA | **3.4957589100** | 3.3985530013 | 3.69 |

  相对旧正式结果，UTMOS `+0.1255740367`、WhiSQA
  `+0.0972059087`、WER `+0.0028537184 pp`。相对论文，
  剩余差为 UTMOS `-0.1046333459`、WhiSQA
  `-0.1942410900`，WER 仍优 `1.1860401804 pp`。
  计数 WER=1,496、UTMOS/WhiSQA=1,934。
- checkpoint 为 `quad_w40_30_20_10` SHA256
  `ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6`；
  target embedding 为 `mean32_shrink0.1`，即向 target 全局
  均值混合 10% 后 L2 normalize。`quality_metrics.json` SHA256
  `542cd9fc44e1c03237150078cb67ddb4e7edfe41775f53c77acb7896040d9f5a`。
  输出
  `runs/n019_official/eval_user/du_pred_nt_soup2_w40_shrink01_20261110`。
- 前三次外层次尝试 `1085482`、`1085520`、`1085586` 均未产生
  指标：第一次静默退出；诊断发现 WER 前置脚本只接受
  `speaker_mean_l2`；修复后第二次确认该限制；第三次已完成
  1,934 条匿名化与 VPC 导出，但 HPC 用户无权在 root-owned
  `data/.../anonymised`、`runs/.../eval` 下新建目录。最终增加
  `N019_EVAL_ANON_OUT` 和 `N019_EVAL_OUT` 可配置输出，复用了
  第三次已生成的完整 WAV/VPC，只补 WER/UTMOS/WhiSQA。
- E-VPC/W-NT EER 尚未在新音频上重算，暂不能声明隐私指标；
  下一步优先在同一批 1,934 WAV 上补 EER。

## 0.0.42 2026-11-10 21:15 短退火诊断失败；soup+shrink 进入全量

- 92k 附近 checkpoint 的权重轨迹显示，每 2,000 step 相对权重
  位移约 `0.045–0.047`；相邻位移的余弦为
  `-0.056` 到 `-0.014`，基本正交且略负。这与“在好区域附近
  随机游走/震荡”一致，而不是单方向持续收敛。
- LR `5e-5`、2,000 step 的 d7 HPC 短退火 Job `1085015`
  已于 20:45:28 完成，实际墙钟 25m，loss 有限；保存
  500/1000/1500/2000 四个 generator。该实验只从 92k
  generator 初始化，discriminator/优化器重新初始化。
- 四点在同一 dev、mean32、duration 和 evaluator 下均 UTMOS
  早拒绝：500 `2.9721151125`、1000 `3.0097030640`、
  1500 `3.0385978484`、2000 `3.1208910155`；baseline
  `3.3922259319`。虽然趋势单调改善，但 2k step 远未恢复。
  因此该实验不能单独否定 LR 假设，因为新 discriminator 造成了
  较大 transient；同时也说明不能用“generator-only + 新 D”
  直接代替真实续训。
- 尽管短退火失败，soup+shrink 的 dev 候选仍有效。
  `quad_w40_30_20_10 + shrink0.1` 相对正式 mean32 baseline：
  UTMOS `+0.1205473352`、WhiSQA `+0.0764533620`、WER 0 pp。
  已提交 d7 HPC 完整复评 Job `1085482`
  （`n019_eval_soup2_w40_shrink01_20261110`）：
  `hx1hdnormal`、1 DCU、16 CPU / 60 GB、2 h，预计 0.75、
  最坏 2.0 卡时。输出
  `runs/n019_official/eval/du_pred_nt_soup2_w40_shrink01_20261110`。
  配置已回写 JobID，完成前不替换正式结果。

## 0.0.41 2026-11-10 20:20 soup+shrink 双 MOS 提升；短退火诊断启动

- 第二轮 soup Job `1084628` 已完成，历时 50m42s。相对正式
  `avg88_92`，最值得保留的结果：
  - `quad_w40_30_20_10`：UTMOS `+0.0757472384`、
    WhiSQA `+0.0174215630`、WER `0 pp`；
  - `quad_plus90_10`：UTMOS `+0.0587908280`、
    WhiSQA `+0.0258395135`、WER `+0.2284148013 pp`；
  - `quad_cross_equal`：UTMOS `+0.0613249838`、
    WhiSQA `+0.0220772654`、WER `-0.0913659205 pp`。
  仍没有候选相对 shrink baseline 达到 WhiSQA `+0.05`。
- 将 soup 与已核验的 `shrink0.1` target embedding 组合后，
  d7 HPC Job `1084912` 完成，历时 8m56s。`shrink0.1` 是
  向 target 全局均值收缩再 L2 normalize，不是向源说话人泄漏。
  相对当前正式 mean32 baseline：
  - `quad_w40_30_20_10 + shrink0.1`：UTMOS `3.5127739525`
    （`+0.1205473352`），WhiSQA `3.4313993633`
    （`+0.0764533620`），WER `6.1215166743%`（0 pp）；
  - `quad_plus90_10 + shrink0.1`：UTMOS `3.4973348951`，
    WhiSQA `3.4374276802`，WER `6.2585655550%`；
  - `quad_cross_equal + shrink0.1`：UTMOS `3.4879527950`，
    WhiSQA `3.4275449798`，WER `6.2128825948%`。
  第一个候选在 dev 上同时明显提高双 MOS 且 WER 不退化，等待
  d7 HPC 空闲后做完整 1,934 句复评。
- 针对“后段学习率衰减不足”假设，已建 d7、HPC
  Job `1085015`（`n019_lr5e5_2k_d7_20261110_2020`）：
  `hx1hdnormal`、1 DCU、16 CPU / 60 GB、1 h，预计 0.5、
  最坏 1.0 卡时。从 d5 92k generator
  SHA256 `f203505cdfc90df0a77b37c3c08870dd7421f076aad226ba3429937aa8ee72f7`
  初始化，新开 D/optimizer，LR `5e-5`，只跑 2,000 step，
  每 500 step 保存 snapshot。输出
  `runs/n019_official/vocoder_nt_hpc_lr5e5_2k_from92k_20261110`。
  配置记录在
  `configs/scnet_d7_hpc_lr5e5_2k_from92k_20261110.json`。

## 0.0.40 2026-11-10 19:12 model soup 第一轮有效，第二轮补 WhiSQA

- 第一轮 d7 HPC Job `1084433` 已完成，历时 18m42s。baseline
  UTMOS/WhiSQA/WER 为 `3.3922265303 / 3.3549458414 /
  6.1215166743%`。12 个候选中 3 个通过 UTMOS 首筛：
  - `quad_84_88_92_96`：UTMOS `3.4503521085`
    （`+0.0581255782`），WhiSQA `3.3788125813`
    （`+0.0238667399`），WER `6.2585655550%`
    （`+0.1370488808 pp`）。
  - `triple_84_88_92`：UTMOS `3.4432123804`，
    WhiSQA `3.3774370834`，WER `6.3042485153%`。
  - `cross_equal_d5d6_88_92`：UTMOS `3.4424616623`，
    WhiSQA `3.3498103991`，WER `5.5276381910%`。
  三者 WER 均在 gate 内，但 WhiSQA 未达到 `+0.05`，故
  `selection.json` 仍选正式 `avg88_92`。第一轮证明把较早
  84k 与 96k 邻域一起做 soup 可同时提高双 MOS，不能忽略。
- 已按互补性生成第二轮 12 个候选：
  - 84/88/92/96 四点的 40:30:20:10、35:30:20:15、
    30:30:25:15、30:35:20:15 权重；
  - 84/88/90/92/96、84/88/92/94/96 五点 soup；
  - 84/88/90/92/94/96 六点 soup；
  - 第一轮四点在 90k、94k、d6 88/92 上分别加 10%；
  - 第一轮四点加 d6 88/92 共 20%；
  - 第一轮四点与 `cross_equal_d5d6_88_92` 各 50%。  
  完整 SHA256 见
  `configs/scnet_d7_hpc_soup2_20261110.json`。
- 提交 d7 HPC Job `1084628`（`n019_soup2_20261110_1912`）：
  `hx1hdnormal`、1 DCU、16 CPU / 60 GB、2 h，预计 0.75、
  最坏 2.0 卡时。输出
  `runs/n019_official/vocoder_selection_soup2_20261110`，
  仍使用 UTMOS 首筛、双 MOS 各 `+0.05`、WER 回归不超过
  `0.25 pp` 的固定 gate。

## 0.0.39 2026-11-10 18:47 零训练 model soup 搜索

- d7 HPC Job `1084308` 已完成，baseline 与 144k/146k 均为
  UTMOS 早拒绝：baseline `3.3922255003`，144k
  `3.3054394627`（`-0.0867860377`），146k
  `3.0862702608`（`-0.3059552395`）。不进入 WhiSQA/WER
  或完整复评。
- 用户要求不再长训练来提升 MOS。已转入纯 inference/weight-space
  搜索：复制 d5 84k/86k 和 d6 88k/92k 到 d7，源/本机/d7
  SHA256 一致（84k `8628ef27…25a5`、86k `7adf34d7…b883`、
  d6 88k `7002acda…a46f`、d6 92k `0abc8cee…caa2`）。
- 已在零训练条件下生成 12 个候选：88/92 的 40:60 与 60:40
  effective-weight-norm 插值，84/88/92、86/88/92、
  88/90/92、88/92/94 三点 soup，84/88/92/96 与
  88/90/92/94 四点 soup，d5/d6 88/92 等权与 2:1/3:1
  组合，以及 raw 88/92。所有候选 SHA256 记录在
  `configs/scnet_d7_hpc_soup12_20261110.json`。
- 提交 d7 HPC Job `1084433`（`n019_soup12_20261110_1847`）：
  `hx1hdnormal`、1 DCU、16 CPU / 60 GB、2 h，预计 0.75、
  最坏 2.0 卡时。baseline 是正式 `avg88_92`；先在正确
  40-speaker dev-100 上只评 UTMOS，通过 `+0.05` 门槛者再评
  WhiSQA/WER，WER 回归上限 `0.25 pp`。输出
  `runs/n019_official/vocoder_selection_soup12_20261110`。

## 0.0.38 2026-11-10 18:17 d6 138k/140k 继续低于基线

- 零卡时核对发现 d7 HPC 的 FP32 旧分支 Job `1071460`
  实际仍在运行，已按“只保留更好训练线”的用户要求于
  18:28:19 主动停止；`sacct` 为 `CANCELLED+`，墙钟
  `23:33:12`。停止时日志 step `75,860`，loss 有限，
  snapshots 到 74k，`last.pt` SHA256
  `93953895bbb4cc7684802ad349b560e6241483f425ef23c629e841da57c80b2a`。
  该 FP32 分支的 2k/8k/10k dev 已明确低于主线，因此不保留续训。
- d7 AI 余额已不足以再跑完整选模；改用 HPC 免费额度。先把
  144k/146k 经本机中转至 d7 并逐项核对 SHA256：
  144k `93ef9e9f57b18cd4b81c564922a75326033bf45adf7dcb5ae8083e0736501a75`，
  146k `8d344ee824ab47c884aa3b98ffc6b57a607521655a6a9baae8a6d4f696f2bb76`。
- 提交 d7 HPC Job `1084308`
  （`n019_d6s144146_20261110_1829`）：`hx1hdnormal`、
  1 DCU、16 CPU / 60 GB、2 h 外层，预计 1.0、最坏 2.0 卡时；
  节点 `f11r2n02`，18:33:03 启动。比较正式 `avg88_92` 与
  d6 144k/146k，固定同一 40-speaker dev、mean32 target、
  预测时长和三项 evaluator。输出
  `runs/n019_official/vocoder_selection_d6_144146_20261110`，
  配置已记录为 `submit:false`。

- d6 138k/140k 已逐项从 d6 经本机中转至 d7，源/本机/d7
  SHA256 分别一致：138k
  `9f1a0f939d12b8850f3cc8d6d3c8be4d8cf1361a5c0172c96c903ac67543fad3`，
  140k `e294cccd50f4720a685661527c24e1c6bf37e9ceff329c9c4ff4cc544e8d11ce`。
- 提交 d7 AI Job `2120083780839763970`
  （`n019_d6s138140_20261110_171847`）：1 DCU、15 CPU / 59 GB、
  1.0 h，预计 0.5、最坏 1.0 卡时；提交前余额
  `1.1558333329`。固定同一 40-speaker dev、mean32 target、
  预测时长和三项 evaluator，配置已回写 JobID 并设
  `submit:false`。
- baseline 为 UTMOS/WhiSQA/WER
  `3.3922264612 / 3.3549451292 / 6.1215166743%`。
  - 138k UTMOS `3.2405943727`，delta `-0.1516320884`；
  - 140k UTMOS `3.2434509814`，delta `-0.1487754798`。
  两者均在 UTMOS 早拒绝，未进入 WhiSQA/WER 或完整复评。
- `selection.json` 仍选择正式 `avg88_92`，SHA256
  `bd1370927b67a0bcf07d9ba14d5e762b1703e5a124e0aa4f0378ff9f2cf566e8`。
  当前证据表明 92k 之后单 checkpoint 已进入 MOS 平台/轻微退化区；
  不再机械地对每个 2k snapshot 花费完整 baseline 选模。后续优先
  观察更大间隔（如 +8k）或相邻 checkpoint 平均，只保留单一训练线。

## 0.0.37 2026-11-10 16:55 d6 134k/136k dev 均未通过

- d6 HPC Job `1076707` 是当前唯一训练任务。16:52 日志 step
  `137,960`，约 `0.6808 s/step`，loss 有限；snapshots 已到
  138k。
- 已提交 d7 AI Job `2120074457103839233`
  （`n019_d6s134136_20261110_164144`）：1 DCU、15 CPU / 59 GB、
  1.0 h，预计 0.5、最坏 1.0 卡时；提交前实时余额
  `1.3336111107`。固定正确 40-speaker dev-100、96-target map、
  mean32 target embedding、预测时长和同一三项 evaluator；
  配置已回写 JobID 并设 `submit:false`。
- baseline 正式 `avg88_92` 的 dev-100 为 UTMOS/WhiSQA/WER
  `3.3922263992 / 3.3549448937 / 6.1215166743%`。
  - d6 134k：UTMOS `3.3342647171`，delta `-0.0579616821`，
    触发 early reject；
  - d6 136k：UTMOS `3.1620127070`，delta `-0.2302136922`，
    触发 early reject。
  两候选均未评 WhiSQA/WER，不能进入完整 1,934 句复评。
- 100 句 UTMOS 配对统计：134k delta `-0.0579616821`，SE
  `0.0307052225`，95% CI `[-0.1188808436, +0.0029574794]`，
  48/100 句提升；属于小幅、不显著的回归。136k delta
  `-0.2302136922`，SE `0.0380565449`，95% CI
  `[-0.3057178773, -0.1547095071]`，仅 28/100 句提升，
  是明确退化。后者比前者更能说明当前训练后段质量下降；
  但仍不据此直接停止单一长训，先继续观察 140k。
- `selection.json` 仍选择正式 `avg88_92`，SHA256
  `d23c5e52b9b2d7062abcbac1da539a892529d973b77b9b7ad6cbd5373f836f51`；
  `selection.md` SHA256
  `dbe3ed036b12d1571df2b4bf9bd14cbd208b8e5c8a78f8d34507e1bbd4ad023f`。
- 继续保留 d6 单训练线，等待 140k 等后续 snapshot 做滚动筛选；
  不因单个 136k 点低于 baseline 就重复提交训练或修改正式结果。

## 0.0.36 2026-11-10 12:50 只保留较优训练分支

- 用户要求不要并行保留多条训练线，只保留结果更好的分支继续训练。
- d5 HPC Job `1076668` 已由平台在 12:21:14 终止，`sacct`
  状态 `CANCELLED+`，累计墙钟 `06:00:14`，snapshot 到 114k。
  不再重提。
- d6 AI utterance-level 分支 Job `2119994244055973889` 已在
  12:50:07 主动停止，平台状态已确认“已停止”。停止依据：
  108k utterance-dev UTMOS `3.24816`，明显低于同一 dev 的
  speaker-mean baseline `3.39223`；继续该分支不符合“保留更好
  结果”的要求。日志到 step `111,660`；最后持久完整
  `last.pt` 为 12:41 写入，SHA256
  `2a6f326f11996ff4e7e979795d7ce25bb48df967fdce9a5a836ecfaaf254d3f8`。
- 现在唯一运行的模型训练 Job 是 d6 HPC
  `1076707`（`n019_vocd6_cont34h`），12:50 日志 step
  `116,720`，约 `0.68 s/step`，loss 有限，snapshots 到 116k。
  保留该 speaker-mean 主线继续训练。
- 原计划 utterance 112k 选模配置
  `configs/scnet_d6_vocsel_uttemb112_20261110.json` 已取消，
  `submit:false`；不得提交。

## 0.0.35 2026-11-10 12:31 跨分支 112k 平均筛选

- 已把 d5/d6 两条从同一 hpclong 状态分叉的 112k generator
  复制到 d7，源/目标 SHA256 一致：d5
  `fbd9c5113bca0f5d712675e48d9ff61c276be59a557d03088e2542c7b695320a`，
  d6 `47820dfa7d9883df8d213ddcff72bae5b2a20ddabbb533becce4179ed19475e7`。
- 跨分支 checkpoint 的 config 只差 `max_hours`（42.25 vs 34.0），
  generator architecture 和 state keys 相同；因此扩展了
  `scripts/average_vocoder_checkpoints.py`，新增显式
  `--allow-nonarchitectural-config-diff`，默认仍要求完整 config
  相同，并新增 architecture/state-key 测试。脚本 SHA256
  `fe55a9923556b4f2de490c60aaa469fb351fb42ebbb27c1b707d135e8c115d12`；
  指定测试 `19 passed`。
- 生成三个 effective-weight-norm 候选：
  `cross_88_92_d5d6_112` SHA256
  `c7c116d94c3b8c173eca5b4dba65bd24bf56f49abde42e5c533160006e5a5ef6`；
  `cross_88_92_d6_112` SHA256
  `564709c7dfd5cc9c01efff0a7c86c0113fec1e5b8a54c0d1fe947e0d02e1c754`；
  `cross_d5d6_112` SHA256
  `71c3a88302dd6b10f75b5f84f257bc03f1f10b55d90a13949bd308bc317dfdc0`。
- 提交 d7 AI Job `2120011373956190209`
  （`n019_voccross112_20261110_123105`）：1 DCU、15 CPU / 59 GB、
  1.0 h，预计 0.5、最坏 1.0 卡时；提交前 d7 余额
  `1.9797222218`。正确 40-speaker dev，UTMOS 早拒绝，通过后
  再补 WhiSQA/WER。配置已回写 JobID 并设 `submit:false`。

## 0.0.34 2026-11-10 12:24 utterance 108k 早期不胜出

- d6 AI 选模 Job `2120005445911465985` 完成。正确 40-speaker
  dev-100 上，正式 `avg88_92` baseline UTMOS
  `3.3922258556`；utterance-level 微调 108k 为
  `3.2481592941`，delta `-0.1440665615`，UTMOS 早拒绝，
  未评 WhiSQA/WER，也不能进入全量复评。
- 这不是立即停止训练的理由：108k 只比共同分支点 104k 多
  4,000 step，切换训练/推理 embedding 口径后可能处于适应期；
  当前 loss 仍有限，训练推进到约 step `109,700`。后续在
  112k、116k 等 snapshot 上重复同一 dev 检查；若持续低于
  baseline，将提前停止，不为该分支耗尽全部 5 h。
- 配置 `configs/scnet_d6_vocsel_uttemb108_20261110.json`
  状态改为 `completed_utmos_rejected_20261110_1224`，
  `submit:false`，不得重复提交。

## 0.0.33 2026-11-10 12:15 加权平均仍不胜出

- d7 Job `2120004844019294210` 已完成。三个加权平均中：
  - `w92x50_106x50` UTMOS `3.4254162288`，
    相对 baseline `+0.0331904066`，early reject；
  - `w88x15_92x25_106x60` UTMOS `3.4421379781`，
    `+0.0499121559`，以 `8.8e-5` 之差 early reject；
  - `w88x20_92x20_106x60` UTMOS `3.4431574130`，
    `+0.0509315908`，通过 UTMOS；但 WhiSQA
    `3.3511320561`，相对 `3.3549456418` 为 `-0.0038135856`，
    且 WER `5.7560529922%`（改善 `0.3654636820 pp`）。
    因 WhiSQA 未达到 `+0.05`，最终 `eligible=false`。
- `selection.json` 仍选择正式 `avg88_92`，不得用该加权候选
  进入完整 1,934 句复评。结论：单纯调整 88/92/106 权重不能
  填平 UTMOS/WhiSQA 差距，继续等待 utterance-level 训练和
  更长 checkpoint。

## 0.0.32 2026-11-10 12:05 106k 加权平均筛选

- 首个扩展平均 Job `2119985822010404865` 已完成。baseline
  `avg88_92` 的 dev-100 为 UTMOS/WhiSQA/WER
  `3.3922258222 / 3.3549456418 / 6.1215166743%`。
  各候选的 UTMOS 及相对 baseline 差值：
  - `avg88_92_100`：`3.4319149876`，`+0.0396891654`
  - `avg88_92_102`：`3.4035132003`，`+0.0112873781`
  - `avg88_92_100_102`：`3.4273676348`，`+0.0351418126`
  - `avg88_92_106`：`3.4404903388`，`+0.0482645166`
  - `avg88_92_96_100_102_106`：`3.4315163684`，`+0.0392905462`
  所有候选都未达到预声明 UTMOS `+0.05`，因此均 early reject；
  `avg88_92_106` 只差 `0.0017354834`。不放宽门槛。
  对 `avg88_92_106` 与 baseline 的 100 句 UTMOS 做配对统计：
  mean delta `+0.0482645166`，paired SD `0.1984581053`，
  SE `0.0198458105`，t `2.4320`，95% CI
  `[+0.0088904, +0.0876386]`。这支持“方向可能真实”，
  但仍不满足预先声明的选模门槛，不能事后降低门槛。
- 已生成三个受控加权候选并回读 SHA256：
  - `avg_w92x50_106x50`：
    `fe458362bc111e33aa76eeafba19df1327af4911de10b4ad0e6cf114ef28f6b5`
  - `avg_w88x20_92x20_106x60`：
    `5757267205b3140faf6d34b7de728d69c7a5264f57c2b6d82e57bedb972762ce`
  - `avg_w88x15_92x25_106x60`：
    `f65eef100242680387b2ddc32f026923de56032a3b3af2306ac26e3304eb081f`
- 提交 d7 AI Job `2120004844019294210`
  （`n019_voc106wt_20261110_120509`）：1 DCU、15 CPU / 59 GB、
  1.0 h，预计 0.4、最坏 1.0 卡时；提交前 d7 余额
  `2.1566666662`。复用同一 dev/output，UTMOS 早拒绝后仅对
  通过者补 WhiSQA/WER。配置已回写 JobID 并设 `submit:false`。
- utterance-level 微调 Job `2119994244055973889` 已于 12:02
  到 step `108,080`，约 `0.77 s/step`，loss 有限，108k
  snapshot 已落盘。d5/d6 HPC 主线分别约 step `112,540 /
  112,640`，最新 snapshots 至 112k，运行正常。
- 另提交 d6 AI Job `2120005445911465985`
  （`n019_utt108sel_20261110_120732`）：1 DCU、15 CPU / 59 GB、
  1.0 h，预计 0.5、最坏 0.85 卡时，与 5.0 h 微调并行；当前
  d6 余额 `6.7469444443`，两项最坏合计 6.35 h，可覆盖。
  在正确的 40-speaker dev 上比较正式 `avg88_92` 与
  utterance-level 微调 108k，先 UTMOS 早拒绝，通过后再补
  WhiSQA/WER。108k SHA256
  `8a887cb2b3f220cf94e304efc00566a171041ccecac8adf724c0d5cb3df15c44`；
  配置已回写 JobID 并设 `submit:false`。

## 0.0.31 2026-11-10 11:23 utterance-level 微调已启动

- 100-step smoke 已验证 utterance-level 训练数据路径：实际读取
  33,236 条 records 和 33,236-key embedding archive，首个 batch
  `codes=(16,28)`、`waveform=(16,8960)`，step 20/40/60/80/100
  loss 全部有限，step 100 写出完整 `last.pt`。`meta.json` 明确记录
  `embedding_level=utterance`。
- smoke 最终平台退出码为 1，不是训练链路失败：为缩短 smoke 将
  `keep_interval` 设为 0，step 100 正常结束后触发
  `ZeroDivisionError: integer modulo by zero`。该 checkpoint 已
  保留，但后续任务使用非零 keep interval，不能重复提交该 smoke。
- 已将 d5 的完整 step 104,000 训练状态经本机中转至 d6；
  源/本机/d6 SHA256 均为
  `95aa744c27590f4dcddcb18b60ae40d9cdbbf8060a7f64f66128586f961ac14b`。
  这作为受控分支点，d5/d6 HPC 主线继续 speaker-mean 训练，
  d6 AI 分支只切换为 utterance-level embedding。
- 已提交 d6 AI Job `2119994244055973889`
  （`n019_uttft5h_20261110_112302`）：1 DCU、15 CPU / 59 GB、
  5.5 h 外层、内部 `MAX_HOURS=5.0`，预计 4.8、最坏 5.5 卡时；
  提交前 d6 余额 `7.0213888887`。输出
  `runs/n019_official/vocoder_nt_uttemb_ft_20261110`，每 2k step
  保存 snapshot，启用 stage trace 和 600 秒 stack dump。
- 配置 `configs/scnet_d6_utterance_ft_5h_20261110.json` 已回写
  JobID 并设 `submit:false`，严禁重复提交。smoke 配置
  `configs/scnet_d6_utterance_smoke_20261110.json` 同样保持关闭。

## 0.0.30 2026-11-10 11:04 完整 utterance embedding 与训练口径 smoke

- 逐句 NT embedding shard1/shard2 均已正常收尾，各 9,212 条。
  完整合并输出
  `data/n019_official/processed/embeddings/libritts_train_clean_100_nt_utterance_merged_20261110`：
  `33,236` keys、250-D、全部 finite、unit norm
  `0.99999988–1.00000012`，canonical manifest SHA256
  `5d3bb4d7bc41cfd973d9313b84b3faae32c3a3abcb572a03153badfa7669e50d`，
  embeddings SHA256
  `20c36171f534342c04831fb169010b81474cecad2e66443016696d06d067eb49`。
  5,600 条 base-partial 与 shard0 重叠向量逐位一致。
- 已提交 d6 AI smoke Job `2119989494043471873`
  （`n019_uttftsmoke_20261110_110409`）：1 DCU、15 CPU / 59 GB、
  0.5 h，预计 0.15、最坏 0.5 卡时；提交前 d6 余额
  `7.0213888887`。只跑 100 steps，从当前正式 `avg88_92`
  generator 初始化，训练时显式使用 utterance-level embedding。
- 目的：验证 `[unit embedding, per-utterance NT embedding]`
  训练链路；若通过，再启动受控微调做 speaker-mean vs
  utterance-level A/B。smoke 配置
  `configs/scnet_d6_utterance_smoke_20261110.json` 已回写 JobID
  并设 `submit:false`，严禁重复提交。

## 0.0.29 2026-11-10 10:49 扩展 checkpoint 平均选模已提交

- 98k/100k/102k 及三个新平均候选已从本机逐项校验并复制到 d7；
  d7 回读 SHA256 与生成端一致。三个候选为
  `avg88_92_100`、`avg88_92_102`、
  `avg88_92_100_102`（effective-weight-norm 等权）。
- 已提交 d7 AI Job `2119985822010404865`
  （`n019_vocsel40_d5avg_ext_20261110_104934`）：
  1 DCU、15 CPU / 59 GB、1.5 h，预计 0.9、最坏 1.5 卡时；
  提交前实时 d7 余额 `3.2297222218`。
- 固定 checkpoint 平均的当前正式基线 `avg88_92`，正确
  40-speaker、96-target dev-100，mean32 target embedding、
  predicted duration 和同一 UTMOS/WhiSQA/WER evaluator。
  启用 `N019_SELECTION_EARLY_REJECT_UTMOS=1`；同步后的 d7
  selection 脚本 SHA256
  `36b8a6c6f7fa7fdc9cba459ee98f244708e546fba1f421a08392d169f4851f73`。
- 输出
  `runs/n019_official/vocoder_selection_40spk_d5_avg8892_vs_100102_20261110`；
  配置 `configs/scnet_d7_vocsel40_d5_avg8892_ext100102_20261110.json`
  已回写真实 JobID 并设 `submit:false`，严禁重复提交。
- 门槛仍为候选相对 `avg88_92` 的 UTMOS、WhiSQA 各至少
  `+0.05`，且 WER 回归不超过 `0.25 pp`。只有通过 dev gate
  的候选才可进入完整 1,934 句复评。
- d5/d6 续训在 10:50 左右分别到日志 step `106,240 / 106,320`，
  最新持久 `last.pt` 均为 `104,000`，loss 有限，约
  `0.68 s/step`；d5 的 106k snapshot 已落盘。
- d5 106k generator SHA256
  `c597aa294523f1fc8333cf4a8d162de7ca1323f1062f8da5e7830cd434aa6182`，
  已经本机中转至 d7，源/本机/d7 回读一致。已在 d7 零卡时生成：
  - `generator_avg_88_92_106_effnorm.pt`，SHA256
    `5f44e6942a3bac6ed6bdb94b71cb3f0d4e0ce4869e3aea3966a2c50a50f9095e`；
  - `generator_avg_88_92_96_100_102_106_effnorm.pt`，SHA256
    `3f842a8a9adb9b6d0ae9cefd2905c7e48ea14d7dd96f4e54dbf82570713de3a4`。
  这两个候选只作为当前 Job 未通过时的 fallback，
  配置 `configs/scnet_d7_vocsel40_d5_avg8892_106_broad_20261110.json`
  仍为 `submit:false`，尚未提交。

## 0.0.28 2026-11-10 10:41 checkpoint 平均成为新正式结果

- Job `2119976635173982210` 已完成 88k/92k effective-weight-norm
  等权平均的完整 official `libri_test` 1,934 句复评，新的正式最优为：

| 指标 | 平均模型 | 论文 | 与论文差 | 相对 88k |
|---|---:|---:|---:|---:|
| WER | **6.2211061012%** | 7.41% | -1.1888938988 pp | **-0.1541007933 pp** |
| UTMOS | **3.3997926173** | 3.63 | -0.2302073827 | **+0.1044138844** |
| WhiSQA | **3.3985530013** | 3.69 | -0.2914469987 | **+0.0554158402** |

  相对 54k，UTMOS/WhiSQA 已提升 `+0.1996578800 /
  +0.2023156020`；WER 仍优于论文，但比 54k 差
  `0.0228297472 pp`。计数为 WER 1,496、UTMOS/WhiSQA 各
  1,934。
- checkpoint SHA256
  `fafe5982588bea492dd761f1c2d51cc925474503a4f158cf1680667b2286ded8`。
  `quality_metrics.json` SHA256
  `582f345de4273d5b0ca32a721925b6317b0684e3ca5742992076a2971b7b207e`，
  WER `1f01b33bff682597aa99e6dc5f62a5d5f0e96a302c459210b5280639498a9d15`，
  UTMOS `776356a7edd3aa7e484f1f339d8ee0c0bdb532f4650e772e54ea7457219240bc`，
  WhiSQA `0e00b0d221ad7e6ffa62a243bd91ceb8bcc8ccf6c7f129cacdd8700fdbdd2dc1`。
  结果目录
  `runs/n019_official/eval/du_pred_nt_hpclong_d5_avg88_92_effnorm`。
- 结论：GAN checkpoint 的 effective-weight-norm 平均明显优于
  任一单点 88k/92k，是当前最有效的残余差距修复之一。下一步继续
  测试 98k/100k/102k 与 88k/92k 的受控平均，并等待逐句
  embedding 训练口径 A/B。

## 0.0.27 2026-11-10 08:43 d5 88k 新正式结果

- Job `2119947801308733442` 已完成完整 official `libri_test` 1,934
  句复评。新的正式最优为：

| 指标 | 88k | 论文 | 差值 | 相对 54k |
|---|---:|---:|---:|---:|
| WER | **6.3752068946%** | 7.41% | -1.0347931054 pp | +0.1769305405 pp |
| UTMOS | **3.2953787330** | 3.63 | -0.3346212670 | **+0.095244** |
| WhiSQA | **3.3431371611** | 3.69 | -0.3468628389 | **+0.1468997617** |

  UTMOS 精确增量为 `3.295378732952485 - 3.200134737291898 =
  +0.095243995660587`；WER 仍优于论文，但相对 54k 回退
  `0.176930540494264 pp`。计数为 WER 1,496、UTMOS/WhiSQA 各
  1,934。
- checkpoint SHA256
  `c8744739ddbecf9075c10470f9b495ca8368e1bba645bd9cda28302a3555701a`；
  `quality_metrics.json` SHA256
  `585af02febd1de622f8f12392ee7c8c22047084bc2b6fa1049f7c8ad41e76c8b`，
  `WER.json` SHA256
  `2f42e85471560f784fa09d5ee88883a23b0e8f34a8fa9d47cc6bdee10a4a0d9a`，
  UTMOS SHA256
  `4afccf4e3d5c091ef8985cd68e3093c5222713d954e4906f579d66f595e674d1`，
  WhiSQA SHA256
  `f81707269ad7813a1a30ed368563cdd3818b003b354b898a141ad9e8e088f50d`。
  `anon.jsonl` SHA256
  `d94173feb5932d54166314d4a14ece78b6dc5444f3aaf9f7a6e8119937439201`。
- 结果目录
  `runs/n019_official/eval/du_pred_nt_hpclong_d5_step88000_mean32`。
  90k/92k 滚动选模 Job `2119948401442332673` 仍在运行；若其通过
  88k baseline gate，再做完整复评。
- 08:50 90k 的 dev UTMOS 为 `3.2506227565`，比 88k baseline
  `3.2961353779` 低 `0.0455126214`，已经不可能通过双 MOS
  `+0.05/+0.05` gate；该 Job 继续自动评 92k，不重跑 90k。
- 94k/96k 快照已生成并逐项本机中转至 d7，源/本机/d7 SHA256 一致：
  94k `8b8a193d215d86dddcb43553a9fa07205d53b65dc0fd6f38ac30356634224ab3`，
  96k `1cdd25714d2a2d4709df0d8903e9760888f6a5161f4ce76fc105241b068358a3`。
  已提交第二个 d7 选模 Job `2119956845166292994`
  （`n019_vocsel40_d5s9496_20261110_085427`）：1 DCU、
  15 CPU / 59 GB、1.5 h，预计 0.9、最坏 1.5 卡时；与 90/92
  Job 并行，baseline 仍是 88k。配置已设 `submit:false`。
- 逐句 NT embedding shard0 已完成并严格核验：manifest 9,212、
  NPZ 含 base+shard 共 14,812 keys、250-D、finite、unit norm；
  NPZ SHA256
  `9329f8e7f6872f62837a06ca8d4ada1a80e66700da5bf56264d01830da0dd69a`。
  shard2 Job `2119956243665928193`
  （`n019_ntutt_s2_20261110_085204`）已在 d6 启动：
  1 DCU、15 CPU / 59 GB、5.5 h，预计 5.0、最坏 5.5 卡时；
  提交前 d6 余额 `12.8902777775`。
- 90k/92k 选模已完成并选择 88k baseline。90k：
  UTMOS/WhiSQA/WER `3.2506227565 / 3.2866789535 /
  5.8931018730%`；92k：
  `3.3259529352 / 3.2646234110 / 6.3956144358%`。
  92k 相对 88k 只有 UTMOS `+0.0298175573`、WhiSQA
  `-0.0174747750`，不通过双 MOS `+0.05` gate。
- 94k：UTMOS/WhiSQA/WER 为
  `3.2928789449 / 3.2841303170 / 6.7153951576%`，相对 88k
  UTMOS `-0.003256`、WhiSQA `+0.002032`、WER
  `+0.365464 pp`，三项 gate 均失败；96k 继续评分。
- 新增 checkpoint effective-weight-norm 平均候选，均从 88k/92k
  生成并逐项校验后复制到 d7：
  - 50/50 `generator_avg_88_92_effnorm.pt`，SHA256
    `fafe5982588bea492dd761f1c2d51cc925474503a4f158cf1680667b2286ded8`；
  - 88k 75% / 92k 25%
    `generator_avg_88x75_92x25_effnorm.pt`，SHA256
    `eae2161f012e98ebe7bb30071789b2b2315d59cb453fb19b75985c9c9197e8ed`。
  已提交 Job `2119962502553157634`
  （`n019_vocsel40_d5avg8892_20261110_091656`）：d7、
  1 DCU、15 CPU / 59 GB、1.5 h，预计 0.9、最坏 1.5 卡时；
  88k baseline，三项指标同协议比较。提交前 d7 余额
  `5.1730555552`，配置已设 `submit:false`。
- **等权平均 88k/92k 通过 dev gate，并已启动完整复评。**
  88k baseline 为 UTMOS/WhiSQA/WER
  `3.2961348867 / 3.2820984185 / 6.3499314756%`；50/50
  effective-weight-norm 平均为
  `3.3922256935 / 3.3549457431 / 6.1215166743%`，delta
  `+0.0960908067 / +0.0728473246 / -0.2284148013 pp`，
  三项全部通过。75/25 平均只有 WhiSQA `+0.048922384`，
  差 `0.001077616` 到门槛，不可选。
- 已提交完整复评 Job `2119976635173982210`
  （`n019_d5_avg8892_effnorm_20261110_101303`）：d7、
  1 DCU、15 CPU / 59 GB、2 h 外层 SIGKILL，预计 0.9、
  最坏 2.0 卡时；提交前 d7 余额 `3.6772222218`。
  checkpoint SHA256
  `fafe5982588bea492dd761f1c2d51cc925474503a4f158cf1680667b2286ded8`。
  输出 suffix/目录中的 label 为 `hpclong_d5_avg88_92_effnorm`。
  配置已回写 JobID 并设 `submit:false`，完成前不替换 88k 正式值。
- 新增选模脚本可选功能
  `N019_SELECTION_EARLY_REJECT_UTMOS=1`：候选 UTMOS 无法达到
  `+0.05` 时直接写 `early_reject.json` 并跳过 WhiSQA/WER，
  用于后续高噪声 checkpoint 滚动筛选，节省约 2/3 选模时间。
  默认关闭；脚本 SHA256
  `36b8a6c6f7fa7fdc9cba459ee98f244708e546fba1f421a08392d169f4851f73`，
  相关测试 `14 passed`。

## 0.0.26 2026-11-10 07:55 utterance-conditioning 启动门禁与 88k 选模进度

- **88k 已通过正确 40-speaker dev gate，并已启动完整 1,934 句复评。**
  同一 speaker-disjoint dev-100 上，54k baseline 为
  UTMOS/WhiSQA/WER `3.1947042739 / 3.1480606735 /
  6.4412973961%`；88k 为
  `3.2961341763 / 3.2820993334 / 6.3499314756%`，delta
  `+0.1014299023 / +0.1340386599 / -0.0913659205 pp`。
  配对标准误为 UTMOS `0.0271275006`、WhiSQA `0.0164503328`，
  三项均通过预声明门槛。`selection.json` SHA256
  `2ee95c602cf86c436655884bfa96895429e72b45fb8487fd92a72b7978e68bde`，
  `selection.md` SHA256
  `52dd6fb39e65d5bbb45bb4f724e602a3d1276ddc115077b680382f13d691472f`。
- 已提交 d7 完整复评 Job `2119947801308733442`
  （`n019_d5_88k_mean32_20261110_081831`）：人工智能/模型训练、
  1 DCU、15 CPU / 59 GB、2 h 外层 SIGKILL，预计 0.9、最坏
  2.0 卡时；提交前 d7 余额 `6.6038888885`。checkpoint
  SHA256 `c8744739ddbecf9075c10470f9b495ca8368e1bba645bd9cda28302a3555701a`。
  输出为
  `data/n019_official/anonymised/libri_test/DU-pred-nt-hpclong_d5_step88000_mean32`、
  VPC suffix `_n019_hpclong_d5_step88000_mean32`、
  `runs/n019_official/eval/du_pred_nt_hpclong_d5_step88000_mean32`。
  配置已设 `submit:false` 并记录 JobID，严禁重复提交。
- 08:26 已完成 88k 全量匿名化和 VPC 导出：`anon.jsonl` 与
  WAV 均为 1,934，VPC `wav.scp` 1,934、enrolls 438、
  trials_f/m 11,744/9,906。随后进入 WER、UTMOS、WhiSQA；
  完成前不替换正式 54k 结果。
- 同时启动 90k/92k 滚动选模 Job `2119948401442332673`
  （`n019_vocsel40_d5s9092_20261110_082054`）：d7、人工智能/
  模型训练、1 DCU、15 CPU / 59 GB、1.5 h，预计 0.9、最坏
  1.5 卡时。90k/92k snapshot 已经本机中转，源/本机/d7 SHA256
  分别一致：90k `cf6d64fed6637f3f2bbe0a9c11af455fd01c9b7bdbf280cdd219c7f4c8199be2`，
  92k `f203505cdfc90df0a77b37c3c08870dd7421f076aad226ba3429937aa8ee72f7`。
  以 88k 为 baseline，在完全相同的正确 40-speaker dev 上评
  UTMOS/WhiSQA/WER；配置已回写 JobID 并设 `submit:false`。
- d5 Job `1076668`、d6 Job `1076707` 在 07:52 分别到 step
  `90,660`、`90,680`，约 `0.68 s/step`，loss 有限；90k
  generator snapshot 均已落盘。d5 90k SHA256
  `cf6d64fed6637f3f2bbe0a9c11af455fd01c9b7bdbf280cdd219c7f4c8199be2`，
  d6 90k SHA256
  `dcec28bc96054b014997415b76f53600c78e3810ef0815a1d1bb95c3f0cfb003`。
- 正确 40-speaker、speaker-disjoint dev-100 上，d5 54k baseline
  的 UTMOS 已得到：`3.1947042739391325`（100 句）；WhiSQA/WER
  和 88k 仍由 Job `2119937853517742082` 运行中。
- 已修复训练 launcher 的 utterance-conditioned 启动门禁：
  `scripts/run_vocoder_ddp.sh` 新增
  `N019_VOCODER_EMBEDDING_LEVEL=speaker|utterance`，默认仍为
  `speaker`，不再硬编码 `--embedding-level speaker`。相关
  paper-alignment、embedding-shard 和 vocoder 测试共
  `13 passed`，shell syntax 检查通过。该入口用于逐句 W-PRO
  embedding 合并完成后的受控训练口径 A/B，本轮未改正在运行任务。
- 逐句 NT embedding 在 07:52 推进到 shard0 `6,900 / 9,212`、
  shard1 `3,400 / 9,212`；完成后才提交 shard2，并用 canonical
  33,236-key manifest 合并。未使用 d8/d9。

## 0.0.25 2026-11-10 07:40 88k checkpoint speaker-disjoint 对比

- d5/d6 长训均正常：07:34 d5 到 step `89,120`、d6 到
  `89,140`，约 `0.68 s/step`，loss 有限。d5 snapshots 已到 88k。
- d5 88k generator 已通过本机中转至 d7：
  源/本机/d7 回读 SHA256 均为
  `c8744739ddbecf9075c10470f9b495ca8368e1bba645bd9cda28302a3555701a`。
- 已提交 d7 AI Job `2119937853517742082`
  （`n019_vocsel40_d5s88_20261110_073859`）：1 DCU、
  15 CPU / 59 GB、1.5 h，预计 0.8、最坏 1.5 卡时；提交前
  d7 余额 `6.9505555552`。在正确 40-speaker VPC dev-100、
  同一 96-target 映射、预测时长、mean32 target embeddings 下，
  比较 d5 54k baseline 与 88k，评 UTMOS、WhiSQA、WER。输出
  `runs/n019_official/vocoder_selection_40spk_d5_54k_vs_88k_20261110`。
  配置已回写 JobID 并设 `submit:false`，不得重复提交。
- 论文对齐进一步收窄：[26] 原文明确 HuBERT 第 6 层、
  LibriSpeech train-clean-100 上拟合 200 clusters。当前 unit
  配置与 [26] 一致；[32] 的 layer 9 仍保留为次级风险。
- utterance shard0 partial 已含 11,500 keys（5,600 base +
  5,900 shard），shard1 含 2,800 keys；均继续运行。
  未使用 d8/d9。

## 0.0.24 2026-11-10 06:44 修正选模集 speaker bias

- 复核发现近期 checkpoint selection 使用的
  `processed/selection_dev100_2x24k_20261108/manifest.jsonl` 并非文档
  声称的 40-speaker 集：100 句全部来自 clean-100 speaker `1116`。
  对应的 `libri_dev100_target_map_paperfix_seed20261102.jsonl` 也只
  覆盖该单说话人源集合。此前基于这个 100 句集得到的候选排序仍有
  追溯价值，但不能继续作为“40-speaker speaker-disjoint”证据。
- 正确资产是
  `processed/selection_dev100_vpc_units_20261108_retry1/units/unit_records.jsonl`：
  100 句、40 speakers、2–3 句/speaker，时长 `1.8–24.8 s`，
  平均 `7.691 s`。其 `embeddings/nt_speaker_embeddings.npz` 含
  40 个 250-D unit-norm source-speaker embedding。
- 为使正确源集合匹配已经抽取的 96 个目标 speaker，新增确定性映射
  `processed/targets/libri_dev100_40spk_reused_target_map_seed20261102.jsonl`：
  按行把 40-speaker 源集合与旧 100 条 target assignment 对齐。
  SHA256 `f8cc5b8b7b56e6393a05eae360bc7736e29ea77a0fd54e78c4220795fdb72627`；
  本机与 d7 回读哈希一致。该映射只用于 dev 选模，不触碰 official test。
- 新增
  `scripts/diagnose_source_vs_target_dev100_ai.sh`，在正确 40-speaker
  dev 上用同一 54k checkpoint、原时长分别做 source-speaker
  reconstruction 与 random-target anonymisation，评 UTMOS、WhiSQA、
  WER。脚本 SHA256
  `15838580cf2943a8d09ad5d785829a0af9cbcf6e4085ae9f30e0fd528861b894`
  （路径修复后版本）。
- 首次 d7 AI Job `2119923576905814017`
  （`n019_srctgt40_20261110_064216`）只因脚本把 ASR 路径写成
  `asr_n19_local`（实际为 `asr_n019_local`）而在生成前失败；
  GPU watchdog 通过，无 WAV、无指标，不重复该 Job。
- 已提交修正后的 d7 AI Job `2119924762827333633`
  （`n019_srctgt40_r1_20261110_064658`）：1 DCU、15 CPU / 59 GB、
  1.5 h，预计 0.6、最坏 1.5 卡时；提交前 d7 余额
  `7.7244444441`。输出
  `runs/n019_official/source_target_diag40_retry1_20261110`。
  配置已回写 JobID 并设 `submit:false`，不得重复提交。
- 另记录 Unit HiFi-GAN 学习率仍未闭合：DISSC commit
  `4b6160bd3c1733ef01527bf2edaf575788ca60f8` 的公开 vocoder
  配置使用 `8e-4/batch64/2 GPU`，当前实现使用
  `2e-4/batch16/1 DCU`。N019 对 vocoder 引用 [27,32]，不能据此
  断言作者使用 DISSC 的 `8e-4`；待当前长训与判别实验后再决定是否
  做受控 A/B。未使用 d8/d9。
- Retry1 Job `2119924762827333633` 已完成。正确 40-speaker dev-100、
  原时长、同一 54k checkpoint 的结果为：
  - source-speaker reconstruction：UTMOS `3.3275684786`、
    WhiSQA `3.3236708373`、WER `4.4312471448%`；
  - random-target anonymisation：UTMOS `3.1768457067`、
    WhiSQA `3.1102414072`、WER `4.5682960256%`；
  - target - source：UTMOS `-0.1507227719`、
    WhiSQA `-0.2134294301`、WER `+0.1370488808 pp`。
- 结论：即使使用源说话人条件，当前声码器仍比论文低 UTMOS
  `0.3024315214`、WhiSQA `0.3663291627`，这是 vocoder/unit/训练
  配方本身的上限差距；目标条件再损失约 `0.15/0.21`。因此不能只改
  target embedding。详细记录见
  `docs/N019_SOURCE_TARGET_DIAG_20261110.md`。
- `comparison.json` SHA256
  `abb94def914b384353754f789575ad639b98ff55d53078bd7561b594a441b2bf`；
  retry 实际墙钟 `45m11s = 0.753` 卡时，先前路径错误尝试
  `1m15s ≈ 0.021`，总计约 `0.774` 卡时。未使用 d8/d9。

## 0.0.23 2026-11-10 06:30 全量 utterance embedding 合并门禁

- 当前长训正常：d5 Job `1076668` 于 06:28 到 step `83,340`，
  `0.684 s/step`，loss 有限；d7 FP32 Job `1071460` 到 step
  `37,140`，`1.11 s/step`，snapshot 已到 36k。
- d6 embedding shard0 Job `2119908581433954306` 于 06:29 到
  `2,100 / 9,212`，约 `1.08 s/utterance`；shard1 Job
  `2119913793307361281` 到 `500 / 9,212`，当前约
  `2.2 s/utterance`。两者仍为运行中。
- 新增 `scripts/merge_utterance_embedding_sources.py`，解决 shard0
  NPZ 同时包含原始 5,600-key partial 和本 shard keys、但其 shard
  manifest 只描述本 shard 的合并问题。脚本以完整 canonical
  33,236 条 manifest 为 ID 权威，校验 250-D、finite、unit norm、
  canonical membership 和全量覆盖；重叠 key 只有在 float32 向量
  逐位一致时才允许。
- 新脚本 SHA256
  `97444ba6690971258a1f5613eb353874ee34f7ecf5b2cbe721f4e240baabf93d`。
  `test_embedding_shards`、`test_paper_alignment`、`test_units`
  共 `14 passed`。本轮零卡时，未使用 d8/d9。

## 0.0.22 2026-11-10 06:24 hpclong 收尾与 d5/d6 成功接管

- d6 hpclong Job `1069636` 在内部 15.5 h 预算附近正常收尾。
  最终完整 checkpoint `last.pt` 的精确 `step=82934`，
  1,019,512,015 B，mtime `06:20`，SHA256
  `bf7f00f931a27feaa8d7d3ad00c8cb9cf812162e79760afe5a40836af9c8eb0d`。
  最后一个 2k snapshot 是 82k：
  `generator_step00082000.pt` SHA256
  `84c27a40e127495329549ceffcc4f36e4c924a9acca0f729237ff61fb46ada0a`。
- d6 续训 Job `1076707` 已于 06:21 启动，节点 `f11r1n03`；
  `continuation_1076707.json` 记录 resume step `82934` 和上述 SHA256。
  输出仍在同一 hpclong 目录，避免分叉或覆盖旧 checkpoint。
- d5 Job `1076668` 也已于 06:21 在 `f11r1n03` 启动。它已完成
  源 checkpoint 读取、复制和 SHA256 校验：源/目标均为
  `bf7f00f931a27feaa8d7d3ad00c8cb9cf812162e79760afe5a40836af9c8eb0d`、
  source/target step 均为 `82934`。`resume_source.json` 已落盘。
- 两个续训作业当前均 RUNNING；训练日志会在各自 preflight/模型构建后
  追加。d5 使用 42.25 h 内部预算，d6 使用 34.0 h 内部预算。
- 06:23:31 两个作业均从 `step=82935` 进入训练循环；
  06:23:43 均完成首个 generator step，`codes=(16,28)`、
  `waveform=(16,8960)`，loss 有限。d5/d6 首个记录 step `82940`
  的 loss_d/loss_g 分别为 `3.11904/49.01631` 与
  `3.11848/49.01437`，单步约 `0.687 s`；并发同一节点后仍正常。
- utterance shard0/shard1 同时运行；hpclong HPC 结束后 d6 AI 分片并发
  不受影响。未使用 d8/d9。

## 0.0.21 2026-11-10 06:05 FP32 70k 淘汰并释放 d6 并发槽

- d6 FP32 step 70k 在固定 dev-100、target-conditioned 协议下完成
  UTMOS：`3.1845301151275636`。baseline d5 54k 为
  `3.200829032659531`，delta `-0.0162989175`，不可能达到双 MOS
  各 `+0.05` 的门槛，因此不等待 WhiSQA/WER。
- d7 AI 选模 Job `2119909855879315457` 已在约 06:02 停止；
  平台状态 `已停止`。实际约 0.24 h、1 DCU。配置状态为
  `rejected_utmos70k_20261110_0602`。
- d6 AI FP32 分支 Job `2119864730527092738` 自 02:48 运行到约
  06:02，实际约 3.23 h，1 DCU；最后完整 snapshot 为 70k
  （SHA256 `424531f6f8b5cefb91b993e715019b9008fe48077c2ea6973ed52cc87efc072e`）。
  已主动停止以释放 d6 并发槽；d7 HPC FP32 长训 Job `1071460`
  继续保留，不把 70k 的失败外推成“FP32 完全不可用”。
- d6 utterance shard0 进度正常：05:52 已到 100 条，`130.5 s`；
  随后 100→200 用时约 `88.4 s`、200→300 约 `93.9 s`，
  稳定约 `0.9–0.95 s/utterance`。预计约 08:00 完成。
- 并发槽释放后已提交 d6 shard1 Job
  `2119913793307361281`（`n019_ntutt_s1_20261110_060323`）：
  1 DCU、15 CPU / 59 GB、5.5 h，预计 5.0、最坏 5.5 卡时；
  配置已写真实 JobID 并设 `submit:false`。当前 shard0 与 shard1
  两个活动实例并行。
- shard0 完成后再提交 shard2；三个 final NPZ 到齐后严格合并，
  要求 33,236 keys、250-D、finite、unit norm，再做训练口径 A/B。
  d5 HPC `1076668`、d6 HPC `1076707` 仍等待 hpclong 退出。
  未使用 d8/d9。

## 0.0.20 2026-11-10 05:50 utterance embedding 改为分片续跑

- 原 d6 逐句 NT embedding Job `2119894378981191682` 实测约
  `1.8 s/utterance`，按 6 h 墙钟最多只能处理约 12k 条，无法覆盖
  33,236 条。已在 05:40 左右主动停止，实际墙钟约 0.9 h；最后
  `partial_embeddings.npz` 含 5,600 个 key，保留不删。
- 新增 `scripts/shard_resume_utterance_manifest.py`，按完整说话人分组
  去除已完成的 5,600 条，把剩余 27,636 条切成 3 个不相交分片；
  每片正好 9,212 条，共覆盖 199 个剩余 speaker。summary 位于
  `processed/embeddings/nt_utterance_shards_20261110/summary.json`。
- 新增 `scripts/run_nt_utterance_shard_ai.sh`：每个任务先跑 300 秒
  DCU watchdog，再以 `--resume --checkpoint-every 100` 提取 250-D
  utterance embedding，最后把 root-owned 输出 chown 回账号。脚本
  SHA256 `9fc9e74d90d0ee299c08036a6e0a6c7547e3c8f0b4e42c429b1873cc5f00be18`。
- d6 shard0 Job `2119908581433954306`
  （`n019_ntutt_s0_20261110_054240`）已于 05:42 启动：
  人工智能/模型训练、d6、1 DCU、15 CPU / 59 GB、5.5 h 墙钟，
  预计 5.0、最坏 5.5 卡时。它以原 5,600-key partial 为基底，
  再处理 shard0 的 9,212 条；最终预计 14,812 keys。输出
  `runs/n019_official/nt_utterance_shards_20261110/shard_0`。
  05:52 日志显示首个 100 条用时 `130.5 s`，约
  `1.305 s/utterance`；按此估计 shard0 有效计算约 3.34 h，
  预计 09:00 左右完成。
- shard1 首次提交因平台同时已有 2 个活动实例而未创建成功，
  页面停在 add-train，未产生新 JobID 或卡时；配置已关闭，不能把
  它当成训练失败。shard1/2 将在 shard0 或旧 FP32 分支释放并发槽后
  顺序提交。
- d6 旧 FP32 分支 Job `2119864730527092738`
  （`n019_fp32_d6_62k_r1_20261110_024825`）仍运行，05:46 到
  step `70,700`，约 `1.13 s/step`，最后持久 snapshot 为 70k。
  已将 70k generator 经本机中转 d7，三处 SHA256 均为
  `424531f6f8b5cefb91b993e715019b9008fe48077c2ea6973ed52cc87efc072e`。
- 新 d7 dev-100 选模 Job `2119909855879315457`
  （`n019_selfp32d6s70_20261110_054744`）：1 DCU、15 CPU / 59 GB、
  1 h，预计 0.35、最坏 1.0 卡时；提交前 d7 余额 `7.978333333`。
  固定 baseline 54k、mean32、duration 和 evaluator，只评 FP32 70k。
  UTMOS 若不超过 baseline，立即淘汰并考虑停止 d6 FP32 分支以释放
  并发槽。配置已写真实 JobID 并设 `submit:false`。
- d5 HPC `1076668`、d6 HPC `1076707` 仍等待 hpclong 退出。
  未使用 d8/d9。

## 0.0.19 2026-11-10 05:38 零卡时核对 HuBERT layer 风险

- 已下载并核对 N019 引用的 [32]（Kreuk et al., EMNLP 2022）
  PDF：正文明确写 content units 取自 HuBERT **第 9 层**，K=200，
  并在 token extraction 表中以 layer 9/K=200 为高质量配置。
- 当前实现仍使用 layer 6，依据是 N019 另一条引用链
  SSL-SAS/GSLM/speech-resynthesis 的 `output_layer=6`。N019 正文没有
  公开自己的层号，因此 layer 6 与 layer 9 的差异仍是未闭合假设，
  不能声称与作者逐项一致。
- 现阶段不改正在运行的 unit/vocoder 数据，因为 layer 9 会要求重新
  提取全部 units、重新拟合 K=200 codebook、重新训练 duration 和
  vocoder，属于高成本分支。只有当前 400k-equivalent 训练与
  utterance-embedding/FP32 审计仍无法缩小 MOS 差距时，才安排
  layer 9 的成对判别实验。
- 已把该风险写回 `configs/paper_algorithm_v1.json` 和
  `docs/PAPER_ALIGNMENT_CHECKLIST.md`，避免后续 AI 把 layer 6
  当成论文明确参数。
- JSON 解析通过；`tests/test_paper_alignment.py` 与
  `tests/test_units.py` 共 `10 passed`。

## 0.0.18 2026-11-10 05:36 FP32 28k 提前淘汰

- d7 FP32 dev-100 选模 Job `2119902514674442241` 的 step 28,000
  UTMOS 已完成：`3.1454054570`。baseline d5 step 54k 为
  `3.200829032659531`，delta `-0.0554235756`，已经不可能满足
  UTMOS/WhiSQA 各 `+0.05` 的预声明 gate。
- 为节省卡时，已在 headless 控制台停止该 Job；页面状态已变为
  `已停止`。从 05:18:29 启动到约 05:35 停止，实际墙钟约
  0.28 h、最坏计费不超过 0.28 卡时。配置状态改为
  `rejected_utmos_20261110_053500`，不要重提。
- 该结果只淘汰 FP32 step 28k 这一候选，不等于宣布整个 FP32
  分支失败；HPC FP32 Job `1071460` 仍继续，后续需到与 baseline
  相近的 54k 或更晚 checkpoint 才可做公平比较。
- 当前训练链：d5 `1076668`（待 hpclong 最终状态）、d6
  `1076707`（hpclong 主线 34 h 续训）均 PENDING/Dependency；
  d6 hpclong `1069636` 和 d7 FP32 `1071460` 正在运行。

## 0.0.17 2026-11-10 05:30 hpclong 持续推进到 78k

- d6 hpclong Job `1069636` 仍在运行；05:26 日志约 step
  `78,100`。新的完整持久 `last.pt` 已推进到 step `78,000`，
  1,019,512,015 B，mtime `05:25:35`，SHA256
  `2fe45e0df81d965d673396333db611b16693565bb4ff286e509f6945c869f2a4`；
  对应 generator SHA256
  `8ebf04e199a3bf7e25bcf83c460bdd2af22a71d208ee785b74abaa3112e1bc72`。
- d5 Job `1076668` 继续 PENDING，依赖 hpclong 最终退出；d5 会
  自动复制当时最后的完整 checkpoint 并从其精确恢复。
- 为把主分支继续推向论文的 400k 训练预算，新增 d6 HPC 续训
  Job `1076707`（`n019_vocd6_cont34h`），同样使用
  `--dependency=afterany:1069636`。规格：d6、HPC/Slurm、
  `hx1hdnormal`、1 DCU、16 CPU / 60 GB、外层 34.25 h、
  内部 34.0 h，预计/最坏 34.0 卡时。
- 该 Job 从 hpclong 停止时同一输出目录中的最终 `last.pt` 恢复，
  验证完整 G/D、MPD/MSD、两个 optimizer 和 scheduler，要求
  step `>=78,000`，并记录 checkpoint step/SHA256。输出仍为
  `runs/n019_official/vocoder_nt_hpc_ft14k_long_20261109`，
  不覆盖任何旧 checkpoint。
- d6 HPC 目前累计约 14.8 h（pilot 7:36 + 主 Job 约 14.5 h）；
  34.0 h 最坏预算预计仍低于 50 h 免费额度，留约 1 h 缓冲。
  launcher SHA256
  `ed9d5fc5d13e48c94a4671fabd84ef34bad7e99b02ed05c3e773c5f0563edde9`。
- 停止条件：checkpoint 缺失/不完整、step 过旧、SHA/recipe/输入
  校验失败、OOM、loss 非有限、10–15 分钟无新日志或达到 34.0 h。
  未使用 d8/d9。

## 0.0.16 2026-11-10 05:25 d5 改为等待 hpclong 最终 checkpoint

- 2026-11-10 05:22 实时核对 d6 hpclong Job `1069636`：训练日志
  已到 step `77,980`，但最后完整持久 `last.pt` 仍是 step `76,000`，
  1,019,512,015 B，mtime `05:03:10`，SHA256
  `327760e9f7a85d09a23bb594745a434444da77e02b4eeb89094104561c081c1a`；
  对应 generator snapshot SHA256
  `b23644fead7262aa88da0d6677983feb599bff81e55d1bb50933ab026e976e99`。
- `last.pt` 只在每 2,000 step 原子更新，因此不能把当前日志 step
  当作可续训 checkpoint。hpclong Job 的内部预算为 15.5 h、外层
  16 h，预计在 `06:18:36–06:48:36` 之间结束；最终完整 checkpoint
  预计为 step `84,000` 左右，以 Job 结束后的实际 `last.pt` 为准。
- 原 d5 Job `1076177` 从 step 72k 分叉，已不符合“从 hpclong 最新
  checkpoint 开始”的要求，于 `05:22` 主动停止。实际墙钟
  `01:00:04`，约 `1.001` 卡时；训练日志到 step `77,040`，
  持久 checkpoint 为 step `76,000`，SHA256
  `1fe19bf95182314a73ef47ba4a6eb4ac6b51f20e59e566a6f7ed6cd3693bc0cb`。
  旧目录保留，不覆盖。
- 已提交 d5 HPC Job `1076668`，名称 `n019_vocd5_final_42h`：
  d5、HPC/Slurm、`hx1hdnormal`、1 DCU、16 CPU / 60 GB、外层
  42.75 h，内部 42.25 h，预计/最坏 42.25 卡时。Job 使用
  `--dependency=afterany:1069636`，等 hpclong 完整退出后自动执行。
- 新 Job 会动态选择 d6 当时最终的 `last.pt`，先验证 checkpoint
  含 G/D、MPD/MSD、两个 optimizer 和 scheduler，要求 step
  `>=76,000`；随后复制到新目录
  `runs/n019_official/vocoder_nt_hpc_d5_hpclongfinal_20261110`，
  源/目标 SHA256 一致后才启动训练。不会覆盖 72k 分叉目录。
- d5 自 2026-11-01 的父 HPC 作业累计约 `7.553 h`，50 h 免费额度
  约剩 `42.447 h`；42.25 h 最坏预算留有约 `0.197 h` 缓冲。
  launcher SHA256
  `4942bc516cfd050c0f3ceaae73bd48d2ec2c1e0d9c23fc3708fcde2192698a10`。
- 停止条件：源 checkpoint 不可读/不完整、step 过旧、传输 SHA256
  不一致、recipe/输入校验失败、OOM、loss 非有限、10–15 分钟无新
  日志或达到 42.25 h。未使用 d8/d9。

## 0.0.15 2026-11-10 05:20 最新状态（72k 淘汰，FP32 选模）

- hpclong 72k 在 target-conditioned dev-100 的 UTMOS 为
  `3.0588623344898225`，d5 54k baseline 为
  `3.200829032659531`，delta `-0.1419666981697085`。UTMOS
  已明确失败，故 05:16:32 停止原选模 Job
  `2119892521730797570`，不再浪费卡时等待 WhiSQA/WER；72k
  checkpoint 不得替换正式 d5 54k。
- 已提交 FP32 snapshot 选模 Job `2119902514674442241`
  （`n019_selfp32seg_20261110_051834`）：d7、人工智能/模型训练、
  1 DCU、15 CPU / 59 GB、2 h，预计 1.4、最坏 2.0 卡时；提交前
  d7 余额 `8.523333333`。在相同 dev-100、mean32、duration 和
  evaluator 下比较 d5 54k baseline 与 FP32 28k/30k/32k
  （SHA256 `603ddf64...cdfb`、`c22068ea...5f37`、
  `21e77d42...b14a`）。输出复用
  `runs/n019_official/vocoder_target_selection_d5_72k_20261110_0436`，
  其中 baseline 评测已复用。Pod 已 Running，配置已回写
  `submit:false` 和 JobID，严禁重复提交。
- d6 逐句 NT embedding 从 `4,400 / 33,236` 续跑的
  6 h Job `2119894378981191682` 正常，未从头重算。d5 Job
  `1076177`、d6 hpclong `1069636`、d7 FP32 `1071460` 均继续运行。
  未使用 d8/d9。

## 0.0.14 2026-11-10 04:34 最新状态（peaknorm 与 shrink01 结果）

- waveform peak-normalization A/B 已完成并拒绝。固定 dev-100 上
  baseline 为 UTMOS `3.2008296072`、WhiSQA `3.1699204698`、
  WER `20.4982517483%`；归一化后为
  `3.1939263511 / 3.1322886452 / 20.4982517483%`，delta
  `-0.0069033 / -0.0376318 / 0.0 pp`。双 MOS 均下降，不能改正式
  inference。
- target mean32 的 shrink-0.1 A/B 已完成：UTMOS
  `3.2332408035`、WhiSQA `3.2276199937`、WER `20.6730769231%`；
  相对 mean32 delta `+0.0324112 / +0.0576995 / +0.174825 pp`。
  WhiSQA 和 WER gate 通过，但 UTMOS 仍差 `0.0175888` 才到
  `+0.05`，不能作为正式候选。
- clean-100 逐句 NT embedding 提取在 04:28 到
  `2,600 / 33,236`，实测约 `0.63 s/utterance`，当前 1 h Job
  无法完成。完成后必须先校验 33,236 keys、250-D、finite、unit norm
  和 `level=utterance`，再做训练口径 A/B。
- 首次逐句 embedding Job `2119880224430178305` 在 55 分钟
  外层 timeout 时推进到 `4,400 / 33,236`，partial NPZ 已落盘；
  已从同一 partial 续跑 6 h Job `2119894378981191682`
  （`n019_ntutt_6h_20261110_044614`）。提交前 d6 余额
  `20.8138888887`；1 DCU、15 CPU / 59 GB、6 h，预计 5.2、
  最坏 6.0 卡时。不得从头重算。
- 新增 d7 target-conditioned 选模 Job `2119892521730797570`
  （`n019_selsel72k_20261110_043851`）：d7、人工智能/模型训练、
  1 DCU、15 CPU / 59 GB、1.5 h，预计 0.5、最坏 1.5 卡时；
  提交前 d7 余额 `8.8722222219`。固定 dev-100、mean32、duration
  和 evaluator，只比较当前正式 d5 54k baseline 与 hpclong 72k
  checkpoint（SHA256 `f3b2f625...e11aae`）。输出
  `runs/n019_official/vocoder_target_selection_d5_72k_20261110_0436`。
  配置已回写 `submit:false` 和 JobID，严禁重复提交。
- 72k 选模在 UTMOS 阶段已明确失败：baseline
  `3.200829032659531`，72k `3.0588623344898225`，delta
  `-0.1419666981697085`。因此无需等待 WhiSQA/WER 即停止 Job
  `2119892521730797570`；停止时间 05:16:32，实际墙钟约 39 分钟。
  checkpoint 不可选，不能替换正式 d5 54k。
- d5 Job `1076177` 从 hpclong step 72k 正常续训；d6 hpclong
  Job `1069636` 和 d7 FP32 Job `1071460` 均继续运行。未使用 d8/d9。

## 0.0.13 2026-11-10 04:28 最新状态（d5 改从 hpclong step 72k 续训）

- 2026-11-10 04:18 实时核对 d6 hpclong Job `1069636`：训练日志已到
  step `72,760`，最新完整持久 checkpoint 是 step `72,000`。
  `last.pt` 为 1,019,512,015 B，SHA256
  `00454ea27ce20842432a4f2baf489bd5c7b57eb7d70400a62c7cd84f45f2dbb3`；
  对应 generator snapshot
  `generator_step00072000.pt` SHA256
  `f3b2f625f4ee7a41376c1d62d38574d5dd71fb96dd52bb8812cb9b62e5e11aae`。
- 此前 d5 Job `1075605` 是从 step 66k 分叉，不符合“从 hpclong
  最新 checkpoint 开始”的要求；该 Job 已在日志约 69.4k、持久
  checkpoint 68k 时停止，实际 Elapsed `00:56:36`。
- step 72k 完整状态已经本机中转至 d5：
  `/public/home/a094f4d5/voice_projects/runs/n019_official/vocoder_nt_hpc_d5_hpclong72k_20261110/last.pt`。
  d6、本机、d5 三处 SHA256 均为 `00454ea2...f2dbb3`。
- 新 Job `1076177`（`n019_vocd5_72k_43h`）：d5、HPC/Slurm、
  `hx1hdnormal`、节点 `f11r2n03`、1 DCU、16 CPU / 60 GB、外层
  43 h、内部 42.5 h，预计 42、最坏 42.5 卡时。launcher SHA256
  `bbde27d090c2fd8eedfd9efdcd38329c2a1f852011936aedf08b8a7f146b1c6c`。
- Job 已于 04:26:07 从 `step=72001` 恢复；04:26:18 完成首个
  generator step，随后日志 step `72,040`，loss 有限，约
  `0.68 s/step`。输出
  `runs/n019_official/vocoder_nt_hpc_d5_hpclong72k_20261110`。
- d5 父作业此前累计约 `4.835833 h`，停止的 66k Job 又消耗
  `0.943333 h`；按 50 h 免费额度估算，新 42.5 h 最坏预算后仍留
  约 `1.22 h`。
- 本轮停止旧 d5 后续训只使用 d5/d6/d7，未使用 d8/d9。不得重提
  Job `1075605`，也不要覆盖旧 66k 目录。

## 0.0.12 2026-11-10 03:55 最新状态（推理波形归一化差异）

- 引用实现 speech-resynthesis 的 `inference.py` 在保存生成音频前执行
  `librosa.util.normalize`。当前正式匿名化直接保存 tanh 输出。
  dev-100 生成 WAV 峰值 mean/median/min/max 为
  `0.723603/0.748535/0.310852/0.968994`，87/100 峰值低于 0.9，
  这是新发现的具体推理口径差异。
- d6 task-creation 页两次超时且均未创建任务；改由 d7 提交成功：
  Job `2119879611382317057`（`n019_peaknorm_d7_20261110_034733`），
  1 DCU、15 CPU / 59 GB、1 h，预计 0.3、最坏 1.0 卡时。复评
  同一 100 句的 peak-normalized 版本，输出
  `runs/n019_official/waveform_peaknorm_dev100_20261110_034733`。
  该任务运行中，不能提前把归一化写进正式 inference。
- 逐句 NT embedding 首任务 `2119876813572554754` 在首次 W-PRO
  matmul 后约 10 分钟无进展，已停止；新版脚本加 300 秒 watchdog、
  每 100 条 checkpoint 和 `--resume`，SHA256
  `1157c4436f934a517482902497ca377681f6646d20f052340ba5ba00d5113cbc`。
  重试 Job `2119880224430178305`
  （`n019_ntutt_r1_20261110_034959`）已通过 tiny-matmul，运行中。
- d5 68k snapshot 已生成：
  `.../vocoder_nt_hpc_d5_hpclong66k_20261110/snapshots/generator_step00068000.pt`，
  SHA256 `4a844b3af233d0830812cd1ec3e7c492c346479d2abe823c66de08579ce3218f`；
  已中转至 d6 的同名 tmp snapshot。54k-vs-68k dev selection 已准备，
  但 d6 已达并发上限，提交页超时且未创建；待任务数下降后重试。
- 54k/56k/58k/60k 等权平均失败：UTMOS `3.164025`、
  WhiSQA `3.181872`、WER `20.541958%`。相对 54k，
  UTMOS `-0.036804`，不满足 gate，不能替换 54k。
- d5 66k 续训正常，03:50 已有 68k snapshot，约 `0.68 s/step`。
  未使用 d8/d9。

## 0.0.11 2026-11-10 03:40 最新状态（逐句 NT embedding 诊断）

- 为排除 vocoder 训练/推理 target embedding 口径差异，已提交 d6
  AI Job `2119876813572554754`（`n019_ntutt_20261110_033626`）：
  1 DCU、15 CPU / 59 GB、1 h，预计 0.4、最坏 1.0 卡时；提交前
  d6 余额 `22.7611111109`。
- 它从 d6 本地原始 LibriTTS clean-100 的 33,236 条 records 和固定
  W-PRO 模型提取逐句 250-D 单位向量，输出
  `processed/embeddings/libritts_train_clean_100_nt_utterance_20261110`。
  当前正式 vocoder 用的是 247 个 speaker mean；该新产物仅用于
  训练口径 A/B，不能直接替换正式 embedding。
- 新脚本 `scripts/extract_libritts_clean100_nt_utterance_ai.sh`
  SHA256 `a9948d16ba7fa1e97d7254500f2fb69911f57a6f0f14b899abfb14f40e104789`；
  配置已回写 `submit:false` 与 JobID，严禁重复提交。
- d5 step 66k 续训 Job `1075605` 正常；03:34 日志 step `66,460`，
  loss 有限、约 `0.685 s/step`。68k snapshot 预计在 03:50 左右出现。
- 未使用 d8/d9。

## 0.0.10 2026-11-10 03:25 最新状态（d5 从 hpclong step 66k 续训）

- d6 hpclong Job `1069636` 当前最后完整持久 checkpoint 是
  step `66,000`，不是训练日志中更靠前的 step `66,580`。
  `last.pt` 为 1,019,512,015 B，SHA256
  `5d901423848236ad1cc1541d6e4207b6aa7bc0b809278554d39fe047633293f1`；
  已反序列化确认 `step=66000`，含完整 G/D、两个 optimizer 和
  scheduler。generator snapshot SHA256
  `c4137dd619174af594746eb38d2daea236cda89cab745c80f2544dfea51791db`。
- 旧 d5 Job `1075139` 是错误地从 step 62k 分叉，不是 hpclong
  最新状态；到日志 step `65,700` 时持久状态仍为 step `64,000`。
  已于 03:19:22 停止，旧目录保留，约消耗 `0.774` 卡时。
- step 66k 完整状态已经本机中转至
  `/public/home/a094f4d5/voice_projects/runs/n019_official/vocoder_nt_hpc_d5_hpclong66k_20261110/last.pt`，
  源、本机、目标 SHA256 一致。
- 新 Job `1075605`（`n019_vocd5_66k_44h`）已启动：
  d5、HPC/Slurm、`hx1hdnormal`、节点 `f11r3n09`、1 DCU、
  16 CPU / 60 GB、外层 44 h、内部 43.5 h，预计 43.0、
  最坏 43.5 卡时。输入为官方 clean-100 33,236 条 records、
  NT speaker embeddings 和 step 66k 完整状态；BF16、batch 16、
  lr `2e-4`、2x feature matching。输出
  `runs/n019_official/vocoder_nt_hpc_d5_hpclong66k_20261110`。
- 提交前 d5 父作业累计 `4.835833 h`；50 h 额度约剩
  `45.164 h`，43.5 h 最坏预算留约 `1.66 h` 缓冲。旧 Job
  `1075139` 和更早的 62k 目录不得重提或覆盖。
- launcher SHA256
  `6bcb0a16bdee9da24709cbd6ad5d89fc0e3fcb3c667af823993de7b2abefb82a`；
  启动门禁已通过 records/embedding/recipe lock/健康 DCU 检查。
  03:27:21 已从 `step=66001` 进入训练循环，03:27:32 完成首个
  generator step，03:27:48 日志 step `66,020`，loss 有限、
  约 `0.687 s/step`。
  未使用 d8/d9。后续应继续在这个 step 66k 分支上训练和选模。

## 0.0.9 2026-11-10 02:50 最新状态（后续选模与 FP32 对照）

- 当前正式结果仍为 d5 step 54k + mean32：WER
  `6.198276354089378%`、UTMOS `3.200134737291898`、WhiSQA
  `3.1962373993728375`。不要用 56k/58k/60k 替换。
- d6 target-conditioned 选模 Job `2119856802969178114` 的 100 句结果：

| checkpoint | UTMOS | WhiSQA | WER % |
|---|---:|---:|---:|
| hpclong 6k baseline | 3.0499825764 | 2.9503006965 | 20.541958 |
| d5 54k | **3.2008287084** | **3.1699211434** | **20.498252** |
| d5 56k | 3.0928345442 | 3.1158912763 | 21.197552 |
| d5 58k | 3.0039809632 | 3.0761852801 | 20.629371 |
| d5 60k | 2.7843480694 | 2.9533840865 | 20.279720 |

  56k 相对 baseline 的 UTMOS 只有 `+0.042852`（低于 `+0.05`
  门槛）且 WER 回归 `+0.655594 pp`；58k 双 MOS 接近或低于
  baseline；60k 虽 WER 最好，但双 MOS 明显低于 baseline。
  56k/58k/60k 都不入选，selected checkpoint 仍是 baseline。
- 新增同轨迹 generator 权重平均候选：54k/56k/58k/60k 等权平均的
  SHA256 `6e24048106cd2946aaf2c273101299c7613dcbece4656c1e1cd68ac6bdbdfa62`。
  d6 A/B Job `2119865770425077762`
  （`n019_avg5460_20261110_025233`）以 54k 为 baseline，在完全相同
  dev-100 上评三项；1 DCU、15 CPU / 59 GB、1.5 h，预计 0.7、
  最坏 1.5 卡时。配置
  `configs/scnet_d6_avg54_60_selection.json` 已设 `submit:false`
  并记录真实 JobID。不得重复提交。
- d5 长训 Job `1075139` 正常，02:48 已到 step `63,180`，
  loss 有限、约 `0.68 s/step`。d6 hpclong Job `1069636`
  也继续运行。
- 零卡时全量诊断已写
  `/public/home/a094f4d7/quality_diagnostic_d5_54k_20261110.json`，
  SHA256 `613bb85e...f377`。1,934 句的 duration error 与
  UTMOS/WhiSQA 相关仅 `-0.107/-0.140`；并非主要缺口。100 句音频中
  generated/source 的 spectral flatness 为 `0.392/0.310`，
  4–8 kHz 能量占比为 `0.100/0.077`，仍显示 vocoder 宽带噪声和
  高频伪影偏多。
- 为验证 BF16 是否限制后期质量，新增 d6 FP32 对照分支，从
  hpclong step 62k 完整状态、SHA256 `a928093e...a064c8e` 恢复。
  第一次 Job `2119864403803394050` 在启动 2 秒后因 d6 缺
  `scripts/verify_training_data_marker.py` 失败，未有效训练；该脚本
  已同步并完成 marker 校验。
- 重试 Job `2119864730527092738`
  （`n019_fp32_d6_62k_r1_20261110_024825`）：d6、人工智能/模型训练、
  1 DCU、15 CPU / 59 GB、6 h，预计 5.5、最坏 6.0 卡时；
  FP32、batch 16、lr `2e-4`、每 2k snapshot。输出
  `runs/n019_official/vocoder_nt_hpc_d6_fp32_from62k_20261110`。
  配置已设 `submit:false` 并记录真实 JobID，不得重复提交。
- `scripts/run_vocoder_ddp.sh` 新增可选
  `N019_VOCODER_RESUME_SHA256` 门禁，SHA256
  `1486f5a369bb1b80aba9262df4dbc5a1481efa8a85a8108668e7bb82c1852614`。
- 新增 `scripts/average_vocoder_checkpoints.py`，可做等权/加权
  checkpoint 平均，并支持按 reconstructed weight-norm kernel 平均。

## 0.0.8 2026-11-10 02:35 最新状态（d5 从 hpclong step 62k 续训）

- 当前正式结果仍为 d5 step 54k + mean32 target embedding，完整
  1,934 句：WER `6.198276354089378%`（1,496 句）、UTMOS
  `3.200134737291898`、WhiSQA `3.1962373993728375`。相对论文
  `7.41 / 3.63 / 3.69`，WER 优 `1.21172 pp`，UTMOS 差
  `-0.429865`，WhiSQA 差 `-0.493763`。
- 2026-11-10 02:26 实时检查 d6 hpclong Job `1069636`：仍在运行，
  日志已到 step `62,580`，最新完整持久 `last.pt` 为 step
  `62,000`，1,019,512,015 B，SHA256
  `a928093e2c603feaf9501c9056f7b4210ebbc1a9e744be3ea4cedeb46a064c8e`；
  对应 generator snapshot SHA256
  `6a98f46357d52d118cb7f308a26da168ddef1831a4d46bbb1ddb721383596b4a`。
- d5 旧 Job `1074023` 从 52k 启动后推进到日志 step `60,820`，
  完整 `last.pt` 为 step `60,000`；该任务已在 02:28:01 主动停止，
  旧目录 `vocoder_nt_hpc_d5_hpclong52k_20261110` 保留，不覆盖。
  实际占用 1:46:15、约 1.771 卡时。
- 已从 d6 step 62k 完整状态经本机中转至 d5，源/本机/目标
  SHA256 均为 `a928093e...a064c8e`，并验证为 step `62,000`。
  新目录为
  `runs/n019_official/vocoder_nt_hpc_d5_hpclong62k_20261110`。
- 新 Job `1075139`（`n019_vocd5_62k_45h`）已于 02:32:50 在
  `f11r1n05` 启动：d5、HPC/Slurm、1 DCU、16 CPU / 60 GB、
  45 h 外层墙钟，预计 44.5、最坏 45.0 卡时。任务使用 BF16、
  total batch 16、lr `2e-4`、2x feature matching，从 step
  `62,001` 恢复完整 G/D、两个 optimizer 与 scheduler。
- 启动门禁已通过：33,236 条 clean-100 records、embedding
  SHA256 `698d1282...2a866`、recipe lock、DCU tiny matmul 和
  mel preflight。02:35:26 已完成首个 generator step，进入
  step `62,002`，无 OOM 或非有限 loss。输出日志为
  `logs/n019_official/n019_vocd5_62k_45h_1075139.out`。
- 停止条件：checkpoint/recipe/输入 SHA 不一致、loss 非有限、
  OOM、10 到 15 分钟无进展、达到 44.5 h 内部预算或 45 h
  外层墙钟。不要重复提交 Job `1075139`；未使用 d8/d9。

## 0.0.7 2026-11-09 23:12 最新状态（d5 改为从 hpclong 44k 续训）

- 用户要求不使用 d8/d9；后续只使用 `a094f4d5`、`a094f4d6`、
  `a094f4d7`。
- 2026-11-09 23:11 实时检查 d6 hpclong BF16 Job `1069636`：
  日志已到 step `44,640`，loss 有限，约 `0.669 s/step`；
  最新完整落盘 generator snapshot 是
  `snapshots/generator_step00044000.pt`（56,858,091 B，
  SHA256 `401fd227bbe484e146294af2fd916cd1dfc8a343e0def4e98b4bcfa5db71efdc`）。
  同步的完整 `last.pt` 为 1,019,512,015 B，SHA256
  `6934b9388672723d7f846de9220df01fdad4af154762ea3a3e43779a2d1471e0`。
  Job `1069636` 的 Slurm 上限为 16 h，预计
  2026-11-10 06:48 结束。
- 旧 d5 HPC 长训 Job `1072951`（`n019_vocd5_48h`）仍固定用
  hpclong 6k 初始化，不符合从最新 checkpoint 续训的要求；该
  pending Job 已取消，未产生卡时。
- 已将 step 44000 generator snapshot 经本机中转至 d5：
  `data/n019_official/checkpoints/n019_hpclong/generator_step00044000.pt`，
  源/目标 SHA256 一致。任务从该权重初始化，不再从 6k 开始。
- 已提交替代 Job `1073179`（`n019_vocd5_44k_45h`）：
  `a094f4d5` / HPC Slurm / `hx1hdnormal`、1 DCU、
  16 CPU / 60 G、45 h，预计 44.5、最坏 45.0 卡时，
  依赖 `afterok:1072805`。输入为 d4 官方 LibriTTS clean-100
  33,236 records、NT speaker embeddings 和上述 44k checkpoint；
  BF16、lr `2e-4`、batch 16、feature matching 2x、
  gradient clipping 0、每 2k 保存 snapshot。输出
  `runs/n019_official/vocoder_nt_hpc_d5_hpclong44k_20261109`。
  停止条件为依赖/输入/SHA/DCU/recipe 失败、loss 非有限、
  10–15 分钟无进展或达到 44.5 h 内部预算。
- 任务脚本
  `hpc/n019_vocoder_hpc_d5_48h.slurm` 已更新，SHA256
  `e018feb4af79f1ac60585b51e24ed71baab3e1483e5cb3974fc65141ad209591`；
  d5 远端旧脚本保留为
  `.bak_before_hpclong44k_20261109`。本轮没有使用 d8/d9。
- 两条选模链已定位为评测代码问题，不是 checkpoint：
  - d7 Job `2119801099336699905` 在 baseline 三项完成后，因
    运行期间脚本被并发改写，Bash 读到损坏的 `'\n,'` 尾行而退出；
    baseline 指标
    `UTMOS 3.0669834614 / WhiSQA 2.6721351326 / WER 19.8426573427%`。
  - d6 Job `2119803120709050369` 的 `eval_mos.py` 是旧版，
    没有把 `N019_WHISPER_SMALL_PATH` 注入 WhiSQA wrapper，
    尽管本地 Whisper cache 存在且 `refs/main` 正确。
- d6 `src/n019/eval_mos.py` 已同步本地修正版，SHA256
  `332cb0f11ad652e78985705ee20961ee1ea73e78d1b4ddbd7d91c6ef4f9c55ea`；
  旧文件保留 `.bak_before_local_whisper_20261109`。在 d6 用现有
  baseline 的前 2 句做 CPU WhiSQA smoke，正常完成，均值
  `2.678769826889038`。
- 23:19 实时余额：d6 `25.8558333332`、d7
  `12.1211111107` 卡时。已提交：
  - d6 `2119812079720611841`
    （`n019_vocselh3r4_20261109_231912`），1 DCU、
    15 CPU / 59 GB、2 h，预计 1.3、最坏 2.0 卡时；
  - d7 `2119812139830759426`
    （`n019_vocselfp32r1_20261109_231926`），1 DCU、
    15 CPU / 59 GB、2 h，预计 1.5、最坏 2.0 卡时。
  两项均已进入“运行中”，复用固定 dev-100；配置已回写
  `submit:false` 和真实 JobID，不得重复提交。
- d6 r4 在 WhiSQA 成功后继续跑 WER 时暴露第二个缺失：
  `n019.wer_eval_vpc` 不存在；补模块后又发现声明的 VPC 包会
  eager import `pandas/pyloudnorm` 等无关 ASR 模块。
- 已把 `src/n019/wer_eval_vpc.py` 改为用
  `importlib.util.spec_from_file_location` 直接加载
  `speechbrain_asr/inference.py`，绕开无关父包 eager import；
  SHA256 `7173970161ac3aa03d40fb23ba90a5895c41b3a324a575cff58cd9640f70b03a`，
  已同步 d6/d7，旧文件各保留
  `.bak_before_lazy_vpc_import_20261109`。
- d6 2 句 CPU WER smoke 已通过：
  utterances/references=`2/2`，WER `20.895522388059703%`。
  d6 r4 已确认失败，提交新的续跑 Job
  `2119817726150946817`（`n019_vocselh3r5_20261109_234138`），
  仍为 1 DCU、15 CPU / 59 GB、2 h，已进入“运行中”，
  复用 baseline 已有 reconstruction/UTMOS/WhiSQA，只补 WER 和
  30k/32k/34k/36k candidate。配置已回写 JobID 和 `submit:false`。
- d7 FP32 首个 2k candidate 已产出：UTMOS `2.7258257794`、
  WhiSQA `2.5131241292`、WER `20.4982517483%`，三项均差于
  baseline `3.0669834614 / 2.6721351326 / 19.8426573427%`；
  2k 不入选，继续测 8k/10k/12k。
- d6 r5 在 AI 容器启动 WER 后再次失败，根因是本地
  `asr_n019_local/hyperparams.yaml` 的 `wav2vec2_hub` 仍指向
  d7 绝对路径；登录节点 smoke 能跨账号读取，所以没有提前暴露。
  已备份并改为 d6 本地路径，确认目录内不再含 d7 路径；
  2 句 CPU WER smoke 再次通过，仍为 `20.8955223881%`。
- 已提交 d6 r6 Job `2119819757712420866`
  （`n019_vocselh3r6_20261109_234943`），规格不变，
  复用已有 baseline reconstruction/UTMOS/WhiSQA，只补 WER 与
  30k/32k/34k/36k。配置已回写真实 JobID 和 `submit:false`。
- d6 r6 已跑通完整 baseline：UTMOS
  `3.0669832468032836`、WhiSQA `2.6721348732709886`、
  WER `19.842657342657343%`，计数 100；随后已开始
  30k candidate reconstruction。WER 评测链已闭环。
- d7 FP32 step 8000 candidate：UTMOS `2.8795240283`、
  WhiSQA `2.5218738884`、WER `20.4108391608%`，仍全面低于
  baseline，不入选；继续测 10k/12k。
- 进一步审计发现训练配方不一致：
  `configs/paper_algorithm_v1.json` 的 vocoder batch size 为
  `32`，但现有 HPC 长训脚本实际使用 total batch `16`。
  新增 `scripts/vocoder_batch32_smoke_ai.sh`，在 d6 上以
  1 DCU、3 steps、BF16、真实 clean-100 records/embeddings
  验证 batch 32 的显存、loss 和吞吐；脚本 SHA256
  `08dc657d79a12a10a7590aa7f141c88bf2669648bf2971926bf4924e0653d782`。
- 已提交 smoke Job `2119821869353947137`
  （`n019_batch32smoke_20261109_235806`）：d6、1 DCU、
  15 CPU / 59 GB、0.5 h，预计 0.15、最坏 0.5 卡时；
  输出 `runs/n019_official/vocoder_batch32_smoke_20261109_235806`。
  只有 3 steps、loss 有限且无 OOM 才考虑把 d5 长训改为
  total batch 32。配置已回写真实 JobID 和 `submit:false`。
- d6 batch32 smoke 暴露的是 smoke 脚本自身错误：
  设置了 `N019_SKIP_PATH_VERIFY=1` 但没有提供 marker，
  `run_vocoder_ddp.sh` 在模型启动前退出，因此不能用于判断显存。
  已移除 skip，让 96 条本地记录走正常路径校验；修正版 SHA256
  `e967e19b8fa785aadbfefdc6d0800141136e4939cda8dddeb88ffdc2121d5eec`。
- d7 FP32 step 10000 candidate：UTMOS `2.9019683790`、
  WhiSQA `2.4624080867`、WER `21.0664335664%`，仍全面低于
  baseline，FP32 分支基本排除；只剩 12k 收尾。
- d6 HPC step 30000 candidate：UTMOS `2.7515156269`、
  WhiSQA `2.5546909496`、WER `20.8479020979%`，三项仍低于
  baseline；正在测 32k/34k/36k。
- 已提交修正版 d7 batch32 smoke Job
  `2119823883898736641`
  （`n019_batch32smoke_d7_20261110_000605`）：1 DCU、
  15 CPU / 59 GB、0.5 h，预计 0.15、最坏 0.5 卡时；
  提交前 d7 余额 `12.12`。输出
  `runs/n019_official/vocoder_batch32_smoke_20261110_000605`。
- d7 batch32 smoke 仍无法运行，因为 d7 full records 中
  audio/codes/codebook 指向 d4，而 AI 容器看不到其他账号
  home；d7 本地缺少对应 audio。该失败不是显存问题。
- 已改回 d6：d6 full `unit_records.jsonl` 的 96 条子集路径
  均在本账号。d6 首次 smoke 是 skip/marker 配置错误；
  修正后提交 Job `2119827168643141634`
  （`n019_batch32smoke_r1_20261110_001908`），
  1 DCU、15 CPU / 59 GB、0.5 h，预计 0.15、最坏 0.5 卡时；
  配置已回写 `submit:false`。
- d5 fullmean 在 23:42 已处理 `103,000 / 168,023` 条，
  Job `1072805` 正常；44k 长训 Job `1073179` 继续等待依赖。

## 0.0.6 2026-11-09 22:35 最新状态（mean32 全量完成，正式结果更新）

- 用户明确要求后续**不使用 d8/d9**；只使用 `a094f4d5`、
  `a094f4d6`、`a094f4d7`。
- `DU-pred-nt-hpclong6k-mean32` 完整 1,934 句复评已完成：
  WER `6.07842018149649%`（1,496 句）、UTMOS
  `3.0965501278361467`、WhiSQA `3.017711649343541`
  （后两项各 1,934 句）。这取代旧 hpclong6k 稀疏 target
  embedding 结果，成为新的正式结果。
- 相对论文 `7.41 / 3.63 / 3.69`：WER 优 `1.33158 pp`，
  UTMOS 差 `-0.533450`，WhiSQA 差 `-0.672288`。
  相对旧正式 `6.212545 / 3.053993 / 2.972314`：
  WER 改善 `0.134125 pp`，UTMOS `+0.042557`，
  WhiSQA `+0.045398`。
- 全量 Job `2119791353482788865` 的三项指标已完整落盘；
  结果目录
  `eval/du_pred_nt_hpclong6k_mean32`。JSON SHA256：
  - `WER.json` `31a4bf95…fafa`
  - `mos/UTMOS.json` `c9ddcdab…c190`
  - `mos/WhiSQA.json` `53494bfa…9cb8`
  - `quality_metrics.json` `bc16b9cb…0451`
- d6 30k/32k/34k/36k 选模前两次失败均非模型问题：
  首次缺 Whisper-small cache；r1 因 d6 `vocoder.py` 旧版不识别
  checkpoint 的 `grad_clip_norm`。已备份旧文件并同步 d7/本地
  `vocoder.py`，SHA256
  `5a7b94e548350eeba0822d7dcf7b10cbef0d90bbf97d73f05588f984943bc688`。
- 已提交 d6 选模 r2 Job `2119799118639157249`
  （`n019_vocselh3r2_20261109_222742`）：1 DCU、
  15 CPU / 59 GB、2 h，预计 1.5、最坏 2.0 卡时；
  提交前 d6 AI 余额 `26.1605555554`。复用同一固定 dev-100，
  比较 baseline 6k 与 30k/32k/34k/36k；输出
  `runs/n019_official/vocoder_selection_hpc30k36k_20261109`。
  配置已回写 `submit:false` 与 JobID，不得重复提交。
- HPC 长训正常：d6 BF16 Job `1069636` 已到 step `40,760`，
  snapshots 到 40k；d7 FP32 Job `1071460` 已到 step
  `11,320`，snapshots 到 10k，loss 均有限。
- mean32 仍是每位目标说话人抽 32 句的近似。已构造 843 个
  target speakers 在完整 LibriTTS train-other-500 中的全部
  utterance manifest：`168,023` 行、speaker group
  min/median/mean/max = `8/195/199.3155/815`，SHA256
  `284f86fa16c1ef9317fb96f422d49647a45a7e497b309232189c738141cd2723`。
- 已提交 d5 HPC Job `1072805`（`n019_tspkfull_hpc`）：
  `hx1hdnormal`、1 DCU、16 CPU / 60 G、6 h，预计约 2.2、
  最坏 6.0 卡时；输入为上述 168,023 行 manifest、d4 原始
  other-500 audio 和 d5 W-PRO，输出
  `processed/embeddings/target_speaker_fullmean843_hpc_20261109`。
  每 1,000 行可恢复；停止条件为 manifest/ACL/输出形状/有限性/
  unit-norm 失败、10–15 分钟无进展、DCU/内存/存储错误或 6 h 墙钟。
- 已提交 d7 AI Job `2119801099336699905`
  （`n019_vocselfp32_20261109_223533`），比较 hpclong 6k
  与 FP32 分支 2k/8k/10k 三个现有 snapshot（12k 若在启动前出现
  也由 glob 自动纳入）。规格 1 DCU、15 CPU / 59 GB、2 h，
  预计 1.5、最坏 2.0 卡时；提交前 d7 余额
  `12.3988888885`。输出
  `runs/n019_official/vocoder_selection_hpclong6k_fp32_20261109`。
  配置已回写 `submit:false` 与 JobID，不得重复提交。
- d6 选模 r2 Job `2119799118639157249` 在 baseline
  reconstruction 完成后失败：d6 缺 `vendor/UTMOS22-demo/score.py`
  和 UTMOS overlay，不是 DCU 故障。已同步 d7 已验证的
  UTMOS demo（`score.py` SHA256 `95b0ef25…75d0`）及 63 MB
  PL 1.5.10/torchmetrics 0.7.2 overlay；d6 CPU 2 句 smoke
  通过（UTMOS mean `3.035479`）。选模脚本前置检查已补上
  UTMOS/WhiSQA/overlay。
- 已提交 d6 r3 Job `2119803120709050369`
  （`n019_vocselh3r3_20261109_224336`）：1 DCU、15 CPU /
  59 GB、2 h，预计 1.3、最坏 2.0 卡时；提交前 d6 余额
  `26.0583333332`。复用 baseline 的 100 句重建，只补其指标并跑
  30k/32k/34k/36k；配置已回写 JobID 和 `submit:false`。
- 为避免训练停在 6k/14k，并利用 d5 剩余 HPC 配额，已准备并提交
  d5 HPC 后续长训 Job `1072951`（`n019_vocd5_48h`），依赖
  fullmean `afterok:1072805`。规格 `hx1hdnormal`、1 DCU、
  16 CPU / 60 G、48 h，预计 47.5、最坏 48.0 卡时；从 hpclong
  6k（SHA256 `4452ad40…5040`）初始化，读取 d4 原始官方
  clean-100 的 33,236 records / 250-D NT speaker embeddings，
  BF16、lr 2e-4、batch 16、无 gradient clipping、每 2k snapshot。
  输出 `runs/n019_official/vocoder_nt_hpc_d5_hpclong6k_20261109`；
  预计推进约 25 万 step，逼近上游默认 400k。停止条件为依赖/
  marker/recipe/DCU/路径、loss 非有限、10–15 分钟无进展或 47.5 h。
- 新增零卡时全量音频诊断（1,934 句）：没有 >=0.999 的削波样本；
  generated/source 的 RMS mean 为 `0.08732/0.05874`（约 +3.4 dB），
  peak mean `0.7381/0.5341`。时长比 mean `1.00309`、p05/p95
  `0.88903/1.09679`，但时长误差与 MOS 相关很弱
  （UTMOS r=`-0.125`，WhiSQA r=`-0.177`）。因此时长不是主因；
  电平和生成音质仍有明显差异，但此前 -4.2 dB A/B 只带来
  small gain，不能把电平当作全部原因。诊断 SHA256
  `52ac7c43…1f63`。
- 本轮未使用 d8/d9；后续也不得用于任务、数据中转或评分。

## 0.0.5 2026-11-09 22:10 最新状态（mean32 dev gate 通过，正在全量复评）

- 本节记录的是 mean32 全量完成前的状态；正式结果见 0.0.6。
- 已确认旧“speaker mean”只平均 target map 中出现的 1–13 条
  target utterance，不代表完整 speaker。d5 HPC Job `1071850`
  已用 843 speakers × 32 utterances（26,917 条）生成完整
  mean32 W-PRO 向量，843 keys、250-D、unit norm；
  NPZ SHA256 `d566b8f0…8f23`。
- 固定 dev-100、同一 hpclong 6k、duration 和 evaluator 的配对 A/B：
  sparse `2.960765/2.835355/20.323427%`，
  mean32 `3.049982/2.950301/20.541958%`；
  delta `+0.089217 / +0.114946 / +0.218531 pp`，通过
  `+0.05/+0.05` MOS 和 `0.25 pp` WER gate。
- 正在 d7 AI Job `2119791353482788865` 做完整 1,934 句复评，
  label `hpclong6k_mean32`；WER 1,496，UTMOS/WhiSQA 1,934。
- 正在 d6 AI Job `2119794137201131522` 比较 hpclong 6k 与
  30k/32k/34k/36k snapshot 的 dev-100 三项指标。
- HPC 长训仍在 d6 BF16（Job `1069636`）和 d7 FP32
  （`1071460`）并行。完整记录见 `docs/JOB_LEDGER.md`。

## 0.0.4 2026-11-09 18:40 最新状态（HPC 长训与选模并行）

- 当前正式全量结果已切换为 DU-pred-nt-hpclong6k：WER
  `6.212545%`、UTMOS `3.053993`、WhiSQA `2.972314`
  （论文 7.41 / 3.63 / 3.69；计数为 1,496 / 1,934 / 1,934）。
- dev-100（speaker-disjoint，40 speakers）上，hpclong 6k 仍是峰值：
  UTMOS `3.066984`、WhiSQA `2.672135`、WER `19.842657%`。
  最新 12k/14k 分别只有 UTMOS `2.776523` / `2.702415`，
  16k/18k 分别为 `2.983690` / `2.924862`，仍低于 6k；
  因此不安排这些 snapshot 的全量复评。
- 电平 A/B 已排除：统一 -4.2 dB 只带来 UTMOS +0.0100、
  WhiSQA +0.0470。
- HPC 模式（2026-11-09 启用）：`sbatch` 分区 `hx1hdnormal`，
  单账号同一时刻只能占 **1 张 DCU**（`max tres limit 1`），
  但单 Job 可跑 3 天；每账号 50 h 免费额度。
- 正在跑：Slurm Job `1069636`，d6、1 DCU / 16 CPU / 60 G、
  16 h 墙钟（inner 15.5 h），从微调 14k
  （SHA256 `479b982c…1dc6`）继续，lr 2e-4、2x feature matching、
  梯度裁剪 0、batch 16，每 2000 step 存 compact snapshot，
  输出 `runs/n019_official/vocoder_nt_hpc_ft14k_long_20261109`。
  2026-11-09 18:34 已到 step 19,920、约 0.67 s/step，
  loss 有限，预计 ~82k step。
- 已备好：`scripts/run_full_eval_param_ai.sh`（参数化完整
  1,934 句复评）、`scripts/average_generator_snapshots.py`
  （SWA 权重平均）、`d7-vocoder-selection-hpclong-4k6k` 选模配置。
- d7 HPC 选模 Job `1071367` 已完成，`selection.json` SHA256
  `1ce7735f…80d53`，`selection.md` SHA256
  `ecfdf07b…c0fa`；16k 的 `2.983690 / 2.577243 / 20.673077%`
  是该批最好结果，但没有超过 hpclong 6k。
- 零卡时审计确认：上游 `speech-resynthesis` 的 `train.py` 不做
  AMP/BF16，而现有 hpclong 长训一直使用 `bf16=true`。这是尚未
  消融的论文对齐差异。`scripts/run_vocoder_ddp.sh` 已增加
  `N019_VOCODER_BF16=0` 开关，默认行为保持 1 以兼容历史。
- 已提交 d7 HPC FP32 分支 Job `1071460`（首次
  `1071434` 在 1 秒时因旧 helper 未读取 records 覆盖而失败；该
  任务无训练或指标产出），从 hpclong 6k
  （SHA256 `4452ad40…5040`）初始化；`hx1hdnormal`、1 DCU、
  16 CPU / 60 G、40 h 墙钟，预计 38、最坏 40 卡时。输出
  `runs/n019_official/vocoder_nt_hpc_hpclong6k_fp32_20261109`。
  训练数据直接读 d6 已 finalize 的官方 LibriTTS clean-100，
  只授予 d7 该账号 ACL 读权限，不复制或改写数据。
  Job 已于 18:57 进入首个有效 step，FP32 实测约 `1.11 s/step`，
  loss 有限；39.5 h 内预计约 12.8 万 step。
- d7 AI 余额 `15.6438888885` 卡时，已用 headless 模式提交
  dev-100 Job `2119749733360357377`
  （`n019_vocselhs_20261109_191127`），比较 hpclong 20k/22k
  与 baseline；1 DCU、15 CPU / 59 GB、2 h，预计 1.4、最坏
  2.0 卡时。配置已回写 `submit:false`，不得重复提交。
- 为校准 MOS 评测器与论文 Original 行，另提交 d7 Job
  `2119750575417610242`（`n019_orig_mos_20261109_191448`）：
  用同一 UTMOS22/WhiSQA、同一 `libri_test/wav.scp` 1,934 句评
  原始语音，对照论文 `4.11 / 4.08`。1 DCU、15 CPU / 59 GB、
  1 h，预计 0.25、最坏 1.0 卡时；配置已回写 `submit:false`。
  该任务已完成：UTMOS `4.100698`、WhiSQA `4.059702`，相对论文
  `4.11 / 4.08` 仅 `-0.009302 / -0.020298`。因此 MOS evaluator、
  Whisper/W-PRO 预处理没有明显口径错误；剩余匿名系统差距已可
  主要归因于生成音频质量/训练配方，而不是打分器。
- 零卡时审计发现当前 speaker-mean-L2 只是 **选中目标 utterance
  的均值**：1,924 条 target 只覆盖 843 个 speaker，每组
  min/mean/max = `1 / 2.2823 / 13` 条；完整 other-500 manifest
  中这 843 个 speaker 实际有 `168,023` 条 utterance，每组
  min/median/mean/max = `8 / 195 / 199.3155 / 815`。因此当前
  proxy 与训练侧 speaker mean 的定义明显不一致，列为高优先级
  target-embedding 修正。
- 已构造 dev/test target-speaker 并集下的确定性 32 条/speaker
  子集，共 `26,917` 条，分两片：
  - d6 shard0：13,503 条、422 speakers；
  - d7 shard1：13,414 条、421 speakers。
- 首次 d6 AI Job `2119752513296613377` 和 d7 AI Job
  `2119753439789150210` 均在首条随机 audio 读取时因 d4 嵌套
  目录 ACL 不足失败，无 embedding/checkpoint 产出。已对 d4
  `train-other-500` 全树只向 d6/d7 加 `rX` ACL（19:48 完成），
  并实际验证此前失败文件可读。
- 修正 Job d6 `2119759136319229954`、d7
  `2119759221633597442` 仍在首条 audio 报
  `LibsndfileError: System error`。1 秒隔离 Job
  `2119759986798252033` 进一步确认：登录节点可读取这些文件，
  但 AI 容器的 uid0 对同一 d4 路径得到
  `FileNotFoundError(2)`；AI 容器根本没有挂载其他账号 home。
  因此不再通过 d6/d7 AI 容器跨账号读 audio，也不做盲重试。
- 改用 d5 HPC Slurm，把 26,917 行合并 manifest 复制到 d5，
  在同一节点的 `/public/home` 直接读取 d4 audio。已提交 Job
  `1071788`：`hx1hdnormal`、1 DCU、16 CPU / 60 G、14 h，
  预计 12、最坏 14 卡时；`sbatch --test-only` 是
  Job `1071787`（未创建），实际提交为 `1071788`。输出
  `processed/embeddings/target_speaker_mean32_hpc_20261109`。
- 下一步：d6 BF16 长训和 d7 FP32 分支并行；两边都按 2k
  snapshot 做 dev-100 选模。只有明显超过 hpclong 6k 的候选才走
  完整 1,934 句复评。
- 未决的 target embedding 口径：现有 speaker-mean-L2 只平均该
  target speaker 在 1,924 条映射中出现的 1–13 条 utterance，
  训练侧 speaker embedding 则平均约整组 clean-100 utterance。
  这不是完整 other-500 speaker mean，后续只有在证据支持时才
  构建更强的 speaker-level 对照，不能把当前 proxy 说成完整 mean。
- 32-sample speaker mean 完成后，先在 speaker-disjoint dev-100
  上做 target anonymisation A/B；只有同时改善 UTMOS/WhiSQA 且
  WER 不退化，才在完整 1,934 句 test 上复评。
- 原始语音 MOS 校准已通过，关闭 evaluator 版本/预处理假设；
  后续不再为这项做新的卡时实验。
- d7 暂不能并行训练：其 train-clean-100 records 指向 `a094f4d4`
  的 audio/codes，d7 无本地 LibriTTS 音频且无读权限。

## 0.0.3 2026-11-08 23:00 论文对齐训练准备

- 上游审计后的新配方固定为 feature-matching 2x、learning rate
  `2e-4`、generator gradient clipping `0.0`、单 DCU、总 batch
  `16`。旧 8e-4 optimizer state 不再续用。
- d6 的 LibriTTS train-clean-100 下载已恢复为单登录节点、
  16 路断点续传，并使用共享文件锁避免两个登录节点重复写同一分片。
  下载完成后由独立 finalizer 自动校验 size `7,723,686,890` 和
  MD5 `4a8c202b78fe1bc0c47916a98f3a2ea8`，解压并核对
  `33,236` 个 WAV。
- finalizer 会把 d6 的
  `unit_records.jsonl` 从 d4 音频路径改写为 d6 本地路径，保留
  `unit_records.source_d4.jsonl`，然后逐项验证 audio、codes 和
  k-means codebook。完成标记为
  `logs/n019_official/d6_training_data_ready.json`。
- 2026-11-09 00:32 数据 finalizer 已完成：archive 精确 size
  `7,723,686,890`、MD5
  `4a8c202b78fe1bc0c47916a98f3a2ea8`、WAV `33,236`；
  `unit_records.jsonl` 为 `33,236` 行，SHA256
  `5d3bb4d7bc41cfd973d9313b84b3faae32c3a3abcb572a03153badfa7669e50d`，
  audio/codes/codebook missing=`0`。NT speaker embeddings
  SHA256 `698d128292e8abbdb0db5d39301539cfc80184b8982133566ba3bf8b6492a866`。
- 已提交 d6 任务 `n019_voc2x_lr2e4_20261109_003725`，
  JobID `2119469373940383745`。规格：d6、
  人工智能/模型训练、113 组、1 DCU、15 CPU / 59 GB、
  2 h，预计 1.75、最坏 2.0 卡时。输入为校验后的
  33,236 条 clean-100 records、NT speaker embeddings 和锁定的
  2x recipe；输出
  `runs/n019_official/vocoder_nt_2x_lr2e4_fresh_20261109_003725`。
  提交前实时 d6 余额 `37.1194444443` 卡时。任务已启动并通过
  recipe 检查；配置已设 `submit:false` 并记录 JobID，严禁重复提交。
- Job `2119469373940383745` 在 2026-11-09 01:11:35 失败：
  数据路径完整校验、recipe、DCU tiny-matmul、mel 和 HuBERT
  preflight 均已通过，`meta.json` 已写出，但 `n019.vocoder`
  在首个训练 step 前收到 `SIGSEGV`，`training_log.jsonl` 为
  `0` 字节。没有 loss、checkpoint 或 NaN/OOM。任务实际墙钟约
  `0.567` h / `0.567` 卡时，不得原样重提。
- 已提交 15 分钟故障隔离 Job `2119478599321141249`，名称
  `n019_vocfault_20261109_011405`；d6、1 DCU、15 CPU / 59 GB，
  预计 0.12、最坏 0.25 卡时，提交前余额 `36.7458333332`。
  依次测试 model-only batch 2、direct trainer batch 2/16 workers 0、
  以及 `torch.distributed.run` 单 rank batch 2；这些只使用官方
  clean-100 的 16 条 smoke 子集，不进入正式结果。
- 已新增 continuation launcher
  `scripts/launch_vocoder_nt_2x_lr2e4_continue_ai.sh`，只从同一
  输出目录的完整 `last.pt` 恢复，并在启动前核对 lr、clipping 和
  recipe；每段结束后另行提取 segment generator。
- 首次训练前的 33,236 条 NFS 路径逐项 `is_file()` 校验约需
  40 分钟。已为后续续训增加
  `scripts/verify_training_data_marker.py`：只有当前 records 行数、
  records SHA256 和 embeddings SHA256 与 finalizer marker 完全
  一致时才允许 `N019_SKIP_PATH_VERIFY=1`，避免每段重复扫描
  99,708 个路径。首次 fresh run 仍使用完整逐项校验。
- 40-speaker dev-100 已通过本机中转从 d6 导入 d7。tar SHA256
  `f546621dfac5cbcf439236ee6c7175c97288dac74632b591d464ee894d022ab0`；
  d7 重写后 `manifest.jsonl` SHA256
  `20a62e8e6a1b3cd47f104de934114e77330871742c6a7bff476c916e942ed9cd`，
  `unit_records.jsonl` SHA256
  `95f4efd9e8ba146a3c3c82d9daf13063a8b1c571f9a71f4cda6bf2c608a5f85c`，
  100 条记录、audio/codes/codebook 全部可读。
- 本地测试最新结果：`123 passed, 3 skipped`；另修复了
  SCNet 表单提交后路由判断过早命中的问题，避免把仍在表单页误判为
  已提交任务。

## 0.0.2 2026-11-08 2x vocoder 从 step 16k 继续训练

- 用户明确要求继续训练，不能停在 step 14k。上一轮 Job
  `2119073031535542274` 的 `last.pt` 保留完整 G/D/优化器状态，
  step `16000`，SHA256
  `6c0837065c1612578d21285127c7c1e8152e2bd7e7e1d19d3f0197a7ab97a0f4`。
- 已提交 d4 Job `2119273319220133890`，名称
  `n019_voc2x_cont16k_20261108_113823`。规格：d4、
  人工智能/模型训练、2 DCU、15 CPU / 59 GB per card、
  1.7 h，预计 3.2、最坏 3.4 卡时；提交前 d4 余额
  `3.8683333333`。
- 新的独立输出为
  `/public/home/a094f4d4/voice_projects/runs/n019_official/vocoder_nt_2x_cont16k`。
  先把原 `last.pt` 复制到新目录并逐项校验 SHA256，不覆盖原
  `vocoder_nt_2x_diag`。从 step 16000 的 G/D/优化器状态续训，
  目标 step `33000`，每 2k 保存 generator snapshot，内部限制
  1.65 h，外层 6000 秒 SIGKILL。
- 保持 `mos_offline`：不使用 mel-L1 早停或选模，后续仍须在
  speaker-disjoint dev 固定样本上按 UTMOS/WhiSQA/WER 选模。
  配置已记录 JobID 并设 `submit:false`，严禁重复提交。
- 2026-11-08 12:26 Job 在节点 `10.6.15.34` 通过 300 秒
  tiny-matmul watchdog、clean-100 路径校验和 HuBERT preflight，
  2 DCU 上恢复训练；`elapsed_hours=0.0465` 时到 step `16320`，
  loss 有限，约 `0.35 s/step`。NFS 逐项路径验证和 preflight
  花费约 48 分钟，外层 6000 秒自 Job 启动计时，因此本次预计
  到约 step 25k 就会被外层 SIGKILL，而不是 33k；仍会保存
  16k 之后每 2k 的 generator snapshot。
- 2026-11-08 13:18 外层 `timeout --signal=KILL 6000` 按计划
  终止，平台状态“失败”；这不是数值或模型失败。训练日志最后
  step `24760`、elapsed `0.88252 h`，约 `0.35 s/step`，
  所有 `loss_d/loss_g/mel_loss` 有限。持久 `last.pt` 为 step
  `24000`，SHA256
  `7db8b51de5400b00c1fd873a7d7500d689ca391084422c908e3d2704f8811e4f`。
- 新 snapshots：step `18000/20000/22000/24000`，SHA256
  `a784e78e4202de2728d3bbb837c56fea6f2579014101eb018e899ef58bb5b109`、
  `c54ce9ad9810bfc1662868d8214e730e5d5f197a9193710836b30d912c3261b3`、
  `0cba4876dd92fb97839eab60352c66b1742ac74d5f76f98d98cc81c731c28b70`、
  `d2c2612cb782908c791b0ac507c3166cdb219b899e8289591ba54b2932894fec`。
  没有 `generator_final.pt` 或 `final_sha256.txt`，因为 SIGKILL 发生在
  DDP 正常退出后的 postprocess 前。不得重提旧 Job；下一步只做
  snapshot selection。
- 已构建 d7 自包含 dev-100 selection 子集：固定沿用上一轮同一
  100 句，故仍只有 1 个 dev speaker；audio、codes、
  `.normalized.txt`、manifest、100 条 unit records、k-means
  codebook 和 250-D speaker embeddings 合计 304 个文件、
  `29,019,329` bytes。bundle tar SHA256
  `194596fd40eeed3a976de94cbe0804733a253277516ba7fa3f9742d0ff483d39`；
  d7 解包后逐文件验证通过，`manifest.jsonl`
  `76cd5c97a0a2647bc99db642782f3960669dcb887bd6f95650a8588a56b72d22`，
  `unit_records.jsonl`
  `187cc18623d41530af3913e34ddde2aca9f4e677a4840882ffbcfb978cb2e36d`。
- step `14000/18000/20000/22000/24000` 五个 generator 已汇集到 d7
  `tmp/n019_2x_selection_pool_20261108`，SHA256 全部复核一致。
  `d7-vocoder-selection-2x24k` 已提交：Job
  `2119366739818729474`、名称
  `n019_vocsel_2x24k_20261108_174936`。规格为 d7、
  1 DCU、15 CPU / 59 GB、1 h，预计 0.45、最坏 1.0 卡时；输出
  `runs/n019_official/vocoder_selection_2x24k_20261108`。
  提交前实时余额 `23.0988888886` 卡时。配置已设 `submit:false`
  并记录 JobID，严禁重复提交。
- 2026-11-08 用户授权：后续实验可由 AI 自行核对余额、记录资源计划
  并提交，不再逐项等待确认；仍禁止重复提交、超额卡时和无计划实验。
- Job `2119366739818729474` 启动后发现 d7 的
  `run_vocoder_snapshot_selection_ai.sh` 是旧版（SHA256
  `8c24663a0fe3bb133435e9402b5b01260d2a46f62254455a1560d4cb4fe7fdd7`），
  `make_kaldi_dataset` 仍只写 utterance ID，导致 baseline WER
  被错误计算为 `2260%`；baseline UTMOS/WhiSQA
  `2.1344790483/2.1209076747` 正常。已把修正版脚本同步到 d7，
  SHA256 `72f691aafa1a29a469c9f28be005f7127559c388a0f6d84f1a1f31dc5f611baa`，
  `bash -n` 通过。当前 Job 继续产出各 candidate 的 reconstruction、
  UTMOS、WhiSQA 和 WAV；完成后必须用修正版
  `N019_SELECTION_RERUN_WER=1` 只重算 WER，不能采用当前 WER 或
  `selection.json` 的 WER gate 结论。
- 已准备同输出目录的续跑任务
  `d7-vocoder-selection-2x24k-rerun`，`submit:false`：d7、
  1 DCU、15 CPU / 59 GB、1 h，预计 0.45、最坏 1.0 卡时。
  它复用已完成的 reconstruction/UTMOS/WhiSQA，补未完成
  snapshots，并强制只重算五个候选的真实 transcript WER。
  等当前 Job 结束或超时后，重新核对余额即可自行提交。
- 首轮选模 Job `2119366739818729474` 于 18:44:47 到 3300 秒
  外层墙钟失败；已完成 baseline 与 14k 的 reconstruction、
  UTMOS、WhiSQA，18k 完成 reconstruction+UTMOS，但所有 WER
  因旧脚本无效。baseline UTMOS/WhiSQA 为
  `2.1344790483/2.1209076747`；14k 为
  `2.6693476605/2.4236758664`，与上一轮结果一致。
- 已用修正版 helper 提交续跑 Job `2119381103774814210`，
  名称 `n019_vocsel_2x24k_rerun_20261108_184641`；d7、1 DCU、
  15 CPU / 59 GB、1 h，预计 0.45、最坏 1.0 卡时；提交前余额
  `22.928333333`。同输出目录复用已有 WAV/MOS，补 18-24k 并
  只重算五个候选真实 transcript WER。配置已设
  `submit:false` 并记录 JobID，严禁重复提交。
- 续跑 Job `2119381103774814210` 于 19:41:51 再次达到 3300 秒
  外层墙钟，平台状态失败；这是资源止损，不是指标或模型错误。
  已完成的 dev-100 候选为：
  - baseline UTMOS/WhiSQA/WER =
    `2.1344790483 / 2.1209076747 / 21.5909090909%`；
  - 14k = `2.6693476605 / 2.4236758664 / 21.1101398601%`；
  - 18k = `1.3242171955 / 1.9122492060 / 20.6730769231%`；
  - 20k = `2.1469291484 / 2.1976736963 / 20.4108391608%`。
  18k MOS 明显塌陷，20k 仅部分恢复，二者都没有超过 14k；
  当前可比较结果仍支持 14k，不能选 18k/20k。
- 22k 在超时前刚开始 reconstruction，`0` 个 WAV、无
  `reconstructed.jsonl`；24k 尚未开始。`.partial` 不会自动续写，
  因此下一任务直接从 22k/24k checkpoint 重跑这两个候选，不重算
  baseline/14k/18k/20k，也不重算它们已有效的 WER。
- 2026-11-08 21:25 实时余额：d7 `21.2652777775` 卡时。
  已提交 d7 Job `2119421417803563009`，名称
  `n019_vocsel_2x24k_tail_20261108_212651`。规格为 d7、
  人工智能/模型训练、1 DCU、15 CPU / 59 GB、2 h，
  预计 1.4、最坏 2.0 卡时；输出仍是
  `runs/n019_official/vocoder_selection_2x24k_20261108`。
  任务只匹配 `generator_step0002[24]000.pt`，复用前四个候选，
  最后用全部 `candidate.json` 重新排名。配置已回写 JobID 并设
  `submit:false`，严禁重复提交。
- Job `2119421417803563009` 已完成 22k/24k 与全部候选排名：
  - 22k UTMOS/WhiSQA/WER =
    `2.5313126397 / 2.3560563654 / 20.8479020979%`；
  - 24k = `2.5692791879 / 2.3806050718 / 20.4545454545%`；
  - 14k 仍为 `2.6693476605 / 2.4236758664 / 21.1101398601%`。
  24k 比 22k 恢复，但仍低于 14k；最终 `selection.json` 选择
  step 14000。`selection.json` SHA256
  `318db649528cc90d5102b134e7acf9395bc3edc1a27811c1c909d870859dd7f8`，
  `selection.md` SHA256
  `fbe6051e9a2f1c1f64f2cdbf9583b72d6c6de1e4e8df82b80a8ba9e2a15b500f`。
  不重跑该 Job，也不因 24k 再做全量复评，因为 dev 上未超过 14k。
- 2026-11-08 零卡时上游审计发现新的关键实现错误：
  speech-resynthesis commit `dbb92c8ddeb081e711adbe9a75714027cd447532`
  的主配置、VCTK 和 Expresso 配置均为 `learning_rate=2e-4`，而旧
  N019 vocoder 误用 `8e-4`；旧训练还额外裁剪 generator 梯度 `5.0`，
  上游没有该步骤。旧 4k/76k/102k 和 2x 14k–24k 都因此只能作为
  历史/诊断结果。代码、机器可读配置、测试和文档已改为 `2e-4`、
  gradient clipping 关闭。详见
  `docs/N019_UPSTREAM_TRAINING_AUDIT_20261108.md`。
- 论文写两个 RTX 4090 用于两个 Unit HiFi-GAN 模型；旧实现用
  2 DCU DDP、总 batch 32。新 NT 论文对齐训练改为 1 DCU、batch 16，
  与引用配置的单卡 batch 一致，不再复用旧 optimizer state。
- d6 已创建版本化代码目录
  `code/n019_official_lr2e4`，同步后
  `vocoder.py` SHA256
  `ac623b7b7fee47728186df19205e36f39661e387f115e956c5509fc21342fcad`，
  远端 `bash -n` 和 6 项目标测试通过。d6 的 33,236 个 unit code
  aggregate SHA256 与 d4 完全一致
  `4551b5e6baf014671abc7f3b98ac14126483583cc4df4d23a9fb6493ca3e604f`；
  speaker embeddings 与 k-means codebook 哈希也一致。只缺
  LibriTTS train-clean-100 音频。
- d6 正在后台自行多连接下载官方 LibriTTS train-clean-100：
  size `7,723,686,890` bytes、expected MD5
  `4a8c202b78fe1bc0c47916a98f3a2ea8`。完成并校验前不得提交训练；
  下载不占卡时。
- 已构建真正与 clean-100 训练集 speaker-disjoint 的 VPC `libri_dev`
  选模集：40 speakers、100 句，每 speaker 2–3 句，覆盖
  1.8–24.8 秒，平均 7.691 秒。由 d4 生成、经本机中转至 d6；
  tar SHA256
  `8de9fb0f88e9558e0f3bed88d1c9aea68b853977feb9db583ec42a28803aa018`。
  d6 `manifest.source_d4.jsonl` SHA256
  `887ba1221e72e92a79e51bac7d589be2af5cf55ea80a2e7347e2c8c93ad72e32`，
  改写 d6 绝对路径后的 `manifest.jsonl` SHA256
  `26de28d291efc45d615c13ec968dfc85760e86cba1a70a1395100d1a09d4a20a`。
- d6 Job `2119432607435173890` 先完成 100 个 unit codes，随后因
  版本化代码归档缺 `compat/torchaudio` 在 W-PRO 导入处失败。
  重试 Job `2119434958879289346`
  （`n019_dev100_retry2_20261108_222040`）复用已有 units，仅补
  speaker embeddings，已成功：40 个 250-D speaker keys，全部
  finite 且 L2 norm≈1。`verify.json` SHA256
  `688b1014c096013c2ffe63b79cc3c14522e3ee26435516f6b00ad35bdd70dd72`，
  `unit_records.jsonl` SHA256
  `249aa5c2f551cdc4b1921939ab70d55816170f01f51d2b83b08ca26029fdad92`，
  speaker NPZ SHA256
  `f9c010d2e455080fd756c70846c005225961eb69f757f749ae4049ebc6e533ad`。
  输出位于
  `data/n019_official/processed/selection_dev100_vpc_units_20261108_retry1`。
- 选模资产完成不代表可以跳过论文对齐训练：旧 2x14k 仍是 test 上
  完整复评的最佳结果；接下来必须等 d6 的 LibriTTS 下载/解压完成，
  再用 `2e-4`、1 DCU、batch 16、无 gradient clipping 从头训练，
  在 40-speaker VPC dev-100 上选模。

## 0.0.1 2026-11-08 2x14k 完整复评结果

- DU-pred-nt-2x14k 已完成完整 1,934 句复评。最终指标为
  WER `6.509331659151875%`、UTMOS `2.8773497233962817`、
  WhiSQA `2.863154954661258`；论文值仍是
  `7.41% / 3.63 / 3.69`。
- 相对旧 ext102k，WER `-0.245419781975914` 个百分点，
  UTMOS `+0.2631017239658391`，WhiSQA
  `+0.1129603277287245`；三项均改善。相对论文仍差
  WER `-0.9006683408481253` 个百分点、UTMOS
  `-0.7526502766037182`、WhiSQA `-0.8268450453387421`。
- 产物计数已核对：anon/VPC wav `1934`，enrolls `438`，
  trials_f/m wav `734/762`，trials
  `11744/9906`，WER `1496`，UTMOS/WhiSQA `1934`。
- `quality_metrics.json` SHA256
  `533e82a16ef4abb5231162b20a143f4bcfa7872a72799ae4ffcab03a7a1b48cf`；
  WER/UTMOS/WhiSQA 单项 JSON SHA256 分别为
  `9ea55fd1f2e56f5956855ec6274c344c61607837bb607a0bae6f3cde667f57b5`、
  `6e11c19d5ba6c7a5241f0cd88ebd4a4859b29f43b0473f7cdac5ab43206e94d2`、
  `8903f3eaf596f9be4a35067abd04cf56b6f1eef4d38fd745271157de22405ae8`。
- Job `2119203372156080129` 在节点 `10.6.15.47` 正常通过 300 秒
  DCU watchdog；科学流程完成并打印
  `DU_PRED_NT_2X14K_FULL_QUALITY_COMPLETE` 后，才因脚本末尾
  CRLF 的 `\r` 返回非零。不得重跑整个 Job；只修脚本换行。
- 当前 2x14k 是完整、可复算的三项指标新最佳候选，但按正式结果
  替换规则，旧 ext102k 仍是现有正式表值，2x14k 待用户确认后再
  切换正式 checkpoint 与表项。

## 0.0.0 2026-11-07 质量修复交接

- 详细记录见 `docs/N019_QUALITY_FIXES_20261107.md`。
- d7 连续三次 2x 训练均在启动门禁失败，根因是
  `libritts_train_clean_100/unit_records.jsonl` 指向
  `a094f4d4` 的音频、codes 和 codebook，而 d7 无权跨账号读取。
  这不是训练代码或 checkpoint 错误。
- 已改由原生拥有数据的 d4 执行同一 2x 诊断。d4 已核验：
  33,236 条 unit record 的 `audio/codes_path/kmeans_codebook`
  全部本地可读；`verify_n019_training_recipe.py` 通过，
  feature-matching probe `4.0`、lock SHA256
  `370ef79bc7f85a86ea1e25afae903e9993e20c2e4da449d942c80aa12233b7e9`；
  初始化 checkpoint SHA256
  `62eb5908aae998f50eed1456a8f6a8f606a88c07627c1d92517f0d072c9ff151`。
- 2026-11-07 22:22 已提交 d4 Job `2119073031535542274`，
  名称 `n019_voc2x_diag_d4_20261107_222229`。规格：d4、
  人工智能/模型训练、2 DCU、15 CPU / 59 GB per card、2 h，
  预计/最坏 4.0 卡时；提交前 d4 实时余额 `8.3249999999`。
  输入固定为 ext102k generator、d4 本地 clean-100 units 和 NT
  speaker embeddings；输出独立
  `runs/n019_official/vocoder_nt_2x_diag`，每 2k step 保存
  generator snapshot，不按 mel L1 早停或选模。配置已设
  `submit:false` 并记录 JobID，严禁重复提交。
- 2026-11-07 22:34 d4 的 300 秒 tiny-matmul watchdog 通过，
  `device_count=2`、`tiny_matmul=-17654.423828125`；mel 和 HuBERT
  preflight 均通过。训练于 22:42:18 完成 DDP 初始化，首步
  `loss_d=7.9975605`、`loss_g=37.8575134`、`mel_loss=34.1501236`，
  到 step 700 的 loss 有限、约 `0.337 s/step`，确认不是 CPU 回退。
- 2026-11-07 22:55 训练到 step `2100`，loss 持续有限，速度约
  `0.34–0.35 s/step`。首个 compact snapshot
  `snapshots/generator_step00002000.pt` 已于 22:54 成功写出，
  大小约 55 MB；完整 `last.pt` 约 973 MB。说明 `mos_offline`
  的 snapshot 机制正常，可进入后续 2k 间隔选模。
- 2026-11-08 00:17 d4 2x 训练被外层 `timeout --signal=KILL 6900`
  终止，平台状态“失败”，但训练日志已到 step `16380`、elapsed
  `1.58923 h`，loss 有限。这是墙钟终止，不是数值或模型错误；
  不要重提该训练 Job。完整保留 8 个 compact snapshots
  （step 2000–16000，每个约 55 MB）和 `last.pt`；SIGKILL 发生在
  postprocess 前，因此未生成 `generator_final.pt` 和
  `final_sha256.txt`，不影响 snapshot selection。
- 2026-11-08 00:52 d4 实时余额 `4.4922222221`。完整 8 个
  snapshot 各做 100 句三项指标会超过原定 1 h，因此先做最小必要的
  baseline + step `16000` 100 句 dev screen；若 16k 不胜出，再
  评估 14k/12k。选模脚本新增
  `N019_SELECTION_SNAPSHOT_GLOB`，SHA256
  `cf8b348e5d1944a89a364716f0ebf9bcdec66521acc79ac9f885f76b0d5b1cb6`。
- 2026-11-08 00:54 已提交 d4 Job
  `2119111166460579842`，名称
  `n019_vocsel_d4_20261108_005402`。规格：d4、人工智能/模型训练、
  1 DCU、15 CPU / 59 GB、1.5 h，预计 0.8、最坏 1.5 卡时。
  输入为 speaker-disjoint dev 固定 100 句、ext102k baseline、
  step 16000 snapshot 和固定三项 metric；输出
  `runs/n019_official/vocoder_selection_20261108_005402`。
  配置已设 `submit:false` 并记录 JobID，严禁重复提交。
- 2026-11-08 00:55 首个选模 Job `2119111166460579842` 的
  tiny-matmul watchdog 在打印 `device_count=1` 和 `device_name=BW`
  后 300 秒 SIGKILL，平台状态失败；这是已知坏 DCU 节点，不是
  选模代码错误。2026-11-08 01:52 实时余额 d4
  `4.408611111`。已按“快速失败并重试一次”提交新 Job
  `2119126896895348737`，名称
  `n019_vocsel_d4_retry1_20261108_015529`。规格仍为 1 DCU、
  15 CPU / 59 GB、1.5 h，预计 0.8、最坏 1.5 卡时；只复用输入，
  输出 `runs/n019_official/vocoder_selection_20261108_015529`。
  配置已设 `submit:false` 并记录 JobID，严禁重复提交。
- 2026-11-08 01:55 重试 Job `2119126896895348737` 正常通过
  watchdog，但 d4 代码目录缺少本地已有的 `wer_eval_vpc.py`。
  baseline 的 100 句 reconstruction、UTMOS、WhiSQA 已完成，
  数值为 `2.1344789516925813 / 2.1209082275629045`；WER
  启动时报 `No module named n019.wer_eval_vpc`。实际输出目录
  为 `runs/n019_official/vocoder_selection_20261108_015814`。
  已同步 `wer_eval_vpc.py`，源/远端 SHA256
  `a9aea2877c93cf04aa5b47327e113b4aef73f898f596399d70033cf572a628f2`，
  并验证模块可导入。
- 2026-11-08 02:58 d4 实时余额 `4.2452777777`。已提交续跑 Job
  `2119143626710753282`，名称
  `n019_vocsel_d4_retry2_20261108_030201`。1 DCU、
  15 CPU / 59 GB、1.5 h，预计 0.6、最坏 1.5 卡时；
  `N019_SELECTION_OUT` 固定到 `..._015814`，复用 baseline
  WAV/UTMOS/WhiSQA，只补 baseline WER 与 step 16000 全套。
  配置已设 `submit:false`，严禁重复提交。
- 2026-11-08 03:40 续跑 Job `2119143626710753282` 完成。
  baseline 与 step 16000 的 UTMOS/WhiSQA 分别为
  `2.13447895 / 2.12090823` 和 `2.18320574 / 2.12432567`；
  16k delta 为 `+0.04872679 / +0.00341745`，低于预设
  `+0.05 / +0.05` 门槛，不能选 16k。
- 同一任务发现 WER 参考文本无效：LibriTTS dev manifest 本身没有
  `text`，旧 selection 代码写出的 `selection/text` 只有 ID，
  导致 SpeechBrain 把参考当成单 token，显示
  `%WER 2260.00`。已修 `make_kaldi_dataset`，从每条源音频旁边的
  `*.normalized.txt` 恢复真实 transcript；并新增
  `N019_SELECTION_RERUN_WER=1` 只重算 WER。选择脚本 SHA256
  `72f691aafa1a29a469c9f28be005f7127559c388a0f6d84f1a1f31dc5f611baa`。
- 2026-11-08 03:53 实时余额 d4 `4.1177777777`。已提交 WER-only
  重算 Job `2119157545622589441`，名称
  `n019_vocwer_rescore_20261108_035705`。1 DCU、15 CPU / 59 GB、
  45 min，预计 0.15、最坏 0.75 卡时；复用已有 reconstruction 和
  UTMOS/WhiSQA，只重建真实 text、重算两个 candidate 的 WER。
  配置已设 `submit:false`，严禁重复提交。
- 2026-11-08 04:00 WER 重算完成，真实 transcript 下的指标为：
  baseline UTMOS/WhiSQA/WER `2.1344789517 / 2.1209082276 /
  21.5909091%`；step 16000 `2.1832057416 / 2.1243256733 /
  21.1101399%`。16k delta 为 `+0.04872678995 / +0.00341744572 /
  -0.4807692308 pp`，两项 MOS 仍低于门槛，`selection.json`
  正确选择 baseline。`selection.json` SHA256
  `9b100c267adbfa3d3dbbf37aed2b0bfc5936c393d0700b57ebc704b82b4582f8`，
  `selection.md` SHA256
  `861f10d8efd8464c29b11b17b8414588a4449e2bb6d5b085d53785bb22092982`。
- 2026-11-08 04:54 d4 实时余额 `4.0533333333`。已提交 step 14000
  screen Job `2119172855578009601`，名称
  `n019_vocsel_step14k_20261108_045739`。d4、1 DCU、
  15 CPU / 59 GB、1 h，预计 0.5、最坏 1.0 卡时；复用同一固定
  输出目录中的 baseline 与 16k candidate，只新增
  `generator_step00014000.pt` 的 100 句 reconstruction、
  UTMOS/WhiSQA/WER 和最终排序。配置已设 `submit:false`，
  严禁重复提交。
- 2026-11-08 05:00 step 14000 screen 完成并通过 dev gate：
  UTMOS/WhiSQA/WER `2.6693478274 / 2.4236760825 / 21.1101399%`，
  相对 baseline delta `+0.5348688757 / +0.3027678549 /
  -0.4807692308 pp`，`eligible=true`，selection 选择 14k。
  checkpoint SHA256
  `343b3a4117b69c72c3b1a2c4fbe69e6c10830af0caccc950e988af9f1828cf45`。
  更新后的 `selection.json` SHA256
  `f79d746447bfd9055ced6539c4aef212f72ed6aab4f810ca2cc42ac80eafb5c6`，
  `selection.md` SHA256
  `e9b6e1f81a516cf389e2f0d07283c8f1f9b147f38066c3766c9b40a43e3e3afb`。
- 已将 14k checkpoint 从 d4 经本机中转至 d7，源/中转/目标 SHA256
  均为 `343b3a4117b69c72c3b1a2c4fbe69e6c10830af0caccc950e988af9f1828cf45`，
  d7 路径为
  `voice_projects/tmp/n019_2x14k/generator_step00014000.pt`。
  `anonymize_libri_test_paperfix_remote.sh` 已增加
  `target_id|target_speaker` 与 `utterance|speaker_mean_l2`
  的显式输入校验和 CLI 透传，SHA256
  `2d960c5dee704e1af8a9f94a54b2832c9e29d9e68d84160822ab537e9e6da06a`；
  新 runner SHA256
  `d1cbd176f9930ac8fdd074f80277f99ecf0426ba2e6e54f78832e061e26d7852`。
- 2026-11-08 06:00 d7 实时余额 `24.0241666663`，已提交完整 1,934 句
  复评 Job `2119189556546523137`，名称
  `n019_du_pred_nt_2x14k_20261108_060403`。规格：d7、
  人工智能/模型训练、1 DCU、15 CPU / 59 GB、2 h，预计 0.75、
  最坏 2.0 卡时。输入为 14k checkpoint、1,934 条
  source/unit/target map、843-key target-speaker mean-L2 embeddings、
  固定 duration/ASR/UTMOS/WhiSQA；输出
  `anonymised/libri_test/DU-pred-nt-2x14k`、VPC suffix
  `_n019_2x14k`、`eval/du_pred_nt_2x14k`。配置已设
  `submit:false` 并记录 JobID，严禁重复提交。
- d4 已独立准备完整选模资产且与 d7 固定版本逐项 SHA256 一致：
  Whisper-small config/model/tokenizer 为
  `e6a2b489.../1d773488.../27fc476b...`；Wav2Vec2 配置和
  SpeechBrain ASR local-HF 探针通过；WhiSQA checkpoint
  `2da43d59...`；UTMOS `44c57e3e...`。公开大文件均在 d4
  本账号下载，没有经本机中转。
- 全量 1,934 句 duration 诊断已完成（CPU、0 卡时）：
  无负值、无零时长、无非有限值；total-duration relative error
  mean `0.0477569`、p95 `0.1259830`；WAV 绝对时长误差
  mean `0.3618411 s`、p95 `1.0635 s`。JSON SHA256
  `9c5818e6624d32e7788a5b5cae13886845960729f171a9460bdde3b0a5a3784a`。
  这与 25 句 A/B 一致：duration 有误差，但不是剩余约 1 分 MOS
  差距的主因，暂不重训。
- 已修正并锁定 2x feature-matching：
  `src/n019/hifigan.py` SHA256
  `ce1cdb2eecd65ecaf4d4c3ecea5bc7c3041692159c515a8911039411937ec830`；
  `src/n019/training_recipe.py` SHA256
  `083c2363b560122fccbcd974c02bfeb0bffb355638d99e2c1feef818fee134cd`。
  d6/d7 已同步并通过 `scripts/verify_n019_training_recipe.py`。
- 新增 `mos_offline` 选模：关闭 mel L1 early stopping，保存
  `snapshots/generator_stepXXXXXXXX.pt`，再由 dev 固定样本的
  UTMOS/WhiSQA 加 WER gate 离线选模。`best.pt` 不再由 mel L1
  自动代表 MOS。
- 新增 target embedding speaker-mean-L2 口径和 A/B 脚本。
  d7 已生成 843 个 target speaker key、250-D、
  NPZ SHA256
  `72e360948e3e8f49fe12c7e6082d67ded9d1477b8dd528745698cb9b0a00f13c`；
  注意这是被选中 target utterance 的 proxy，不是完整 other-500
  speaker 均值。
- 新增 speaker-disjoint vocoder dev split：train 31,245 / dev 1,991，
  dev manifest SHA256
  `963d2146a77910e8356bc6ea98b3be972242a6cbf3fc3221cba96aa3f164c811`。
  新增 `reconstruct_vocoder.py`，选模采用源说话人重建，避免在
  论文 official test 上反复调 checkpoint。
- duration 诊断已补原始/舍入/负值/WAV 时长误差，并支持按
  total-duration relative error 选 duration checkpoint。现有 25 句
  证据显示 duration 不是 MOS 主因。
- target A/B 和 2x 诊断已分别提交；`d7-vocoder-snapshot-selection`
  仍等待 2x snapshots。任何新 GPU 任务先过 300 秒 SIGKILL
  tiny-matmul watchdog。
- 2026-11-07 21:13 target embedding A/B Job
  `2119055643385360385` 已完成：100 句 utterance embedding 为
  UTMOS/WhiSQA/WER `2.4527917790 / 2.6547999933 / 8.1640780566%`；
  speaker-mean-L2 为 `2.5831683111 / 2.7459385157 / 7.9649542015%`。
  配对差 `+0.1303765321 / +0.0911385223 / -0.1991238550 pp`。
  这是一项有效口径修正，但不能单独填平论文差距。
- 2026-11-07 22:00–22:09 的 d7 2x 提交
  `2119067497001140225`、`2119068434422919169`、
  `2119069752202182658` 仅保留为失败追溯；三者都在训练前
  数据权限门禁失败，没有有效训练结果。完成后必须先跑
  snapshot selection，不得直接做全量 1,934。

## 0.0.1 短期计划：只做 DU-pred-nt（2026-11-04 22:15）

- 2026-11-06 23:13：已提交 step 102k 的完整 1,934 句质量复评
  Job `2118723529665581057`（`n019_ext102k_quality_20261106_231328`）。
  d7、人工智能/模型训练、1 DCU、15 CPU / 59 GB、2 h 墙钟，
  预计 0.5、最坏 2.0 卡时；提交前 d7 余额 `40.7927777775` 卡时。
  输入固定为 ext step 102000 checkpoint（SHA256
  `62eb5908aae998f50eed1456a8f6a8f606a88c07627c1d92517f0d072c9ff151`）、
  duration paperfix、1934 条 unit/target map/target embedding、d7
  官方 ASR、UTMOS22 和 WhiSQA。输出独立
  `anonymised/libri_test/DU-pred-nt-ext102k`、
  `vpc/data/*_n019_ext102k` 和 `eval/du_pred_nt_ext102k`，不覆盖
  paperfix 结果。只跑匿名化、WER、UTMOS22、WhiSQA；不跑 E-VPC/W-NT。
  配置已设 `submit:false`，严禁重复提交。
- 2026-11-06 23:26：Job `2118723529665581057` 已失败于 WER
  启动阶段。原因不是模型或数据：d7 远端 `n019/wer_eval.py` 仍是旧版，
  不识别本地已加入的 `--model` 参数；匿名化和 VPC 导出已经完成。
  已将本地 `wer_eval.py`（SHA256
  `42011dac54a3801436d1c8e75e5487235001ab3f05129ad6e11f3ea737ee3356`）
  同步到 d7。准备用同一输出目录续跑匿名化并重新执行 WER/MOS；
  新任务只能复用完整进度，不能重算已完成的 1,934 条 WAV。
- 2026-11-06 23:28：ext102k 质量复评重试 Job
  `2118727181430194177`（`n019_ext102k_retry_20261106_232758`）
  已提交，d7、1 DCU、15 CPU / 59 GB、2 h，预计 0.5、最坏 2.0
  卡时；提交前余额 `40.6369444442`。复用完整 1,934 条匿名 WAV，
  只续跑 WER/UTMOS/WhiSQA 和汇总。配置已设 `submit:false`。
- 2026-11-07 00:43：重试 Job `2118727181430194177` 在
  `--resume` 校验阶段持续 74 分钟无新日志，满足 10 分钟无进度
  停止条件，已从无头控制台停止，状态“已停止”。1,934 条 WAV 和
  四个 VPC split 仍完整。原因是按逐文件 resume 校验在这批 NFS
  输出上异常阻塞，不是 WER/MOS 结果失败。启动脚本已改为：当
  anon.jsonl、1,934 WAV 和 VPC 行数门禁全部通过时直接跳过
  anonymisation，只执行 WER/UTMOS/WhiSQA。准备以 1 DCU、1 h、
  预计 0.4、最坏 1.0 卡时的 metrics-only 任务重试；停止前余额
  `40.1105555553`。
- 2026-11-07 00:45：metrics-only 任务已提交，Job
  `2118746652075986946`（`n019_ext102k_metrics_20261107_004521`），
  d7、1 DCU、15 CPU / 59 GB、1 h，预计 0.4、最坏 1.0 卡时。
  启动脚本会在完整 WAV/VPC 门禁通过后直接跳过 anonymisation，
  只运行 WER、UTMOS22、WhiSQA 和汇总。配置已设 `submit:false`。
- 2026-11-07 00:46：metrics-only Job `2118746652075986946`
  失败于直接 HF `Wav2Vec2Processor`。远端 VPC ASR 是
  SpeechBrain `EncoderASR` bundle，只有 `tokenizer.ckpt`，没有 HF
  tokenizer 文件。已新增 `n019.wer_eval_vpc`，直接复用 VPC2024 的
  `InferenceSpeechBrainASR` 和 Kaldi ASR dataset，先合并
  enrolls/trials_f/trials_m 为官方 1,496 句 WER 集合，再评分。
  2 句 CPU smoke 已成功完成模型加载和推理。准备 metrics-only 重试；
  停止前余额 `39.3655555553`。
- 2026-11-07 00:53：最终 metrics-only 重试 Job
  `2118748742678118401`（`n019_ext102k_metrics2_20261107_005339`）
  已提交，d7、1 DCU、15 CPU / 59 GB、1 h，预计 0.4、最坏 1.0
  卡时。复用 1,934 条 WAV/VPC，不重算；WER 使用 VPC2024
  SpeechBrain `EncoderASR` 对官方 1,496 句 ASR 集合评分。
  配置已设 `submit:false`。

- 2026-11-06 21:38：d3 续训 Job
  `2118550713240682497` 已失败，不能按正常运行继续监控或重复提交。
  训练日志最后到 step `109160`、elapsed `7.4992857 h`，loss 有限；
  `best.pt` 为 step `102000`、epoch `97`、validation mel L1
  `0.7640142440795898`，SHA256
  `62eb5908aae998f50eed1456a8f6a8f606a88c07627c1d92517f0d072c9ff151`，
  大小 `56,851,575` bytes。日志在 `19:42:33` 出现 rank 1 与
  rank 0 的 `ALLREDUCE` collective timeout（`600033/600064 ms`），
  随后 rank 1 `SIGABRT`；这是 DDP/通信超时，不是非有限 loss。
  `generator_final.pt` 和 `final_sha256.txt` 未生成，原
  `vocoder_nt_paperfix` checkpoint 未被覆盖。d3 实时余额仅
  `1.3774999999` 卡时，不能覆盖另一次 2-DCU 续训。
- 2026-11-06 21:45：已将 ext `best.pt` 经本机逐项校验中转至 d7
  固定路径
  `runs/n019_official/audit/vocoder_checkpoint_cpu_20261106/checkpoints/paperfix_ext_best_step102000.pt`，
  源/中转/目标 SHA256 均为
  `62eb5908aae998f50eed1456a8f6a8f606a88c07627c1d92517f0d072c9ff151`。
  正在 d7 登录节点以 CPU 对同一固定 25 句运行 UTMOS/WhiSQA
  A/B，占用 0 卡时；输出
  `runs/n019_official/audit/vocoder_checkpoint_cpu_20261106/ext102k`，
  日志
  `voice_projects/tmp/vocoder_checkpoint_ext102k_cpu_20261106.log`。
  完成后只与 step 33,999 和 main step 76k 的 25 句结果比较，不替换
  正式 1,934 句表，也不启动新的卡时任务。
- 2026-11-06 22:29：ext step `102000` 的 CPU A/B 已完成，25 句
  UTMOS `2.469762306213379`、WhiSQA `2.703620159626007`。
  相对 main step 76k，UTMOS 降低 `0.074724245071411`、WhiSQA
  提高 `0.0597982347011565`；相对 paperfix step 33,999，分别提高
  `0.232695689201355` / `0.2845718562602997`。这是混合结果，
  未明确优于 main 76k。后续配对统计显示，与 76k 的两项差值分别只有
  `t=-0.895` / `+0.914`（25 句），在样本噪声内基本打平；但相对当前
  正式 step 4k 仍提高约 `+1.221/+0.855`。因此 102k 不应被淘汰，
  它是完整 I/WER/MOS 复评的有效候选，尤其在当前全量仍用 4k 的情况下。
  不能仅凭这批 25 句直接替换正式全量表。`summary.json` SHA256
  `173377556f4c46b42eff6e2d6f93f5be95c378f677ca5dd794bd0dd0657875d5`。
  下一步转向零卡时审计训练/声码器配方和官方实现线索，不再单纯延长
  同一训练配方。
- 2026-11-06 23:00：零卡时根因审计补上两组关键证据。使用 main step
  `76000`、相同 25 句，只把预测时长换成原时长后 UTMOS/WhiSQA 为
  `2.496909/2.665299`，相对预测时长 `2.544487/2.643822` 仅
  `-0.047578/+0.021477`，说明 duration predictor 不是主要 MOS 来源。
  用同一 vocoder 对 25 条已见 LibriTTS 训练语音做 source-speaker
  reconstruction（原时长），UTMOS/WhiSQA 仍只有
  `2.704474/2.589972`，说明残差主要是 vocoder 重建质量，不是匿名目标
  映射单独造成。另确认正式 1,934 句 run 的 `vocoder_version=4000`、
  vocoder SHA256 `f1735e757ecfc4bfb6a230ae26219058e6aed8bef18656bb2b694cc89ed070d9`；
  当前全量 `1.262/1.847` 仍来自过早选中的 step 4k。
  代码审计还发现 `feature_matching_loss` 漏掉了 speech-resynthesis
  和 DISSC 的 `2x` 系数，已修正并新增回归测试；旧 checkpoint 不能用
  修正后的损失语义解释，必须重新训练后再评价。

- 2026-11-06 16:48：d3 续训 Job
  `2118550713240682497` 正常到 step `81,720`，elapsed
  `4.75 h`；validation best 更新为 step `80,000`、
  `0.7743873596191406`。`last.pt`/`best.pt` 时间戳
  `16:37`；`generator_final.pt` 尚未生成。

- 2026-11-06 15:48：d3 续训 Job
  `2118550713240682497` 正常到 step `71,800`，elapsed
  `3.76 h`；validation best 更新为 step `66,000`、
  `0.7774511575698853`。`last.pt` 持续写入，
  `generator_final.pt` 尚未生成。

- 2026-11-06 14:50：d3 续训 Job
  `2118550713240682497` 正常到 step `61,980`；validation
  best 更新为 step `60,000`、`0.7811204195022583`。
  `last.pt` 持续写入，最终 `generator_final.pt` 尚未出现。

- 2026-11-06 12:00：用户要求每小时检查一次状态。Codex automation
  `n019` 已从 `PAUSED` 恢复为 `ACTIVE`，频率
  `FREQ=HOURLY;INTERVAL=1`。当前只监控 d3 Job
  `2118550713240682497` 和续训日志/产出；不重复提交，
  不做不必要的卡时操作。

- 2026-11-06 11:55：论文原文已核对
  （`https://www.isca-archive.org/odyssey_2026/bakari26_odyssey.pdf`）。
  Section 3.2 只说明两个 Unit HiFi-GAN 均在 LibriTTS
  train-clean-100 上用两块 RTX 4090 训练，**没有报告 step 数、
  epoch 数、batch size 或学习率**。因此不能把本项目的
  400,000-step 安全上限写成论文值。当前从 33,999 续训至
  110,000 是对选模问题的受控实验，不是论文参数复刻。

- 2026-11-06 11:17：25 句 checkpoint 对照完成。相同输入下，
  `paperfix best` step 4k 的 UTMOS/WhiSQA 为
  `1.248995` / `1.848322`；`main best` step 76k 为
  `2.544487` / `2.643822`。换到长训练 checkpoint 后分别提高
  `+1.295492` / `+0.795500`，但距论文仍有
  `-1.085513` / `-1.046178`。这说明训练步数/选模是显著原因之一，
  不能单独解释全部差距。该 25 句结果仅用于诊断，不替换完整 1,934 句表。
  首个诊断 Job `2118538301277642754` 已生成两套 25 句 WAV 后，
  因运行中的 shell 脚本被覆盖而失败；仅补跑 MOS 的 Job
  `2118540599713480705` 已完成并写出 `summary.json`，SHA256
  `22eef2b6f2eea401356fc28efe090435609071d03199fcc5ba1fc0ccb2441aab`。
- 2026-11-06 11:34：已从 d3 的 paperfix `last.pt` 提取
  generator-only step `33,999` checkpoint（56,856,123 bytes，
  SHA256 `50ce0ecb2e26a20698002a7483be171aefa42997e4318eda6b35f6086d2d4005`），
  并经本机逐项 SHA256 中转至 d7。d7 登录节点正在用 CPU 对同一
  25 句跑 UTMOS/WhiSQA；该诊断不占卡时，下一小时只检查日志和
  `summary.json`，不要重复提交。
- 2026-11-06 11:48：step `33,999` 的诊断完成：UTMOS
  `2.237066617012024`、WhiSQA `2.4190483033657073`。三个
  checkpoint 在同一 25 句上的趋势为：
  step 4k `1.249/1.848`、step 33,999 `2.237/2.419`、
  step 76k main `2.544/2.644`。训练步数提高两个 MOS 指标，
  但 76k 仍低于论文；下一步可做受控延长训练，同时继续审计
  与论文未公开实现细节有关的残余差距。
- 2026-11-06 11:46：已提交 paperfix NT vocoder 受控续训 Job
  `2118550713240682497`，任务名
  `n019_vocoder_nt_ext_20261106_114645`。d3、2 DCU、
  15 CPU / 59 GB 每卡、外层 8 h、内部训练上限 7.5 h，
  预计 15.0、最坏 16.0 卡时；提交前余额 `17.268611111`。
  从 step `33,999` 续训到最多 `110,000`，patience 放宽到 100，
  不再沿用原先 34k 早停；输出独立
  `vocoder_nt_paperfix_ext`，保留原始 `last.pt`/`best.pt`。
  任务结束时自动从新 `last.pt` 提取 `generator_final.pt`。
  配置已设 `submit:false`，禁止重复提交。下一小时只检查该任务
  和日志，不启动其他卡时任务。

- 2026-11-06 10:57：已提交零训练 checkpoint 质量诊断 Job
  `2118538301277642754`。d7、1 DCU、15 CPU / 59 GB、1 h，
  预计 0.1、最坏 1.0 卡时；提交前余额 `41.0380555553`。
  对同一批 25 句分别使用 `vocoder_nt_paperfix/best.pt`
  （step 4k）和 `vocoder_nt_main/best.pt`（step 76k），各跑
  UTMOS/WhiSQA；输出独立 audit 目录，不覆盖正式结果。
  `submit:false`，JobID 已写入配置，禁止重复提交。

- 2026-11-06 10:21：WhiSQA-only 第三次运行
  `2118528804410613762` 已完成，实例 `10:20:09–10:21:54`。
  完整评分 1,934 句：mean `1.847028814125209`、stddev
  `0.20560664702048057`、min `1.3582201302051544`、max
  `2.62214332818985`；论文 `3.69`，绝对差
  `-1.842971185874791`、相对差 `-49.945%`。
  `WhiSQA.json` SHA256
  `2f6eeca6f51f8b460a7cdc0f63273e66bb2c960a3be0c2a1b8a529f8994275df`，
  `WhiSQA.tsv` SHA256
  `d63a791af75b4b6663dfcb8fe6ede36796ff2507b090276c1f7bb53003ba78e5`。
  最新 `paper_metrics.json` / `paper_comparison.json` /
  `paper_comparison.md` SHA256 分别为
  `b48f51778575c74b090ef7cdd7a57f537d41e96bc76294637a39c4cdbfa04dda`、
  `77c843479bf4f41934097f6ccd84fb5cfbbeb9546cc24625dcac7fe1712a545d`、
  `6c5c497a477103620397cf43853261bec8114bd4b8b0ed0056126c39cedb8b67`。
  配置任务状态已改为完成，`submit:false`，不得重复提交。
- 2026-11-06 10:40：零卡时抽查 3 对原始/匿名 WAV。三句匿名输出均失去
  原始语音清晰的谐波结构，STFT 上出现明显周期性条带和宽带噪声；
  其中 `1089-134686-0004` 的匿名音频谱平坦度从 `0.00024`
  升至 `0.13302`，6–8 kHz 能量占比从近 0 升至 `0.0391`。
  原始 UTMOS/WhiSQA smoke 分别约 `4.31`/`4.59`，同一批匿名音频的
  全量分数为 `1.2621`/`1.8470`，因此不是两个 MOS scorer 全局失效；
  当前证据指向匿名音频质量。该抽查只证明缺陷确实存在，频次和根因仍需
  用更多样本及不同 checkpoint 验证。

- 2026-11-06 10:20：WhiSQA-only 第二次运行
  `2118527870481043458` 已完整评分 1,934/1,934，但汇总阶段因
  本地转存的 `eval_mos.py` 把 `statistics.stdev` 写成
  `statistics.stddev`，在写出 JSON 前失败；没有有效 WhiSQA 结果。
  已修正远端代码，`py_compile` 通过；本机与远端
  `eval_mos.py` SHA256 均为
  `a746c71b971ac54e7e1291849df4b281a289321aaaa4b96c0d617f0e2434b102`。
  第三次提交 Job `2118528804410613762`，任务名
  `n019_whisqa_resume_20261106_101942`，初始“排队中”。
  配置已再次设 `submit:false`，禁止重复提交。
- 2026-11-06 10:16：WhiSQA-only 修复版已重新提交，Job
  `2118527870481043458`，任务名
  `n019_whisqa_resume_20261106_101558`，初始“排队中”。
  修正了三点：Whisper-small 通过显式本地 snapshot 路径加载；
  WhiSQA 使用真实 `models/n019_official/mos/WhiSQA_single_head.pt`
  （364,031,990 bytes，SHA256
  `2da43d59294c358bdd3f450d0aef5ce57ad20bed3beb34657ef3a795a4766810`），
  不再使用 vendor 下的 134-byte LFS pointer；`eval_mos.py` 将
  `WhisperWrapper_encoder(pretrained_model=<local path>)` 显式注入。
  CPU 单句 WhiSQA probe 已通过，score `2.1883495151996613`。
  该 Job 初始失败记录为 `2118523635443597313`，原因是远端脚本尚未
  同步，启动即报 `No such file or directory`，不重跑该失败任务。
- 2026-11-06 09:08：d7 已从固定 `hf-mirror` 下载
  `openai/whisper-small` revision
  `973afd24965f72e36ca33b3055d56a652f456b4d` 到
  `$HF_HOME/hub/models--openai--whisper-small`；16 个文件完成，
  日志 `audit/whisper_small_download_20261106.log`。新增
  `scripts/resume_du_pred_nt_paperfix_whisqa_ai.sh`，复用已有
  1,934 条 UTMOS 结果，只运行 WhiSQA，并先以
  `local_files_only=True` 检查 config/feature extractor/tokenizer；
  不重算 UTMOS/E-VPC/W-NT/WER。对应配置任务
  `d7-libri-test-du-pred-nt-paperfix-whisqa-resume` 已准备，
  `submit:false`，规格 1 DCU、15 CPU / 59 GB、1 h，
  预计 0.1、最坏 1.0 卡时；尚未提交。
- 2026-11-06 08:05：MOS-only Job `2118405442188128258` 已完成
  UTMOS，但在 WhiSQA 阶段失败。日志窗口约
  `02:11:54–02:17:37`，约 `0.10` 卡时（以平台账单为准）。
  UTMOS 完整 1,934 条：mean `1.2620579278580035`、
  stddev `0.048784797436545006`、min `1.2143617868423462`、
  max `1.9752699136734009`；论文 DU-pred-nt 为 `3.63`，
  绝对差约 `-2.3679421`。`UTMOS.json` SHA256
  `0aea532589b81e7e374ea82e4675cab62111102933586367fbd510f448047b4c`，
  `UTMOS.tsv` SHA256
  `cfad51be458bb2d8f35d4235d7f51d818ff19e26a7b7b5942fc99520091d98a2`。
  WhiSQA 失败原因是 Transformers 在
  `openai/whisper-small` 本地缓存中找不到 `config.json`，
  访问 `https://hf-mirror.com` 也失败；没有写出 `WhiSQA.json`。
  下一步只修复固定的 Whisper-small 本地缓存和 WhiSQA 续跑，
  不重算 UTMOS/E-VPC/W-NT/WER。
- 2026-11-06 08:05：UTMOS 与论文差距很大，先不把它归因于
  UTMOS 代码错误；固定 checkpoint、1,934 条完整计数和 SHA256
  已闭环。需要同时审计输入音频质量、NT paperfix vocoder 的
  `best.pt` 选模（旧记录显示 step 4k 早停）以及 MOS 模型协议，
  再决定是否重训/换选模。
- 2026-11-06 02:09：d7 资源恢复，MOS-only 续跑已提交，
  Job `2118405442188128258`，任务名
  `n019_libri_test_mos_20261106_020935`，初始“排队中”。
  规格为 1 DCU、15 CPU / 59 GB、1.5 h，预计 0.25、
  最坏 1.5 卡时。只运行 UTMOS/WhiSQA 和汇总对表；
  不重算 E-VPC/W-NT/WER，不替换已锁定 vocoder。配置已改为
  `submit:false` 并记录 JobID，禁止重复提交。
- 2026-11-06 00:06：MOS-only 续跑已具备全部前置条件，但 d7
  的“华中一区【A区】/异构加速卡BW/113 组”资源表连续两次显示
  `共 0 条`，未创建 Job，消耗 0 卡时。无头提交只做到资源门禁，
  没有点击最终“创建”。待资源出现后重试；运行期间每小时只查
  最新 MOS 日志和输出，不做其他任务。
- 2026-11-05 23:54：改为全程直连 SSH。`a094f4d7` 已用
  `zzeshell.scnet.cn:65032` 的 E-Shell key 实测登录成功；后续日志、
  文件、进程和产出检查不再启动浏览器或 Playwright 页面。E-Shell
  不接受非交互式远程命令（channel 打开后无 exec 返回），必须用
  SSH 会话或 WSL `ssh -tt` 后在同一 shell 内执行命令。
- UTMOS runtime bootstrap + 单句 probe Job
  `2118364969222721538` 已完成。`UTMOS_RUNTIME_READY` 报告
  fairseq `0.12.2`、hydra `1.0.7`、omegaconf `2.0.6`、
  pytorch-lightning `1.5.10`、torch `2.9.0`、numpy `1.26.4`；
  单句 UTMOS `count=1`、`mean=1.2382493019104004`，门禁
  `UTMOS_PROBE_OK` 通过并写出 `UTMOS_RUNTIME_BOOTSTRAP_COMPLETE`。
  `UTMOS.json` SHA256
  `c9758342eb68043f919939449b41be3bcfc0ed9d7b9d2e7f0a39bd061b47744e`，
  `UTMOS.tsv` SHA256
  `834f116030de28dfdd7456e99501699b777954fb80e1c4074b121a7a525d6f74`，
  overlay 总表 SHA256
  `bde5cfe5fc569329a773c52271f219ebcbacbaacd53a8bf91348bd97fc4ada0f`。
- 2026-11-05 22:52：retry2 Job `2118351412085760002` 于
  `22:38:46` 失败。fairseq wheel 已成功构建、安装及 py311 dataclass
  补丁；随后导入时 OmegaConf 2.0.6 不接受
  `FairseqConfig` 中 `default_factory` 字段暴露的
  `dataclasses.MISSING`。已扩展 `patch_fairseq_py311.py`，让
  `hydra_init` 优先调用 `default_factory()`，定向测试 6 项通过。
  已重提 d7 Job `2118355893485817858`，仍为 1 DCU、15 CPU /
  59 GB、1 h、预计 0.25、最坏 1.0 卡时；提交前余额
  `42.1758333332`。启动命令内嵌两个已测试补丁后再运行 bootstrap。
- 2026-11-05 22:35：第二次 bootstrap retry 已提交，d7 Job
  `2118351412085760002`，初始“排队中”。规格仍为 1 DCU、
  15 CPU / 59 GB、1 h、预计 0.25、最坏 1.0 卡时。启动命令
  先以固定 base64 覆盖修正后的 `patch_fairseq_sdist.py`，再执行
  bootstrap，避免继续等待受限的 SSH 新连接。不要重复提交。
- 2026-11-05 22:20：retry Job `2118344298533593089` 于
  `22:08:08` 失败，实例 1 分 07 秒。固定 fairseq sdist 下载与
  SHA256 校验已通过，失败原因是补丁脚本预期 2 个
  `extensions.extend`，实际 setup.py 有 3 个（额外为 CUDA 块）。
  已修正为删除前两个缺失源码的 CPU 块、保留 CUDA 块；定向测试
  5 项及全量 `110 passed, 3 skipped` 通过，补丁脚本新 SHA256
  `7f2459844e403d4715413d7f94c84ffe74e988baf8fbd06e930568b1b52e8226`。
- 2026-11-05 22:07：fairseq sdist 补丁版 bootstrap 已重提，
  d7 Job `2118344298533593089`，初始状态“排队中”。
  仍是 1 DCU、15 CPU / 59 GB、1 h、预计 0.25、最坏 1.0 卡时；
  提交前余额 `42.2533333332`。不要重复提交。
- 2026-11-05 22:02：fairseq 失败已定位到 PyPI sdist 省略三个可选
  C++ 源文件（`libbase`、`libnat`、`alignment_train_cpu`）。
  已固定 fairseq sdist SHA256
  `34f1b18426bf3844714534162f065ab733e049597476daa35fffb4d06a92b524`，
  并新增只删除这三个可选扩展的构建补丁
  `scripts/patch_fairseq_sdist.py`（SHA256
  `a2f5949f144889e7f5e39a5c78b4f61d89888da83fe41693d02cf4f6ca0ec1dd`）。
  更新后的 bootstrap 脚本 SHA256
  `45fc60788e6f6d1ba16c057f8b0ff8d889dfa1489caf13a907c69381f09ccb36`。
  两个文件已通过 SSH/SCP 上传 d7；需要等网关限流窗口后再核验远端
  SHA256 并重提 bootstrap + 单句 probe。
- 2026-11-05 21:31：隔离 UTMOS bootstrap Job
  `2118333381196488706` 于 `21:25:37` 失败，实例约 2 分 02 秒、
  约 `0.034` 卡时。Hydra/OmegaConf/PyTorch-Lightning 安装阶段通过，
  但 PyPI 的 `fairseq==0.12.2` sdist 缺少
  `fairseq/clib/libbase/balanced_assignment.cpp`，wheel 构建停止。
  正式 torch/numpy 未被改动。下一步改用已成功安装并打补丁的
  py311 fairseq 包做隔离迁移，不再重复从 PyPI 构建；完整 MOS 仍未启动。
- 2026-11-05 21:24：已提交隔离 UTMOS runtime bootstrap + 单句 probe，
  d7 Job `2118333381196488706`，1 DCU、15 CPU / 59 GB、1 h、
  预计 0.25、最坏 1.0 卡时。输入固定 UTMOS demo/checkpoint 与
  1,934 行 paperfix `wav.scp`；输出
  `envs/n019_utmos_overlay` 和 `runs/n019_official/eval/utmos_runtime_probe`。
  已上传脚本至 d7，远端 SHA256 与本地一致：
  bootstrap `2b70631f...58d7`、resume
  `22923097...1387`。提交前 d7 余额 `42.2872222221` 卡时。
  任务运行中，单句 UTMOS 有限且 0–5 后才允许完整 1,934 句 MOS 续跑。
- 2026-11-05 19:50：MOS-only 续跑 Job
  `2118298417542995969` 已失败，实例实际运行
  `19:04:39–19:09:05`。启动门禁、1,934 行检查和 E-VPC/W-NT
  输入检查均通过，但 UTMOS 在加载作者 `score.py` 时因 d7 环境缺
  `hydra` 退出；E-VPC I/L/WER 与 W-NT I/L 未改，不得重算。
  该任务最坏 1.5 卡时，实际约 0.074 卡时。d7 最新余额
  `42.2872222221` 卡时。下一步必须从已有可工作的账号环境迁入
  与作者 requirements 对应的隔离 UTMOS 依赖，先做单句 probe，
  再只续跑 MOS + 汇总/对表。
- 2026-11-05 19:04：原评测 Job `2118255578293129217` 于 18:39:42
  结束，控制台“失败”。失败发生在 E-VPC 与 W-NT 都完成之后：
  d7 缺少 `vendor/UTMOS22-demo/score.py`，不是模型或指标失败。
  W-NT L 已完成：female `42.1511322260%`、male `43.5985133052%`、
  mean `42.8748227656%`（论文 `42.3%`，绝对差 `+0.5748%`）；
  W-NT I/L 和 E-VPC I/L/WER 均保留，不得重跑。
  W-NT L 两个 JSON 的 SHA256 为
  `49d24d47299e311356516a2d9a7802a0c08c537eff8fed48029abb91eb0245e8`
  与 `c6f3102dd02fe7334e4a8240a80ca854d672cd0d9dca4f474493cc061e15e25e`；
  W-NT `summary.json` SHA256
  `60018ad55973d45cb663428642165068846a90115788553bb47c6b8268b9fb51`，
  paperfix `evpc_metrics.json` SHA256
  `40e6d671b7a37a6b72247ed3588a7197f75eb16747ef2c620ed42d919722d767`。
  已将本地固定 UTMOS22 demo 源码打包（tar SHA256
  `bd51d01899f8b1917e5ccdde87cd4bbd60f87fd374efd10907567a1afba742fc`）
  同步到 d7；`score.py`/`model.py`/`lightning_module.py` SHA256
  分别为 `95b0ef25...375d0`、`79ca330b...36d4`、`def23a75...13f`。
  新增只跑 MOS、汇总和对表的续跑任务
  `d7-libri-test-du-pred-nt-paperfix-mos-resume`，启动脚本 SHA256
  `dad27507a10600fc49e01f725358de5f4d30346037db884c664328d930a5fb96`。
  计划 d7、1 DCU、15 CPU / 59 GB、1.5 h、预计 0.25、最坏 1.5
  卡时；提交时余额 `43.0227777777`，可覆盖。Job
  `2118298417542995969` 已于 19:04:39 启动，当前“运行中”，已通过
  E-VPC/W-NT/MOS 输入门禁并开始 UTMOS；不得重跑 E-VPC/W-NT。
- 2026-11-05 17:37：W-NT I 已完成：female `39.9397730827%`、
  male `42.3170581460%`、mean `41.1284156144%`；论文 `39.9%`，
  绝对差 `+1.2284%`。female/male JSON SHA256 分别为
  `a2792c584c4490c02327133ed21ba369549ccf75716b3a6492c40c323021c2bd`
  和 `5fe47ebd58501d072f6cb71451e7495ab3853d8504a6fb732a58c86764a9d3f0`。
  该值高于论文，说明身份隐私没有变差，不能据此解释 WER 偏高。
  Job `2118255578293129217` 仍在运行，已开始 W-NT L；UTMOS/WhiSQA
  尚未产出。d7 余额 `44.0227777777` 卡时，正常。
- 2026-11-05 16:33：主评测 Job `2118255578293129217` 仍在运行。
  E-VPC pre 已完成：I `47.473%`（female `46.349%` / male
  `48.597%`，论文 `47.2%`，绝对差 `+0.273`，在 0.5 容差内）；
  L `45.8775%`（female `46.552%` / male `45.203%`，论文
  `47.9%`，绝对差 `-2.0225`）；匿名 WER `10.333%`（论文
  `7.41%`，绝对差 `+2.923`）。原始基线仍为 `1.8435%`。
  因此当前 paperfix vocoder 不能判定为论文复现通过。训练日志显示
  `vocoder_nt_paperfix/best.pt` 是 step `4,000`，虽然训练到
  step `34,000`，但正式 checkpoint 只保留了 step 4k；旧主 vocoder
  的最佳点则在 step 76k。初步证据指向 NT vocoder 训练不足/选模过早，
  但在 W-NT 与 UTMOS/WhiSQA 完成前不把根因写成结论。
- 2026-11-05 16:33 零卡时审计：本地 `111` 项测试通过、`3` 项因
  本机缺 librosa 跳过；d7 激活官方环境后 `107` 项测试全部通过、
  `compileall` 通过。本地与 d7 的源码仅 `src/n019/duration.py`
  SHA256 不同：本地已有允许启动器 `launch.txt` 的修复，d7 仍是旧的
  “任何非空目录均拒绝”。该差异不影响当前 eval（不调用 duration.py），
  但评测结束后必须同步；另有 3 个本地专用单元测试文件和 1 个
  duration 回归测试尚未同步，不能把 r37 当作最终审计包。
- 2026-11-05 16:14：d7 实时余额 `44.8574999999` 卡时。原始语音
  基线 Job `2118253551901843458` 已于 16:10:53 完成并通过指标门禁：
  female/male EER `8.761%/0.418%`、mean `4.5895%`（论文 `4.6%`），
  WER `1.8435020832144284%`（论文 `1.8%`）；
  `evpc_metrics.json` SHA256
  `0ebc90dc9ee46157140a710786d8213fc836f6fdf28baf7320b1f81135ba3680`。
  正式 `DU-pred-nt-paperfix` I/L/WER/UTMOS/WhiSQA 评测已提交：
  d7 Job `2118255578293129217`，1 DCU、15 CPU / 59 GB、4 h、
  预计 2.0、最坏 4.0 卡时；启动脚本 SHA256
  `87d908ac630e6da1736a4309be47c0fb9989322723670325feb4039638a6660a`。
  已于 16:14:25 启动，当前“运行中”；输出
  `runs/n019_official/eval/du_pred_nt_paperfix`，日志
  `audit/libri_test_du_pred_nt_paperfix_eval_20261105_161403.log`。
  不得重复提交；完成后只缺 E-VPC S 与 W-NT S，二者需完整匿名 LS360
  重训，另做资源计划。
- 2026-11-05 15:20：d4 target map/manifest/NPZ/metadata 已通过本机
  中转至 d7，四个 SHA256 与源一致；d7 现有 1,934 units、
  1,934 target map、1,924 target embeddings，balance
  `45.3341666667`。准备提交 1 DCU、15 CPU / 59 GB、1 h、
  预计 0.25、最坏 1.0 卡时的 libri_test `DU-pred-nt-paperfix`
  匿名化；输出固定为四个 `_n019_paperfix` VPC split，不得改 suffix。
  Job `2118242604438040578` 已提交，初始“部署中”。
- 该匿名化 Job 已于 15:29:12 完成，1,934 WAV/anon/VPC、
  0 negative duration、抽样 16 kHz mono PCM16、owner 正确。
  `anon.jsonl` SHA256
  `3f9ef37ed014a5debd8372227f042892ea49754a9d80d0e13691a5b38df4f6df`。

- 2026-11-05 14:33：d4 target embedding 到 900/1,924，d7 units
  到 304/1,934。已新增 d7 原始语音基线脚本，SHA256
  `3d091c3002d6f2b613fc231e31eef074e3c49e7a2f33ac382372278060e43064`；
  计划 1 DCU、15 CPU / 59 GB、2 h、预计 0.25、最坏 2.0 卡时；
  Job `2118230351709052930` 已提交并排队。
  基线使用独立 `_n019_orig` symlink，不能占用匿名化
  `_n019_paperfix` 后缀。
  首个基线 Job 在模型加载前缺 `pandas`；已零卡时安装
  `pandas==2.2.3`、`pytz`、`pyloudnorm`，numpy 保持 `1.26.4`，
  `run_evaluation.py` import 已通过；重试 Job
  `2118234972682821633` 已提交并排队，但 d7 的 vendor 文件为旧版，
  未识别 skip 环境变量；已同步本地 `run_evaluation.py`，远端核验
  第 94 行存在 `N019_SKIP_DEPENDENCY_CHECK` 分支；第二次重试 Job
  `2118235252464013314` 已提交并排队。
  该 Job 因 VPC split 使用相对路径
  `data/libri_test/wav/...` 而停止；已建立
  `vendor/Voice-Privacy-Challenge-2024/data -> vpc/`，并确认相对
  WAV 路径存在。不得把 split `wav.scp` 改写为猜测路径。第三次重试
  Job `2118241331310600193` 已提交并排队；该 Job 仍失败，因为
  symlink 目标多了一层 `vpc/`。现已指向 `vpc/data/`，并确认
  `data/libri_test/wav/1089-134691-0001.wav` 可解析；第四次重试 Job
  `2118242914452033537` 已提交并排队。
  第四次已通过 format gate，但 ASV 因 d7 的 compat 包缺
  `__init__.py`/`transforms.py` 而报 `torchaudio.load` 不存在；已从
  固定 `torchaudio_scnet_compat.tar.gz` 补齐，保留现有扩展版
  `functional.py`，并确认 `torchaudio 2.9.0+scnet-compat`。第五次
  重试 Job `2118245146424352769` 已提交并排队。
  第五次 ASV 已通过：female `8.761%`、male `0.418%`，mean
  `4.5895%`。ASR 缺 HF metadata；已按 revision
  `54074b1c16f4de6a5ad59affb4caa8f2ea03a119` 下载并中转
  `config.json`/`preprocessor_config.json`，offline probe 返回
  `feature_extractor_ok 16000`。
  第六次重试 Job `2118249890493542402` 已提交并排队。
  第六次仍失败，因为 SpeechBrain 使用显式相对
  `cache_dir=exp/asr/wav2vec2_model_checkpoints`；已把固定 snapshot
  复制到该 cache，并以相同 cwd/cache_dir 做 offline probe，通过。
  第七次重试 Job `2118251610465116162` 已提交并排队。
  第七次仍在 ASR 模型源检查时访问 Hub。已建立
  `vpc/exp/asr_n019_local`，三个 ckpt 用硬链接保持 SHA256 不变，
  仅将 `wav2vec2_hub` 指向本地目录并附固定 metadata；本地
  feature extractor/config probe 通过，原 `exp/asr` 未修改。
  第八次重试 Job `2118253551901843458` 已提交并排队。
- d7 libri_test paperfix units Job `2118228637901398018` 已于
  14:46:40 完成：1,934 records、40 speakers、0 missing code、
  0 shape/value mismatch。`unit_records.jsonl` SHA256
  `407fb8b5bbc7b689702df69419b087058cd142ece5d84eb9a8cc69e1eb369b3f`。
- d4 libri_test target embedding Job `2118223421122203650` 已于
  14:58:36 完成：1,924 条、250-D、finite、L2 norm 正常；NPZ SHA256
  `0c2a747220bac2a231cbde981a9d5dfca621750348f87f7ce18fab84994a58b7`。

- 2026-11-05 14:27：d4 paperfix target embedding 仍在运行，日志
  已到 600/1,924，输出有限；d7 paperfix units 脚本已部署，SHA256
  `d7c162b6a49688515de18babf0e7c83219963fce1370d7958b2aefde4c42fa78`，
  d7 余额 `45.7341666667` 卡时，计划 1 DCU、15 CPU / 59 GB、1 h、
  预计 0.5、最坏 1.0 卡时；Job `2118228637901398018` 已提交并排队。
  不要重跑 d4 embedding 或使用旧 unit 目录。

- 2026-11-05 10:13：首次 paperfix LS360 Job
  `2118069808953692162` 在 6 h 外层墙钟停止，日志最后为
  `93391/104014`，没有 `anon.jsonl`，`anon.partial.jsonl` 最后写入
  09:56:14。已确认没有残留匿名化 writer。续跑 Job
  `2118164816636981249` 已提交到完全相同的输出目录：d6、1 DCU、
  15 CPU / 59 GB、外层 2 h（其中合成 `timeout 5400s`）、预计
  0.75、最坏 2.0 卡时。启动前强制核验 partial 至少 93,390 行且末行
  JSON 完整；结束后在同一任务内纯 `chown` 到 `a094f4d6`。第一次
  续跑 Job `2118164816636981249` 因启动脚本漏传 `N019_ANON_OUT`，
  在模型加载前立即失败；第二次 `2118165264547106817` 因日志计数
  93,391 与真实落盘 93,375 相差一个 `flush_every=25` 缓冲而在模型
  加载前退出，partial 两次均未改。门禁已按真实行数改为至少 93,350，
  第三次 Job `2118165677283745794` 已于 10:17:10 启动，partial
  `93,375` 行、末行 `8119-115686-0028` 可解析，内层日志确认
  `resume=1`。该 Job 已完成剩余 10,639 句：`104014/104014`，
  `anon.jsonl`、`run_meta.json` 已写出，VPC `wav.scp=104014`。
  收尾 `chown` 因组名 `a094f4d6` 在容器内不可解析而失败，数据内容
 未受影响；已提交纯所有权修复 Job `2118180309146669057`，使用固定
  数值 UID/GID，1 DCU、15 CPU / 59 GB、2 h、最坏 2.0 卡时。提交时
  d6 余额 `39.1208333332` 卡时。该 Job 于 11:53:35 完成，日志为
  `OWNERSHIP_FIX_COMPLETE`；`anon.jsonl`、`run_meta.json`、
  `wav.scp` 已归 `a094f4d6:a094f4d6`。全量
  `verify_anonymized_outputs.py` 已通过：`passed=true`，104,014 WAV
  / 104,014 `anon.jsonl` / 104,014 VPC 行，ID 与路径集合一致，
  0 negative duration，抽样 16 kHz mono PCM16，owner 正确。
  `anon.jsonl` SHA256
  `68e450ce18425905a5a5dd3571bc3d9f6cbc161e7e0f3bf249984e01dc1e1941`；
  `run_meta` SHA256
  `0608dad89aaffb1f1288c7cd3a606769914596820d9a6aa7f3d442767a8d97be`；
  `wav.scp` SHA256
  `69d1c08a5b8e4656748213a22d62a42ae8673a2a0a5f6e79ecf95eb906635cbd`；
  WAV 总字节 `41,940,252,136`。验收记录见
  `audit/verify_ls360_du_pred_nt_paperfix.json`。
- 当前代码包已包含 duration 归一化修复、feature-matching 权重修复、
  launcher 输出目录修复和训练输入路径门禁；最终审计包的名称、大小和
  SHA256 以 `artifacts/SHA256SUMS.txt` 为准。
- d6/d7 的公开评测资产均已完成：VPC repo/data/data_test_tools、
  asv_orig、asr、HuBERT、W-PRO、UTMOS22、WhiSQA 及
  `WhiSQA_single_head.pt`。d6 首次在 WhiSQA checkpoint 71% 处
  遇到 HTTP/2 中断，已从 `.part` 断点续传成功；不得重新下载已校验
  资产。
- d7 已解包官方 `data.zip`、`data_test_tools.zip`、`asv_orig.zip` 和
  `asr.zip`；VPC libri_test 元数据门禁通过：enrolls `438`，female
  `734` wav / `11744` trials，male `762` wav / `9906` trials，
  train-clean-360 `104014` / `921` speakers。d6/d7 的公开
  `test-clean.tar.gz` 已各自启动下载，目标 MD5
  `32fa31d27d2e1cad72775fee3f4849a9`。
- d6/d7 的 `test-clean.tar.gz` 均已完成并由 MD5 固定为
  `32fa31d27d2e1cad72775fee3f4849a9`；各 2,620 个 FLAC。d7 按官方
  `wav.scp` 精确重建 libri_test：1,934 个唯一 WAV、全部
  16 kHz mono PCM16、0 failure；VPC 元数据仍为 enrolls 438、female
  734/11744、male 762/9906。重建审计见
  `audit/vpc_libri_test_rebuild_20261105/`，验收 `ok=true`：
  `audit/vpc_libri_test_verify_20261105.json`。
- d4 已启动论文版 libri_test target embedding Job
  `2118223421122203650`：1 DCU、15 CPU / 59 GB、3 h 上限、预计 1.5、
  最坏 3.0 卡时；输入 d7 重建并由本机 SHA256 中转的 1,934 条
  manifest、完整 205,044 条 train-other-500 manifest、本地音频和
  W-PRO；输出带 `_paperfix` 的新 target map/manifest/embedding。
  提交时 d4 余额 `9.1908333332` 卡时。
- 22:55 执行状态：d3 duration-pred 第二次提交
  `2117992970106335234` 已进入运行中；第一次提交
  `2117990487663157250` 不是训练失败，而是 launcher 先写
  `launch.txt` 后被输出目录门禁拒绝，已修正为允许该启动元数据。
  d6 NT vocoder 新任务 `2117993296451735554` 已提交，2 DCU、
  8.25 h 外层墙钟、最坏 16.5 卡时，输出
  `runs/n019_official/vocoder_nt_paperfix`。d6 的 LibriSpeech
  clean-100 unit 解包仍未完成，但本任务使用已存在的
  `libritts_train_clean_100` 记录和 NT speaker embedding。
- 23:04 d3 duration-pred retry `2117992970106335234` 已完成 30 epochs；
  `best.pt` SHA256 `8d5153c920058204fe13ebb75b0744703bc0523e70f3a83fbd8b194245a3ba1c`，
  `last.pt` `466c5a9f5bf05eea181f0a16fc842ae126845dbf50e463c98b2433ce4d6661af`，
  输出已由 Job `2117996828583972865` 纯 chown。训练最后 loss
  `1.3018964665651633`、point MSE `0.8687219544126944`。
- d6 第一次 vocoder Job `2117993296451735554` 因
  `libritts_train_clean_100/unit_records.jsonl` 中旧 d4 `codes_path`
  失败；已将仅训练所需的 `codes_path`/`kmeans_codebook` 改写到 d6，
  全量校验为 33,236 records、247 speakers、0 missing、0 shape/value
  mismatch，并保留备份。第二次 Job `2118000486608805889` 已提交，
  输出仍为 `vocoder_nt_paperfix`。
- d6 第二次 vocoder 仍无法训练：LibriTTS clean-100 的 `audio`
  路径同样来自 d4，而 d6 没有该语料；这是输入资产缺失，不是算法失败。
  d3 已有完整 8.8 GB LibriTTS clean-100 音频、33,236 codes 和 247
  speaker 的 NT embedding，因此改在 d3 训练：Job
  `2118002044909432834`，2 DCU、8.25 h 墙钟、最坏 16.5 卡时，
  输出 `runs/n019_official/vocoder_nt_paperfix`，已开始 step 训练。
- 已新增 `scripts/verify_local_unit_records.py`，并在
  `run_vocoder_ddp.sh` 训练前强制检查 `audio`、`codes_path`、
  `kmeans_codebook` 是否都属于本账号且存在。定向测试 `16 passed`，
  全量 `107 passed, 3 skipped`，`compileall` 通过；门禁不改变训练数值。
- d3 修正版 NT vocoder 已在 2026-11-05 02:55 完成：step `34,000`，
  `validations_without_improvement=15`，`best.pt` 为 step `4,000`，
  validation mel L1 `0.7951396703720093`；`best.pt` 已实际加载并在
  CPU 上完成有限波形检查。`best.pt` SHA256
  `f1735e757ecfc4bfb6a230ae26219058e6aed8bef18656bb2b694cc89ed070d9`，
  `last.pt` SHA256
  `c40b745ade7caaf29c2abc7a8ea6ad271f2c8a11ae904cd9dc8a9c370276de5c`。
- d3 的两个 paperfix checkpoint 已按文件经本地中转 d6，六个文件
  SHA256 与源一致；d6 模型加载和有限合成检查通过。d6 已提交
  `DU-pred-nt-paperfix` LS360 任务 Job `2118069808953692162`：
  1 DCU、15 CPU / 59 GB、6 h 墙钟、最坏 6 卡时；输出
  `anonymised/ls360/DU-pred-nt-paperfix` 和
  `vpc/data/train-clean-360_n019_paperfix`。必须验收 104,014 WAV、
  104,014 条 `wav.scp`、0 negative duration、16k mono PCM16、owner。
- SCNet 表单自动化增加了强制 radio fallback，并把非关键截图失败降级为
  警告；本次提交失败的原因是 headless 表单 radio/截图，不是模型或作业失败。
- 代码审查发现两项会改变正式数值的 P1 偏差，已在本地修正：
  duration loss 改为“point/window 都求和，再统一除以有效 unit 数”；
  Unit HiFi-GAN 的 MPD/MSD feature-matching 权重从 2.0 改为 1.0。
- 同时修正 `run_duration_ai.sh` 的 `pred -> none` 参数映射、ECAPA
  duration 默认语料路径，并新增 LibriSpeech clean-100 ECAPA 提取入口。
  修正前训练的 duration 和 vocoder checkpoint 不能被新代码重新贴标签。
- 修正前结果冻结为工程结果 v1，不覆盖：
  `vocoder_nt_main/`、`duration_pred_main/`、d6/d7 的现有 LS360 输出。
- 短期只闭环 **`DU-pred-nt`**。新目录固定为：
  `runs/n019_official/duration_pred_paperfix/`、
  `runs/n019_official/vocoder_nt_paperfix/`，并在验证通过后生成独立的
  `anonymised/ls360/DU-pred-nt-paperfix/` 与
  `vpc/data/train-clean-360_n019_paperfix/`。
- 第一项重训为 duration-pred：1 DCU、15 CPU / 59 GB、墙钟 0.25 h、
  最坏 0.25 卡时；训练 30 epochs，输入仍是 LibriSpeech train-clean-100。
- 第二项重训为 NT Unit HiFi-GAN：2 DCU、每卡 15 CPU / 59 GB、
  训练上限 8 h、外层 8.25 h、最坏 16.5 卡时；从 step 0 重新训练，
  不续接旧 checkpoint。停机条件保持现有 early-stop：
  每 2,000 步验证，至少 20,000 步，连续 15 次无至少 0.001 改善。
- 只有在 `DU-pred-nt` 的模型、LS360 和 libri_test 评测都通过后，才允许
  规划其他 DU 系统。ECAPA、其余 7 个系统和 S attack 暂不提交。
- 本地代码修正后测试为 `107 tests OK, skipped=3`；修正后的代码需要打包
  r32 并同步目标账号，禁止覆盖仍运行的 live code。
- 修正版代码包已生成；最终包名、大小和 SHA256 以
  `artifacts/SHA256SUMS.txt` 为准。

## 0.0 当前执行状态（2026-11-04 21:05）

- 主 vocoder 已闭环，不再训练：d3 Job
  `2117804993484845057` 于 13:09:40 正常收敛，最后 step
  `106,000`；正式推理 checkpoint 固定为 `best.pt`，step
  `76,000`，validation mel L1 `0.7805652022361755`，SHA256
  `32f8cbf064b48e1cedb2541c72b34916570e8d3a1da66c39de0ca04a2cfc1477`。
- d5 的 1,024 句 DU-pred-nt pilot 已完成：`1,024/1,024` WAV，
  纯合成约 `5.61` 句/s，外推 104,014 句约 `5.16 h`、PCM16
  输出约 `41.9 GB`；未发现 negative duration。
- d6/d7 已完成真实绝对路径迁移和输入门禁。两账号的
  `unit_records.jsonl` 均由 d5 绝对路径原子改写到本账号，备份保留；
  `verify_unit_dataset.py` 对两账号全量验证为 `104,014` records、
  `921` speakers、0 missing code、0 shape/value mismatch。
- 两账号的 source/unit/target-map/VPC 的 104,014 个 ID 完全一致；
  target NPZ 均为 81,605 条、250-D、全部 finite，L2 norm
  `0.9999998808–1.0000001192`，NPZ SHA256
  `274dd8012a59ff02a7bcc11921b1be2b731b2c4fcba50603428c7d5c2a047f1a`，
  target map SHA256
  `c9a182adfc4076087dc5144a85694b5900270a4fefee6b38459d720da228ee75`。
- 正式匿名化已完成：
  - d6 `DU-orig-nt`，Job `2117871537248841729`；
  - d7 `DU-pred-nt`，Job `2117871585265983490`。
  d6 在 18:51:57、d7 在 18:54:04 正常停止，控制台均为“已完成”；
  两边日志均为 `104,014 / 104,014`，VPC `wav.scp` 均为 104,014 行。
  输出因 AI 容器 root 写入暂为 `root:root`，已提交纯 `chown`：
  - d6 Job `2117936167295954945`；
  - d7 Job `2117936206308601857`。
  每个 chown 任务 1 DCU、15 CPU / 59 GB、2 h 上限、最坏 2 卡时；
  d6/d7 chown 分别于 19:16:45、19:15:49 完成。全量
  `verify_anonymized_outputs.py` 均通过：
  - d6：104,014 WAV，41,849,921,896 bytes；`anon.jsonl` SHA256
    `72898a50c94e73cac3c27471c11d8096269a638c5acbb99bfeb76aa9c5668c07`，
    `run_meta` SHA256
    `c8706f8f538a3030a5039eb7fc85cf2e6f54d2331abc16413e9b0fa9e57210bd`；
  - d7：104,014 WAV，42,281,386,856 bytes；`anon.jsonl` SHA256
    `3a22f4874dd2056417f7ff3de84aa6fce6f54b08b798de099b19b5a14b5d625f`，
    `run_meta` SHA256
    `22a21b8e2f1e9b667b1a95307336dd63308b656cfbfadc58147f4d1663a3f73d`。
  双方 source/anon/VPC ID 集合一致、路径集合一致、0 negative
  duration，抽样 WAV 均为 16 kHz mono PCM16，owner 正确。
- r29 的 `src/n019/anonymize.py` 已同步 d6/d7，SHA256
  `b3baab561a17930499eac653fcbc243dbab051554caea9508a44768706330c45`；
  d6/d7 的 r29 anonymise 定向 7 项测试均通过。
- 本地已生成审计包 r30：
  `artifacts/n019_code_20261104_r30.tar.gz`，`272,966` bytes，SHA256
  `59ca7ef776accf2071e7902ba3251aeb9c9c1b6063d3bf1b0614a3dbd1bb5662`；
  它新增输入门禁/路径迁移脚本并记录本次正式 Job。为不打断仍在运行的
  LibriSpeech 下载脚本，d6/d7 没有整包原地覆盖；正式匿名化所需的
  r29 `anonymize.py` 已单独同步并验证。
- 本地最新审计包已更新为 r31：
  `artifacts/n019_code_20261104_r31.tar.gz`，`276,605` bytes，SHA256
  `c89713ca0557003d020d8279932a11e55b0d559b2d3fdb951de1c40ad9e3d4b7`；
  包含 `verify_anonymized_outputs.py`、输出验收结果和当前台账。
- d6/d7 仍在各自服务器下载 LibriSpeech train-clean-360 原始包；
  19:04 约为 `52.03%` / `60.76%`，下载进程正常，不占 DCU。
  真实 tar 固定期望 MD5 `c0e676e450a7ff2f54aeade5171606fa`。
- 下一阶段：核对 d6/d7 上的官方 VPC2024、asv_orig/asr、W-PRO、
  UTMOS/WhiSQA 资产，缺项按规则补齐后启动 E-VPC I/L、W-NT I/L、
  WER 和 MOS；S attack 需完整匿名 LS360 训练，单独做资源计划。
- 20:18 已在 d6/d7 各自服务器启动零卡时公开评测资产下载：
  `scripts/multi_account/download_public_assets_remote.sh`，日志为
  `logs/n019_official/public_assets_eval_20261104.log`。目标包括
  pinned VPC2024 v2、data/data_test_tools、asv_orig/asr、
  HuBERT、W-PRO、UTMOS22 和 WhiSQA。下载不占 DCU。
- 首轮下载因 GitHub 网络中断提前退出：d6 停在 asv_orig 约 4 MB，
  d7 停在 asr 约 91%。VPC repo、data.zip、data_test_tools 已完成；
  d7 asv_orig.zip 已完成。d6 改用
  `download_vpc_release_parallel_remote.sh`，经公开 GitHub 代理做
  16 连接分块和 SHA256 门禁，日志
  `logs/n019_official/vpc_release_parallel_20261104.log`。d7 从现有
  asr `.part` 断点续传。不要删除已有 `.part` 或重复从头下载。
- 资产准备完成后，分别下载公开 `test-clean`，按官方 `data.zip`
  清单重建 libri_test，并准备 1,934 条 unit/target 输入；随后用
  d6/d7 各自最终的 DU checkpoint 匿名化 libri_test，再运行
  E-VPC I/L、W-NT I/L、WER 和 MOS。

## 0.0 当前执行状态（2026-11-04 13:39）

- d3 vocoder NT main continuation Job `2117804993484845057` 已正常
  `converged` 并在 13:09:40 停止；控制台状态“已完成”，最后训练
  step `106,000`，106k 验证 mel L1 `0.7946256995201111`，
  `validations_without_improvement=15`。正式推理 checkpoint 选
  `best.pt`，仍为 step 76k、mel L1 `0.7805652022361755`。
- d3 `best.pt` 为 `56,851,575` bytes，SHA256
  `32f8cbf064b48e1cedb2541c72b34916570e8d3a1da66c39de0ca04a2cfc1477`，
  与 d4 源文件一致。完整 `last.pt` 为 `1,019,516,431` bytes，
  SHA256 `21a7cf2ab6c301ea34cdc890fd5c751e888795eb6b4a247a020465f6c26dd0a3`。
  `last.pt` 和 `meta.json` 仍是 root-owned；已登记一个纯 chown
  收尾任务，资源为 d3、1 DCU、15 CPU / 59 GB、墙钟 `0.08 h`、
  最坏 `0.08` 卡时，当前余额 `24.5091666666` 充足。
- 13:39 实时余额：d3 `24.5091666666`、d4 `9.1908333332`、
  d5 `4.4113888888`、d6 `50`、d7 `50` 卡时。
- d6/d7 的 LibriTTS clean-100 training 与 LS360 units 均已解压到
  `104,014` code files；两台仍在各自下载 LibriSpeech LS360 原始包：
  13:39 约 `18.92%` 和 `22.33%`，下载完成后才做 MD5/FLAC/921
  speaker 验收。
- 下一步不再训练主 vocoder。先完成 d3 run ownership，随后把
  `best.pt` 与正式 run metadata 中转准备评测；正式 LS360
  anonymisation 优先使用 d6/d7，d5 只保留为已校验备份/小规模 pilot。
- 已登记但尚未提交 d5 `DU-pred-nt` 1,024 句吞吐 pilot：
  1 DCU、15 CPU / 59 GB、墙钟 0.5 h、最坏 0.5 卡时，输入只用
  正式 LS360 的确定性前缀，输出独立诊断目录，不进入论文指标。

- 上一快照余额：d3 `28.8313888888`、d4 `9.1908333332`、
  d5 `4.4113888888`、d6 `50`、d7 `50` 卡时。d4 当前无运行任务，
  d5 无运行任务，d3 有 2-DCU 主 vocoder 续训。
- d3 vocoder NT main 续训 Job `2117804993484845057` 状态“运行中”。
  11:50 日志已到 step `91,120`，吞吐约 `0.35 s/step`，loss 全部有限；
  90k 验证 mel L1 `0.7877435684204102`，best 仍为 step 76k 的
  `0.7805652022361755`，`validations_without_improvement=7`。
  当前窗口从 10:23 开始，约 18:24 到 8 小时训练上限；未收敛前不得
  切到 d6/d7。
- d5 LS360 units 所有权修复 Job `2117799927749849089` 已于 11:07:15
  完成，控制台状态“已完成”，日志 `OWNERSHIP_FIX_COMPLETE`。实际运行
  约 1.056 卡时，明显超过原 0.08 h 计划，原因是 NFS 上 104,014 个
  `codes/` 小文件元数据操作较慢。最终抽样 105 个文件全部为
  `a094f4d5:a094f4d5 644`；`codes=104014`、`records=104014`，
  `verification.json` 为 921 speakers、0 missing、0 mismatch。
- d4 → 本机 → d5 的评测资产中转已完成并通过逐文件 SHA256：
  canonical NT target NPZ
  `274dd8012a59ff02a7bcc11921b1be2b731b2c4fcba50603428c7d5c2a047f1a`，
  target manifest
  `f6986086fbf79e0555629ad31fe7acb5893b90db03cef44f60b27fa9e5cea76b`，
  duration NT best
  `5fb1383660f738051f77b5dd6b4dd2fd52444be96803912d25ec8f5247c53be7`，
  duration pred best
  `903f75ad44f2b48ac9f181d63b057e19c049efa1d6b94dfeee29c4c6768d42be`。
  文件、metadata 和 transfer manifest 暂存在
  `tmp/n019_d5_eval_assets_20261104_1055/`。
- d5 的 canonical target NPZ 已重新做内容门禁：`81,605` 行、
  250-D、全部 finite、L2 norm `0.9999999208–1.0000001083`；
  manifest 与 NPZ key 数量/集合/顺序均为 `81,605 / True / True`。
- d6/d7 已按各自公开下载规则启动 LibriSpeech train-clean-360
  23,049,477,885 bytes 的后台下载，期望 MD5
  `c0e676e450a7ff2f54aeade5171606fa`。两个登录节点都不占 DCU；
  11:50 分别完成约 `7.67%` 和 `9.60%`。d6/d7 的下载脚本已补上
  `SSL_CERT_FILE=/etc/pki/tls/certs/ca-bundle.crt` 默认修复。
- d6/d7 的训练与匿名化静态输入已开始准备：
  LibriTTS clean-100 训练包 `12,908,375` bytes、SHA256
  `059cca69fc5fc78c530b4dbd01d8f0ff04023d1f42c201d587d0932ecc214034`，
  解压后每账号 33,236 records / 33,236 code files；
  LS360 units 包 `64,170,474` bytes、SHA256
  `c7a31759e195a16ad09ecf35a1228b0fbbd1c61f5bb18e28eda89354c299ccf0`；
  LS360 anon 静态输入包 `105,754,520` bytes、SHA256
  `e5610ec554978e0ae97168f20a2bbe5f6c0ab3b868540fd6be6298b1197b6ea0`，
  已在 d6/d7 解压并核验 target NPZ、target map、两个 duration
  checkpoint 和 104,014 行 VPC `wav.scp`。LS360 units 的
  104,014 文件解压/计数仍在进行。
- 新增可复用的 Paramiko 本地中转入口
  `scripts/transfer_files_via_local.py`；本次配置为
  `configs/transfer_d5_eval_assets_20261104.json`。该入口要求源文件和
  目标文件 SHA256 都与配置一致，目标已有不同内容时默认拒绝覆盖。
- 当前代码包为 `artifacts/n019_code_20261104_r27.tar.gz`，
  `264,355` bytes，SHA256
  `74a6ee2fc02b63db9a1b1783ced4076566a784f11b2305188d5aee2ef15dfee2`。
  本地和包内测试均为 `101 passed, 3 skipped`；d6/d7 解包后各自
  `104 tests OK`。只读包和包内容已同步 d4/d5/d6/d7 live code。
  d3 正在运行主训练，未覆盖其 live code。
- `configs/scnet_browser_tasks.json` 已把 d4 target shard 0/1、d5
  units 第一窗口和 d4 vocoder 第一窗口的过期 `running` 状态改为真实
  收尾状态；不要按旧状态重复提交。

## 0.0.1 上一执行状态（2026-11-04 10:18）

- d4 vocoder NT main 第一窗口已在 8 小时上限停止：
  `last.pt` step `78,896`、`stop_reason=max_hours`；最佳验证是
  step `76,000` 的 mel L1 `0.7805652022361755`，`best.pt` 对应该步。
  `last.pt` SHA256
  `310452a8aebf820f64fb4daea36a412f19142ee20f66219060919cb64ca62c4d`，
  `best.pt` SHA256
  `32f8cbf064b48e1cedb2541c72b34916570e8d3a1da66c39de0ca04a2cfc1477`。
- 完整 run 已通过本机分块中转 d3，源/目标 `last.pt`、`best.pt`、
  `meta.json`、`training_log.jsonl`、`launch.txt` 五项 SHA256
  全部一致；中转 archive SHA256
  `7194f254858441a175029b727042d533ed51c56b063dc9bb47e38f3bc7c295e1`。
- d3 第一次续训 Job `2117802840442572801` 在 DDP 初始化后、
  首个 generator 更新前失败：d3 live `spectral.py` 仍是旧的
  `torch.stft` 实现，报 `HIPFFT_PARSE_ERROR`。已将 r25 的显式
  DFT 实现同步到 d3（SHA256
  `6015a5029282f3c59a496a4400884b30ff87a42dfafd613cbbf89b6e36e3dacc`），
  定向 `test_spectral` 2 项通过。
- d3 重试 Job `2117804993484845057` 已提交，资源仍为 2 DCU、
  8 h 训练窗口、8.25 h 外层墙钟、最坏 16.5 卡时。必须确认新日志
  step 从 `78,896` 之后继续，不能从头训练。
- d3 重试已在 10:34 确认续训成功：日志第一段为
  step `79,480–80,000`，80k 验证 mel L1 `0.828044`；best 仍为
  d4 的 step 76k `0.780565`，`validations_without_improvement=2`。
  说明 checkpoint、optimizer、scheduler 和 step 恢复正确。
- d5 LS360 units 已完成：Job `2117781760282206209`，
  `104,014` records、`921` speakers、`104,014` unique IDs，
  0 missing manifest/code、0 shape/value mismatch。
  `unit_records.jsonl` SHA256
  `e55b76ac70540f4458c08d5c8f03c03c31edfa6880aa92335ad3903be25725be`。
  root 所有权修复 Job `2117799927749849089` 已提交；由于 `codes/`
  下有 104,014 个小文件，`chown -R` 在 NFS 上耗时较长，但仍运行。

- d5 第二 resume `2117685309698658306` 在 6 小时硬上限暂停于
  `99,600/104,014`。第三 resume Job `2117781760282206209` 已按同一
  输出目录提交，日志确认 `resume=1`；剩余约 4,414 句，预计不足一个
  完整窗口即可完成。
- d4 vocoder NT main 在 08:49 已到约 step 69,700、训练约
  `7.1 h`；58k 验证最佳 mel L1 为 `0.808085`，之后耐心重新累计。
  8 小时训练窗口约在 09:15 到达，届时必须等容器完全停止后检查
  `last.pt`/`best.pt` 与所有权。

- d5 上一窗口 `2117591722692628481` 在 6 小时硬上限结束，partial
  到达 `65,904/104,014`。已按同一输出目录和 `resume=1` 提交
  Job `2117685309698658306`；日志已确认
  `RESUME_FLAG=(--resume)`，不是重新从头生成。
- d4 vocoder NT main 在 02:32 已到约 step `12,000` 以上，继续稳定
  训练；尚未达到 20k 收敛判断门槛。
- 四片 NT target embedding 已在 d4 canonical 合并完成，81,605 行、
  250-D、finite，manifest SHA256
  `f6986086fbf79e0555629ad31fe7acb5893b90db03cef44f60b27fa9e5cea76b`，
  NPZ SHA256
  `274dd8012a59ff02a7bcc11921b1be2b731b2c4fcba50603428c7d5c2a047f1a`。

- d3 target embedding shard 2/3 均已写出并核验：各 `20,401` 条、
  250-D、finite、L2 norm `0.99999988–1.00000012`，NPZ key 与各自
  manifest 完全一致。root 所有权已由 Job
  `2117675967040299010` 纯 `chown` 修正；期间一次失败 Job
  `2117675611960512514` 的原因只是 d3 缺少维护脚本，脚本已按 SHA256
  `2dd020156dfdb0d163187db8ee765288057aa552533a2cc0e605e33bcad2098b`
  同步后重提成功。
- d3 shard 2/3 已通过本机/Paramiko 流式中转到 d4，六个 NPZ、
  manifest、metadata 文件逐项 SHA256 一致。四片已在 d4 合并为：
  `processed/embeddings/librispeech_train_clean_360_target_nt_utterance/`。
  合并验收结果：`81,605` 行、250-D、最小/最大 L2 norm
  `0.9999998211860657 / 1.0000001192092896`；canonical source
  manifest SHA256 `f6986086fbf79e0555629ad31fe7acb5893b90db03cef44f60b27fa9e5cea76b`；
  合并 NPZ SHA256 `274dd8012a59ff02a7bcc11921b1be2b731b2c4fcba50603428c7d5c2a047f1a`；
  合并 manifest 与 canonical manifest 的 SHA256 相同。
- d4 vocoder NT main 在 01:57 已到 step `6,800`，约
  `0.36 s/step`，loss 有限且训练持续；尚未到 20k 收敛判断门槛。
- d5 LS360 units resume 在 01:57 约 `63,104/104,014`，继续运行。

- d4 的 2-DCU/1000-step DDP pilot `2117653221587161090` 已完成训练并在
  1000 步写出 `last.pt`、`checkpoint_00001000.pt` 和 `best.pt`。
  `training_log.jsonl` 的 51 条训练记录全部为有限值，`loss_d`
  `7.9976 -> 3.4541`，`loss_g` `150.388 -> 45.852`，最后验证
  mel L1 `0.860746`，best `0.855895`（step 500）。三个 checkpoint
  均已实际反序列化；`last.pt` 含 generator/MPD/MSD、两个 optimizer、
  两个 scheduler 和收敛状态，`stop_reason=max_steps`。
- pilot 控制台最终显示失败，不是数值失败：运行期间
  `scripts/run_vocoder_ddp.sh` 于 00:38 被原地更新，Bash 在执行到旧
  文件偏移后把续行误当成命令，日志末尾为
  `line 168: -early-stop-patience: command not found`。因此正式启动前
  禁止再原地改写正在执行的脚本；新作业必须使用固定 r25 包。
- pilot 输出的 root 所有权已由 Job `2117661135441678337` 纯 `chown`
  修正为 `a094f4d4`；`fix_ai_output_ownership_remote.sh` 已加入
  `N019_OFFICIAL_RUNS` 白名单，并通过 SHA256 同步。
- d4 主 NT vocoder 训练已提交：
  Job `2117662083886911489`，2 DCU，15 CPU / 59 GB per DCU，
  训练窗口 8 h、外层 8.25 h，最坏 16.5 卡时，预计 16 卡时。
  输入为 LibriTTS clean-100 33,236 条 units 和 247 个 250-D NT
  speaker embeddings；输出为 `runs/n019_official/vocoder_nt_main`。
  提交时 d4 余额 `25.7924999999` 卡时，`/public` 可用约 39 GB。
- d3 shard 3 已写出并核验 20,401 条、250-D、finite、L2 norm
  `0.99999988–1.00000012`；manifest 仍为 root-only，待 shard 2
  收尾后统一修复所有权。shard 2 当前 partial 为 18,560 / 20,401。
- d5 LS360 units resume 在 00:56 为 58,000 / 104,014，仍运行；当前
  6 小时窗口结束后必须用同一目录再次 `--resume`。

- 当前完整代码包为 `artifacts/n019_code_20261104_r25.tar.gz`，
  精确字节数与 SHA256 以同目录 `artifacts/SHA256SUMS.txt` 为准。
  r25 相对 r24 修复 AI 容器 root 所有权收尾，允许仅对
  `N019_OFFICIAL_RUNS` 做受控 `chown`，并记录 pilot 验收结果。
  r24 仍可在历史目录追溯，不得覆盖。
- d6/d7 已在 r24 上分别通过 `104 tests OK`；r25 同步后必须重新
  逐账号跑完整测试。
- d6/d7 的 `py311` 已从 d4 的 `conda-unpack` 归档迁移并完成
  `conda-unpack`；代码包、venv、SpeechBrain/HyperPyYAML/kaldiio、
  torchaudio compat 层均已安装。
- d6/d7 `audit_account_remote.sh` 均通过：Python 3.11.17、
  Torch 2.9.0、Transformers 4.46.3、SpeechBrain 0.5.16、
  librosa 0.10.2.post1、NumPy 1.26.4。
- d7 完整测试 `104 tests OK`；d6 已在新增 spectral 回归测试前完成
  `103 tests OK`，新增用例单独通过，最终 r24 同步后复跑全套。
- 2-DCU pilot 连续暴露 SCNet DTK 节点级 hipFFT 问题：
  `torch.stft` 和 `torch.fft.rfft` 都报 `HIPFFT_PARSE_ERROR`。
  当前实现改为显式分帧 + cos/sin 实数 DFT 矩阵；与 `torch.stft`
  数值一致的回归测试已通过。
- 最新 pilot Job `2117653221587161090` 使用 DFT 前端重提，
  规格仍为 2 DCU、1000 steps、0.25 h 外层墙钟、最坏 0.5 卡时。
- 该 pilot 已在 `cuda:0` 和 `cuda:1` 输出
  `mel_preflight_ok shape=(2, 80, 62) dtype=torch.float32`，
  首次通过此前阻断 DDP 的 hipFFT 门禁。
- 浏览器文件管理可稳定上传/下载大文件；SSH/SCP 大文件会间歇
  `Broken pipe`。d6/d7 的 1.3 GB 环境归档均以浏览器或限速 SCP
  传输并逐账号复算同一 SHA256。

### 2026-11-03 22:50 快照

- d4 的 NT target embedding shard 0/1 已完成并核验：
  shard 0 为 `20,402` 条、shard 1 为 `20,401` 条；两片均为
  250 维、finite、NPZ key 集合与各自 manifest 完全一致。
- 两个 shard 的控制台状态都显示“失败”，但 final NPZ、manifest 和
  metadata 已完整写出。直接原因是 AI 容器最初按 root 所有权收尾；
  已用 Job `2117623116743094274` 只做 `chown`，数据内容未改。
- d4 2-DCU/1000-step DDP pilot 已提交，Job
  `2117623823366492162`，状态“运行中”。规格：2 DCU、15 CPU/59 GB
  每卡、墙钟 0.25 h、最坏 0.5 卡时、训练 12 分钟上限。
- d3 shard 2/3 仍在运行；22:29 的 partial NPZ 分别为
  `17,727,980` 和 `20,212,696` bytes。它们由旧版脚本启动，完成后
  预计仍是 root-owned，需要同样做一次短 `chown`。
- d5 LS360 units resume 在 22:29 到 `45,104 / 104,014`；
  仍须同目录 `--resume`，不能换输出目录。
- d6/d7 已完成网页持久化登录、独立 SSH key 下载与安装，均可
  `ssh scnet-a094f4d6` / `scnet-a094f4d7` 登录。key 为 E-Shell
  页面生成的 30 天 RSA key，到期时间约 2026-12-03。
- d4 的 `py311` 已打成可迁移归档并通过 `zstd -t`：
  `1,317,358,370` bytes，SHA256
  `babcb9a81b3f0dc4f1125edc3af24bcd7b42723caf8bad2a3bd7b819110ad41f`。
  该归档含 `conda-unpack`；d6/d7 解包后必须运行再验收。

## 0.0.1 上一执行状态（2026-11-03 20:32）

- 三账号在 20:31 的实时余额：d3
  `40.3622222221`、d4 `31.3025`、d5 `18.7744444444` 卡时。
  浏览器会话已持久化，`--inspect-accounts --no-prompt` 可直接读取，
  不需要重新登录或再次索取密码。
- d4 target embedding shard 0/1 在 20:01 均为
  `16,896 / 20,402`，仍在写 `partial_embeddings.npz`；JobID
  `2117447702608093185`、`2117447862870855681`。
- d3 target embedding shard 2/3 在 20:32 分别为
  `9,472 / 20,401` 与 `11,264 / 20,401`；JobID
  `2117524054988300289`、`2117524094031339521`。
- d5 LS360 units 第一个 6 小时窗口在 `33,504 / 104,014` 结束，
  控制台状态为“失败”，日志确认是 `timeout --signal=TERM 21600`
  到点退出，partial 文件保留。
- 已通过配置脚本提交 resume JobID `2117591722692628481`，任务名
  `n019_ls360_units_resume_20261103_201559`。日志确认
  `resume=1`，从 `33,600 / 104,014` 继续，20:31 到
  `33,800 / 104,014`；禁止再次创建同名任务或换输出目录。
- 四份 `run_vocoder_ddp.sh`、`run_vocoder_ddp_pilot_ai.sh`、
  `extract_ecapa_embeddings_remote.sh` 已在三账号同步并通过
  `bash -n`；d4 旧脚本偏差已消除。
- `anonymize_ls360_remote.sh` 已参数化
  `N019_DURATION_MODE`、`N019_VOCODER_TYPE`、
  `N019_VOCODER_EMBEDDINGS`、`N019_DURATION_EMBEDDINGS`。
  NT 与 ECAPA 分别选择对应 target embedding 和 vocoder；`orig`
  不再要求 duration model。当前 SHA256 为
  `c5b9cde049990d558f650d1bf312d1c4b739e0105b92c7819d47cf5230a042a5`。
- 已新增官方 VPC ECAPA 的 LS360 target utterance shard 提取入口：
  `scripts/run_ls360_target_ecapa_shard_ai.sh` 和四个 launcher；
  四个任务已写入 `configs/scnet_browser_tasks.json`，状态为
  `planned_after_nt_embeddings`、`submit:false`，尚未提交。
- `merge_target_embedding_shards.py` 现支持 `--kind nt|ecapa`；
  NT 固定 250 维，ECAPA 固定 192 维，输出文件名和 metadata 随 kind
  改变。本地测试为 `99 passed, 2 skipped`；完整目录级 `pytest` 会把
  `artifacts/r9_compare_tmp/tests` 一起收集并触发同名模块冲突，正式
  测试命令应使用 `python -m pytest -q tests`。
- 当前代码包为 `n019_code_20261103_r21.tar.gz`，SHA256
  `09a1ae008fdaa93a680807f895346fa97e5434dde01a8ad9a36f6e9ffd42595e`，
  d3/d5 已解包；d4 的 tar 解包受 SSH 中断影响，已改为逐文件二进制
  流式同步本次关键文件并逐项 SHA256 校验一致。
  三账号 `unittest discover -s tests` 均为 `103 tests ... OK`；新增
  shell 已通过 `bash -n`。不要覆盖历史代码包。
- 用户已确定训练策略：不再无条件跑满 400k，而是按验证集收敛停止；
  每个账号训练窗口结束必须保存 `last.pt`，换账号后从该 checkpoint
  精确续训。实现与体积说明见 `docs/VOCODER_TRAINING_RESUME.md`。
- 当前 early-stop 默认：每 2,000 steps 验证，至少 20,000 steps，
  连续 15 次没有至少 `0.001` 的 mel L1 改善则停止；400,000 仍只是
  安全上限。
- `last.pt` 实测约 973 MiB，包含 generator、MPD、MSD、两个 AdamW
  optimizer 和 scheduler；`best.pt` 仅 generator，约 54 MiB。
  duration checkpoint 约 4.1 MiB。跨账号前必须传输约 1.02 GB 的完整
  resume checkpoint。
- `scripts/transfer_vocoder_run.py` 已实现本地中转分块、逐块和最终
  SHA256 校验、目标原子解包；d3→d5 的 3.15 MB 假 checkpoint 全链路
  自测通过。
- 主训练配置已写入 `configs/scnet_browser_tasks.json`：
  `d4-vocoder-nt-main`、`d3-vocoder-nt-main-continuation`、
  `d4-vocoder-ecapa-main`、`d3-vocoder-ecapa-main-continuation`，
  当前全部 `submit:false`。d4 pilot 通过前不得提交主训练。
- 用户新增可用算力账号 `a094f4d6`、`a094f4d7`，但要求先配置环境。
  两账号已加入 provisioning/download/inspection 白名单；尚缺各自 SSH
  key、持久化浏览器会话、环境导入测试和空间审计，完成前禁止提交卡时
  任务。

## 0.1 最新执行状态（2026-11-03 03:00）

- 三账号环境导入已验证；`a094f4d4` 的激活脚本已改为不依赖
  交互式 `module` 函数，并已通过 CPU probe 和 37 个单元测试。
- `train-other-500` 已通过 SSH 完整解压并验收为 205,044 个 WAV。完成
  标记是 `audit/train-other-500.ssh-complete.20261102_222950.txt`。
  旧 1,272 条目录保留为 `train-other-500.partial.ssh.20261102_222950`，
  在确认无需回滚前不要删除。
- 官方 manifests 已生成到 `data/n019_official/processed/manifests`：
  LibriSpeech clean-100 为 28,539 句/251 人/100.59 h；LibriTTS clean-100
  为 33,236 句/247 人/53.79 h；LibriTTS other-500 为 205,044 句/1,160
  人/310.08 h。manifest 哈希在 `audit/official_manifests.sha256`。
- duration 训练中发现并修复了带 padding 的随机 unit masking 形状错误；
  CLI 单批次集成训练已成功，回归测试已加入。
- W-PRO extractor 已按官方 `compute_embedding` 的默认行为截断到前
  320,000 samples，并在 embedding metadata 中记录。
- `n019_official_smoke` 已实际完成：Slurm `1020395`，节点 `f11r2n04`，
  DCU forward/backward、bf16 和 checkpoint 均通过。
- LibriSpeech units 已在 Slurm `1020558` 内完成并核验：
  28,539 条 record、251 个 250 维 W-PRO speaker embedding、K=200
  codebook。`units_metadata.json` 中的 codebook SHA256 为
  `a5cc08f707301a1c05da4ab4b00cd280dec66533796a976c3ac4743287eaf446`。
  `1020558` 外层作业最终 FAILED，原因是随后 LibriTTS resample 的旧
  compat 维度错误；不能把整个 Job 记成 COMPLETED。
- 旧 compat 错误已修复。Slurm `1020709` 暴露了新的节点级问题：
  `f11r1n17` 上最小 `GroupNorm [1,512,500]` 也报 HIP
  `invalid device function`。对照 `1020739` 在 `f11r2n04` 通过全部
  GroupNorm/短中长 HuBERT 探测，确认不是数据或 batch 问题。
- `f11r1n17` 已从 unit pipeline 排除；所有长 GPU 作业启动前运行
  `python -m n019.diagnose_hubert --quick` 预检。远端全量单元测试现为
  39 项通过。
- Slurm `1020756` 正在 `f11r1n07` 运行 LibriTTS clean-100 units，
  预检通过；完成后同一作业继续提取 247 个 speaker 的 250 维 W-PRO
  embedding。下一步是评测数据资产、original speech baseline、
  duration pilot 和 NT Unit HiFi-GAN pilot。

### 0.2 已完成的首轮门禁（2026-11-03 03:45）

- `1020756` 已 COMPLETED：LibriTTS 33,236 units、247 个 250 维
  W-PRO embeddings。`scripts/verify_processed_units.py` 全量核验：
  LibriSpeech 28,539 和 LibriTTS 33,236 records 均无缺文件或形状错误；
  两套 W-PRO embedding 均为 250 维、L2 norm 约为 1；codebook
  `(200,768)`，SHA256
  `a5cc08f707301a1c05da4ab4b00cd280dec66533796a976c3ac4743287eaf446`。
  LibriSpeech 只保留 1 个旧的 `.tmp.npy` 警告，不影响最终文件。
- `1020773` 已 COMPLETED：固定 target map 覆盖 1,934 个 source，
  去重后 1,924 个 target utterance；W-PRO utterance embeddings 和
  1,934 句 `libri_test` units 已生成。
- VPC 的 `libri_test/` 原始包只有 `wav/`，没有 `wav.scp` 等元数据。
  已由 manifest 生成 1,934 行 `wav.scp/utt2spk/text/utt2dur` 和
  40 个 speaker 的 `spk2gender/spk2utt`，并位于
  `vpc/data/libri_test/`。
- 原始 E-VPC 已得到：female `8.761%`、male `0.418%`，平均
  `4.5895%`；论文为 `4.6%`。这是原始语音基线通过的强证据。
  ASR 首次失败原因是离线环境缺
  `facebook/wav2vec2-large-960h-lv60-self` 的 `config.json` 和
  `preprocessor_config.json`，已下载到 `HF_HOME` 缓存。
- 原始 W-NT（W-PRO）得到：female `7.1177%`、male `7.3494%`，
  平均 `7.2335%`；论文为 `7.8%`。差异属于同一量级，后续报告必须
  注明 W-PRO 版本和 UTMOS/WhiSQA snapshot，而不是声称逐位一致。
- 原始 WER 已在 `1020917` 完成：`1.8435%`，论文为 `1.8%`。官方
  baseline 的三项门禁全部通过，证据已复制到
  `runs/n019_official/evidence_original_20261103/`，含 README、
  results、config、Slurm 日志和 SHA256SUMS。
- `1020918` duration NT pilot 已 COMPLETED：全量 1 epoch 用时
  `14.6 s`，`train_loss=3.3666`，duration mean/std
  `1.8093/1.2481`，checkpoint 大小 4.1 MB。
- `1020937` 已完成 30-epoch NT duration predictor：
  `train_loss 3.3681 → 2.3985`。`1020938` 已完成无条件
  `DU-pred`：`3.4252 → 2.6172`。两者均使用 28,539 句
  LibriSpeech train-clean-100，checkpoint 在
  `runs/n019_official/duration_nt_main/` 和
  `duration_pred_main/`。
- `1020953` NT Unit HiFi-GAN pilot 已完成 2,000 steps：batch 32、
  bf16、1 DCU 稳定约 `0.519 s/step`，checkpoint
  `checkpoint_00002000.pt` 和 `last.pt` 已保存。验证 mel L1 在
  500/1000/1500/2000 步为
  `0.867/0.879/0.846/0.913`，说明 2k 步还不能判断最终质量，但训练、
  验证和 checkpoint 链路通过。按该吞吐，400k steps 在单 DCU 上约
  58 小时；主训练必须转到人工智能/模型训练或用多 DCU DDP。

### 0.3 主训练入口

AI 容器统一使用 `scripts/run_vocoder_ddp.sh`。脚本会：

- 按 `/mnt/data/voice_projects`、
  `/public/home/<user>/voice_projects`、`$HOME/voice_projects` 的顺序
  自动识别项目根；
- 先运行 `scripts/preflight_dcu_remote.sh`；
- 用 `python -m torch.distributed.run --standalone` 启动
  `n019.vocoder` 的 DDP；当前 env 没有单独安装 `torchrun` 可执行文件；
- 保持 effective batch 为 32（`N019_VOCODER_TOTAL_BATCH`）；
- 默认 400k steps、bf16、每 5k 保存一次、每 50k 留档；
- 默认墙钟上限为 `48 / DCU 数` 小时，保证最坏不超过 48 卡时；
- 支持从 `last.pt` 自动续训。

示例（4 DCU）：

```bash
N019_NPROC=4 N019_VOCODER_RUN_NAME=vocoder_nt_ddp \
  bash scripts/run_vocoder_ddp.sh
```

若要拆分账号，先把 `last.pt` 和 `meta.json` 同步到下一账号同一 run 路径，
保持架构参数完全一致，再运行同一命令；`vocoder.py` 会从 checkpoint 续训。

### 0.4 单句端到端 smoke

用 2,000-step pilot checkpoint 和已训练的 duration predictor 在第一句
`1089-134686-0002` 上完成 CPU 推理：

- `DU-orig-nt`：331 frames，6.62 s；
- `DU-pred-nt`：334 frames，6.68 s；
- 两条路径均成功生成 16 kHz WAV、`anon.jsonl` 和 `run_meta.json`，
  单句 CPU 推理约 5 秒。

输出目录：
`runs/n019_official/smoke_inference_1020953/`。这些 WAV 只用于链路验证，
不是最终匿名化结果。

### 0.5 尚未闭环的评测项

- W-NT I/L 已实现：I 用原始 enrollment，L 用同一匿名系统生成的
  enrollment；两者都使用匿名 trial。W-NT S 需要按
  `ASV_eval^anon` 在匿名化的 train-clean-360 上重训 W-NT，当前尚未实现，
  不能把 I/L 冒充 S。
- UTMOS22 与 WhiSQA checkpoint 已下载，但还没有批量评分 wrapper。
  等 DU 系统音频稳定后再接，且必须记录实际 snapshot。
- 主 Unit HiFi-GAN 仍需 400k-step 训练；HPC 1-DCU 只有约 58 小时
  吞吐，无法在当前剩余额度内完成，必须用 AI 模型训练多 DCU。

### 0.6 2026-11-03 环境与 MOS 新进展

- `a094f4d3`、`a094f4d4`、`a094f4d5` 已分别重新执行
  `scripts/check_official_env_remote.sh`。三账号均为 Python 3.11.17、
  Torch 2.9.0、HIP 6.3.26093、torchaudio 2.9.0+scnet-compat，
  Transformers 4.46.3，`compileall` 通过；登录节点无 DCU 属正常现象。
- `a094f4d4` 全量测试由 39 项增至 48 项并全部通过，新增 MOS 输入
  去重/冲突检测、LS360 ID 校验和 fairseq Python 3.11 兼容补丁测试。
- UTMOS 官方 demo 源码已固定到 `vendor/UTMOS22-demo/`，文件哈希记录在
  该目录 `README.md`。UTMOS 权重仍来自镜像 snapshot
  `65956d677bd502519c30c0f4bfda97a749d63009`，不是作者 commit。
- fairseq 0.12.2 已安装并在当前环境内做 Python 3.11 dataclass 兼容补丁；
  Hydra/OmegaConf 降至 UTMOS 作者 requirements 的
  `1.0.7/2.0.6`，Hydra 自身也做了 dataclass 兼容补丁。补丁可重复执行：
  `python scripts/patch_fairseq_py311.py --tree <site-packages>/fairseq`。
- `openai/whisper-small` 已缓存在 `$HF_HOME/hub`，snapshot 为
  `973afd24965f72e36ca33b3055d56a652f456b4d`；WhiSQA 使用官方
  `single_head_model.pt`。
- 单句 CPU smoke：
  - UTMOS `1089-134686-0002` = `4.314345359802246`；
  - WhiSQA 同一句 = `4.5908671617507935`。
  这两个数值只证明加载和推理链路通过，不是 Table 1 结果。
- 新增 `src/n019/eval_mos.py`、`scripts/evaluate_mos_remote.sh`，
  支持对女/男 trial `wav.scp` 合并去重后批量评分，并保存逐句 TSV、
  模型/代码/输入 SHA256。
- 新增 `src/n019/prepare_train360.py`，从原始 LibriSpeech
  train-clean-360 建立 utterance ID 与 VPC 官方 `wav.scp` 完全一致的
  manifest；任何 ID 集合不一致都会直接失败。
- 新增 `scripts/run_s_eval_remote.sh`，直接调用 VPC2024 官方
  `configs/eval_paper_test_only_post.yaml`，在匿名化 LS360 上重训
  ECAPA 10 epochs 并计算 E-VPC S。W-NT S 模型仍需单独 fine-tune，
  `scripts/evaluate_wnt_remote.sh` 已预留 `N019_WNT_S_MODEL` 入口。
- W-NT S 训练代码已补齐为 `src/n019/wnt_attack.py` 和
  `scripts/train_wnt_s_remote.sh`。它强制检查 104,014 句/921 人，
  以 250 维 W-PRO 为初始化，在匿名化 LS360 上 fine-tune 20 epochs。
  CPU smoke 已确认 W-PRO forward 输出 `(1,250)` 且 L2 norm 为 1。
  论文未公开 S fine-tune 的 lr/batch/segment/AAM 设置，当前选择已在
  `docs/ALGORITHM_IMPLEMENTATION.md` 标为实现假设。
- `a094f4d3` 和 `a094f4d5` 已同步可训练代码与两份小型处理后训练集：
  LibriSpeech clean-100 28,539 units、LibriTTS clean-100 33,236 units、
  对应 251/247 个 250 维 W-PRO speaker embeddings。打包文件 SHA256 为
  `08e97bb8578492bc919b3ac25e42ade0565c8684c2b2668f29351f1ddcf2d195`。
  两个账号的 unit records 已把 `codes_path` 改写到各自 home，并通过
  `verify_processed_units.py` 全量核验。
- `a094f4d3` 与 `a094f4d5` 当前各通过 71 项单元测试；两者均已具备
  `run_vocoder_ddp.sh`、pilot Slurm 模板和完整 28,539/33,236 记录，
  因此可以在确认卡时计划后直接承接主 vocoder 训练。
- 当前主要阻塞仍是 SCNet 人工智能/模型训练控制台处于登录页。登录后
  先读取余额并确认 1k-step DDP pilot；见 `docs/JOB_LEDGER.md` 的待确认
  资源计划。

### 0.7 2026-11-03 当前最新状态

- 最新代码包为 `artifacts/n019_code_20261103_r18.tar.gz`，SHA256 见
  `artifacts/SHA256SUMS.txt`。
  r18 在 r17 基础上补齐 LS360 匿名化的 duration-embedding 参数传递。
  r17 已修复混合 d3/d4 路径的 unit-record 迁移，并让 d3 clean-100
  收尾脚本可幂等复跑。r16 已增加浏览器会话状态持久化、
  任务列表只读检查、target embedding canonical 合并校验。
  早期版本相对 r9 增加并发安全的原子
  manifest 写入、LS360 target 映射修正、target embedding 入口、
  匿名化前磁盘空间门禁、机器可读 Table 1 指标组装/对表工具，以及
  配置驱动的 SCNet 浏览器登录/建任务脚本；当前本地 98 项 Python tests
  通过、2 项 skip，`compileall` 通过。
- 三个账号的环境 gate 已再次通过：Python 3.11.17、Torch 2.9.0、
  HIP 6.3.26093、torchaudio 2.9.0+scnet-compat、Transformers
  4.46.3、SpeechBrain 0.5.16。登录节点无 DCU 属预期。
- LS360 manifest 已完成：
  `data/n019_official/processed/manifests/librispeech_train_clean_360.jsonl`
  为 104,014 句、921 人、363.6056 小时、16 kHz 单声道；ID 集合已与
  VPC 官方 `train-clean-360/wav.scp` 强制比较一致。manifest SHA256
  `1c32d0cb016289e4528f9a682dc17343ceb72416a1fc174ff27d7422d0a20263`，
  VPC `wav.scp` SHA256
  `ebb0dc7cbeaee1a169b1fe7ea505908e92a684e05de2add2d93cfc1f67e4dc7b`。
- `a094f4d5` 已在自身服务器完成 LS360 下载、MD5 校验、SSH 解压和
  manifest 扫描；104,014 句、921 人、363.6056 小时、16 kHz 单声道。
  其 manifest 因记录本机绝对路径，SHA256 为
  `d6b9be4ebbf37175a05e02f55b2adcf41f0b761c3af8ca1c4f7f4b74f3676053`，
  与 d4 不会逐字节相同；ID 集合、官方 `wav.scp` SHA256 和统计口径一致。
- 旧 LS360 target map 把抽样池错误地缩成了 `libri_test` 用到的 1,924
  个 target，并使用了 `mode=speaker`。它不能进入正式 S 结果。新流程
  `scripts/prepare_ls360_target_map_remote.sh` 改为从完整
  205,044 句 LibriTTS other-500 以 `mode=utterance` 抽样，再单独选目标
  embedding 清单；`scripts/extract_ls360_target_embeddings_remote.sh`
  负责提取。d4 已生成正式 map：104,014 个 source、81,605 个实际引用
  target；map SHA256
  `c9a182adfc4076087dc5144a85694b5900270a4fefee6b38459d720da228ee75`，
  target subset SHA256
  `f6986086fbf79e0555629ad31fe7acb5893b90db03cef44f60b27fa9e5cea76b`。
  target subset 共 81,605 句、1,158 人、123.8027 小时。旧文件保留作
  失败/偏离记录。map 和 target manifest 已通过本机中转同步到 d3/d5，
  两个账号的 SHA256 均与 d4 一致。
- `n019.units --resume` 和 `n019.anonymize --resume` 已实现。前者每批
  保存 `unit_records.partial.jsonl`；后者每 25 条保存
  `anon.partial.jsonl`。续跑会校验 codebook/K/layer、duration mode、
  vocoder type、确定性输出路径和文件存在性。
- LibriSpeech LS360 unit extraction 入口已补齐：
  `scripts/extract_ls360_units_remote.sh`、
  `hpc/n019_ls360_units.slurm`、`scripts/verify_unit_dataset.py`。
  资源计划见 `docs/LS360_UNIT_RESOURCE_PLAN.md`。任务尚未提交。
- CPU duration 推理诊断已完成（`libri_test` 1,934 句）：
  - `duration_nt_main`：1 个 utterance 出现负值，最小 `-0.3114`；
    437,390 个 unit 的总时长相对误差 mean `7.872%`、p95 `19.648%`。
    推理前会 clamp 负值到 0，并逐句记录 `negative_duration_values`。
  - `duration_pred_main`：无负值；总时长相对误差 mean `4.997%`、
    p95 `12.748%`。
  - 证据：`runs/n019_official/evidence_duration_nt_diag_20261103.json`
    和 `runs/n019_official/evidence_duration_pred_diag_20261103.json`。
- W-NT S fine-tune 已补成 `python -m torch.distributed.run` DDP：
  W-PRO 编码器与 AAM head
  共同封装，默认全局 batch 8、4 DCU（每 rank 2），loss/accuracy 做
  全 rank 聚合，rank 0 保存和导出。单进程入口仍可用 `N019_NPROC=1`。
- VPC 原始轨迹映射已纠正。`OO` 是原始基线；原始模型的 `OA` 才是 I、
  `AA` 才是 L；匿名化重训模型的 `AA` 才是 S。旧 parser 把 `OO` 标成
  I 的错误已删除，原始基线重新落盘为
  `evidence_original_20261103/evpc_metrics_neutral.json`。
- `a094f4d5` 的 LS360 原始包由该账号自行从镜像下载，并按用户要求用
  SSH 解压；没有从主账号中转 23 GB 原始包。
- `1021278` 已完成一次有界端到端 pilot（2,000-step vocoder，非 Table 1）：
  E-VPC I mean `46.8735%`、L mean `46.4230%`；W-NT I mean
  `42.3356%`、L mean `42.3863%`；anon WER `18.424%`。WER 的主要问题
  明确来自尚未训练的 2k vocoder，不能拿这些数值替代主模型结果。
- Evidence 位于 `runs/n019_official/pilot_e2e/`。VPC 的文本 summary
  只写了 OO，但 `exp/asv_orig/results_n019_pilot.csv` 保留了完整
  OO/OA/AA；parser 现在会合并 CSV，不能只看 `results_orig.txt`。
- 仍未完成：正式 LS360 utterance target map、LS360 target embeddings、
  LS360 HuBERT unit extraction、主 vocoder 400k steps、
  DU-orig-nt/DU-pred-nt 全测试集匿名化、I/L/S、WER、UTMOS/WhiSQA。
- 当前阻塞已从控制台登录转为新模型训练平台在容器启动前返回 FAILED；
  详见 0.8。HPC 估算累计约 49.027 卡时，不能把 LS360 units 或长训练
  提交到 `hx1hdnormal`。
- 2026-11-03 的 `sbatch --test-only` 进一步确认：`a094f4d4` 在
  `hx1hdnormal` 的 group max DCU 为 1，2-DCU HPC 请求会报
  `AssocGrpGRES`。多 DCU DDP 只能走人工智能/模型训练。

### 0.8 2026-11-03 10:20 AI pilot 容器启动阻塞

- 已通过 Edge 登录 `a094f4d4`；实时页面显示 50 卡时、华中一区 A 区、
  113 组 `hx1hgbwnormal`、BW 1 卡可用。
- 三次 1-DCU、256 句、10 分钟以内 pilot 均返回 FAILED：
  - `2117438497411723265`：日志明确为 `/root/voice_projects/...`
    `No such file or directory`，属于容器路径错误；
  - `2117440005699194882`：实例开始/结束时间 `--`，日志为空，
    调度事件为空；
  - `2117440312291258369`：改为直接执行
    `/public/home/a094f4d4/.../run_ls360_target_embedding_pilot_ai.sh`，
    仍在实例启动前 FAILED，日志和调度事件为空。
- 不能将以上任务计为有效吞吐，也暂不能证明产生卡时；费用仍需核验。
- 已将 AI 入口根目录探测统一为
  `/mnt/data/voice_projects`、
  `/public/home/<user>/voice_projects`、`$HOME/voice_projects`，
  修改了 `hpc/activate_n019_official.sh`、
  `scripts/preflight_dcu_remote.sh`、
  `scripts/run_ls360_target_embedding_pilot_ai.sh`、
  `scripts/run_vocoder_ddp.sh`、
  `scripts/extract_ls360_target_embeddings_remote.sh`。
  五个脚本在本地与 d4 均通过 `bash -n`，d4 上逐文件 SHA256 与本地
  一致：`178a13e...`、`3832216...`、`605418d...`、`779e340...`、
  `79dbbb2...`。
- 本地测试为 `82 passed, 2 skipped`，`compileall` 通过。
- 下一步只做一次最小容器启动诊断（例如打印 `id/pwd/ls` 后退出），
  确认平台是否执行启动命令；在得到实例开始时间和日志前，不重复提交
  target 主提取或任何长训练。

### 0.9 2026-11-03 10:45 target embedding pilot 通过并启动正式分片

- 最小容器诊断 `2117441405643378689` 已完成，确认容器内
  `id=root`、`pwd=/workspace`、`HOME=/root`，但
  `/public/home/a094f4d4/voice_projects` 正常挂载，`hy-smi` 可见
  1 块 DCU。
- 根因是 AI 容器内 `id -un=root`，旧路径探测会拼出
  `/public/home/root/...`。现已优先从脚本自身 `BASH_SOURCE` 推导根。
- 256 句 pilot `2117442203569016834` 已完成：含模型加载
  `638.0 s`、`0.4012539185 句/s`，外推 81,605 句
  `203,374.96 s = 56.4930` 卡时。NPZ SHA256
  `f271a655aab72b4fe8f539abd0133be0afd0280d82eaa3f41638279219abeced`；
  本地复核 256 条、250 维、有限值、L2 norm 约 1。
- 正式提取使用四份确定性互斥 shard，每份 `20401–20402` 句：
  d4 运行 shard 0/1（`2117447702608093185`、
  `2117447862870855681`），d3 运行 shard 2/3。每任务 1 DCU、
  15 CPU、59 GB、墙钟上限 18 小时；四任务最坏 72 卡时，预计总计
  约 56.5 卡时。
- d3 已完成 `train-other-500.tar.gz` SSH 解压和 canonical 移动，
  验收 205,044 个 WAV；shard 2/3 只等当前 2-DCU pilot 释放配额。
- 新增 `prepare_target_embedding_shards.py`、
  `merge_target_embedding_shards.py`、shard 启动脚本及回归测试；
  本地 `83 passed, 2 skipped`，shell syntax 和 `compileall` 通过。

### 0.10 浏览器任务提交脚本

- 后续不要再反复用 computer-use 手工点“创建”。
- 使用 `scripts/scnet_browser_tasks.py`；所有页面选择在
  `configs/scnet_browser_tasks.json`：账号、区域、加速卡、资源组、
  卡数、实例数、自动容错、镜像、墙钟、输入输出、停止条件、任务名、
  启动脚本，以及 `browser.ui` 中的登录/创建页选择器。
- 密码只从 `SCNET_PASSWORD_<ACCOUNT>`、`SCNET_PASSWORD` 或交互式
  `getpass` 读取，不写入配置和结果 JSON。
- 默认 `dry_run=true`，只填表并截图；正式提交使用 `--submit`。
- `--check-config` 可离线检查模板、任务名长度和资源配置，不打开浏览器。
- `--list-tasks` 可离线列出所有任务，包括 `enabled:false` 的备用任务。
- `--account <账号> --list-jobs` 可只读列出控制台任务行，并保存 JSON
  和整页截图；同一账号的持久化 Edge profile 不能并行运行两个实例。
- 2026-11-03 16:15 已用脚本自行登录三账号并保存
  `~/.scnet-browser-profiles/<account>/n019_browser_state.json`；该文件
  恢复 cookies/localStorage/sessionStorage，不保存密码。随后
  `--no-prompt` 复查三账号余额成功，不需要再次手工登录。
- `--submit` 与 `--dry-run` 互斥；任务已有 `submitted_task_id` 时，
  正式提交会在打开浏览器前被拒绝，必须确认旧任务结束后清理该字段或
  显式使用 `--force-resubmit`。
- 脚本会逐项校验名称、区域、资源行、卡数、实例数、自动容错、完整镜像
  tag 和启动脚本，并写出 `<task>_form.json`。平台不单独提供 CPU/RAM
  选择，因此配置记录并验证每卡 15 CPU / 59 GB 的资源行。
- 2026-11-03 已用该脚本完成真实登录和 d4 shard 0 干跑，未点击创建、
  卡时 0；`实例数=2` 的加减控件路径也已干跑通过。
- 2026-11-03 15:51 在增加防重复提交和显式 `--dry-run` 后再次干跑通过；
  `tests/test_scnet_browser_tasks.py` 为 10 passed。
- d4 shard 0/1 已有运行中 job，配置中设 `submit:false` 并记录现有
  `submitted_task_id`，防止误重复提交；d3 shard 2/3 在解压验收前同样
  为 `submit:false`。
- 正式创建按钮之后的跳转、任务 ID 与状态解析尚未做一次真实提交；
  第一次获批提交时必须保存 `*_submitted.png` 和 `results.json`。
- 本轮本地完整测试为 `98 passed, 2 skipped`；浏览器脚本专项测试为
  `10 passed`。

## 0. 你的任务

你接手的是 N019 的官方复现，不是 N010，也不是此前的 80-trial
探索实验。目标是在 SCNet 上完成以下闭环：

1. 建立独立的 `n019_official` 远端项目。
2. 配置可复现的 DTK/DCU 环境。
3. 获取并校验论文所需的数据、模型和官方评测代码。
4. 实现 HuBERT+k-means unit、duration predictor 和 Unit HiFi-GAN。
5. 先完成 `DU-orig-nt` 与 `DU-pred-nt` 的核心消融。
6. 在官方 VPC2024 `libri_test` 上跑 E-VPC、W-NT、WER、UTMOS 和
   WhiSQA。
7. 记录卡时、失败实验、原始分数和与论文 Table 1 的差异。

最终不能只交一个“能跑”的脚本。必须能回答：

- 用了哪个账号、哪种 SCNet 模式、多少卡时；
- 用了哪一版代码、数据、模型和 trial list；
- 哪些数值是论文明确给出的，哪些是实现假设；
- 哪些指标完成官方复算，哪些只是探索性结果；
- 为什么旧结果不能冒充完整 Table 1。

## 1. 不可违反的规则

### 1.1 平台边界

- 只使用 SCNet 账号 `a094f4d3`、`a094f4d4`、`a094f4d5`。
- 三个账号现在都允许使用“高性能计算 / Slurm”和
  “人工智能 / 模型训练”两种模式。
- 主账号是 `a094f4d4`；`a094f4d3` 是第二训练账号；
  `a094f4d5` 是备用账号。
- **绝对禁止连接或操作实验室 A6000。**
- **绝对禁止使用 `/mnt/data/lihaopeng`、`lab-a6000-direct` 或任何以
  `lab-` 开头的旧主机。**
- 用户已授权直接执行 SCNet 操作，不必每次等待单独批准。但任何消耗卡时的
  任务仍须先打印资源计划、预计/最坏卡时、输入输出和停止条件，并写入台账。
- 不删除其他项目、其他账号或旧实验的文件。需要清理时，先列清单并得到用户
  确认。
- 不打印、复制或提交私钥、密码、token。SSH 私钥只允许由 SSH 客户端读取。

### 1.2 科学边界

- 机器可读版本锁定在 `configs/source_lock.json`。
- VPC2024 必须使用 tag `v2`，commit
  `7c80e86d3a4d58b81a2f3bdc01a3508c37018be4`，不能使用 `main`。
- Table 1 的主数值只使用 VPC2024 `libri_test`，不是 `dev + test`。
- E-VPC 必须使用 VPC2024 release 中的官方 `asv_orig`，不得用
  SpeechBrain Hub 的 VoxCeleb ECAPA 代替。
- W-NT 必须使用 `Orange/Speaker-wavLM-pro` 的 250 维版本。
- 训练数据必须是原始 LibriTTS，禁止 LibriTTS-R。
- IEMOCAP 不进入 N019 Table 1；不要下载 IEMOCAP 后才能开始主实验。
- 论文没有公开作者完整代码。不得写“作者代码完全复现”。
- 旧 `n019_repro` 的 result、checkpoint 和 Table 1 都只能标为探索性，
  不得作为正式论文证据。

## 2. 本地项目与权威文件

本地官方项目：

```text
C:\Users\lihaopeng\Desktop\文件\水课\大三上\语音识别_N019_official
```

先完整阅读以下文件：

```text
README.md
docs/OFFICIAL_ASSET_MANIFEST.md
docs/ACQUISITION_RUNBOOK.md
docs/PAPER_ALIGNMENT_CHECKLIST.md
docs/PUBLIC_DATA_FALLBACK.md
configs/source_lock.json
scripts/check_local_assets.ps1
```

论文和评测计划：

```text
vendor/papers/N019_paper.txt
vendor/papers/N019_Joint_Timbral_Non-Timbral_Speaker_Anonymisation.pdf
vendor/papers/VoicePrivacy_2024_Eval_Plan_v2.0.pdf
vendor/papers/VoicePrivacy_2024_Eval_Plan_v2.0.txt
vendor/papers/bakari25_spsc_W-NT.pdf
```

在当前 Windows 机器上先运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\check_local_assets.ps1
```

允许出现：

```text
PENDING asr.zip is not present
```

其他任何 FAIL 都必须先修复，不能继续。

## 3. SCNet 账号和当前状态

本地 `%USERPROFILE%\.ssh\config` 已有以下别名：

| 别名 | 用户 | 私钥 | 角色 |
|---|---|---|---|
| `scnet-a094f4d3` | `a094f4d3` | `~/.ssh/scnet_a094f4d3_rsa` | 第二训练账号 |
| `scnet-a094f4d4` | `a094f4d4` | `~/.ssh/scnet_a094f4d4_rsa` | 主账号 |
| `scnet-a094f4d5` | `a094f4d5` | `~/.ssh/scnet_a094f4d5_rsa` | 小任务备用 |

只允许检查密钥是否存在和文件大小，不得读取或打印私钥内容。

### 3.1 2026-11-02 只读审计快照

三个账号都能登录。默认 home：

```text
/public/home/a094f4d3
/public/home/a094f4d4
/public/home/a094f4d5
```

HPC/Slurm 分区：

```text
hx1hdnormal
最大墙钟：3 天
每个请求使用 --gres=dcu:N
```

`sacct` 累计的 1-DCU 卡时：

| 账号 | 已用 HPC 卡时 | 按 50 小时估算余额 |
|---|---:|---:|
| `a094f4d3` | 42.035 | 约 7.965 |
| `a094f4d4` | 46.392 | 约 3.608 |
| `a094f4d5` | 38.101 | 约 11.899 |

HPC 余额不是 CLI 直接给出的权威值，必须继续用 `sacct` 和
`sbatch --test-only` 复核。

模型训练余额在 2026-10-31 直接从控制台读到：

| 账号 | 模型训练余额 | 备注 |
|---|---:|---|
| `a094f4d3` | 50.0000 卡时 | 可用于第二训练 |
| `a094f4d4` | 50.0000 卡时 | 主训练账号 |
| `a094f4d5` | 24.9067 卡时 | 存储接近满 |

这些 AI 余额可能已经变化。接管后必须在控制台重新读取“机时余量”，
不能把 2026-10-31 的数字当实时余额。

存储快照：

| 账号 | 已用 / 配额 | 状态 |
|---|---:|---|
| `a094f4d3` | 约 58 / 200 GB | 可用 |
| `a094f4d4` | 113 / 200 GB，57% | 主数据目录 |
| `a094f4d5` | 188 / 200 GB，94% | 不放全量语料 |

AI 模型训练入口：

```text
https://www.scnet.cn/ui/console/index.html
-> 人工智能
-> 模型训练
-> 创建任务
```

创建页必须记录：

```text
账号：
任务名：
区域：
加速卡：
卡数：
镜像完整 tag：
自动容错：关闭
墙钟上限：
最坏卡时：
预计卡时：
容器项目根：
输出路径：
启动脚本：
机时余量：
```

自动容错必须关闭，否则异常重启会重复消耗卡时。

## 4. 旧远端项目 `n019_repro` 的处理

主账号 `a094f4d4` 现有旧探索项目：

```text
/public/home/a094f4d4/voice_projects/code/n019_repro
/public/home/a094f4d4/voice_projects/data/n019
/public/home/a094f4d4/voice_projects/models/n019
```

2026-11-02 快照：

```text
code/n019_repro = 11 GB，其中 runs 约 11 GB
data/n019       = 25 GB
models/n019     = 2.8 GB
```

这个目录不是正式官方项目。它没有 Git 元数据，且包含基于 LibriTTS-R、
80-trial 和自定义评测子集的探索结果。

### 4.1 可以审慎复用

以下文件已经过校验或尺寸检查，但仍需在新目录重新记录哈希：

```text
data/n019/raw/test-clean.tar.gz
  size 346663984
  MD5 32fa31d27d2e1cad72775fee3f4849a9

data/n019/raw/libritts-train-clean-100.tar.gz
  size 7723686890
  MD5 4a8c202b78fe1bc0c47916a98f3a2ea8
```

这两个文件与 OpenSLR 官方 MD5 一致，可以硬链接或复制到新的
`data/n019_official`，禁止重新使用从 LibriTTS-R 导出的音频。

以下模型目录有正确的尺寸，但复用前必须重算 SHA256：

```text
models/n019/hubert/pytorch_model.bin  377569754 bytes
models/n019/wpro/model.safetensors   1266588504 bytes
```

W-NT 权重期望 SHA256：

```text
ad40a04ae6f0b46dbe6c7a6db71ff46f99775c59a0dccf61eb91f29216fbb2d4
```

已有 DTK 环境和一次成功的 HPC DCU smoke 可以作为环境基线：

```text
env: /public/home/a094f4d4/voice_projects/envs/n019
base: /public/home/a094f4d4/voice_projects/miniconda3/envs/py311
Python: 3.11.17
Job: 1009627
State: COMPLETED
Exit: 0:0
Elapsed: 39 s
DCU-hours: 0.010833
```

### 4.2 禁止复用于正式结果

```text
data/n019/libritts_r_clean100_wav/
data/n019/raw/libritts_r_clean100/
data/n019/processed/
data/n019/targets/
data/n019/manifests/libritts_r*
data/n019/eval_test*/
data/n019/eval_validation/
code/n019_repro/runs/
```

原因：

- `libritts_r_*` 是 LibriTTS-R，不是论文使用的原始 LibriTTS。
- 旧 `runs/` 使用旧数据和自定义子集，不是官方 Table 1。
- 旧 `ecapa/` 来自 SpeechBrain VoxCeleb，不是 VPC `asv_orig`。
- 旧 `asr/` 是否为 VPC release 的官方 `asr.zip` 尚未完成逐文件校验。
- 旧 vocoder checkpoint 的训练集、步数和评测协议都不能证明与论文一致。

保留旧目录作为失败溯源，不删除，也不覆盖。

## 5. 新远端目录

用户要求新项目在新文件夹中进行。正式远端根目录固定为：

```text
/public/home/a094f4d4/voice_projects/code/n019_official
/public/home/a094f4d4/voice_projects/data/n019_official
/public/home/a094f4d4/voice_projects/models/n019_official
/public/home/a094f4d4/voice_projects/logs/n019_official
/public/home/a094f4d4/voice_projects/runs/n019_official
```

AI 模型训练容器中对应：

```text
/mnt/data/voice_projects/code/n019_official
/mnt/data/voice_projects/data/n019_official
/mnt/data/voice_projects/models/n019_official
/mnt/data/voice_projects/logs/n019_official
/mnt/data/voice_projects/runs/n019_official
```

创建目录：

```bash
ssh scnet-a094f4d4

export N019_OFFICIAL_ROOT="$HOME/voice_projects/code/n019_official"
export N019_OFFICIAL_DATA="$HOME/voice_projects/data/n019_official"
export N019_OFFICIAL_MODELS="$HOME/voice_projects/models/n019_official"
export N019_OFFICIAL_LOGS="$HOME/voice_projects/logs/n019_official"
export N019_OFFICIAL_RUNS="$HOME/voice_projects/runs/n019_official"

mkdir -p \
  "$N019_OFFICIAL_ROOT"/{src,configs,hpc,tests,docs,vendor,compat} \
  "$N019_OFFICIAL_DATA"/{corpora,lmdb,manifests,vpc,processed} \
  "$N019_OFFICIAL_MODELS"/{hubert,wpro,vpc,mos} \
  "$N019_OFFICIAL_LOGS" \
  "$N019_OFFICIAL_RUNS"
```

## 6. 上传本地官方项目和少量资产

从 Windows PowerShell 执行，路径中有中文，必须保留引号：

```powershell
$local = "C:\Users\lihaopeng\Desktop\文件\水课\大三上\语音识别_N019_official"
$remote = "scnet-a094f4d4:/public/home/a094f4d4/voice_projects/code/n019_official"

scp -r "$local\configs" "$remote/"
scp -r "$local\docs" "$remote/"
scp -r "$local\scripts" "$remote/"
scp "$local\README.md" "$remote/"

scp "$local\vendor\vpc2024\data.zip" `
  "scnet-a094f4d4:/public/home/a094f4d4/voice_projects/data/n019_official/vpc/data.zip"

scp "$local\vendor\vpc2024\data_test_tools.zip" `
  "scnet-a094f4d4:/public/home/a094f4d4/voice_projects/data/n019_official/vpc/data_test_tools.zip"

scp "$local\vendor\vpc2024\asv_orig.zip" `
  "scnet-a094f4d4:/public/home/a094f4d4/voice_projects/models/n019_official/vpc/asv_orig.zip"
```

不要把本地 `vendor/vpc2024/data_unzipped` 或 `pre_model_unzipped` 当权威副本；
在远端重新解压并记录 SHA256。

可以把已经验证的旧源码作为初始实现骨架复制过来，但必须排除
`runs/`、`data/`、`assets/` 和缓存：

```bash
OLD="$HOME/voice_projects/code/n019_repro"
NEW="$HOME/voice_projects/code/n019_official"

if command -v rsync >/dev/null 2>&1; then
  rsync -a \
    --exclude 'runs/' \
    --exclude 'data/' \
    --exclude 'assets/' \
    --exclude '__pycache__/' \
    --exclude '*.pyc' \
    "$OLD/src/" "$NEW/src/"

  rsync -a \
    --exclude '__pycache__/' \
    --exclude '*.pyc' \
    "$OLD/compat/" "$NEW/compat/"

  rsync -a \
    --exclude '__pycache__/' \
    --exclude '*.pyc' \
    "$OLD/hpc/" "$NEW/hpc/"

  rsync -a \
    --exclude '__pycache__/' \
    --exclude '*.pyc' \
    "$OLD/tests/" "$NEW/tests/"

  rsync -a "$OLD/requirements-n019.txt" "$NEW/"
else
  echo "rsync missing; use cp -a and manually remove cache/run paths" >&2
  exit 1
fi
```

复制后必须逐文件审计，不要默认旧实现正确。旧代码只是起点，不是论文官方代码。

## 7. 激活环境

新项目创建自己的激活脚本：

```bash
cat > "$N019_OFFICIAL_ROOT/hpc/activate_n019_official.sh" <<'EOF'
#!/usr/bin/env bash

module load compiler/dtk/26.04

export N019_OFFICIAL_ROOT="$HOME/voice_projects/code/n019_official"
export N019_BASE_ENV="$HOME/voice_projects/miniconda3/envs/py311"
export N019_ENV="$HOME/voice_projects/envs/n019"
export N019_OFFICIAL_DATA="$HOME/voice_projects/data/n019_official"
export N019_OFFICIAL_MODELS="$HOME/voice_projects/models/n019_official"
export N019_OFFICIAL_LOGS="$HOME/voice_projects/logs/n019_official"
export N019_OFFICIAL_RUNS="$HOME/voice_projects/runs/n019_official"

if [[ ! -x "$N019_ENV/bin/python" ]]; then
  echo "Missing N019 env: $N019_ENV" >&2
  return 1 2>/dev/null || exit 1
fi

export PATH="$N019_ENV/bin:$PATH"
export LD_LIBRARY_PATH="$N019_ENV/lib:$N019_BASE_ENV/lib:${LD_LIBRARY_PATH:-}"
export CPATH="$N019_ENV/include:$N019_BASE_ENV/include:${CPATH:-}"
export LIBRARY_PATH="$N019_ENV/lib:$N019_BASE_ENV/lib:${LIBRARY_PATH:-}"
export PYTHONPATH="$N019_OFFICIAL_ROOT/compat:$N019_OFFICIAL_ROOT/src:${PYTHONPATH:-}"

export HF_HOME="$HOME/voice_projects/hf_cache/n019_official"
export HF_HUB_OFFLINE=1
export TRANSFORMERS_OFFLINE=1
export TOKENIZERS_PARALLELISM=false

mkdir -p \
  "$N019_OFFICIAL_DATA" \
  "$N019_OFFICIAL_MODELS" \
  "$N019_OFFICIAL_LOGS" \
  "$N019_OFFICIAL_RUNS" \
  "$HF_HOME"

echo "N019 official environment: $N019_ENV"
echo "N019_OFFICIAL_ROOT=$N019_OFFICIAL_ROOT"
EOF

chmod +x "$N019_OFFICIAL_ROOT/hpc/activate_n019_official.sh"
source "$N019_OFFICIAL_ROOT/hpc/activate_n019_official.sh"
```

不要安装公网 PyPI 的 `torch` 或 `torchaudio`。当前环境已经验证：

```text
Python 3.11.17
torch 2.9.0
HIP 6.3.26093
torchaudio 2.9.0+scnet-compat
Transformers 4.46.3
scikit-learn 1.9.1
librosa 0.10.2.post1
soundfile 0.14.0
NumPy 1.26.4
SciPy 1.17.1
huggingface_hub 0.36.2
```

登录节点验证：

```bash
source "$N019_OFFICIAL_ROOT/hpc/activate_n019_official.sh"

python - <<'PY'
import sys
import torch
import torchaudio
import transformers
import sklearn
import librosa
import soundfile
import numpy

print("python", sys.version.split()[0])
print("torch", torch.__version__)
print("hip", torch.version.hip)
print("cuda_available_login", torch.cuda.is_available())
print("torchaudio", torchaudio.__version__)
print("transformers", transformers.__version__)
print("sklearn", sklearn.__version__)
print("librosa", librosa.__version__)
print("soundfile", soundfile.__version__)
print("numpy", numpy.__version__)
PY
```

登录节点出现 `cuda_available_login=False` 正常，因为登录节点没有 DCU。

## 8. 官方资产清单

### 8.1 VPC2024 清单和模型

```text
VPC repo:
  tag v2
  commit 7c80e86d3a4d58b81a2f3bdc01a3508c37018be4

data.zip:
  10119867 bytes
  SHA256 60C71B3F2F8FF8D7A35237CDA7D92FB2F6F5F1F2CB5C89CB91FC511A699860F7

data_test_tools.zip:
  120506 bytes
  SHA256 6270EBA200A8986EEE96B7E4CA9828BE3000678073985C15273A5B34B3D4F304

asv_orig.zip:
  70464879 bytes
  SHA256 F0ABF60E569CB60A6F945A1A0A48E1A7D1AABE973F956DC3A872A3E686A7BF5E

asr.zip:
  752987942 bytes
```

验证：

```bash
cd "$N019_OFFICIAL_DATA/vpc"
sha256sum data.zip data_test_tools.zip
unzip -t data.zip
unzip -t data_test_tools.zip

cd "$N019_OFFICIAL_MODELS/vpc"
sha256sum asv_orig.zip
unzip -t asv_orig.zip
unzip -o asv_orig.zip -d .
```

下载官方 ASR：

```bash
cd "$N019_OFFICIAL_MODELS/vpc"
wget -c \
  https://github.com/Voice-Privacy-Challenge/Voice-Privacy-Challenge-2024/releases/download/pre_model.zip/asr.zip
test "$(stat -c%s asr.zip)" = "752987942"
unzip -t asr.zip
unzip -o asr.zip -d .
```

官方 `asv_orig` 的关键哈希：

```text
embedding_model.ckpt
  24946382 bytes
  D71E0DC0C2E4AE857DC57A59A8D9702655698ADEFE7B9D74A2B1B2DC5031EB8C

classifier.ckpt
  708216 bytes
  F5CB94BCA53A8D8780988D396C7B12330EB0B80D8896CFAD0354D6D277371552

normalizer.ckpt
  1153 bytes
  30F888CCA75B7781AF7C03EA4973C8CAA1F070D60EFB9D7500190FB425ABC5E4
```

### 8.2 HuBERT

```text
repo: facebook/hubert-base-ls960
revision: dba3bb02fda4248b6e082697eee756de8fe8aa8a
usage: hidden layer 6, approximately 50 Hz
```

下载：

```bash
source "$N019_OFFICIAL_ROOT/hpc/activate_n019_official.sh"
unset HF_HUB_OFFLINE TRANSFORMERS_OFFLINE
export HF_ENDPOINT=https://hf-mirror.com

python - <<'PY'
from pathlib import Path
from huggingface_hub import snapshot_download

snapshot_download(
    repo_id="facebook/hubert-base-ls960",
    revision="dba3bb02fda4248b6e082697eee756de8fe8aa8a",
    local_dir=str(Path.home() / "voice_projects/models/n019_official/hubert"),
)
PY
```

### 8.3 W-NT / W-PRO

```text
repo: Orange/Speaker-wavLM-pro
revision: 8451deb7b5019b9a99b1ed6a528dc75ba6b62b08
output: 250-dimensional L2-normalized embedding
```

下载：

```bash
source "$N019_OFFICIAL_ROOT/hpc/activate_n019_official.sh"
unset HF_HUB_OFFLINE TRANSFORMERS_OFFLINE
export HF_ENDPOINT=https://hf-mirror.com

python - <<'PY'
from pathlib import Path
from huggingface_hub import snapshot_download

snapshot_download(
    repo_id="Orange/Speaker-wavLM-pro",
    revision="8451deb7b5019b9a99b1ed6a528dc75ba6b62b08",
    local_dir=str(Path.home() / "voice_projects/models/n019_official/wpro"),
    allow_patterns=[
        "README.md",
        "LICENSE.txt",
        "config.json",
        "spk_embeddings.py",
        "model.safetensors",
    ],
)
PY

test "$(stat -c%s "$N019_OFFICIAL_MODELS/wpro/model.safetensors")" = "1266588504"
sha256sum "$N019_OFFICIAL_MODELS/wpro/model.safetensors"
```

如果文件只有 135 bytes 或开头是 `version https://git-lfs.github.com/spec/v1`，
那是 LFS pointer，不是模型权重。

### 8.4 MOS 工具

```bash
git clone https://github.com/sarulab-speech/UTMOS22.git \
  "$N019_OFFICIAL_ROOT/vendor/UTMOS22"
git -C "$N019_OFFICIAL_ROOT/vendor/UTMOS22" checkout \
  2d6d612cdf5bc610fde1a1b913c2d6c6fac8e063

git clone https://github.com/leto19/WhiSQA.git \
  "$N019_OFFICIAL_ROOT/vendor/WhiSQA"
git -C "$N019_OFFICIAL_ROOT/vendor/WhiSQA" checkout \
  0ad007e97093aa54c0c8cdac1af3e6ad6305af3f
```

WhiSQA 使用 Git LFS：

```bash
git -C "$N019_OFFICIAL_ROOT/vendor/WhiSQA" lfs pull \
  --include="checkpoints/single_head_model.pt"

test "$(stat -c%s \
  "$N019_OFFICIAL_ROOT/vendor/WhiSQA/checkpoints/single_head_model.pt")" \
  = "364031990"

sha256sum \
  "$N019_OFFICIAL_ROOT/vendor/WhiSQA/checkpoints/single_head_model.pt"
```

期望：

```text
2da43d59294c358bdd3f450d0aef5ce57ad20bed3beb34657ef3a795a4766810
```

UTMOS 的具体 strong-learner snapshot 论文没有给出。下载时必须记录实际
revision；最终报告只能写“官方 UTMOS22 代码 + 实际固定 snapshot”，不能写
“与原论文 snapshot 完全相同”。

## 9. 数据下载和校验

### 9.1 OpenSLR 官方 MD5

```text
LibriSpeech dev-clean:
  337926286 bytes
  42e2234ba48799c1f50f24a7926300a1

LibriSpeech test-clean:
  346663984 bytes
  32fa31d27d2e1cad72775fee3f4849a9

LibriSpeech train-clean-100:
  https://www.openslr.org/resources/12/train-clean-100.tar.gz
  2a93770f6d5c6c964bc36631d331a522

LibriSpeech train-clean-360:
  https://www.openslr.org/resources/12/train-clean-360.tar.gz
  c0e676e450a7ff2f54aeade5171606fa

LibriTTS train-clean-100:
  https://www.openslr.org/resources/60/train-clean-100.tar.gz
  4a8c202b78fe1bc0c47916a98f3a2ea8

LibriTTS train-other-500:
  https://www.openslr.org/resources/60/train-other-500.tar.gz
  7b181dd5ace343a5f38427999684aa6f
```

### 9.2 复用已验证文件

旧目录中的以下两个文件已经有正确 MD5：

```bash
OLD_DATA="$HOME/voice_projects/data/n019"
NEW_DATA="$HOME/voice_projects/data/n019_official"

mkdir -p "$NEW_DATA/corpora/librispeech" "$NEW_DATA/corpora/libritts"

ln -sfn \
  "$OLD_DATA/raw/test-clean.tar.gz" \
  "$NEW_DATA/corpora/librispeech/test-clean.tar.gz"

ln -sfn \
  "$OLD_DATA/raw/libritts-train-clean-100.tar.gz" \
  "$NEW_DATA/corpora/libritts/train-clean-100.tar.gz"

cd "$NEW_DATA/corpora/librispeech"
md5sum test-clean.tar.gz

cd "$NEW_DATA/corpora/libritts"
md5sum train-clean-100.tar.gz
```

使用符号链接是只读复用，不复制 8 GB 文件。最终报告仍要记录源路径和 MD5。

### 9.3 新下载

全部在 `scnet-a094f4d4` 登录节点执行。登录节点有外网，不占卡时。

```bash
cd "$N019_OFFICIAL_DATA/corpora/librispeech"
wget -c https://www.openslr.org/resources/12/dev-clean.tar.gz
wget -c https://www.openslr.org/resources/12/train-clean-100.tar.gz
wget -c https://www.openslr.org/resources/12/train-clean-360.tar.gz

cd "$N019_OFFICIAL_DATA/corpora/libritts"
wget -c https://www.openslr.org/resources/60/train-other-500.tar.gz
```

校验：

```bash
cd "$N019_OFFICIAL_DATA/corpora/librispeech"
md5sum dev-clean.tar.gz train-clean-100.tar.gz train-clean-360.tar.gz

cd "$N019_OFFICIAL_DATA/corpora/libritts"
md5sum train-clean-100.tar.gz train-other-500.tar.gz
```

解压前先用 `df -h "$HOME"` 确认剩余空间。建议每个 tar 包解压到自己的
临时目录，只把需要的元数据和音频保留到正式目录。

## 10. VPC2024 `libri_test` 重建

### 10.1 为什么可以重建

VPC2024 Evaluation Plan 明确写明 LibriSpeech development/evaluation sets
是 `dev-clean` / `test-clean` 的官方指定子集。`data.zip` 给出精确
`wav.scp`、`utt2spk`、`spk2gender`、`text` 和 `trials`。

当前 Table 1 所需 test 清单：

```text
libri_test_enrolls: 438 wav
libri_test_trials_f: 734 wav, 11744 trials
libri_test_trials_m: 762 wav, 9906 trials
unique wav IDs: 1934
trial pairs: 21650
```

### 10.2 materialize 规则

实现 `scripts/materialize_vpc2024.py`，必须：

1. 读取三个 test split 的 `wav.scp`，按 utterance ID 去重。
2. 只从 `test-clean/SPK/CHAPTER/UTT.flac` 找源文件。
3. 使用 FFmpeg 输出 16 kHz mono PCM16 WAV：

```bash
ffmpeg -nostdin -y -i input.flac \
  -ar 16000 -ac 1 -c:a pcm_s16le output.wav
```

4. 将 test 文件写到：

```text
data/libri_test/wav/UTT.wav
```

5. 将 dev 文件写到：

```text
data/libri_dev/wav/UTT/UTT.wav
```

6. 不修改原始 `trials`、`utt2spk`、`spk2gender` 或 `text`。
7. 记录每个 WAV 的 SHA256、源 FLAC 路径、源 tar MD5、FFmpeg 版本。
8. 对 `utt2dur` 做时长一致性检查，超过容器解码误差就失败。

千万不要把整个 `test-clean` 无筛选地当作 VPC `libri_test`。

### 10.3 验收

```bash
test "$(wc -l < "$N019_OFFICIAL_DATA/vpc/data/libri_test_enrolls/wav.scp")" = 438
test "$(wc -l < "$N019_OFFICIAL_DATA/vpc/data/libri_test_trials_f/wav.scp")" = 734
test "$(wc -l < "$N019_OFFICIAL_DATA/vpc/data/libri_test_trials_f/trials")" = 11744
test "$(wc -l < "$N019_OFFICIAL_DATA/vpc/data/libri_test_trials_m/wav.scp")" = 762
test "$(wc -l < "$N019_OFFICIAL_DATA/vpc/data/libri_test_trials_m/trials")" = 9906
```

还要确认所有 `wav.scp` 路径均可解析，且没有缺少文件。

数据层面只有在以下条件同时满足后才能写“已验证”：

- 原 LibriSpeech tar 的 MD5 正确；
- 1,934 个 test utterance ID 全部找到；
- 输出 WAV 全部可解码；
- 官方 `asv_orig` 在 original test 上的 EER/WER 量级与发布值一致；
- 记录完整的音频 SHA256 清单。

如果没有组织者 SFTP 包，不能声称与 `libri_test.tar.gz` 逐字节相同。可以
写“按官方 protocol 从公开 LibriSpeech 重建”，并在完成基线复算后写
“数据层面的信号和 trial 关系已验证”。

## 11. 论文 Table 1 原文

下表必须作为最终对表基准，不得自行修正：

| System | E-VPC I | E-VPC L | E-VPC S | W-NT I | W-NT L | W-NT S | WER | UTMOS | WhiSQA |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Original |  |  | 4.6 |  |  | 7.8 | 1.8 | 4.11 | 4.08 |
| B4 | 47.8 | 49.5 | 27.3 | 38.2 | 34.7 | 17.4 | 5.90 | 3.42 | 3.87 |
| B5 | 49.1 | 48.7 | 34.3 | 42.5 | 42.0 | 23.2 | 4.37 | 3.31 | 3.65 |
| kNN-VC | 42.1 | 43.8 | 11.0 | 19.0 | 17.6 | 5.9 | 2.77 | 3.80 | 4.05 |
| Private kNN-VC | 47.4 | 49.7 | 27.9 | 41.6 | 43.9 | 18.6 | 5.63 | 2.62 | 2.92 |
| DU-orig-nt | 47.6 | 47.2 | 35.9 | 33.1 | 33.6 | 22.6 | 4.48 | 3.59 | 3.70 |
| DU-orig-ecapa | 47.3 | 46.6 | 24.3 | 34.0 | 33.9 | 11.5 | 4.66 | 3.30 | 3.17 |
| DU-pred-nt | 47.2 | 47.9 | 34.8 | 39.9 | 42.3 | 24.6 | 7.41 | 3.63 | 3.69 |
| DU-pred-ecapa | 47.1 | 47.6 | 31.6 | 39.9 | 42.4 | 20.5 | 8.10 | 3.32 | 3.18 |
| DU-nt-nt | 48.2 | 48.1 | 34.1 | 40.5 | 42.5 | 23.7 | 7.73 | 3.63 | 3.69 |
| DU-ecapa-ecapa | 46.9 | 48.9 | 41.1 | 40.4 | 40.7 | 22.2 | 7.63 | 3.27 | 3.19 |
| DU-ecapa-nt | 47.6 | 47.9 | 36.6 | 40.3 | 43.0 | 24.1 | 7.59 | 3.60 | 3.70 |
| DU-nt-ecapa | 47.1 | 47.6 | 35.1 | 40.1 | 42.4 | 22.9 | 7.55 | 3.32 | 3.16 |

原文的 B4 行本身存在不一致：I/L/S 与该文引用 [7] 的 B4 不一定来自同一行，
S/W-NT 实际对应 [7] 的 B3。不要自行修正论文表格；最终对表时保留原值并
注明来源冲突。

优先完成：

```text
DU-orig-nt
DU-pred-nt
```

这两行足以检验论文最核心的非音色时长信息泄露机制。不要在核心消融尚未闭环
时先训练全部 8 个 DU 变体。

## 12. 算法实现规格

### 12.1 Unit

```text
16 kHz waveform
-> HuBERT-base-ls960, layer 6
-> k-means K=200
-> integer unit sequence
-> collapse consecutive duplicates
-> duration = run length in frames
```

HuBERT layer 6 来自 N019 引用的 SSL-SAS 实现，不是 N019 正文明确写出。
必须在 `docs/implementation_assumptions.md` 记录。

论文未给出：

- k-means 拟合语料的具体采样量；
- 迭代次数；
- random seed；
- 是否对特征做额外归一化。

建议固定使用 train-clean-100，保存 codebook、拟合参数和特征 SHA256。

### 12.2 Duration predictor

论文明确：

- 目标是每个 unit 的持续时间；
- 损失一是 unit-wise MSE；
- 损失二是相邻四个 unit 的总时长 MSE；
- 目标是目标说话人条件下的 duration；
- 推理先 round，再传播累计舍入余量。

论文没有给：

- 网络层数；
- hidden size；
- optimizer、lr、batch、epochs；
- 训练时 teacher forcing 或 scheduled sampling。

旧代码中 hidden 256、kernel 3、dropout 0.5 只是实现假设。不能从论文
反推为作者设置。

### 12.3 Unit HiFi-GAN

论文明确：

- 每个 vocoder 帧输入 `[unit_embedding, speaker_embedding]`；
- 两种 speaker 条件：ECAPA 192 维和 NT 250 维；
- vocoder 训练集是 LibriTTS train-clean-100；
- target embedding 来自 LibriTTS train-other-500；
- 论文用两张 RTX 4090。

论文没有给：

- unit embedding 维度；
- speaker projection 结构；
- generator 层宽；
- optimizer、batch、steps；
- target embedding 是单条 utterance 还是多人平均；
- target sampling seed；
- 是否排除源说话人作为目标。

第一阶段只训练 NT-conditioned vocoder。ECAPA-conditioned 是后续可选工作。

### 12.4 目标说话人

- 目标池必须来自原始 LibriTTS `train-other-500`。
- 不允许复用旧 `libritts_r_other500_targets.jsonl`。
- 固定 source -> target 映射 seed。
- 所有系统共享同一映射，便于配对比较。
- 每条评测 utterance 独立选目标，不做 speaker-level 固定映射。
- 先采用单条目标 utterance embedding；池化版本作为单独消融。
- 映射、目标 utterance ID、目标 embedding 模型 revision 全部落盘。

## 13. 环境与 smoke 阶段

### 13.1 零卡时检查

```bash
source "$N019_OFFICIAL_ROOT/hpc/activate_n019_official.sh"
cd "$N019_OFFICIAL_ROOT"

python -m compileall -q src tests
python -m unittest discover -s tests -v
```

CPU probe 必须验证：

- W-PRO 输出 `[1, 250]`；
- HuBERT layer 6 输出约为 `[1, T, 768]`；
- K-means label 全部在 `[0, 199]`;
- 连续重复合并保持总帧数不变；
- 空音频、短音频、单声道、双声道和超长音频行为明确。

### 13.2 新目录 DCU smoke

沿用旧 smoke 脚本前，先把路径改为 `n019_official`。计划示例：

```text
Account: a094f4d4
Mode: HPC / Slurm
Partition: hx1hdnormal
DCU: 1
CPU: 4
Host RAM: 14G
Wall time: 00:05:00
Worst-case: 0.0833 DCU-hour
Output: $HOME/voice_projects/runs/n019_official/smoke_<JOBID>
Stop: import failure, OOM, non-finite loss/gradient, no progress in 5 min
```

Slurm 模板：

```bash
#!/bin/bash
#SBATCH --job-name=n019_official_smoke
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --gres=dcu:1
#SBATCH --mem=14G
#SBATCH --time=00:05:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail
source "$HOME/voice_projects/code/n019_official/hpc/activate_n019_official.sh"
cd "$N019_OFFICIAL_ROOT"

echo "user=$(id -un) host=$(hostname) date=$(date -Is)"
echo "HIP_VISIBLE_DEVICES=${HIP_VISIBLE_DEVICES:-unset}"
hy-smi || true
python -u -m n019.dcu_smoke \
  --out "$N019_OFFICIAL_RUNS/smoke_${SLURM_JOB_ID}"
```

提交前使用 `sbatch --test-only` 检查。当前用户已授权直接执行 SCNet 操作，
不需要逐次等待确认，但资源计划和台账必须先写入。

## 14. 训练阶段

### 14.1 数据和超参选择边界

- Duration predictor：LibriSpeech train-clean-100。
- Unit HiFi-GAN：LibriTTS train-clean-100。
- 目标 embedding：LibriTTS train-other-500。
- S-attacker：匿名化 LibriSpeech train-clean-360。
- 不能因为下载方便改用 train-clean-360 训练 vocoder。
- 不能用 LibriTTS-R 的任何音频。
- 不能用 test 集选超参数。

### 14.2 先 pilot，再正式训练

AI 模型训练模式首选 `a094f4d4`。每次任务：

- 1 DCU；
- 自动容错关闭；
- 单次 2 到 4 小时；
- 单卡 forward/backward/checkpoint/resume 先通过；
- DDP 验证前不申请 2 卡；
- 容器内路径必须使用 `/mnt/data/...`；
- `HF_HUB_OFFLINE=1`、`TRANSFORMERS_OFFLINE=1`。

建议预算，不是已测卡时：

| 任务 | 卡数 | 单次墙钟 | 最坏卡时 | 通过条件 |
|---|---:|---:|---:|---|
| duration pilot | 1 | 30 min | 0.5 | loss 有限且下降 |
| duration main | 1 | 2 h | 2 | 总时长 MAE 下降，非恒定输出 |
| vocoder pilot | 1 | 30 min | 0.5 | 频谱重建、checkpoint 写入 |
| vocoder main | 1 | 6-10 h | 10 | 重建稳定、WER 不崩溃 |
| 第二条件 vocoder | 1 | 6-10 h | 10 | 仅在核心结果完成后 |

任何“最坏卡时”按 `DCU 数 × 墙钟小时` 计算。先查实时余额，再确认
`余额 - 运行中作业最坏卡时 - 本次最坏卡时 > 0`。

### 14.3 AI 模型训练启动脚本

模板：

```bash
#!/bin/bash
set -euo pipefail

ROOT=/mnt/data/voice_projects/code/n019_official
ENV=/mnt/data/voice_projects/envs/n019

test -x "$ENV/bin/python"
test -d "$ROOT"
source "$ENV/bin/activate"

export PYTHONPATH="$ROOT/compat:$ROOT/src:${PYTHONPATH:-}"
export N019_OFFICIAL_ROOT="$ROOT"
export N019_OFFICIAL_DATA=/mnt/data/voice_projects/data/n019_official
export N019_OFFICIAL_MODELS=/mnt/data/voice_projects/models/n019_official
export N019_OFFICIAL_RUNS=/mnt/data/voice_projects/runs/n019_official
export HF_HOME=/mnt/data/voice_projects/hf_cache/n019_official
export HF_HUB_OFFLINE=1
export TRANSFORMERS_OFFLINE=1
export TOKENIZERS_PARALLELISM=false

mkdir -p "$N019_OFFICIAL_RUNS"
cd "$ROOT"

echo "user=$(id -un) host=$(hostname) date=$(date -Is)"
echo "pwd=$PWD"
echo "HIP_VISIBLE_DEVICES=${HIP_VISIBLE_DEVICES:-unset}"
hy-smi || true

python -u -m n019.duration \
  --records "$N019_OFFICIAL_DATA/processed/units/librispeech_train_clean_100/unit_records.jsonl" \
  --embeddings "$N019_OFFICIAL_DATA/processed/embeddings/librispeech_train_clean_100_nt/nt_speaker_embeddings.npz" \
  --speaker-dim 250 \
  --embedding-kind nt \
  --device cuda \
  --out "$N019_OFFICIAL_RUNS/duration_nt_$(date +%Y%m%d_%H%M%S)"
```

上面的入口调用当前 `src/n019/duration.py`。默认训练全部 clean-100 记录，
不会为了 dev 悄悄删除 5% 或 10% 数据。需要 pilot 监控时才显式设置
`--validation-fraction`。默认 Adam、30 epochs、batch 32、lr 3e-4 和
window weight 0.5 来自 DISSC 参考实现，不是 N019 论文公开数字。

对应 vocoder 入口是：

```bash
python -u -m n019.vocoder \
  --records "$N019_OFFICIAL_DATA/processed/units/libritts_train_clean_100/unit_records.jsonl" \
  --embeddings "$N019_OFFICIAL_DATA/processed/embeddings/libritts_train_clean_100_nt/nt_speaker_embeddings.npz" \
  --speaker-dim 250 \
  --out "$N019_OFFICIAL_RUNS/vocoder_nt_$(date +%Y%m%d_%H%M%S)" \
  --max-hours 4 \
  --device cuda \
  --bf16
```

默认值是 reference-style 的 400,000 steps、AdamW、lr 2e-4、batch 32
和 28-frame/8,960-sample 片段；论文正文没有给这些数字。`--max-hours 4`
只用于分段试跑，正式训练按资源计划调整。

## 15. 官方评测

### 15.1 评测前验收

- `data/libri_test/wav` 全部存在；
- 438 / 734 / 762 / 11,744 / 9,906 行数一致；
- 官方 `asv_orig` 与 `asr` 解压、加载成功；
- VPC `run_evaluation.py --help` 成功；
- W-NT 使用 250 维 exact checkpoint；
- UTMOS/WhiSQA 版本和 checkpoint 已记录；
- 所有系统使用同一 target mapping 和同一 trial list；
- I/L/S 定义与配置一致。

### 15.2 原始语音基线

先跑：

```bash
cd /path/to/Voice-Privacy-Challenge-2024
python run_evaluation.py \
  --config /path/to/n019_official/configs/eval_paper_test_only_pre.yaml \
  --overwrite '{"anon_data_suffix": "_n019_official"}' \
  --force_compute True
```

这一个基线必须先证明：

- E-VPC female/male EER 与官方发布值量级一致；
- WER 使用 `libri_test` trials；
- trial 数没有悄悄减少。

如果原始语音基线就对不上，停止，不训练。

### 15.3 匿名系统评测

Pre attack：

```bash
python run_evaluation.py \
  --config /path/to/n019_official/configs/eval_paper_test_only_pre.yaml \
  --overwrite '{"anon_data_suffix": "_n019_official"}' \
  --force_compute True
```

Post / semi-informed：

```bash
python run_evaluation.py \
  --config /path/to/n019_official/configs/eval_paper_test_only_post.yaml \
  --overwrite '{"anon_data_suffix": "_n019_official"}' \
  --force_compute True
```

Post 配置必须包含：

```text
train_data_name: train-clean-360_n019_official
lr: 0.01
epochs: 10
batch_size: 256
retrain: true
```

S attack 必须匿名化完整 train-clean-360 后重训 ASV。不能用原模型直接冒充
semi-informed。

### 15.4 EER 口径

Table 1 主表使用：

```text
libri_test_trials_f
libri_test_trials_m
```

分别计算 female/male EER，再按论文一位小数报告。最终正式结果要同时保存：

- 两个子集各自 EER；
- 两个 EER 的算术平均；
- 合并 score 后统一计算的 EER；
- 两者差异。若差异会影响结论，必须说明。

### 15.5 WER

- 只使用 `libri_test` trial 音频；
- 使用 VPC2024 官方 `asr.zip`；
- 同一 checkpoint、同一 batch、同一文本归一化用于所有系统；
- 保存每个 utterance 的 hypothesis、reference 和错误统计。

### 15.6 MOS

- UTMOS22 和 WhiSQA 都在同一批最终音频上运行；
- 记录实际 checkpoint revision；
- 论文没有给 UTMOS snapshot；
- WhiSQA 默认单头只是一种官方默认重建选择，论文未明确写 single/multi。
- MOS 只能在 EER/WER 主流程稳定后跑。

## 16. 结果目录契约

每个正式 run 必须包含：

```text
runs/n019_official/<timestamp>_<arm>/
  config.yaml
  command.txt
  environment.txt
  git_commit.txt
  stdout.log
  stderr.log
  data_manifest.json
  model_manifest.json
  target_mapping.jsonl
  metrics.json
  metrics.csv
  scores/
  embeddings/
  checkpoint_sha256.txt
```

必须记录：

- SCNet 账号和模式；
- Slurm JobID 或模型训练任务 ID；
- 开始、结束、墙钟、卡数、卡时；
- GPU/DCU 型号和可见设备；
- Python、torch、HIP、Transformers 版本；
- 数据 tar 的 MD5；
- VPC `data.zip` 和 `asv_orig.zip` 的 SHA256；
- VPC repo commit；
- HuBERT/W-PRO/ASR/MOS 权重 SHA256；
- K-means codebook SHA256；
- target mapping seed 和文件 SHA256；
- 所有随机种子；
- 失败阶段和 error tail。

禁止：

- 删除失败 run；
- 用 `best.pt` 覆盖历史 checkpoint；
- 只报最好 seed；
- 把 exploratory 结果复制到 official 表中；
- 用 dev 结果补 Table 1 test 空格；
- 把 ECAPA 结果命名为 W-NT；
- 把 LibriTTS-R 结果写成 LibriTTS。

## 17. 卡时与失败止损

每次 HPC 提交和 AI 任务记录：

```text
日期：
账号：
模式：
JobID / 任务ID：
任务：
DCU 数：
墙钟：
卡时：
输出：
状态：
失败原因：
```

停止条件：

- 10 到 15 分钟无新日志；
- 首次 forward 即 OOM；
- loss 为 NaN 或 Inf；
- throughput 低于 pilot 的 50%；
- checkpoint 目录长时间不增长；
- 自动重启；
- 存储不足；
- 余额不足以覆盖最坏卡时。

取消作业也计费。不要用“提交看看，失败再取消”代替 smoke。

## 18. 常见故障

### `ModuleNotFoundError: hyperpyyaml`

使用官方 VPC 环境或在当前 venv 中补 `hyperpyyaml`。不要因此覆盖 DTK
torch。

### `import torch` 失败

不要安装公网 PyPI torch。先确认 `module load compiler/dtk/26.04`，再检查
基础环境 `py311`、venv 和 shared libraries。必要时复用已验证的 DTK
torch 修复流程。

### W-PRO `model.safetensors` 很小

下载到了 LFS pointer。使用 `huggingface_hub.snapshot_download` 或
`git lfs pull`，校验 1,266,588,504 bytes 和 SHA256。

### 容器内找不到 `/public/home/...`

AI 模型训练容器里使用 `/mnt/data/...`。Slurm 里使用
`/public/home/...`。

### 计算节点没有网络

登录节点先下载好全部资产。Slurm 和 AI 容器均设置 offline HF 环境变量。

### `sbatch` 拒绝 account/partition

先看 `scontrol ping`、`sinfo`、`sbatch --test-only` 和 `sacct` 卡时。
不要先改 `.slurm` 脚本。

### RPC / RSA warning

`client_global_hostkeys_prove_confirm ... bad signature for RSA key 0`
可能是客户端警告；以 SSH 退出码和远端输出为准。

### 旧代码没有 git 元数据

不要声称可追溯。把正式新项目纳入用户指定的私有版本管理，或至少为每个
run 保存 source tree 的 `SHA256SUMS`。

## 19. 完成标准

第一阶段完成：

- 新目录 `n019_official` 建立；
- 环境 import 全部通过；
- 数据、模型、官方评测代码均校验；
- `libri_test` 1,934 个唯一 wav 全部重建并可解码；
- original 语音基线通过；
- CPU probe 和 DCU smoke 日志新鲜、可复算。

核心科学完成：

- `DU-orig-nt` 与 `DU-pred-nt` 使用同一 NT Unit HiFi-GAN；
- 训练集是原始 LibriTTS clean-100；
- target 池是原始 LibriTTS other-500；
- `libri_test` I/L/S EER、WER 全部跑完；
- 观察 `DU-pred-nt - DU-orig-nt` 的 W-NT I/L 提升是否接近论文的
  `+6.8` / `+8.7` 个绝对点；
- WER 和 MOS 没有明显协议错误；
- 所有数字来自 official run。

完整 Table 1 完成：

- 12 个系统全部完成；
- B4 来源冲突已注明；
- ECAPA/NT 两种 conditioning 都完成；
- I/L/S、WER、UTMOS、WhiSQA 都有原始分数；
- 论文值、复现值、绝对差、相对差、容差判定齐备；
- 任何未复现项都明确写原因。

## 20. 直接给下游 AI 的启动指令

## 20.1 DCU 节点健康状态（2026-11-07）

- `10.6.15.32` 的 DCU 当前不可用：同一 D7 镜像在该节点上能报告
  `cuda_available=True`、`device_name=BW`，但 `torch.randn` 后第一次
  `torch.cuda.synchronize()` 永不返回。Job `2118998908457992193`
  和 `2119017477546799106` 均复现。
- `10.6.15.3`、`10.6.15.37` 和 `10.6.15.39` 已验证正常：
  `2118996023452123137` 完成 2 句 WhiSQA；
  `2119018005205766145` 在 `.39` 完成完整 1,934 句 WhiSQA，
  用时 5 分 49 秒，均值 `2.750191857889988`，与 CPU 全量只差
  `2.769e-6`；`2119019823947862018` 在 `.3` 完成 2 句 UTMOS；
  `2119021746961141762` 在 `.3` 完成 8 句 WER，结果与 CPU WER
  smoke 完全一致（`2.0833333333%`）。
- 因此不要再把评测任务默认切 CPU。GPU 脚本必须先用 300 秒
  `timeout --signal=KILL` 包围 tiny matmul；若落在 `.32`，任务应快速
  失败后重试，而不是拖满外层墙钟。
- AI 控制台的 113 组没有可选节点字段；调度到 `.32` 时，可在该节点
  先占一个短任务，再提交正式任务，使正式任务落到其他节点。该办法仅作
  节点避让，不可用来掩盖真实代码错误。

## 20.2 质量差距与训练代码状态（2026-11-07）

- ext step 102000 的完整 1,934 句结果为 WER `6.7547514411%`、
  UTMOS `2.6142479994`、WhiSQA `2.7501946269`；相对论文仍差
  `-1.01575` 和 `-0.93981`。
- d7 旧训练代码的 `feature_matching_loss` 只有 1x，本地修正版才是
  2x。step 4k/76k/102k 全部是在 1x 代码下训练出来的；不能把它们当作
  2x 配方结果。修正版已同步到 d7，训练前仍要再次核对 SHA256
  `6d77f4033e75519d2c503cd284913505fd2aff2a06db90a2abb4a295b9cd9ccb`。
- duration 已做过原时长/预测时长 A/B，影响只有约 0.02–0.05 MOS，
  不是首要修复方向。
- 训练 embedding 是 clean-100 的 speaker-level W-PRO；推理 target
  embedding 是 other-500 中 target utterance 的 utterance-level
  W-PRO。论文只说 target speaker embedding，未公开 pooling 规则。
  先做小样本配对 A/B，不要直接把 utterance 结果改名或替换。
- 下一步优先级：2x feature-matching 重新训练 NT vocoder；建立不与
  train-clean-100 训练集重叠的 MOS 验证集用于选模；再做 target
  embedding pooling A/B。所有正式评测优先在健康 GPU 节点运行。

```text
你接手 N019《Joint Timbral and Non-Timbral Speaker Anonymisation》的
官方复现。先读本地
C:\Users\lihaopeng\Desktop\文件\水课\大三上\语音识别_N019_official\docs\HANDOFF_FOR_NEXT_AI.md，
以及同目录的 OFFICIAL_ASSET_MANIFEST.md、PAPER_ALIGNMENT_CHECKLIST.md、
PUBLIC_DATA_FALLBACK.md 和 source_lock.json。

只使用 SCNet 的 a094f4d3、a094f4d4、a094f4d5；主账号 a094f4d4。
两种模式都允许：HPC/Slurm 和人工智能/模型训练。禁止连接实验室 A6000，
禁止使用 /mnt/data/lihaopeng。不要打印、复制或提交任何密钥、密码。

新项目必须放在
/public/home/a094f4d4/voice_projects/code/n019_official，
不能继续扩展旧的 n019_repro，也不能把旧 runs 当作官方结果。
旧 n019_repro 只可作为源码和环境参考，且其中 LibriTTS-R、80-trial 和
自定义评测产物全部禁止进入正式结果。

先做零卡时工作：新目录、环境复用、官方资产校验、test-clean 精确重建、
CPU probe。然后提交 1-DCU 5 分钟 smoke。之后优先完成 DU-orig-nt 与
DU-pred-nt，而不是全部 Table 1。Duration predictor 用 LibriSpeech
train-clean-100；Unit HiFi-GAN 用原始 LibriTTS train-clean-100；目标池
用 LibriTTS train-other-500。评测只用 VPC2024 libri_test。

每次消耗卡时的任务先打印：账号、模式、任务名、partition、DCU 数、
CPU/RAM、墙钟、最坏卡时、预计卡时、输入输出、停止条件。用户已授权直接
执行 SCNet 操作，但台账和资源计划必须真实。保存原始 score、checkpoint、
日志、哈希和失败记录。不要把探索性结果写成论文复现。
```

## 0.0.31 `DU-pred-nt` I/L 完成，S 四片匿名化开始

- 当前 checkpoint 不变：soup2 `84/88/92/96k = 40/30/20/10` + shrink0.1。
- 同批 1,934 WAV/VPC 的 I/L：E-VPC I `48.0285`，L `47.7540`；
  W-NT I `39.1678579152`，L `39.7293478251`。论文分别为
  `47.2/47.9/39.9/42.3`。W-NT L 是最大隐私残差。
- I/L 结果目录：
  `/public/home/a094f4d6/voice_projects/runs/n019_official/privacy/du_pred_nt_soup2_w40_shrink01_20261110_il_r3`。
- 全部 1,158 个 target speaker 的 shrink0.1 embedding 已生成：
  `target_speaker_mean32_all1158_shrink01_20261110.npz`，SHA256
  `28ffbaec9516cd8f5abbc752b40315b9fe958f7d37dc6b6f4a58bcd28c2540a7`。
- 当前 d6 HPC `1086660` 是 LS360 shard 0，1 DCU / 6 h。完成后依次跑
  shard 1/2/3，禁止并行重复或跳过核验。每片约 5.2 h，使用同一
  checkpoint、target map、duration predictor 和 shrink embedding。
- 四片完成后在 d6 用 `merge_ls360_anonymisation_shards.py` 合并并导出
  `train-clean-360_n019_soup2_w40_shrink01_20261110`，必须核验 104,014。

## 0.0.32 d6 长训已停，162k 三项复核完成

- d6 长训 Job `1076707` 已停止，`CANCELLED by 580461`，墙钟
  `15:31:12`；最后日志 step `164,280`，稳定 `last.pt` step `164,000`，
  SHA256 `e7a6ef1003dfc0caebe0f356b751340c93588e1d53867f068ca5f44feb911bb0`。
  不得重提该训练。d6 当前 `1087347` 是 S 隐私评测，不是长训。
- d6 160k/162k/164k 中 162k 的 UTMOS 最高；d7 Job
  `2120196966200995842` 复用其已有 100 句 WAV 补齐三项指标：

| checkpoint | UTMOS | WhiSQA | WER % |
|---|---:|---:|---:|
| soup2 baseline | **3.5127723885** | **3.4313990980** | **6.1215166743** |
| d6 step 162k | 3.3362299037 | 3.3230666950 | 6.4869803563 |

  d6 候选在 UTMOS、WhiSQA 和 WER 上均退化，`selection.json` 选择
  baseline。结果目录
  `/public/home/a094f4d7/voice_projects/runs/n019_official/vocoder_selection_d6_final_160_164_20261110`，
  `selection.json` SHA256
  `490fffa17381f55a18c6863cdd5a3c73270343f6500bcc60e45f8feaaa68a778`。
- 本次 d7 AI 任务 1 DCU、15 CPU / 59 GB，实际墙钟
  `13m30s = 0.225` 卡时；提交前 d7 余额 `0.654444444`。

## 0.0.33 E-VPC S 完成，W-NT S 训练中

- d6 HPC `1087347` 正常完成，实际 `1h33m30s = 1.5583` 卡时。
  E-VPC S：female `30.114%`、male `29.371%`、mean `29.7425%`；
  论文 `34.8%`，差 `-5.0575 pp`。
- `s_metrics.json`：
  `/public/home/a094f4d6/voice_projects/runs/n019_official/privacy/du_pred_nt_soup2_w40_shrink01_s_eval/s_metrics.json`，
  SHA256
  `be265b317001fe6c199016224bce5e48ce3cc9ac312e6005e401f02c06f3bb97`。
- d6 W-NT S Job `1087348` 已由依赖自动启动，使用匿名
  train-clean-360 suffix `_n019_soup2_w40_shrink01_20261110`，
  20 epochs、batch 8、W-PRO 初始化、内部最多 10 h。
  输出
  `/public/home/a094f4d6/voice_projects/runs/n019_official/privacy/wnt_s_soup2_w40_shrink01`。
  后续 Job `1087349` 是 S 评测，等待训练成功。
- 等 S 完成后使用新增的
  `scripts/merge_wnt_attack_summaries.py` 合并 I/L/S，
  再用 `scripts/assemble_du_pred_nt_final_remote.sh` 和
  `configs/du_pred_nt_final_metrics_20261111.json` 生成九项完整
  `paper_metrics.json` / `paper_comparison.json/md`。
- 03:03 W-NT S 第 1 epoch 完成：13,001 steps、epoch loss `13.0033`、
  `0.8363 h`，已导出完整 `model/`；epoch 2 继续正常，
  step `14,460` 时 loss `12.8808`。训练 accuracy 仍为 `0.0`，
  需要继续观察，不能提前判定失败。
- `evaluate_wnt_remote.sh` 已加入 S 模型文件完整性门禁，d6/d7
  同步并通过 `bash -n`；真实 I/L summary 的合并测试也已通过。
- 当前 8/9 项部分结果已写入
  `privacy/du_pred_nt_soup2_w40_shrink01_partial8_20261111`，
  仅缺 W-NT S。不要重算已有的 E-VPC I/L/S、W-NT I/L、
  WER、UTMOS 或 WhiSQA。
- 原 W-NT S 全 WavLM fine-tune `1087348` 已取消并替换：
  epoch 1 和 step 19k 的 accuracy 均为 `0.0`，保存模型输出
  embedding 余弦接近 1，属于表示塌缩。Job `1087349` 同时取消。
- 新 recipe 冻结 WavLM，只训练 W-PRO top layers + AAM head；
  smoke `1088364` 通过，6,500 steps 后 loss `12.5623`、
  accuracy 非零且 embedding 未塌缩。
- 正式 Job `1088443` 正在 d6 HPC 运行：1 DCU、16 CPU / 60 GB、
  外层 5 h、内部 4.5 h、20 epochs、batch 16。评测 Job
  `1088444` 为 `afterok:1088443`。输出
  `privacy/wnt_s_soup2_w40_shrink01_freeze_r1`。
  不要重提旧 `1087348/1087349`。
- r1 `1088443` 在 `f11r1n20` 启动后 1m29s 发生 `SIGSEGV`，
  未进入训练 step；不得重复提交 r1。r2 `1088459` 已排除该节点，
  落到 `f11r2n02`，当前正常训练；评测 Job 为 `1088460`。
  正式源目录改为
  `privacy/wnt_s_soup2_w40_shrink01_freeze_r2`。

