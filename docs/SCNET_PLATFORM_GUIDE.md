# SCNet 平台使用指南（HPC 模式 + AI 训练模式）

更新日期：2026-11-09  
适用对象：需要在本机（Windows + PowerShell）远程使用 SCNet 跑训练/评测的 AI 或人  
作者注：本文所有命令都在本项目 `语音识别_N019_official` 下实测通过，
路径与限制均来自 2026-11-09 的真实运行结果。

---

## 1. 平台概览

SCNet（国家超算互联网）提供两种互相独立的算力交付方式：

| 模式 | 入口 | 调度方式 | 单任务时长 | 计费 |
|---|---|---|---|---|
| HPC 高性能计算 | SSH 登录节点 + Slurm | `sbatch` / `squeue` | 最长 **3 天** | 每账号 50 h 免费额度，按 DCU 占用计 |
| AI 模型训练 | 网页控制台（可脚本化） | 平台表单任务 | 常见 1–2 h 墙钟 | 按卡时余额扣费（`卡*时`） |

两种模式的**文件系统是同一套**：`/public/home/<账号>/`。
但不同账号的目录默认**互不可读**（`Permission denied`），跨账号数据要走本机中转或重新下载。

当前使用的账号（5 个）：

```
a094f4d3  a094f4d4  a094f4d5  a094f4d6  a094f4d7
```

其中 d6 存有完整的 LibriTTS 训练数据，d7 存有 VPC 评测资产与选模 dev 集。

---

## 2. SSH 连接

登录节点：`zzeshell.scnet.cn:65032`（每个账号一个独立用户名）。
本机 `~/.ssh/config` 已配置好别名，直接 `ssh <别名>` 即可：

| 别名 | 账号 |
|---|---|
| `scnet` | lwjnjy |
| `scnet-new` | lwjnjy1 |
| `scnet-a094f4d3` … `scnet-a094f4d7` | 对应 a094f4d3 … a094f4d7 |

验证：

```powershell
ssh -o BatchMode=yes scnet-a094f4d6 "hostname; id -un; echo \$HOME"
```

私钥位于 `~/.ssh/scnet_a094f4d6_rsa` 等文件，有效期见 `~/.ssh/config` 注释。

> 注意：项目里的很多命令参数带引号，在 **PowerShell** 下执行时请用双引号包住
> 远程命令，并避免在命令里混用未转义的 `$`。批量脚本建议直接用仓库里的
> `.sh` 文件，减少引号问题。

---

## 3. 两种模式怎么选

- **要跑 2 小时以上、或者需要连续几十小时**：选 HPC 模式。单 Job 可以跑 3 天，
  不用反复切段，checkpoint 也不会因为外层墙钟被截断。
- **要短平快（<2 h）、或者需要平台镜像/计费余额**：选 AI 训练模式。
  它的网页表单会自动带好 PyTorch 2.9 + DTK 26.04 镜像。
- **两者可以同时用**（不同账号），但同一账号在 HPC 侧同一时刻只能占 1 张 DCU。

---

## 4. HPC 高性能计算模式

### 4.1 分区与硬件

```bash
sinfo -s
# PARTITION   AVAIL  TIMELIMIT   NODES(A/I/O/T)
# hx1hdnormal    up  3-00:00:00   44/9/5/58
```

每个节点：8 张 Hygon DCU、128 CPU、510 GB 内存。

### 4.2 账号限制（实测）

```
sbatch: error: tres(gres/dcu) request 2 exceeds group max tres limit 1
```

即**每账号同一时刻只能占 1 张 DCU**。所以 50 h 免费额度实质是
**1 DCU × 50 h**；好处是单 Job 墙钟上限高达 3 天。

查询额度使用情况：

```bash
sshare -U -u a094f4d6
sacct -u a094f4d6 -S 2026-11-09 --format=JobID,JobName%25,Elapsed,AllocTRES%35,State
```

### 4.3 目录约定

```text
/public/home/<账号>/voice_projects/
├── code/n019_official/            # 项目代码（含 hpc/、scripts/、src/）
├── data/n019_official/            # 数据（corpora / processed / vpc）
├── models/n019_official/          # 预训练模型（HuBERT、UTMOS、WhiSQA、ASR）
├── runs/n019_official/            # 训练与评测输出
├── logs/n019_official/            # Slurm stdout/stderr
├── envs/n019/                     # Python 环境
└── tmp/                           # 中转文件
```

### 4.4 环境激活

所有 HPC 作业第一步都应执行：

```bash
export N019_OFFICIAL_ROOT="$HOME/voice_projects/code/n019_official"
source "$N019_OFFICIAL_ROOT/hpc/activate_n019_official.sh"
```

它会设置 DTK 26.04 的 `PATH/LD_LIBRARY_PATH`、Python 环境
`envs/n019`、`HF_HOME`（离线缓存）以及
`N019_OFFICIAL_DATA / MODELS / LOGS / RUNS` 等变量。

### 4.5 最小可用 sbatch 模板

保存为 `my_job.slurm`：

```bash
#!/bin/bash
#SBATCH --job-name=my_job
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=04:00:00
#SBATCH --exclude=f11r1n17
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail
export N019_OFFICIAL_ROOT="$HOME/voice_projects/code/n019_official"
source "$N019_OFFICIAL_ROOT/hpc/activate_n019_official.sh"
cd "$N019_OFFICIAL_ROOT"

echo "job=${SLURM_JOB_ID} host=$(hostname) date=$(date -Is)"
python -u my_script.py --out "$N019_OFFICIAL_RUNS/my_run"
```

提交与查看：

```bash
sbatch my_job.slurm          # 返回 Submitted batch job 1069636
squeue -u $USER              # R=运行中, PD=排队
scontrol show job 1069636    # 详细状态
tail -f ~/voice_projects/logs/n019_official/my_job_1069636.out
scancel 1069636              # 取消
```

### 4.6 HPC 注意事项

- 两台以上 DCU 会被拒绝（`AssocGrpGRES`），不要写 `--gres=dcu:2`。
- 同时提交两个任务时，第二个通常是 `PD (AssocGrpCpuLimit)`，
  等第一个结束才会启动——这是账号级 CPU 限额，不是故障。
- `--exclude=f11r1n17` 是历史避让节点，建议保留。
- 输出目录权限：HPC 作业以本人身份运行，不会出现 AI 训练那种 root 属主问题。
- 单 Job 建议把内部训练预算（如 `MAX_HOURS`）设得比 `--time` 少 0.5 h，
  留出收尾写 checkpoint 的时间。

---

## 5. AI 模型训练模式（网页控制台）

### 5.1 入口

`https://www.scnet.cn/ui/console/index.html#/model-training`

手工操作：创建任务 → 填启动脚本 → 选镜像 `PyTorch 2.9.0 / py3.11-Ubuntu22.04 /
dtk26.04` → 选资源 `异构加速卡BW * 1卡`（15 CPU / 59 GB per card）→ 提交。

### 5.2 脚本化提交（推荐）

仓库内已封装 Playwright 自动提交脚本：

```text
scripts/scnet_browser_tasks.py
configs/scnet_browser_tasks.json
```

常用命令：

```powershell
# 只看渲染出来的计划，不开浏览器
python scripts\scnet_browser_tasks.py --check-config --task <task_id> --no-prompt

# 读所有账号余额（headless，不开可见窗口）
python scripts\scnet_browser_tasks.py --inspect-accounts --headless --no-prompt

# 按名称只读查看某个任务详情
python scripts\scnet_browser_tasks.py --inspect-job <显示名> --account a094f4d6 --headless --no-prompt

# 真正提交
python scripts\scnet_browser_tasks.py --task <task_id> --submit --headless --no-prompt
```

### 5.3 配置文件结构

`configs/scnet_browser_tasks.json` 顶层：

```json
{
  "browser":   { "channel": "msedge", "headless": false, "timeout_ms": 180000, "...": "..." },
  "output_root": "runs/scnet_browser_submissions",
  "dry_run": true,
  "max_tasks_per_run": 4,
  "inspection": { "accounts": ["a094f4d3", "..."], "balance_regex": "..." },
  "defaults":  { "region": "华中一区【A区】", "accelerator": "异构加速卡BW",
                 "cards": 1, "cpu_per_card": 15, "memory_gb_per_card": 59,
                 "image": { "framework": "PyTorch", "version": "2.9.0",
                            "python": "py3.11-Ubuntu22.04", "dtk": "dtk26.04" } },
  "tasks": [ { "id": "...", "submit": false, "name": "...", "account": "...",
               "startup_script": "...", "...": "..." } ]
}
```

单个 task 的关键字段：

| 字段 | 含义 |
|---|---|
| `id` | 任务模板唯一标识（提交时用 `--task <id>`） |
| `name` | 平台显示名，支持 `{timestamp}` 占位符 |
| `account` | 用哪个账号提交 |
| `cards` / `wall_hours` | 卡数、墙钟 |
| `expected_card_hours` / `worst_card_hours` | 预计/最坏卡时，用于预算核查 |
| `input_paths` / `output_paths` | 输入输出清单（`--check-config` 会展示） |
| `stop_conditions` | 停止条件（写给自己和审阅者看） |
| `submit` | **必须默认 `false`**，真正提交前才临时改 `true` |
| `submitted_task_id` | 提交成功后回写的平台 JobID，用于防重复提交 |
| `startup_script` | 容器里执行的命令，必须以 `bash `/`python `/`torchrun `/`timeout ` 开头 |

### 5.4 安全提交三步法（重要）

平台任务一旦重复提交会白烧卡时，本项目强制以下流程：

```powershell
# 1) 打开提交开关（临时）
python scripts\scnet_task_submit_toggle.py <task_id> true submitting_<时间戳>

# 2) 提交（会写 results.json，内含真实 JobID）
python scripts\scnet_browser_tasks.py --task <task_id> --submit --headless --no-prompt

# 3) 回写 JobID 并立刻关闭开关
python scripts\scnet_task_record_submission.py <task_id> <JobID> <平台显示名>
python scripts\scnet_task_submit_toggle.py <task_id> false submitted_<时间戳>
```

提交结果落盘在：

```text
runs/scnet_browser_submissions/<YYYYMMDD_HHMMSS>/results.json
runs/scnet_browser_submissions/<YYYYMMDD_HHMMSS>/<task_id>_submitted.png
```

### 5.5 AI 训练注意事项

- 容器内进程通常是 **root**，输出文件会变成 root 属主；脚本末尾应 `chown` 回账号属主，
  否则后续 scp / 读取会失败。
- 外层 `timeout` 与训练内部预算要留余量：外层 2 h、内部建议 ≤1.5 h。
- 平台节点存在已知坏卡（如 `10.6.15.32`），本项目所有 DCU 任务都先跑
  `scripts/gpu_tiny_matmul_watchdog.sh`（300 s SIGKILL 看门狗）再开始正式计算。
- `torch.cuda.is_available()` 在部分 DTK 节点会阻塞 1–3 分钟属正常现象，
  不要用 2–3 分钟级别的超时判定模型失败。

---

## 6. 本项目已写好的脚本清单

### 6.1 平台交互

| 路径 | 用途 |
|---|---|
| `scripts/scnet_browser_tasks.py` | AI 训练模式的浏览自动化：检查配置、读余额、查任务、提交 |
| `configs/scnet_browser_tasks.json` | 所有 AI 训练任务模板 + 浏览器/账号/余额配置 |
| `scripts/scnet_task_submit_toggle.py` | 切换某任务的 `submit` 开关并写 `status` |
| `scripts/scnet_task_record_submission.py` | 提交后回写 `submitted_task_id` 并关闭开关 |

### 6.2 HPC（Slurm）

| 路径 | 用途 |
|---|---|
| `hpc/activate_n019_official.sh` | HPC 环境激活（DTK 26.04 + Python 环境 + 项目变量） |
| `hpc/n019_vocoder_hpc_pilot.slurm` | 1 DCU / 20 min 冒烟模板（带 init-generator） |
| `hpc/n019_vocoder_hpc_long.slurm` | 1 DCU / 16 h 长训模板（inner 15.5 h） |
| `hpc/n019_vocoder_main.slurm` | 1 DCU / 4 h 主训练模板 |
| `hpc/n019_vocoder_ddp_pilot.slurm` | 双 DCU DDP 冒烟模板（当前账号会被配额拒绝，留作他账号参考） |
| `hpc/n019_eval_assets.slurm` | 评测资产生成模板 |
| `hpc/n019_duration_*.slurm` | duration predictor 训练模板 |
| `hpc/n019_unit_pipeline.slurm` | HuBERT unit 提取流水线模板 |

### 6.3 训练/评测执行脚本（两种模式通用）

| 路径 | 用途 |
|---|---|
| `scripts/gpu_tiny_matmul_watchdog.sh` | 300 s DCU 看门狗（建议所有卡任务第一步执行） |
| `scripts/preflight_dcu_remote.sh` | DCU/GroupNorm/mel/HuBERT 预检 |
| `scripts/run_vocoder_ddp.sh` | vocoder 训练主入口（读 `N019_VOCODER_*` 环境变量） |
| `scripts/launch_vocoder_nt_2x_lr2e4_ai.sh` | 从零/指定 init 的新训练（2x FM、lr 2e-4、无裁剪） |
| `scripts/launch_vocoder_nt_2x_lr2e4_continue_ai.sh` | 从 `last.pt` 分段续训 |
| `scripts/run_vocoder_snapshot_selection_ai.sh` | 固定 dev-100 上的 checkpoint 选模（UTMOS/WhiSQA/WER） |
| `scripts/run_full_eval_param_ai.sh` | 参数化完整 1,934 句复评（匿名化 → VPC → WER/MOS → 对比论文） |
| `scripts/average_generator_snapshots.py` | 多 snapshot 权重平均（SWA） |
| `scripts/verify_training_data_marker.py` | 用 marker 快速校验训练数据（跳过全量路径扫描） |

### 6.4 典型用法

**HPC 冒烟（1 DCU / 20 min）**

```bash
scp hpc/n019_vocoder_hpc_pilot.slurm scnet-a094f4d6:~/voice_projects/code/n019_official/hpc/
ssh scnet-a094f4d6 "sbatch ~/voice_projects/code/n019_official/hpc/n019_vocoder_hpc_pilot.slurm"
ssh scnet-a094f4d6 "squeue -u a094f4d6"
```

**HPC 长训（1 DCU / 16 h）**

```bash
scp hpc/n019_vocoder_hpc_long.slurm scnet-a094f4d6:~/voice_projects/code/n019_official/hpc/
ssh scnet-a094f4d6 "sbatch ~/voice_projects/code/n019_official/hpc/n019_vocoder_hpc_long.slurm"
```

**AI 训练（网页表单）**

```powershell
python scripts\scnet_task_submit_toggle.py d6-vocoder-ft2x14k-lr2e4 true submitting_20261109_0616
python scripts\scnet_browser_tasks.py --task d6-vocoder-ft2x14k-lr2e4 --submit --headless --no-prompt
python scripts\scnet_task_record_submission.py d6-vocoder-ft2x14k-lr2e4 2119554846081961986 n019_voc2xft14k_20261109_061704
```

---

## 7. 给“另一个项目/AI”的最小复用模板

### 7.1 新项目 HPC 作业

1. 把代码放到 `/public/home/<账号>/<project>/`
2. 参考 `hpc/n019_vocoder_hpc_pilot.slurm`，只改：
   - `--job-name`
   - `--time`（≤ 72:00:00）
   - `--cpus-per-task`（建议 16）
   - `--mem`（建议 60G）
   - 最后一行执行命令与输出目录
3. `sbatch` 提交，`squeue`/`sacct` 跟踪，日志在 `--output` 指定位置。

### 7.2 新项目 AI 训练任务

在 `configs/scnet_browser_tasks.json` 的 `tasks` 数组里追加：

```json
{
  "id": "my-task",
  "enabled": true,
  "status": "prepared",
  "submit": false,
  "name": "myjob_{timestamp}",
  "account": "a094f4d6",
  "cards": 1,
  "wall_hours": 2.0,
  "expected_card_hours": 1.5,
  "worst_card_hours": 2.0,
  "input_paths": ["/public/home/a094f4d6/myproject/data"],
  "output_paths": ["/public/home/a094f4d6/myproject/runs/{timestamp}"],
  "stop_conditions": ["达到墙钟", "loss 非有限", "10 分钟无日志"],
  "startup_script": "timeout --signal=KILL 6900 bash -x /public/home/a094f4d6/myproject/run.sh > /public/home/a094f4d6/myproject/logs/{timestamp}.log 2>&1"
}
```

然后按 5.4 的三步法提交。

---

## 8. 常见问题与排查

| 现象 | 原因 | 处理 |
|---|---|---|
| `sbatch: tres(gres/dcu) request 2 exceeds ... limit 1` | 账号级 DCU 限额 | 改回 `--gres=dcu:1`，或换账号 |
| 第二个 Job 一直 `PD (AssocGrpCpuLimit)` | 上一个 Job 还占着 CPU | 等前一个结束，或 `scancel` 后重提 |
| AI 任务 `排队中` 很久 | 平台资源紧张 | 正常等待，不要重复提交 |
| `permission denied` 读别的账号目录 | 家目录默认互不可读 | 走本机中转 / 各自下载 |
| 训练无日志、无 step | `torch.cuda.is_available()` 卡住（DTK 已知） | 给 20–25 分钟启动窗口，用 `N019_STAGE_TRACE=1` + faulthandler 看栈 |
| 任务被 SIGKILL 且没有 final checkpoint | 外层墙钟早于内部预算 | 内部 `MAX_HOURS` 至少比外层少 0.5 h |
| 输出文件 root 属主 | AI 训练容器以 root 运行 | 脚本末尾 `chown` 回账号属主 |
| `.nfs0000... Device or resource busy` | NFS 临时目录清理报错 | 不影响已写出的 checkpoint，可忽略 |
| 余额查询失败 | 浏览器登录态过期 | 用 `--headed` 手工登录一次，或设置 `SCNET_PASSWORD_<账号>` |

---

## 9. 提交前检查清单

无论哪种模式，提交前逐项确认：

1. 账号、模式、任务名、分区/资源组
2. DCU 数、CPU、内存、墙钟、预计/最坏卡时
3. 输入路径存在且行数/哈希符合预期
4. 输出路径不与已有任务冲突
5. 停止条件写清楚（墙钟、非有限 loss、无日志、坏卡）
6. 不会与同一账号正在运行的任务冲突
7. AI 模式：`submit` 是否仍为 `false`、`submitted_task_id` 是否为空
8. HPC 模式：`--time` 与内部 `MAX_HOURS` 是否留出余量

---

## 10. 附：本项目当前实例（可作为参考）

- HPC 长训：Slurm Job `1069636`，`hx1hdnormal`，1 DCU / 16 CPU / 60 G，
  16 h 墙钟，inner 15.5 h，输出
  `runs/n019_official/vocoder_nt_hpc_ft14k_long_20261109`
- AI 训练余额（2026-11-09 下午）：d6 ≈ 26.7、d7 ≈ 16.9 卡时；
  d3 1.38、d4 0.54、d5 4.22 卡时
- HPC 免费额度：每账号 50 h，d6 已用约 1.3 h

以上数字会随时间变化，使用前请用第 5.2 节的余额命令重新核对。
