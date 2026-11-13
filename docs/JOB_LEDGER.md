# N019 作业与卡时台账

更新日期：2026-11-06  
账号：`a094f4d4`（主账号）  
模式：HPC/Slurm `hx1hdnormal`

## 2026-11-13 00:47 fullmean1160 的 20-epoch E-VPC S 收敛对照

- 已提交 d7 HPC Job `1103529`（`n019_fullmean_adj20_s`）：
  `hx1hdnormal`、1 DCU、16 CPU / 60 GB、3 h；
  预计 `2.8`、最坏 `3.0` 卡时。提交前估算余额 `3.117744 h`。
- 复用 `_n019_fullmean1160_20261112` 的 104,014 WAV/VPC，
  不重新匿名化。相对官方 eval config 仅修改
  `lr 0.01 -> 0.001`、`epochs 10 -> 20`；其余训练参数保持。
- 输出
  `runs/n019_official/privacy/fullmean1160_du_pred_nt_s_20261112/s_eval_adj20_lr1e3`。
  该任务是对同一作者既往 S 训练收敛问题的诊断，不是正式论文配置。
- 配置 SHA256
  `ec69c22504d8d8eb6f3f57e2547b8b9ae0176c5a3c68d1c1de427781b115e859`；
  wrapper SHA256
  `7f58b322a9f04b202dfd528cf723bdae2297f85ccd1a6edd1dd13cfd5821b59c`。
  提交状态 `PENDING/Priority`；不得重复提交。
- Job `1103529` 已完成：`00:48:45-03:33:22`，
  `02:44:37 = 2.7436` 卡时，`ExitCode=0:0`。
  20-epoch 最终 train loss `7.98`、valid error `89.7%`，但
  E-VPC S 为 female `29.929%`、male `32.071%`、mean
  **`31.000%`**，比官方 10-epoch fullmean `31.200%` 低
  `0.200 pp`。`s_metrics.json` SHA256
  `940017ed664ec67f586997d72c73491755e4d85e178513abcf02628ee59ab214`。
  该结果排除 S 训练收敛差异，不替换正式指标。
- 按 50 h HPC 额度，d7 估算剩余
  `3.117744 - 2.743611 = 0.374133 h`；不再安排 d7 长任务。

## 2026-11-13 00:43 avg88_92 checkpoint 对照完成，S 未改善

- d7 HPC Job `1102767`（`n019_avg8892_fullmean_s`）完成：
  `2026-11-12T21:37:06-2026-11-13T00:39:36`，
  `03:02:30 = 3.0417` 卡时，`ExitCode=0:0`。
  test 1,934、LS360 104,014、VPC 104,014 全部通过验证。
- E-VPC S：female `28.823%`、male `30.568%`、mean
  **`29.6955%`**；相对 soup2 fullmean `31.200%` 回退
  `-1.5045 pp`，相对正式 soup2 shrink0.1 `29.7425%` 回退
  `-0.0470 pp`。`s_metrics.json` SHA256
  `7165b66520da6780922a53032c0f67c726feaf8572a0399db83144c54060917c`。
- 结论：checkpoint/soup 不是剩余 S 差距的主因。此结果不替换正式
  指标，不再重提旧的 `1102715` 或重复本次 checkpoint 对照。
- 提交前 HPC 估算余额 `6.159444 h`；本次实际 `3.0417 h`，
  估算剩余 `3.117744 h`。

## 2026-11-12 21:25 source S 完成并提交 avg88_92 checkpoint 对照

- d7 HPC Job `1101644`（`n019_source_s_diag`）完成：
  `17:57:21-21:07:49`，墙钟 `03:10:28 = 3.1744` 卡时，
  `ExitCode=0:0`。1,934 test、104,014 LS360、104,014 VPC
  完整，test/LS360 verification 全部通过。
- source-reconstruction E-VPC S 为 female/male/mean
  `0.0/0.0/0.0%`；原始 enrollment + source-conditioned trial
  `OA=42.1695%`。source attacker 训练最终 valid speaker error rate
  `0.128%`。这证明当前 vocoder/unit 在给定源 embedding 时几乎完整
  保留身份，随机 target 条件下仍存在的残余身份才是 S 的主要问题。
- `s_metrics.json` SHA256
  `b04a16aae2d178c9b192df677769a72aa7ef92806a6a0bfd048f31c9cd3c5d51`。
- 已提交 d7 HPC Job `1102767`（`n019_avg8892_fullmean_s`）：
  `hx1hdnormal`、1 DCU、16 CPU / 60 GB、4 h；
  预计 `3.2`、最坏 `4.0` 卡时；提交前按 50 h HPC 额度估算
  已用 `43.840556 h`、余额 `6.159444 h`。
  输入为 `generator_avg_88_92_effnorm.pt`
  SHA256 `fafe5982588bea492dd761f1c2d51cc925474503a4f158cf1680667b2286ded8`、
  fullmean1160、paper random full-pool target maps、duration pred。
  输出 `runs/n019_official/privacy/avg8892_fullmean_s_20261112`。
  实际于 `21:37:06` 在 `f11r4n01` 启动，后完成；
  结果见上方 2026-11-13 小节；不得重复提交。
- 首次 Job `1102715` 在 `21:26:38-21:27:08` 运行 30 秒后
  `FAILED 1:0`；原因仅为 test map 的 941 keys 与 full 1,160-key
  NPZ 严格 key 集合不匹配。没有 WAV 或指标输出。修复为 test 使用
  `test_941.npz` SHA256
  `983f9d85f08783842d31755b2a0189904c06ea0e1159b388cafcd3f53dbdb14e`，
  LS360 使用 full `nt_speaker_embeddings.npz`；重试 Job `1102767`
  于 21:36 提交。不要重提 `1102715`。

## 2026-11-12 16:54 fullmean1160 S 完成；source-reconstruction 诊断启动

- 修复长 TMPDIR 后，d7 HPC Job `1100544`
  （`n019_fullmean1160_s_nw10st`）正常完成：
  `15:18:29-16:50:51`，墙钟 `01:32:22 = 1.5394` 卡时，
  `ExitCode=0:0`，节点 `f11r3n14`。官方 `num_workers=10` 和
  10-epoch ECAPA retrain 未改。
- fullmean1160/no-shrink E-VPC S：
  female `32.113%`、male `30.287%`、mean **`31.200%`**。
  正式 shrink0.1 为 `29.7425%`，因此提升 `+1.4575 pp`；
  论文 `34.8%` 仍高 `3.6 pp`。
  `s_metrics.json` SHA256
  `c7106d956870874c5d1ff67c99f5ad839a9cca141528b0034cb22cf034d6e06e`，
  `results_anon.txt` SHA256
  `6657510d16d93f6f015f01993f9d6d7ed86fc9251dab24af682758a0cd9371d0`。
- fullmean1160 test 质量已经测过：WER `6.152617%`、
  UTMOS `3.440497`、WhiSQA `3.429525`。WER 优于正式，
  但 UTMOS/WhiSQA 分别回归 `-0.084870/-0.066234`，不替换正式模型。
- 零卡时 source-reconstruction maps 已生成：
  test 1,934 行/40 speakers，SHA256
  `7cde8b3eb7f6a894d47a519f5dc283a233699aebebecbc3350acfe8ecc4f1cd7`；
  LS360 104,014 行/921 speakers，SHA256
  `98519aa3d632706cc604d54796799b0c18160a3a4c5f57d5752ef52ad96f8f35`。
- d7 HPC Job `1101189`（`n019_source_nt_diag`）实际运行
  `16:57:59-17:00:44 = 2m45s`，`ExitCode=1:0`。test 的
  40-speaker source embeddings 已完成；LS360 阶段因 d7 没有原始
  FLAC corpus（manifest 指向的 train-clean-360 路径不存在）失败。
- d5 HPC 的 `hx1hdnormal` test-only 报
  `Invalid account or account/partition combination`，因此尝试 d5
  人工智能/模型训练。Job `2120806846710960129` 在 2 秒内失败，
  原因是 d5 代码树缺少 `scripts/gpu_tiny_matmul_watchdog.sh`；
  未进入 watchdog、模型加载或音频读取。提交前 d5 余额
  `4.216111111`，该失败无有效卡时产出。
- 复核确认 d7 登录节点可直接读取 d5 的原始 LS360 FLAC，且 d7
  已有 `librispeech_train_clean_360_d5read_20261111.jsonl`。
  因此改用 d7 HPC Job `1101373`（`n019_source_nt_ls360`）：
  `hx1hdnormal`、1 DCU、16 CPU / 60 GB、1 h，预计 0.3、
  最坏 1.0 卡时；只提取 921 个 source-speaker W-PRO means，
  每 speaker 至多 32 条，不训练模型。
- `1101373` 只用于 source-reconstruction E-VPC S 诊断，不是论文
  候选。完成后必须验证 921 keys、250-D、finite、unit norm 和
  SHA256，再进入同一 vocoder/duration/S 协议。
- d7 HPC `1101373` 已完成：
  `17:22:32-17:51:02 = 28m30s = 0.475` 卡时，
  `ExitCode=0:0`。LS360 921-speaker source mean NPZ SHA256
  `fdd6d6837dacd40c520d60fa18a1957943a6ab6341a812051828dbbf0793e660`；
  test 40-speaker source mean NPZ SHA256
  `902abc3fb8c8b12d13d54380d597777ec1d3311972fe8856c86acb15f5ec76d6`。
  250-D、finite、unit-norm 和 map/embedding key 精确匹配均已核验。
- 已提交 d7 HPC Job `1101644`（`n019_source_s_diag`）：
  `hx1hdnormal`、1 DCU、16 CPU / 60 GB、4 h，预计 3.2、
  最坏 4.0 卡时；`17:57:21` 在 `f11r3n11` 开始。它复用正式
  soup2、`duration=pred` 和官方 S 重训，只把输入条件改为
  source-speaker mean，执行 1,934 test + 104,014 LS360。
  输出 `runs/n019_official/source_reconstruction_diag_20261112/s_eval`。
  这是隐私残差诊断，不是论文方法或正式候选。

## 2026-11-12 15:17 fullmean1160 S-only：修复长 TMPDIR 的 shm 错误

- 调度器复核发现交接摘要中的 `1100489` 没有 `squeue/sacct/scontrol`
  记录，因此它不是一次真实提交；不得把它写成失败任务。
- d7 HPC 首次 num_workers=10 Job `1100497`
  （`n019_fullmean1160_s_nw10`）于 `14:59:35` 在 `f11r2n13`
  开始，`15:14:25` 主动停止，实际 `14:50`。它完成了 VPC 数据准备，
  但在官方 DataLoader 启用 workers 时再次出现
  `torch_shm_manager ... Invalid argument`，没有训练 step 或指标。
- 规格：`hx1hdnormal`、1 DCU、16 CPU / 60 GB、2 h，
  预计 1.5、最坏 2.0 卡时；`--exclude=f11r1n01`。
- 复用 d7 已完成并验证的 1,934 test 与 104,014 LS360 WAV/VPC，
  不重新匿名化。输入 suffix `_n019_fullmean1160_20261112`。
  输出
  `/public/home/a094f4d7/voice_projects/runs/n019_official/privacy/fullmean1160_du_pred_nt_s_20261112/s_eval_nw10`。
- 根因不是坏节点：旧 TMPDIR 是 run 内 NFS 路径，长度 114，
  超过 `torch_shm_manager` 支持的共享内存名长度；`1098744` 在
  另一节点使用同一长度级路径时也报相同错误。
- 修复版 Job `1100544`（`n019_fullmean1160_s_nw10st`）于
  `15:17:22` 提交，初始状态 `PENDING/Priority`。TMPDIR 改为
  `/dev/shm/n019_s_${SLURM_JOB_ID}`，输出改到 `s_eval_nw10st`，
  并排除 `f11r1n01,f11r2n13`。
- 使用官方 `configs/eval_paper_test_only_post.yaml`
  （`num_workers=10`）；旧 `1100375` 的 `num_workers=0` 仅约
  `1.1 it/s`，1 epoch 估计超过 20 分钟，已在 14:53:53 主动停止，
  墙钟 `19:12`。本次不改 ECAPA 10 epochs、lr `0.01`、batch `256`、
  speaker selection 或 921-class retraining 口径。
- 提交前 d7 `share RawUsage=1872833`。远端修复版 wrapper SHA256
  `0c7e04930bbe1224de33f4e591e096ba2e4c452974ceca69e705602a649e352c`。
  停止条件：完成并写出六行 `results_anon.txt` 与 `s_metrics.json`；
  或出现 shm/OOM/非有限 loss/节点故障；或达到 2 h 墙钟。

## 2026-11-12 14:10 fullmean1160 S：d7 shm 失败，d6 nw0 重跑

- d7 HPC `1098744` 在 `f11r1n01` 超时，实际
  `09:22:28-13:22:53 = 4:00:25`。LS360 匿名化已完成并通过验证：
  104,014 行/WAV、VPC 104,014 行，`wav_bytes=41,940,252,136`，
  `anon.jsonl` SHA256
  `2980f12e1e93ea97244b440df63244c6e54638c5b78fb7e1adb34f883a1f5abf`。
- 失败点是 S 阶段官方 ECAPA DataLoader 的
  `torch_shm_manager ... Invalid argument`，之后进程无进展直到墙钟；
  没有 `results_anon.txt` 或 `s_metrics.json`。
- 新增官方配置副本
  `configs/eval_paper_test_only_post_nw0.yaml`，仅把 DataLoader
  workers 从 10 改为 0；epochs、lr、batch、selection、speaker 数
  均保持官方值。
- d6 AI 快速重试 `2120761326156005378`、`2120761815004876802`、
  `2120762690334326785` 依次暴露容器 `HOME`、缺失
  `SLURM_JOB_ID`、缺失 `TMPDIR`，均未进入训练或生成音频。
- d6 AI Job `2120762893529796609`
  （`n019_fm1160_s_nw0_r3_20261112_141722`）通过 watchdog 后，
  实测约 `441/26054` 句/78 秒（`5.6 utt/s`）。四片顺序执行会
  超出 4 h 且在 S 重训前超时，已在 14:26 主动停止。
  1 DCU、15 CPU / 59 GB、4 h，预计 3.0、最坏 4.0 卡时；
  提交前 d6 余额 `4.9927777776`。输入/输出均在 d6 home；
  输出
  `/public/home/a094f4d6/voice_projects/runs/n019_official/privacy/fullmean1160_du_pred_nt_s_20261112/s_eval`。
- 替代 d7 HPC Job `1100375`（`n019_fullmean1160_s_nw0`）已提交：
  1 DCU、16 CPU / 60 GB、2 h，预计 1.5、最坏 2.0 卡时；
  只复用 d7 已完成的 104,014 条 WAV/VPC 重跑官方 ECAPA S，
  使用 `num_workers=0`，其余科学参数不变。输出
  `/public/home/a094f4d7/voice_projects/runs/n019_official/privacy/fullmean1160_du_pred_nt_s_20261112/s_eval_nw0`；
  pending TimeLimit 从 2.5 h 收紧到 2 h 后，调度器给出
  `StartTime=2026-11-12 14:34:29`、节点 `f11r3n12`。

## 2026-11-12 08:40 回到论文随机 target：补齐 full speaker mean

- 用户否决强制异性别 target；此前 `1098250/1098251/1098566` 只作为
  privacy-enhanced diagnostic 保留，不进入正式 `DU-pred-nt` 复现。
- 零卡时审计确认原始 LibriTTS `train-other-500` 为 205,044 条、
  1,160 speakers。已有 full speaker mean 覆盖 843 speakers /
  168,023 utterances，当前 test/LS360 speaker map 覆盖 1,158
  speakers，缺 315 speakers / 37,015 utterances。另有 `147`、
  `7683` 未进入旧 map，共 6 条 utterance，待补。
- d5/d6 的 `hx1hdnormal + 1 DCU` test-only 均报
  `Invalid account or account/partition combination`；d7 可用。
- 已提交 d7 HPC Job `1098620`（`n019_tspkfull315_20261112`）：
  1 DCU、16 CPU / 60 GB、2 h，预计 0.6、最坏 2.0 卡时；节点
  `f11r1n15`。任务先跑 300 秒 SIGKILL tiny-matmul watchdog，再对
  37,015 条 target utterance 提取 full speaker mean。输入 manifest
  SHA256 `eeb097cfdcd99a2f7e4f9676dcb851392d01b23b48519f8ff7a8837583793438`；
  输出
  `/public/home/a094f4d7/voice_projects/data/n019_official/processed/embeddings/target_speaker_fullmean315_hpc_20261112`。
- 已提交 `afterok:1098620` 依赖 Job `1098659`
  （`n019_fullmean1160_prep`）：1 DCU、16 CPU / 60 GB、1 h，
  预计 0.15、最坏 1.0 卡时。补 speaker `147/7683` 的 6 条
  utterance，合并为 1,160-key full speaker mean，并生成 941-key
  test subset。
- 全 pool maps 已生成：test 1,934 行 / 941 speakers，SHA256
  `0215470094e36b98d6dd4b082f1e0edbf839711f236b2d9ee84c5c35dd2a96f3`；
  LS360 104,014 行 / 1,160 speakers，SHA256
  `53058fdbede1bd46ee1fe8013e46c535af58787e5c90182cfa355f351198e6b8`。
- 已提交依赖链：
  - `1098670`（`n019_fullmean1160_eval`，`afterok:1098659`）：
    1 DCU、16 CPU / 60 GB、2 h，预计 0.25、最坏 2.0 卡时；
    完整测试集匿名化和 WER/UTMOS/WhiSQA。
  - `1098672`（`n019_fullmean1160_s`，`afterok:1098670`）：
    1 DCU、16 CPU / 60 GB、4 h，预计 3.0、最坏 4.0 卡时；
    完整 LS360 匿名化和官方 E-VPC S 重训。
- fullmean1160 prep `1098659` 完成，墙钟 47 秒；full NPZ
  SHA256 `576e72f7...c4bcb4`，1,160 keys；test subset 941 keys，
  SHA256 `983f9d85...bdb14e`。全部 250-D、finite、unit-norm。
- fullmean315 Job `1098620` 实际
  `08:40:00–09:06:28 = 26m28s`，完成 37,015 条；315-key
  NPZ SHA256 `5e414c996e24a3a688bd01f703b1855b0c03edde758deee8410cdfeb5dec06a6`。
- `1098670` 因 `data/n019_official/anonymised/libri_test` 父目录不可写，
  运行 21 秒失败，未产生 WAV/指标；`1098672` 被依赖取消。已把测试
  匿名化输出移到 `runs/n019_official/privacy/fullmean1160_du_pred_nt_20261112`，
  重提 eval `1098697` 和其 `afterok` S 任务 `1098699`。不要重提
  `1098670/1098672`。
- `1098697` 在 2m23s 内完成并核验 1,934 WAV/VPC、1,496 行 ASR
  视图；随后因 root-managed `runs/n019_official/eval` 父目录不可写，
  在创建新结果目录时失败，`1098699` 被依赖取消。没有 WER/MOS
  输出。音频/VPC 保留，不重算；eval 输出改到候选 privacy run，
  重提 `1098721`（metrics-only）和 `1098723`（S，`afterok`）。
- `1098721` 在 watchdog 启动前因计算节点默认 `/tmp` 满而
  `No space left on device` 秒失败，`1098723` 被依赖取消。两个
  wrapper 已在 source 后设置候选 run 内的 `TMPDIR`，重提
  `1098741`（metrics-only）和 `1098744`（S，`afterok`）。
- `1098741` 完成，实际 `09:15:51–09:22:28 = 6m37s`：
  WER `6.1526168598%`、UTMOS `3.4404968176`、
  WhiSQA `3.4295246571`；计数 `1496/1934/1934`。相对当前正式
  shrink0.1，WER `-0.071343 pp`，UTMOS/WhiSQA
  `-0.084870/-0.066234`。单看质量不满足替换门槛。
  `quality_metrics.json` SHA256
  `a723ee9da979d1d5bec4fcc8ee9f4a2c0db9081e9cf1e9f5b89850034ea3c5d9`。
- fullmean1160 的官方 S Job `1098744` 已由 dependency 于
  09:22:28 在 `f11r1n01` 启动；必须等完整 LS360 和 ECAPA 重训后
  才能报告 E-VPC S。
- 配置文件：`configs/scnet_d7_target_fullmean315_20261112.json`。
  提交后已回写真实 JobID 并保持 `submit:false`，不得重复提交。

## 2026-11-12 04:45 DU-nt-nt S 仍不足，异性别采样全量链路运行中

- d7 HPC Job `1097898` 完成 `DU-nt-nt` 的官方 10-epoch E-VPC S
  重训，墙钟 `01:32:59 = 1.5497` 卡时。female `29.563%`、
  male `30.515%`、mean `30.039%`，仅比正式 `29.7425%` 高
  `+0.2965 pp`，比论文 `34.8%` 低 `4.761 pp`。
  `s_metrics.json` SHA256
  `2d6daa038fa2471ed1932c59ff276951ef430303d5b23f742a8c4a77e1668673`。
- 新增 opposite-gender target map：现有 seed20261102 map 的异性别比例
  只有 `48.7%`，新 map 在原始 other-500 target speaker 池内强制
  异性别并保持 target-speaker uniform。test/LS360 map SHA256 分别为
  `96c3bb8f...6c205f493`、`8956628f...dfd6376b`。
- 异性别 full-test 质量 Job `1098238` 完成：WER `6.292449%`、
  UTMOS `3.458855`、WhiSQA `3.491496`。相对正式
  `6.223960% / 3.525367 / 3.495759`，WER `+0.068489 pp`、
  UTMOS `-0.066512`、WhiSQA `-0.004263`。
- 同 suffix W-NT L Job `1098241` 完成：female `41.424432%`、
  male `40.781495%`、mean `41.102964%`；相对正式
  `39.729348%` 提高 `+1.373616 pp`。`summary.json` SHA256
  `0f2aa853...62ad5cf`。
- 已提交 d7 HPC 全量依赖链：anonymisation `1098250`（1 DCU、
  16 CPU / 60 GB、3 h，预计 1.5、最坏 3.0 卡时）→ E-VPC S
  `1098251`（`afterok:1098250`、3 h，预计 1.5、最坏 3.0 卡时）。
  输出 `privacy/opposite_gender_du_nt_nt_20261112`。配置
  `configs/scnet_d7_opposite_gender_full_s_20261112.json` 已回写。
- `1098250` 已完成并核验：104,014 WAV/VPC，`wav_bytes=42536030056`；
  `anon.jsonl` SHA256 `41a8e361...a37981`，`run_meta.json`
  `bcfebe03...26b6c`，`verification.json` `b73e4776...e4648c`，
  VPC `wav.scp` `07a6f390...92bb01`。依赖 Job `1098251` 已自动启动
  官方 10-epoch S 重训。
- `1098251` 完成，墙钟 `01:27:36 = 1.46` 卡时；异性别 E-VPC S
  female `40.874%`、male `43.207%`、mean `42.0405%`。相对正式
  `29.7425%` 提高 `+12.2980 pp`，相对论文 `34.8%` 高
  `+7.2405 pp`，相对随机 target 的 DU-nt-nt `30.039%` 高
  `+12.0015 pp`。`s_metrics.json` SHA256
  `27b1d55e...eb3e09`，`results_anon.txt` SHA256
  `48cb9cab...d5819c5`。它是 privacy-enhanced calibration，不能
  冒充论文随机 target 设置。
- 已提交 `1098557` 补 E-VPC I/L 和 W-NT I/L，d7 HPC、1 DCU、
  16 CPU / 60 GB、1 h，预计 0.2、最坏 1.0 卡时；输出
  `privacy/opposite_gender_du_nt_nt_20261112/privacy_il`。
- `1098557` 因 W-NT I 的原始 enroll `data/...` 相对路径快速失败；
  增加兼容链接后 `1098566` 完成，墙钟 `8m09s`：
  E-VPC I/L `47.192/49.0715`，W-NT I/L `39.391970/41.102964`。
  `privacy_il_metrics.json` SHA256
  `6dcb7525...418776`，`evpc_metrics.json`
  `9b30c123...9b21ba`，`wnt/summary.json`
  `fbb39e13...eaac24`。
- 失败追溯：`1098216` 因 map/embedding key 集合不精确相等在预检失败；
  `1098220` 因 anonymised 父目录不可写在预检后失败；`1098226`
  完整生成并核验 1,934 WAV/VPC，仅 eval 父目录不可写而失败。
  `1098238` 复用该音频完成质量指标。不要重跑这些 Job。

## 2026-11-11 22:30 utterance-target S 完成，E-VPC S 仍仅 30.9685%

- d6 Job `1095367`（`n019_uttvec_s_d6r2`）完成完整 104,014 句
  LS360 匿名化和官方 10-epoch ECAPA S 重训；评分完成后 MIOpen
  析构崩溃，平台退出码 `6:0`，但原始评分文件完整。实际墙钟
  `3:07:07`，规格 1 DCU、16 CPU / 60 GB、4 h。
- CPU 重建 E-VPC S：female `30.109%`、male `31.828%`、mean
  `30.9685%`。相对正式 `29.7425%` 提升 `+1.2260 pp`，距论文
  `34.8%` 仍差 `3.8315 pp`。`s_metrics.json` SHA256
  `7db0eff5036bc65c174f083a1bd9d6dbcf988961b2286adb692e2203368d05c2`；
  `results_anon.txt` SHA256
  `a46156d21b891d2dee7b72315f3b031c256a440373e7a85eb1355da8dd6b1a87`。
- 结论：utterance-level target 不是 E-VPC S 修复方向，而且完整
  1,934 句 UTMOS/WhiSQA 已回归 `-0.171911/-0.165424`，不得替换正式模型。
  下一实验转测论文的 `DU-nt-nt`，不做长训练，只做 target-conditioned
  时长/声码器推理和官方 S 重训。
- d7 的 4 句 GPU smoke Job `1097145` 已完成，墙钟 `54s`，4/4 WAV。
  正式 Job `1097354` 已提交：d6 HPC、1 DCU、16 CPU / 60 GB、5 h，
  预计 3.2、最坏 5.0 卡时；执行 1,934 句 test 和 104,014 句 LS360
  的 `DU-nt-nt` 推理，再用同一 suffix 重训官方 ECAPA S。输出
  `runs/n019_official/privacy/du_nt_nt_s_20261111`。配置
  `configs/scnet_d6_du_nt_nt_s_20261112.json` 已设 `submit:false`，
  不得重复提交。d7 `1097191` 在 pending 时取消；d6 `1097330`
  因 staging 长文件名缺失在 1 秒失败；`1097336` 因 test map 的
  954 个 target speakers 与全量 1,158-key embedding 不相等，在
  31 秒预检失败。三次均未生成音频或消耗有效卡时。已生成 954-key
  test 子集，SHA256
  `75f445857cbb02c245937ba5b2f4a355e43b4715486a42fc10e0f470df5f8f52`。
- Job `1097354` 正式运行正常：1,934 句 test 在 `99.7s` 完成并通过
  全部文件/计数/VPC 校验，`anon.jsonl` SHA256
  `f8f10024298fe5731d7b83b736e3db7b716aab23cf11c192ff8118002eb9688d`。
  LS360 第一片实测约 18–19 句/s，预计四片约 1.5 h；运行中默认安静。

## 2026-11-11 19:20 E-VPC S shrink 排除与 utterance target 实验

- d6 Job `1094009` 完成 speaker-sampled `shrink0.05` 的完整 LS360 E-VPC S
  评分：female `31.387%`、male `30.070%`、mean `30.7285%`。相对
  speaker-sampled shrink0.1 的 `30.6420%` 只有 `+0.0865 pp`，说明
  shrink 不是 E-VPC S 主因。评分后 MIOpen 析构崩溃，`results_anon.txt`
  完整，CPU 重建 `s_metrics.json` SHA256
  `d0003d98229a1e44efff6034043f104ebb0eacb684edfccedb20d16f8050aa3a`。
  依赖它的 shrink0 Job `1094023` 因父任务非零退出自动取消。
- 新增 speaker-uniform、单 utterance target 采样脚本
  `scripts/make_speaker_uniform_utterance_target_map.py` 和 embedding
  子集脚本 `scripts/subset_target_embeddings.py`。生成并校验：
  - test target map `c139d91f69d85e7c7b325d5658a3dfe548363c1689972abfe4adc831d8dd24d7`；
  - LS360 target map `4a94aed9d96053312ec8142777a0cd9304696c5a9e01dbdb8a851bdcead19252`；
  - test embedding subset `20e0954447831b8c00ca0556e768f05e887b032365062c864e6423de32163415`；
  - LS360 embedding subset `fdf52668d8a4f955ce2029ea24f0cbdc007dda615f6485691504326db9b594e4`。
- d7 Job `1094954` 完成完整 1,934 句 test screen：d7 HPC、1 DCU、
  16 CPU / 60 GB，外层 2 h；实际 `18:34:31–18:41:48 = 7m17s`。结果：
  WER `6.186861%`、UTMOS `3.353455`、WhiSQA `3.330335`。相对正式
  mean32/shrink0.1，WER `-0.037099 pp`、UTMOS `-0.171911`、WhiSQA
  `-0.165424`。`quality_metrics.json` SHA256
  `9a64c58641864a86dcc6ebc7c460d9276fdd5e4d9d8fc01631e9d3a9024f7aa3`。
- 同一 test suffix 的 W-NT L Job `1095473` 完成：d7 HPC、1 DCU、
  16 CPU / 60 GB、45 min；实际 `3m18s`。female `41.058850%`、male
  `40.977447%`、mean `41.018149%`，相对正式 `39.729348%` 提高
  `+1.288801 pp`，仍低于论文 `42.3%`。`summary.json` SHA256
  `58f8a79761351f9e2a56cf104e5061e529b4f459a528109674d7706cbe6111aa`。
- 失败追溯：`1094914` 写共享 root-owned anonymised 目录，33 s 失败；
  `1095005` 缺 LS360 shard 脚本；`1095051`、`1095097` 使用 d7 旧版
  `anonymize_ls360_remote.sh`，实际读取旧 target map；`1095304` 缺 d6
  soup checkpoint；均已做最小修复。`1095259` 在 d7 慢节点约 4.6 句/s，
  预计超过 4 h，运行 5m21s 后主动取消。以上均无有效指标。
- 当前 d6 Job `1095367`：d6 HPC、1 DCU、16 CPU / 60 GB、4 h，预计 3.0、
  最坏 4.0 卡时；用完整 104,014 句 utterance-target 数据重训官方
  ECAPA S。节点实测约 19.5 句/s，预计匿名化约 1.5 h。输出
  `runs/n019_official/utterance_target_maps_20261111/full_s_r2`。
  提交前 17:54 AI 余额 d6 `4.9927777776`、d7 `0.429444444`；任务走 HPC，
  不消耗该 AI 余额，d8/d9 未使用。

## 2026-11-11 15:05 E-VPC S 与 W-NT L 残差修复诊断

- 论文写法支持 target **speaker** 均匀采样。旧 test map 实际按 target
  utterance 采样，导致 target speaker 频次不均。改用 speaker-sampled
  map 后，E-VPC S 从正式 `29.7425%` 提高到 `30.6420%`，仍比论文
  `34.8%` 低 `4.1580 pp`，说明采样只是次要原因。
- d6 Job `1091285` 已完成 full LS360 anonymisation、10-epoch ECAPA
  重训和六行 EER；评分结束后 postprocess 因文件系统异常退出。
  `results_anon.txt` 完整，CPU 重建的 `s_metrics.json` SHA256
  `307f9366f7f46fe582de81f1c23ef84d51b3a70048d6ef91287eb992e158198a`。
  旧 shrink0.05 依赖 Job `1092021` 被自动取消，未耗卡时。
- 在已有 1,934 WAV/VPC 上完成无训练 target-shrink 交叉：

| 配置 | E-VPC I | E-VPC L | W-NT I | W-NT L |
|---|---:|---:|---:|---:|
| 正式 shrink0.1 | 48.0285 | 47.7540 | 39.1679 | 39.7293 |
| speaker map + shrink0.05 | 46.8930 | 47.6450 | 38.9625 | 41.0403 |
| speaker map + shrink0 | 47.3850 | 47.6340 | 39.5045 | 41.2432 |
| 论文 | 47.2 | 47.9 | 39.9 | 42.3 |

- E-VPC I/L 的 job `1092299`、`1092397` 均正常完成。W-NT L 复用
  `wntl_shrink_screen_20261111`；W-NT I shrink0 的 Job `1092352`
  已完成评分，但汇总器因只请求 I、缺少 L 键而退出，I 数值有效。
- 完整 1,934 句质量：shrink0.05 为 WER `6.283888%`、UTMOS
  `3.480695`、WhiSQA `3.474208`，相对正式为
  `+0.059928 pp/-0.044671/-0.021550`，满足预声明质量门槛。shrink0
  为 `6.252497% / 3.455499 / 3.444798`，UTMOS/WhiSQA 回归
  `-0.069868/-0.050961`，略超双 MOS 门槛。
- W-NT L seed 稳定性 Job `1092779` 完成，实际 13m14s：
  seed `20261103/04/05` 的 shrink0 W-NT L 为
  `40.0028/40.1629/40.1546`，均值 `40.1068`、总体标准差
  `0.0736`。同 seed03 下 shrink0.1 为 `39.9580`，shrink0 仅
  `+0.0447 pp`；因此 seed20261102 的 `41.2432` 是偏有利的
  target-map 样本，不能把 shrink0 的单项提升写成稳定修复。
  seed03 shrink0.1 对照 Job `1092919` 正常完成，实际 5m18s。
- 后段 checkpoint 控制也没有达到论文值。Job `1093016` 完成
  100k/102k/106k，W-NT L 为
  `40.1966/40.1175/40.9905`，随后因 112k 文件名不是
  `generator_step...` 退出；Job `1093169` 用显式 symlink 完成
  112k/134k/136k，结果为 `40.0386/40.6948/40.5316`。均未达到
  42.3，且不随训练步数单调改善。
- 已完成失败修复：E-VPC launcher 现在复制 job-local `asv_orig`，
  避免 root-owned score 目录；包装脚本允许显式 `N019_WNT_ATTACKS`；
  shrink0 eval-view 已补齐。Job `1092174/1092261/1092323` 的失败
  分别为 wrapper 环境串值、缺 config、缺 eval view，均已追溯。
- 当前 d6 队列：`1092783` 为 shrink0.05 full-LS360 E-VPC S，
  `1092786` 为 `afterok:1092783` 的 shrink0 E-VPC S；各 1 DCU、
  16 CPU / 60 GB、4 h，预计 3.0、最坏 4.0 卡时。d7 `1092779`
  用 shrink0 在 target-map seeds `20261103/04/05` 上做 W-NT L
  稳定性 screen，25 min，预计 0.2、最坏 0.417 卡时。
- 新增台账配置 `configs/scnet_privacy_gap_followup_20261111.json`。
  未使用 d8/d9。

## 2026-11-11 07:01 W-NT S 稳定重训与 DU-pred-nt 九项完成

- `freeze_r2` 的原 AAM `0.2/30` 分支在 epoch 7 因非有限 loss 失败；
  用 epoch06 直接评估得到的 `42.9055%` 被判定为攻击模型未正常收敛，
  不进入最终结果。
- 新 smoke `1089060` 在 `f11r1n05` SIGSEGV，未产生训练 step；
  排除 `f11r1n05,f11r1n20` 后，Job `1089071` 在 `f11r1n03`
  完成 4 epochs / 26,000 steps。参数：d6 HPC、1 DCU、16 CPU /
  60 GB、外层 1.5 h；实际 `06:12:29–06:57:56`，墙钟
  `45m27s = 0.7575` 卡时。AAM `margin=0.05, scale=10`，
  WavLM 冻结，top-layer/head lr `1e-4/1e-3`，batch 16。
- 训练结果：epoch 4 loss `5.4820056`、accuracy `0.0655096`；
  `last.pt` SHA256
  `11a006c2f724a655ca3053aaf5ee410359e8a034c0dd633f9b7c8d5535994eaf`，
  `model.safetensors` SHA256
  `cbd6762b757a12260868009c07c31993b9f75391b2b800233caff23eae338e0e`。
- W-NT S 评估 Job `1089232`：d6 HPC、1 DCU、16 CPU / 60 GB、
  1 h；实际 `06:58:04–07:01:16`，墙钟 `3m12s = 0.0533` 卡时。
  结果为 female `23.880922%`、male `25.166792%`、mean
  **`24.523857%`**，论文值 `24.6%`，差 `-0.076143 pp`。
  `summary.json` SHA256
  `cd9cb2f2031554e1dde0960731e841b77f0b223a9197cb0958ef47f43f2ff132`。
- 最终汇总 `privacy/du_pred_nt_soup2_w40_shrink01_final_r2_20261111`
  生成 9/9 项，`paper_metrics.json` 无 missing；WER=1,496、
  UTMOS/WhiSQA=1,934。最终 SHA256：
  - `wnt_summary_ils.json`: `12198f340f981440198616201d7bfcacb616af8e89352befa6ad22fef17b3126`
  - `paper_metrics.json`: `5ade74a7d1486b258b80062638d1fe0c39c2f5b8b6005cc3828e31d328fd07d6`
  - `paper_comparison.json`: `9e51fafca0a245dcbecd406c66eea9ae7f4c4c0255c4f5af82a12984493b5010`
  - `paper_comparison.md`: `3b14b8fc689206b0cb25ff33d56728231c0aef904ca16f9ccfb34f5014638d37`

## 2026-11-11 05:41 d6 长训保持停止，164k 三项补测完成

- d6 长训 `1076707` 已停止且 d6 队列为空，不再提交训练。
- 新任务 `1088937`：d7、HPC/Slurm `hx1hdnormal`、1 DCU、
  16 CPU / 60 GB、外层 40 分钟。只复用 164k 已有 WAV/UTMOS，
  补 WhiSQA/WER；预计 0.05、最坏 0.667，实际
  `05:38:51–05:40:31` 墙钟 `1m40s ≈ 0.028` 卡时，状态
  `COMPLETED`。
- 固定 40-speaker dev-100 结果：

| checkpoint | UTMOS | WhiSQA | WER % |
|---|---:|---:|---:|
| soup2 baseline | 3.5127723885 | 3.4313990980 | 6.1215166743 |
| d6 step 162k | 3.3362299037 | 3.3230666950 | 6.4869803563 |
| d6 step 164k | 3.2473053122 | 3.3189123020 | 6.6697121974 |

  164k 相对 baseline：UTMOS `-0.2654670763`、WhiSQA
  `-0.1124867961`、WER `+0.5481955231 pp`，不通过 gate。
  `selection.json` SHA256
  `f6043028387b28c437195f200683ac29c304ba0baf2300de7bb625f8f532afa4`。

## 2026-11-10 22:02 停止 d6 并测试最后 checkpoint

- d6 HPC Job `1076707` 于 21:52:12 停止，状态
  `CANCELLED+`，实际墙钟 `15:31:12`。最后日志 step
  `164,280`，持久 `last.pt` step `164,000`，SHA256
  `e7a6ef1003dfc0caebe0f356b751340c93588e1d53867f068ca5f44feb911bb0`。
- d7 HPC Job `1085907` 使用当前正式 soup+shrink0.1 基线，
  在正确 40-speaker dev-100 上评 d6 最后三个 snapshot：
  baseline UTMOS `3.5127723885`；
  160k `3.2387674308`；
  162k `3.3362299037`；
  164k `3.2473053122`。
  三者均早拒绝，正式 checkpoint 不变。
- 输出
  `runs/n019_official/vocoder_selection_d6_final_160_164_20261110`。

## 2026-11-10 21:50 当前策略与总体进度归档

- 新增
  `docs/N019_CURRENT_STRATEGY_AND_RESULTS_20261110.md`，记录当前正式
  checkpoint soup + shrink0.1 策略、历代结果、论文对齐差异、
  EER/Table 1 未完成项和下一步优先级。
- 当前正式质量结果仍为：WER `6.2239598196%`、UTMOS
  `3.5253666541`、WhiSQA `3.4957589100`。
- 不将当前状态报告为完整论文复现；E-VPC/W-NT、S 条件、
  其他 DU 系统和第三方基线仍未闭环。

## 2026-11-10 21:36 soup+shrink 完整结果

- d7 HPC Job `1085663`
  （`n019_eval_soup2_w40_shrink01_r4`）完成，墙钟 5m31s。
  完整 1,934 句结果：WER `6.2239598196%`（1,496）、
  UTMOS `3.5253666541`（1,934）、WhiSQA
  `3.4957589100`（1,934）。
- 相对旧正式 `avg88_92+mean32`，UTMOS
  `+0.1255740367`、WhiSQA `+0.0972059087`、WER
  `+0.0028537184 pp`。checkpoint SHA256
  `ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6`；
  `quality_metrics.json` SHA256
  `542cd9fc44e1c03237150078cb67ddb4e7edfe41775f53c77acb7896040d9f5a`。
  输出
  `runs/n019_official/eval_user/du_pred_nt_soup2_w40_shrink01_20261110`。
- 失败追溯：`1085482` 静默退出；`1085520` trace 定位为
  embedding mode gate；`1085586` 已完成 WAV/VPC，但在
  root-owned 目录创建 eval 输出时失败。最终增加可配置输出路径，
  复用完整 WAV/VPC 后由 `1085663` 成功完成。
- E-VPC/W-NT EER 未在新 WAV 上重算，仍是 pending。

## 2026-11-10 21:15 5e-5 短退火与 soup+shrink 全量

- d7 HPC Job `1085015` 完成，实际墙钟 25m。92k generator
  以 LR `5e-5` 训练 2,000 step；500/1000/1500/2000 四点
  UTMOS 分别为 `2.9721 / 3.0097 / 3.0386 / 3.1209`，
  全部低于 baseline `3.3922`。由于 discriminator/优化器
  重新初始化，该结果包含明显 transient，不单独否定 LR 假设。
- 权重轨迹诊断：相邻 2k-step 相对位移约 `4.5%`，连续位移
  余弦约 `-0.056` 到 `-0.01`，支持高噪声随机游走。
- 提交 d7 HPC 完整复评 Job `1085482`
  （`n019_eval_soup2_w40_shrink01_20261110`）：
  `hx1hdnormal`、1 DCU、16 CPU / 60 GB、2 h，预计 0.75、
  最坏 2.0 卡时。checkpoint 为
  `quad_w40_30_20_10` SHA256
  `ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6`，
  target embedding 为 `shrink0.1`。输出
  `runs/n019_official/eval/du_pred_nt_soup2_w40_shrink01_20261110`。

## 2026-11-10 20:20 soup+shrink0.1 与 5e-5 短退火

- d7 HPC Job `1084628` 完成，历时 50m42s。最好的两个
  soup 相对正式 baseline：`quad_w40_30_20_10` UTMOS
  `+0.0757472384`、WhiSQA `+0.0174215630`、WER 不变；
  `quad_plus90_10` UTMOS `+0.0587908280`、WhiSQA
  `+0.0258395135`、WER `+0.2284148013 pp`。
- d7 HPC Job `1084912` 完成，历时 8m56s，组合 soup 与
  `shrink0.1` target embedding。`quad_w40_30_20_10 + shrink0.1`
  的 dev-100 为 UTMOS `3.5127739525`、WhiSQA
  `3.4313993633`、WER `6.1215166743%`；相对当前正式
  mean32 baseline 为 `+0.1205473352 / +0.0764533620 / 0 pp`。
- 提交 d7 HPC Job `1085015`
  （`n019_lr5e5_2k_d7_20261110_2020`）：`hx1hdnormal`、
  1 DCU、16 CPU / 60 GB、1 h，预计 0.5、最坏 1.0 卡时。
  从 92k generator 初始化，LR `5e-5`、2,000 step、每 500
  step snapshot。输出
  `runs/n019_official/vocoder_nt_hpc_lr5e5_2k_from92k_20261110`；
  配置已记录为 `submit:false`。

## 2026-11-10 19:12 model soup 第一轮与第二轮

- d7 HPC Job `1084433` 完成，历时 18m42s。12 个候选中
  `quad_84_88_92_96` 为 UTMOS `3.4503521085`、
  WhiSQA `3.3788125813`、WER `6.2585655550%`；相对
  baseline 为 `+0.0581255782 / +0.0238667399 /
  +0.1370488808 pp`。UTMOS 和 WER 通过，WhiSQA 未到
  `+0.05`；`selection.json` 仍选择正式 `avg88_92`。
- 提交第二轮 d7 HPC Job `1084628`
  （`n019_soup2_20261110_1912`）：`hx1hdnormal`、
  1 DCU、16 CPU / 60 GB、2 h，预计 0.75、最坏 2.0 卡时。
  12 个候选围绕 84/88/92/96 调权，并分别与 90k/94k/
  d6 88/92 混合。输出
  `runs/n019_official/vocoder_selection_soup2_20261110`。

## 2026-11-10 18:47 零训练 model soup 搜索

- d7 HPC Job `1084308` 完成，历时 4m58s。144k UTMOS
  `3.3054394627`（`-0.0867860377`），146k
  `3.0862702608`（`-0.3059552395`），均早拒绝。
- 生成 12 个不训练候选，覆盖 88/92 邻近插值、84–96
  多点 soup、d5/d6 同 step soup 和 raw average。完整
  SHA256 见 `configs/scnet_d7_hpc_soup12_20261110.json`。
- 提交 d7 HPC Job `1084433`
  （`n019_soup12_20261110_1847`）：`hx1hdnormal`、
  1 DCU、16 CPU / 60 GB、2 h，预计 0.75、最坏 2.0 卡时。
  输出 `runs/n019_official/vocoder_selection_soup12_20261110`。
  先用 UTMOS 早拒绝，通过后再评 WhiSQA/WER。

## 2026-11-10 18:17 d6 138k/140k 选模失败

- 停止 d7 HPC FP32 旧分支 Job `1071460`，平台
  `CANCELLED+`，墙钟 `23:33:12`。停止时 step `75,860`，
  snapshots 到 74k，`last.pt` SHA256
  `93953895bbb4cc7684802ad349b560e6241483f425ef23c629e841da57c80b2a`。
  原因是 2k/8k/10k dev 已明确低于主线；当前只保留 d6
  HPC `1076707` 一条训练线。
- 144k/146k 已中转至 d7，SHA256 分别为
  `93ef9e9f57b18cd4b81c564922a75326033bf45adf7dcb5ae8083e0736501a75`
  和 `8d344ee824ab47c884aa3b98ffc6b57a607521655a6a9baae8a6d4f696f2bb76`。
  提交 d7 HPC Job `1084308`
  （`n019_d6s144146_20261110_1829`）：`hx1hdnormal`、
  1 DCU、16 CPU / 60 GB、2 h，预计 1.0、最坏 2.0 卡时；
  节点 `f11r2n02`，18:33:03 启动。输出
  `runs/n019_official/vocoder_selection_d6_144146_20261110`。

- 提交 d7 AI Job `2120083780839763970`
  （`n019_d6s138140_20261110_171847`）：1 DCU、15 CPU / 59 GB、
  1.0 h，预计 0.5、最坏 1.0 卡时；提交前余额
  `1.1558333329`。配置
  `configs/scnet_d7_vocsel40_d6_138140_20261110.json`
  已回写 JobID 并设 `submit:false`。
- baseline `avg88_92` 在正确 40-speaker dev-100 上为 UTMOS
  `3.3922264612`、WhiSQA `3.3549451292`、WER
  `6.1215166743%`。d6 138k UTMOS `3.2405943727`
  （`-0.1516320884`）；140k UTMOS `3.2434509814`
  （`-0.1487754798`）。两者均 UTMOS 早拒绝。
- `selection.json` 仍选择正式 `avg88_92`，SHA256
  `bd1370927b67a0bcf07d9ba14d5e762b1703e5a124e0aa4f0378ff9f2cf566e8`。
  输出 `runs/n019_official/vocoder_selection_d6_138140_20261110`。
- 后续不再每 2k snapshot 做完整 baseline 选模；改为至少 8k
  间隔或相邻 checkpoint 平均，保持 d6 为唯一训练线。

## 2026-11-10 16:55 d6 134k/136k 选模失败

- 提交 d7 AI Job `2120074457103839233`
  （`n019_d6s134136_20261110_164144`）：1 DCU、15 CPU / 59 GB、
  1.0 h，预计 0.5、最坏 1.0 卡时；提交前余额
  `1.3336111107`。配置
  `configs/scnet_d7_vocsel40_d6_134136_20261110.json`
  已回写 JobID 并设 `submit:false`。
- baseline `avg88_92` 在正确 40-speaker dev-100 上为 UTMOS
  `3.3922263992`、WhiSQA `3.3549448937`、WER
  `6.1215166743%`。d6 134k UTMOS `3.3342647171`
  （`-0.0579616821`）；136k UTMOS `3.1620127070`
  （`-0.2302136922`）。两者均 UTMOS 早拒绝，未评
  WhiSQA/WER，不进入完整复评。
- 100 句配对 UTMOS：134k delta `-0.0579616821`，SE
  `0.0307052225`，95% CI `[-0.1188808436, +0.0029574794]`，
  48/100 句提升；136k delta `-0.2302136922`，SE
  `0.0380565449`，95% CI
  `[-0.3057178773, -0.1547095071]`，仅 28/100 句提升。
- `selection.json` 仍选择正式 `avg88_92`。输出
  `runs/n019_official/vocoder_selection_d6_134136_20261110`；
  `selection.json` SHA256
  `d23c5e52b9b2d7062abcbac1da539a892529d973b77b9b7ad6cbd5373f836f51`。
- d6 HPC `1076707` 仍为唯一训练任务。16:52 日志 step
  `137,960`，`0.6808 s/step`，loss 有限，138k snapshot
  已于 16:52 落盘。

## 2026-11-10 12:50 收敛为单一训练分支

- 用户要求只保留更好的训练任务。d5 HPC `1076668` 已于
  12:21:14 由平台终止，`sacct` 为 `CANCELLED+`，墙钟
  `06:00:14`；不重提。
- d6 AI utterance-level `2119994244055973889` 于 12:50:07
  主动停止，平台状态已确认“已停止”。依据是 108k
  utterance-dev UTMOS `3.2481592941`，低于 speaker-mean
  baseline `3.3922258556`。日志最后 step `111,660`；
  `last.pt` SHA256
  `2a6f326f11996ff4e7e979795d7ce25bb48df967fdce9a5a836ecfaaf254d3f8`。
- 保留 d6 HPC `1076707` 作为唯一训练 Job。12:50 日志
  step `116,720`，loss 有限，snapshots 到 116k。
  utterance 112k 选模配置已取消并保持 `submit:false`。

## 2026-11-10 12:31 跨分支 112k 平均

- 同步 d5/d6 112k generator 到 d7，SHA256 分别为
  `fbd9c5113bca0f5d712675e48d9ff61c276be59a557d03088e2542c7b695320a`
  和 `47820dfa7d9883df8d213ddcff72bae5b2a20ddabbb533becce4179ed19475e7`。
  两 checkpoint 仅 `max_hours` 不同，generator 架构与 state keys
  一致。
- 更新 `scripts/average_vocoder_checkpoints.py`，默认行为不变，
  新增显式 `--allow-nonarchitectural-config-diff` 和 generator
  state-key 校验；脚本 SHA256
  `fe55a9923556b4f2de490c60aaa469fb351fb42ebbb27c1b707d135e8c115d12`，
  相关指定测试 `19 passed`。
- 提交 d7 AI Job `2120011373956190209`
  （`n019_voccross112_20261110_123105`）：1 DCU、15 CPU / 59 GB、
  1.0 h，预计 0.5、最坏 1.0 卡时；提交前余额
  `1.9797222218`。三个候选的 UTMOS 先筛，通过者再评
  WhiSQA/WER；配置已设 `submit:false`。

## 2026-11-10 12:24 utterance 108k 选中失败

- d6 AI Job `2120005445911465985` 完成。baseline
  `avg88_92` UTMOS `3.3922258556`；utterance-level 108k
  UTMOS `3.2481592941`，delta `-0.1440665615`，early reject。
- 108k 距离共同分支点 104k 只有 4,000 step，视为口径切换
  适应期但当前不胜出；继续观察 112k/116k，若持续不恢复则
  提前停止 5h 分支。没有启动 WhiSQA/WER 或全量复评。

## 2026-11-10 12:15 加权平均完成

- d7 Job `2120004844019294210` 完成。`w92x50_106x50`
  UTMOS `3.4254162288`；`w88x15_92x25_106x60`
  `3.4421379781`；`w88x20_92x20_106x60`
  `3.4431574130`。最后一个通过 UTMOS 门槛，但 WhiSQA
  `3.3511320561`（baseline `3.3549456418`），WER
  `5.7560529922%`，因 WhiSQA 不达标而 `eligible=false`。
- 最终仍选择正式 `avg88_92`，不启动该候选的完整复评。
  配置状态改为 `completed_no_eligible_20261110_1215`。

## 2026-11-10 12:05 106k 加权平均筛选

- d7 Job `2119985822010404865` 完成。baseline `avg88_92`
  dev UTMOS/WhiSQA/WER =
  `3.3922258222 / 3.3549456418 / 6.1215166743%`。
  扩展候选 UTMOS 均未到 `+0.05`：
  100k `3.4319149876`、102k `3.4035132003`、100/102
  `3.4273676348`、106k `3.4404903388`、六点平均
  `3.4315163684`。106k 是最接近者，差门槛 `0.0017354834`。
  100 句配对 UTMOS：delta `+0.0482645166`，SE
  `0.0198458105`，t `2.4320`，95% CI
  `[+0.0088904, +0.0876386]`；方向可能真实，但选模门槛
  不因此回溯放宽。
- 生成加权候选 `w92x50_106x50`、`w88x20_92x20_106x60`、
  `w88x15_92x25_106x60`。提交 d7 AI Job
  `2120004844019294210`（`n019_voc106wt_20261110_120509`）：
  1 DCU、15 CPU / 59 GB、1.0 h，预计 0.4、最坏 1.0 卡时；
  提交前余额 `2.1566666662`。输出目录沿用固定 selection 目录，
  配置已设 `submit:false`。
- utterance-level Job `2119994244055973889` 于 12:02 到
  step `108,080`，约 `0.77 s/step`，loss 有限；d5/d6 HPC
  主线分别到约 `112,540 / 112,640`。
- 提交 d6 AI Job `2120005445911465985`
  （`n019_utt108sel_20261110_120732`）：1 DCU、15 CPU / 59 GB、
  1.0 h，预计 0.5、最坏 0.85 卡时。比较 `avg88_92` baseline
  与 utterance-level 108k snapshot（SHA256
  `8a887cb2b3f220cf94e304efc00566a171041ccecac8adf724c0d5cb3df15c44`）；
  当前 d6 余额 `6.7469444443`，与 5h 微调最坏合计 6.35 h。
  配置已回写 JobID 并设 `submit:false`。

## 2026-11-10 11:23 utterance-level 5 小时微调

- smoke Job `2119989494043471873` 的训练路径成功：step
  1/20/40/60/80/100 loss 有限，step 100 保存完整 checkpoint，
  `meta.json` 中 `embedding_level=utterance`。平台最终失败仅因
  smoke 配置 `keep_interval=0` 在正常结束后触发除零；不重提该
  smoke。
- 复制 d5 完整 step 104,000 训练状态到 d6 作为共同分支点，
  SHA256 `95aa744c27590f4dcddcb18b60ae40d9cdbbf8060a7f64f66128586f961ac14b`。
- 提交 d6 AI Job `2119994244055973889`
  （`n019_uttft5h_20261110_112302`）：1 DCU、15 CPU / 59 GB、
  5.5 h 外层、内部 5.0 h，预计 4.8、最坏 5.5 卡时；提交前
  余额 `7.0213888887`。输出
  `runs/n019_official/vocoder_nt_uttemb_ft_20261110`。
- 输入为 canonical 33,236 records、完整 33,236-key utterance
  NT embeddings、step 104k 完整状态、mean32 之外的唯一变量
  `embedding_level=utterance`；停止条件为非有限 loss、数据/
  checkpoint 哈希不符、10 分钟无进度、DCU watchdog/OOM 或墙钟。
  配置已回写 JobID 并设 `submit:false`。

## 2026-11-10 11:04 utterance embedding 合并与 smoke

- shard1/2 各完成 9,212 条。用 canonical 33,236 条
  `unit_records.jsonl` 合并 base partial、shard0/1/2：
  canonical SHA256
  `5d3bb4d7bc41cfd973d9313b84b3faae32c3a3abcb572a03153badfa7669e50d`，
  输出 embeddings SHA256
  `20c36171f534342c04831fb169010b81474cecad2e66443016696d06d067eb49`；
  33,236 keys、250-D、finite、unit norm，5,600 个重叠 key
  逐位一致。
- 提交 d6 AI Job `2119989494043471873`
  （`n019_uttftsmoke_20261110_110409`）：1 DCU、15 CPU / 59 GB、
  0.5 h，预计 0.15、最坏 0.5 卡时；提交前余额
  `7.0213888887`。仅 100 steps，从 `avg88_92` generator
  初始化，`embedding_level=utterance`。输入、输出和停止条件见
  `configs/scnet_d6_utterance_smoke_20261110.json`；已设
  `submit:false`，不得重复提交。

## 2026-11-10 10:49 扩展 checkpoint 平均选模

- 提交 d7 AI Job `2119985822010404865`
  （`n019_vocsel40_d5avg_ext_20261110_104934`）：
  1 DCU、15 CPU / 59 GB、1.5 h，预计 0.9、最坏 1.5 卡时；
  提交前实时余额 `3.2297222218`。
- baseline 为当前正式 `avg88_92`；比较
  `avg88_92_100`、`avg88_92_102`、`avg88_92_100_102`
  三个 effective-weight-norm 等权平均。
- 输入为正确 40-speaker dev-100、96-target map、mean32
  target embedding、duration predictor、UTMOS/WhiSQA/WER
  evaluator；输出
  `runs/n019_official/vocoder_selection_40spk_d5_avg8892_vs_100102_20261110`。
- 停止条件：checkpoint 集合或 SHA256 不符、dev 协议不符、
  任一指标缺失/非有限、UTMOS 早拒绝、DCU 异常/OOM/无进度
  或达到 1.5 h。配置已设 `submit:false`，不得重复提交。
- d5/d6 在 10:50 左右到日志 step `106,240 / 106,320`；
  d5 106k snapshot SHA256
  `c597aa294523f1fc8333cf4a8d162de7ca1323f1062f8da5e7830cd434aa6182`，
  源/本机/d7 三处一致。
- 已在 d7 零卡时生成 `avg88_92_106`（SHA256
  `5f44e6942a3bac6ed6bdb94b71cb3f0d4e0ce4869e3aea3966a2c50a50f9095e`）
  和 `avg88_92_96_100_102_106`（SHA256
  `3f842a8a9adb9b6d0ae9cefd2905c7e48ea14d7dd96f4e54dbf82570713de3a4`）。
  fallback 配置
  `configs/scnet_d7_vocsel40_d5_avg8892_106_broad_20261110.json`
  尚未提交。

## 2026-11-10 10:41 88k/92k checkpoint 平均完整复评

- Job `2119976635173982210` 完成，完整 1,934 句。正式值：
  WER `6.221106101249928%`（1,496）、UTMOS
  `3.3997926173313697`（1,934）、WhiSQA
  `3.3985530013351433`（1,934）。
- 相对论文 7.41/3.63/3.69，差值
  `-1.1888938988 pp / -0.2302073827 / -0.2914469987`。
  相对 88k，WER `-0.1541007933 pp`、UTMOS
  `+0.1044138844`、WhiSQA `+0.0554158402`。
- checkpoint SHA256
  `fafe5982588bea492dd761f1c2d51cc925474503a4f158cf1680667b2286ded8`；
  `quality_metrics.json` SHA256
  `582f345de4273d5b0ca32a721925b6317b0684e3ca5742992076a2971b7b207e`。
  输出
  `runs/n019_official/eval/du_pred_nt_hpclong_d5_avg88_92_effnorm`。
- 后续优先测试 98k/100k/102k 与 88k/92k 的 effective-weight-norm
  平均；单项 snapshots 不可超过该正式结果，除非完整复评完成。

## 2026-11-10 08:43 d5 88k 完整复评完成并成为正式结果

- Job `2119947801308733442` 已完成，运行
  `08:18:42–08:43` 左右，完整 1,934 句。正式值：
  WER `6.375206894583642%`（1,496）、UTMOS
  `3.295378732952485`（1,934）、WhiSQA
  `3.3431371611147163`（1,934）。
- 相对论文 7.41%/3.63/3.69，差值为
  `-1.0347931054 pp / -0.3346212670 / -0.3468628389`。
  相对旧正式 54k，UTMOS `+0.0952439957`、WhiSQA
  `+0.1468997617`、WER `+0.1769305405 pp`；WER 仍明显优于论文。
- checkpoint SHA256
  `c8744739ddbecf9075c10470f9b495ca8368e1bba645bd9cda28302a3555701a`。
  `quality_metrics.json` SHA256
  `585af02febd1de622f8f12392ee7c8c22047084bc2b6fa1049f7c8ad41e76c8b`。
  输出
  `runs/n019_official/eval/du_pred_nt_hpclong_d5_step88000_mean32`。
- 90k/92k 滚动选模 Job `2119948401442332673` 继续运行，不将其
  dev 结果与本次 full test 混写；只有通过 88k dev baseline gate
  才安排下一轮完整复评。
- 90k dev UTMOS 已出：`3.2506227565`，相对 88k
  `3.2961353779` 为 `-0.0455126214`，已提前判定不可选；
  Job 继续测 92k。
- 94k/96k snapshots 已从中转链逐项校验并复制到 d7。新 Job
  `2119956845166292994`，名称
  `n019_vocsel40_d5s9496_20261110_085427`；d7、人工智能/
  模型训练、1 DCU、15 CPU / 59 GB、1.5 h，预计 0.9、最坏
  1.5 卡时；baseline 88k。94k/96k SHA256 分别为
  `8b8a193d215d86dddcb43553a9fa07205d53b65dc0fd6f38ac30356634224ab3`、
  `1cdd25714d2a2d4709df0d8903e9760888f6a5161f4ce76fc105241b068358a3`。
  配置已回写 JobID 并设 `submit:false`。
- utterance embedding shard0 完成：manifest 9,212、NPZ
  14,812 keys（5,600 base + 9,212 shard）、250-D、finite、
  unit norm；NPZ SHA256
  `9329f8e7f6872f62837a06ca8d4ada1a80e66700da5bf56264d01830da0dd69a`。
  shard2 Job `2119956243665928193`（`n019_ntutt_s2_20261110_085204`）
  已启动：d6、1 DCU、15 CPU / 59 GB、5.5 h，预计 5.0、
  最坏 5.5 卡时；提交前 d6 余额 `12.8902777775`。
- 90k/92k selection 完成，selected 仍为 88k baseline：
  90k UTMOS/WhiSQA/WER `3.2506227565 / 3.2866789535 /
  5.8931018730%`；92k `3.3259529352 / 3.2646234110 /
  6.3956144358%`。92k 的 UTMOS/WhiSQA delta 只有
  `+0.0298175573 / -0.0174747750`，不通过 gate。
- 94k dev 为 `3.2928789449 / 3.2841303170 / 6.7153951576%`；
  UTMOS `-0.003256`、WhiSQA `+0.002032`、WER
  `+0.365464 pp`，不通过；96k 继续。
- 新增两个 effective-weight-norm 平均候选并提交 Job
  `2119962502553157634`
  （`n019_vocsel40_d5avg8892_20261110_091656`）：d7、1 DCU、
  15 CPU / 59 GB、1.5 h，预计 0.9、最坏 1.5 卡时；提交前
  d7 余额 `5.1730555552`。50/50 平均 SHA256
  `fafe5982588bea492dd761f1c2d51cc925474503a4f158cf1680667b2286ded8`；
  75/25 平均 SHA256
  `eae2161f012e98ebe7bb30071789b2b2315d59cb453fb19b75985c9c9197e8ed`。
  配置已回写 JobID 并设 `submit:false`。
- 等权平均 88k/92k 的 dev 结果通过 gate：UTMOS
  `3.3922256935`（+0.0960908067）、WhiSQA
  `3.3549457431`（+0.0728473246）、WER `6.1215166743%`
  （-0.2284148013 pp）。75/25 平均 WhiSQA 只提升
  `0.048922384`，不足 0.05，不可选。
- 新 Job `2119976635173982210`，名称
  `n019_d5_avg8892_effnorm_20261110_101303`；d7、人工智能/
  模型训练、1 DCU、15 CPU / 59 GB、2 h，预计 0.9、最坏
  2.0 卡时；提交前余额 `3.6772222218`。checkpoint SHA256
  `fafe5982588bea492dd761f1c2d51cc925474503a4f158cf1680667b2286ded8`。
  完整 1,934 句结果写入 `eval/du_pred_nt_hpclong_d5_avg88_92_effnorm`。
  配置已设 `submit:false`。
- 选模脚本新增可选 UTMOS 早拒绝：默认关闭，开启后 UTMOS
  不可能通过 `+0.05` gate 的候选跳过后续两项评测并写
  `early_reject.json`；静态测试 `14 passed`。

## 2026-11-10 07:55 utterance-conditioning 门禁与 88k 选模进度

- d7 Job `2119937853517742082` 已完成正确 40-speaker dev-100
  选模。54k baseline 为 UTMOS `3.1947042739`、WhiSQA
  `3.1480606735`、WER `6.4412973961%`；88k 为
  `3.2961341763 / 3.2820993334 / 6.3499314756%`。delta
  `+0.1014299023 / +0.1340386599 / -0.0913659205 pp`，三项
  通过 gate。`selection.json` SHA256
  `2ee95c602cf86c436655884bfa96895429e72b45fb8487fd92a72b7978e68bde`。
- 新 Job `2119947801308733442`，名称
  `n019_d5_88k_mean32_20261110_081831`；d7、人工智能/模型训练、
  1 DCU、15 CPU / 59 GB、2 h 外层 SIGKILL，预计 0.9、最坏
  2.0 卡时；提交前余额 `6.6038888885`。输入为 88k checkpoint
  SHA256 `c8744739ddbecf9075c10470f9b495ca8368e1bba645bd9cda28302a3555701a`、
  1,934 source/unit/target map、mean32 embeddings、duration/ASR/
  UTMOS/WhiSQA。实际输出为
  `data/n019_official/anonymised/libri_test/DU-pred-nt-hpclong_d5_step88000_mean32`，
  VPC suffix `_n019_hpclong_d5_step88000_mean32`，
  `runs/n019_official/eval/du_pred_nt_hpclong_d5_step88000_mean32`。
  配置已回写 JobID 并设 `submit:false`。
- 08:26 已完成该 Job 的匿名化与 VPC 导出：`anon.jsonl` 和 WAV
  均 1,934，VPC 1,934/438/734/762，trials 11,744/9,906；
  已进入 WER/UTMOS/WhiSQA，完成前不替换正式结果。
- 同时提交滚动选模 Job `2119948401442332673`
  （`n019_vocsel40_d5s9092_20261110_082054`）：d7、人工智能/
  模型训练、1 DCU、15 CPU / 59 GB、1.5 h，预计 0.9、最坏
  1.5 卡时。输入为 90k/92k snapshots、88k baseline、正确
  40-speaker dev、mean32 target embedding、duration/ASR/
  UTMOS/WhiSQA。90k SHA256
  `cf6d64fed6637f3f2bbe0a9c11af455fd01c9b7bdbf280cdd219c7f4c8199be2`，
  92k SHA256
  `f203505cdfc90df0a77b37c3c08870dd7421f076aad226ba3429937aa8ee72f7`；
  本地及 d7 回读一致。配置已回写 JobID 并设 `submit:false`。
- d5 Job `1076668`、d6 Job `1076707` 在 07:52 分别到 step
  `90,660`、`90,680`，约 `0.68 s/step`，loss 有限；90k snapshot
  已落盘，SHA256 分别为
  `cf6d64fed6637f3f2bbe0a9c11af455fd01c9b7bdbf280cdd219c7f4c8199be2`、
  `dcec28bc96054b014997415b76f53600c78e3810ef0815a1d1bb95c3f0cfb003`。
- d7 Job `2119937853517742082` 已完成 54k baseline 的 100 句
  UTMOS `3.1947042739391325`；WhiSQA、WER 和 88k 候选仍运行。
- 训练 launcher 新增 `N019_VOCODER_EMBEDDING_LEVEL`，允许在后续
  受控 A/B 中显式选择 `utterance`；默认 `speaker` 保持历史行为。
  静态测试 `13 passed`，shell syntax 检查通过。
- utterance embedding shard0/shard1 在 07:52 为
  `6,900 / 9,212`、`3,400 / 9,212`。shard0 完成后提交 shard2；
  三片完成后按 33,236-key canonical manifest 严格合并。

## 2026-11-10 07:40 d5 88k 的 40-speaker selection

- d5 Job `1076668` 与 d6 Job `1076707` 均在 07:34 到约
  step `89,140`，约 `0.68 s/step`；d5 88k snapshot 已落盘。
- 88k generator 源/本机/d7 回读 SHA256 均为
  `c8744739ddbecf9075c10470f9b495ca8368e1bba645bd9cda28302a3555701a`。
- 新 Job：`2119937853517742082`，名称
  `n019_vocsel40_d5s88_20261110_073859`；d7、人工智能/模型训练、
  1 DCU、15 CPU / 59 GB、1.5 h，预计 0.8、最坏 1.5 卡时；
  提交前余额 `6.9505555552`。
- 输入：正确 40-speaker dev units、匹配的 96-target map、
  mean32 target embeddings、d5 54k baseline/88k snapshot、
  duration predictor、UTMOS/WhiSQA/ASR。输出
  `runs/n019_official/vocoder_selection_40spk_d5_54k_vs_88k_20261110`。
  配置已回写 JobID 并设 `submit:false`。未使用 d8/d9。
- utterance shard0 partial `11,500` keys（5,900 shard rows），
  shard1 partial `2,800` keys，均运行中。

## 2026-11-10 06:44 40-speaker 选模集修正与 source/target 判别

- 发现旧选模路径 `selection_dev100_2x24k_20261108` 的 100 句
  全部来自同一 speaker `1116`，不是文档声称的 40 speakers。历史
  候选排名保留，但后续不再把它当作 speaker-disjoint 选模集。
- 正确的 40-speaker VPC dev-100 位于
  `selection_dev100_vpc_units_20261108_retry1`，含 40 个
  source-speaker embeddings。新增按行复用 96 个既有 target
  assignments 的匹配 map，SHA256
  `f8cc5b8b7b56e6393a05eae360bc7736e29ea77a0fd54e78c4220795fdb72627`。
- 首次 Job `2119923576905814017`，名称
  `n019_srctgt40_20261110_064216`；GPU watchdog 通过，但脚本
  把 ASR 默认路径写成 `asr_n19_local`（实际
  `asr_n019_local`），在生成前退出；无 WAV/指标，卡时损失很小。
  不重复该 Job。
- 修正后的 retry1 Job：`2119924762827333633`，名称
  `n019_srctgt40_r1_20261110_064658`；账号 d7、人工智能/模型训练、
  1 DCU、15 CPU / 59 GB、1.5 h，预计 0.6、最坏 1.5 卡时；
  提交前余额 `7.7244444441`。
- 输入：正确 40-speaker dev units/manifest、source embeddings、
  96 个 mean32 target embeddings、d5 step 54k generator。
  输出 `runs/n019_official/source_target_diag40_retry1_20261110`。
  停止条件为 speaker/ID/embedding 校验失败、tiny-matmul watchdog、
  OOM/存储/无进度或 1.5 h。配置已回写 JobID 并设
  `submit:false`。未使用 d8/d9。
- Retry1 已完成，平台状态 `已完成`，运行
  `06:47:10–07:32:21`，实际 `45m11s = 0.753` 卡时。
  source reconstruction UTMOS/WhiSQA/WER 为
  `3.3275684786 / 3.3236708373 / 4.4312471448%`；target
  anonymisation 为 `3.1768457067 / 3.1102414072 /
  4.5682960256%`。target-source 为
  `-0.1507227719 / -0.2134294301 / +0.1370488808 pp`。
  `comparison.json` SHA256
  `abb94def914b384353754f789575ad639b98ff55d53078bd7561b594a441b2bf`。
  首次路径错误 Job 运行 `1m15s ≈ 0.021` 卡时；
  两次合计约 `0.774` 卡时。

## 2026-11-10 06:30 utterance embedding 全量合并门禁

- d5 Job `1076668` 于 06:28 到 step `83,340`，约
  `0.684 s/step`，loss 有限；持久 checkpoint 仍为 hpclong 最终
  step `82,934`，下一个 84k snapshot 尚未落盘。
- d7 FP32 Job `1071460` 到 step `37,140`，约 `1.11 s/step`，
  snapshot 已到 36k。
- d6 shard0 Job `2119908581433954306` 到 `2,100 / 9,212`；
  shard1 Job `2119913793307361281` 到 `500 / 9,212`，均运行中。
- 新增 canonical merge 脚本，允许“base partial + shard”造成的
  逐位相同 key 重叠，但拒绝冲突向量、缺 key、错误维度、非有限值
  或非 unit-norm；输出固定按完整 manifest 顺序。脚本 SHA256
  `97444ba6690971258a1f5613eb353874ee34f7ecf5b2cbe721f4e240baabf93d`，
  相关测试共 `14 passed`。本轮零卡时，未使用 d8/d9。

## 2026-11-10 06:24 hpclong 最终 82,934 step，d5/d6 接续

- d6 hpclong Job `1069636` 正常到达内部上限并退出。最终
  `last.pt` step `82934`，SHA256
  `bf7f00f931a27feaa8d7d3ad00c8cb9cf812162e79760afe5a40836af9c8eb0d`；
  generator 82k SHA256
  `84c27a40e127495329549ceffcc4f36e4c924a9acca0f729237ff61fb46ada0a`。
- d6 续训 Job `1076707` 于 06:21 启动，节点 `f11r1n03`；启动记录
  `continuation_1076707.json` 已确认从 step `82934` 恢复，输出仍为
  `runs/n019_official/vocoder_nt_hpc_ft14k_long_20261109`。
- d5 续训 Job `1076668` 于 06:21 启动，节点 `f11r1n03`。
  `/public/home/a094f4d5/.../resume_source.json` 已写入：
  source/target step `82934`，source/target SHA256 均为
  `bf7f00f9...eb0d`，复制校验通过。
- d5 内部预算 42.25 h，d6 内部预算 34.0 h；两者当前 RUNNING，
  等待 preflight 后的训练日志。utterance shard0/shard1 继续运行。
  未使用 d8/d9。
- 06:23:31 两个 Job 均已从 `step=82935` 进入训练循环；
  06:23:43 完成首步，首条 step `82940` 日志的 loss_g 分别为
  `49.01631`（d5）和 `49.01437`（d6），单步约 `0.687 s`。

## 2026-11-10 06:05 FP32 70k 淘汰，shard1 启动

- d7 AI dev-100 Job `2119909855879315457` 完成 FP32 70k UTMOS：
  `3.1845301151275636`。baseline 54k 为 `3.200829032659531`，
  delta `-0.0162989175`，未达到 `+0.05`，因此不等待
  WhiSQA/WER，并在约 06:02 停止；实际约 0.24 h、1 DCU。
- d6 AI FP32 Job `2119864730527092738` 同时停止，实际约 3.23 h、
  1 DCU。70k generator SHA256
  `424531f6f8b5cefb91b993e715019b9008fe48077c2ea6973ed52cc87efc072e`
  已保留。d7 HPC FP32 `1071460` 继续。
- d6 shard0 正常：100 条 `130.5 s`，100→200 约 `88.4 s`，
  200→300 约 `93.9 s`，约 `0.9–0.95 s/utterance`。
- 释放并发槽后提交 d6 shard1 Job `2119913793307361281`
  （`n019_ntutt_s1_20261110_060323`）：1 DCU、15 CPU / 59 GB、
  5.5 h，预计 5.0、最坏 5.5 卡时。配置已回写真实 JobID 并设
  `submit:false`。
- shard2 仍等待 shard0 完成，不重复提交。d5 HPC `1076668`、
  d6 HPC `1076707` 保持 Dependency PENDING。未使用 d8/d9。

## 2026-11-10 05:50 逐句 embedding 三路分片与 FP32 70k 选模

- d6 AI 逐句 embedding Job `2119894378981191682` 的实测吞吐为
  约 `1.8 s/utterance`，原 6 h 墙钟无法覆盖 33,236 条。于约
  05:40 主动停止；实际墙钟约 0.9 h，最后 partial 为 5,600 keys。
- 新增零卡时分片准备脚本与运行脚本，按 speaker 将剩余 27,636 条
  分成三个严格不相交的 9,212 条分片，共 199 个 speaker。准备
  summary：
  `processed/embeddings/nt_utterance_shards_20261110/summary.json`。
- 新 d6 AI Job `2119908581433954306`
  （`n019_ntutt_s0_20261110_054240`）：1 DCU、15 CPU / 59 GB、
  5.5 h，预计 5.0、最坏 5.5 卡时；提交时 d6 余额
  `18.8344444442`。任务以 5,600-key partial 为基底，再处理 shard0，
  输出
  `runs/n019_official/nt_utterance_shards_20261110/shard_0`。
  首个 100 条用时 `130.5 s`（`1.305 s/utterance`），预计 shard0
  有效计算约 3.34 h、09:00 左右完成。
- shard1/2 暂未提交。shard1 第一次表单提交时，平台已有两个活动
  实例，创建页未离开 add-train，未生成 JobID，消耗 0 卡时；配置
  已关闭。待并发槽释放后按顺序提交，不重复现有 Job。
- d6 FP32 分支 Job `2119864730527092738` 仍在运行，05:46 日志
  step `70,780`，持久 snapshot 70k，实际约 `1.13 s/step`。
  70k SHA256
  `424531f6f8b5cefb91b993e715019b9008fe48077c2ea6973ed52cc87efc072e`。
- 已提交 d7 AI Job `2119909855879315457`
  （`n019_selfp32d6s70_20261110_054744`）：1 DCU、15 CPU / 59 GB、
  1 h，预计 0.35、最坏 1.0 卡时；提交时 d7 余额
  `7.978333333`。只比较 baseline 54k 与 FP32 70k 的 dev-100
  UTMOS/WhiSQA/WER。配置已写真实 JobID 并设 `submit:false`。
- d5 HPC `1076668`、d6 HPC `1076707` 保持 Dependency PENDING。
  未使用 d8/d9。

## 2026-11-10 05:38 零卡时 HuBERT layer 口径审计

- 下载并解析 N019 引用 [32] 的 EMNLP 2022 论文。该文明确报告
  HuBERT 第 9 层、K=200 的 content units，token extraction 表中
  layer 9/K=200 也是其最佳配置。
- 当前 N019 实现使用 layer 6，依据 SSL-SAS/GSLM/
  speech-resynthesis 引用链；N019 本身未公开层号。因此 layer
  6/9 仍是一个未闭合复现风险，但不能在现有 unit/codebook/
  duration/vocoder 全链已训练完成后无证据切换。
- 该风险已写回 `configs/paper_algorithm_v1.json` 与
  `docs/PAPER_ALIGNMENT_CHECKLIST.md`。layer 9 重新提取和重训只在
  当前长训、utterance embedding、FP32 审计仍不足时作为高成本
  判别分支。本轮 0 卡时。

## 2026-11-10 05:36 FP32 28k dev UTMOS 淘汰与提前停止

- d7 AI 选模 Job `2119902514674442241` 的
  `generator_step00028000` 在固定 dev-100、mean32 target embedding
  和预声明 target-conditioned 协议下完成 UTMOS：
  `3.145405457019806`。
- 同次 Job 的 d5 step 54k baseline UTMOS 为
  `3.200829032659531`，28k delta `-0.055423575640274`。UTMOS
  已低于 baseline，无法满足双 MOS 各 `+0.05` 的门槛，因此不再等待
  WhiSQA/WER，于约 05:35 通过 headless 控制台停止任务。
- 平台详情已确认状态 `已停止`；实际墙钟约 0.28 h、1 DCU，
  最坏约 0.28 卡时。配置状态改为
  `rejected_utmos_20261110_053500`，不得重复提交。
- 这不构成对 FP32 整个分支的结论；d7 HPC FP32 Job `1071460`
  继续运行，后续只在 54k 或更晚 checkpoint 上做同预算比较。

## 2026-11-10 05:30 d6 hpclong 续训到 78k，并排队继续 34h

- d6 hpclong Job `1069636` 仍在运行。05:26 日志约 step
  `78,100`；完整持久 checkpoint 已到 step `78,000`，SHA256
  `2fe45e0df81d965d673396333db611b16693565bb4ff286e509f6945c869f2a4`。
  generator snapshot SHA256
  `8ebf04e199a3bf7e25bcf83c460bdd2af22a71d208ee785b74abaa3112e1bc72`。
- 新 Job：`1076707`，名称 `n019_vocd6_cont34h`；账号
  `a094f4d6`；模式 HPC/Slurm；分区 `hx1hdnormal`；1 DCU、
  16 CPU / 60 GB；外层 34.25 h，内部 34.0 h，预计/最坏
  34.0 卡时。当前 PENDING，依赖 `afterany:1069636`。
- 输入同上，从 hpclong 最终 `last.pt` 在同一输出目录续训；
  启动前校验完整 checkpoint 键、step `>=78,000`、checkpoint
  SHA256 和 2x feature-matching recipe。输出
  `runs/n019_official/vocoder_nt_hpc_ft14k_long_20261109`。
- d6 HPC 累计约 14.8 h；34.0 h 最坏预算后仍预计低于 50 h
  免费额度。launcher SHA256
  `ed9d5fc5d13e48c94a4671fabd84ef34bad7e99b02ed05c3e773c5f0563edde9`。
  未使用 d8/d9。

## 2026-11-10 05:25 d5 停止旧分叉并等待 hpclong 最终 checkpoint

- 05:22 实时核对 d6 hpclong Job `1069636`：日志 step `77,980`，
  当前最后完整持久 checkpoint 为 step `76,000`，1,019,512,015 B，
  SHA256 `327760e9f7a85d09a23bb594745a434444da77e02b4eeb89094104561c081c1a`；
  generator snapshot SHA256
  `b23644fead7262aa88da0d6677983feb599bff81e55d1bb50933ab026e976e99`。
  Job 预算 15.5 h、外层 16 h，预计在 06:18:36–06:48:36 结束。
- d5 Job `1076177` 从 step 72k 分叉，落后于 hpclong 分支，已停止；
  实际墙钟 `01:00:04`，约 `1.001` 卡时。旧输出最后持久 checkpoint
  为 step `76,000`，SHA256
  `1fe19bf95182314a73ef47ba4a6eb4ac6b51f20e59e566a6f7ed6cd3693bc0cb`，
  目录保留，不覆盖、不再续跑。
- 新 Job：`1076668`，名称 `n019_vocd5_final_42h`；账号
  `a094f4d5`；模式 HPC/Slurm；分区 `hx1hdnormal`；1 DCU、
  16 CPU / 60 GB；外层 42.75 h，内部 42.25 h，预计/最坏
  42.25 卡时。`--dependency=afterany:1069636` 当前状态 PENDING。
- 输入为 hpclong Job 结束后 d6 的最终 `last.pt`；输出为
  `runs/n019_official/vocoder_nt_hpc_d5_hpclongfinal_20261110`。
  启动脚本会验证完整 checkpoint 键、要求 step `>=76,000`、复制后
  逐项核对源/目标 SHA256，再沿用 BF16、total batch 16、lr `2e-4`、
  2x feature matching 和每 2k snapshot 配方。
- d5 HPC 累计约 `7.553 h`，按 50 h 免费额度估算约剩
  `42.447 h`；最坏预算后约留 `0.197 h`。launcher SHA256
  `4942bc516cfd050c0f3ceaae73bd48d2ec2c1e0d9c23fc3708fcde2192698a10`。
  未使用 d8/d9。

## 2026-11-10 05:20 72k 淘汰与 FP32 28k/30k/32k 选模

- 72k target-conditioned dev-100 UTMOS 为
  `3.0588623344898225`；baseline d5 54k 为
  `3.200829032659531`，delta `-0.1419666981697085`。UTMOS
  已明确失败，05:16:32 停止 Job `2119892521730797570`，
  不等待 WhiSQA/WER；72k 不可选。
- 新 Job `2119902514674442241`，名称
  `n019_selfp32seg_20261110_051834`；d7、人工智能/模型训练、
  1 DCU、15 CPU / 59 GB、2 h，预计 1.4、最坏 2.0 卡时；
  提交前 d7 余额 `8.523333333`。
- 输入为同一 dev-100、mean32、duration predictor、d5 54k baseline
  和 FP32 28k/30k/32k generator。checkpoint SHA256 分别为
  `603ddf64e1627a5313ef97fadba5f6c6ad9ca05db6983b90502175dcef65cdfb`、
  `c22068ea900360a89e6290f635cf78cba498fac783dde4b0722b4d6e74d65f37`、
  `21e77d42a4821eff6c54b2513da14759b24da18c330dec488d53ac9d7e1ab14a`。
  输出复用
  `runs/n019_official/vocoder_target_selection_d5_72k_20261110_0436`，
  baseline WAV/指标直接复用，只评 FP32 三个候选。Pod 已 Running。
- 配置 `configs/scnet_d7_fp32_2832_selection.json` 已回写
  `submit:false` 和 JobID，严禁重复提交。未使用 d8/d9。

## 2026-11-10 04:34 peaknorm、shrink01 与 embedding 进度

- peak-normalization dev-100 已完成，输出
  `runs/n019_official/waveform_peaknorm_dev100_20261110_034733`。
  baseline UTMOS/WhiSQA/WER 为
  `3.2008296072 / 3.1699204698 / 20.4982517483%`；normalized
  为 `3.1939263511 / 3.1322886452 / 20.4982517483%`，delta
  `-0.0069033 / -0.0376318 / 0.0 pp`。方向拒绝。
- target mean32 vs shrink-0.1 dev-100 已完成，输出
  `runs/n019_official/target_embedding_ab_mean32_vs_shrink01_d5_54k_20261110_031238`。
  shrink01 UTMOS/WhiSQA/WER 为
  `3.2332408035 / 3.2276199937 / 20.6730769231%`，delta
  `+0.0324112 / +0.0576995 / +0.174825 pp`。UTMOS 未达到
  `+0.05` gate，不能成为正式候选。
- d6 逐句 NT embedding Job `2119880224430178305` 仍在运行；
  04:28 日志 `2,600 / 33,236`，约 `0.63 s/utterance`。1 h 内无法
  完成，当前 Job 超时后只从 checkpoint 续跑，不从头重算。
- 首次逐句 embedding Job `2119880224430178305` 于 55 分钟
  外层 timeout 结束时为 `4,400 / 33,236`，partial NPZ
  `partial_embeddings.npz` 为 5,699,486 B，保留可续跑状态。
  已提交 6 h 续跑 Job `2119894378981191682`
  （`n019_ntutt_6h_20261110_044614`）：1 DCU、15 CPU / 59 GB、
  预计 5.2、最坏 6.0 卡时；提交前 d6 余额 `20.8138888887`。
  Pod 已 Running。配置已回写 `submit:false`，严禁重复提交。
- 已提交 d7 target-conditioned 选模 Job `2119892521730797570`
  （`n019_selsel72k_20261110_043851`）：1 DCU、15 CPU / 59 GB、
  1.5 h，预计 0.5、最坏 1.5 卡时；提交前 d7 余额
  `8.8722222219`。比较 d5 54k baseline 与 hpclong 72k generator
  （SHA256 `f3b2f625f4ee7a41376c1d62d38574d5dd71fb96dd52bb8812cb9b62e5e11aae`），
  固定 dev-100、mean32、duration predictor 和 evaluator。输出
  `runs/n019_official/vocoder_target_selection_d5_72k_20261110_0436`。
  04:38 平台返回 ID 后 Pod 已 Running。配置已回写 `submit:false`，
  严禁重复提交。
- 该 Job 的 baseline UTMOS 为 `3.200829032659531`，72k 为
  `3.0588623344898225`，delta `-0.1419666981697085`。UTMOS
  已明确低于正式 baseline，按双 MOS 门槛不可选；05:16:32 停止，
  不再耗卡等待 WhiSQA/WER。实际运行约 39 分钟。
- 当前训练：d5 Job `1076177` 从 step 72k 续训；d6 hpclong
  Job `1069636`；d7 FP32 Job `1071460`。未使用 d8/d9。

## 2026-11-10 04:28 d5 改从 hpclong step 72k 完整状态续训

- 2026-11-10 04:18 实时核对 d6 hpclong Job `1069636`：日志 step
  `72,760`；最后完整持久 `last.pt` 为 step `72,000`，
  1,019,512,015 B，SHA256
  `00454ea27ce20842432a4f2baf489bd5c7b57eb7d70400a62c7cd84f45f2dbb3`。
  generator snapshot SHA256
  `f3b2f625f4ee7a41376c1d62d38574d5dd71fb96dd52bb8812cb9b62e5e11aae`。
- 旧 d5 Job `1075605` 从 step 66k 分叉，日志约 69.4k 时最后持久
  checkpoint 为 68k，不符合从 hpclong 最新状态续训的要求；已停止，
  Elapsed `00:56:36`，约 `0.943` 卡时。旧目录保留，不覆盖。
- step 72k `last.pt` 经本机中转至
  `/public/home/a094f4d5/voice_projects/runs/n019_official/vocoder_nt_hpc_d5_hpclong72k_20261110/last.pt`；
  d6、本机、d5 三处 SHA256 一致。
- 新 Job：`1076177`，名称 `n019_vocd5_72k_43h`；账号
  `a094f4d5`；模式 HPC/Slurm；分区 `hx1hdnormal`；节点
  `f11r2n03`；1 DCU、16 CPU / 60 GB；外层 43 h，内部预算
  42.5 h，预计 42、最坏 42.5 卡时。输出
  `runs/n019_official/vocoder_nt_hpc_d5_hpclong72k_20261110`。
- 输入仍为 d4 官方 LibriTTS clean-100 33,236 records、NT speaker
  embeddings、2x feature-matching recipe 和上述 step 72k 完整状态；
  BF16、total batch 16、lr `2e-4`、grad clipping 0、每 2k snapshot。
  launcher SHA256
  `bbde27d090c2fd8eedfd9efdcd38329c2a1f852011936aedf08b8a7f146b1c6c`。
- 04:26:07 从 `step=72001` 恢复；04:26:18 完成首个 generator step；
  随后日志 step `72,040`，loss 有限、约 `0.68 s/step`。
- 父作业此前累计约 `4.835833 h`，旧 66k Job 实际 `0.943333 h`；
  按 50 h 免费额度估算，42.5 h 最坏预算后约剩 `1.22 h` 缓冲。
- 停止条件：checkpoint/recipe/输入 SHA 不一致、loss 非有限、OOM、
  10-15 分钟无进展、达到 42.5 h 内部预算或 43 h 外层墙钟。
  不得重提 Job `1075605`；本轮未使用 d8/d9。

## 2026-11-10 03:55 波形归一化审计、embedding 重试与 68k snapshot

- 发现引用实现 speech-resynthesis 的 `inference.py` 在保存生成音频前
  会执行 `librosa.util.normalize(audio.astype(np.float32))`，而当前
  `n019.anonymize` 直接保存 generator 的 tanh 输出。实测 dev-100
  生成 WAV 的峰值 mean/median/min/max 为
  `0.723603/0.748535/0.310852/0.968994`，87/100 低于 0.9；
  这是此前未审计的具体推理口径差异。
- 已建立 waveform peak-normalization A/B 脚本
  `scripts/evaluate_waveform_peak_normalization_ai.sh`，SHA256
  `036a591cf00cf13894cc967cfe8cc98c49d6b257385b8bfa1367949221f93f39`。
  d6 两次提交均在 task-creation 页面超时且确认未创建任务；改在 d7
  提交成功：Job `2119879611382317057`
  （`n019_peaknorm_d7_20261110_034733`），d7、人工智能/模型训练、
  1 DCU、15 CPU / 59 GB、1 h，预计 0.3、最坏 1.0 卡时。
  它复用 mean32/d5-54k 的 100 个 WAV，只做 peak normalization 后重评
  UTMOS/WhiSQA/WER。输出
  `runs/n019_official/waveform_peaknorm_dev100_20261110_034733`。
- d5 Job `1075605` 于 03:50 写出 68k snapshot，大小
  `56,858,091 B`，SHA256
  `4a844b3af233d0830812cd1ec3e7c492c346479d2abe823c66de08579ce3218f`；
  已经本机中转至 d6
  `tmp/n019_d5_snapshots_20261110/generator_step00068000.pt`，哈希一致。
  已准备 d6 target-conditioned selection（baseline 54k vs 68k），
  输出 `vocoder_target_selection_d5_68k_20261110_0358`；d6 AI
  当时已有两个任务，提交页超时且未创建，配置保持 `submit:false`，
  待占用数下降后重试。
- 逐句 NT embedding 首任务 `2119876813572554754` 在 W-PRO 模型加载后
  约 10 分钟无日志、无 partial，判定落在坏 DCU；03:49 已停止。
  新版脚本加入强制 300 秒 tiny-matmul watchdog，并将
  `--checkpoint-every` 改为 100、启用 `--resume`，SHA256
  `1157c4436f934a517482902497ca377681f6646d20f052340ba5ba00d5113cbc`。
  重试 Job `2119880224430178305`
  （`n019_ntutt_r1_20261110_034959`）已提交；1 DCU、15 CPU /
  59 GB、1 h，预计 0.4、最坏 1.0 卡时。tiny-matmul 已通过并进入
  W-PRO 提取。
- 54k/56k/58k/60k 等权 generator 平均的 dev-100 结果为
  UTMOS `3.164025`、WhiSQA `3.181872`、WER `20.541958%`；
  相对 54k baseline，UTMOS `-0.036804`、WhiSQA `+0.011953`、
  WER `+0.043706 pp`，不满足双 MOS `+0.05` gate，明确不入选。

## 2026-11-10 03:40 clean-100 逐句 NT embedding 提取

- 目的：验证一个尚未排除的实现口径。论文只称 `zspk` 为 speaker
  embedding，没有明确 vocoder 训练时使用 speaker 级预平均向量，还是
  每条训练 utterance 对应的 W-PRO utterance embedding。当前正式
  vocoder 使用 247 个 clean-100 speaker mean；先提取逐句版本，供后续
  受控 A/B，不修改现行正式结果。
- Job：`2119876813572554754`，名称
  `n019_ntutt_20261110_033626`；账号 `a094f4d6`；模式
  人工智能/模型训练；1 DCU、15 CPU / 59 GB；墙钟 1 h，
  预计 0.4、最坏 1.0 卡时。提交前 d6 实时余额
  `22.7611111109` 卡时。
- 输入为 d6 本地 LibriTTS clean-100 33,236 条 unit records 和
  `models/n019_official/wpro`。输出
  `data/n019_official/processed/embeddings/libritts_train_clean_100_nt_utterance_20261110`。
- 启动脚本
  `scripts/extract_libritts_clean100_nt_utterance_ai.sh`，本地与 d6
  SHA256 均为
  `a9948d16ba7fa1e97d7254500f2fb69911f57a6f0f14b899abfb14f40e104789`。
  配置 `configs/scnet_browser_tasks.json` 已回写 `submit:false` 和
  JobID，严禁重复提交。
- 停止条件：records 不是 33,236、W-PRO 缺失、DCU 不可用、
  extractor 非零退出、达到 1 h，或输出不是 33,236 keys / 250-D /
  finite 单位向量。该任务只产生诊断 embedding，不能直接替换正式结果。

## 2026-11-10 03:25 d5 改从 hpclong step 66k 完整状态续训

- 实时检查 d6 hpclong Job `1069636`：03:17 训练日志已到
  step `66,580`，但最后已持久落盘的完整状态是 step `66,000`。
  `last.pt` 为 1,019,512,015 B，mtime `03:11:05`，SHA256
  `5d901423848236ad1cc1541d6e4207b6aa7bc0b809278554d39fe047633293f1`；
  反序列化核对 checkpoint `step=66000`，含 G/D、两个 optimizer、
  scheduler，BF16=true。对应 generator snapshot SHA256
  `c4137dd619174af594746eb38d2daea236cda89cab745c80f2544dfea51791db`。
- 旧 d5 Job `1075139` 从 step 62k 恢复，到日志 step `65,700`
  时仍只有 step `64,000` 的完整持久状态；它不是 hpclong 的
  最新分支。03:19:22 已主动停止，旧目录保留。实际墙钟约
  `00:46:27`，约 `0.774` 卡时。
- 上述 step 66k `last.pt` 已经本机中转至新目录
  `/public/home/a094f4d5/voice_projects/runs/n019_official/vocoder_nt_hpc_d5_hpclong66k_20261110/last.pt`；
  源、本机、目标 SHA256 三项一致。
- 新 Job：`1075605`，名称 `n019_vocd5_66k_44h`；账号
  `a094f4d5`；模式 HPC/Slurm；分区 `hx1hdnormal`；节点
  `f11r3n09`；1 DCU、16 CPU / 60 GB；外层 44 h，内部预算
  43.5 h，预计 43.0、最坏 43.5 卡时。03:24:54 提交，
  03:24:57 启动。
- 提交前 d5 自 2026-11-01 的父作业累计 `17,409 s = 4.835833 h`；
  按 50 h 免费额度估算约 `45.164 h` 可用，43.5 h 最坏预算
  留有约 `1.66 h` 缓冲。
- 输入仍为 d4 官方 clean-100 33,236 条 records、NT speaker
  embeddings、2x feature-matching recipe 和上述 step 66k 完整状态；
  BF16、total batch 16、lr `2e-4`、grad clipping 0、每 2k
  snapshot。输出为
  `runs/n019_official/vocoder_nt_hpc_d5_hpclong66k_20261110`；
  launcher
  `hpc/n019_vocoder_hpc_d5_66k_44h.slurm`，SHA256
  `6bcb0a16bdee9da24709cbd6ad5d89fc0e3fcb3c667af823993de7b2abefb82a`。
- 启动门禁已核对 records 33,236、embedding SHA
  `698d1282...a866`、recipe lock 2x 和健康 DCU tiny matmul。
  03:27:21 已从 `step=66001` 进入训练循环，首个 generator step
  完成于 03:27:32；03:27:48 日志 step `66,020`，loss 有限，
  约 `0.687 s/step`。
  停止条件：SHA/recipe/输入失败、OOM、loss 非有限、10–15 分钟
  无进展或达到 43.5 h 内部预算。不得重复提交。未使用 d8/d9。

## 2026-11-10 02:50 后续 snapshot 选模、质量诊断与 FP32 对照

- d6 Job `2119856802969178114` 的 target-conditioned dev-100：
  baseline `3.0499825764 / 2.9503006965 / 20.541958%`；
  54k `3.2008287084 / 3.1699211434 / 20.498252%`；
  56k `3.0928345442 / 3.1158912763 / 21.197552%`；
  58k `3.0039809632 / 3.0761852801 / 20.629371%`；
  60k `2.7843480694 / 2.9533840865 / 20.279720%`。
  56k/58k/60k 均不满足相对 baseline 的双 MOS 增益和 WER gate，
  54k 仍为唯一入选 checkpoint。
- d5 HPC Job `1075139` 02:48 到 step `63,180`，loss 有限；
  d6 hpclong Job `1069636` 继续运行。
- 零卡时诊断：
  `/public/home/a094f4d7/quality_diagnostic_d5_54k_20261110.json`，
  SHA256 `613bb85ec1fb09261b933e5d03dc5987a92ad9759470d1e013b466762531f377`。
  duration error 对 UTMOS/WhiSQA 的相关为
  `-0.106803/-0.140033`；generated/source spectral flatness
  `0.391745/0.309749`，4–8 kHz 占比 `0.100139/0.076856`。
- FP32 对照初版 Job `2119864403803394050` 在 02:47:20 因 d6 缺
  `verify_training_data_marker.py` 失败，无有效训练。补齐脚本并验证
  33,236 行、records SHA `5d3bb4d7...e50d`、embedding SHA
  `698d1282...a866` 后重试。
- FP32 重试 Job `2119864730527092738`
  （`n019_fp32_d6_62k_r1_20261110_024825`）：d6 AI、1 DCU、
  15 CPU / 59 GB、6 h，预计 5.5、最坏 6.0 卡时；提交前 d6 AI
  余额 `23.6402777776`。输入 step 62k 完整状态、本地 clean-100
  records/embeddings；输出
  `runs/n019_official/vocoder_nt_hpc_d6_fp32_from62k_20261110`。
  配置 `configs/scnet_d6_fp32_from62k.json` 已设 `submit:false`
  并记录 JobID。首轮启动已通过数据和 recipe 门禁，进入 DCU
  preflight。
- `run_vocoder_ddp.sh` 新增可选 resume SHA256 门禁，远端/本地
  SHA256 `1486f5a369bb1b80aba9262df4dbc5a1481efa8a85a8108668e7bb82c1852614`。
  新增 `scripts/analyze_full_eval_quality.py`，只做零卡时诊断。
- 已生成 d5 54k/56k/58k/60k 等权 generator 平均，
  SHA256 `6e24048106cd2946aaf2c273101299c7613dcbece4656c1e1cd68ac6bdbdfa62`。
  已提交 d6 A/B Job `2119865770425077762`
  （`n019_avg5460_20261110_025233`）：1 DCU、15 CPU / 59 GB、
  1.5 h，预计 0.7、最坏 1.5 卡时；只比较 54k baseline 与平均权重，
  使用同一 dev-100、target map、duration 和三项 evaluator。输出
  `runs/n019_official/vocoder_target_selection_avg54_60_20261110_025233`。
  配置已设 `submit:false` 并记录 JobID，不得重复提交。
- FP32 Job `2119864730527092738` 于 02:58:18 从 step `62,001`
  正常进入训练，实测约 `1.13 s/step`，loss 有限。d5 BF16 Job
  `1075139` 继续约 `0.68 s/step`。

## 2026-11-10 02:35 d5 改从 hpclong step 62k 续训

- d6 hpclong Job `1069636` 仍在运行；02:26 日志到 step
  `62,580`，最新完整持久 checkpoint 为 step `62,000`。
- 源 checkpoint：d6
  `runs/n019_official/vocoder_nt_hpc_ft14k_long_20261109/last.pt`，
  1,019,512,015 B，SHA256
  `a928093e2c603feaf9501c9056f7b4210ebbc1a9e744be3ea4cedeb46a064c8e`；
  已验证 step `62,000`。
- d5 旧 Job `1074023` 从 52k 启动，实际推进到日志 step
  `60,820`、持久 step `60,000`；02:28:01 主动停止，保留旧目录，
  实际墙钟 `1:46:15`、约 `1.771` 卡时。
- 新 Job：`1075139`，名称 `n019_vocd5_62k_45h`；账号
  `a094f4d5`；模式 HPC/Slurm；分区 `hx1hdnormal`；节点
  `f11r1n05`；1 DCU、16 CPU / 60 GB；外层 45 h，预计
  44.5、最坏 45.0 卡时。
- 提交前 d5 自 2026-11-01 的 `sacct` 父作业累计约 14,616 秒
  （4.06 h），按 50 h HPC 免费额度估算余额约 45.94 h；
  新任务最坏 45.0 h 可覆盖，但只剩约 0.94 h 余量。
- 输入：d4 官方 clean-100 33,236 条 unit records、NT speaker
  embeddings（SHA256 `698d1282...2a866`）、上述 step 62k
  完整断点、已锁定 2x feature-matching recipe。配方为 BF16、
  total batch 16、lr `2e-4`、grad clipping 0、每 2k 保存。
- 输出：
  `runs/n019_official/vocoder_nt_hpc_d5_hpclong62k_20261110`；
  日志
  `logs/n019_official/n019_vocd5_62k_45h_1075139.out`。
- 本机中转目标 checkpoint 的 SHA256 与源一致；launcher
  `hpc/n019_vocoder_hpc_d5_62k_45h.slurm` SHA256
  `cb6027cba34efb1636da9c5fddf87828612e11166badf446e86649f628eff116`。
- 02:35:26 已从 step `62,001` 完成首个 generator step并进入
  step `62,002`；无 OOM、无非有限 loss。停止条件为
  checkpoint/recipe/输入 SHA 校验失败、OOM、loss 非有限、
  10 到 15 分钟无进展或达到 44.5/45 h 预算。不得重复提交。
- 本轮未使用 d8/d9。

## 2026-11-08 23:00 论文对齐训练准备

- 2026-11-08 23:01 实时余额：d6 `37.1194444443`、d7
  `20.8763888886` 卡时；当前没有运行中的 GPU 训练或评测。
- d6 LibriTTS train-clean-100 下载已恢复为单登录节点 16 路
  断点续传，使用共享 `flock` 防止 `zz-login01` / `zz-login02`
  重复写分片。22:55 时保存的分片总量约 `3.14 GB`；该下载不占
  卡时。完成条件为 exact size `7,723,686,890` 和 MD5
  `4a8c202b78fe1bc0c47916a98f3a2ea8`。
- d6 finalizer 已以独立 session 启动；下载完成后自动解压、
  核对 `33,236` 个 WAV、把 `unit_records.jsonl` 的 d4 音频路径
  改写为 d6 本地路径，并验证 33,236 条 audio/codes/codebook。
  输出标记：
  `/public/home/a094f4d6/voice_projects/logs/n019_official/d6_training_data_ready.json`。
- 2026-11-09 00:32 d6 finalizer 已完成：archive size
  `7,723,686,890`、MD5
  `4a8c202b78fe1bc0c47916a98f3a2ea8`、WAV `33,236`；
  `unit_records.jsonl` SHA256
  `5d3bb4d7bc41cfd973d9313b84b3faae32c3a3abcb572a03153badfa7669e50d`，
  records=`33,236`、missing=`0`，embeddings SHA256
  `698d128292e8abbdb0db5d39301539cfc80184b8982133566ba3bf8b6492a866`。
- 已提交 d6 Job `2119469373940383745`，名称
  `n019_voc2x_lr2e4_20261109_003725`；d6、
  人工智能/模型训练、113 组、1 DCU、15 CPU / 59 GB、
  2 h，预计 1.75、最坏 2.0 卡时；提交前 d6 余额
  `37.1194444443`。输入为 clean-100 unit records / NT speaker
  embeddings / training recipe lock；输出
  `runs/n019_official/vocoder_nt_2x_lr2e4_fresh_20261109_003725`。
  启动后已通过 `N019_LR2E4_RECIPE_OK`，配置已回写 JobID 并设
  `submit:false`，严禁重复提交。
- Job `2119469373940383745` 于 2026-11-09 01:11:35 失败：
  路径校验、recipe、tiny-matmul、mel/HuBERT preflight 和
  `meta.json` 都成功；`n019.vocoder` 在首个训练 step 前
  `SIGSEGV`，`training_log.jsonl` 为 0 字节，无 loss/checkpoint。
  实际墙钟约 0.567 h、1 DCU，约 0.567 卡时。配置保持
  `submit:false`，不重提该 Job。
- 2026-11-09 01:14 d6 实时余额 `36.7458333332`。已提交故障隔离
  Job `2119478599321141249`，名称
  `n019_vocfault_20261109_011405`；d6、1 DCU、15 CPU / 59 GB、
  15 分钟，预计 0.12、最坏 0.25 卡时。输入为官方 clean-100
  records/embeddings 的前 16 条 smoke 子集和当前代码；输出
  `runs/n019_official/vocoder_fault_isolation_20261109_011405`。
  配置已回写 JobID 并设 `submit:false`，严禁重复提交。
- 停止条件为数据/路径/recipe/checkpoint 门禁失败、loss
  NaN/Inf、10 到 15 分钟无日志、DCU 错误或 2 h 墙钟。
- 已新增 continuation launcher
  `scripts/launch_vocoder_nt_2x_lr2e4_continue_ai.sh`，只从同一
  run 的 `last.pt` 恢复，启动前验证 lr=`2e-4`、grad clipping=`0`
  和 recipe 一致。后续分段训练不得恢复旧 8e-4 optimizer state。
- 针对首次 33,236 条 NFS 路径校验约 40 分钟的问题，新增
  `scripts/verify_training_data_marker.py` 和
  `N019_SKIP_PATH_VERIFY=1`。续训仅在当前 records 行数、
  records SHA256、embeddings SHA256 与 finalizer marker 完全匹配时
  跳过逐路径检查；fresh run 仍做完整校验。已把新逻辑放到独立
  `code/n019_official_lr2e4_resume`，不修改正在运行的 fresh 代码目录。
- 40-speaker VPC dev-100 已从 d6 经本机中转至 d7；bundle SHA256
  `f546621dfac5cbcf439236ee6c7175c97288dac74632b591d464ee894d022ab0`。
  d7 重写后 manifest/unit-records SHA256 分别为
  `20a62e8e6a1b3cd47f104de934114e77330871742c6a7bff476c916e942ed9cd`
  和 `95f4efd9e8ba146a3c3c82d9daf13063a8b1c571f9a71f4cda6bf2c608a5f85c`；
  100 条记录的 audio/codes/codebook 全部可读。

## 2026-11-08 2x vocoder step 16k 续训

- 账号：`a094f4d4`；模式：人工智能/模型训练；Job
  `2119273319220133890`；任务名
  `n019_voc2x_cont16k_20261108_113823`。
- 资源组：`113 组`、异构加速卡BW、2 DCU、15 CPU / 59 GB
  per card；1.7 h 墙钟，预计 3.2、最坏 3.4 卡时；提交前
  d4 余额 `3.8683333333`。
- 输入：上一轮 step 16000 完整训练状态
  `vocoder_nt_2x_diag/last.pt`，SHA256
  `6c0837065c1612578d21285127c7c1e8152e2bd7e7e1d19d3f0197a7ab97a0f4`；
  clean-100 unit records、NT speaker embeddings、2x recipe lock。
- 输出：
  `/public/home/a094f4d4/voice_projects/runs/n019_official/vocoder_nt_2x_cont16k`。
  由新 helper
  `scripts/launch_vocoder_nt_2x_continue_ai.sh` 先将源
  `last.pt` 复制到新目录并校验哈希，再以同一 G/D/优化器状态
  从 step 16000 续训到 step 33000，每 2k 保存 generator
  snapshot；不覆盖原 `vocoder_nt_2x_diag`。
- 停止条件：源/目标 checkpoint SHA256 不一致、输出目录非空、
  loss NaN/Inf、10–15 分钟无日志、DCU/内存/存储错误，或达到
  1.7 h 外层墙钟。配置已记录 JobID 并设 `submit:false`，
  严禁重复提交。
- 2026-11-08 12:26 在节点 `10.6.15.34` 完成 watchdog、数据路径
  校验、HuBERT preflight 和 DDP 初始化，开始有效续训；12:28
  已到 step `16320`，loss 有限，约 `0.35 s/step`，确认使用
  2 DCU 而非 CPU。由于 NFS 路径校验耗时约 26 分钟、完整
  preflight 合计约 48 分钟，6000 秒外层 timeout 预计在
  13:18:36 结束本次任务，实际约到 step 25k。
- 2026-11-08 13:18 外层 timeout 按预期 SIGKILL，平台状态失败；
  有效训练从 16k 推进到日志最后 step `24760`，elapsed
  `0.88252 h`，loss 全程有限。实际墙钟约 1.667 h、2 DCU，
  约 3.33 卡时。
- 持久 `last.pt` 为 step `24000`，SHA256
  `7db8b51de5400b00c1fd873a7d7500d689ca391084422c908e3d2704f8811e4f`；
  snapshots `18000/20000/22000/24000` SHA256 为
  `a784e78e4202de2728d3bbb837c56fea6f2579014101eb018e899ef58bb5b109`、
  `c54ce9ad9810bfc1662868d8214e730e5d5f197a9193710836b30d912c3261b3`、
  `0cba4876dd92fb97839eab60352c66b1742ac74d5f76f98d98cc81c731c28b70`、
  `d2c2612cb782908c791b0ac507c3166cdb219b899e8289591ba54b2932894fec`。
  `generator_final.pt`、`final_sha256.txt` 未生成；旧 checkpoint 均未覆盖。
  不得重提该 Job，下一步是 dev 100 句 snapshot selection。
- 2026-11-08 零卡时准备完成：在 d4 构建固定 dev-100 的自包含选模
  bundle，包含 100 条 audio/codes/transcript、manifest、unit records、
  k-means codebook 和 speaker embeddings，共 304 个文件、
  `29,019,329` bytes。bundle tar SHA256
  `194596fd40eeed3a976de94cbe0804733a253277516ba7fa3f9742d0ff483d39`；
  经本机中转后 d7 解包并逐项 SHA256 验证通过。
- d7 的 `tmp/n019_2x_selection_pool_20261108` 已含
  step `14000/18000/20000/22000/24000` 五个 checkpoint，哈希分别为
  `343b3a4117b69c72c3b1a2c4fbe69e6c10830af0caccc950e988af9f1828cf45`、
  `a784e78e4202de2728d3bbb837c56fea6f2579014101eb018e899ef58bb5b109`、
  `c54ce9ad9810bfc1662868d8214e730e5d5f197a9193710836b30d912c3261b3`、
  `0cba4876dd92fb97839eab60352c66b1742ac74d5f76f98d98cc81c731c28b70`、
  `d2c2612cb782908c791b0ac507c3166cdb219b899e8289591ba54b2932894fec`。
- 提交前 d7 实时余额 `23.0988888886` 卡时。2026-11-08 已提交
  Job `2119366739818729474`，名称
  `n019_vocsel_2x24k_20261108_174936`；d7、1 DCU、
  15 CPU / 59 GB、1 h，预计 0.45、最坏 1.0 卡时；固定 100 句
  source reconstruction，评 UTMOS/WhiSQA/WER，输出
  `runs/n019_official/vocoder_selection_2x24k_20261108`。
  配置已设 `submit:false` 并记录 JobID，严禁重复提交。
- 用户已授权后续实验在核对余额并记录资源计划后自行提交；
  仍需遵守禁止重复提交、超额卡时和无计划实验的约束。
- 选模 Job `2119366739818729474` 启动后发现 d7 helper 仍为旧版：
  Kaldi `text` 只有 ID，baseline WER 无效（`2260%`）；baseline
  UTMOS/WhiSQA `2.1344790483/2.1209076747` 正常。已同步修正版
  helper（SHA256
  `72f691aafa1a29a469c9f28be005f7127559c388a0f6d84f1a1f31dc5f611baa`）。
  当前 Job 只保留 reconstruction/UTMOS/WhiSQA/WAV；完成或超时后用
  `N019_SELECTION_RERUN_WER=1` 只重算 100 句 WER，禁止使用本 Job
  当前的无效 WER 或 selection 排名。
- 已准备 `d7-vocoder-selection-2x24k-rerun`，固定同一输出目录：
  d7、1 DCU、15 CPU / 59 GB、1 h，预计 0.45、最坏 1.0 卡时；
  复用 100 句 WAV/UTMOS/WhiSQA，补齐未完成 snapshots，并根据
  `*.normalized.txt` 重算五个候选 WER。当前 `submit:false`；
  等 Job `2119366739818729474` 结束后再提交。
- 首轮 Job 在 18:44:47 被 3300 秒外层墙钟终止；baseline/14k
  的 reconstruction 和两项 MOS 已完成，18k 完成
  reconstruction+UTMOS；WER 均为旧脚本的无效值。
  baseline UTMOS/WhiSQA `2.1344790483/2.1209076747`，
  14k `2.6693476605/2.4236758664`，与上一轮一致。
- 18:46:41 已提交修正版续跑 Job `2119381103774814210`
  （`n019_vocsel_2x24k_rerun_20261108_184641`）：d7、1 DCU、
  15 CPU / 59 GB、1 h，预计 0.45、最坏 1.0 卡时；提交前余额
  `22.928333333`。复用同目录 WAV/MOS，补 18-24k 并重算
  五个候选真实 WER。配置已设 `submit:false` 并记录 JobID。
- `2119381103774814210` 于 19:41:51 达到 3300 秒外层墙钟后
  失败；没有重提旧 Job。完成结果：
  baseline `2.1344790483 / 2.1209076747 / 21.5909090909%`、
  14k `2.6693476605 / 2.4236758664 / 21.1101398601%`、
  18k `1.3242171955 / 1.9122492060 / 20.6730769231%`、
  20k `2.1469291484 / 2.1976736963 / 20.4108391608%`
  （UTMOS / WhiSQA / WER）。18k 无可用 MOS 收益，20k 只部分
  恢复，14k 仍是当前最佳 dev-100 候选。
- 22k 只启动 reconstruction，未写 WAV/JSON；24k 未启动。
  2026-11-08 21:25 实时余额 d7 `21.2652777775` 卡时，已提交
  Job `2119421417803563009`，名称
  `n019_vocsel_2x24k_tail_20261108_212651`。资源组 `113 组`、
  1 DCU、15 CPU / 59 GB、2 h，预计 1.4、最坏 2.0 卡时。
  输入为自包含 dev-100、22k/24k checkpoint、已有四个候选和固定
  MOS/WER 资产；输出仍为
  `runs/n019_official/vocoder_selection_2x24k_20261108`。
  停止条件为旧候选不完整、checkpoint 哈希不符、任一计数不是
  100、非有限指标、evaluator 非零退出、DCU/存储错误或 2 h
  墙钟。配置已回写 JobID 并设 `submit:false`，严禁重复提交。
- `2119421417803563009` 已完成；22k
  `2.5313126397 / 2.3560563654 / 20.8479020979%`，24k
  `2.5692791879 / 2.3806050718 / 20.4545454545%`
  （UTMOS / WhiSQA / WER）。两者均低于 14k 的
  `2.6693476605 / 2.4236758664 / 21.1101398601%`，最终选择
  `generator_step00014000.pt`。
- 2026-11-08 上游训练审计：speech-resynthesis commit
  `dbb92c8ddeb081e711adbe9a75714027cd447532` 使用
  `learning_rate=2e-4`、单卡 batch 16、无 generator gradient
  clipping。旧 N019 实现误用 `8e-4`、2 DCU DDP batch 32、
  clipping 5.0，已全部修正并增加机器可读证据。旧 4k/76k/102k
  与 2x 14k–24k 保留为历史/诊断，不得称为论文对齐配方。
- d6 已同步版本化代码 `code/n019_official_lr2e4`，目标测试通过。
  d6 的 unit codes、speaker embeddings、k-means codebook 与 d4
  canonical 哈希一致；正在后台下载官方 LibriTTS train-clean-100
  音频，expected size `7,723,686,890` bytes、MD5
  `4a8c202b78fe1bc0c47916a98f3a2ea8`。下载和校验完成前不提交
  训练任务。
- 2026-11-08 21:55 实时余额：d6 `37.536111111` 卡时。d6 的
  unit codes、speaker embeddings、codebook 已与 d4 canonical
  哈希一致；VPC `libri_dev` 的 40-speaker、100 句平衡子集已
  从 d4 经本机中转，tar SHA256
  `8de9fb0f88e9558e0f3bed88d1c9aea68b853977feb9db583ec42a28803aa018`，
  d6 manifest SHA256
  `887ba1221e72e92a79e51bac7d589be2af5cf55ea80a2e7347e2c8c93ad72e32`。
- 准备提交 d6 选模资产任务，名称
  `n019_dev100_assets_d6_{timestamp}`，人工智能/模型训练、
  资源组 `113 组`、1 DCU、15 CPU / 59 GB、30 分钟墙钟，
  预计 0.1、最坏 0.5 卡时。输入为 VPC dev-100 raw bundle、
  固定 k-means codebook、HuBERT、W-PRO 和
  `code/n019_official_lr2e4`；输出
  `data/n019_official/processed/selection_dev100_vpc_units_20261108`。
  停止条件：manifest/codebook/model 哈希不符、unit records
  不是 100、speaker embeddings 不是 40 个 250-D 有限单位向量、
  DCU tiny-matmul/内存/存储错误或 30 分钟墙钟。
- 已提交 Job `2119429079874945025`，名称
  `n019_dev100_assets_d6_20261108_215718`；规格与上项一致，
  配置已回写 JobID 并设 `submit:false`，严禁重复提交。当前
  LibriTTS 下载仍在后台进行，不占卡时。
- 首次 dev100 资产 Job `2119429079874945025` 在 GPU watchdog
  通过后失败：转存的 manifest 仍保留 d4 音频绝对路径，d6 的
  `sf.read` 报 `LibsndfileError: System error`。已保留原 manifest
  为 `manifest.source_d4.jsonl`，重写 d6 `audio` 路径并逐项验证
  100 个文件可读；新 manifest SHA256
  `26de28d291efc45d615c13ec968dfc85760e86cba1a70a1395100d1a09d4a20a`。
- 2026-11-08 22:10 实时余额 d6 `37.3924999999` 卡时。已提交重试
  Job `2119432607435173890`，名称
  `n019_dev100_retry1_20261108_221118`；规格为 1 DCU、
  15 CPU / 59 GB、30 分钟，预计 0.1、最坏 0.5 卡时，输出改为
  `selection_dev100_vpc_units_20261108_retry1`，不覆盖失败输出。
  配置已回写 JobID 并设 `submit:false`，严禁重复提交。
- 重试 Job `2119432607435173890` 已成功提取 100/100 个 unit
  records 和 codes，但随后 W-PRO 导入失败：版本化代码目录最初
  未包含 `compat/torchaudio`，环境报
  `ModuleNotFoundError: No module named 'torchaudio'`。units 保留，
  不重算。
- 已把 `compat/` 和 `vendor/UTMOS22-demo` 纳入版本化代码归档，
  远端验证 `torch 2.9.0` / `torchaudio 2.9.0+scnet-compat` 可导入；
  `vendor/WhiSQA` 通过同账号旧目录只读符号链接复用。
- 正在准备 retry2，只复用现有 100 个 codes 并运行 speaker
  embeddings；1 DCU、15 CPU / 59 GB、30 分钟，预计 0.05、最坏
  0.5 卡时。输出仍写 `selection_dev100_vpc_units_20261108_retry1/embeddings`。
- 已提交 retry2 Job `2119434958879289346`，名称
  `n019_dev100_retry2_20261108_222040`；配置已回写 JobID 并设
  `submit:false`，严禁重复提交。现有 codes 为 root-owned，
  容器以 root 运行可读；成功结束时脚本统一 chown 回账号属主。
- `2119434958879289346` 已完成：复用 100 个 unit codes，
  W-PRO speaker embeddings 共 40 个 250-D vectors，全部 finite
  且 L2 norm≈1。`verify.json` SHA256
  `688b1014c096013c2ffe63b79cc3c14522e3ee26435516f6b00ad35bdd70dd72`。
  输出
  `selection_dev100_vpc_units_20261108_retry1` 已 chown 回账号属主。

## 2026-11-08 DU-pred-nt-2x14k 完整复评

- 账号：`a094f4d7`；模式：人工智能/模型训练；Job
  `2119203372156080129`；任务名
  `n019_2x14k_resume_20261108_065849`；节点 `10.6.15.47`。
- 规格：1 DCU、15 CPU / 59 GB、2 h；原计划预计 0.75、最坏
  2.0 卡时。实际科学流程约 21 分钟，`0.35` 卡时。
- 输入：step 14000 generator，SHA256
  `343b3a4117b69c72c3b1a2c4fbe69e6c10830af0caccc950e988af9f1828cf45`；
  source/unit/target map 各 1,934；843-key target-speaker
  mean-L2 embeddings；duration/ASR/UTMOS/WhiSQA 固定资产。
- 输出：`data/n019_official/anonymised/libri_test/DU-pred-nt-2x14k`、
  VPC suffix `_n019_2x14k`、
  `runs/n019_official/eval/du_pred_nt_2x14k`。
- 结果：WER `6.509331659151875%`、UTMOS
  `2.8773497233962817`、WhiSQA `2.863154954661258`。
  相对论文 `7.41 / 3.63 / 3.69` 为
  `-0.9006683408481253 pp / -0.7526502766037182 /
  -0.8268450453387421`；相对旧 ext102k 为
  `-0.245419781975914 pp / +0.2631017239658391 /
  +0.1129603277287245`，三项均改善。
- 产物计数：anon/VPC wav `1934`、enrolls `438`、
  trials_f/m wav `734/762`、trials `11744/9906`、
  WER `1496`、UTMOS/WhiSQA `1934`。
- `quality_metrics.json` SHA256
  `533e82a16ef4abb5231162b20a143f4bcfa7872a72799ae4ffcab03a7a1b48cf`。
  其余哈希记录在 audit 日志末尾。
- 平台状态为 `Error` 的原因仅是脚本末尾 CRLF 产生
  `line 200: $'\r': command not found`；此前所有指标、汇总、计数和
  sha256sum 已成功完成，并打印
  `DU_PRED_NT_2X14K_FULL_QUALITY_COMPLETE`。不得重提该 Job。
- 已移除 helper 脚本中的 CR，并重新同步本地/d7；最终 SHA256
  `9d40c5cbd09e3036957ae3d9708ecc4714bf86cb94fb69c9a2bee1d64c14e35e`，
  d7 `bash -n` 通过。
- 判断：2x14k 是完整复评中的新最佳候选，但 UTMOS/WhiSQA 相对
  论文仍有 `-0.75/-0.83`，不能宣称完全复现。下一步应先做零卡时
  target embedding 口径对比与误差归因，再决定是否需要短程训练或
  其他有明确证据的修正。

## 2026-11-07 质量修复与待提交任务

- 2026-11-07 22:05 实时余额：d3 `1.3774999999`、
  d4 `8.3249999999`、d5 `4.216111111`、d6 `37.536111111`、
  d7 `24.0241666663` 卡时。
- d7 的 2x 任务连续三次失败在训练前路径门禁：
  Job `2119067497001140225` 缺校验脚本；
  `2119068434422919169` 的 unit records 引用 d4 路径；
  `2119069752202182658` 虽允许 root，但 d7 实际无权读取
  d4 的 99,708 个路径。三者都没有有效训练卡时或结果。
- 2026-11-07 22:22 改由 d4 提交 2x 诊断 Job
  `2119073031535542274`，名称
  `n019_voc2x_diag_d4_20261107_222229`。d4、人工智能/模型训练、
  2 DCU、15 CPU / 59 GB per card、2 h，预计/最坏 4.0 卡时；
  提交前余额 `8.3249999999`，可覆盖。输入为 d4 本地
  33,236 条 LibriTTS clean-100 unit records、NT 250-D speaker
  embeddings 和固定 ext102k generator；输出
  `runs/n019_official/vocoder_nt_2x_diag`。d4 已于提交前验证
  全部路径可读、配方锁和 probe 4.0；配置已设 `submit:false`，
  严禁重复提交。
- 2026-11-07 22:34–22:43 d4 训练启动门禁全部通过：
  tiny-matmul、mel、HuBERT 和 DDP 初始化正常，22:42:18 开始
  有效训练；step 700 loss 有限，约 `0.337 s/step`，使用 2 DCU，
  未回退 CPU。
- 2026-11-07 22:55 d4 训练到 step `2100`；首个
  `snapshots/generator_step00002000.pt`（约 55 MB）已成功写出，
  `last.pt` 约 973 MB。snapshot 选模链路具备实际输入。
- 2026-11-08 00:17 Job `2119073031535542274` 被外层
  `timeout --signal=KILL 6900` 终止，平台状态失败；训练日志到
  step `16380`、elapsed `1.58923 h`，loss 有限。保留 step
  2000–16000 八个 compact snapshots 和 `last.pt`，未生成
  `generator_final.pt`/`final_sha256.txt`。不重提旧训练。
- 2026-11-08 00:52 实时余额 d4 `4.4922222221` 卡时。为控制卡时，
  snapshot selection 先做 baseline + step 16000 的 100 句
  speaker-disjoint dev screen。脚本 SHA256
  `cf8b348e5d1944a89a364716f0ebf9bcdec66521acc79ac9f885f76b0d5b1cb6`。
- 2026-11-08 00:54 提交 d4 选模 Job
  `2119111166460579842`，名称
  `n019_vocsel_d4_20261108_005402`。1 DCU、15 CPU / 59 GB、
  1.5 h，预计 0.8、最坏 1.5 卡时；输入 baseline 与 16k snapshot、
  dev 固定 100 句和固定三项指标；输出
  `runs/n019_official/vocoder_selection_20261108_005402`。
  配置已设 `submit:false`，严禁重复提交。
- 2026-11-08 00:55 该 Job 落在已知坏 DCU 节点：
  tiny-matmul watchdog 打印设备后 300 秒 SIGKILL，平台状态失败。
  无 candidate 或指标输出。2026-11-08 01:52 d4 实时余额
  `4.408611111`；重试一次 Job `2119126896895348737`，
  名称 `n019_vocsel_d4_retry1_20261108_015529`，规格 1 DCU、
  15 CPU / 59 GB、1.5 h，预计 0.8、最坏 1.5 卡时；输出
  `runs/n019_official/vocoder_selection_20261108_015529`。
  配置已设 `submit:false`，严禁重复提交。
- 2026-11-08 01:55 重试 Job `2119126896895348737` 正常上卡，
  baseline 100 句 reconstruction、UTMOS `2.1344789516925813`、
  WhiSQA `2.1209082275629045` 完成；随后因 d4 代码目录缺少
  `n019.wer_eval_vpc` 在 WER 启动时报错。实际输出目录
  `vocoder_selection_20261108_015814`。已同步
  `wer_eval_vpc.py`，源/远端 SHA256
  `a9aea2877c93cf04aa5b47327e113b4aef73f898f596399d70033cf572a628f2`。
- 2026-11-08 02:58 d4 实时余额 `4.2452777777`。提交续跑 Job
  `2119143626710753282`，名称
  `n019_vocsel_d4_retry2_20261108_030201`。1 DCU、
  15 CPU / 59 GB、1.5 h，预计 0.6、最坏 1.5 卡时；固定复用
  `vocoder_selection_20261108_015814` baseline 输出，只补 WER
  和 16k candidate。配置已设 `submit:false`，严禁重复提交。
- 2026-11-08 03:40 续跑 Job `2119143626710753282` 完成：
  baseline UTMOS/WhiSQA `2.1344789516925813 / 2.1209082275629045`；
  step 16000 `2.1832057416439055 / 2.1243256732821463`；
  delta `+0.04872678995132418 / +0.003417445719240743`，
  未达到 `+0.05 / +0.05` 门槛。
- 同一任务发现 selection/text 只有 ID，没有参考 transcript，
  WER 2260% 无效。已修脚本，从 LibriTTS
  `*.normalized.txt` 恢复文本，脚本 SHA256
  `72f691aafa1a29a469c9f28be005f7127559c388a0f6d84f1a1f31dc5f611baa`。
- 2026-11-08 03:53 d4 余额 `4.1177777777`，提交 WER-only
  重算 Job `2119157545622589441`，名称
  `n019_vocwer_rescore_20261108_035705`。1 DCU、15 CPU / 59 GB、
  45 min，预计 0.15、最坏 0.75 卡时；复用已有 WAV 和
  UTMOS/WhiSQA，只重算 baseline/16k WER。配置已设
  `submit:false`，严禁重复提交。
- 2026-11-08 04:00 WER 重算完成：
  baseline UTMOS/WhiSQA/WER `2.1344789516925813 /
  2.1209082275629045 / 21.59090909090909%`；
  step 16000 `2.1832057416439055 / 2.1243256732821463 /
  21.11013986013986%`。16k delta `+0.04872678995132418 /
  +0.003417445719240743 / -0.48076923076923 pp`；
  MOS 门槛未过，selection 选择 baseline。`selection.json` SHA256
  `9b100c267adbfa3d3dbbf37aed2b0bfc5936c393d0700b57ebc704b82b4582f8`。
- 2026-11-08 04:54 d4 余额 `4.0533333333`，提交 step 14000
  screen Job `2119172855578009601`，名称
  `n019_vocsel_step14k_20261108_045739`。1 DCU、
  15 CPU / 59 GB、1 h，预计 0.5、最坏 1.0 卡时；复用固定输出
  目录中的 baseline/16k，只新增 14k 候选。配置已设
  `submit:false`，严禁重复提交。
- 2026-11-08 05:00 step 14000 screen 完成：
  UTMOS/WhiSQA/WER `2.6693478274345397 / 2.4236760824918746 /
  21.11013986013986%`；delta `+0.5348688757419584 /
  +0.30276785492897007 / -0.48076923076923 pp`，eligible。
  checkpoint SHA256
  `343b3a4117b69c72c3b1a2c4fbe69e6c10830af0caccc950e988af9f1828cf45`。
  selection.json SHA256
  `f79d746447bfd9055ced6539c4aef212f72ed6aab4f810ca2cc42ac80eafb5c6`。
- 已将 14k checkpoint 经本机中转至 d7，源/目标 SHA256 一致。
  anonymize 脚本 SHA256
  `2d960c5dee704e1af8a9f94a54b2832c9e29d9e68d84160822ab537e9e6da06a`；
  新完整复评 runner SHA256
  `d1cbd176f9930ac8fdd074f80277f99ecf0426ba2e6e54f78832e061e26d7852`。
- 2026-11-08 06:00 d7 余额 `24.0241666663`，提交完整 1,934 句
  复评 Job `2119189556546523137`，名称
  `n019_du_pred_nt_2x14k_20261108_060403`。d7、1 DCU、
  15 CPU / 59 GB、2 h，预计 0.75、最坏 2.0 卡时；输出
  `DU-pred-nt-2x14k`、VPC `_n019_2x14k` 和
  `eval/du_pred_nt_2x14k`。配置已设 `submit:false`，严禁重复提交。
- d4 选模资产已在本账号完成：Whisper-small、Wav2Vec2 配置、
  SpeechBrain ASR local-HF、WhiSQA、UTMOS 和 duration。
  `d4-vocoder-snapshot-selection` 已准备，等待 2x snapshots。
- 2026-11-07 22:49 全量 1,934 句 duration 诊断完成，0 卡时：
  `negative_values=0`、`zero_values=0`、`nonfinite_utterances=0`，
  总时长相对误差 mean `0.0477569`、p95 `0.1259830`；
  `duration_diagnostic_full_1934_20261107.json` SHA256
  `9c5818e6624d32e7788a5b5cae13886845960729f171a9460bdde3b0a5a3784a`。
  暂不重训 duration。
- 已完成零卡时代码修复：2x feature-matching recipe lock、
  `mos_offline` snapshot 选模、target embedding speaker-mean-L2、
  duration 总时长诊断、GPU 300 秒 tiny-matmul watchdog。
- d6/d7 代码已同步，远端
  `scripts/verify_quality_fix_remote.sh` 均通过；2x probe = 4.0，
  配方锁 SHA256
  `370ef79bc7f85a86ea1e25afae903e9993e20c2e4da449d942c80aa12233b7e9`。
- d7 已生成 target-speaker proxy：
  `libri_test_target_nt_speaker_mean_l2_paperfix/nt_target_speaker_embeddings.npz`
  SHA256
  `72e360948e3e8f49fe12c7e6082d67ded9d1477b8dd528745698cb9b0a00f13c`，
  843 keys、250-D、mean-then-L2。
- speaker-disjoint clean-100 split：train 31,245 / dev 1,991；
  dev manifest SHA256
  `963d2146a77910e8356bc6ea98b3be972242a6cbf3fc3221cba96aa3f164c811`。
- 2026-11-07 21:05 实时余额：d3 1.3775、d4 8.3250、d5 4.2161、
  d6 37.5361、d7 24.7708 卡时。下列任务尚未提交，提交时重新核对：
  - `d7-target-embedding-speaker-mean-ab`：1 DCU / 15 CPU / 59 GB /
    1 h，预计 0.35、最坏 1.0 卡时。
  - `d7-vocoder-2x-diagnostic`：2 DCU / 15 CPU / 59 GB per card /
    2 h，预计 4.0、最坏 4.0 卡时；从 ext102k generator 初始化，
    不覆盖旧 checkpoint。
  - `d7-vocoder-snapshot-selection`：1 DCU / 15 CPU / 59 GB / 1 h，
    预计 0.35、最坏 1.0 卡时；仅在 2x snapshot 存在后启动。
- 2026-11-07 21:13 target embedding A/B Job
  `2119055643385360385` 已提交，名称
  `n019_te_spk_ab_20261107_211324`。d7、人工智能/模型训练、
  1 DCU、15 CPU / 59 GB、1 h，预计 0.35、最坏 1.0 卡时；
  固定 100 句、同一 ext102k checkpoint 和 duration predictor，
  只切换 target utterance embedding 与 target-speaker mean-L2。
  输出 `runs/n019_official/target_embedding_ab_20261107_211652`。
  配置已设 `submit:false` 并记录 `submitted_task_id`，不得重复提交。
- 2026-11-07 21:57 target embedding A/B 完成，固定 100 句：
  utterance embedding UTMOS/WhiSQA/WER =
  `2.4527917790 / 2.6547999933 / 8.1640780566%`；
  speaker-mean-L2 = `2.5831683111 / 2.7459385157 / 7.9649542015%`。
  配对差 `+0.1303765321 / +0.0911385223 / -0.1991238550 pp`，
  配对 SE `0.0431365228 / 0.0305995695`。方向和 WER 均支持该口径，
  但绝对增益不足以单独解释论文差距。输出
  `runs/n019_official/target_embedding_ab_20261107_211652`；
  `comparison.json` SHA256
  `bdc43eca3869e18c02ed4aafa4664b58b8f4b29b1d2f6d9712d66e4739ba6bf3`。
- 2026-11-07 21:13–21:17 两次尝试创建 2-DCU `n019_voc2x_diag_*`
  均在浏览器提交表单阶段超时，任务列表确认没有生成 Job；原因是
  2-DCU 表单提交后未跳回列表，具体资源/UI 原因未定。
  `d7-vocoder-2x-diagnostic` 已改回 `submit:false`，等 1-DCU A/B
  结束后最多再重试一次，不连续提交。
- d7 的 2x 尝试只保留失败追溯，不再提交；后续以 d4 Job
  `2119073031535542274` 为准。
- 禁止把上述 proxy、dev 选模结果或旧 1x checkpoint 写成论文正式结果。
  正式 1,934 句复评必须先通过 dev MOS/WER gate，再单独记录。

## 2026-11-04 22:15 代码修正后的 DU-pred-nt 短期计划

- 2026-11-06 23:13：提交 d7 完整 `libri_test` ext102k 质量复评
  Job `2118723529665581057`，任务名
  `n019_ext102k_quality_20261106_231328`。1 DCU、15 CPU / 59 GB、
  2 h 墙钟，预计 0.5、最坏 2.0 卡时；提交前实时余额
  `40.7927777775` 卡时。输入为 step `102000` generator
  SHA256 `62eb5908aae998f50eed1456a8f6a8f606a88c07627c1d92517f0d072c9ff151`、
  1934 条 source/unit/target map、1924 个 target embedding、duration
  paperfix、d7 官方 ASR 和 UTMOS22/WhiSQA。输出
  `anonymised/libri_test/DU-pred-nt-ext102k`、
  `vpc/data/*_n019_ext102k`、`eval/du_pred_nt_ext102k`；只跑
  WER/UTMOS/WhiSQA，不覆盖既有 paperfix 结果。停止条件为输入/SHA/
  行数/ID 不一致、指标非 1934 句、非有限结果、10 分钟无进度、
  DCU/存储错误或达到 2 h。配置已设 `submit:false`。
- 2026-11-06 23:26：上条 Job `2118723529665581057` 失败。1,934
  条匿名化和 `_n019_ext102k` VPC 导出已成功；失败点是 d7 远端
  `wer_eval.py` 旧版不接受 `--model`，日志明确报
  `unrecognized arguments: --model`。已同步本地新版
  `wer_eval.py`，SHA256
  `42011dac54a3801436d1c8e75e5487235001ab3f05129ad6e11f3ea737ee3356`。
  保留原输出，准备同一目录续跑 WER/UTMOS/WhiSQA；不复算已完成 WAV。
- 2026-11-06 23:28：ext102k 质量复评重试 Job
  `2118727181430194177` 已提交，名称
  `n019_ext102k_retry_20261106_232758`。规格仍为 d7、1 DCU、
  15 CPU / 59 GB、2 h，预计 0.5、最坏 2.0 卡时；提交前余额
  `40.6369444442`。输入沿用固定 102k checkpoint，复用已生成的
  1,934 条 WAV/VPC 文件，只续跑 WER、UTMOS22、WhiSQA 和
  `quality_metrics.json`。配置已设 `submit:false`。
- 2026-11-07 00:43：重试 Job `2118727181430194177` 在
  `--resume` 校验阶段 74 分钟无新日志，按 10 分钟无进度停止条件
  从无头控制台停止，最终状态“已停止”，未生成新指标。已有
  1,934 条 WAV 和 VPC split `1934/438/734/762` 完整保留。
  根因是逐文件 resume 校验在 NFS 输出上异常阻塞。启动脚本已增加
  完整输出短路：只在 anon/WAV/VPC 门禁通过时直接进入 WER/MOS，
  不再调用 anonymisation resume。准备 metrics-only 重试，规格
  1 DCU、1 h、预计 0.4、最坏 1.0 卡时；当前余额
  `40.1105555553`。
- 2026-11-07 00:45：metrics-only Job
  `2118746652075986946` 已提交，名称
  `n019_ext102k_metrics_20261107_004521`。d7、1 DCU、15 CPU /
  59 GB、1 h，预计 0.4、最坏 1.0 卡时。任务检测到 1,934 WAV、
  1,934 anon 和 1934/438/734/762 VPC 行数后直接跳过 anonymisation，
  只跑 WER/UTMOS22/WhiSQA。配置已设 `submit:false`。
- 2026-11-07 00:46：metrics-only Job `2118746652075986946`
  已失败。WAV/VPC 短路成功，失败点是 `n019.wer_eval` 把
  SpeechBrain ASR bundle 当作 HF `Wav2Vec2Processor`，目录缺 HF
  tokenizer。新增 `src/n019/wer_eval_vpc.py`，使用 VPC2024 官方
  `InferenceSpeechBrainASR`、`EncoderASR` 和 Kaldi dataset；WER
  官方样本是 enrolls/trials_f/trials_m 去重后的 1,496 句，不是
  1,934 句。2 句 CPU smoke 已通过。准备最终 metrics-only 重试；
  当前余额 `39.3655555553`。
- 2026-11-07 00:53：最终 metrics-only Job
  `2118748742678118401` 已提交，名称
  `n019_ext102k_metrics2_20261107_005339`。d7、1 DCU、
  15 CPU / 59 GB、1 h，预计 0.4、最坏 1.0 卡时。复用完整
  1,934 条 WAV/VPC；WER 改为官方 SpeechBrain `EncoderASR`
  对 1,496 句 ASR 集合评分，UTMOS/WhiSQA 仍为 1,934 句。
  配置已设 `submit:false`。

- 2026-11-06 21:38：d3 paperfix NT vocoder 续训 Job
  `2118550713240682497` 失败。账号 `a094f4d3`、人工智能/模型训练、
  2 DCU、15 CPU / 59 GB 每卡、外层 8 h、内部 7.5 h；提交前余额
  `17.268611111`，实时余额剩 `1.3774999999` 卡时。训练正常到
  step `109160`、elapsed `7.4992857 h`，loss 有限；`19:42:33`
  rank 1/0 的 `ALLREDUCE` 分别等待 `600033/600064 ms` 后超时，
  rank 1 `SIGABRT`。未生成 `generator_final.pt` 和
  `final_sha256.txt`。保留的 `best.pt` 为 step `102000`、epoch
  `97`、validation mel L1 `0.7640142440795898`，SHA256
  `62eb5908aae998f50eed1456a8f6a8f606a88c07627c1d92517f0d072c9ff151`，
  大小 `56,851,575` bytes。不得自动重提，不得覆盖原
  `vocoder_nt_paperfix` checkpoint。
- 2026-11-06 21:45：step `102000` 的 generator-only `best.pt`
  已经本机中转至 d7，源/中转/目标 SHA256 一致，目标
  `runs/n019_official/audit/vocoder_checkpoint_cpu_20261106/checkpoints/paperfix_ext_best_step102000.pt`。
  d7 登录节点正在用 CPU 对固定 25 句做 UTMOS/WhiSQA A/B，占 0 卡时；
  输出
  `runs/n019_official/audit/vocoder_checkpoint_cpu_20261106/ext102k`，
  日志 `voice_projects/tmp/vocoder_checkpoint_ext102k_cpu_20261106.log`。
  该诊断只用于判断是否值得做完整复评，不能替代正式 1,934 句结果。
- 2026-11-06 22:29：step `102000` 的 25 句 CPU A/B 完成，0 卡时。
  UTMOS `2.469762306213379`、WhiSQA `2.703620159626007`。
  相对 main step 76k `2.54448655128479/2.6438219249248505`，
  UTMOS `-0.074724245071411`、WhiSQA `+0.0597982347011565`；
  相对 step 33,999 `2.237066617012024/2.4190483033657073`，
  两项分别提高 `+0.232695689201355` / `+0.2845718562602997`。
  与 main 76k 的配对差值 `t=-0.895/+0.914`（25 句），在噪声内
  基本打平；相对当前正式 step 4k 则仍有大幅提升。因此不能直接替换
  正式全量表，但 102k 已是完整 I/WER/MOS 复评的有效候选。
  `summary.json` SHA256
  `173377556f4c46b42eff6e2d6f93f5be95c378f677ca5dd794bd0dd0657875d5`。
- 2026-11-06 23:00：完成两组 0 卡时归因诊断。相同 25 句、main step
  76k 下，原时长 UTMOS/WhiSQA `2.496909/2.665299`，预测时长
  `2.544487/2.643822`，差异仅为 `-0.047578/+0.021477`，duration
  predictor 不是主要来源。对 25 条已见 LibriTTS train-clean-100
  语音做 source-speaker reconstruction，UTMOS/WhiSQA 仍为
  `2.704474/2.589972`，显示 vocoder 重建本身与论文仍有明显差距。
  诊断摘要 SHA256 分别为
  `c43cb0e8197b5ce4142bc44fe621f325ec22294fa78934e4d80c14328bea1c39`
  和 `962ed3b4a393ad0263bb7362a447908a9f77482e190efe4e7d044a77eecfb831`。
  当前正式 1,934 句 run 的 `run_meta.json` 明确记录
  `vocoder_version=4000`、vocoder SHA256
  `f1735e757ecfc4bfb6a230ae26219058e6aed8bef18656bb2b694cc89ed070d9`。
  同时确认 `feature_matching_loss` 少乘了引用实现的 `2x`，已修正
  `src/n019/hifigan.py` 并新增回归测试；修正后的损失需要新训练，
  不能把旧 checkpoint 当作该配方的结果。

- 2026-11-06 16:48：d3 续训 Job
  `2118550713240682497` 正常到 step `81,720`，elapsed
  `4.75 h`，loss 有限；validation best 更新为 step
  `80,000`、`0.7743873596191406`。`last.pt`/`best.pt`
  时间戳 `16:37`；最终 generator 尚未生成。

- 2026-11-06 15:48：d3 续训 Job
  `2118550713240682497` 正常到 step `71,800`，elapsed
  `3.76 h`，loss 有限；validation best 更新为 step
  `66,000`、`0.7774511575698853`。`last.pt` 时间戳
  `15:37`；最终 generator 尚未生成。

- 2026-11-06 14:50：d3 续训 Job
  `2118550713240682497` 正常运行到 step `61,980`，
  elapsed `2.79 h`，loss 有限；validation best 已在
  step `60,000` 更新为 `0.7811204195022583`
  （原先 step 4k 为 `0.7951396703720093`）。
  `last.pt` 时间戳 `14:49`；`generator_final.pt` 尚未生成。

- 2026-11-06 11:17：checkpoint 诊断的 MOS-only Job
  `2118540599713480705` 已完成，实例 `11:07:00–11:17:57`，
  1 DCU、1 h 墙钟。25 句对照：paperfix step 4k
  UTMOS/WhiSQA `1.248995/1.848322`；main step 76k
  `2.544487/2.643822`。长训练 checkpoint 带来
  `+1.295492/+0.795500`，残余 `-1.085513/-1.046178`。
  该对照不是正式 1,934 句结果，不能替换 `paper_metrics.json`。
  前一生成 Job `2118538301277642754` 在已写完两套 25 句 WAV 和
  `wav.scp` 后，因运行中覆盖 shell 脚本而失败，不重复该生成任务。
  MOS-only Job 的 `summary.json` SHA256
  `22eef2b6f2eea401356fc28efe090435609071d03199fcc5ba1fc0ccb2441aab`。
- 2026-11-06 11:34：从 d3 paperfix `last.pt` 提取 generator-only
  step `33,999` checkpoint，大小 `56,856,123` bytes，SHA256
  `50ce0ecb2e26a20698002a7483be171aefa42997e4318eda6b35f6086d2d4005`；
  已按本地中转规则复制到 d7，源/目标 SHA256 一致。当前正在 d7
  登录节点以 CPU 对同一 25 句做 UTMOS/WhiSQA 诊断，不占卡时；
  输出 `voice_projects/tmp/vocoder_checkpoint_step34k_cpu_20261106`。
- 2026-11-06 11:48：step `33,999` CPU 诊断完成，不占卡时。
  UTMOS `2.237066617012024`、WhiSQA `2.4190483033657073`，
  `summary.json` SHA256
  `68c804efdfa107b703036ce5a0c3dc1d6ffbd81f6cc0327fa08bc1b69824326a`。
  当前排序：step 4k < step 33,999 < main step 76k。
- 2026-11-06 11:46：d3 paperfix NT vocoder 受控续训已提交，
  Job `2118550713240682497`，任务名
  `n019_vocoder_nt_ext_20261106_114645`。规格：人工智能/模型训练、
  113 组、2 DCU、15 CPU / 59 GB 每卡、外层 8 h、内部 7.5 h、
  预计 15.0、最坏 16.0 卡时；提交前余额 `17.268611111`。
  输入固定为原 paperfix `last.pt` / `best.pt`、33,236 条训练记录和
  250-D NT embeddings；输出 `vocoder_nt_paperfix_ext`。停止条件为
  源 SHA256 不符、复制/架构/优化器错误、非有限 loss、DCU/存储错误
  或达到内部/外层墙钟。配置已设 `submit:false`，不得重复提交。
  该 Job 已于 `11:46:52` 启动，源 checkpoint SHA256 门禁和
  `vocoder_nt_paperfix_ext` 复制均通过，当前运行中。

- 2026-11-06 10:57：提交 checkpoint 质量诊断 Job
  `2118538301277642754`，任务名
  `n019_vocoder_ckpt_diag_20261106_105726`。账号 d7、
  人工智能/模型训练、113 组 `hx1hgbwnormal`、1 DCU、
  15 CPU / 59 GB、1 h 墙钟，预计 0.1、最坏 1.0 卡时；
  提交前实时余额 `41.0380555553` 卡时，可覆盖。输入是固定的
  libri_test 25 句、paperfix unit/target、duration 模型、paperfix
  step 4k `best.pt` 与 main step 76k `best.pt`、UTMOS22/WhiSQA；
  输出 `runs/n019_official/audit/vocoder_checkpoint_cpu_20261106`。
  只用于判断 checkpoint 选模对音频质量和 MOS 的影响，不覆盖正式
  `DU-pred-nt-paperfix` 输出。停止条件为固定输入缺失、样本或 MOS
  不是 25、非有限结果、DCU/存储错误或达到 1 h。配置已设
  `submit:false`，禁止重复提交。

- 2026-11-06 10:21：WhiSQA-only Job
  `2118528804410613762` 已完成；实例
  `10:20:09–10:21:54`，1 DCU、1 h 墙钟，最坏 1.0 卡时。
  1,934/1,934 句，mean `1.847028814125209`、stddev
  `0.20560664702048057`、min `1.3582201302051544`、max
  `2.62214332818985`；论文 `3.69`，绝对差
  `-1.842971185874791`。不重跑 UTMOS、E-VPC、W-NT 或 WER。
- 2026-11-06 10:40：零卡时 WAV 抽查发现匿名样本的谐波结构明显劣化。
  3 对样本中均出现宽带/周期性噪声；`1089-134686-0004`
  spectral flatness `0.00024 -> 0.13302`，6–8 kHz 能量占比
  `~0 -> 0.0391`。下一步先做 checkpoint 选模诊断，不直接重训。

- 2026-11-06 10:20：WhiSQA-only Job
  `2118527870481043458` 跑到 1,934/1,934 后因
  `statistics.stddev` 拼写错误在汇总阶段失败，尚无 WhiSQA JSON。
  远端 `eval_mos.py` 已修正，本机/远端 SHA256
  `a746c71b971ac54e7e1291849df4b281a289321aaaa4b96c0d617f0e2434b102`；
  第三次提交 Job `2118528804410613762`，排队中。两次失败任务
  `2118523635443597313`、`2118527870481043458` 保留追溯。
- 2026-11-06 10:16：WhiSQA-only 修复版 Job
  `2118527870481043458` 已提交并排队。此前
  `2118523635443597313` 于 09:59:37 启动即失败，日志确认远端
  `resume_du_pred_nt_paperfix_whisqa_ai.sh` 尚未同步；该失败不产生
  有效指标。现在远端脚本 SHA256
  `713a43bcdc8174b60280abc01b0f06fb3e38419cfedf4f0f68b239081b340700`，
  Whisper snapshot 使用显式本地路径，WhiSQA checkpoint 使用
  364,031,990 bytes 真文件，SHA256
  `2da43d59294c358bdd3f450d0aef5ce57ad20bed3beb34657ef3a795a4766810`。
- 2026-11-06 09:08：Whisper-small 固定快照已下载到 d7 本账号
  HF cache，snapshot
  `973afd24965f72e36ca33b3055d56a652f456b4d`，下载日志
  `audit/whisper_small_download_20261106.log`。新增
  `scripts/resume_du_pred_nt_paperfix_whisqa_ai.sh` 和配置任务
  `d7-libri-test-du-pred-nt-paperfix-whisqa-resume`，只补
  WhiSQA 和汇总；1 DCU、15 CPU / 59 GB、1 h，预计 0.1、
  最坏 1.0 卡时。任务保持 `submit:false`，尚未消耗卡时。
  `bash -n` 与 JSON 校验通过；离线加载门禁将在任务内先执行。
- 2026-11-06 08:05：Job `2118405442188128258` 状态为失败，
  但 UTMOS 子步骤成功。任务日志窗口
  `02:11:54–02:17:37`，约 `0.10` DCU 卡时（最终账单待核）；
  UTMOS 1,934 条 mean `1.2620579278580035`，论文 `3.63`；
  `UTMOS.json` SHA256
  `0aea532589b81e7e374ea82e4675cab62111102933586367fbd510f448047b4c`。
  WhiSQA 在加载 `openai/whisper-small` 时因离线缓存缺少
  `config.json` 失败，未产出 `WhiSQA.json`。该 Job 不重跑；
  下一次只修 Whisper 缓存并续跑 WhiSQA。
- 2026-11-06 02:09：d7 资源恢复，MOS-only 续跑提交成功。
  Job `2118405442188128258`，任务名
  `n019_libri_test_mos_20261106_020935`，初始“排队中”；
  规格 1 DCU、15 CPU / 59 GB、1.5 h，预计 0.25、
  最坏 1.5 卡时。输入仅使用已有 E-VPC/W-NT/WER、1934 行
  `wav.scp`、`anon.jsonl`、UTMOS22 和 WhiSQA 固定模型；
  输出 `runs/n019_official/eval/du_pred_nt_paperfix`。配置已
  设 `submit:false`，后续不得重复提交。
- 2026-11-06 00:06：MOS-only 续跑候选已配置为 d7、1 DCU、
  15 CPU / 59 GB、1.5 h，预计 0.25、最坏 1.5 卡时。连续两次
  无头提交均在资源行门禁停止：华中一区 A 区、异构加速卡 BW、
  113 组显示 `共 0 条`，未创建 Job，实际消耗 0 卡时。未重算
  E-VPC/W-NT/WER；下一次每小时检查在资源出现时只重试一次。
- 2026-11-05 23:54：UTMOS bootstrap retry4 Job
  `2118364969222721538` 已完成，`runtime_ready`、固定 checkpoint
  单句 probe、owner 收尾和 overlay SHA256 总表全部通过。单句
  UTMOS `mean=1.2382493019104004`，`UTMOS_PROBE_OK`；该任务
  `1 DCU / 15 CPU / 59 GB / 1 h`，最坏 1.0 卡时。后续只续跑
  MOS，不重算 E-VPC/W-NT/WER。运行时监控改走 d7 的直连 SSH
  `a094f4d7@zzeshell.scnet.cn:65032`，不启动浏览器。
- 2026-11-05 23:49：UTMOS probe 的 `UTMOS.json` SHA256
  `c9758342eb68043f919939449b41be3bcfc0ed9d7b9d2e7f0a39bd061b47744e`，
  `UTMOS.tsv` SHA256
  `834f116030de28dfdd7456e99501699b777954fb80e1c4074b121a7a525d6f74`，
  `overlay_SHA256SUMS.txt` SHA256
  `bde5cfe5fc569329a773c52271f219ebcbacbaacd53a8bf91348bd97fc4ada0f`；
  三个文件均已归 `a094f4d7`，overlay 仍保留
  `/public/home/a094f4d7/voice_projects/envs/n019_utmos_overlay`。
- 2026-11-05 22:52：retry2 Job `2118351412085760002` 失败，
  实例 `22:35:14–22:38:46`，约 0.059 卡时。fairseq wheel 已成功
  构建和安装；OmegaConf 2.0.6 在 `hydra_init` 遇到
  `dataclasses.MISSING` 校验失败。扩展 py311 补丁后 6 项定向测试
  通过，重提 retry3 Job `2118355893485817858`；规格不变，
  提交前 d7 余额 `42.1758333332`。
- 2026-11-05 22:35：第二次 UTMOS bootstrap retry 已提交，d7 Job
  `2118351412085760002`，初始“排队中”。1 DCU、15 CPU / 59 GB、
  1 h、预计 0.25、最坏 1.0 卡时。启动命令内嵌已测试的 patch
  base64，先覆盖远端旧补丁再运行 bootstrap。
- 2026-11-05 22:20：UTMOS bootstrap retry Job
  `2118344298533593089` 于 `22:08:08` 失败，实际约 0.018 卡时。
  fairseq sdist 下载与 SHA256 校验通过；patch 脚本把
  setup.py 中 3 个 `extensions.extend` 误判为 2 个。已修正为
  删除两个缺源码 CPU 块并保留 CUDA 块，补丁脚本 SHA256
  `7f2459844e403d4715413d7f94c84ffe74e988baf8fbd06e930568b1b52e8226`。
- 2026-11-05 22:07：fairseq sdist 补丁版 UTMOS bootstrap 重提，
  d7 Job `2118344298533593089`，初始“排队中”。1 DCU、
  15 CPU / 59 GB、1 h、预计 0.25、最坏 1.0 卡时；提交前余额
  `42.2533333332`。上一失败 Job
  `2118333381196488706` 保留在 `previous_task_ids`。
- 2026-11-05 22:02：修复 fairseq sdist 构建门禁。固定 PyPI
  `fairseq-0.12.2.tar.gz` SHA256
  `34f1b18426bf3844714534162f065ab733e049597476daa35fffb4d06a92b524`；
  新增 `scripts/patch_fairseq_sdist.py`，仅移除 sdist 中源码缺失的
  `libbase`、`libnat`、`alignment_train_cpu` 三个可选扩展。定向测试
  5 项通过，shell syntax 通过。更新后的 bootstrap SHA256
  `45fc60788e6f6d1ba16c057f8b0ff8d889dfa1489caf13a907c69381f09ccb36`，
  已 SCP 到 d7；待网关限流恢复后核验远端哈希并重提。
- 2026-11-05 21:31：隔离 UTMOS bootstrap Job
  `2118333381196488706` 失败，实例 `21:23:35–21:25:37`，实际
  约 0.034 卡时。PyPI `fairseq==0.12.2` sdist 缺
  `fairseq/clib/libbase/balanced_assignment.cpp`，wheel 构建失败；
  Hydra/OmegaConf/PyTorch-Lightning 第一阶段已安装。正式
  torch/numpy 未被替换，下一步从已有 py311 环境迁入 fairseq。
- 2026-11-05 21:24：隔离 UTMOS runtime bootstrap + 单句 probe
  Job `2118333381196488706` 已提交并运行，账号 d7，人工智能/
  模型训练，113 组 `hx1hgbwnormal`，1 DCU、15 CPU / 59 GB，
  墙钟 1 h，预计 0.25、最坏 1.0 卡时。输入固定
  `vendor/UTMOS22-demo`、镜像 checkpoint 和 1,934 行 paperfix
  `wav.scp`；输出 `envs/n019_utmos_overlay` 与
  `runs/n019_official/eval/utmos_runtime_probe`。停止条件为正式
  torch/numpy 被替换、固定输入缺失、依赖安装失败、非有限或越界
  UTMOS、DCU/存储错误或达到 1 h。提交前 d7 余额
  `42.2872222221`，可覆盖最坏卡时。
- 2026-11-05 19:50：MOS-only Job `2118298417542995969` 已失败。
  实例运行 `19:04:39–19:09:05`，启动门禁、1,934 行检查和既有
  E-VPC/W-NT 输入检查通过，但 UTMOS 作者代码在加载阶段报
  `ModuleNotFoundError: No module named 'hydra'`。实际约 0.074
  卡时；job 配额的 1.5 卡时未用满。E-VPC I/L/WER 与 W-NT I/L
  未改，不得重算。d7 余额 `42.2872222221` 卡时。
- 2026-11-05 19:04：原评测 Job `2118255578293129217` 于 18:39:42
  失败，日志停在 `Missing MOS input:
  vendor/UTMOS22-demo/score.py`。失败前 E-VPC 与 W-NT 已全部完成；
  W-NT L 为 female `42.1511322260%`、male `43.5985133052%`、mean
  `42.8748227656%`（论文 `42.3%`）；W-NT L JSON SHA256 为
  `49d24d47299e311356516a2d9a7802a0c08c537eff8fed48029abb91eb0245e8`
  与 `c6f3102dd02fe7334e4a8240a80ca854d672cd0d9dca4f474493cc061e15e25e`，
  W-NT summary SHA256
  `60018ad55973d45cb663428642165068846a90115788553bb47c6b8268b9fb51`。
  已同步固定 UTMOS22 demo
  源码，tar SHA256
  `bd51d01899f8b1917e5ccdde87cd4bbd60f87fd374efd10907567a1afba742fc`。
  新增 MOS-only 续跑任务 `d7-libri-test-du-pred-nt-paperfix-mos-resume`：
  d7、1 DCU、15 CPU / 59 GB、1.5 h、预计 0.25、最坏 1.5 卡时；
  输入为已保留的 E-VPC/W-NT 结果与 1,934 句匿名音频，输出仍为
  `runs/n019_official/eval/du_pred_nt_paperfix`；停止条件为既有
  I/L/WER 或 W-NT I/L 缺失、MOS 输入缺失、评分不是 1,934 句、
  非有限结果、DCU/存储错误或达到 1.5 h。启动脚本 SHA256
  `dad27507a10600fc49e01f725358de5f4d30346037db884c664328d930a5fb96`。
  提交时余额 `43.0227777777`；Job `2118298417542995969` 已提交并于
  19:04:39 启动，当前“运行中”，已通过输入门禁并开始 UTMOS。
- 2026-11-05 17:37：Job `2118255578293129217` 的 W-NT I 完成，
  female `39.9397730827%`、male `42.3170581460%`、mean
  `41.1284156144%`；论文 mean `39.9%`，绝对差 `+1.2284%`。
  两个结果 JSON 的 SHA256 为
  `a2792c584c4490c02327133ed21ba369549ccf75716b3a6492c40c323021c2bd`
  与 `5fe47ebd58501d072f6cb71451e7495ab3853d8504a6fb732a58c86764a9d3f0`。
  W-NT L 正在运行；任务总状态仍为“运行中”，d7 余额
  `44.0227777777` 卡时。
- 2026-11-05 16:33：Job `2118255578293129217` 运行中。E-VPC pre
  实测 I `47.473%`、L `45.8775%`、anon WER `10.333%`；论文为
  `47.2/47.9/7.41`。I 在 0.5 容差内，L 与 WER 超容差，当前
  `DU-pred-nt-paperfix` 不能记为通过。`vocoder_nt_paperfix` 训练
  到 step `34,000` 后按 patience 15 停止，但 `best.pt` 是 step
  `4,000`；这是目前最可疑的正式 checkpoint 选模问题。待 W-NT 与
  MOS 完成后再决定续训步数和评测方案，不直接复用旧 main checkpoint。
- 零卡时代码审计：本地 `111 tests OK, skipped=3`（缺 librosa）；
  d7 官方环境 `107 tests OK, skipped=0`，`compileall` 通过。d7
  与本地源码仅 `duration.py` 未同步 launch metadata 修复；当前 eval
  不调用该文件，评测结束后同步。
- 2026-11-05 16:14：d7 原始语音基线 Job
  `2118253551901843458` 已完成并验收，运行
  16:06:23–16:10:53；female/male EER `8.761%/0.418%`、mean
  `4.5895%`、WER `1.8435020832144284%`。正式
  `DU-pred-nt-paperfix` I/L/WER/UTMOS/WhiSQA 评测 Job
  `2118255578293129217` 已提交并于 16:14:25 启动，当前“运行中”。账号 d7、
  人工智能/模型训练、资源组 113 组 `hx1hgbwnormal`、1 DCU、
  15 CPU / 59 GB、4 h 墙钟、预计 2.0、最坏 4.0 卡时；提交前余额
  `44.8574999999`，可覆盖最坏占用。输入为已验收的 1,934 句
  anonymous/VPC splits、官方 asv_orig/asr 和 W-PRO；输出
  `runs/n019_official/eval/du_pred_nt_paperfix`。停止条件为
  anon/VPC/trials 行数不符、任一 E-VPC/W-NT 条件缺失、MOS 不是
  1,934 句、WER 条件错误、结果非有限、DCU/存储错误或达到 4 h。
  启动脚本 SHA256
  `87d908ac630e6da1736a4309be47c0fb9989322723670325feb4039638a6660a`。
- 2026-11-05 15:20：d7 准备提交 libri_test `DU-pred-nt-paperfix`
  正式匿名化。账号 d7、人工智能/模型训练、资源组 113 组
  `hx1hgbwnormal`、1 DCU、15 CPU / 59 GB、1 h 墙钟、预计 0.25、
  最坏 1.0 卡时；实时余额 `45.3341666667`，可覆盖最坏占用。
  输入为 1,934 条 source/unit/map、1,924 条 250-D target embedding、
  duration SHA256 `8d5153c920058204fe13ebb75b0744703bc0523e70f3a83fbd8b194245a3ba1c`
  和 vocoder SHA256
  `f1735e757ecfc4bfb6a230ae26219058e6aed8bef18656bb2b694cc89ed070d9`；
  输出 `anonymised/libri_test/DU-pred-nt-paperfix` 与完整四个
  `_n019_paperfix` VPC split。停止条件为 ID/行数/checkpoint/
  embedding/WAV/VPC 任一不一致、10 分钟无进度、DCU/存储错误或达到
  1 小时。启动脚本 SHA256
  `2ee96ca0e12c91ddf22038e316a3115279038c9a19fcdf8e6fb634443ada6f2e`。
  Job `2118242604438040578` 已于 15:22 提交，初始状态“部署中”。
- 2026-11-05 15:29：该匿名化 Job 已完成并通过全量验收：运行
  15:22:52–15:29:12，1,934 WAV / 1,934 anon rows / 1,934 VPC rows，
  0 negative duration，抽样 16 kHz mono PCM16，owner 正确。
  `anon.jsonl` SHA256
  `3f9ef37ed014a5debd8372227f042892ea49754a9d80d0e13691a5b38df4f6df`，
  `run_meta.json` SHA256
  `3a27eb38cd285fd77a74ecfcc7b2a7efe72b0b84748c71ffd03055c553b8ecab`，
  VPC `wav.scp` SHA256
  `eec2417bdb0e2b40c4e66c2c98f2fd2348eb5b0ca672211bb9beb549080d2d6d`，
  verification SHA256
  `67355ab731d064ad2bb3b7acc0f3109c40b4eba7966d7b53b81b042749d1cb4d`。

- 2026-11-05 14:33：d7 libri_test 原始语音基线已提交，Job
  `2118230351709052930`，初始页面状态“排队中”。账号 d7、
  人工智能/模型训练、资源组 113 组 `hx1hgbwnormal`、1 DCU、
  15 CPU / 59 GB、2 h 墙钟、预计 0.25、最坏 2.0 卡时；实时余额
  `45.7341666667`，可覆盖最坏占用。输入为官方 libri_test
  1,934/438/734/762、21,650 trials、VPC `asv_orig` 和 `asr`；
  输出 `runs/n019_official/eval/baseline_orig_vpc`，使用独立
  `_n019_orig` 符号链接，不得覆盖匿名化导出。启动脚本 SHA256
  `3d091c3002d6f2b613fc231e31eef074e3c49e7a2f33ac382372278060e43064`。
  停止条件为 split/trial 数不符、ASV/ASR 权重或 cache 缺失、
  baseline EER 与既有 4.5895% 门禁严重不符、evaluator 非零退出、
  DCU/存储错误或达到 2 小时。
  该 Job 于 14:34 在模型加载前失败：环境缺 `pandas`；随后发现
  `pytz`、`pyloudnorm` 也缺失。已在零卡时环境安装
  `pandas==2.2.3`、`pytz`、`pyloudnorm`，保持
  numpy `1.26.4` 和 torch `2.9.0` 不变，并已实际 import
  `run_evaluation.py`。重试 Job `2118234972682821633` 于 14:52
  提交，初始“排队中”，使用完全相同的资源计划和输出目录。该重试
  在 14:52 仍被官方 dependency pin 拒绝，原因是 d7 的
  `vendor/Voice-Privacy-Challenge-2024/run_evaluation.py` 未同步本地
  已有的 `N019_SKIP_DEPENDENCY_CHECK=1` 分支；已同步该文件并确认远端
  第 94 行存在该门禁，numpy/torch 未变。第二次重试 Job
  `2118235252464013314` 于 14:53 提交并排队；该 Job 在
  14:56 因官方 split 的 `wav.scp` 保存相对路径
  `data/libri_test/wav/...` 而失败。已在 d7 的 vendor 根建立
  `data -> /public/home/a094f4d7/voice_projects/data/n019_official/vpc`
  符号链接并确认相对 WAV 路径可解析；正式脚本也已加入同一门禁。
  第三次重试 Job `2118241331310600193` 于 15:17 提交并排队；页面详情
  已确认 ID，抓取结果本身只返回了“任务模式”文本。该 Job 在 15:18
  仍失败：vendor `data` 第一次误指向 `vpc/`，而 split 相对路径实际
  是 `data/libri_test/...`；已改为指向 `vpc/data/`，并确认
  `data/libri_test/wav/1089-134691-0001.wav` 可解析。
  第四次重试 Job `2118242914452033537` 于 15:23 提交并排队。
  该 Job 已越过 format gate，但 ASV 开始后因 d7 的
  `compat/torchaudio` 只有 `functional.py`、没有 `__init__.py` 和
  `transforms.py`，报 `torchaudio.load` 不存在。已从项目固定的
  `torchaudio_scnet_compat.tar.gz` 补齐这两个文件，远端确认
  `torchaudio 2.9.0+scnet-compat` 与 `load` 已存在；现有扩展版
  `functional.py` 未被覆盖。第五次重试 Job
  `2118245146424352769` 于 15:32 提交并排队。
  该 Job 成功完成 ASV：female/male EER 与三次轨迹均为
  `8.761/0.418`，均值 `4.5895%`，与论文 `4.6%` 及既有门禁一致；
  ASR 在加载 SpeechBrain 时因 HF cache 缺
  `facebook/wav2vec2-large-960h-lv60-self` 的
  `config.json`/`preprocessor_config.json` 停止。已从
  `hf-mirror.com` 固定 revision
  `54074b1c16f4de6a5ad59affb4caa8f2ea03a119` 下载两个小文件，
  经本机 SHA256 中转到 d7 HF cache，并在 offline 模式实测
  `feature_extractor_ok 16000`。
  第六次重试 Job `2118249890493542402` 于 15:51 提交并排队。
  第六次 ASV 仍完全一致，但 SpeechBrain 的
  `Wav2Vec2FeatureExtractor.from_pretrained` 使用 hyperparams 的
  显式相对 `cache_dir=exp/asr/wav2vec2_model_checkpoints`，不读取
  `HF_HOME`。已把同一固定 snapshot 复制到 vendor 与该 model dir
  下的对应 cache，并从 vendor 工作目录以显式相对 cache_dir 运行
  offline probe，返回 `feature_extractor_ok 16000`。
  第七次重试 Job `2118251610465116162` 于 15:58 提交并排队。
  第七次 still 在 ASV 后失败：SpeechBrain `_check_model_source` 还会
  访问 Hub（offline 时失败）。已构造非破坏性本地 ASR 模型目录
  `vpc/exp/asr_n019_local`：三个 ckpt 用硬链接，SHA256 与官方
  `exp/asr` 逐一相同；加入固定 `config.json`、
  `preprocessor_config.json`，仅把 `wav2vec2_hub` 改为该本地目录。
  `Wav2Vec2FeatureExtractor`/`Wav2Vec2Config` 本地 probe 返回
  `sample_rate=16000 hidden_size=1024`；原 `exp/asr` 未修改。
  第八次重试 Job `2118253551901843458` 于 16:05 提交并排队。

- 2026-11-05 14:46：d7 libri_test paperfix units 已完成并通过全量
  验收，Job `2118228637901398018` 于 14:27:22 开始、14:46:40
  结束。输出 1,934 records、40 speakers、0 missing code、
  0 shape/value mismatch；`unit_records.jsonl` SHA256
  `407fb8b5bbc7b689702df69419b087058cd142ece5d84eb9a8cc69e1eb369b3f`，
  `units_metadata.json` SHA256
  `f89e57c1745c4decb985437cf73290bfa76daa6cae056943c9d9bd680059bc3d`，
  verification SHA256
  `507dddaa64d2efbe6e6d5f6775d98077c3504a1517485a1e7abb9da772121308`。
- 2026-11-05 14:27：d7 libri_test paperfix units 已提交，Job
  `2118228637901398018`，提交时页面状态“排队中”。账号
  d7、人工智能/模型训练、资源组 113 组 `hx1hgbwnormal`、1 DCU、
  15 CPU / 59 GB、1 h 墙钟、预计 0.5、最坏 1.0 卡时；实时余额
  `45.7341666667`，可覆盖最坏占用。输入为 d7 canonical
  `libri_test.jsonl`（1,934 行、40 speakers）、HuBERT、K=200
  codebook（SHA256
  `a5cc08f707301a1c05da4ab4b00cd280dec66533796a976c3ac4743287eaf446`）；
  输出为 `processed/units/libri_test_paperfix/`。启动脚本 SHA256
  `d7c162b6a49688515de18babf0e7c83219963fce1370d7958b2aefde4c42fa78`。
  停止条件为输入行数/
  speaker 数或 codebook 哈希不一致、非有限 HuBERT 输出、unit/code/
  speaker ID 不一致、10 分钟无进度、DCU/存储错误或达到 1 小时。

- 2026-11-05 14:06：d4 正式 libri_test target embedding Job
  `2118223421122203650` 已提交。账号 d4、人工智能/模型训练、1 DCU、
  15 CPU / 59 GB、3 h 上限、预计 1.5、最坏 3.0 卡时；输入
  1,934 条 `libri_test_paperfix.jsonl`（SHA256
  `d97cafa5790e69c41c14bda6d130148dc982933c22d2fccbdd421b0723e1c432`）、
  205,044 条完整 train-other-500 manifest、d4 本地音频和 W-PRO；
  输出 `libri_test_target_{map,manifest}_paperfix.jsonl` 与
  `libri_test_target_nt_utterance_paperfix/`。提交时 d4 余额
  `9.1908333332` 卡时。
- 2026-11-05 14:58：该 Job 已完成，1,934 条 target map、
  1,924 条唯一 target utterance，embedding 250-D、finite、L2 norm
  正常；输出 owner 为 `a094f4d4`。关键 SHA256：
  map `c497769b4de43824d3a5840d3b497ecd71156222828a69e352140cebc9f4c383`，
  manifest `1a7ae129f4423005c0f883139e73af0bbb4c3af63f20199f313fc58becec0cc8`，
  NPZ `0c2a747220bac2a231cbde981a9d5dfca621750348f87f7ce18fab84994a58b7`，
  metadata `25d07294da0d2343b0f5154727a4ba9b5eb14e0fa7ceb7adab3776a6a192d20f`。
- d7 已从官方 test-clean 重建 1,934 个 libri_test WAV，全部
  16 kHz mono PCM16、duration error 为 0，VPC trials 21,650；
  `audit/vpc_libri_test_verify_20261105.json` 为 `ok=true`。
- 2026-11-05 10:13：paperfix LS360 首跑 Job
  `2118069808953692162` 在 6 h 外层墙钟结束，控制台显示“失败”，
  但日志为 `synthesized=93391/104014 elapsed=21383.2s`，没有
  `anon.jsonl`；按超时处理，不重跑已完成的 93,391 句。确认远端无
  `n019.anonymize`/`anonymize_ls360_remote.sh` writer 后，续跑 Job
  `2118164816636981249` 已提交：账号 d6、人工智能/模型训练、1 DCU、
  15 CPU / 59 GB、外层 2 h、合成停止上限 1.5 h、预计 0.75、最坏
  2.0 卡时。输入输出与首跑完全相同；启动门禁要求 partial 至少
  93,350 行、末行为完整 JSON，结束执行纯 `chown`。第一次续跑
  `2118164816636981249` 因漏传 `N019_ANON_OUT` 在模型加载前失败；
  第二次 `2118165264547106817` 因日志 93,391 与真实落盘 93,375
  相差一个 25 行缓冲，被过严门禁拒绝；两次均未改 partial。第三次
  Job `2118165677283745794` 于 10:17:10 启动，门禁确认 partial
  `93,375` 行、末行 `8119-115686-0028`、`resume=1`，资源不变。
  10:55 完成剩余合成到 `104014/104014`，写出 `anon.jsonl`、
  `run_meta.json`，VPC `wav.scp` 为 `104014` 行。Job 最终因
  `chown` 使用无法解析的组名而失败，数据内容未变；已提交纯 ownership
  Job `2118180309146669057`，1 DCU、15 CPU / 59 GB、2 h、最坏
  2.0 卡时，使用数值 UID/GID。该 Job 于 11:53:35 完成，
  `OWNERSHIP_FIX_COMPLETE`，关键输出已归 `a094f4d6:a094f4d6`；
  全量 `verify_anonymized_outputs.py` 已通过：104,014 WAV/VPC/JSONL、
  104,014 个 source ID 与路径集合一致、0 negative duration、抽样
  16 kHz mono PCM16、owner 正确；`anon.jsonl` SHA256
  `68e450ce18425905a5a5dd3571bc3d9f6cbc161e7e0f3bf249984e01dc1e1941`，
  `run_meta` SHA256
  `0608dad89aaffb1f1288c7cd3a606769914596820d9a6aa7f3d442767a8d97be`。
  提交时 d6 余额
  `39.1208333332` 卡时。最终 launcher SHA256
  `7977c2918067af09ec3fb8dc47a63ad801858ed0515c64b93ef51b2113b72719`。
- 最终审计包名称、大小和 SHA256 以 `artifacts/SHA256SUMS.txt` 为准；
  代码内容已通过 107 项测试和 compileall。
- d3 duration-pred 第一次 Job `2117990487663157250` 在 preflight
  后因输出目录已有 launcher 写入的 `launch.txt` 而以
  `FileExistsError` 退出；已修复 `n019.duration` 对该启动元数据的
  白名单处理，并本地增加回归测试。第二次 Job
  `2117992970106335234` 于 22:50:34 提交，资源不变。
- d6 NT vocoder paperfix Job `2117993296451735554` 于 22:51:54
  提交：2 DCU、每卡 15 CPU / 59 GB、8 h 训练上限、8.25 h 外层墙钟、
  最坏 16.5 卡时；输入
  `libritts_train_clean_100/unit_records.jsonl` 与
  `libritts_train_clean_100_nt/nt_speaker_embeddings.npz`，输出
  `runs/n019_official/vocoder_nt_paperfix`。d6 clean-100 的
  `librispeech_train_clean_100` unit 解包尚未完成，不影响该任务。
- d3 duration-pred retry `2117992970106335234` 于 23:04 完成 30 epochs；
  `best.pt` SHA256 `8d5153c920058204fe13ebb75b0744703bc0523e70f3a83fbd8b194245a3ba1c`，
  `last.pt` SHA256 `466c5a9f5bf05eea181f0a16fc842ae126845dbf50e463c98b2433ce4d6661af`。
  末尾 loss `1.3018964665651633`，输出已纯 chown 到 `a094f4d3`。
- d6 第一次 vocoder 任务失败的根因是 LibriTTS clean-100 记录仍保存
  d4 的 `codes_path`，并非模型/RCCL 算法失败。仅训练所需的
  `codes_path` 和 `kmeans_codebook` 已重写为 d6，备份
  `unit_records.jsonl.pre_d4pathfix_20261104_2308` 保留；全量门禁
  `record=33236, speakers=247, missing=0, mismatch=0`。第二次 Job
  `2118000486608805889` 已提交。
- d6 第二次 vocoder 因同一记录的 `audio` 指向 d4、而 d6 没有
  8.8 GB LibriTTS clean-100 音频而失败。为避免把公共大语料本地中转，
  改在已有完整本地输入的 d3 训练：Job `2118002044909432834`，
  2 DCU、每卡 15 CPU / 59 GB、8 h 训练上限、8.25 h 外层墙钟、
  最坏 16.5 卡时；输入
  `data/n019_official/processed/units/libritts_train_clean_100/unit_records.jsonl`
  和 `..._nt/nt_speaker_embeddings.npz`，输出
  `runs/n019_official/vocoder_nt_paperfix`。已在 23:31 产生
  step 120 训练日志。
- 新增本地输入路径门禁 `scripts/verify_local_unit_records.py`，
  正式 vocoder 启动前会验证全部 `audio/codes_path/kmeans_codebook`
  都是本账号且存在；定向测试 16 passed，全量 107 passed, 3 skipped，
  compileall 通过。该门禁只改变失败前置检查，不改变训练数值。
- d3 `vocoder_nt_paperfix` Job `2118002044909432834` 于 2026-11-05
  02:55 converged：step `34,000`、patience `15`、best step `4,000`；
  `best.pt` / `last.pt` SHA256
  `f1735e757ecfc4bfb6a230ae26219058e6aed8bef18656bb2b694cc89ed070d9` /
  `c40b745ade7caaf29c2abc7a8ea6ad271f2c8a11ae904cd9dc8a9c370276de5c`。
- d3 duration/vocoder checkpoint 已中转 d6，逐项 SHA256 一致并通过
  `load_duration_checkpoint` / `load_generator` 加载检查。
- d6 `DU-pred-nt-paperfix` Job `2118069808953692162` 于 03:51 提交：
  1 DCU、15 CPU / 59 GB、6 h 墙钟、最坏 6 卡时；输入 d6 的 LS360
  manifest/unit/target map/target NPZ、新 duration/vocoder checkpoint；
  输出 `anonymised/ls360/DU-pred-nt-paperfix` 与
  `vpc/data/train-clean-360_n019_paperfix`。
- `scnet_browser_tasks.py` 已修复 Element Plus radio 的可见但不稳定点击，
  并对 filled/submitted 截图超时做非致命处理；本次失败没有创建作业。
- 本轮先修改并验证正式算法差异，尚未为修正版提交卡时任务：
  duration loss 改为有效 unit 归一化的 point/window 求和；
  feature-matching 权重改为 1.0；修复 `pred` duration launcher；
  ECAPA duration 默认改回 LibriSpeech clean-100。
- 本地测试 `107 tests OK, skipped=3`，`compileall` 通过。
- 修正版代码包已生成；最终包名、大小和 SHA256 以
  `artifacts/SHA256SUMS.txt` 为准。
- 下一项 `duration_pred_paperfix`：账号 `a094f4d6`，人工智能/模型训练，
  1 DCU、15 CPU / 59 GB、墙钟 0.25 h、最坏 0.25 卡时；输入
  `processed/units/librispeech_train_clean_100/unit_records.jsonl`，
  输出 `runs/n019_official/duration_pred_paperfix`；30 epochs 正常结束，
  非有限 loss、输入缺失、DDP/DCU 错误或超过 0.25 h 停止。
  已提交 Job `2117986223557693442`，因 d6 缺少
  `librispeech_train_clean_100/unit_records.jsonl` 很快失败；该任务只消耗
  启动级卡时，不作为有效训练。d6 的本训练输入未完整就绪。
- 已增加 d3 重试配置 `d3-duration-pred-paperfix`：d3 已有 28,539 条
  LibriSpeech clean-100 unit records；资源仍为 1 DCU、15 CPU / 59 GB、
  墙钟 0.25 h、最坏 0.25 卡时，输出仍为
  `runs/n019_official/duration_pred_paperfix`。已提交 Job
  `2117990487663157250`，初始状态“排队中”。
- 下一项 `vocoder_nt_paperfix`：账号 `a094f4d6`，人工智能/模型训练，
  2 DCU、每卡 15 CPU / 59 GB、训练上限 8 h、外层 8.25 h、最坏 16.5
  卡时；输入 `processed/units/libritts_train_clean_100/unit_records.jsonl`
  与 `processed/embeddings/libritts_train_clean_100_nt/nt_speaker_embeddings.npz`；
  输出 `runs/n019_official/vocoder_nt_paperfix`。从 step 0 重训，
  每 2,000 步验证，至少 20,000 步，连续 15 次无至少 0.001 改善后
  converged；非有限 loss、DDP 初始化失败、checkpoint/存储失败停止。
- 现有 `vocoder_nt_main`、`duration_pred_main` 和 d6/d7 的正式 LS360
  输出全部冻结，不在修正版中覆盖或改名复用。

## 2026-11-04 14:50 正式 LS360 匿名化

- d6 `DU-orig-nt`：Job `2117871537248841729`，人工智能/模型训练，
  1 DCU、15 CPU / 59 GB、外层墙钟 6 h、最坏 6.0 卡时；输入为
  d6 本账号的 LS360 manifest/unit records/target map/target NPZ、
  final vocoder `best.pt` 和 VPC train-clean-360 `wav.scp`；输出
  `anonymised/ls360/DU-orig-nt` 与
  `vpc/data/train-clean-360_n019_official`。提交前余额 `50` 卡时，
  状态运行中。
- d7 `DU-pred-nt`：Job `2117871585265983490`，同样资源规格；
  额外输入 `duration_pred_main/best.pt`（3,852,057 bytes，SHA256
  `903f75ad44f2b48ac9f181d63b057e19c049efa1d6b94dfeee29c4c6768d42be`）；
  输出 `anonymised/ls360/DU-pred-nt` 与
  `vpc/data/train-clean-360_n019_official`。提交前余额 `50` 卡时，
  状态运行中。
- 两任务共同停止条件：6 h 墙钟、输入/SHA 不一致、非有限输出、
  10 分钟无进度、CUDA/存储错误、导出数不是 104,014。超时后必须
  在同一输出目录 `--resume`，不能另建目录。
- 输入门禁：d6/d7 各 `104,014` records、`921` speakers、0 missing
  code、0 shape/value mismatch；source/unit/target-map/VPC ID 完全
  一致；target NPZ 81,605 条、250-D、finite、L2 正常。
- d6/d7 的 LibriSpeech LS360 原包下载仍运行，14:43 约
  `24.00%` / `29.00%`；不占卡时。
- 14:56 状态复核：d6 `2,241 / 104,014`，d7
  `1,991 / 104,014`，约 `7.0–7.1 句/s`，控制台均“运行中”；
  原包下载约 `25.73%` / `30.11%`，共享盘可用约 `5.2 PB`。
- 15:56 状态复核：d6 `28,081 / 104,014`，d7
  `27,711 / 104,014`，约 `7.2–7.3 句/s`，控制台均“运行中”；
  纯合成预计还需约 2.9 小时。原包下载约 `30.90%` / `35.99%`。
- 16:59 状态复核：d6 `56,341 / 104,014`，d7
  `55,681 / 104,014`，约 `7.2–7.3 句/s`，控制台均“运行中”；
  纯合成预计还需约 1.85 小时。原包下载约 `37.05%` / `43.25%`。
- 18:04 状态复核：d6 `84,261 / 104,014`，d7
  `83,341 / 104,014`，约 `7.2–7.3 句/s`，控制台均“运行中”；
  按当前吞吐预计约 18:50 完成纯合成。原包下载约
  `45.49%` / `53.26%`。
- 18:52 / 18:54：d6/d7 匿名化 Job 先后正常完成，日志均为
  `104,014/104,014`，VPC 导出行数均为 `104,014`。因 AI 容器
  以 root 写文件，输出顶层目录为 `root:root`，需先做纯 `chown`
  才能完整读取和评测。
- 已登记两个纯所有权修复任务：
  - d6 `n019_chown_ls360_du_orig_nt_{timestamp}`：1 DCU、
    15 CPU / 59 GB、墙钟 2 h、预计 1.2、最坏 2.0 卡时；
    目标为 `anonymised/ls360/DU-orig-nt` 与
    `vpc/data/train-clean-360_n019_official`；18:02 余额
    `45.9411111111`，充足。
  - d7 `n019_chown_ls360_du_pred_nt_{timestamp}`：同样资源与
    停止条件；目标为 `anonymised/ls360/DU-pred-nt` 与
    `vpc/data/train-clean-360_n019_official`；18:02 余额
    `45.9086111111`，充足。
- 两任务只改变所有权，不修改数据内容；完成后重算
  `anon.jsonl`、WAV、`wav.scp` 行数和关键 SHA256。
- 两个 chown 已提交：d6 Job `2117936167295954945`，d7 Job
  `2117936206308601857`；均 1 DCU、15 CPU / 59 GB、2 h 上限、
  最坏 2.0 卡时。d6 于 19:16:45、d7 于 19:15:49 完成，
  `OWNERSHIP_FIX_COMPLETE`，实际各约 0.19 h。
- 20:05 全量输出验收通过：d6/d7 各 104,014 WAV、104,014 VPC 行、
  唯一 ID 与 source 完全一致、行路径与文件集合一致、0 negative
  duration、抽样 WAV 为 16 kHz/mono/PCM16、owner 正确。
  d6 `anon.jsonl` SHA256
  `72898a50c94e73cac3c27471c11d8096269a638c5acbb99bfeb76aa9c5668c07`，
  d7 `anon.jsonl` SHA256
  `3a22f4874dd2056417f7ff3de84aa6fce6f54b08b798de099b19b5a14b5d625f`。
- 20:18 起，d6/d7 各自开始零卡时下载官方评测资产：pinned VPC2024
  v2、asv_orig/asr、HuBERT、W-PRO、UTMOS22、WhiSQA；不占 DCU。
  完成后需解包/校验，再准备公开 `test-clean` 的 libri_test 重建。
- 21:05 网络中断状态：d6 VPC repo/data.zip/data_test_tools 完成，
  asv_orig 仅有约 4 MB part；d7 VPC repo/data.zip/data_test_tools
  及 asv_orig 完成，asr 约 687.9 MB part。d6 已改用 16 连接公开
  代理下载器从 asv/asr 继续，并保留 SHA256 校验；d7 从现有 asr
  part 续传。两个操作均不占 DCU。

## 2026-11-04 13:39 实时更新

- 已登记 `d5-anon-pilot-pred-nt-1024`，尚未提交：账号 d5，
  人工智能/模型训练，1 DCU，15 CPU / 59 GB，墙钟 0.5 h，
  预计 0.25、最坏 0.5 卡时。输入为 d5 上正式 LS360 的确定性
  前 1,024 条 subset、完整 unit_records、正式 target map、
  canonical target embedding、duration_pred best 和最终 vocoder
  best；输出独立 pilot 目录，只用于吞吐/端到端门禁，不能写入
  Table 1。停止条件：达到 0.5 h、缺输入、非有限输出、10 分钟
  无进度、CUDA/存储错误。13:39 d5 余额 `4.4113888888`，可覆盖。
- d3 主 vocoder continuation `2117804993484845057`：状态“已完成”，
  13:09:40 停止，step `106,000`，event=`converged`，
  `validations_without_improvement=15`。最终推理 checkpoint
  为 `best.pt`（step 76,000，mel L1 `0.7805652022361755`），
  `56,851,575` bytes，SHA256
  `32f8cbf064b48e1cedb2541c72b34916570e8d3a1da66c39de0ca04a2cfc1477`。
- d3 `last.pt` 为 `1,019,516,431` bytes，SHA256
  `21a7cf2ab6c301ea34cdc890fd5c751e888795eb6b4a247a020465f6c26dd0a3`；
  `last.pt`/`meta.json` 仍为 root-owned，已登记
  `d3-fix-vocoder-main-ownership` 纯 chown 任务，计划如下：
  账号 d3，人工智能模式，1 DCU，15 CPU / 59 GB，墙钟 `0.08 h`，
  预计 `0.04`、最坏 `0.08` 卡时；输入/输出
  `runs/n019_official/vocoder_nt_main`；停止条件为任务仍在运行、
  目标 owner 非 d3、目录缺失或超过 5 分钟。13:39 d3 余额
  `24.5091666666` 卡时，可覆盖。
- d6/d7 LibriSpeech 原始下载在 13:39 约 `18.92%` / `22.33%`；
  两账号 LS360 units 均已解压到 `104,014` 个 code 文件。
- 13:39 实时余额：d3 `24.5091666666`、d4 `9.1908333332`、
  d5 `4.4113888888`、d6 `50`、d7 `50` 卡时。

- d3 主 vocoder continuation `2117804993484845057`：2 DCU、
  8.25 h 外层墙钟、最坏 16.5 卡时；11:50 日志到 step `91,120`，
  `0.35 s/step`，loss 有限。90k 验证 `0.7877435684204102`，
  best step 76k `0.7805652022361755`，patience `7`。
- d5 ownership repair `2117799927749849089`：1 DCU，11:07:15
  “已完成”；实际约 1.056 卡时。104,014 codes、104,014 records，
  所有权抽样与完整 verification 均通过。
- 11:31 实时余额：d3 `28.8313888888`、d4 `9.1908333332`、
  d5 `4.4113888888`、d6 `50`、d7 `50` 卡时。
- d5 评测静态资产已从 d4 经本机中转完成，七项文件 SHA256 一致：
  target NPZ `274dd801...047f1a`、manifest
  `f6986086...cea76b`、duration NT best
  `5fb13836...3be7`、duration pred best
  `903f75ad...42be`。
- 本时段没有提交新的卡时训练任务；d3 主训练和 d5 收尾任务继续。
- r27 代码包已生成并部署 d4/d5/d6/d7 live code：
  `264,355` bytes，SHA256
  `74a6ee2fc02b63db9a1b1783ced4076566a784f11b2305188d5aee2ef15dfee2`；
  d6/d7 各自 `104 tests OK`，包内测试 `101 passed, 3 skipped`。
- d6/d7 无卡时公开数据准备已启动：各自下载
  LibriSpeech train-clean-360（23,049,477,885 bytes，期望 MD5
  `c0e676e450a7ff2f54aeade5171606fa`），11:50 进度约
  `7.67%` / `9.60%`。完成后才执行 MD5、104,014 FLAC 和
  921 speaker 目录验收。
- d6/d7 已收到并通过 SHA256 的本地中转包：
  LibriTTS clean-100 training `12,908,375` bytes /
  `059cca69...214034`；
  LS360 units `64,170,474` bytes /
  `c7a31759...99ccf0`；
  LS360 anon inputs `105,754,520` bytes /
  `e5610ec5...7b6ea0`。LS360 units 的 104,014 文件解压/计数进行中。

## 2026-11-04 01:57 人工智能训练

| 账号 | 任务 | 外部 JobID | DCU | 墙钟上限 | 状态 | 进度 |
|---|---|---:|---:|---:|---|---|
| d3 | LS360 NT target shard 2 | `2117524054988300289` | 1 | 18 h | Failed after final write | `20,401/20,401`，内容已核验 |
| d3 | LS360 NT target shard 3 | `2117524094031339521` | 1 | 18 h | Failed after final write | `20,401/20,401`，内容已核验 |
| d3 | target shard ownership repair | `2117675967040299010` | 1 | 0.08 h | Completed | 纯 `chown` |
| d4 | vocoder DDP pilot | `2117653221587161090` | 2 | 0.25 h | Failed after training | `1,000/1,000`，checkpoint 已核验 |
| d4 | pilot ownership repair | `2117661135441678337` | 1 | 0.08 h | Completed | 纯 `chown` |
| d4 | vocoder NT main window 1 | `2117662083886911489` | 2 | 8.25 h | Max-hours stop | step `78,896`，best step `76,000` |
| d5 | LS360 units resume #1 | `2117591722692628481` | 1 | 6 h | Timeout | `65,904/104,014` |
| d5 | LS360 units resume #2 | `2117685309698658306` | 1 | 6 h | Timeout | `99,600/104,014` |
| d5 | LS360 units resume #3 | `2117781760282206209` | 1 | 6 h | Completed | `104,014/104,014`，921 speakers |
| d5 | LS360 units ownership repair | `2117799927749849089` | 1 | 0.08 h | Submitted | 纯 `chown` |
| d3 | vocoder NT main continuation #1 | `2117802840442572801` | 2 | 8.25 h | Failed | 旧 `spectral.py` 触发 HIPFFT |
| d3 | vocoder NT main continuation #2 | `2117804993484845057` | 2 | 8.25 h | Running | DFT 修复后从 step 78,896 续训 |

- d4 pilot 实测 2-DCU 约 `0.34 s/step`，1000 步训练记录 51 条且全部
  有限；`last.pt` 含完整优化器和调度器，1000-step checkpoint 与
  `last.pt` 均可实际加载。控制台最终失败来自运行中原地更新 shell
  脚本造成的 Bash 续行错位，不是模型数值错误。以后正在执行的代码包
  只读，不在原路径覆盖。
- d4 主训练资源：2 DCU、1 实例、每卡 15 CPU / 59 GB、自动容错关闭、
  8 h 训练窗口、8.25 h 外层墙钟、最坏 16.5 卡时、预计 16 卡时。
  输入为 LibriTTS clean-100 units 和 250-D NT speaker embeddings；
  输出 `runs/n019_official/vocoder_nt_main`。停止条件：达到 8 h、
  400k 硬上限、收敛、非有限 loss、DDP/checkpoint/存储失败。
- 提交时实时余额：d3 `31.8633333332`、d4 `25.7924999999`、
  d5 `15.0494444444`、d6 `50`、d7 `50` 卡时。d4 `/public`
  可用约 39 GB，满足至少 12–15 GB 的 checkpoint 余量要求。
- d3 shard 2/3 已全部核验并中转 d4。四片合并 canonical 输出
  `librispeech_train_clean_360_target_nt_utterance`：81,605 行、
  250-D、finite、L2 norm `0.9999998211860657–1.0000001192092896`；
  NPZ SHA256
  `274dd8012a59ff02a7bcc11921b1be2b731b2c4fcba50603428c7d5c2a047f1a`，
  manifest SHA256 与 canonical
  `f6986086fbf79e0555629ad31fe7acb5893b90db03cef44f60b27fa9e5cea76b`
  一致。
- d5 units 第一 resume 在 6 小时硬上限保存到
  `65,904/104,014`，新 Job `2117685309698658306` 已确认使用
  `--resume` 并从同一 partial 继续。该账号余额仍足够覆盖本窗口
  最坏 6 卡时；本窗口结束后按实际剩余量决定是否再提交一次。
- d4 主训练第一窗口最终在 step `78,896` 因 `max_hours` 正常停止；
  best 为 step `76,000` 的 `0.7805652022361755`。完整 run 已中转
  d3，五项文件 SHA256 与 d4 完全一致。
- d3 continuation 第一次 Job `2117802840442572801` 在首个
  generator 更新前因 d3 旧 `torch.stft` 实现报
  `HIPFFT_PARSE_ERROR`；同步 r25 explicit DFT `spectral.py`
  （SHA256
  `6015a5029282f3c59a496a4400884b30ff87a42dfafd613cbbf89b6e36e3dacc`）
  并跑过定向测试后，重试 Job `2117804993484845057` 已提交。
  重试已确认从 `78,896` 之后继续：10:34 日志为
  step `79,480–80,000`，80k 验证 `0.828044`，best 仍为 step 76k
  的 `0.780565`，patience `2`。
- d5 LS360 units 已完成 104,014 records / 921 speakers，
  `verification.json` 为 0 missing、0 shape/value mismatch；
  `unit_records.jsonl` SHA256
  `e55b76ac70540f4458c08d5c8f03c03c31edfa6880aa92335ad3903be25725be`。
  root 所有权修复 Job `2117799927749849089` 已提交。

## 2026-11-03 人工智能/模型训练实时台账

| 账号 | 任务 | 外部 JobID | DCU | 墙钟上限 | 状态（19:39） | 进度 |
|---|---|---:|---:|---:|---|---|
| d4 | LS360 NT target shard 0 | `2117447702608093185` | 1 | 18 h | Running | `16,256/20,402` |
| d4 | LS360 NT target shard 1 | `2117447862870855681` | 1 | 18 h | Running | `16,256/20,402` |
| d3 | LS360 NT target shard 2 | `2117524054988300289` | 1 | 18 h | Running | `7,680/20,401` |
| d3 | LS360 NT target shard 3 | `2117524094031339521` | 1 | 18 h | Running | `8,192/20,401` |
| d5 | LS360 HuBERT units #1 | `2117499601892397057` | 1 | 6 h | Timeout | `33,504/104,014` |
| d5 | LS360 HuBERT units resume #1 | `2117591722692628481` | 1 | 6 h | Running | `33,800/104,014` |
| d4 | NT target shard 0 | `2117447702608093185` | 1 | 18 h | Failed after final write | `20,402/20,402`，已核验 |
| d4 | NT target shard 1 | `2117447862870855681` | 1 | 18 h | Failed after final write | `20,401/20,401`，已核验 |
| d4 | shard ownership repair | `2117623116743094274` | 1 | 0.08 h | Completed | 纯 `chown` |
| d4 | vocoder DDP pilot | `2117623823366492162` | 2 | 0.25 h | Running | 1000 steps |
| d4 | env distribution attempt #1 | `2117630644059906049` | 1 | 0.08 h | Not instantiated | 2 卡占用时提交 |
| d4 | env distribution attempt #2 | `2117631280985444353` | 1 | 0.25 h | Failed | 容器看不到其他账号家目录 |
| d4 | DDP pilot after FP32 STFT | `2117642750959849473` | 2 | 0.25 h | Failed | 节点 FP32 `torch.stft` 仍报 HIPFFT |
| d4 | DDP pilot after rfft | `2117649872622702594` | 2 | 0.25 h | Failed | `torch.fft.rfft` 同样报 HIPFFT |
| d4 | DDP pilot after DFT fallback | `2117653221587161090` | 2 | 0.25 h | Running | 显式分帧 + cos/sin DFT |

- 资源口径：每个 embedding shard 为 15 CPU / 59 GB；d5 units 为
  15 CPU / 59 GB。所有任务自动容错关闭。
- 四个 embedding shard 输出到各自的
  `processed/embeddings/librispeech_train_clean_360_target_nt_utterance_shards/shard_00N`；
  完成后必须合并到四账号共享的 canonical 输出，不能用 shard 顺序
  直接拼接 manifest。
- d4 shard 0/1 已完成并核验：`20,402 + 20,401` 条、250 维、finite，
  NPZ key 与 manifest 完全一致。控制台虽记为“失败”，final 文件
  已完整写出；Job `2117623116743094274` 已把 root-owned 输出修正为
  d4 所有权。
- d3 shard 2/3 仍使用旧版启动脚本，完成后也要核验并修正所有权。
- d5 units 输出到
  `processed/units/librispeech_train_clean_360`；第一窗口日志为
  `audit/ls360_units_ai_20261103_140916.log`，resume 日志为
  `audit/ls360_units_resume_ai_20261103_201559.log`。resume 明确从
  `33,600` 开始，没有重跑前 33.5k 句。
- d4 shard 释放两张卡后，先提交 2-DCU/1000-step/12 分钟训练的
  `d4-vocoder-ddp-pilot`，验证 DDP；该 pilot 完成后再决定主
  vocoder 训练。当前任务配置为 `submit:false`，提交前必须显式改配置。
- 该 pilot 已提交为 Job `2117623823366492162`，22:24 开始运行；
  最坏 `0.5` 卡时。完成后先读取 `meta.json`、loss 和 checkpoint，
  通过后才允许提交 `d4-vocoder-nt-main`。
- 前三次重试分别证明 BF16 `stft`、FP32 `stft` 和 `rfft` 在该类
  2-DCU 节点上都会触发 `HIPFFT_PARSE_ERROR`。r24 改为不依赖
  hipFFT 的显式 DFT 矩阵实现，并用 CPU 回归测试与 `torch.stft`
  对齐；下一次 2-DCU pilot 验收的是该实现和 DDP，而不是改数据。
- Job `2117653221587161090` 已在 `cuda:0` 和 `cuda:1` 通过
  `mel_preflight_ok`，输入/输出 mel shape 为 `(2, 80, 62)`、FP32；
  这是第一次越过 hipFFT 门禁进入后续训练预检的重试。

### d6/d7 新账号环境

- 状态：`ENVIRONMENT_READY`（2026-11-04 00:30）。
- d6/d7 `py311` 均由 d4 的可迁移归档建立，归档 SHA256
  `babcb9a81b3f0dc4f1125edc3af24bcd7b42723caf8bad2a3bd7b819110ad41f`。
- 两账号 audit 均通过，r24 同步后均为 `104 tests OK`。
- 在这些文件通过逐账号 SHA256 检查和全量测试前，不向 d6/d7
  提交卡时任务。
- 新增 ECAPA target utterance 四个 shard 的提取配置均为
  `planned_after_nt_embeddings`、`submit:false`，尚未消耗卡时。

### Unit HiFi-GAN 收敛与换账号 checkpoint

- 训练器已支持 `stop_reason=converged`、`best.pt`、完整
  `last.pt`、跨账号恢复 best metric/patience 和防重复续训。
- 完整 checkpoint 实测 `1,019,490,959 bytes`（972.26 MiB）；远端
  2,000-step pilot 的 `last.pt` 为 973 MiB，两者一致。
- 2,000-step pilot 目录当前保存 3 个约 973 MiB 文件，合计约
  2.9 GiB：`checkpoint_00001000.pt`、`checkpoint_00002000.pt`、
  `last.pt`。主训练必须按每 50k 一个完整归档预留磁盘。
- `scripts/transfer_vocoder_run.py` 已完成 d3→d5 分块中转自测：
  archive `3,153,920` bytes，4 个 1 MiB 块，最终逐文件 SHA256
  全部匹配。
- 主训练必须先通过 2-DCU pilot，再提交 d4 8 小时窗口；达到窗口后
  停止源任务、传输 checkpoint、再启动 d3 continuation。若先触发
  convergence，则不继续换账号。

## 当前资源判断

`sacct -S 2026-10-01` 统计到的 1-DCU HPC 作业累计约 `49.208`
卡时（截至 `1020953` 完成）。项目交接文档中的 HPC 额度是按 50
卡时估算，不是 CLI 权威余额；剩余 HPC 已不足以再跑长训练，任何新长
作业必须转到人工智能/模型训练。

## 正式相关作业

| JobID | 任务 | 节点 | 状态 | 墙钟 | 卡时 | 说明 |
|---|---|---|---:|---:|---:|---|
| 1020395 | DCU smoke | f11r2n04 | COMPLETED | 36 s | 0.010 | forward/backward、bf16、checkpoint 通过 |
| 1020430 | original eval | f11r2n04 | FAILED | 9 s | 0.003 | 官方依赖 pin 检查拒绝 SCNet 版本 |
| 1020436 | original eval | f11r2n05 | FAILED | 34 s | 0.009 | 空 suffix 导致 VPC split 崩溃 |
| 1020439 | units | f11r1n14 | FAILED | 8m59s | 0.150 | 旧 compat resample 2D 错误 |
| 1020515 | units | f11r1n09 | FAILED | 9m05s | 0.151 | 同一 resample 错误 |
| 1020558 | units | f11r1n14 | FAILED | 47m19s | 0.789 | LibriSpeech units/W-PRO 已完成，LibriTTS resample 失败 |
| 1020709 | units | f11r1n17 | FAILED | 39 s | 0.011 | GroupNorm HIP `invalid device function` |
| 1020739 | HuBERT diag | f11r2n04 | COMPLETED | 36 s | 0.010 | 7 项 GroupNorm/HuBERT 探测全部通过 |
| 1020740 | HuBERT diag | f11r1n17 | FAILED | 22 s | 0.006 | 最小 GroupNorm 即失败，节点排除 |
| 1020756 | LibriTTS units + W-PRO | f11r1n07 | COMPLETED | 35m40s | 0.594 | 33236 units + 247 W-PRO embeddings，全部核验通过 |
| 1020773 | eval assets | f11r1n07 | COMPLETED | 3m51s | 0.064 | 1924 target embeddings + 1934 test units |
| 1020782 | original speech eval | f11r1n07 | FAILED | 55 s | 0.015 | VPC `libri_test` 缺 `wav.scp`，已补齐元数据 |
| 1020789 | original W-NT | f11r1n07 | COMPLETED | 4m54s | 0.082 | W-NT I 平均 7.234%，论文 7.8% |
| 1020819 | duration NT pilot | n/a | CANCELLED | 0 s | 0.000 | 未启动；改依赖修正后的 baseline |
| 1020872 | original speech eval retry | f11r1n07 | FAILED | 2m54s | 0.048 | E-VPC 成功，ASR 缺 Wav2Vec2 预处理缓存 |
| 1020873 | duration NT pilot retry | n/a | CANCELLED | 0 s | 0.000 | 依赖 baseline；baseline 失败后自动取消 |
| 1020888 | original speech eval retry 2 | f11r1n05 | FAILED | 2m07s | 0.035 | ASV 通过；ASR 仍读旧共享缓存视图 |
| 1020889 | duration NT pilot retry 2 | n/a | CANCELLED | 0 s | 0.000 | 依赖 baseline 失败 |
| 1020904 | original speech eval retry 3 | f11r1n19 | FAILED | 2m24s | 0.040 | SpeechBrain 使用独立 cache_dir，HF_HOME 缓存未命中 |
| 1020907 | duration NT pilot retry 3 | n/a | CANCELLED | 0 s | 0.000 | baseline 失败 |
| 1020917 | original speech eval retry 4 | f11r1n03 | COMPLETED | 3m24s | 0.057 | E-VPC 4.5895%，WER 1.8435% |
| 1020918 | duration NT pilot retry 4 | f11r1n03 | COMPLETED | 2m52s | 0.048 | 1 epoch 14.6 s，loss 3.3666 |
| 1020937 | duration NT main | f11r1n03 | COMPLETED | 5m49s | 0.097 | 30 epochs，loss 3.3681 → 2.3985 |
| 1020938 | duration pred main | f11r1n03 | COMPLETED | 5m17s | 0.088 | 30 epochs，loss 3.4252 → 2.6172 |
| 1020953 | vocoder NT pilot | f11r1n03 | COMPLETED | 19m37s | 0.327 | 2000 steps，0.519 s/step；checkpoint 已保存 |
| 1021278 | pilot end-to-end | f11r1n07 | COMPLETED | 10m50s | 0.181 | 2k-vocoder DU-pred-nt 全 libri_test；仅链路诊断 |

## 节点结论

- `f11r1n17`：不可用于 HuBERT/GroupNorm 作业，已加入
  `hpc/n019_unit_pipeline.slurm` 的 `--exclude`。
- `f11r2n04`：GroupNorm、短/中/长 HuBERT 和训练 backward smoke 全部通过。
- `f11r1n14`：LibriSpeech HuBERT units 与 251 个 W-PRO embedding 已通过。
- 其他节点在每次长作业前由 `n019.diagnose_hubert --quick` 重新确认。

## 资源计划与状态

### n019_pilot_e2e

- 状态：`COMPLETED`，JobID `1021278`（2026-11-03），ExitCode `0:0`。
- 账号：`a094f4d4`；模式：HPC/Slurm；partition：`hx1hdnormal`。
- DCU：1；CPU：12；host RAM：40 GB。
- 墙钟上限：25 分钟；最坏卡时：0.4167；预计：0.20–0.30。
- 输入：2,000-step vocoder pilot、duration_pred_main、官方 libri_test
  units/target map/target embeddings。
- 输出：`runs/n019_official/pilot_e2e/`，含 DU-pred-nt WAV、VPC
  `_n019_pilot` 导出、官方 E-VPC/WER、W-NT I/L 和中间汇总。
- 用途：只验证端到端链路和定位问题，不得写入 Table 1。
- 停止条件：25 分钟墙钟、非有限输出、WAV 数不是 1,934、依赖/路径
  失败、存储不足。
- 实际墙钟：`10m50s`；实际卡时：`0.1806`。任务完成，但
  2,000-step pilot 的 WER 为 `18.424%`，只能作为链路诊断。
- 详细对照：`docs/PILOT_E2E_RESULTS.md`。
- 完整计划：`docs/PILOT_E2E_RESOURCE_PLAN.md`。

### n019_ls360_units

- 状态：`AWAITING_PORTAL_LOGIN_AND_SUBMISSION`，尚未提交。
- 账号：`a094f4d4`；模式：人工智能/模型训练；资源组：
  `hx1hgbwnormal`。
- DCU：1；CPU：16；host RAM：40 GB。
- 墙钟上限：6 小时；最坏卡时：6.0；预计卡时：2.5–4.5。
- 输入：LS360 manifest、LS100 K=200 codebook、HuBERT。
- 输出：`processed/units/librispeech_train_clean_360/`，含可恢复
  partial records、最终 records、metadata 和 verification。
- 停止条件：DCU/GroupNorm 初始化失败、非有限 forward、10 分钟无进度、
  存储不足、达到墙钟、ID 集合不一致。
- 不允许提交到 HPC：估算余额约 `0.973` 卡时，最坏占用超余额。
- 完整计划见 `docs/LS360_UNIT_RESOURCE_PLAN.md`。

### n019_voc_ddp_pilot

- 状态：`AWAITING_USER_CONFIRMATION`，尚未提交。
- 账号：`a094f4d4`。
- 模式：人工智能/模型训练。2026-11-03 `sbatch --test-only` 已证明
  `a094f4d4` 在 `hx1hdnormal` 的 group max DCU 为 1；2-DCU HPC 请求
  被 `AssocGrpGRES` 拒绝。因此 HPC 只能做 1-DCU 短测试，DDP pilot
  必须走 AI 容器。
- partition：`hx1hdnormal`。
- DCU：2；CPU：12；host RAM：40 GB。
- 墙钟上限：15 分钟；最坏卡时：0.5。
- 预计卡时：0.15–0.25，取决于双卡 DDP 吞吐和启动开销。
- 输入：
  `data/n019_official/processed/units/libritts_train_clean_100/unit_records.jsonl`
  与对应 250 维 W-PRO speaker embeddings。
- 输出：`runs/n019_official/vocoder_nt_ddp_pilot_<JobID>/`，包含
  `last.pt`、`meta.json`、`launch.txt`、`training_log.jsonl`。
- 任务：1000 steps、bf16、effective batch 32（每 rank 16），验证
  `python -m torch.distributed.run --standalone`、ROCm nccl 和多 DCU 吞吐。
- 停止条件：15 分钟墙钟到；非有限 loss；DDP/GroupNorm 初始化失败；
  显存不足。不得自动改参数后重试。
- 启动修正：当前 env 没有独立的 `torchrun` 可执行文件，脚本改用
  `python -m torch.distributed.run --standalone`。
- 预算说明：截至 `1020953` 的累计估算为 `49.027` 卡时；若按 50
  卡时上限，本计划最坏占用会超过剩余约 `0.973` 卡时，因此提交前必须
  由用户明确确认。
- 2026-11-03 14:20 起改为实际可从 AI 控制台提交的计划：
  账号 `a094f4d4`、2 DCU、1 实例、每卡 15 CPU / 59 GB、平台墙钟
  不超过 15 分钟、训练上限 12 分钟、1000 steps、effective batch 32、
  bf16。最坏 0.5 卡时；14:02 实时余额 `45.3025` 卡时。入口脚本为
  `scripts/run_vocoder_ddp_pilot_ai.sh`，输出
  `runs/n019_official/vocoder_nt_ddp_pilot_ai_*`。
- d4 的 2-DCU 尝试未创建任务：页面提示团队最多允许 2 张异构卡，
  当时已由 shard 0/1 占满。配置标记
  `blocked_by_team_dcu_quota`。
- d3 于 14:35 提交同规格 pilot，Job
  `2117506038057177089`，状态 Running；最坏 0.5 卡时。输出目录
  `runs/n019_official/vocoder_nt_ddp_pilot_ai_20261103_143602/`。
- 第一次 d3 pilot 在预检阶段失败，未生成 `launch.txt`。增加
  `bash -x` 日志后重提；第二次 Job
  `2117507521850683393`（14:40）已 Running，日志保存到
  `audit/vocoder_ddp_pilot_ai_20261103_144034.log`。配置已锁为
  `submit:false`。
- 第二次 d3 pilot 因 d3 没有 manifest 候选而失败。预检新增
  `libritts_train_clean_100/unit_records.jsonl` fallback，并同步
  wrapper；第三次 Job `2117509424831827970`
  （`n019_voc_ddp_pilot_20261103_144752`）页面状态为“运行中”。
  配置已锁为 `submit:false`。
- 第三次 d3 pilot 已通过预检并进入 DDP，但 `n019.vocoder` 报
  `Output directory is not empty and has no last.pt`。根因是启动器先写
  `launch.txt`，训练入口却要求目录完全空。已改为仅允许
  `launch.txt`，仍拒绝任何其他未知文件；新增 3 项回归测试，并在 d3
  同步修复后的 `vocoder.py`（SHA256 一致）。
- 第四次 d3 pilot：Job `2117516960314695682`
  （15:18 创建），修复后的训练入口已部署，页面初始状态“部署中”。
  配置已锁为 `submit:false`，等待 1000-step 结果。
- 第四次失败原因为修复 `launch.txt` 逻辑时漏保留
  `last_checkpoint` 局部变量，两个 rank 均在初始化早期报
  `NameError`，未进入训练。已补回变量，4 项 vocoder 测试通过并同步
  d3（SHA256 `46ee09e1...`）。
- 第五次 d3 pilot：Job `2117519452213268481`
  （15:28 创建），页面初始状态“排队中”；配置已锁为
  `submit:false`。
- 第五次 pilot 已确认失败于 `soundfile.LibsndfileError`：d3 的
  `unit_records.jsonl` 仍保存 d4 音频绝对路径，且本机 LibriTTS
  train-clean-100 当时尚未解压。DDP/RCCL 已成功初始化，失败属于数据
  路径门禁；配置状态改为 `failed_soundfile_audio_paths`，修复并验收前
  不得重提。

### n019_ls360_target_embeddings

- 状态：`AWAITING_PORTAL_LOGIN_AND_THROUGHPUT_PILOT`，尚未提交。
- 账号：`a094f4d4`；模式：人工智能/模型训练；资源组：
  `hx1hgbwnormal`。
- 前置条件：先用完整 205,044 句 other-500 manifest 生成 LS360
  `mode=utterance` target map，并选出实际被引用的 target utterance。
- DCU：1；CPU：16；host RAM：40 GB。
- 计划：先跑 256 句、15 分钟吞吐 pilot；再由实测吞吐决定主任务
  6 小时分片数量，允许 `partial_embeddings.npz` 续跑。
- 最坏卡时：pilot 0.25；每个主分片 6.0。未经实时余额检查不得提交。
- 输入：LS360 target subset manifest、完整 W-PRO 250 维模型和原始
  LibriTTS other-500 音频。
- 输出：
  `processed/embeddings/librispeech_train_clean_360_target_nt_utterance/`。
- 停止条件：DCU 初始化失败、非有限 embedding、10 分钟无进度、存储
  不足、达到墙钟；不得改用 libri_test 用过的 1,924 个 target 子集。
- 完整计划见 `docs/LS360_TARGET_EMBEDDING_RESOURCE_PLAN.md`。

### n019_ls360_target_embedding_pilot

- 状态：`COMPLETED`，AI 控制台任务 `2117442203569016834`。
- 账号：`a094f4d4`；模式：HPC/Slurm；partition：`hx1hdnormal`。
- DCU：1；CPU：16；host RAM：40 GB；墙钟：10 分钟。
- 最坏卡时：0.1667；预计卡时：0.05–0.12。
- 输入：正式 LS360 target subset 的前 256 句。
- 输出：`runs/n019_official/ls360_target_embedding_pilot_<JobID>/`；
  `pilot_throughput.json` 记录 256 句实际耗时和 81,605 句外推卡时。
- `sbatch --test-only` 通过，模拟队列最早
  `2026-11-07T23:46:42` 才会在 `f11r1n09` 开始；这说明 HPC 不适合作为
  当前快速吞吐 pilot。未提交正式 Job，当前卡时仍为 0。
- 停止条件：10 分钟墙钟、非有限 embedding、10 分钟无进度、
  DCU/GroupNorm 初始化失败、模型/音频路径错误、存储不足。
- 结果只用于吞吐估算，不进入正式 target embedding 或 Table 1。
- 实际：256 句全部完成，进程墙钟约 11 分钟；`pilot_throughput.json`
  记录含模型加载的 `638.0 s`、`0.4012539185 句/s`，外推 81,605 句
  `203,374.96 s = 56.4930` 卡时。
- 输出 `nt_utterance_embeddings.npz` SHA256
  `f271a655aab72b4fe8f539abd0133be0afd0280d82eaa3f41638279219abeced`；
  本地复核 256 条、250 维、有限值，norm 范围
  `0.99999994–1.00000012`。
- 页面机时余额由 50 降至 `49.8186111111`，与约 11 分钟一致。

### AI 控制台 target embedding pilot 尝试（2026-11-03）

下列三次任务均为 `a094f4d4`、人工智能/模型训练、华中一区 A 区、
113 组 `hx1hgbwnormal`、1 DCU、1 实例、自动容错关闭、基础镜像
`PyTorch / 2.9.0 / py3.11-Ubuntu22.04 / dtk26.04`。计划墙钟均为
10 分钟以内，最坏卡时 `0.1667`，输入为正式 target subset 前 256 句。

| 任务 ID | 名称 | 页面结果 | 证据与判断 |
|---|---|---|---|
| 2117438497411723265 | `n019_target_embed_ai_pilot_20261103` | FAILED | 日志明确报 `/root/voice_projects/.../run_ls360_target_embedding_pilot_ai.sh: No such file or directory`；这是容器路径错误，不是模型/数据结果 |
| 2117440005699194882 | `n019_te_pilot_retry_20261103` | FAILED | 实例开始/结束时间均为 `--`，日志和调度事件为空；未确认容器执行 |
| 2117440312291258369 | `n019_te_pilot_bashx_20261103` | FAILED | `bash -x` 入口没有启动实例；日志和调度事件为空 |
| 2117441405643378689 | `n019_ai_container_diag_20261103` | COMPLETED | 普通 `bash /public/home/...` 入口成功；日志确认 `id=root`、`pwd=/workspace`、`HOME=/root`，`/public/home/a094f4d4` 正常挂载，`hy-smi` 可见 1 块 DCU |
| 2117441697139961858 | `n019_te_pilot_plain_20261103` | FAILED | 普通入口成功启动，但脚本仍按容器内的 `id -un=root` 拼出 `/public/home/root/...`，启动后立即退出 |
| 2117442203569016834 | `n019_te_pilot_fixed_20261103` | COMPLETED | 改为从脚本自身 `BASH_SOURCE` 推导项目根后，256 句全部完成 |

- 已将 `activate_n019_official.sh`、`preflight_dcu_remote.sh`、
  `run_ls360_target_embedding_pilot_ai.sh`、`run_vocoder_ddp.sh`、
  `extract_ls360_target_embeddings_remote.sh` 的根目录探测统一为
  `/mnt/data/voice_projects`、
  `/public/home/<user>/voice_projects`、`$HOME/voice_projects`。
- 五个脚本在本地和 `a094f4d4` 均通过 `bash -n`，逐文件 SHA256
  一致；当前需要先排查新模型训练平台在容器启动前返回 FAILED 的原因。
- 页面没有实例开始时间，暂不能证明产生卡时；费用页仍需后续核验。
- 不得把上述失败尝试记为有效吞吐结果；只有
  `2117442203569016834` 的 256 句完整输出进入吞吐与外推。

### n019_ls360_target_embeddings_4shards（运行中）

- 目的：在相同 W-PRO 250 维、同一完整 81,605 句 target subset 上并行
  提取 embedding；不使用采样、近似或替代模型。
- 分片：四份确定性、互斥、并集完全等于 source manifest 的 JSONL；
  行数分别为 `20402/20401/20401/20401`。
- d4 shard 0：
  - 任务 `2117447702608093185`，`n019_te_shard0_20261103`；
  - 创建于 `2026-11-03 10:44:09`，普通 `bash /public/home/...` 入口；
- d4 shard 1：
  - 任务 `2117447862870855681`，`n019_te_shard1_20261103`；
  - 创建于 `2026-11-03 10:44:47`。
- 两个 d4 任务均为人工智能/模型训练、113 组、
  `hx1hgbwnormal`、BW 1 DCU、15 CPU、59 GB、自动容错关闭；
  每个启动脚本墙钟上限 18 小时。两任务最坏 36 卡时，按 pilot 线性
  外推各约 14.12 卡时/约 14.1 小时。
- 输出根：
  `processed/embeddings/librispeech_train_clean_360_target_nt_utterance_shards/shard_000`
  与 `shard_001`。启动时 `shard_000`、`shard_001` 均显示运行中。
- d3 shard 2/3 已于 2026-11-03 15:47 提交并 Running：
  `2117524054988300289`（shard 2）与
  `2117524094031339521`（shard 3）。每个 1 DCU、15 CPU/59 GB、
  18 小时上限，预计各约 14.12 卡时。配置已回写 Job ID 并设
  `submit:false`。
- d3 shard 2/3：计划使用同一镜像和资源规格，输入路径改写到 d3 自己的
  `LibriTTS/train-other-500`；在 d3 SSH 解压和 manifest 路径复核完成前
  不提交。
- d3 SSH 解压于 2026-11-03 15:19 完成：205,044 WAV 已移动到
  canonical 路径，完成标记
  `audit/train-other-500.ssh-complete.20261103_151949.txt`。shard
  2/3 manifest 行数与路径复核通过，等待 d3 pilot 释放 2 卡配额。
- 停止条件：18 小时、非有限 embedding、10 分钟无进度、DCU/GroupNorm
  初始化失败、manifest/audio ID 不一致、存储不足。
- 2026-11-03 15:59 实测：d4 shard 0/1 各 `9,472 / 20,402`，250 维、
  有限值、L2 norm `1.0`；d3 shard 2/3 各 `256 / 20,401` 与
  `128 / 20,401`。d4 实时余额 `41.3025` 卡时。
- 2026-11-03 18:39 实测：d4 shard 0/1 各 `14,464 / 20,402` 与
  `14,592 / 20,402`；d3 shard 2/3 各 `5,632 / 20,401` 与
  `5,888 / 20,401`。四个任务均仍在运行，最终 NPZ 尚未生成。
- 合并：四份完成后用
  `scripts/merge_target_embedding_shards.py` 做全 ID 集合、维度、有限值
  与 L2 norm 核验，再原子写出单一 NPZ。输出 manifest 和 NPZ key 必须
  按 canonical source manifest 原始顺序重建；不得沿用 d3 改写过的
  shard manifest 路径或 shard 拼接顺序。

### n019_ls360_units（d5 待提交）

- 账号：`a094f4d5`；模式：人工智能/模型训练；资源组：113 组
  `hx1hgbwnormal`；加速卡：异构加速卡 BW。
- DCU：1；实例：1；CPU/RAM：平台资源行 15 CPU / 59 GB；
  自动容错关闭；墙钟上限：6 小时；最坏 6 卡时；预计 2.5–4.5 卡时。
- 实时余额：`24.9066666666` 卡时（2026-11-03 13:42，浏览器脚本读取）。
- 输入：d5 自身 LS360 manifest、HuBERT、K=200 codebook 和
  104,014 个 FLAC。
- 输出：
  `processed/units/librispeech_train_clean_360/`，含
  `unit_records.partial.jsonl`、`codes/`、最终 records 和 verification。
- 停止条件：6 小时硬超时、非有限 HuBERT 输出、连续 10 分钟无进度、
  DCU 预检失败、ID 集合不一致、存储不足。
- 当前状态：配置已写入 `configs/scnet_browser_tasks.json` 的
  `d5-ls360-units`。
- 首次提交 `2117493067859922946`：页面 FAILED，Pod 于
  `13:44:28–13:44:29` 运行 1 秒并以 ExitCode 1 结束。没有生成
  `launch.txt`、`unit_records.partial.jsonl` 或 codes，确认未进入
  HuBERT 提取。根因是 AI 容器 `HOME=/root`，脚本仍按
  `$HOME/voice_projects` 找根；已改为从 `BASH_SOURCE` 推导并等待
  一次最小重试。
- 第二次提交 `2117493860055044097`：仍显示失败且当时未观察到
  `launch.txt`。d5 登录节点 `bash -x` probe 已证明修复后的脚本能完成
  根目录/输入检查并准确停在“无 DCU 的登录节点”预检，probe 日志为
  `audit/ls360_units_login_probe_20261103_135310.log`。
- 第三次提交改为把 AI 容器 stdout/stderr 写到
  `audit/ls360_units_ai_<timestamp>.log`，避免再次依赖不可读的 Web
  容器日志。
- 第四次提交 `2117497221462544385`（任务
  `n019_ls360_units_20261103_140036`）已进入 Running。日志确认
  AI 容器内 `N019_VOICE_ROOT=/public/home/a094f4d5/voice_projects`，
  输入检查通过并开始 HuBERT 预检。配置已回写现有 Job ID 并设
  `submit:false`，禁止误重复提交。
- 第五次提交 `2117497850171535361`（任务
  `n019_ls360_units_20261103_140306`）：同步最新
  `preflight_dcu_remote.sh` 后已 Running，日志确认
  `N019_VOICE_ROOT` 正确并进入 DCU/HuBERT 预检。配置已设
  `submit:false`，当前只允许监控和续跑，不允许再建同名任务。
- 第六次提交 `2117499601892397057`（任务
  `n019_ls360_units_20261103_140916`）已成功越过预检：
  GroupNorm 1/16 卡形状、0.5 秒 HuBERT forward 全通过；
  `unit_records.partial.jsonl` 已开始增长。配置再次回写现有 Job ID
  并设 `submit:false`。
- 2026-11-03 15:59 日志进度为 `9,800 / 104,014`，累计
  `6,210.6 s`。按当前约 `1.58 句/s` 吞吐，6 小时窗口不能完成全量；
  配置已新增 `d5-ls360-units-resume`，保持 `submit:false`，等当前任务
  达到硬超时后使用同一输出目录和 `--resume` 继续，禁止换目录拼接。
- 2026-11-03 18:38 日志进度为 `24,504 / 104,014`，任务仍运行；
  预计 20:10 左右硬超时，之后必须用同一输出目录和 `--resume` 续跑。

### d3 train-clean-100 收尾（2026-11-03 18:30）

- 解压 canonical 已达到 `33,236` 个 WAV；第一次重复解压阶段目录保留。
- `unit_records.jsonl` 的 33,236 条记录已完成 d4 -> d3 路径迁移，
  `audio`/`codes_path`/`kmeans_codebook` 全部指向 d3；迁移前备份保留。
- `verify_unit_dataset.py` 通过：33,236 个唯一 ID、247 人、0 缺文件、
  0 形状/值错误；迁移后 records SHA256 为
  `a87525aff2e4c361748743fe98208d9ab606b710a8ac3fc48452131fd575c957`。
  完成标记为
  `audit/train-clean-100.relocate-complete.20261103_183746.txt`。
- 不占卡 Dataset 门禁已通过：`UnitVocoderDataset` 成功读取首条、中间条、
  末条；code `(28,)`、waveform `(8960,)`、speaker `(250,)` 全部有限，
  speaker norm 约 `1.0`。d3 vocoder pilot 配置状态改为
  `ready_after_dataset_gate_waiting_dcu`，但两个 shard 仍占满卡，暂不提交。
- d4 也完成相同 Dataset 门禁并得到相同形状/有限值结果；d4 vocoder
  pilot 配置同样改为 `ready_after_dataset_gate_waiting_dcu`。两个账号
  目前都具备 pilot 数据条件，只剩 DCU 配额等待。

## 2026-11-03 环境与 MOS 门禁

| 账号 | 环境 | 结论 |
|---|---|---|
| `a094f4d3` | Python 3.11.17 / Torch 2.9.0 / HIP 6.3.26093 | 环境通过；待同步 r10 |
| `a094f4d4` | 同上 | 主账号可用；待同步 r10 |
| `a094f4d5` | 同上 | 环境通过；待同步 r10 |

- `a094f4d3`：71 项测试通过；LibriSpeech/LibriTTS processed units 与
  251/247 个 W-PRO speaker embeddings 全量核验通过。
- `a094f4d5`：71 项测试通过；同一批 processed units/embeddings 全量
  核验通过；原始 corpora 仍为空，但 vocoder/duration 训练所需数据已齐。
- UTMOS 单句 CPU smoke：`4.314345359802246`。
- WhiSQA 单句 CPU smoke：`4.5908671617507935`。
- 两项均为链路验证，不产生作业 ID、不占 DCU 卡时，不得写入 Table 1。
- 最新代码包为 `n019_code_20261103_r18.tar.gz`，SHA256 记录在
  `artifacts/SHA256SUMS.txt`；本地 98 项测试通过、2 项 skip；
  三账号同步后必须各自复跑全部测试。
- LS360 manifest 已完成：104,014 句、921 人、363.6056 小时；ID 与
  官方 VPC `wav.scp` 完全一致。d5 已在自身服务器完成同一验收。
- 旧 LS360 target map 只引用 1,924 个 target 且为 `mode=speaker`，
  已标记为不得进入正式 S。正式流程改从完整 205,044 句 other-500
  以 `mode=utterance` 生成，并单独提取被引用 target 的 embedding。
- d4 已生成正式 LS360 target map：104,014 个 source、81,605 个实际
  引用 target；map SHA256
  `c9a182adfc4076087dc5144a85694b5900270a4fefee6b38459d720da228ee75`，
  target subset SHA256
  `f6986086fbf79e0555629ad31fe7acb5893b90db03cef44f60b27fa9e5cea76b`。
- CPU duration 诊断覆盖 `libri_test` 1,934 句：NT-conditioned 模型有
  1 个负 duration value（会 clamp 到 0 并记录）；无条件模型无负值。
  DU-pred 总时长相对误差 mean `4.997%`、p95 `12.748%`。

## 记录规则

新增卡时作业必须在此表补记录：账号、模式、任务名、partition、DCU 数、
CPU/RAM、墙钟、最坏/预计卡时、输入输出、停止条件和实际结果。失败的
run 与日志不得删除。

后续 AI 控制台任务统一通过
`scripts/scnet_browser_tasks.py --config configs/scnet_browser_tasks.json`
提交。账号、区域、资源组、镜像、卡数、启动脚本和计划全部从配置读取；
密码只从进程环境或交互式提示读取。默认干跑，`--submit` 才点击创建。

## 2026-11-07 ext102k 全量质量评测重试

- 已确认 `2118748742678118401` 在 `libri_test_asr_n019_ext102k` 的
  1,934 行门禁处失败；失败发生在旧 ASR 数据目录仍包含 438 条 enroll
  的状态。未重跑 UTMOS、E-VPC、W-NT 或 WER 的既有结果。
- `src/n019/wer_eval_vpc.py` 已修正 VPC2024 SpeechBrain
  `ErrorRateStats` 的百分数口径：`wer` 保存 0-1 小数，
  `wer_percent` 保存百分数。2 句 CPU smoke 返回
  `wer=0.06896551724137931`、`wer_percent=6.896551724137931`。
- 已将修正文件同步到 d7，远端 SHA256
  `b9b5442dfd812b59efbce403e7b374545e3394b9259563ea2f3ee2477d109d5e`；
  `run_du_pred_nt_ext102k_eval_ai.sh` SHA256
  `b82d8ae16da3262a4dfef442de57064bf2933d0ac975657214a4b59dd715c4c7`。
- 账号 `a094f4d7`；人工智能/模型训练；AI 控制台任务
  `2118751285394268161`，名称
  `n019_ext102k_metrics3_20261107_010346`；状态：运行中（WER 阶段）。
- 资源：1 DCU、15 CPU / 59 GB、1 实例、墙钟 1.0 小时；预计
  0.4、最坏 1.0 卡时；提交前余额 `39.3599999997` 卡时。
- 输入：固定 ext step 102000 checkpoint
  `62eb5908aae998f50eed1456a8f6a8f606a88c07627c1d92517f0d072c9ff151`、
  已有 1,934 条匿名 WAV / VPC 系列、VPC `trials_f`/`trials_m` 合并的
  1,496 句 ASR、UTMOS22、WhiSQA 和 Whisper-small 离线快照。
- 输出：`runs/n019_official/eval/du_pred_nt_ext102k/{WER.json,
  mos/UTMOS.json,mos/WhiSQA.json,quality_metrics.json}`。
- 停止条件：输入或 checkpoint hash 不符、WER 不是 1,496 句、
  UTMOS/WhiSQA 不是 1,934 句、指标非有限、evaluator 非零退出、
  10 分钟无进度、DCU/存储错误或 1 小时墙钟。
- 该任务复用已有匿名 WAV/VPC，不重新合成，不替换正式 step 4k
  结果，也不进行新的训练。
- 启动校验已通过：ASR 数据集
  `libri_test_asr_n019_ext102k` 的 `wav.scp` 和 `text` 均为 1,496 行；
  容器 host 为 `vcjob-2118751285394268161-a094f4d7-86091-worker-0`，
  日志时间 `2026-11-07T01:04:36+08:00`。
- `2118751285394268161` 于 `2026-11-07 02:04:12` 因 1 小时外层
  timeout 结束，控制台状态为失败；WER 日志在 `01:06:40` 后没有进度，
  未生成 `WER.json`、`UTMOS.json`、`WhiSQA.json` 或
  `quality_metrics.json`。失败原因是 VPC 上游 `ASRDataset` 在构造时
  顺序预载全部 1,496 个 WAV，尚未进入推理就耗尽墙钟；不是 ASR 权重或
  VPC 数据错误。
- 已将 `n019.wer_eval_vpc` 改为惰性 `LazyASRDataset`：保留相同的
  SpeechBrain `audio_normalizer` 和 collate 语义，在 DataLoader 取 batch
  时逐条加载；`num_workers=0` 以避免把 parametrized SpeechBrain 模块
  序列化到 fork worker。2 句 CPU smoke 再次通过，返回
  `wer=0.019230769230769232`、`wer_percent=1.9230769230769231`。
- 新准备任务仍为 d7、人工智能/模型训练、1 DCU、15 CPU / 59 GB、
  1 实例、1.0 小时外层墙钟，预计 0.4、最坏 1.0 卡时；最新实时余额
  `38.4299999997` 卡时。只复用已有 ext102k WAV/VPC，不重新合成；
  仍只运行 WER 1,496 句、UTMOS/WhiSQA 各 1,934 句。
- 已提交惰性 WER 重试：AI 控制台任务
  `2118777081015451649`，名称
  `n019_ext102k_metrics4_20261107_024616`；提交时状态排队中。
  远端 `wer_eval_vpc.py` SHA256
  `a9aea2877c93cf04aa5b47327e113b4aef73f898f596399d70033cf572a628f2`。
- `2118777081015451649` 已于 `2026-11-07 02:46:59` 启动，
  host 为 `vcjob-2118777081015451649-a094f4d7-97471-worker-0`；
  启动门禁再次确认 ASR 数据集为 1,496 行。当前仍在 WER 阶段，
  尚未生成 `WER.json` 或 MOS 文件。
- `2118777081015451649` 于 `2026-11-07 03:46:41` 再次因 1 小时外层
  timeout 结束，控制台状态失败；WER 日志最后时间仍为 `02:49:26`，
  未写出任何结果。该日志只到 SpeechBrain “wav2vec 2.0 is frozen”，
  说明失败点仍在 WER 推理批次之前/首批附近，而不是 UTMOS 或 WhiSQA。
- 为区分 CPU 惰性加载问题与 DCU 首 batch 问题，已准备 8 句
  DCU smoke：AI 控制台任务 `2118793481147813889`，名称
  `n019_wer_lazy8_dcu_20261107_035126`；d7、1 DCU、15 CPU / 59 GB、
  15 分钟墙钟，预计 0.1、最坏 0.25 卡时；提交前余额
  `37.4299999997` 卡时。输入固定为 8 句
  `tmp_wer_smoke_lazy8_n019_ext102k`、VPC2024 SpeechBrain ASR 和
  `n019.wer_eval_vpc`；输出
  `runs/n019_official/eval/wer_lazy_dcu_smoke/WER.json`。
- 8 句 DCU smoke 在模型加载完成并打印 `wav2vec 2.0 is frozen`
  后，首个 batch 仍无进度；`timeout 900` 没有终止卡住的进程，遂通过
  无头 Playwright 点击“停止”并在 `2026-11-07 04:02:42` 确认任务
  已停止。未生成 smoke `WER.json`。这与 CPU 8 句 smoke 成功形成对照：
  CPU smoke 返回 `wer=0.020833333333333336`、
  `wer_percent=2.0833333333333335`，说明问题集中在 DCU 上的
  SpeechBrain ASR 推理，不再是 WAV 行数或 collate 预处理。
- 已新增 `n019.wer_eval_hf`：从同一
  `wav2vec2.ckpt`/`asr.ckpt` 重建 wav2vec2 + 两层 DNN + CTC，
  使用官方 `tokenizer.ckpt` 标签和贪心 CTC 解码，绕过 SpeechBrain
  DCU 推理封装。CPU 8 句 smoke 返回 `wer=0.020833333333333332`、
  `wer_percent=2.083333333333333`，与 SpeechBrain CPU smoke 完全一致。
- 为验证 native 路径的 DCU 行为，提交 AI 控制台任务
  `2118797917668675585`，名称
  `n019_wer_native8_dcu_20261107_040903`；d7、1 DCU、
  15 CPU / 59 GB、15 分钟墙钟，预计 0.1、最坏 0.25 卡时；
  提交前余额 `37.2491666664` 卡时；输出
  `runs/n019_official/eval/wer_native_dcu_smoke`。
- native DCU smoke 启动后 WER 日志一直为空（`04:09:28` 之后无输出），
  在约 8 分钟无进度后通过无头 Playwright 停止；说明原 SpeechBrain
  DCU 问题同样影响 native `Wav2Vec2Model`，不再继续尝试 DCU WER。
- 改用 CPU native 8 分片：每片 187 句、`N019_NUM_THREADS=1`，同一
  `n019.wer_eval_hf` 路径，最后由脚本核对 8×187=1,496 句并按
  `errors/words` 合并 WER。任务
  `2118800628084670466`，名称
  `n019_wer_native_cpu_20261107_041950`；d7、1 DCU 资源、
  15 CPU / 59 GB、2 小时墙钟，预计 1.5、最坏 2.0 卡时；提交前余额
  `37.2491666664` 卡时。输出
  `runs/n019_official/eval/wer_native_cpu_shards/WER.json`。
- 该任务已于 `2026-11-07 04:20:18` 启动，8 个 187 句 CPU 分片均已
  拉起；当前只等待分片日志和 shard `WER.json`，不重跑已完成的
  ext102k 匿名化、E-VPC、W-NT 或 WER 的其他配置。
- `2026-11-07 04:50` 轻量检查：8 个分片均在解码，进度约
  `32–64 / 187`，尚未生成 shard `WER.json`；主进程正常 `wait`，
  没有错误或重复提交。
- `2118800628084670466` 于 `2026-11-07 06:20:15` 到 2 小时墙钟后
  控制台状态失败。已完成分片 `01/02/05/06/07` 共 935 句；未完成
  分片 `00/03/04` 的最后进度约 152–176/187，未生成最终
  `WER.json`。失败是分片粒度过粗，不是指标计算错误。
- 因 8 分片仍有 7 个 CPU 核空闲，改为 16 分片（前 8 片 94 句、
  后 8 片 93 句），仍使用已与 SpeechBrain CPU smoke 对齐的
  `n019.wer_eval_hf`，预计 1.2、最坏 2.0 卡时；准备任务输出
  `runs/n019_official/eval/wer_native_cpu16`。提交前实时余额
  `35.0991666664` 卡时。
- 已提交 16 分片任务 `2118834138852724738`，名称
  `n019_wer_native_cpu16_20261107_063100`；启动时控制台显示
  运行中。脚本 SHA256
  `9ea3e8251424385385d8feb79c0991dace741dc45b61564a57bd9069565ce879`，
  输出沿用 `wer_native_cpu16`。
- 16 分片任务在 `2026-11-07 06:33:13` 很快失败，分片日志为空，
  判断为 16 个模型副本并发加载导致资源/内存压力；没有产出可用指标。
- 保留已完成的 5 个 8 分片结果（`shard_01/02/05/06/07`，共 935 句），
  只补齐缺失区间 `0–186`、`561–747`、`748–934`，拆为 6 个
  94/93 句恢复分片。提交 AI 控制台任务
  `2118841835679023106`，名称
  `n019_wer_native_recover_20261107_070306`；d7、1 DCU、
  15 CPU / 59 GB、2 小时墙钟，预计 1.2、最坏 2.0 卡时；提交前余额
  `35.0844444442` 卡时。输出
  `runs/n019_official/eval/wer_native_cpu_recover/WER.json`，
  合并时必须核对 1,496 句。
- 恢复任务已于 `2026-11-07 07:04` 启动，6 个恢复分片均已拉起；
  `03b` 日志已到 `8/93`，其余分片正在加载/解码，尚无最终 WER。
- 恢复任务已完成，最终
  `runs/n019_official/eval/wer_native_cpu_recover/WER.json`：
  1,496 句、35,042 词、2,367 错误，WER `6.754751441127789%`；
  JSON SHA256
  `5ab39bbf7caefda93f62e71b087c80aedf8a3ae742ce50f52915d31d8f1887f3`，
  hypothesis text SHA256
  `5cdbd07706b8c110cc8f5df09f0017e608b6bc9a09351b5d366381a162b4640c`。
  相对论文 7.41% 为 `-0.65525` 个百分点，相对 step4k 的 10.333%
  为 `-3.57825` 个百分点；这是指标复现结果，不是替代论文值。
- 已提交 MOS-only 任务 `2118863503522172930`，名称
  `n019_ext102k_mos_only_20261107_082707`；d7、1 DCU、
  15 CPU / 59 GB、1 小时墙钟，预计 0.4、最坏 1.0 卡时；提交前余额
  `33.8219444442` 卡时。该任务只复用 1,934 句 ext102k WAV 和已恢复
  WER，不重算 WER/E-VPC/W-NT，输出
  `runs/n019_official/eval/du_pred_nt_ext102k/`。
- `2118863503522172930` 因 UTMOS 环境缺少 `hydra` 在 WER 复制后
  立即失败；已补 `envs/n019_utmos_overlay` 到 `PYTHONPATH` 并加入
  fairseq/hydra/omegaconf/pytorch_lightning 启动门禁。修正脚本
  SHA256 `069179dfd0911a59b6f401b791dc85a5ff1412f2c94a858fd3caf66e79430241`。
- 重新提交 MOS-only 任务 `2118864716782256129`，名称
  `n019_ext102k_mos2_20261107_083329`；规格不变，提交时排队中。
  只运行 UTMOS/WhiSQA 并汇总，不重算 WER/E-VPC/W-NT。
- `2118864716782256129` 已启动并通过 `PYTHONPATH` 覆盖层导入检查，
  当前进入 UTMOS 阶段；`du_pred_nt_ext102k/WER.json` 已由已验证的
  1,496 句恢复结果复制，尚无 UTMOS/WhiSQA 最终 JSON。
- `2026-11-07 08:55` 轻量检查：UTMOS 已加载到 DCU
  （日志 `08:40:01`，`Using device: cuda`），尚未写出 UTMOS.json；
  WER.json 保持 `6.754751441127789%`，没有重算或重复提交。
- `2118864716782256129` 到 1 小时墙钟后失败，UTMOS 在 DCU 上
  只打印模型加载信息，首个样本无进度；未写出 UTMOS/WhiSQA JSON。
  该现象与 wav2vec2 ASR 的 DCU 首 batch 挂起一致。
- 已用 CPU 2 句 smoke 验证 MOS 路径：UTMOS 成功 2 句，WhiSQA 成功
  2 句；输出位于
  `tmp/mos_cpu_smoke_20261107_095948/`，模型 SHA256 分别为
  UTMOS `44c57e3e4135a243b43d2c82b6a693fcd56f15f9ad0e1eb2a8b31fdecd3a49b8`
  与 WhiSQA `2da43d59294c358bdd3f450d0aef5ce57ad20bed3beb34657ef3a795a4766810`。
- 已把 MOS-only 脚本切换到 CPU，并计划 2 小时墙钟、预计 1.2、
  最坏 2.0 卡时；任务名
  `n019_ext102k_mos_cpu_20261107_100124`。提交前余额
  `32.7886111109` 卡时。
- `2026-11-07 10:02` 的 CPU MOS 提交在资源选择阶段失败：
  华中一区【A区】当前“暂无加速卡资源”（共 0 条），未创建 Job，
  未消耗卡时；配置保持 `submit:true`，等待资源窗口，不重复刷提交。
- `2026-11-07 10:55` 资源窗口恢复后仅做一次提交尝试，AI 控制台任务
  `2118900546075533314`（`n019_ext102k_mos_cpu_20261107_105513`）
  已创建，状态部署中；使用 CPU 版 MOS-only 脚本，2 小时墙钟，
  预计 1.2、最坏 2.0 卡时。提交前余额 `32.7886111109` 卡时。
- CPU 单进程 UTMOS 在 `11:58` 只到 `350/1934`，按进度会超过 2 小时，
  已在 `11:58:52` 人工停止，未生成 UTMOS/WhiSQA JSON。
- 改为 UTMOS/WhiSQA 各 8 个 CPU 分片（每片覆盖约 242/241 句），
  每片 `N019_NUM_THREADS=1`，两阶段运行并在本地按 records 合并；
  UTMOS/WhiSQA 2 句 CPU smoke 均通过。任务
  `2118916554821054466`（`n019_ext102k_mos_shards_20261107_120043`）
  已创建，提交时排队中；规格为 d7、1 DCU、15 CPU / 59 GB、
  2 小时，预计 1.2、最坏 2.0 卡时。
- `2118916554821054466` 已启动，WAV/WER/模型门禁通过，正在执行
  UTMOS 8 分片阶段；尚未生成最终 UTMOS/WhiSQA/quality JSON。
- `2026-11-07 12:58` 轻量检查：8 个 UTMOS 分片均已完成并写出
  shard JSON；8 个 WhiSQA CPU 分片已启动，主进程正常 `wait`，
  尚未合并最终 MOS/quality 文件。
- `2118916554821054466` 到 2 小时墙钟后失败：UTMOS 8 分片已完成，
  WhiSQA 8 分片日志为空，未生成 `UTMOS.json`、`WhiSQA.json` 或
  `quality_metrics.json`。保留全部 UTMOS shard，不重算。
- 首次 WhiSQA 恢复任务 `2118949702348853250`
  （`n019_ext102k_wsr_20261107_141043`）在 14:12:33 启动后快速失败。
  4 个分片均报
  `Input type (torch.cuda.FloatTensor) and weight type (torch.FloatTensor)`
  ：WhiSQA vendor wrapper 在可见 DCU 环境中强制把输入送入 CUDA，
  即使 evaluator 指定 `--device cpu`。该失败未改动 UTMOS shard 或 WER。
- 实时余额检查：d3 `1.3774999999`、d4 `8.3249999999`、
  d5 `4.216111111`、d6 `37.536111111`、d7 `29.7380555553` 卡时。
- 首次设备修复任务 `2118954300423909378`
  （`n019_ext102k_wsr2_20261107_142744`）的 2 句预检再次快速失败：
  遍历 `model.modules()` 时误触 HuggingFace Whisper 的只读
  `device` property，报 `AttributeError: property 'device' ... has no setter`。
  未进入 4 分片，也未改动已有 UTMOS shard 或 WER。
- `src/n019/eval_mos.py` 最终只覆盖自身 `__dict__` 中确有可变
  `device` 字段的 vendor wrapper，避开只读 property；最终 SHA256
  `1252b0875a6469f3b75ec39487ff6b4ebc14b5739da4c3d88959c021de9cc0a0`。
  恢复脚本增加独立临时目录下的 2 句 CPU 预检和
  `N019_SMOKE_ONLY=1` 提前退出，最终 SHA256
  `1973e7a68d105e02dc96602b0cb13b93aa01f5c219024a8dbe58010368b1dffc`；
  本地和 d7 哈希一致，远端 `bash -n` 与零卡时
  `WHISQA_DEVICE_SMOKE_OK` 均已通过。
- 已提交第三版 WhiSQA 恢复任务 `2118955843912245249`
  （`n019_ext102k_wsr3_20261107_143534`），提交时排队中。
  规格：d7、人工智能/模型训练、1 DCU、15 CPU / 59 GB、
  2 小时墙钟，预计 1.2、最坏 2.0 卡时；最近实测 d7 余额
  `29.7380555553`，足以覆盖最坏值。复用 8 个已完成 UTMOS shard、
  1,934 句 WAV、1,496 句 WER；只运行 WhiSQA 4 个 CPU 分片并合并
  MOS/quality。配置已设 `submit:false`，严禁重复提交。
- `2118955843912245249` 于 `2026-11-07 16:35` 到 2 小时墙钟后结束：
  4 个 WhiSQA CPU 分片均到 `350/484` 或 `350/483`，按分片约完成
  1,400/1,934 句；未写出 shard JSON、最终 `WhiSQA.json` 或
  `quality_metrics.json`。原分片日志与 UTMOS shard 均保留，不删除。
- 为避免再次覆盖失败日志，恢复脚本已改为独立版本目录
  `eval/du_pred_nt_ext102k/mos_whisqa_wsr4_20261107_1709`，并从原
  `mos_shards` 复用 8 个已完成 UTMOS shard。WhiSQA 改为 8 个 CPU
  分片（每片约 242/241 句），预计 1.4、最坏 2.0 卡时。脚本 SHA256
  `882eb0dc79527f27716c80137d633c5ae23c2bf33449eeff511b287a87b2dd0b`，
  远端 `bash -n` 和 `WHISQA_DEVICE_SMOKE_OK` 均通过。
- d7 实时余额 `27.7266666664` 卡时，足以覆盖下一任务最坏 2.0 卡时。
  已提交 `2118994883693924353`
  （`n019_ext102k_wsr4_20261107_171158`）；规格为 d7、
  人工智能/模型训练、1 DCU、15 CPU / 59 GB、2 小时墙钟。
  只补 WhiSQA 1,934 句并合并已有 UTMOS、1,496 句 WER，不重跑已完成
  项目。配置已设 `submit:false`，严禁重复提交。
- 为验证“此前 GPU 能跑”是否适用于 WhiSQA，新增 2 句 DCU smoke
  `2118996023452123137`（`n019_wsr4_dcu_smoke_20261107_171630`）。
  规格为 d7、人工智能/模型训练、1 DCU、15 CPU / 59 GB、
  15 分钟，预计 0.1、最坏 0.25 卡时；启用
  `HIP_LAUNCH_BLOCKING=1`、`CUDA_LAUNCH_BLOCKING=1`，先执行 DCU
  tiny matmul，再以 `--device cuda` 跑 2 句 WhiSQA。输入为现有
  1,934 行 `wav.scp`、固定 WhiSQA checkpoint 和 Whisper-small 快照；
  输出 `runs/n019_official/eval/du_pred_nt_ext102k/dcu_whisqa_smoke`。
  该 smoke 与 CPU 8 分片任务并行，成功后才会停止 CPU 任务并切换
  完整 DCU 运行；失败则保留日志，不再盲目提交完整 GPU 作业。
- 2 句 DCU smoke 已完成：tiny matmul 和 WhiSQA forward 均正常，
  `WhiSQA.json` SHA256
  `48488e89ca7cd5eb371978294bff0aefac5b862ff459d31a6dea649fbd7fa584`，
  两句话均值为 `2.6129891723394394`。因此此前“所有评估都只能 CPU”
  的判断过宽；至少 WhiSQA 可以在 DCU 上运行。
- 已提交完整 WhiSQA DCU 任务 `2118998908457992193`
  （`n019_wsr4_dcu_full_20261107_172757`）：d7、1 DCU、
  15 CPU / 59 GB、1 小时墙钟，预计 0.4、最坏 1.0 卡时。
  单进程跑 1,934 句，输出
  `runs/n019_official/eval/du_pred_nt_ext102k/dcu_whisqa_full_20261107_1728/`
  并汇总到 `mos/`。脚本 SHA256
  `172982a38f124f63585659d567325162467dcacc8bd80eb39ab7b720b7880081`。
  该任务于 `17:28:05` 启动，但到 `17:39` 仍停在 DCU tiny matmul
  之前，尚未进入 WhiSQA 推理；继续做一次轻量日志检查，不重复提交。
- CPU 8 分片任务 `2118994883693924353` 仍在运行，约 `25/242`；
  因 API 对运行中 Pod/Job 没有删除权限，无法立即取消，保留作 GPU 失败时
  的兜底。后续不再新建 CPU 版本。
- GPU 节点对照已完成：
  - WhiSQA 2 句 smoke `2118996023452123137` 位于节点
    `10.6.15.37`，DCU tiny matmul 和 WhiSQA 均正常完成；
  - 完整 GPU 任务 `2118998908457992193` 位于节点 `10.6.15.32`，
    只打印 `cuda_available=True` / `device_name=BW`，随后停在
    tiny matmul 直至 1 小时墙钟，Pod 状态 `Error`；
  - 同一镜像 `jupyterlab-pytorch:2.9.0-ubuntu22.04-dtk26.04-py3.11-devel`
    在 `.37` 可运行、在 `.32` 卡死，因此不是项目 Python/DTK 环境整体损坏，
    而是节点 `10.6.15.32` 的 DCU 运行异常或分配异常；
  - 之前 `2118916554821054466` 也落在 `.32`，进一步支持该节点存在
    DCU 侧问题。
- CPU 兜底任务 `2118994883693924353` 在 `18:39` 完成，最终
  `du_pred_nt_ext102k`：
  WER `6.754751441127789%`、UTMOS
  `2.6142479994304426`、WhiSQA `2.7501946269325535`；
  `WER.json` SHA256
  `5ab39bbf7caefda93f62e71b087c80aedf8a3ae742ce50f52915d31d8f1887f3`，
  `UTMOS.json` SHA256
  `cb147bc3afc785edeab503441ad2a8dab72c48f422f66a5fdff530a2213a38aa`，
  `WhiSQA.json` SHA256
  `0c5a75478297041c6952c76cf32c21a86cd54a3f20080e4b78e14e2a9d386145`，
  `quality_metrics.json` SHA256
  `78770e7641aecbc6d7b7dccd5449eef6d494c0c29d2d31a102717ac82e253c10`。
  相对论文：WER `-0.65525` 个百分点、UTMOS `-1.01575`、
  WhiSQA `-0.93981`；相对 step4k 全量：WER `-3.57825` 个百分点、
  UTMOS `+1.35219`、WhiSQA `+0.90317`。
- 已修正 GPU 全量脚本：tiny matmul 单独加 300 秒 SIGKILL 看门狗，
  去掉 `HIP_LAUNCH_BLOCKING` / `CUDA_LAUNCH_BLOCKING`，GPU 验证结果写入
  独立 `dcu_quality_20261107_1840`，不覆盖已完成 CPU 正式结果。脚本
  SHA256 `92f57743824bc795fe331ca3789a514b4ad2ef0ac666c33efc736e40ce111510`。
- d7 余额 `25.8986111108` 卡时，足以覆盖 1 小时 GPU 重试最坏值。已提交
  `2119017477546799106`（`n019_wsr4_dcu_full2_20261107_184145`）；
  若再次调度到 `.32`，300 秒看门狗会快速失败，不再拖满 1 小时。
- 上述重试再次被调度到 `10.6.15.32`，300 秒内被看门狗终止，Pod
  状态 `Error`。这说明问题可稳定复现到该节点，而不是脚本偶发。
- 为验证健康节点，利用 `.32` 上另一个短任务占位后提交
  `2119018005205766145`（`n019_wsr4_dcu_full3_20261107_184350`）；
  该任务落到 `10.6.15.39`，DCU tiny matmul 正常，完整 WhiSQA
  1,934 句在 5 分 49 秒内完成：
  mean `2.750191857889988`、count `1934`，
  `WhiSQA.json` SHA256
  `6ce028250feb4d6c49ce82bae4a793023b1e3a6abd910cebef234f309f8f4b79`，
  `quality_metrics.json` SHA256
  `70d537467b58ce29e9ba18cd9f456e26fe7783f47bb085bf718523ba7c89bacf`。
  与 CPU 全量 WhiSQA `2.7501946269325535` 仅差
  `2.769e-6`，确认模型、输入和指标实现无环境性问题。
- 结论：D7 的 DTK 26.04 / PyTorch 环境和 WhiSQA GPU 路径正常；
  `10.6.15.32` 的 DCU 运行异常。后续 GPU 任务必须有 300 秒
  tiny-matmul 看门狗；落在 `.32` 就快速失败并重试，不能再用 CPU
  代替。CPU 8 分片任务已完成并形成正式兜底结果。
- 继续验证其余两项 GPU 推理：
  - UTMOS 8 句 smoke：先提交的 `2119019733294792705` 落在 `.32`
    并在 300 秒看门狗处失败；随后 `2119019823947862018` 落在
    `10.6.15.3`，完成 2 句，均值 `2.3035210967063904`，
    `UTMOS.json` SHA256
    `977c0642bac6951e656f5598f81b77bdc65d9f69f8a4cffbbd2c030d5f6d416d`。
  - WER 8 句 smoke：`2119021656863297538` 落在 `.32` 并失败；
    `2119021746961141762` 落在 `.3`，完成 8 句，
    `wer=0.020833333333333332`、`wer_percent=2.083333333333333`，
    `WER.json` SHA256
    `a0a76c45f9d6af7c355ccd05df4d012eee870d7d7dbf362c96de6443f0f7d4b6`。
- 因此 UTMOS、WhiSQA、WER 三类评测均已在健康 DCU 节点跑通；
  `10.6.15.32` 的结果不能作为模型或代码问题证据。后续正式评测优先
  使用 GPU，并保留 300 秒 DCU 看门狗与节点避让。
- `2026-11-07 20:15` 零卡时代码审计发现 d7 的训练代码发生漂移：
  - d7 原 `src/n019/hifigan.py` 的
    `feature_matching_loss` 仍直接 `return loss`，SHA256
    `dce219d834543ca8f3e6d0c427d7edb1b8ab46e8b14f418db4bcde4f53d09014`；
  - 本地已修正版本为 `return loss * 2`，SHA256
    `6d77f4033e75519d2c503cd284913505fd2aff2a06db90a2abb4a295b9cd9ccb`。
  - 因此 ext step 102000（以及此前的 step 4k/76k）都是按 **1x
    feature-matching** 训练的。当前全量 `UTMOS 2.614 /
    WhiSQA 2.750` 不能验证 2x 配方。
  - d7 旧 `duration.py` 也缺少 `output_is_pristine` 修复；本地 SHA256
    `9773154b58962cf1c06b673810ce27f57b4acd8b0efdddf8776f57db90891e56`。
  - 已将上述两个本地修正同步到 d7，远端哈希与本地一致。
  - 本地 `tests.test_hifigan`、`tests.test_duration`、
    `tests.test_paper_alignment` 共 20 项通过。
- target embedding 口径核对：
  - vocoder 训练使用 LibriTTS clean-100 的
    `nt_speaker_embeddings.npz`，`embedding_level=speaker`；
  - 推理使用 train-other-500 target utterance 的
    `nt_utterance_embeddings.npz`，`embedding_level=utterance`；
  - 论文只写“target speaker embedding”，未定义 pooled speaker mean
    还是单个 target utterance embedding。该差异是待 A/B 的实验假设，
    不能先验判为 bug。
- duration 审计维持既有结论：原时长/预测时长在 25 句上的 UTMOS/WhiSQA
  差仅 `-0.0476/+0.0215` 与 `+/-` 噪声量级，不是主要 MOS 来源。
- 下一项最小验证不是直接跑全量：用同一固定 source/target/duration，
  对 102k checkpoint 做 utterance-level 与 target-speaker-mean
  embedding 的小样本配对 A/B；同时规划真正使用 `2x` 的 NT vocoder
  新训练和独立 MOS 验证集选模。任何卡时任务提交前另列资源计划。

### 2026-11-09 LR 2e-4 fresh vocoder：DTK 启动卡点定位与重启

- `n019_vocfixsmoke_20261109_013157`（Job
  `2119483096447078401`，d6，1 DCU，15 CPU / 59 GB，15 min，
  预计 0.12、最坏 0.25 卡时，提交前余额 36.5527777776）：
  - `direct_b2_w0` 与 `direct_b16_w0` 均在 180 秒超时后
    `exit=137`，case 日志 0 字节，没有 step 输出。
  - `direct_b16_w4`（batch 16、workers 4、2 step）`exit=0`，
    `training_log.jsonl` 有 step 1/2，`loss_d=7.997372150421143`、
    `loss_g=139.3001708984375`、`mel_loss=132.572265625`，并写出
    1,019,512,015 字节 `last.pt`。说明模型、判别器和训练循环本身可跑。
- `n019_vocstage_20261109_014409`（Job
  `2119486165537148929`，d6，1 DCU，15 CPU / 59 GB，20 min，
  预计 0.2、最坏 0.35 卡时）：
  - 新增 `N019_STAGE_TRACE` 与 `N019_STACK_DUMP_SECONDS` 两个
    仅诊断用的入口，`src/n019/vocoder.py` 本地/远端 SHA256
    `5a7b94e548350eeba0822d7dcf7b10cbef0d90bbf97d73f05588f984943bc688`。
  - `fp32_b2` 与 `bf16_b2` 两个 case 的 30 秒 `faulthandler`
    栈都停在
    `torch/cuda/__init__.py:182 in is_available` →
    `src/n019/vocoder.py:505 in main`。因此此前的“无日志卡死”
    不是 dataloader、batch size、AMP 或首个卷积 kernel，而是
    **`torch._C._cuda_getDeviceCount()` 在该 DTK 节点上偶发阻塞**。
  - 同一 job 前的 `gpu_tiny_matmul_watchdog.sh` 本身能通过
    （`N019_GPU_TINY_MATMUL_OK`），说明设备可用；阻塞发生在
    随后新进程的驱动枚举阶段，时间可达 2 分钟以上。
  - 结论：启动阶段不能再用 180 秒级 timeout 判定“模型失败”；
    真实训练必须给 20–25 分钟启动窗口，并保留 STAGE/栈日志。
- `n019_voc2xlr2e4b_20261109_015040`（Job `2119487803555074049`，
  d6、人工智能/模型训练、1 DCU、15 CPU / 59 GB、2 h，预计 1.75、
  最坏 2.0 卡时；提交前余额 36.3030555554）：
  - 使用 `code/n019_official_lr2e4_resume`，2x feature matching、
    lr 2e-4、grad clipping 0、batch 16、workers 4，从零训练到
    step 400000，每 2000 step 存 checkpoint 与 compact generator
    snapshot。
  - 输入：原始 LibriTTS `train-clean-100` 的 33,236 条 unit records
    与 247-speaker NT embeddings，走
    `N019_SKIP_PATH_VERIFY=1` + `d6_training_data_ready.json`
    marker，避免重复 99,708 路径扫描。
  - 输出：`runs/n019_official/vocoder_nt_2x_lr2e4_fresh_20261109_015040`。
  - 配置已回写 `submit:false` 与 `submitted_task_id`，禁止重复提交。
  - 2026-11-09 02:24 实际状态：启动链完整通过
    （`args_validated` 01:57:36 → `distributed_ready` 01:58:08，
    本次 `is_available` 仅约 32 秒），step 1 于 01:58:45 写出，
    稳定 `0.67 s/step`，mel loss 从 146.58 降到约 39。
    step 2000 checkpoint（`last.pt` 1,019,512,015 字节）于 02:21
    落盘；compact snapshot
    `snapshots/generator_step00002000.pt` 56,858,091 字节，SHA256
    `d12a376355c83b47d3c6966100e4b4aed9ff117fdcfaeab0300d3738cfb581ec`。
    按 0.67 s/step 估算，本段 1.75 h 训练预算约到 step 9,000–9,300。
  - 2026-11-09 02:47 已把 step 2000 / 4000 两个 compact snapshot
    经本机中转同步到 d7
    `data/n019_official/checkpoints/n019_lr2e4_fresh_20261109/`，
    三段 SHA256 完全一致（2000：`d12a3763…b581ec`；
    4000：`f2738b66…39b757`）。
  - 已预注册 d7 选模任务 `d7-vocoder-selection-lr2e4`
    （`submit:false`，无 JobID），等 6000 / 8000 snapshot 到位后
    在固定 speaker-disjoint dev-100 上比较 baseline、6k、8k 的
    UTMOS/WhiSQA/WER；未到位前不得提交。
  - 2026-11-09 03:29 step 8000 snapshot 落盘，SHA256
    `41401334fb76e74366e04d48e60641da080cd17c297d16a0344b27d4b5ad7637`；
    6k/8k 均已 d6 → 本机 → d7 中转，d7 上四个 snapshot 哈希全部一致。
  - d7 选模 Job `2119513067544604673`
    （`n019_vocsel_lr2e4_20261109_033103`）已提交：
    d7、人工智能/模型训练、1 DCU、15 CPU / 59 GB、2 h，预计 1.4、
    最坏 2.0 卡时，提交前 d7 余额 20.8763888886。
    固定 dev-100 上比较 ext102k baseline、step 6000、step 8000，
    输出 `runs/n019_official/vocoder_selection_lr2e4_20261109_033103`。
    配置已回写 `submit:false` 与 `submitted_task_id`，禁止重复提交。
- 2026-11-09 03:43 训练第 1 段正常结束：日志停在 step 9280
  （`elapsed_hours=1.7495`，达到 `max_hours=1.75`），随后打印
  `N019_LR2E4_TRAINING_COMPLETE`；`last.pt` 1,019,512,015 字节，
  退出时的 `Device or resource busy` 只发生在 NFS 临时目录清理，
  不影响 checkpoint。
- 2026-11-09 03:41 选模首次 Job `2119513067544604673` 失败，原因
  是 d7 侧 `src/n019/vocoder.py`（SHA256 `317fad41…`）比 d6
  训练代码旧，`load_generator` 解析 snapshot config 时
  `UnitVocoderConfig.__init__() got an unexpected keyword argument
  'grad_clip_norm'`。只消耗约 0.195 卡时，无 candidate 指标。
- 已把本地/d6 的 `vocoder.py`（SHA256
  `5a7b94e548350eeba0822d7dcf7b10cbef0d90bbf97d73f05588f984943bc688`）
  同步到 d7 并做导入 smoke（`grad_clip_norm=0.0`、`lr=2e-4`）；
  其余 `hifigan/training_recipe/spectral/audio/manifest` 哈希本来就一致。
- 选模重试 Job `2119517395894943746`
  （`n019_vocsel_lr2e4r1_20261109_034815`，d7、1 DCU、15 CPU /
  59 GB、2 h，预计 1.4、最坏 2.0 卡时，提交前余额
  20.6816666664）已提交并进入 baseline 100 句 reconstruction +
  UTMOS 阶段；输出
  `runs/n019_official/vocoder_selection_lr2e4r1_20261109_034815`。
- 训练第 2 段 Job `2119519038174097409`
  （`n019_voc2xlr2e4s2_20261109_035446`，d6、1 DCU、15 CPU /
  59 GB、2 h，预计 1.75、最坏 2.0 卡时，提交前余额
  34.1119444443）已提交，从同一目录 `last.pt` 续训，目标仍是
  step 400000，本段预算 1.75 h。

### 2026-11-09 04:22 dev-100 选模结果：from-scratch 8k 仍远低于 baseline

- Job `2119517395894943746`（`n019_vocsel_lr2e4r1_20261109_034815`）
  正常完成（`N019_VOCODER_SNAPSHOT_SELECTION_COMPLETE`），
  `selection.json` / `selection.md` 已生成。
- 固定 speaker-disjoint dev-100，三项均为 100 句：

| candidate | UTMOS | ΔUTMOS | WhiSQA | ΔWhiSQA | WER % | ΔWER |
|---|---:|---:|---:|---:|---:|---:|
| ext102k baseline | 2.134480 | 0 | 2.120907 | 0 | 21.590909 | 0 |
| from-scratch step 6000 | 1.234920 | -0.899560 | 1.645249 | -0.475659 | 23.776224 | +2.185315 |
| from-scratch step 8000 | 1.234614 | -0.899866 | 1.598272 | -0.522636 | 24.125874 | +2.534965 |

- 结论不是“代码坏了”：两个 snapshot 彼此一致，谱统计显示
  6k/8k 输出整体偏暗（谱质心 1878/1778 Hz，baseline 2156 Hz）、
  谱平坦度略高（0.453/0.428 vs 0.424）、RMS 低 2–4 dB，
  属于从零训练早期的过度平滑，不是静音、噪声或加载错模型。
- 关键事实修正：此前 UTMOS 2.877 的 2x14k 是**从 ext102k
  generator 初始化**的微调结果，不是 from-scratch；因此不能用来
  推断 from-scratch 在 14k 能收敛。论文若按字面从零训练，
  8k 步远未收敛，需要 more steps（按 0.67 s/step，100k 步约
  18.6 卡时）。
- 后续策略：继续 from-scratch 分段训练，但 checkpoint 选模门槛不变；
  在 ~16–18k 再筛一次，若 UTMOS 仍停在 1.2–1.5，则评估是否改为
  更长训练或恢复更高的学习率（旧 8e-4 从零到 102k 曾达到
  UTMOS 2.614，可作为收敛速度参照）。

- 2026-11-09 06:13 第二轮 dev-100 选模（Job
  `2119548101571723265`，`n019_vocsel_lr2e4b_20261109_055016`）
  完成，from-scratch 仍然平坦：

| candidate | UTMOS | WhiSQA | WER % |
|---|---:|---:|---:|
| baseline | 2.134479 | 2.120908 | 21.590909 |
| step 14000 | 1.239114 | 1.728601 | 24.388112 |
| step 16000 | 1.249426 | 1.799677 | 22.902098 |

  UTMOS 从 6k 到 16k 只从 1.235 变到 1.249，基本没有起色；WhiSQA
  有缓慢上升。按 HiFi-GAN 常规从零训练量级（十万到百万 step），
  16k 远未收敛，但在本预算下不可行。
- 同一 dev-100 上旧 2x 微调谱系（从 ext102k 初始化、8e-4）为：
  18k 1.324、20k 2.147、22k 2.531、24k 2.569、14k 2.669。
  18k 的低谷说明该谱系在 8e-4 下会短暂失稳后恢复，14k 仍是最好。
- 据此改为“优化路线”：以 2x14k（SHA256
  `343b3a4117b69c72c3b1a2c4fbe69e6c10830af0caccc950e988af9f1828cf45`，
  dev UTMOS 2.669、全量 UTMOS 2.877）为初始化，用已校验的
  lr 2e-4、2x feature matching、梯度裁剪 0、batch 16 继续训练，
  discriminator/optimizer 重新初始化。这是明确标注的微调路线，
  不是 from-scratch，不与论文原设定混写。
- 微调 Job `2119554846081961986`
  （`n019_voc2xft14k_20261109_061704`，d6、1 DCU、15 CPU / 59 GB、
  2 h，预计 1.75、最坏 2.0 卡时，提交前余额 32.1116666665）已提交；
  输出 `runs/n019_official/vocoder_nt_2x_ft14k_lr2e4_20261109_061704`，
  每 2000 step 存 checkpoint 与 compact snapshot。
- from-scratch 谱系的完整状态只到 step 16000（seg2 被平台 SIGKILL，
  `last.pt` 仍是 05:41 的 16k），保留作为诊断，不再占用卡时。

### 2026-11-09 06:53 电平归一化 A/B：不是 MOS 差距来源

- Job `2119558822145388545`（`n019_lvl_20261109_063251`，d7、1 DCU、
  15 CPU / 59 GB、45 min，预计 0.4、最坏 0.75 卡时）完成。
- 取 2x14k 全量匿名化音频的前 120 句，原样 vs 统一 -4.2 dB
  （使其 RMS 对齐 LibriTTS train-clean-100 的 `-24.34 dBFS`）：

| 条件 | UTMOS | WhiSQA |
|---|---:|---:|
| raw | 2.839055 | 2.829264 |
| gain -4.2 dB | 2.849045 | 2.876283 |
| Δ | **+0.009990** | **+0.047019** |

- 结论：输出偏响（+5.4 dB）对两个 MOS 预测器只有 0.01 / 0.05 的影响，
  不是论文差距的主因。该假设关闭，后续不再在电平上花卡时。
- 该 120 句 raw UTMOS 2.839 与全量 1,934 句的 2.877 一致，说明
  子集抽样没有偏倚。
- 同时微调 Job 已到 step 2380、mel loss 约 28.5–30.5，
  `generator_step00002000.pt` 于 06:48 落盘。

### 2026-11-09 08:16 微调 2k/4k dev-100：4k 首次超过 14k 起点

- 微调第 1 段 Job `2119554846081961986` 于 08:10 正常结束
  （`N019_LR2E4_TRAINING_COMPLETE`），最后日志 step 9180，
  `last.pt` 1,019,512,015 字节；snapshots 2000/4000/6000/8000。
- 选模 Job `2119569650580275202`
  （`n019_vocself_20261109_071531`）完成，固定 dev-100：

| candidate | UTMOS | Δ vs baseline | WhiSQA | WER % |
|---|---:|---:|---:|---:|
| baseline ext102k | 2.134479 | 0 | 2.120908 | 21.590909 |
| ft 2000 | 2.659647 | +0.525168 | 2.369678 | 20.847902 |
| ft 4000 | **2.759049** | **+0.624570** | **2.461728** | **20.673077** |

- 与微调起点（2x14k，dev UTMOS 2.669348 / WhiSQA 2.423676 /
  WER 21.110140）相比，ft 4000 为 +0.089701 / +0.038052 /
  -0.437063 pp，三项同向改善，首次在 dev 上超过 14k。
  ft 2000 与起点基本持平（-0.009701），说明 2e-4 起步没有破坏模型。
- 6k/8k snapshot 已 d6 → 本机 → d7 中转并校验哈希
  （6k `7b7f1514…5249`，8k `87da6bd1…6d2a`）。
- 微调第 2 段 Job `2119586043298729986`
  （`n019_voc2xft14ks2_20261109_082003`，d6、1 DCU、2 h，预计 1.75、
  最坏 2.0 卡时，提交前余额 30.2152777776）已提交，从 9180 续训。
- 6k/8k 选模 Job `2119586758341705729`
  （`n019_vocselg_20261109_082301`，d7、1 DCU、2 h，预计 1.4、
  最坏 2.0 卡时）已提交。

### 2026-11-09 09:15 微调 6k/8k：8k 小幅领先，WhiSQA/WER 最好

| candidate | UTMOS | WhiSQA | WER % |
|---|---:|---:|---:|
| baseline ext102k | 2.134479 | 2.120908 | 21.590909 |
| ft 6000 | 2.677829 | 2.428408 | 20.847902 |
| ft 8000 | **2.764180** | **2.479369** | **20.323427** |
| ft 4000（上一轮） | 2.759049 | 2.461728 | 20.673077 |
| 起点 2x14k | 2.669348 | 2.423676 | 21.110140 |

- 6000 有一个小回落（-0.081 vs 4000），8000 又回到 2.764，
  略高于 4000（+0.0051）。UTMOS 轨迹为
  `2.669 → 2.660 → 2.759 → 2.678 → 2.764`，整体向上但带 GAN 噪声。
- 8000 的 WhiSQA（+0.0557 vs 起点）与 WER（-0.7867 pp vs 起点）
  都是目前最好，因此暂定 8k 为当前候选，继续训练观察 12k/16k。
- 按 2e-4 的观测斜率（约 +0.01 UTMOS / 1k step），要达到 dev 2.85
  还需约 10k step（≈2 h）；要到 3.0 需约 25k step（≈5 h）。

### 2026-11-09 10:34 第 2 段被外层墙钟截断；改 1.5 h 预算续训

- 微调第 2 段 Job `2119586043298729986` 在 10:25 左右被外层
  `timeout 7200` SIGKILL，最后日志 step 17660（elapsed 1.64 h），
  没有 `TRAINING_COMPLETE`；`last.pt` 停在 10:01 的 step 16000。
  原因是 outer wall 2 h 先于 inner `max_hours=1.75` 触发，
  以及 preflight 约 20 分钟未计入 inner 计时。
- 教训：后续段把 `N019_LR2E4_MAX_HOURS` 设为 1.5（outer 2 h），
  留出 preflight 与收尾写盘余量。
- snapshot 已到 12000（09:15）、14000（09:38）、16000（10:01），
  全部 d6 → 本机 → d7 校验同步（14k `479b982c…`、16k
  `0a5a33f3…`）。18000 未产生，因为截断发生在 17660。
- 14k/16k 选模 Job `2119619881038794754`
  （`n019_vocselh_20261109_103527`，d7、1 DCU、2 h）已提交。
- 微调第 3 段 Job `2119619960427814913`
  （`n019_voc2xft14ks3_20261109_103546`，d6、1 DCU、2 h，
  inner 1.5 h，预计 1.5、最坏 2.0 卡时，提交前余额
  28.2155555554）已提交，从 step 16000 续训。

### 2026-11-09 11:46 微调 14k/16k：14k 刷新最佳

| candidate | UTMOS | WhiSQA | WER % |
|---|---:|---:|---:|
| baseline ext102k | 2.134478 | 2.120908 | 21.590909 |
| ft 14000 | **2.783845** | **2.513872** | **20.367133** |
| ft 16000 | 2.675921 | 2.470484 | 20.804196 |

- 微调 14k 是目前三项全优的最佳点：相对 2x14k 起点
  （2.669348 / 2.423676 / 21.110140）为
  `+0.114497 / +0.090196 / -0.743007 pp`。
- 16k 回落 0.108，与 6k 的回落幅度相当，属于 GAN 周期性抖动；
  最佳点不能只看“最新 checkpoint”，必须每 2k 选模。
- UTMOS 序列（dev-100）：`2.669 → 2.660 → 2.759 → 2.678 →
  2.764 → (10k/12k 未筛) → 2.784 → 2.676`。
  16k step 累计提升约 +0.115，平均 +0.007 / 1k step。
- 18k/20k snapshot（11:08 / 11:31）已同步到 d7，选模 Job
  `2119638036823896066`（`n019_vocseli_20261109_114735`）已提交。

### 2026-11-09 14:40 启用 HPC 模式（每个账号 50 h）

- 用户提示 HPC 模式可通过 SSH 直接提交，每账号另有 50 h 免费时长。
  实测 d6：`sbatch/squeue/sinfo` 可用，分区 `hx1hdnormal`，
  58 节点、每节点 8 张 Hygon DCU、128 CPU、510 GB，
  `MaxTime=3-00:00:00`。
- 关键限制：`sbatch` 报
  `tres(gres/dcu) request 2 exceeds group max tres limit 1`，
  即每账号同一时刻只能占 **1 张 DCU**，所以 50 h 实质是
  1 DCU × 50 h；但单 Job 墙钟可到 3 天，远优于 AI 训练的 2 h。
- `sshare -U -u a094f4d6` 显示 RawUsage 0，d6 的 50 h 未消耗。
- HPC 冒烟 Job `1069599`（1 DCU / 16 CPU / 60 G / 20 min，
  从 ft14k snapshot 初始化，400 step）已正常运行：
  step 120 时 `0.675 s/step`、`mel_loss≈29–33`，与 AI 训练速度一致。
- 长训 Job `1069636`（`n019_voc_hpc_long`，1 DCU / 16 CPU / 60 G /
  16 h 墙钟，inner 15.5 h）已提交，初始化 checkpoint 为
  微调 14k（SHA256 `479b982c…1dc6`，dev UTMOS 2.783845），
  输出 `runs/n019_official/vocoder_nt_hpc_ft14k_long_20261109`。
  预计 15.5 h 可跑约 82,000 step，每 2000 step 存 checkpoint 与
  compact snapshot。
- d7 的 HPC 训练暂缓：其 `libritts_train_clean_100/unit_records.jsonl`
  是 d4 路径（audio/codes 都指向 `a094f4d4`），d7 本地无 LibriTTS
  音频；跨账号 NFS 读 33k 小文件会成为 I/O 瓶颈，需先把音频或
  重写路径后再跑。
- 2026-11-09 14:55 HPC 长训 Job `1069636` 实测 step 400、`0.671 s/step`、
  `mel_loss≈27.8–29.2`，节奏与 AI 训练一致；预计 15.5 h 约 82k step。
- 已新增两项零卡时准备：
  - `scripts/run_full_eval_param_ai.sh`（d7 已同步，`bash -n` 通过）：
    参数化完整 1,934 句复评，支持任意 checkpoint/label，自动做
    匿名化 → VPC 导出 → WER 1,496 / UTMOS / WhiSQA 1,934 → 与论文
    对比并写 `quality_metrics.json`；
  - `scripts/average_generator_snapshots.py`（d6/d7 已同步，本地
    用合成 tensor 单测通过）：把多个 compact generator snapshot
    做权重平均（SWA），用于对抗 14k 之后出现的 GAN 抖动。

### 2026-11-09 16:30 HPC 长训 6k 大幅刷新 dev 最佳

- HPC 长训 Job `1069636` 的 4k/6k snapshot 已同步到 d7 并选模
  （Job `2119702652776108033`，`n019_vocselhp_20261109_160422`，
  固定 dev-100）：

| candidate | UTMOS | WhiSQA | WER % |
|---|---:|---:|---:|
| baseline ext102k | 2.134479 | 2.120908 | 21.590909 |
| hpclong 4000 | 2.589327 | 2.463038 | 20.673077 |
| **hpclong 6000** | **3.066984** | **2.672135** | **19.842657** |
| 旧最佳（微调 14k） | 2.783845 | 2.513872 | 20.367133 |

- 6k 相对旧最佳：UTMOS `+0.283139`、WhiSQA `+0.158263`、
  WER `-0.524476 pp`；相对 ext102k baseline：
  `+0.932505 / +0.551227 / -1.748252 pp`。三项同时大幅改善，
  是本项目启动以来最大的一次跃升。
- 4k（2.589）与 6k（3.067）之间差 0.478，再次说明该训练谱系
  抖动很大，必须逐快照选模，不能取“最新”。
- 已提交完整 1,934 句复评 Job `2119709249634582529`
  （`n019_hpclong6k_20261109_163035`，d7、1 DCU、2 h，
  预计 0.75、最坏 2.0 卡时），使用
  `run_full_eval_param_ai.sh`，label `hpclong6k`，
  checkpoint SHA256 `4452ad40022ef509b7d6fda7a3786cc12eef6e29704bd51be2ccc5e4e1485040`。
- 训练继续（step 8,820，8k snapshot 已落盘），后续 8k/10k/12k
  继续筛选；若 6k 仍是峰值，则以 6k 的完整复评为新的正式结果。

### 2026-11-09 17:00 完整 1,934 句复评：hpclong6k 刷新正式结果

- Job `2119709249634582529`（`n019_hpclong6k_20261109_163035`）
  正常完成（`N019_FULL_QUALITY_COMPLETE`），`quality_metrics.json`
  SHA256 `9485d3a1c78c9a5207f1bcf2e78df2204adf15d9ca1bf96dc58c014eb61e9fa9`。
- 计数核验：WER 1,496 句、UTMOS/WhiSQA 各 1,934 句；
  checkpoint SHA256 `4452ad40…5040`、step 6000。

| 指标 | 论文 | 新结果 hpclong6k | 旧正式 2x14k | 相对论文 |
|---|---:|---:|---:|---:|
| WER % | 7.41 | **6.2125** | 6.5093 | **-1.1975 pp（优于论文）** |
| UTMOS | 3.63 | **3.0540** | 2.8774 | -0.5760 |
| WhiSQA | 3.69 | **2.9723** | 2.8632 | -0.7177 |

- 相对旧正式结果：UTMOS `+0.1766`、WhiSQA `+0.1092`、
  WER `-0.2968 pp`，三项同向改善。这是目前唯一同时满足
  “全量 1,934 + 官方 VPC 流程 + 计数核验”的新正式候选，
  但在 HPClong 谱系完成 8k/10k 选模前先标注为候选，
  待确认 6k 是否仍是峰值后再定稿。
- d7 余额已用到约 16.1 卡时；HPC d6 长训仍在跑（step 11,580），
  8k/10k snapshot 已同步并提交选模 Job
  `2119717700279955457`（`n019_vocselhq_20261109_170409`）。

- 18:07 8k/10k 选模完成（Job `2119717700279955457`）：

| candidate | UTMOS | WhiSQA | WER % |
|---|---:|---:|---:|
| baseline | 2.134479 | 2.120908 | 21.590909 |
| hpclong 8000 | 2.824213 | 2.524383 | 20.236014 |
| hpclong 10000 | 2.814773 | 2.424114 | 20.891608 |
| hpclong 6000（当前最佳） | 3.066984 | 2.672135 | 19.842657 |

  6k 仍是明显峰值；8k/10k 回落到 2.82 左右，但都优于旧最佳
  2.784。说明该谱系在 6k 处出现过一次强峰，后续仍有再次冲高的可能。
- 训练到 17,460 step（3.27 h），12k/14k snapshot 已同步到 d7
  并提交选模 Job `2119734465512976385`
  （`n019_vocselhr_20261109_181047`）。

### 2026-11-09 18:40 12k/14k 未超过 6k；启用 d7 HPC 选模

- d7 选模 Job `2119734465512976385` 已完成，固定 dev-100：

| candidate | UTMOS | WhiSQA | WER % |
|---|---:|---:|---:|
| baseline ext102k | 2.134479 | 2.120908 | 21.590909 |
| hpclong 12000 | 2.776523 | 2.460104 | 20.498252 |
| hpclong 14000 | 2.702415 | 2.490007 | 20.236014 |

  两者均明显低于 hpclong 6k 的
  `3.066984 / 2.672135 / 19.842657%`，不提交全量复评。
  d6 HPC 长训 Job `1069636` 在 18:34 到 step 19,920，
  loss 有限，仍以约 0.67 s/step 运行。
- 16k/18k compact snapshot 已从 d6 经本机中转至 d7，源/目标
  SHA256 一致：
  - 16k `6fe2f37cde69e6bcf69968f056a17e1d64a8e29bdab11c5d7e3967b054aa093f`
  - 18k `9556a40819eac1a2e2e202193536a2d80d24f56560e1c33fb49066490de61d2e`
- 新增 `hpc/n019_vocoder_selection_hpc.slurm`，已同步 d7 并通过
  `bash -n` 和 `sbatch --test-only`。提交前 d7 HPC RawUsage 为
  0，50 h 免费额度未消耗，且 d7 当前无其他 Slurm Job。
- 已提交 d7 HPC 选模 Job `1071367`，任务名
  `n019_vocsel_hpc`；`hx1hdnormal`、1 DCU、16 CPU / 60 G、
  4 h 墙钟，预计 0.8、最坏 4.0 卡时。输入固定为 dev-100、
  ext102k baseline、hpclong 16k/18k；输出
  `runs/n019_official/vocoder_selection_hpclong1618_20261109_1836`。
  停止条件为输入/SHA256/计数不符、指标非有限、evaluator 非零、
  DCU/内存/存储错误、10–15 分钟无进展或达到 4 h 墙钟。

### 2026-11-09 18:50 16k/18k 未超过 6k；新增 FP32 对照分支

- d7 HPC 选模 Job `1071367` 已完成，固定 dev-100：

| candidate | UTMOS | WhiSQA | WER % |
|---|---:|---:|---:|
| baseline ext102k | 2.134479 | 2.120908 | 21.590909 |
| hpclong 16000 | 2.983690 | 2.577243 | 20.673077 |
| hpclong 18000 | 2.924862 | 2.572085 | 20.541958 |

  16k/18k 均低于 hpclong 6k 的
  `3.066984 / 2.672135 / 19.842657%`。
  `selection.json` SHA256
  `1ce7735fbea196faa9d4b5822e120a37908c4fb1af3531e43312abea03f80d53`，
  `selection.md` SHA256
  `ecfdf07bd8fc1f4dd95306603efdd76deabe469666ddb7bd1250a8f4c518c0fa`。
- 零卡时差异审计：上游 commit
  `dbb92c8ddeb081e711adbe9a75714027cd447532` 的 `train.py`
  没有 AMP/autocast/BF16；当前 hpclong 系列 `meta.json` 明确为
  `"bf16": true`。此前未对此做受控 A/B，现列为剩余实现差异。
- `scripts/run_vocoder_ddp.sh` 新增 `N019_VOCODER_BF16`（0/1，
  默认 1）；同时把 records 改为可由 `N019_VOCODER_RECORDS`
  显式覆盖，便于 d7 只读复用 d6 已 finalize 的官方训练资产。
  本地和 d7 均 `bash -n` 通过。
- 为避免 7.7 GB 音频复制，d6 仅对 `/public/home/a094f4d6`
  设置 d7 的 traverse ACL；records、audio、codes、codebook、
  speaker embeddings 和 finalizer marker 已从 d7 逐项读取验证。
- 已提交 d7 HPC Job `1071434`，任务名 `n019_voc_fp32_hpc`；
  `hx1hdnormal`、1 DCU、16 CPU / 60 G、40 h 墙钟，预计 38、
  最坏 40 卡时。提交前 d7 HPC RawUsage `6556` 秒（约 1.82 h），
  50 h 额度仍可覆盖。初始化 checkpoint 为 hpclong 6k，
  SHA256 `4452ad40022ef509b7d6fda7a3786cc12eef6e29704bd51be2ccc5e4e1485040`；
  使用 FP32、lr `2e-4`、2x feature matching、batch 16、
  gradient clipping 0，每 2k 保存 snapshot。
- 输出：
  `runs/n019_official/vocoder_nt_hpc_hpclong6k_fp32_20261109`。
  停止条件为 ACL/输入 SHA/recipe/D-CU watchdog 失败、loss
  NaN/Inf、10–15 分钟无进展、evaluator 前 smoke 失败或达到
  40 h 墙钟。不得把它与 BF16 结果混写；完成后再按 dev-100
  逐快照比较。
- 首次 Job `1071434` 在 1 秒时失败：d7 的
  `scripts/run_vocoder_ddp.sh` 仍是未含 records/BF16 覆盖的旧
  版本，导致路径校验读取 d7 的 d4-path records 并报
  `PermissionError`。没有启动训练、没有 snapshot/指标。
- 已把更新后的 helper 移到 d7 `scripts/`，保留旧版
  `scripts/run_vocoder_ddp.sh.bak_before_fp32`；同步缺失的
  `verify_training_data_marker.py`。随后在 d7 登录节点实际运行
  marker verifier，确认 records `33,236`、records SHA256
  `5d3bb4d7…e50d`、embeddings SHA256 `698d1282…a866` 全部匹配。
- 已提交修正重试 Job `1071460`，名称 `n019_voc_fp32_r1`。
  2026-11-09 18:55 已运行并通过 recipe lock
  `370ef79b…7e9` / feature matching probe `4.0` 校验；仍需确认
  DCU watchdog、FP32 首个 step 和吞吐。不得重复提交该 Job。
- `1071460` 于 18:57 完成 watchdog、数据 marker、模型构建和首个
  FP32 step；首个 step 含预热为 `9.40 s`，随后稳定约
  `1.11 s/step`，loss 有限。按 39.5 h 估算约 12.8 万 step。
- 2026-11-09 19:10 headless 实时 AI 余额：
  d3 `1.3775`、d4 `0.5350`、d5 `4.2161`、d6 `26.5497`、
  d7 `15.6439`、d8/d9 各 `50` 卡时。未启动可见浏览器。
- 已提交 d7 AI dev-100 Job `2119749733360357377`，名称
  `n019_vocselhs_20261109_191127`；1 DCU、15 CPU / 59 GB、
  2 h，预计 1.4、最坏 2.0 卡时。输入为 hpclong 20k/22k
  checkpoint（SHA256 `0638298f…54cd`、`a0e0606b…0371`）、
  fixed dev-100 和 ext102k baseline；输出
  `runs/n019_official/vocoder_selection_hpclong2022_20261109_191127`。
  配置已回写 `submit:false` 与 JobID，不得重复提交。
- 为排除 MOS evaluator 口径错误，新增
  `scripts/run_original_libri_test_mos_ai.sh`，在 d7 原始
  `vpc/data/libri_test/wav.scp` 的 1,934 句上用与匿名结果完全相同
  的 UTMOS22/WhiSQA checkpoint 和预处理评分，并写入
  `eval/original_libri_test_mos/summary.json`，对照论文 Original
  `4.11 / 4.08`。
- 已提交 d7 AI Job `2119750575417610242`，名称
  `n019_orig_mos_20261109_191448`；1 DCU、15 CPU / 59 GB、
  1 h，预计 0.25、最坏 1.0 卡时。配置已回写 `submit:false`；
  不重跑已有匿名系统 MOS。
- d7 Job `2119750575417610242` 已完成，原始 `libri_test` 1,934 句：
  UTMOS `4.100698282824677`、WhiSQA `4.059702170918375`；
  论文 Original 为 `4.11 / 4.08`，仅差
  `-0.0093017172 / -0.0202978291`。这证明当前 UTMOS22、
  WhiSQA、Whisper-small、wav.scp 和预处理口径与论文基本一致，
  剩余 UTMOS/WhiSQA 差距不是 evaluator 造成的。
- 零卡时 target-embedding 审计：现有 speaker-mean-L2 来自
  target map 中出现的 1,924 个 target utterance，覆盖 843 个
  speaker；group size 为 `1 / 2.2823 / 13`
  （min / mean / max）。在完整 other-500 manifest 中，这 843
  个 speaker 实际有 `168,023` 条 utterance，group size 为
  `8 / 195 / 199.3155 / 815`。当前代理并非完整 speaker mean。
- 新增 `scripts/sample_target_speaker_manifests.py`：
  对 dev/test target-map speaker 并集按固定 seed 每 speaker
  抽 32 条，支持 deterministic shard；新增
  `scripts/merge_npz_shards.py` 做无重叠 NPZ 合并。
  dev target map 已生成：100 行，SHA256
  `68ed3924ace55934342443396c8c3cb6cccbe51adb371d8ffd5b6546e6a892c1`。
- 抽样结果共 `26,917` 行，两片：
  - shard0/2：13,503 行、422 speakers，SHA256
    `a2d558eafc90d212f7d6c8566b5bd8ea25cbadd5620c1430e2c6212339098cb9`；
  - shard1/2：13,414 行、421 speakers，SHA256
    `df7c752f87e507712b2e57a30a3b5083cf568f90a90400375c0e90cf2d5982ba`。
- 按此前 1,924 条 W-PRO utterance embedding 实测 3,066 秒
  线性外推，两片并行约 6 h。d4 仅向 d6/d7 开放 home
  traverse ACL，target audio/manifest 已从两账号实际读取。
- 首次两个 AI Job d6 `2119752513296613377`、d7
  `2119753439789150210` 都因 d4 `train-other-500` 嵌套目录
  ACL 不足，在首条随机 audio 打开时失败；没有 partial embedding
  或最终指标。已对 d4 该语料全树仅向 d6/d7 增加 `rX` ACL，
  `19:48:32` 完成，并对失败路径逐账号实际验证可读。
- ACL 修复后 d6 `2119759136319229954`、d7
  `2119759221633597442` 仍在首条 audio 报
  `LibsndfileError: System error`。d6 隔离 Job
  `2119759986798252033` 对前 20 条逐项输出：登录节点可读，
  但 AI 容器 uid0 全部 `FileNotFoundError(2)`。结论是 AI
  容器未挂载其他账号 `/public/home`，不是 ACL 或 libsndfile
  文件损坏。停止在两个 AI 容器内跨账号读取的方案。
- 改为在 d5 HPC Slurm 计算节点使用 `/public/home` 直接读取
  d4 audio。26,917 行合并 manifest SHA256
  `7de14b39f33b6e2c573532bc8e4d9467d62f2f8447d29b86a1f3189b0571f0fc`，
  已复制到 d5；同步最新 `extract_speakers/speaker/audio/manifest`
  后 `py_compile` 通过。
- d4 `sbatch --test-only` 为 Job `1071781`，预计
  2026-11-10 08:08 起，未提交。d5 `sbatch --test-only`
  为 Job `1071787`，预计 2026-11-10 04:26 起。
- 已提交 d5 HPC Job `1071788`，名称 `n019_tspk32_hpc`；
  `hx1hdnormal`、1 DCU、16 CPU / 60 G、14 h，预计 12、
  最坏 14 卡时。输入为 d5 本地合并 manifest、d5 W-PRO 和
  d4 other-500 audio；输出
  `processed/embeddings/target_speaker_mean32_hpc_20261109`。
  每 200 条保存 partial speaker means，可中断续跑。

### 2026-11-09 20:20 HPC speaker-mean ACL 修复与依赖重试

- 用户明确要求继续使用 HPC 模式，但不要使用 d8/d9；后续只使用
  d5/d6/d7。HPC 单账号仍为 1 DCU，50 h 额度按 DCU 占用计。
- d5 HPC Job `1071788` 在 60 秒时失败。错误不是 `soundfile` 本身：
  d5 无法穿越 `/public/home/a094f4d4`，登录节点
  `os.path.exists` 为 False，`stat` 返回 `Permission denied`。
- 已在 d4 `/public/home/a094f4d4` 为 d5 增加 `--x` ACL；d5 用
  py311 实际读取
  `train-other-500/1006/135212/1006_135212_000002_000001.wav`
  成功，`shape=(242160,1), sample_rate=24000`。失败 Job 没有
  partial embedding 或指标。
- 已提交 d5 HPC audio-mount smoke `1071847`：`hx1hdnormal`、
  1 DCU、4 CPU / 14 G、10 min，预计/最坏 0.17 卡时；输入为
  d5 manifest + d4 audio，输出
  `runs/n019_official/n019_tspk_mount_1071847.*`。
  `sbatch --test-only` 预计 2026-11-10 08:19 启动。
- 已提交依赖重试 `1071850`（`afterok:1071847`）：
  `n019_tspk32_hpc`、`hx1hdnormal`、1 DCU、16 CPU / 60 G、
  14 h，预计 12、最坏 14 卡时；输入为 d5 本地 manifest、
  W-PRO 和 d4 other-500 audio，输出
  `processed/embeddings/target_speaker_mean32_hpc_20261109`。
  每 200 条保存 partial。停止条件为 smoke 失败、manifest/ACL/
  evaluator 非零、非有限或非 250-D/unit-norm 结果、10–15 分钟
  无进展、DCU/内存/存储错误或达到 14 h 墙钟。
- 实际调度比 `--test-only` 估计更快：smoke `1071847` 于
  20:05:43 完成，20/20 条 d4 audio 全部通过 `stat`、RIFF prefix
  和 `soundfile` 解码，输出 `TARGET_AUDIO_MOUNT_SMOKE_OK`。
- 依赖 Job `1071850` 于 20:06:01 自动启动，节点
  `f11r2n13`；manifest 预检 `26,917` 行 / `843` speakers 通过，
  已进入 W-PRO 提取。旧失败 Job `1071788` 无 partial 或指标。
- 为后续 dev-A/B 做自包含准备：d7 和 d6 分别从 d4 复制 dev-100
  target map 对应的全部 target audio。dev target map SHA256
  `68ed3924…92c1`，100 个 source 映射到 99 个唯一 target
  utterance（1 个 target 被复用）和 96 个 speaker。
  d6 本地 manifest SHA256
  `3a87a55ea3f130eba559a81d133f3378b02b4af5a3d84e39ef31246b5bbaef7c`。
- 2026-11-09 20:12 提交 d6 AI Job
  `2119765086666862593`（`n019_devtspk_20261109_201229`），
  1 DCU、15 CPU /
  59 GB、0.5 h 墙钟，预计 0.1、最坏 0.5 卡时。提交前 d6 AI
  余额 `26.5044444443`。它只在 d6 本地 99 条 target audio 上提取
  W-PRO utterance embeddings，输出
  `processed/embeddings/target_dev100_nt_utterance_20261109`；
  配置已回写 `submit:false` 和 JobID，不得重复提交。
- 已准备 dev 配对 A/B：`d7-dev-target-fullmean-ab`，但保持
  `submit:false`，等待 d6 sparse utterance embeddings 和 d5 完整
  speaker-mean 都完成并复制到 d7。任务固定 hpclong 6k checkpoint、
  dev-100 source/unit/target map、同一 duration predictor、同一
  UTMOS/WhiSQA/ASR，只切换 target embedding 口径。WER 参考文本
  优先读 source 侧 `*.normalized.txt`，避免再次出现空 transcript。
  资源为 1 DCU、15 CPU / 59 GB、1 h，预计 0.35、最坏 1.0 卡时；
  不满足 100 句/99-key/843-key、有限、unit norm 或计数条件即停止。
- d6 AI sparse Job `2119765086666862593` 在 GPU watchdog、manifest
  99 条和本地音频检查通过后失败：
  `torchaudio has no attribute functional`。根因是 d6 的
  `compat/torchaudio` 缺 `__init__.py` 和 `transforms.py`，Python
  回退到不含 `functional` 的旧模块；没有 embedding 或指标产出。
- 已从本地完整同步 `compat/torchaudio` 到 d6，并在 d6 激活环境后
  实测模块路径、`2.9.0+scnet-compat`、`functional=True` 和
  `resample` 函数均正确。提交前 d6 AI 余额仍为
  `26.5044444443`。
- 已提交最小重试 `2119766795812040705`
  （`n019_devtspk_r1_20261109_201916`），规格仍为 1 DCU、
  15 CPU / 59 GB、0.5 h，预计 0.1、最坏 0.5 卡时；
  输入/输出不变。配置已回写 `submit:false` 和 JobID，不得重复
  提交第一次失败的 Job。
- d5 speaker-mean Job `1071850` 于 20:27 正常完成，实际
  `1259 s = 0.35` 卡时，远低于原预计 12 h。输出 843 speakers /
  26,917 utterances、250-D；验证结果
  `norm_min=0.99999988, norm_max=1.00000012`。SHA256：
  - `nt_speaker_embeddings.npz`
    `d566b8f01d7def24c5784ba202f2bcbfc7d8f35fe84491cf47f2e64c7d928f23`
  - `metadata.json`
    `6bce9b946eb7ac564808eedbfb188ab7fc0704a043d7b1a8d3f00fd5f1a5e1e2`
  - `nt_speaker_manifest.jsonl`
    `01720a8ff0f29758c1f8dc4814b419417ec477167f59d606807f880339fb7a91`
- d6 sparse retry `2119766795812040705` 已正常完成：99 个唯一
  target utterance、250-D、finite、unit norm；NPZ SHA256
  `83eda132c2ac1b6b2d20febca64b7590537735dabdedff9b0df29499b2b95e9b`。
  AI 容器以 root 写出 metadata 且 mode 600，但 NPZ 实际可读且已
  验证，不需要为此再开卡。
- fullmean 与 sparse NPZ 已逐项经本机中转至 d7，源/目标 SHA256
  完全一致；d7 再次验证 `843/99 keys, 250-D, unit norm`。
- d7 AI 选模 Job `2119749733360357377` 已完成，20k/22k 都低于
  hpclong 6k：

| candidate | UTMOS | WhiSQA | WER % |
|---|---:|---:|---:|
| hpclong 20000 | 2.901247 | 2.560946 | 20.716783 |
| hpclong 22000 | 2.810531 | 2.501727 | 20.061189 |
| hpclong 6000（现行最佳） | 3.066984 | 2.672135 | 19.842657 |

  20k/22k 不进入完整 1,934 句复评。`selection.json` SHA256
  `32ebcd7c3a6fc454311417a40cdc56df4d1d08a57d42cb0c01fb7f9bd9722694`，
  `selection.md` SHA256
  `7bf7ee3d0050f358fa025a6810c7f2c56993cb94b5fbc44ac47f125b0e5ab4e2`。
- 2026-11-09 20:34 提交 d7 AI dev A/B
  `2119770508302110721`（`n019_devteab_20261109_203401`）：
  1 DCU、15 CPU / 59 GB、1 h，预计 0.35、最坏 1.0 卡时；
  提交前 d7 AI 余额 `14.5186111107`。固定 hpclong 6k、
  dev-100 source/unit/target map 和 duration predictor，只比较
  sparse utterance embedding（99 keys）与 mean32-L2 speaker
  embedding（843 keys）。输出
  `runs/n019_official/target_embedding_dev100_fullmean_ab_20261109_203401`。
  配置已回写 `submit:false` 和 JobID，严禁重复提交。
- dev A/B 的 UTMOS/WhiSQA 已完成，完整 32-sample speaker-mean 在
  两项 MOS 上都优于稀疏 utterance proxy：

| variant | UTMOS | WhiSQA | WER % |
|---|---:|---:|---:|
| sparse target utterance (99 keys) | 2.9607650697 | 2.8353551850 | 20.3234265734 |
| full speaker mean32-L2 (843 keys) | **3.0499821389** | **2.9503012195** | 20.5419580420 |
| delta（mean - sparse） | **+0.0892170692** | **+0.1149460346** | **+0.2185314685 pp** |

  同一 source、unit、target map、hpclong 6k checkpoint 和 duration
  predictor；两变体各 100 句。99 个唯一 target utterance 与 96 个
  target speaker 的 embedding 余弦相似度
  min/mean/max = `0.2549656034 / 0.7917744151 / 0.9693702459`，
  说明“稀疏代理”与完整 speaker mean 实为明显不同的条件向量。
- 原 Job 在完整 mean 变体最后 WER 阶段、UTC 约 21:29 被平台
  “容器异常退出”终止；前面的 100 句 WAV、UTMOS、WhiSQA 均已
  完整落盘，sparse WER 也已完整。不是 OOM/NaN/evaluator 结果错误，
  且没有 comparison 汇总。
- 已提交 WER-only 收尾 Job `2119787696965591041`
  （`n019_devtewer_20261109_214218`）：d7 AI、1 DCU、15 CPU /
  59 GB、0.5 h，预计 0.1、最坏 0.5 卡时；提交前 d7 AI 余额
  `13.0622222218`。只补 mean 变体 100 句 WER 并写
  `comparison.json/.md`，复用已有 WAV/UTMOS/WhiSQA。
  配置已回写 `submit:false` 和 JobID，严禁重复提交。
- WER 收尾 Job `2119787696965591041` 已完成。mean32 的 WER 为
  `20.541958%`，相对 sparse `20.323427%` 回归 `+0.218531 pp`，
  低于预声明 `0.25 pp` gate；UTMOS/WhiSQA 增益均超过 `+0.05`，
  因此 mean32 通过 dev eligibility。配对标准误：
  UTMOS `0.0499345`、WhiSQA `0.0354064`。`comparison.json`
  SHA256 `f7592cc83514cb77221260cba258826319d59af59c81e920000a5610d108fe9c`，
  `comparison.md` SHA256
  `a5ce4c3dbd21be9104adefe4a3cc69ded8dcdfeb3aabb062293d7ecc2dd3ed50`。
- 这项结果说明“完整 other-500 speaker mean”比之前平均
  1–13 条 target utterance 的稀疏代理更符合训练/推理口径，是
  一个真实的实现修正；其 dev 绝对增益仍不足以单独填平论文差距。
- 因 mean32 通过预声明 dev gate，已提交完整 1,934 句复评
  `2119791353482788865`（`n019_hpc6kmean32_20261109_215650`）：
  d7 AI、1 DCU、15 CPU / 59 GB、2 h，预计 0.9、最坏 2.0 卡时；
  提交前 d7 AI 余额 `13.0622222218`。固定 hpclong 6k
  checkpoint SHA256 `4452ad40…5040`、同一 duration predictor、
  test target map 和 mean32-L2 embeddings，重跑匿名化 +
  VPC 导出 + WER 1,496 / UTMOS / WhiSQA 1,934。输出
  `anonymised/libri_test/DU-pred-nt-hpclong6k_mean32`、
  VPC suffix `_n019_hpclong6k_mean32`、`eval/du_pred_nt_hpclong6k_mean32`。
  `run_full_eval_param_ai.sh` 已增加 target embedding 路径/key/mode
  参数化覆盖，d7 SHA256
  `6d17ce85a60959e8828399c1a74f1f9b64e79f7078e27ec1286f9e5251918535`。
  配置已回写 `submit:false` 和 JobID，严禁重复提交。
- 并行准备后续 checkpoint 选模：d7 的 self-contained dev-100
  子集经共享文件系统复制到 d6 本地
  `processed/selection_dev100_2x24k_20261108_d6copy`（28 MB），
  manifest/unit records 的绝对路径已逐项改写并验证
  `missing=0, outside_root=0, records=100`。
- d6 原缺 `wer_eval_vpc` 使用的官方 ASR 权重，已从 d7 同文件系统
  复制到本地 `models/n019_official/vpc/exp/asr_n019_local`
  （1.2 GB）；UTMOS/WhiSQA/duration 原本已存在。
- 已提交 d6 AI Job `2119794137201131522`
  （`n019_vocselh3_20261109_220754`）：1 DCU、15 CPU /
  59 GB、2 h，预计 1.5、最坏 2.0 卡时；提交前 d6 AI 余额
  `26.3063888888`。固定同一个 self-contained dev-100，直接以
  hpclong 6k 为 baseline，比较 30k/32k/34k/36k snapshot 的
  source reconstruction、UTMOS、WhiSQA、WER。输出
  `runs/n019_official/vocoder_selection_hpc30k36k_20261109`。
  配置已回写 `submit:false` 和 JobID，严禁重复提交。
- d6 选模首次 Job `2119794137201131522` 在 GPU watchdog 和全部
  输入前置检查中通过，但随后因 d6 缺 Whisper-small 本地缓存退出：
  `models--openai--whisper-small/.../config.json` 不存在。
  没有 candidate、reconstruction 或指标产出。失败不是 bad DCU。
- 已从 d7 同文件系统复制 `3.7 GB` Whisper-small 缓存到 d6；D6
  AI 余额仍 `26.3063888888`。提交最小重试
  `2119795852910112769`（`n019_vocselh3r1_20261109_221443`），
  规格/输入/输出不变，仍为 1 DCU、15 CPU / 59 GB、2 h，
  预计 1.5、最坏 2.0 卡时。配置已回写 `submit:false` 和 JobID，
  不得重复提交首次失败 Job。

### 2026-11-09 22:35 mean32 全量完成与选模 r2

- 用户明确要求后续不使用 d8/d9；只允许 d5/d6/d7。
- d7 AI 全量 Job `2119791353482788865`
  （`n019_hpc6kmean32_20261109_215650`）三项指标完成并核验：
  WER `6.07842018149649%` / 1,496、
  UTMOS `3.0965501278361467` / 1,934、
  WhiSQA `3.017711649343541` / 1,934。相对论文
  `7.41 / 3.63 / 3.69`，WER 已优 `1.33157984 pp`，
  UTMOS 差 `-0.53344987`，WhiSQA 差 `-0.67228835`。
  相对旧正式 hpclong6k-sparse，三项分别改善
  `0.13412482 pp / +0.04255713 / +0.04539765`。
- mean32 产物目录：
  `anonymised/libri_test/DU-pred-nt-hpclong6k_mean32` 有
  1,934 WAV，`vpc/data/libri_test_n019_hpclong6k_mean32/wav.scp`
  有 1,934 行。JSON SHA256：
  - `WER.json`
    `31a4bf95e6122356842adb35b82722d80de6e286d2d8027d460d134171d4fafa`
  - `mos/UTMOS.json`
    `c9ddcdabd83e5383b69120f7de88e355ad9aab9390af9b2d637e2cf138c6c190`
  - `mos/WhiSQA.json`
    `53494bfab904274568a9b3e91c16778fd0d9319ee8b746e0440bc86e2cab9cb8`
  - `quality_metrics.json`
    `bc16b9cb96c0b95c648247ea99ecc1659c750f804067b89d45eb991face80451`
- d6 选模首次 Job `2119794137201131522` 缺 Whisper cache；
  r1 `2119795852910112769` 在 watchdog 后因 d6
  `n019.vocoder.UnitVocoderConfig` 是旧版、不能接收 checkpoint
  中的 `grad_clip_norm` 而退出。两者都没有 candidate 或指标。
- 已备份 d6 旧文件为
  `src/n019/vocoder.py.bak_before_gradclip_20261109`，同步最新
  `vocoder.py`，SHA256
  `5a7b94e548350eeba0822d7dcf7b10cbef0d90bbf97d73f05588f984943bc688`；
  在 d6 官方环境实测 `UnitVocoderConfig().grad_clip_norm == 0.0`。
- 提交前实时 d6 AI 余额 `26.1605555554`。已提交选模 r2
  Job `2119799118639157249`
  （`n019_vocselh3r2_20261109_222742`）：人工智能/模型训练、
  `113 组`、1 DCU、15 CPU / 59 GB、2 h，预计 1.5、
  最坏 2.0 卡时。输入为固定 self-contained dev-100、
  baseline 6k、30k/32k/34k/36k snapshots、duration、
  UTMOS22、WhiSQA 和 VPC ASR；输出
  `runs/n019_official/vocoder_selection_hpc30k36k_20261109`。
  配置已回写 `submit:false` 和 JobID，严禁重复提交。
  停止条件为任一路径/计数/SHA 校验失败、指标非有限、
  evaluator/DCU/内存/存储错误或达到 2 h 墙钟。
- HPC 长训正常：d6 BF16 `1069636` 到 step `40,760`，
  snapshots 到 40k；d7 FP32 `1071460` 到 step `11,320`，
  snapshots 到 10k。两者 loss 有限。
- 本轮没有使用 d8/d9。
- mean32 的 32 句/说话人仍是近似。已在 d5 构造 843 个目标
  speaker 在完整 LibriTTS train-other-500 中的全部
  `168,023` 行 manifest；group size
  min/median/mean/max = `8 / 195 / 199.315539739 / 815`，
  SHA256
  `284f86fa16c1ef9317fb96f422d49647a45a7e497b309232189c738141cd2723`。
- 已提交 d5 HPC Job `1072805`（`n019_tspkfull_hpc`）：
  `hx1hdnormal`、1 DCU、16 CPU / 60 G、6 h，预计约 2.2、
  最坏 6.0 卡时；输入为
  `processed/targets/target_speaker_full843_other500.jsonl`、
  d4 原始 other-500 audio 和 d5 W-PRO；输出
  `processed/embeddings/target_speaker_fullmean843_hpc_20261109`。
  批处理每 1,000 条保存 partial，停止条件为 manifest/ACL、输出
  shape/finite/unit-norm、无进展、DCU/内存/存储错误或 6 h 墙钟。
  `sbatch --test-only` 为 Job `1072803`（未运行）；实际提交
  `1072805` 已进入 `f11r2n13`。脚本 SHA256
  `aa8e4efcbde300274b59318336810dc71b3c136dc72375966f138b825bf3b9df`。
- d7 FP32 分支已到 step `11,320`，已有 2k/8k/10k snapshots。
  已于 22:35 提交 d7 AI Job `2119801099336699905`
  （`n019_vocselfp32_20261109_223533`）：人工智能/模型训练、
  `113 组`、1 DCU、15 CPU / 59 GB、2 h，预计 1.5、
  最坏 2.0 卡时；提交前余额 `12.3988888885`。固定同一
  dev-100，以 hpclong 6k 为 baseline，比较 FP32 2k/8k/10k，
  若启动时 12k 已出现也会纳入。输出
  `runs/n019_official/vocoder_selection_hpclong6k_fp32_20261109`。
  配置已回写 `submit:false` 与 JobID，不得重复提交。
- d6 选模 r2 `2119799118639157249` 失败：baseline 100 句
  reconstruction 已完成，但 d6 无 UTMOS demo 和 overlay；
  `eval_mos` 在 `score.py` 前置检查退出。平台状态已确认失败。
  没有 UTMOS/WhiSQA/WER/candidate 产出，不是 DCU 或模型问题。
- 已从本机中转 UTMOS demo，并在 d6 验证 `score.py`
  `95b0ef25…75d0`、`model.py` `79ca330b…36d4`、
  `lightning_module.py` `def23a75…313f`；从 d7 共享文件系统
  复制 63 MB overlay（PL `1.5.10`、torchmetrics `0.7.2`）。
  d6 CPU 2 句 UTMOS smoke 完成，mean `3.0354788303`。
- 选模脚本已把 UTMOS demo/overlay 与 WhiSQA `get_score.py`
  加入前置门禁，并同步 d6/d7，防止再次跑到 scorer 才失败。
- 提交前 d6 AI 余额 `26.0583333332`。已提交 r3
  `2119803120709050369`（`n019_vocselh3r3_20261109_224336`）：
  1 DCU、15 CPU / 59 GB、2 h，预计 1.3、最坏 2.0 卡时。
  固定输出仍为
  `runs/n019_official/vocoder_selection_hpc30k36k_20261109`；
  baseline reconstruction 被复用，只补 baseline 指标并跑
  30k/32k/34k/36k。配置已回写 `submit:false` 和 JobID。
- 为避免只停在短训练 checkpoint，已准备 d5 HPC 长训：
  - 账号/模式：`a094f4d5` / HPC Slurm；
  - Job `1072951`、名称 `n019_vocd5_48h`、依赖
    `afterok:1072805`；
  - `hx1hdnormal`、1 DCU、16 CPU / 60 G、48 h，
    预计 47.5、最坏 48.0 卡时；
  - 输入：d4 原始官方 LibriTTS clean-100 records 33,236 行
    （SHA256 `edf45431…f795`）、NT embeddings
    （SHA256 `698d1282…a866`）、hpclong 6k
    （SHA256 `4452ad40…5040`）；
  - 配方：BF16、lr `2e-4`、batch 16、feature matching 2x、
    gradient clipping 0、每 2k snapshot；
  - 输出：
    `runs/n019_official/vocoder_nt_hpc_d5_hpclong6k_20261109`；
  - 停止：依赖/marker/recipe/DCU/输入失败、loss 非有限、
    10–15 分钟无进展或 47.5 h。
  - 独立代码目录
    `code/n019_official_lr2e4_hpc_20261109`；bundle SHA256
    `239928f83c42c45458ff8f708368ffd55b97abd22c807b1700a11a2909ca238d`，
    launcher SHA256
    `f3f9d72631e29e829cde25640e754ce19e46a96294bcc2c15190e1f9ebf90188`。
  - `sbatch --test-only` 为 Job `1072949`（未运行），实际提交
    `1072951` 已处于依赖等待。
- 全量 1,934 句生成音频诊断已完成（0 卡时）：无削波；
  generated/source RMS `0.087319/0.058743`、peak
  `0.738055/0.534074`；总时长比 mean `1.00309`、p05/p95
  `0.88903/1.09679`。UTMOS/WhiSQA 与绝对时长误差相关
  `-0.125/-0.177`，说明剩余 MOS 差距主要不是 duration。
  输出
  `runs/n019_official/audio_diagnostic_hpclong6k_mean32_20261109.json`，
  SHA256 `52ac7c43…1f63`。

### 2026-11-09 23:12 d5 改为 hpclong step 44000

- 日期：2026-11-09 23:12（Asia/Shanghai）。
- 账号/模式：`a094f4d5` / HPC Slurm。
- JobID / 任务名：`1073179` / `n019_vocd5_44k_45h`。
- 资源：`hx1hdnormal`、1 DCU、16 CPU / 60 G、45 h；
  预计 44.5、最坏 45.0 卡时。该 HPC 账号本日前序任务约
  0.4 h，另有 target-fullmean Job `1072805` 预计约 2.2 h，
  本任务限制为 45 h，以覆盖 50 h 配额风险。
- 依赖：`afterok:1072805(unfulfilled)`；只有完整 target
  speaker mean 任务成功后才启动。
- 输入：
  - d4 官方 LibriTTS clean-100 `unit_records.jsonl`，33,236 行；
  - d4 clean-100 250-D NT speaker embeddings；
  - d5
    `data/n019_official/checkpoints/n019_hpclong/generator_step00044000.pt`，
    56,858,091 B，SHA256
    `401fd227bbe484e146294af2fd916cd1dfc8a343e0def4e98b4bcfa5db71efdc`。
- 输出：
  `runs/n019_official/vocoder_nt_hpc_d5_hpclong44k_20261109`。
- 配方：BF16、lr `2e-4`、batch 16、feature matching 2x、
  gradient clipping 0、每 2k snapshot、无 mel-L1 早停。
- 停止条件：依赖/输入/SHA/DCU/recipe 失败、loss 非有限、
  10–15 分钟无进展、存储不足或 44.5 h 内部预算。
- 提交前旧 pending Job `1072951` 已取消；它从未启动，不计卡时。
  新 launcher SHA256
  `e018feb4af79f1ac60585b51e24ed71baab3e1483e5cb3974fc65141ad209591`。
- hpclong d6 Job `1069636` 在 23:11 的日志 step 为 `44,640`；
  最新持久 snapshot 为 step `44,000`，同步 `last.pt` SHA256
  `6934b9388672723d7f846de9220df01fdad4af154762ea3a3e43779a2d1471e0`。
- 本轮未使用 d8/d9。

### 2026-11-09 23:20 选模评测链修复与重提

- d7 旧 Job `2119801099336699905` 已完成 baseline 的 100 句
  reconstruction、UTMOS、WhiSQA、WER，指标分别为
  `3.0669834614 / 2.6721351326 / 19.8426573427%`。
  随后 Bash 读到 `'\n,'` 并报 command not found。脚本文件当前
  `bash -n` 和内容检查均正常，判断为任务运行期间脚本被并发
  改写，Bash 按字节继续读取而得到损坏尾行；不是模型或 DCU 故障。
- d6 旧 Job `2119803120709050369` 的 baseline reconstruction 和
  UTMOS 均完成
  （`3.0669832468`），随后 WhiSQA 仍硬编码
  `openai/whisper-small`。根因是 d6 `eval_mos.py` 仍为旧版，
  缺少 d7 已有的本地路径注入。Whisper cache 和 `refs/main`
  本身均正确。
- 已备份并同步 d6
  `src/n019/eval_mos.py`，SHA256
  `332cb0f11ad652e78985705ee20961ee1ea73e78d1b4ddbd7d91c6ef4f9c55ea`。
  d6 2 句 CPU WhiSQA smoke 完成，count 2、mean
  `2.678769826889038`、模型与代码 SHA256 正常落盘。
- 新任务：
  - 日期：2026-11-09 23:19；
  - d6：Job `2119812079720611841`，名称
    `n019_vocselh3r4_20261109_231912`；
  - d7：Job `2119812139830759426`，名称
    `n019_vocselfp32r1_20261109_231926`；
  - 模式均为人工智能/模型训练，`113 组`，各 1 DCU、
    15 CPU / 59 GB、2 h；预计 1.3 / 1.5、最坏各 2.0 卡时；
  - 提交前余额：d6 `25.8558333332`、d7
    `12.1211111107` 卡时；
  - 输出沿用
    `vocoder_selection_hpc30k36k_20261109` 与
    `vocoder_selection_hpclong6k_fp32_20261109`，复用已有
    baseline reconstruction/指标；
  - 停止条件：100 句计数、输入/SHA、UTMOS/WhiSQA/Whisper/
    ASR、DCU tiny matmul、指标非有限、内存/存储错误或 2 h。
- 两项任务在 23:20 均已进入“运行中”。配置已回写
  `submit:false` 和真实 JobID。本轮仍未使用 d8/d9。

### 2026-11-09 23:43 d6 WER 评测链修复、r5 与 d7 2k 指标

- d6 Job `2119812079720611841`（r4）完成 baseline
  reconstruction、UTMOS、WhiSQA 后，在 WER 启动时失败：
  `No module named n019.wer_eval_vpc`。WhiSQA 本次已成功，
  证明上一轮本地 Whisper 修复有效。
- 已同步 `wer_eval_vpc.py`，并把其 VPC SpeechBrain ASR
  inference 改为按文件路径直接加载，避免无关的
  `evaluation/__init__.py` eager import
  `pandas/pyloudnorm`。最终 SHA256
  `7173970161ac3aa03d40fb23ba90a5895c41b3a324a575cff58cd9640f70b03a`，
  d6/d7 相同，均保留 `.bak_before_lazy_vpc_import_20261109`。
- d6 2 句 CPU WER smoke 通过：
  `utterances=2, references=2, wer_percent=20.895522388059703`。
  本地 `PYTHONPATH=src python -m pytest -q tests` 为
  `123 passed, 3 skipped`。
- 新 Job `2119817726150946817`，名称
  `n019_vocselh3r5_20261109_234138`：d6、人工智能/模型训练、
  `113 组`、1 DCU、15 CPU / 59 GB、2 h，预计 1.3、
  最坏 2.0 卡时；提交前 d6 AI 余额 `25.75`。输出不变，
  复用 baseline reconstruction/UTMOS/WhiSQA，只补 WER 和
  candidate 30k/32k/34k/36k。23:42 已确认运行中。
  配置已回写真实 JobID 和 `submit:false`。
- d7 r1 的 FP32 首个 candidate：
  - baseline：UTMOS `3.0669834614`、WhiSQA
    `2.6721351326`、WER `19.8426573427%`；
  - step 2000：UTMOS `2.7258257794`、WhiSQA
    `2.5131241292`、WER `20.4982517483%`；
  - step 2000 三项均回归，不入选，继续 8k/10k/12k。
- d5 fullmean Job `1072805` 正常，23:42 已到
  `103,000 / 168,023`；d5 44k 受依赖 Job `1073179`
  仍为 PENDING。本轮未使用 d8/d9。

### 2026-11-09 23:50 d6 ASR 本地路径修复、r6 与 FP32 8k

- d6 r5 Job `2119817726150946817` 在 AI 容器启动 WER 后失败：
  `asr_n019_local/hyperparams.yaml` 的 `wav2vec2_hub` 仍为
  `/public/home/a094f4d7/...asr_n019_local`。登录节点能跨账号
  读取 d7，因此此前 2 句 smoke 未暴露该问题。
- 已备份 `hyperparams.yaml.bak_before_local_asr_path_20261109`，
  把 `wav2vec2_hub` 改为
  `/public/home/a094f4d6/.../asr_n019_local`，并确认排除备份后
  目录内不再含 d7 路径。2 句 CPU WER smoke 再次通过：
  `20.895522388059703%`。
- 新 Job `2119819757712420866`，名称
  `n019_vocselh3r6_20261109_234943`：d6、人工智能/模型训练、
  1 DCU、15 CPU / 59 GB、2 h，预计 1.3、最坏 2.0 卡时；
  输出不变，复用 baseline reconstruction/UTMOS/WhiSQA，
  只补 baseline WER 与 30k/32k/34k/36k。配置已回写
  `submit:false` 和真实 JobID。
- r6 已跑通 baseline 完整 100 句：
  UTMOS `3.0669832468032836`、
  WhiSQA `2.6721348732709886`、
  WER `19.842657342657343%`；随后进入 30k reconstruction。
  d6 的 UTMOS/WhiSQA/WER 三段评测链现已全部跑通。
- d7 FP32 step 8000 candidate：
  UTMOS `2.879524028301239`、
  WhiSQA `2.521873888373375`、
  WER `20.41083916083916%`。相对 baseline
  `3.0669834614 / 2.6721351326 / 19.8426573427%` 仍全面
  回归，不入选；继续测 10k/12k。
- d5 fullmean 在 23:55 已到 `123,000 / 168,023`，
  44k 长训依赖队列 `1073179` 仍正常等待。

### 2026-11-09 23:58 vocoder batch-size 口径审计与 batch32 smoke

- 发现一处明确配方差异：
  `configs/paper_algorithm_v1.json` 记录
  `vocoder_batch_size=32`，但 `hpc/n019_vocoder_hpc_long.slurm`
  和当前 d5/fp32 脚本均设置 `N019_VOCODER_TOTAL_BATCH=16`。
  这意味着当前长训每个 optimizer step 只有配置值的半量。
- 新增 `scripts/vocoder_batch32_smoke_ai.sh`，读取 d6 本地
  clean-100 records/embeddings，先运行 300 秒 DCU watchdog，
  再用 BF16、batch 32、3 steps 做最小资源验证。脚本 SHA256
  `08dc657d79a12a10a7590aa7f141c88bf2669648bf2971926bf4924e0653d782`。
- 已提交 d6 AI Job `2119821869353947137`
  （`n019_batch32smoke_20261109_235806`）：
  人工智能/模型训练、1 DCU、15 CPU / 59 GB、0.5 h，
  预计 0.15、最坏 0.5 卡时；提交前 d6 余额 `25.75`。
  输出
  `runs/n019_official/vocoder_batch32_smoke_20261109_235806`。
  停止条件为 watchdog 失败、OOM、loss 非有限、不是 3 steps
  或达到 0.5 h。配置已回写真实 JobID 和 `submit:false`。
- 该 smoke 决定 d5 长训是否从 total batch 16 修正为 32；
  在结果出来前不改动运行中/排队中训练。
- 首次 d6 batch32 smoke 不能用于显存判断：smoke 脚本设置了
  `N019_SKIP_PATH_VERIFY=1` 但未提供 marker，导致
  `run_vocoder_ddp.sh` 在模型构建前退出。已移除 skip，并让
  96 条本地记录走正常路径校验；脚本修正版 SHA256
  `e967e19b8fa785aadbfefdc6d0800141136e4939cda8dddeb88ffdc2121d5eec`。
- d7 FP32 step 10000 candidate：
  UTMOS `2.901968379020691`、
  WhiSQA `2.462408086657524`、
  WER `21.066433566433567%`；仍全面低于 baseline，
  FP32 分支基本排除，只等 12k 收尾。
- 已提交修正版 d7 smoke Job `2119823883898736641`
  （`n019_batch32smoke_d7_20261110_000605`）：
  人工智能/模型训练、1 DCU、15 CPU / 59 GB、0.5 h，
  预计 0.15、最坏 0.5 卡时；提交前 d7 余额 `12.12`。
  配置已回写 `submit:false` 和真实 JobID。
- d6 HPC step 30000 candidate：
  UTMOS `2.7515156269073486`、
  WhiSQA `2.5546909496188164`、
  WER `20.847902097902097%`；仍全面低于 baseline，
  不入选，继续测 32k/34k/36k。
- d7 batch32 smoke Job `2119823883898736641`
  无法运行：d7 的 full unit records 指向 d4 audio/codes，
  AI 容器不可见且 d7 本地缺少 audio。不是显存/OOM。
- d6 batch32 smoke 首次因 skip/marker 配置错误退出；第二次
  d6 创建页超时且确认未创建任务。第三次提交成功：
  Job `2119827168643141634`
  （`n019_batch32smoke_r1_20261110_001908`），
  1 DCU、15 CPU / 59 GB、0.5 h，预计 0.15、最坏 0.5 卡时。
  d6 完整 records 为本地路径，script 已改为正常本地路径校验。
  配置已回写 `submit:false` 和真实 JobID。

### 2026-11-10 00:42 d5 改为从 hpclong 最新完整 last.pt 断点续训

- d6 hpclong Job `1069636` 在 00:34 写出 step `52,000` 的完整
  `last.pt`：1,019,512,015 bytes，SHA256
  `d3930bab8ddd307714e81356e52d4373c5192b18bf3950eedd86fc2b2c34bcfe`。
  训练继续运行，00:41 日志已到 step `52,640`；在 d5 启动时，
  这个稳定归档是当前最后完整 checkpoint。
- 原 d5 Job `1073179`（`n019_vocd5_44k_45h`）在依赖解除后于
  00:26:38 启动，只运行 10 秒即被取消，未产生训练文件或指标。
  因此没有从旧 44k generator-only 文件实施续训。
- 首个 50k 过渡 Job `1073959` 在 00:36:21 启动，仍处 preflight
  时发现 d6 已写出 52k 完整 `last.pt`，于 00:36:50 取消；
  同样未产生训练文件。
- 新 Job `1074023`（`n019_vocd5_52k_45h`）于 00:41:46 在
  `f11r2n12` 启动。d5 HPC、1 DCU、16 CPU / 60 GB、外层 45 h，
  预计 44.5、最坏 45.0 卡时；BF16、total batch 16。
- 输入是上述 52k 完整状态，已复制为
  `/public/home/a094f4d5/voice_projects/runs/n019_official/vocoder_nt_hpc_d5_hpclong52k_20261110/last.pt`；
  源、本机中转和目标 SHA256 三项一致。训练将从 step 52,001
  恢复 generator、MPD、MSD、两个优化器和 scheduler。
- 输出目录为同一路径；训练数据仍是 33,236 条 clean-100 records，
  embedding SHA256
  `698d128292e8abbdb0db5d39301539cfc80184b8982133566ba3bf8b6492a866`，
  2x feature-matching recipe lock 已通过。
- 停止条件：DCU/环境/checkpoint recipe 校验失败、OOM、loss 非有限、
  到达 44.5 h 或外层 45 h。未使用 d8/d9。

### 2026-11-10 00:52 full-168023 target mean 与 batch32 smoke 审计

- d5 full target-mean Job `1072805` 已于 00:26:37 正常完成：
  843 speakers、168,023 utterances、250-D；所有值有限，
  norm min/mean/max
  `0.9999998808 / 1.0 / 1.0000001192`。NPZ SHA256
  `704c80a0f8b081956ff5a16a51f77493ad6514135b421154b0ffffaabee04017`，
  metadata SHA256
  `9032e8634031ed35b8e59f12217eb79ed4f6aeedcfad827161038b736a1bf974`。
- 该 NPZ 已经本机中转至 d7
  `processed/embeddings/target_speaker_full168023_mean843_20261110`，
  源、本机、目标 SHA256 一致。
- 首次 d7 A/B Job `2119834331477221377` 因左侧 mean32 仍按
  `target_id/utterance` 读取而快速失败，未产生 WAV 或指标。
  已修正为 `target_speaker/speaker_mean_l2`。
- 新 A/B Job `2119835087797071874`
  （`n019_devtfull_20261110_005036`）已提交并运行：
  d7、人工智能/模型训练、1 DCU、15 CPU / 59 GB、1 h，
  预计 0.35、最坏 1.0 卡时；提交前 d7 AI 余额
  `11.1491666663`。在同一 dev-100、hpclong 6k、duration
  predictor 和评测器上比较 mean32 与 full-168023 mean；
  只有 MOS 均提升且 WER 回归不超过 `0.25 pp` 才进入全量。
- 本地 `run_target_embedding_ab_ai.sh` 已增加模型加载前的
  key/mode/250-D/finite/unit-norm 快速校验；本地测试
  `123 passed, 3 skipped`。为避免并发改写正在运行的脚本，
  远端同步待当前 A/B 结束后执行。
- d6 selection `2119819757712420866` 已选择 hpclong 6k：
  step 36k 的 UTMOS 为 `3.1135340381`，但 WhiSQA
  `2.6509445786`、WER `20.410839%`，低于 baseline
  `3.0669832468 / 2.6721348733 / 19.842657%` 的资格线；
  step 32k/34k/30k 同样不入选。
- d6 batch32 smoke `2119827168643141634` 平台状态失败。
  实际不是 OOM：d6 旧版 `run_vocoder_ddp.sh` 把
  `RECORDS` 硬编码为完整 33,236 条，忽略了 smoke 的 96 条
  records，CPU 路径校验和 DCU preflight 用掉 30 分钟，
  在外层 timeout 前尚未进入 3-step 训练。因此 batch32
  显存结论仍未验证，d5 继续使用 total batch 16。

### 2026-11-10 01:43 target full-mean A/B 与 batch 口径收口

- full-168023 target speaker mean 的 dev-100 A/B 已完成
  （d7 Job `2119835087797071874`）：

| target embedding | UTMOS | WhiSQA | WER % |
|---|---:|---:|---:|
| mean32-L2 | 3.0499822199 | **2.9503008768** | 20.541958 |
| full-168023 mean-L2 | **3.0598460257** | 2.9496085644 | **20.367133** |
| full - mean32 | +0.009864 | -0.000692 | -0.174825 pp |

  UTMOS 配对差 `+0.009864 ± 0.015744`，WhiSQA
  `-0.000692 ± 0.007907`，不满足双 MOS 各 `+0.05`
  的预声明门槛。因此 fullmean 只保留为更严格的全量
  speaker aggregation 诊断，不替换当前正式 mean32。
- 首次 A/B 因 mean32 左侧误用 `target_id/utterance` 快速失败；
  修正后指标完整。汇总阶段又发现脚本漏 `import statistics`，
  已修复本地并同步 d6/d7，脚本 SHA256
  `a36a37adee48068b0893ff7619f766eb37b4095b394c28af91569a57fd2f817a`。
  该次 comparison 由零卡时补算：
  `runs/n019_official/target_embedding_ab_mean32_vs_full168023_20261110_summary`，
  `comparison.json` SHA256
  `aa210efafe79fb618d0ea6fe5ca82a5fd5ed6fbe4b9f6fd12b0393dff9b3389c`。
- 审计确认上游 `configs/VCTK/hubert100_lut.json` 的
  `batch_size=16`；论文“two RTX 4090 GPUs”更合理对应
  NT/ECAPA 两个模型各一张卡。已将 `UnitVocoderConfig`、
  CLI 默认和 `paper_algorithm_v1.json` 的 vocoder batch 统一为 16，
  并新增配置/代码一致性测试。
- d5 Job `1074023` 正常推进，01:43 到 step `57,440`，
  loss 有限，约 `0.68 s/step`；已产出 54k/56k generator snapshots。
  54k SHA256 `732ba853…372e`，56k
  `c36dd999…998a`，均已逐项复制到 d6/d7 的
  `tmp/n019_d5_snapshots_20261110`。
- 新提交 d6 target-conditioned 选模 Job
  `2119843882860302338`（`n019_selsel54k_20261110_012534`）：
  d6、人工智能/模型训练、1 DCU、15 CPU / 59 GB、1.5 h，
  预计 0.65、最坏 1.5 卡时；提交前 d6 AI 余额
  `24.2005555554`。它首次使用 dev-100
  `target_anonymisation`，而不是 source reconstruction，
  比较 hpclong 6k 与 d5 step 54k，固定 mean32 target
  embedding、duration predictor 和三项评测器。
- 本地测试仍为 `123 passed, 3 skipped`。未使用 d8/d9。

### 2026-11-10 02:00 d5 step 54k 通过 target-conditioned dev gate

- d6 target-conditioned 选模 Job `2119843882860302338`
  已完成。固定同一 dev-100、target map、mean32 target embedding、
duration predictor 和三项 evaluator：

| checkpoint | UTMOS | WhiSQA | WER % |
|---|---:|---:|---:|
| hpclong 6k baseline | 3.049983 | 2.950300 | 20.541958 |
| d5 step 54000 | **3.200829** | **3.169921** | **20.498252** |
| delta | **+0.150846** | **+0.219621** | **-0.043706 pp** |

  step 54k 三项均通过预声明门槛并通过 WER gate，selection
  明确选择 `generator_step00054000`。`selection.json` SHA256
  `59b14277630b76346ce4a87dffc16ecd848a3bbb6fecdbad10a7c58d1bc26b6d`，
  `selection.md` SHA256
  `d47cf0b1c7d89fd31f089dc142d37679d1b6411e2fde7519b257c0a21146abea`。
- 这是本轮最重要的方法性发现：source-reconstruction 选模没有显示
  54k 的优势，而 paper-aligned target-conditioned dev 评测显示双 MOS
  大幅提升。后续 checkpoint 选模必须继续使用
  `N019_SELECTION_MODE=target_anonymisation`，不能回到 source-only。
- 已提交完整 1,934 句复评 Job `2119852455948414978`
  （`n019_d5_54k_mean32_20261110_015939`）：
  d7、人工智能/模型训练、1 DCU、15 CPU / 59 GB、2 h，
  预计 0.9、最坏 2.0 卡时；提交前 d7 AI 余额
  `10.2777777774`。
- 输入固定 d5 step 54k checkpoint
  SHA256 `732ba853041fa981bca7d7e2693fcab759de862227dde01a869316cd6cc9372e`、
  1,934 条 source/unit/target map、mean32 target embedding、
duration/ASR/UTMOS/WhiSQA。输出：
  `anonymised/libri_test/DU-pred-nt-d5-54k-mean32`、
  VPC suffix `_n019_d5_54k_mean32`、
  `eval/du_pred_nt_d5_54k_mean32`。
- 验收必须为匿名化/WAV 1,934、WER 1,496、
  UTMOS/WhiSQA 1,934；完成前不替换当前正式 mean32-6k 结果。

### 2026-11-10 23:06 `DU-pred-nt` I/L EER 闭环与 S 输入准备

- d7 HPC `1086390` 完成 315 个缺失 target speaker 的 mean32 提取：
  8,436 条样本、7m35s、0.1264 卡时，NPZ SHA256
  `ddf7c365f3c34dd7a58c616ab73264504d2e7ae65f03f825182039a423943168`。
  与已有 843 speakers 合并后得到 1,158 keys 的
  `target_speaker_mean32_all1158_shrink01_20261110.npz`，SHA256
  `28ffbaec9516cd8f5abbc752b40315b9fe958f7d37dc6b6f4a58bcd28c2540a7`。
  250-D、finite、unit norm 全部通过；原 843 keys 最大绝对差 `0.0`。
- d6 `1086445` + EVPC-only retry `1086600` 完成当前 soup+shrink0.1
  的 W-NT I/L 和 E-VPC I/L：

| 指标 | 实测 | 论文 | 绝对差 |
|---|---:|---:|---:|
| E-VPC I | 48.0285 | 47.2 | +0.8285 |
| E-VPC L | 47.7540 | 47.9 | -0.1460 |
| W-NT I | 39.1678579152 | 39.9 | -0.7321420848 |
| W-NT L | 39.7293478251 | 42.3 | -2.5706521749 |

- I/L 指标目录：
  `/public/home/a094f4d6/voice_projects/runs/n019_official/privacy/du_pred_nt_soup2_w40_shrink01_20261110_il_r3`。
  `evpc_metrics.json` SHA256
  `09cb95aec4f547b272cba52bc2d4f4555fc89ce1bf6926377b17763e6b52604c`；
  `wnt/summary.json` SHA256
  `4370004b6fefe3b9f9893d885dbc986af9793204709c0813e97d20ecd780637a`。
- EVPC 调试中依次修复：d6 缺 `pyloudnorm`、远端
  `run_evaluation.py` 未启用 dependency bypass、vendor 相对
  `data/` 路径绑定。EVPC-only 正式成功任务墙钟 3m44s。
- 已建立 LS360 四片匿名化输入，片内 source/unit/target 行数分别为
  `26054/25979/26052/25929`。8 句 1-DCU smoke `1086642` 通过，
  8/8 WAV、predicted duration、1,158-key target map 全部正常。
- d6 HPC `1086660`（`n019_ls360_shard0_20261110`）已提交：
  1 DCU、16 CPU / 60 GB、6 h；输入
  `ls360_anonymise_shards_soup2_w40_shrink01_20261110/shard_0`，
  输出 `shard_0/anon`。运行中实测约 18 utt/s，修正预计约 0.4 h、
  最坏 6.0 卡时。已用 `afterok` 链提交 shard 1/2/3：
  `1086675/1086676/1086677`，每个 1 h；禁止重复提交同一 shard。
- 依赖链继续为：LS360 merge `1087345`（1 DCU、8 CPU / 16G、1h）→
  E-VPC S `1087347`（1 DCU、16 CPU / 60G、8h）→
  W-NT S 训练 `1087348`（1 DCU、16 CPU / 60G、12h，最多 10h）
  → W-NT S 评测 `1087349`（1 DCU、1h）。全部使用同一
  `_n019_soup2_w40_shrink01_20261110` WAV/VPC 后缀和 1,158-key
  shrink0.1 target embedding。
- 首轮待执行 S 链 `1086689/1086700/1086702` 在启动前发现
  post-evaluation 数据视图缺少 test suffix 与本地 `train-clean-360`
  的联合入口，已全部取消并以 `1087086/1087087/1087088` 替代；
  这不是训练失败，也没有产生可复用结果。
- merge `1086685` 在启动后 3 秒失败：合并脚本只查找
  `shard_i/anon.jsonl`，实际输出在 `shard_i/anon/anon.jsonl`。
  已修正为同时接受两种布局，并以 `1087345` 重跑；同样在
  `1087345` 启动前取消了依赖它但尚未运行的
  `1087086/1087087/1087088`。

### 2026-11-11 01:02 d6 长训停止与 162k 三项指标复核

- d6 长训 Job `1076707` 保持停止状态，平台记录
  `CANCELLED by 580461`，实际墙钟 `15:31:12`。停机时日志最后
  step `164,280`，持久 `last.pt` 为 step `164,000`，SHA256
  `e7a6ef1003dfc0caebe0f356b751340c93588e1d53867f068ca5f44feb911bb0`。
  当前 d6 上的 `1087347` 是 S 隐私评测，不是长训，未停止。
- 为补全 d6 最后训练效果的 WhiSQA/WER，只对 d6 step 162k
  （三个候选里 UTMOS 最高者）复用已有 100 句匿名 WAV。
  d7 AI Job `2120196966200995842`，1 DCU、15 CPU / 59 GB，
  实际 `00:48:48–01:02:18`，墙钟 `13m30s = 0.225` 卡时；
  提交前 d7 余额 `0.654444444`，没有重新渲染或训练。
- 固定正确 40-speaker dev-100、96-target map、mean32 target
  embedding、预测时长和同一 evaluator，结果：

| checkpoint | UTMOS | WhiSQA | WER % |
|---|---:|---:|---:|
| soup2 baseline | **3.5127723885** | **3.4313990980** | **6.1215166743** |
| d6 step 162k | 3.3362299037 | 3.3230666950 | 6.4869803563 |
| delta | -0.1765424848 | -0.1083324030 | +0.3654636820 pp |

  三项均未通过预声明门槛，d6 最后训练 checkpoint 不应替换当前
  soup2 正式模型。`selection.json` 选择了 baseline；SHA256
  `490fffa17381f55a18c6863cdd5a3c73270343f6500bcc60e45f8feaaa68a778`。
  `selection.md` SHA256
  `74f1971983574f79b352bb1a66dd875bb81654ef28417fb59d324d617760a2b2`。
- 候选 162k SHA256
  `388ac611ad75ab87c7774ab0818a6df6da69bf79b5e605dd4758f98d67407892`；
  UTMOS/WhiSQA/WER JSON SHA256 分别为
  `527ad920747e0c4b82a87cce1d182f0c289eaafbaa9dd962b4cd09e7d039485e`、
  `044a20f86491045830d193192f7fc0bdc842fc5ec41ad4dc87135e915cd78287`、
  `5a3ffad041d580d2a3029377303a30eaacb8b488dafa4385ee4b089cc6b94937`。

### 2026-11-11 02:11 E-VPC S 完成，W-NT S 开始训练

- d6 HPC Job `1087347` 完成，`00:38:19–02:11:49`，墙钟
  `1h33m30s = 1.5583` 卡时。它在匿名化 LS360 上按官方 VPC
  post path 重训 ECAPA 10 epochs，再计算 AA 条件。
- E-VPC S 结果：

| gender | AA EER % |
|---|---:|
| female | 30.114 |
| male | 29.371 |
| mean | **29.7425** |

  论文 E-VPC S 为 `34.8%`，绝对差 `-5.0575` 个百分点；
  当前匿名 WAV 在 S 条件下的隐私弱于论文。不得改写指标或复用旧 S 值。
- `s_metrics.json` SHA256
  `be265b317001fe6c199016224bce5e48ce3cc9ac312e6005e401f02c06f3bb97`，
  官方 `results_anon.txt` SHA256
  `baa06f9f40e75d6b9c20ca8db7ff974fe7a13de1d9512a7118b00f8fb4795858`。
- 依赖链已自动启动 d6 W-NT S 训练 Job `1087348`：
  `02:12:12` 开始在 `f11r1n03` 运行，1 DCU、16 CPU / 60 GB，
  外层 12 h、内部最多 10 h、20 epochs、batch 8、初始模型 W-PRO。
  输出
  `/public/home/a094f4d6/voice_projects/runs/n019_official/privacy/wnt_s_soup2_w40_shrink01`。
  W-NT S 评测 Job `1087349` 仍为 `afterok:1087348`。
- 新增可复现汇总工具 `scripts/merge_wnt_attack_summaries.py` 和
  `scripts/assemble_du_pred_nt_final_remote.sh`；本地相关测试
  `13 passed`，d6/d7 远端均通过 `bash -n` / `py_compile`。
- 02:38 W-NT S 训练健康：`meta.json` 已确认 104,014 utterances、
  921 speakers、W-PRO SHA256
  `ad40a04ae6f0b46dbe6c7a6db71ff46f99775c59a0dccf61eb91f29216fbb2d4`；
  当前 step `6,340`，loss `13.0774`，`last.pt` 持续刷新，无异常。
- 03:03 W-NT S 完成第 1 个 epoch：13,001 steps、epoch loss
  `13.0033`、耗时 `0.8363 h`；已导出完整 `model/`
  （`config.json`、1,266,588,504-byte `model.safetensors`、
  `spk_embeddings.py`、LICENSE）。随后进入 epoch 2，03:09
  step `14,460`、loss `12.8808`，仍无非有限值或运行时错误。
  第 1 epoch 训练 accuracy 记录为 `0.0`，继续观察后续 epoch；
  在 W-NT S EER 出来前不据此下结论。
- `scripts/evaluate_wnt_remote.sh` 已增加模型完整性门禁：I/L/S
  执行前都必须存在 `config.json`、`model.safetensors` 和
  `spk_embeddings.py`。SHA256
  `0259a4c281a75cddaad08cbc99e2dda1b10a1ea9e1f9f69edc627de2e6ee26ee`；
  d6/d7 均通过 `bash -n`。W-NT I/L/S 合并工具也已在 d6
  用真实 I/L summary 验证，输出
  `merge_validation_20261111/wnt_il.json`，SHA256
  `c7f4f66c8c2bdf4f1f09a3921ebc2f4ecb6469aec44161bdb0e2f1170b3ecb76`。
- 已生成当前 8/9 项部分论文对比：
  `privacy/du_pred_nt_soup2_w40_shrink01_partial8_20261111`。
  E-VPC I/L/S、W-NT I/L、WER、UTMOS、WhiSQA 已齐，
  `missing=["W-NT S"]`。`paper_metrics_partial8.json` SHA256
  `9ff01d00fa15679177b2b21fe2c7d33694f184016448e2bd5108559be208fac4`；
  `paper_comparison_partial8.md` SHA256
  `97e542d5d96d2800fd83c437e029e6aacdf131e269311775836aa7728c3f08c5`。

### 2026-11-11 03:34 W-NT S 全量微调表示塌缩，改为冻结 WavLM 的 adapter 微调

- 原 W-NT S Job `1087348` 在 `03:32:56` 主动取消，实际墙钟
  `1h21m07s = 1.3520` 卡时；依赖评测 `1087349` 一并取消。
  这不是盲目停机：epoch 1 训练 accuracy 为 `0.0`，step
  `19,000` 附近仍为 `0.0`，loss 在 `12.90` 平台停滞。
- 对保存的 `last.pt` 做固定 8 句诊断：训练后 W-PRO embedding
  两两余弦最大达到 `0.9999994`，模型输出塌缩，预测集中在
  400/401/714 等少数类别。根因是全 WavLM fine-tune 在
  batch 8、lr `1e-4` 下发生表示塌缩，不是数据标签错位；
  `wav_scp`/`utt2spk` 的 104,014 句、921 speakers 均已核验。
- 新增受控 `--freeze-wavlm` 模式：冻结 315,453,120 个 WavLM
  参数，只训练 1,177,338 个 W-PRO top-layer 参数和 AAM head；
  两个参数组分别支持独立学习率。smoke 使用 global batch 16、
  lr/head-lr `1e-3`。
- d6 HPC smoke `1088364` 完成：6,500 steps、墙钟约 `15m`；
  loss 从 `13.68` 降至 `12.5623`，accuracy 首次变为非零
  `0.000173`，且 8 句 embedding 余弦为
  min/mean/max `-0.50246 / 0.13306 / 0.44311`，没有塌缩。
  `last.pt` SHA256
  `ad76730a3efa9649ba70d7dec9b1aa81c8a05ec1f92e818a92f02473becbb8e5`；
  exported model SHA256
  `0b21af62edcf2a81a54995f5b883ff6093009a3a075a51bb94d384887ea51312`。
- 已提交正式替代训练 Job `1088443`：d6 HPC、1 DCU、
  16 CPU / 60 GB、外层 5 h、内部最多 4.5 h、20 epochs、
  batch 16。预计约 3.6、最坏 5.0 卡时；输出
  `privacy/wnt_s_soup2_w40_shrink01_freeze_r1`。
  `afterok` 评测 Job `1088444` 已提交，使用同一输出目录下的
  `model/` 计算匿名 enrollment + 匿名 trial 的 W-NT S EER。
- 新配置：`configs/scnet_d6_wnt_s_freeze_20261111.json`；
  修订代码 SHA256：`src/n019/wnt_attack.py`
  `37c7074e8d86477113cd13483805fe522bf7c8b566826d0ffc74c02f25f44db6`，
  `scripts/train_wnt_s_remote.sh`
  `3ce0e24002f2a067910502d111f7dcc7eea5399c53dfdb57dec6bf2e3922e2ff`。
- r1 Job `1088443` 在 `f11r1n20` 运行 1m29s 后发生
  `SIGSEGV`；只有 `launch.txt/meta.json`，没有训练 step 或
  checkpoint，属于节点级异常而非 recipe 失败。依赖评测
  `1088444` 随之取消，不重提 r1。
- 已提交 r2 Job `1088459`，排除 `f11r1n20`。规格不变；实际落到
  `f11r2n02`，`03:53:28` 启动。03:58 step `1,300`，
  loss `13.4005`，`last.pt` 正常增长；评测 Job `1088460`
  为 `afterok:1088459`。r2 输出
  `privacy/wnt_s_soup2_w40_shrink01_freeze_r2`。
- 04:09 r2 已完成 epoch 1：6,500 steps、loss `12.5623`、
  accuracy `0.0001731`、epoch 墙钟约 `11m26s`。epoch 2
  到 step `7,500` 时 loss 已降至 `11.4720`，accuracy
  `0.0001875`，说明冻结 WavLM 的 adapter 微调在持续学习，
  没有再出现原全模型微调的塌缩。
- 04:29 r2 epoch 2 完成：loss `11.3665`、accuracy
  `0.00040385`，累计 `0.3798 h`。epoch 3 step `19,060` 时
  loss `10.6833`、accuracy `0.00057756`，学习信号继续增强。
- 已保存 epoch 3 完整模型快照，便于最终模型若发生后期过拟合时回退比较：
  `wnt_s_soup2_w40_shrink01_freeze_r2/snapshots/epoch03_model`。
  `model.safetensors` SHA256
  `d0bb82433b4183e9253acc6399ada2cdb5417c4d4927067e8cc82874871e387a`；
  `config.json` SHA256
  `996cfc1059926c9e3899d9381aba9a8bf9f68fa292ed7317d23c89395c6bad41`。
- 04:42 r2 epoch 4 完成：step `26,000`、loss `10.0655`、
  accuracy `0.00052885`，累计 `0.76365 h`。epoch 5 起步时
  loss 已降至 `9.58–9.60`。已保存 epoch 4 快照
  `snapshots/epoch04_model`，`model.safetensors` SHA256
  `3baa0969b756e9a0e1639114c5dac167b204efba55cc6a17aa547f2a943e90db`。
- 05:03 r2 epoch 5 完成：step `32,500`、loss `9.5107`、
  accuracy `0.00029808`，累计 `0.95722 h`。epoch 6
  step `37,940` 时 loss `9.0616`。已保存 epoch 5 快照
  `snapshots/epoch05_model`，`model.safetensors` SHA256
  `0821d709f62c1fe9f5f5db0a18c465de9bcb791d2ac898f42349af62aacce7e4`。
  训练 accuracy 随 AAM 难度变化有波动，最终以正式 W-NT S EER
  和中间快照比较为准，不能按单一 epoch accuracy 选模。
