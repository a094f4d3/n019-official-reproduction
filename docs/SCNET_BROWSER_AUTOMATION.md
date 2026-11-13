# SCNet 训练任务浏览器自动化

## 0. 2026-11-05 操作约束

日常监控、日志查看、文件核验和远端命令一律使用直连 SSH，不要为这些
操作启动 Edge/Playwright 或“召唤”任务页面。d7 已实测可通过
`a094f4d7@zzeshell.scnet.cn:65032` 和
`~/.ssh/scnet_a094f4d7_rsa` 登录。E-Shell 不支持可靠的非交互式
`ssh host "command"`：会话会建立但 exec 请求可能一直不返回；应使用
交互式 SSH（Windows 下可用 WSL `ssh -tt`），在同一个持久 shell 中
执行检查命令。浏览器脚本只保留给平台侧任务创建，且必须显式确认后
才可运行；禁止用浏览器页面代替 SSH 监控。

`scripts/scnet_browser_tasks.py` 使用 Playwright 操作 Edge：登录账号、填写
创建任务页面、校验最终表单并创建人工智能/模型训练任务。它不接管现有
Edge 标签页，而是为每个账号使用独立持久化目录，避免账号会话互相覆盖。

账号、页面文字、下拉选择、资源规格、任务参数和启动命令全部在
`configs/scnet_browser_tasks.json`。换账号或换任务时只改 JSON，不改
Python 脚本。只有 SCNet 页面结构本身变化时才需要更新 `browser.ui` 中的
选择器。

## 1. 安装依赖

```powershell
python -m pip install -e ".[automation]"
```

脚本使用系统已安装的 Edge，不需要额外下载 Chromium。

## 2. 配置

所有页面选择和训练参数都在
`configs/scnet_browser_tasks.json`。常用字段：

```text
browser.channel                 浏览器 channel，默认 msedge
browser.headless                是否无界面运行
browser.profile_root            每个账号的持久化登录目录
browser.viewport                浏览器窗口宽高
defaults.region                 区域
defaults.accelerator            加速卡型号
defaults.resource_group         资源组
defaults.cards                  每实例卡数
defaults.instances              实例数
defaults.auto_fault             自动容错
defaults.auto_fault_retry_limit 自动容错开启时的最大重启次数
defaults.cpu_per_card           平台资源行必须满足的每卡 CPU 数
defaults.memory_gb_per_card     平台资源行必须满足的每卡内存
defaults.expected_resource_text 提交前必须匹配的资源行文字
defaults.image.framework        PyTorch
defaults.image.version          2.9.0
defaults.image.python           py3.11-Ubuntu22.04
defaults.image.dtk              dtk26.04
defaults.wall_hours             墙钟上限，用于计划记录
defaults.expected_card_hours    预计卡时，用于计划记录
tasks[].name                    任务名，可含 {timestamp}
tasks[].account                 账号
tasks[].startup_script          启动脚本，可含 {account}
tasks[].submit                  是否允许该任务提交
tasks[].status                  台账状态，仅用于计划和审计
tasks[].submitted_task_id       已提交任务的现有 ID，防止误重复提交
browser.ui.*                    登录和创建页的页面文字/CSS/XPath 选择器
```

配置中的任务参数会覆盖 `defaults`。脚本会拒绝名称长度超过 40 个字符、
非 Bash 启动命令、重复渲染名称、无效卡数和墙钟，以及任何包含 password
字样的配置字段。平台不能单独选择 CPU/RAM；脚本会按 `cpu_per_card`、
`memory_gb_per_card` 和 `expected_resource_text` 校验资源行实际显示的
“15 CPU / 59 GB / DTK 26.04”等分配。

## 3. 密码

密码只从环境变量或交互式 `getpass` 读取，不写入配置、结果 JSON、表单
快照或日志。
未设置环境变量时，脚本会在终端提示输入，输入内容不会回显。
无人值守运行可由现有密钥管理工具在子进程环境中临时提供
`SCNET_PASSWORD_A094F4D4` 等账号专用变量，或共享的
`SCNET_PASSWORD`。不要把密码写入 PowerShell 历史、仓库或聊天记录。

环境变量名前缀本身也可在 `browser.password_env_prefix` 和
`browser.shared_password_env` 中修改。

SCNet 使用浏览器会话 cookie。仅依赖 Edge persistent profile 时，关闭
浏览器后 `Token`/`jsessionid` 等 session cookie 和 `sessionStorage`
可能丢失。脚本因此会在登录成功后额外保存：

```text
~/.scnet-browser-profiles/<account>/n019_browser_state.json
```

该文件包含 cookies、localStorage 和 sessionStorage，不含账号密码；下次
启动同一账号时自动恢复。文件只保存在本机用户目录，不应复制到仓库或
上传。对应配置是 `browser.persist_session_state` 和
`browser.session_state_filename`。

## 4. 干跑

默认 `dry_run=true`。下面命令会登录并把所有表单填好，逐项校验名称、
区域、资源行、卡数、实例数、自动容错、镜像和启动脚本，然后保存表单
快照与截图，但不会点击最终的“创建”：

```powershell
python scripts/scnet_browser_tasks.py --config configs/scnet_browser_tasks.json
```

无人值守环境可加 `--no-prompt`，此时缺少密码环境变量会立即失败而不是
等待终端输入。

只验证配置、不打开浏览器：

```powershell
python scripts/scnet_browser_tasks.py --check-config
```

列出所有配置任务（包括 `enabled:false`）的账号、提交开关和已有任务 ID，
同样不打开浏览器：

```powershell
python scripts/scnet_browser_tasks.py --list-tasks
```

只读检查已加入 `inspection.accounts` 的账号实时机时余量，不创建任务：

```powershell
python scripts/scnet_browser_tasks.py --inspect-accounts
```

账号列表和余额正则位于 `inspection.accounts` 与
`inspection.balance_regex`；结果保存为
`runs/scnet_browser_submissions/<timestamp>/inspection_results.json`。

只读查看某个已创建任务的详情页：

```powershell
python scripts/scnet_browser_tasks.py `
  --account a094f4d5 `
  --inspect-job n019_ls360_units_20261103_134715
```

该命令不会创建或停止任务，只保存 `*_details.png` 和
`*_details.json`。

列出该账号任务列表中的全部可见行：

```powershell
python scripts/scnet_browser_tasks.py `
  --account a094f4d4 `
  --list-jobs
```

结果保存为 `runs/scnet_browser_submissions/<timestamp>/<account>_jobs.json`，
同时保存整页截图。不要对同一账号并行启动两个脚本实例；Playwright 的
持久化 Edge profile 同一时间只能由一个进程占用。

只跑一个任务：

```powershell
python scripts/scnet_browser_tasks.py `
  --task d4-target-embedding-shard0 `
  --dry-run
```

## 5. 正式提交

先确认 `tasks[].startup_script`、任务名、卡数和墙钟计划，然后：

```powershell
python scripts/scnet_browser_tasks.py --submit
```

`--submit` 会覆盖顶层 `dry_run`，但仍遵守每个任务的 `submit: false`。
`--submit` 与 `--dry-run` 互斥；显式 `--dry-run` 会覆盖配置中的
`dry_run:false`，用于临时阻止点击“创建”。
若任务已经记录了 `submitted_task_id` 且 `submit:true`，脚本会在打开
浏览器前拒绝提交，避免重复建任务；只有确认旧任务结束并需要有意重跑时
才使用 `--force-resubmit`。`submit:false` 的台账记录任务不受该检查影响。
每个任务的计划在提交前写入
`runs/scnet_browser_submissions/<timestamp>/<task>_plan.json`；提交后保存
填表截图、表单快照、详情页截图和 `results.json`。

当前配置中，d4 的 shard 0/1 已有运行中的任务，因此
`tasks[].submit=false` 并记录了现有 job ID。即使误加 `--submit`，脚本也
只完成表单校验，不会重复创建。d3 的 shard 2/3 同样暂设
`submit=false`，必须在 other-500 解压验收后再显式改为 `true`。

## 6. 已验证状态

2026-11-03 通过脚本本身完成了一次真实登录和 d4 shard 0 干跑：

- 登录复用 `~/.scnet-browser-profiles/a094f4d4`；
- 资源行为 `113 组 / 异构加速卡BW / 64GB / 8 卡每节点 /
  15 CPU / 59GB / DTK 26.04`；
- 表单为 1 DCU、1 实例、自动容错关闭、
  `PyTorch / 2.9.0 / py3.11-Ubuntu22.04 / dtk26.04`；
- 启动脚本逐字写回并校验；
- 未点击“创建”，卡时为 0；
- `实例数=2` 的加号控件路径另行干跑通过。

2026-11-03 15:51 再次用脚本本身对 d4 shard 0 完成干跑，未点击创建，
表单和截图写入 `runs/scnet_browser_submissions/20261103_155129/`。
浏览器单项测试为 10 passed。

2026-11-03 16:15 三个旧账号均通过脚本登录并保存会话状态；随后在不提供
密码环境变量、使用 `--no-prompt` 的情况下再次读取三账号余额成功，
证明持久化恢复生效。实时余额分别为 d3 `48.3622222221`、d4
`39.3025`、d5 `23.0208333333` 卡时。

`a094f4d6` 与 `a094f4d7` 已加入配置白名单，并已完成持久化登录。
两者可在 E-Shell 的“SSH连接”对话框中下载各自 30 天 RSA key；key
已安装为 `~/.ssh/scnet_a094f4d6_rsa` 和
`~/.ssh/scnet_a094f4d7_rsa`，SSH 登录已实测。短信验证只影响
“个人中心 → 访问控制”的长期访问秘钥，不影响 E-Shell 临时 SSH key。
后续 provisioning 完成前，两账号仍禁止提交卡时任务。

2026-11-03 22:00 后，脚本已实际提交 `chown`、DDP pilot 和
分发任务；每次创建后的任务 ID、状态与截图保存在
`runs/scnet_browser_submissions/<timestamp>/results.json`。

大文件迁移优先使用 SCNet 文件管理页，而不是直接 `scp` 整个文件：

- 文件管理会把上传中的目标写成 `.efilePart`，上传列表显示“完成”
  不代表 `.efilePart` 已原子改名；必须等 SSH 侧看到最终文件名并
  复算 SHA256；
- 实测 SSH `scp -O` 对 1.3 GB 文件会间歇 `Broken pipe`，32 MiB
  分片或浏览器上传更稳定；
- AI 容器内 `id -un=root` 也只能看到本账号挂载，不能借容器 root
  给其他 SCNet 家目录复制文件。

## 7. 失败处理

- 若出现图形验证码，脚本不会解题；`--headless` 下直接失败，
  `--headed` 下等待人工完成登录。
- 页面结构变化时，脚本会保存 `*_failed.png`。优先更新配置或脚本中的
  UI 文本，不要改用坐标点击。
- 同一账号复用持久化目录和 `n019_browser_state.json`，正常登录后后续
  运行不需要再次输入密码。
- 若持久化会话过期，脚本会明确报 `LoginRequired`；在本地终端交互运行一次，
  通过 `getpass` 输入密码即可刷新该账号会话，不要把密码写入配置或命令参数。
