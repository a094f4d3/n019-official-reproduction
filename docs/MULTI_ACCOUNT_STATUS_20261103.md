# N019 Multi-Account Status

更新时间：2026-11-04（Asia/Shanghai）

## 0. 2026-11-04 22:15 修正版短期状态

- 2026-11-06 11:17：d7 checkpoint 诊断已完成。同一批 25 句，
  paperfix step 4k 的 UTMOS/WhiSQA 为 `1.248995/1.848322`；
  main step 76k 为 `2.544487/2.643822`。后者明显更好，说明
  训练步数/选模是重要原因，但仍未达到论文值；需要继续优化
  paperfix 训练，而不是更换指标。`summary.json` SHA256
  `22eef2b6f2eea401356fc28efe090435609071d03199fcc5ba1fc0ccb2441aab`。
- 2026-11-06 11:34：step `33,999` 的 paperfix generator-only
  checkpoint 已从 d3 经本机中转 d7，SHA256
  `50ce0ecb2e26a20698002a7483be171aefa42997e4318eda6b35f6086d2d4005`。
  d7 登录节点正在以 CPU 对同一 25 句跑 UTMOS/WhiSQA，不占卡时。
- 2026-11-06 11:48：step `33,999` 诊断完成：UTMOS
  `2.2371`、WhiSQA `2.4190`。相比 step 4k 明显提升，
  但仍低于 main step 76k，说明延长训练有效但尚非全部差距来源。
- 2026-11-06 11:46：d3 已提交 paperfix 受控续训 Job
  `2118550713240682497`，2 DCU、外层 8 h、内部 7.5 h，
  预计 15.0、最坏 16.0 卡时；提交前余额 `17.268611111`。
  输出独立 `vocoder_nt_paperfix_ext`，不覆盖原 checkpoint。

- 2026-11-06 10:57：d7 实时余额 `41.0380555553` 卡时。已提交
  25 句 checkpoint 质量诊断 Job `2118538301277642754`：
  paperfix step 4k 与 main step 76k 各生成同一批音频并跑
  UTMOS/WhiSQA；1 DCU、1 h、最坏 1.0 卡时。当前排队中。

- 2026-11-06 10:21：d7 WhiSQA-only Job
  `2118528804410613762` 已完成。1,934 句 mean
  `1.847028814125209`（论文 `3.69`），WhiSQA 与 UTMOS
  均显著低于论文。三对原始/匿名 WAV 的只读抽查显示匿名输出
  谐波结构明显劣化并出现宽带噪声，当前优先诊断
  `vocoder_nt_paperfix` 的 checkpoint 选模，不重跑已完成指标。

- 2026-11-05 21:31：d7 UTMOS bootstrap Job
  `2118333381196488706` 已失败（`21:25:37`，约 0.034 卡时）。
  失败点是 PyPI `fairseq==0.12.2` sdist 缺
  `clib/libbase/balanced_assignment.cpp`，不是模型/指标错误；
  正式 torch/numpy 未改。改为从已有可工作的 py311 fairseq
  安装目录做隔离迁移。
- 2026-11-05 21:24：d7 已提交隔离 UTMOS runtime
  bootstrap + 单句 probe，Job `2118333381196488706`，1 DCU、
  15 CPU / 59 GB、1 h、预计 0.25、最坏 1.0 卡时。代码和
  resume 脚本已通过文件管理上传，远端/本地 SHA256 一致。任务
  “运行中”；提交前 d7 余额 `42.2872222221` 卡时。完整
  UTMOS/WhiSQA 要等 probe 成功后再提交。
- 2026-11-05 19:50：MOS-only Job `2118298417542995969` 已失败，
  实例 `19:04:39–19:09:05`。UTMOS 因缺 `hydra` 在模型加载阶段
  退出；之前的 E-VPC I/L/WER 与 W-NT I/L 保持不变，UTMOS/WhiSQA
  仍未产出。d7 实时余额 `42.2872222221` 卡时，其余账号为 d3
  `17.268611111`、d4 `8.3249999999`、d5 `4.216111111`、d6
  `37.536111111` 卡时。继续准备隔离依赖和单句 probe，暂不重提
  完整 MOS。
- 2026-11-05 19:04：原评测 Job `2118255578293129217` 在 E-VPC 与
  W-NT 完成后，因 d7 缺 `vendor/UTMOS22-demo/score.py` 于 18:39:42
  失败。W-NT L female/male/mean 为
  `42.1511%/43.5985%/42.8748%`（论文 `42.3%`）。UTMOS22 demo 已
  补齐并哈希核验；仅 MOS 的续跑 Job `2118298417542995969` 已启动并通过
  E-VPC/W-NT/MOS 输入门禁，开始 UTMOS；
  d7、1 DCU、1.5 h、最坏 1.5 卡时，提交余额 `43.0227777777`。
- 2026-11-05 17:37：d7 `DU-pred-nt-paperfix` 评测 Job
  `2118255578293129217` 仍在运行。W-NT I 已完成：female
  `39.9398%`、male `42.3171%`、mean `41.1284%`（论文 `39.9%`）；
  身份隐私高于论文，不是 WER 偏差的来源。W-NT L 正在运行，
  UTMOS/WhiSQA 尚未产出。实时余额 d3 `17.268611111`、d4
  `8.3249999999`、d5 `4.216111111`、d6 `37.536111111`、d7
  `44.0227777777` 卡时。
- 2026-11-05 16:33：主评测 Job `2118255578293129217` 运行中。
  E-VPC I `47.473%`（论文 `47.2%`）通过 0.5 容差；
  L `45.8775%`（论文 `47.9%`）和 WER `10.333%`（论文 `7.41%`）
  超容差，不能判为复现通过。NT vocoder 的正式 best 仅为 step 4k，
  训练在 step 34k 被 patience 停止；等 W-NT/MOS 完成后处理续训与
  重新选模。d7 官方环境 `107 tests OK`，本地 `111 OK + 3 skipped`。
- 2026-11-05 16:14：实时余额 d3 `17.268611111`、d4
  `8.3249999999`、d5 `4.216111111`、d6 `37.536111111`、d7
  `44.8574999999` 卡时。d7 基线 Job `2118253551901843458`
  已验收：female/male EER `8.761%/0.418%`、mean `4.5895%`，
  WER `1.8435020832144284%`。正式 `DU-pred-nt-paperfix`
  I/L/WER/MOS 评测 Job `2118255578293129217` 已启动运行，
  1 DCU、15 CPU / 59 GB、4 h、预计 2.0、最坏 4.0 卡时。
- 2026-11-05 15:20：实时余额 d3 `17.268611111`、d4
  `8.3249999999`、d5 `4.216111111`、d6 `37.536111111`、d7
  `45.3341666667` 卡时。d7 准备以 1 DCU、1 h、最坏 1.0 卡时提交
  1,934 句 `DU-pred-nt-paperfix` 匿名化；所有输入已通过 SHA256
  中转并在 d7 验证 1,934/1,924/1,934 行。Job
  `2118242604438040578` 已提交，初始“部署中”。
- 2026-11-05 15:29：libri_test `DU-pred-nt-paperfix` 匿名化已完成，
  1,934 WAV/JSONL/VPC、0 negative duration、格式和 owner 正确；
  verification SHA256
  `67355ab731d064ad2bb3b7acc0f3109c40b4eba7966d7b53b81b042749d1cb4d`。

- 2026-11-05 14:33：d7 libri_test 原始语音基线已提交 Job
  `2118230351709052930`，初始“排队中”，1 DCU、
  2 h、预计 0.25、最坏 2.0 卡时；输出独立
  `baseline_orig_vpc/_n019_orig`，不与匿名化 suffix 混用。d7
  paperfix units 已提取到 304/1,934，d4 target embedding 到
  900/1,924，二者日志均正常。
  基线 Job 在模型加载前因缺 `pandas` 失败；已零卡时补齐
  `pandas==2.2.3`、`pytz`、`pyloudnorm`，numpy 仍为 `1.26.4`，
  `run_evaluation.py` import 通过；同规格重试 Job
  `2118234972682821633` 已提交并排队，但远端 vendor 文件仍是旧版，
  在 dependency pin 处失败。已将本地带
  `N019_SKIP_DEPENDENCY_CHECK` 分支的文件同步到 d7 并核验。
  第二次重试 Job `2118235252464013314` 已提交并排队。
  该 Job 因 vendor 根缺少相对 `data/` 路径而在 format gate 失败；
  已建立指向 `vpc/` 的 vendor `data` symlink 并确认 WAV 可解析。
  第三次重试 Job `2118241331310600193` 已提交并排队。
  该 Job 仍因 vendor `data` symlink 目标多了一层 `vpc/` 而失败；
  已改为指向 `vpc/data/`，并确认相对 WAV 路径存在；第四次重试 Job
  `2118242914452033537` 已提交并排队。
  该 Job 已通过 format gate，但 ASV 因 d7 的 torchaudio compat
  目录缺 `__init__.py`/`transforms.py` 而报 `torchaudio.load` 不存在；
  已从固定 compat 包补齐并确认 `torchaudio.load` 可导入。
  第五次重试 Job `2118245146424352769` 已提交并排队。
  该 Job ASV 已通过：female `8.761%`、male `0.418%`，均值
  `4.5895%`；ASR 因 HF metadata cache 缺失停止。已固定 revision
  `54074b1c...` 下载 `config.json`/`preprocessor_config.json`
  并中转，offline feature extractor probe 通过。
  第六次重试 Job `2118249890493542402` 已提交并排队。
  该 Job 仍因 SpeechBrain 使用显式相对
  `cache_dir=exp/asr/wav2vec2_model_checkpoints` 而读不到 HF_HOME。
  已把固定 snapshot 放入对应 cache，并用相同 cwd/cache_dir 做
  offline probe，通过。
  第七次重试 Job `2118251610465116162` 已提交并排队。
  第七次仍因 SpeechBrain 在离线时访问 Hub 而停止。已建立
  `asr_n019_local`：ckpt 与官方模型逐字节相同（硬链接），只把
  `wav2vec2_hub` 指向本地目录并附带固定 metadata；本地 probe 通过。
  第八次重试 Job `2118253551901843458` 已提交并排队。
- 2026-11-05 14:46：d7 libri_test paperfix units Job
  `2118228637901398018` 已完成，1,934 records、40 speakers、
  0 missing/0 mismatch，verification SHA256
  `507dddaa64d2efbe6e6d5f6775d98077c3504a1517485a1e7abb9da772121308`。
- 2026-11-05 14:58：d4 target embedding Job
  `2118223421122203650` 已完成：1,924 条、250-D、finite、norm 正常；
  NPZ SHA256 `0c2a747220bac2a231cbde981a9d5dfca621750348f87f7ce18fab84994a58b7`。

- 2026-11-05 14:27：d4 libri_test target embedding Job
  `2118223421122203650` 仍在运行，日志已提取到 600/1,924 条且
  embedding 有限；同轮实时余额为 d3 `17.268611111`、d4
  `9.1908333332`、d5 `4.216111111`、d6 `37.536111111`、d7
  `45.7341666667` 卡时。d7 已部署 paperfix units 脚本，SHA256
  `d7c162b6a49688515de18babf0e7c83219963fce1370d7958b2aefde4c42fa78`，
  1 DCU、1 h、最坏 1.0 卡时；已提交 Job `2118228637901398018`，
  初始页面状态“排队中”。

- 2026-11-05 14:06：libri_test 已在 d7 从官方 test-clean 精确重建
  并通过验收：1,934 WAV、16 kHz mono PCM16、21,650 trials。d4
  已提交论文版 target embedding Job `2118223421122203650`，
  1 DCU、15 CPU / 59 GB、3 h、最坏 3.0 卡时。实时余额：d3
  `17.268611111`、d4 `9.1908333332`、d5 `4.216111111`、
  d6 `37.536111111`、d7 `45.7341666667` 卡时。
- 2026-11-05 10:13：d6 paperfix LS360 第一窗口因 6 h 外层
  timeout 在 `93391/104014` 停止，partial 完整保留，控制台“失败”
  不代表模型失败。没有残留 writer，已提交同一目录续跑 Job
  `2118164816636981249`，1 DCU、15 CPU / 59 GB、外层 2 h、最坏
  2.0 卡时。第一次因启动脚本漏传 `N019_ANON_OUT`、第二次因
  93,391 日志计数与 93,375 实际落盘行数相差一个 25 行缓冲，均在
  模型加载前退出，partial 未改。门禁改为至少 93,350 后，第三次
  Job `2118165677283745794` 已启动，partial 93,375 行且
  `resume=1`。该 Job 已完成 `104014/104014` 合成和 VPC 导出；
  收尾 chown 因组名不可解析失败，数据未变，纯 ownership Job
  `2118180309146669057` 已完成于 11:53:35，关键输出 owner
  已修正，全量验收 `passed=true`。d6/d7 公开评测资产均已完成；d6
  WhiSQA checkpoint 从 `.part` 成功续传。提交时余额：d3
  `17.268611111`、d4 `9.1908333332`、d5 `4.216111111`、d6
  `39.1208333332`、d7 `45.7341666667`。
- 22:55：d3 duration-pred retry Job `2117992970106335234` 运行中；
  d6 NT vocoder paperfix Job `2117993296451735554` 运行中。d6 的
  LibriSpeech clean-100 解包尚未完成（当前约 20,931 codes、无
  `unit_records.jsonl`），但 vocoder 所需的 `libritts_train_clean_100`
  输入完整，不能把两者混用。
- 23:20：d3 duration-pred 已完成 30 epochs；`best.pt`
  SHA256 `8d5153c920058204fe13ebb75b0744703bc0523e70f3a83fbd8b194245a3ba1c`。
  d6 vocoder 第一次失败已确认是旧 d4 unit path；路径修复门禁通过后，
  第二次 Job `2118000486608805889` 已提交，余额 `45.2569444444` 卡时。
- 23:32：d6 second vocoder 因缺少本地 LibriTTS clean-100 音频退出；
  d3 的对应音频、codes、NT embedding 均完整，修正版 NT vocoder 已改在
  d3 运行，Job `2118002044909432834`，输出 `vocoder_nt_paperfix`。
- 2026-11-05 03:51：d3 paperfix vocoder 已 converged
  （step 34000，best 4000，best SHA256
  `f1735e757ecfc4bfb6a230ae26219058e6aed8bef18656bb2b694cc89ed070d9`）；
  d6 的 `DU-pred-nt-paperfix` Job `2118069808953692162` 已提交，
  预计 5.5 h、最坏 6 卡时。
- 实时余额：d3 `24.5091666666`、d4 `9.1908333332`、
  d5 `4.216111111`、d6 `45.7486111111`、d7 `45.7341666667` 卡时。
- 代码修正已完成：duration loss 归一化、feature-matching 权重、
  `pred` duration launcher 和 ECAPA duration 语料路径；本地
  `107 tests OK, skipped=3`。
- 修正版代码包的最终名称、大小和 SHA256 以 `artifacts/SHA256SUMS.txt` 为准；
  待同步 d6/d7 后再提交新训练。
- 短期只做 `DU-pred-nt`，先重训 `duration_pred_paperfix` 和
  `vocoder_nt_paperfix`。修正前的 checkpoint 和 d6/d7 LS360 输出冻结，
  不作为修正版结果复用。
- d6/d7 当前控制台任务均为“已完成”，没有运行中的 AI 训练任务。

## 0. 2026-11-04 21:05 实时快照

- 主 vocoder 已完成收敛，最终推理使用 step 76,000 的 `best.pt`；
  SHA256 `32f8cbf064b48e1cedb2541c72b34916570e8d3a1da66c39de0ca04a2cfc1477`。
- 提交前余额：d6 `50`、d7 `50` 卡时；d3 `24.5091666666`、
  d4 `9.1908333332`、d5 `4.216111111` 卡时。
- d6 `DU-orig-nt` Job `2117871537248841729` 于 18:51:57 完成；
  d7 `DU-pred-nt` Job `2117871585265983490` 于 18:54:04 完成。
  两边均写出 `104,014` records/WAV，VPC `wav.scp=104,014`。
- d6/d7 的 d5 绝对路径已修复并复验；两账号均为 104,014 records、
  921 speakers、0 missing/shape error，target NPZ 81,605 条、250-D、
  finite、L2 正常。输入门禁通过后才提交。
- d6/d7 仍在下载 LibriSpeech train-clean-360 原包，18:04 约
  `45.49%` / `53.26%`，不占 DCU。
- 因输出仍为容器 root 所有，已提交 d6/d7 纯 chown：
  Job `2117936167295954945` / `2117936206308601857`，二者已分别于
  19:16:45 / 19:15:49 完成。
- 全量 `verify_anonymized_outputs.py` 已通过：两边各 104,014 WAV、
  104,014 VPC 行、ID/路径集合一致、0 negative duration、
  16 kHz mono PCM16 抽样通过、owner 正确。d6/d7 `anon.jsonl`
  SHA256 分别为 `72898a50...668c07` / `3a22f487...5d625f`。
- 20:01 余额：d3 `24.5091666666`、d4 `9.1908333332`、
  d5 `4.216111111`、d6 `45.7486111111`、d7 `45.7341666667` 卡时。
- 下一步核对 d6/d7 官方评测资产，随后进入 E-VPC I/L、W-NT I/L、
  WER、UTMOS、WhiSQA；S attack 单独做资源计划。
- 20:18 已在 d6/d7 启动公开评测资产下载，目标包含 VPC2024 v2、
  asv_orig/asr、HuBERT、W-PRO、UTMOS22 和 WhiSQA；日志见
  `logs/n019_official/public_assets_eval_20261104.log`，不占 DCU。
- 21:05 网络中断：d6 的 asv 约 4 MB、d7 的 asr 约 91%（687.9 MB）。
  d7 的 asv 已完成；d6 改用 16 连接公开代理下载器并保留 SHA256
  校验，d7 从现有 asr part 续传，不重新下载已完成的文件。
- 21:03 余额：d3 `24.5091666666`、d4 `9.1908333332`、
  d5 `4.216111111`、d6 `45.7486111111`、d7 `45.7341666667` 卡时。

## 0. 2026-11-04 13:39 实时快照

- d3 主 vocoder 已于 13:09:40 `converged` 完成：step `106,000`，
  15 次验证无至少 0.001 改善；最终推理选择 `best.pt`（step 76k，
  mel L1 `0.7805652022361755`，SHA256 `32f8cbf0...cf1477`）。
- 13:39 余额：d3 `24.5091666666`、d4 `9.1908333332`、
  d5 `4.4113888888`、d6 `50`、d7 `50` 卡时。
- d3 vocoder NT main continuation Job `2117804993484845057` 正在运行；
  11:50 到 step `91,120`，约 `0.35 s/step`，loss 有限；90k 验证
  `0.7877435684204102`，best 仍为 step 76k 的
  `0.7805652022361755`，patience `7`。
- d5 LS360 units ownership repair Job `2117799927749849089` 已于
  11:07:15 完成；实际约 1.056 卡时。最终 104,014 codes、
  104,014 records，关键文件所有权与 verification 均通过。
- canonical NT target embedding、manifest、metadata，以及 duration
  NT/pred checkpoint 与 meta 已通过本机中转 d5；七项 SHA256 全部
  与 d4 源文件一致。d5 已具备正式匿名化的静态输入。
- 当前代码包为 r27：`264,355` bytes、SHA256
  `74a6ee2fc02b63db9a1b1783ced4076566a784f11b2305188d5aee2ef15dfee2`；
  已解包到 d4/d5/d6/d7 live code。d6/d7 各 `104 tests OK`，
  d3 因主训练未覆盖 live code。
- d5 target NPZ 内容复核通过：81,605 行、250-D、finite，manifest
  与 NPZ key 的集合和顺序均一致。
- d6/d7 已启动各自服务器上的 LibriSpeech train-clean-360 公开下载；
  不占 DCU。13:39 分别约 `18.92%`、`22.33%`，下载完成后仍需
  MD5、104,014 FLAC 和 921 speaker 目录验收。
- d6/d7 已收到 LibriTTS clean-100 训练包和 LS360 anonymisation
  静态输入包；两账号解压后的关键 SHA256 与 d4 一致。LS360 units
  104,014 文件的解压/计数仍在进行。

## 0. 2026-11-04 10:18 实时快照

- d4 vocoder NT main 第一窗口在 step `78,896` 正常达到
  `max_hours`；最佳验证为 step `76,000`、mel L1 `0.780565`。
- run 已完整中转 d3，五项文件 SHA256 一致。第一次 continuation
  `2117802840442572801` 因 d3 旧 `torch.stft` 触发 HIPFFT 失败；
  已同步 r25 explicit DFT `spectral.py` 并通过定向测试，重试
  Job `2117804993484845057` 已在 10:34 确认从 step `78,896` 之后
  续训，当前到 step 80,000；80k 验证 mel L1 `0.828044`。
- d5 LS360 units 已完成 104,014 records、921 speakers、
  0 missing、0 shape/value mismatch；`unit_records.jsonl` SHA256
  `e55b76ac70540f4458c08d5c8f03c03c31edfa6880aa92335ad3903be25725be`。
  所有权修复 Job `2117799927749849089` 已提交。
- 当前计划中的 target embedding、units 数据阶段均已闭环，下一阶段是
  vocoder 收敛、LS360 anonymisation 和官方指标评测。

## 0. 2026-11-04 08:54 实时快照

- d5 第二 resume 在 `99,600/104,014` 到 6 小时上限；第三 resume
  Job `2117781760282206209` 已启动并确认 `resume=1`。剩余约
  4,414 句，预计本窗口内完成。
- d4 vocoder NT main 在 08:49 约 step 69,700、训练 7.1 小时；
  58k 验证最佳 mel L1 为 `0.808085`。8 小时窗口约 09:15 到达，
  届时先查 checkpoint、`stop_reason` 和所有权，再决定是否按规则续训。
- d3 target embedding、canonical merge 和 d4 主训练资源均未变化。

## 0. 2026-11-04 02:32 实时快照

- d5 上一 LS360 units 窗口在 `65,904/104,014` 达到 6 小时硬上限；
  Job `2117685309698658306` 已按同一目录 `--resume` 重新启动，
  日志确认 `resume=1`。
- d4 vocoder NT main 继续稳定训练，当前超过 step 10,500；尚未进入
  20k 收敛判断区。
- 四片 NT target embedding canonical 合并已完成：81,605 行、
  250-D、finite，merged NPZ SHA256
  `274dd8012a59ff02a7bcc11921b1be2b731b2c4fcba50603428c7d5c2a047f1a`。
- 本轮未新增除 d5 resume 外的卡时任务；d4 主训练资源计划不变。

## 0. 2026-11-04 01:57 实时快照

- d3 target embedding shard 2/3 均完成并核验为 20,401 条、250-D、
  finite、L2 norm 正确；Job `2117675967040299010` 已修复 root
  所有权。
- 两片 NPZ/manifest/metadata 已通过稳定流式中转到 d4，逐文件
  SHA256 一致。四片合并 canonical 输出为 81,605 行，NPZ SHA256
  `274dd8012a59ff02a7bcc11921b1be2b731b2c4fcba50603428c7d5c2a047f1a`，
  manifest 与 canonical source SHA256
  `f6986086fbf79e0555629ad31fe7acb5893b90db03cef44f60b27fa9e5cea76b`
  一致。
- d4 vocoder NT main 到 step 6,800，约 `0.36 s/step`，loss 有限，
  未到 20k 收敛判断门槛。
- d5 LS360 units 到 `63,104/104,014`，当前窗口继续运行。
- 无新增长训练卡时任务；d6/d7 仍各 50 卡时并保持空闲。

## 0. 2026-11-04 00:56 实时快照

- 实时余额：d3 `31.8633333332`、d4 `25.7924999999`、
  d5 `15.0494444444`、d6 `50`、d7 `50` 卡时。
- d4 2-DCU pilot 已完成 1000 步训练，51 条 loss 全部有限；
  `last.pt`、1000-step checkpoint 和 `best.pt` 均可加载。控制台
  最终失败由运行中更新脚本导致，不是数值失败；root 所有权已通过
  短任务修正。
- d4 已启动 `vocoder_nt_main` 第一窗口，Job
  `2117662083886911489`：2 DCU、8 h 训练窗口、8.25 h 外层墙钟、
  最坏 16.5 卡时，收敛即停。余额覆盖最坏占用并保留约 9.29 卡时。
- d3 shard 3 已写出 20,401 条 final NPZ，250-D、finite、L2 norm
  正确；manifest 权限待 shard 2 完成后统一修复。shard 2 当前
  `18,560/20,401`。
- d5 LS360 units resume 当前 `58,000/104,014`；本窗口结束后需要
  同一输出目录的第二次 `--resume`。
- d4 `/public` 可用约 39 GB，主训练 checkpoint 预算按至少 12–15 GB
  通过门禁。

## 0. 2026-11-04 00:30 实时快照

- d6/d7 的 `py311`、代码 root、venv 和依赖均已建立；audit 通过。
- r24 已同步 d6/d7；两账号完整测试均为 `104 tests OK`。
- r24：`artifacts/n019_code_20261104_r24.tar.gz`，SHA256
  `60663b42f715476b33508158961352b63d4069f9b5ac4ef027c160aecf1817fa`。
- 大文件本机中转不再依赖 SSH：SCNet 文件管理页可以稳定
  上传/下载；1.3 GB `py311` 归档在 d6/d7 的 SHA256 均为
  `babcb9a81b3f0dc4f1125edc3af24bcd7b42723caf8bad2a3bd7b819110ad41f`。
- d4 2-DCU pilot 已改用不依赖 hipFFT 的显式 DFT mel 前端，
  Job `2117653221587161090` 正在运行。

## 0. 22:50 实时快照

- d4 的 NT target shard 0/1 已写出 final 文件并核验：
  `20,402 + 20,401` 条、250 维、finite、key 集合一致；
- 两片控制台状态为“失败”，原因是 AI 容器收尾时按 root 所有权
  处理输出；Job `2117623116743094274` 已完成纯 `chown`，数据内容
  未改；
- d4 2-DCU vocoder DDP pilot 已提交，Job
  `2117623823366492162`，1000 steps、12 分钟训练上限、最坏 0.5 卡时；
- d3 shard 2/3 仍在累计 partial；d5 units resume 在 22:29 到
  `45,104 / 104,014`；
- d6/d7 已安装 30 天 E-Shell RSA key，SSH 登录成功；下一关是
  `py311` 迁移、`conda-unpack`、venv provisioning、103 项测试与空间审计。

## 0. 19:27–19:39 实时快照

- 实时余额：d3 `42.3622222221`、d4 `33.3025`、d5
  `20.0208333333` 卡时。三个持久化浏览器会话均可直接读取，未重新
  登录，也没有把凭据写入项目。
- d4 NT target shard 0/1：`16,256/20,402`，仍运行；
- d3 NT target shard 2/3：`7,680/20,401` 与 `8,192/20,401`，
  仍运行；
- d5 LS360 units：`30,200/104,014`，累计 `19,371.2 s`，预计
  20:09 左右达到 6 小时硬上限；
- d4 共享 `/public` 仅剩 44 GB，d3 119 GB，d5 163 GB；
- d4 的旧 vocoder/ECAPA 脚本已补齐到与 d3/d5 相同哈希；
- `anonymize_ls360_remote.sh` 已支持 NT/ECAPA 独立选择，
  `DU-nt-ecapa`、`DU-ecapa-nt` 等交叉组合不再被硬编码覆盖；
- 新增 ECAPA target shard 配置，尚未提交。

## 0.1 20:32 续跑状态

- 实时余额：d3 `40.3622222221`、d4 `31.3025`、d5
  `18.7744444444` 卡时；
- d4 shard 0/1 在 20:01 各 `16,896/20,402`，继续运行；
- d3 shard 2/3 在 20:32 为 `9,472/20,401` 与
  `11,264/20,401`，继续运行；
- d5 第一个 units 窗口在 `33,504/104,014` 到 6 小时硬上限；
  resume `2117591722692628481` 已提交并从 `33,600` 正确继续，
  20:31 为 `33,800/104,014`；
- 当前代码包为 r20，SHA256
  `9aa51696549632448193b1130f1416edda05a58bb1d52427dbbb379746dd30be`。

## 1. 代码与环境

- 最新代码包：`n019_code_20261103_r18.tar.gz`，SHA256 见
  `artifacts/SHA256SUMS.txt`；
- 本地测试：98 项通过、2 项因本地缺 librosa skip；
- 三账号环境：Python 3.11.17、DTK 26.04、Torch 2.9.0、
  HIP 6.3.26093、torchaudio 2.9.0+scnet-compat；
- r18 同步后三账号必须各自通过 `compileall`、shell syntax 和全部测试。
- 浏览器任务提交已改为配置驱动的
  `scripts/scnet_browser_tasks.py`；账号、资源、镜像、启动脚本和页面
  选择器均在 `configs/scnet_browser_tasks.json`。d4 真实登录干跑通过，
  未创建任务、卡时 0。

## 2. `a094f4d3`

- 四个公开训练语料 tar 已在该账号自己的服务器下载完成，文件名已从
  `.parallel.part` 改成正式名，说明下载脚本已执行 MD5 校验；
- 2026-11-03 再次逐文件复算，四个官方 MD5 均匹配：

```text
LibriSpeech train-clean-100  2a93770f6d5c6c964bc36631d331a522
LibriSpeech train-clean-360  c0e676e450a7ff2f54aeade5171606fa
LibriTTS train-clean-100     4a8c202b78fe1bc0c47916a98f3a2ea8
LibriTTS train-other-500     7b181dd5ace343a5f38427999684aa6f
```

- `data/n019_official` 当前约 78 GB；没有正在运行的 N019 下载进程；
- LibriTTS train-other-500 已通过 SSH 完整解压并移动到 canonical
  `corpora/libritts/LibriTTS/train-other-500`，验收 205,044 个 WAV；
  完成标记为
  `audit/train-other-500.ssh-complete.20261103_151949.txt`。
- LibriTTS train-clean-100 的 SSH 解压已完成，canonical 为
  `33,236` 个 WAV。2026-11-03 18:30 unit-record 路径迁移和全量校验
  通过（33,236 records、247 speakers、0 missing）。
- 已同步正式 LS360 utterance target map 和 target manifest；
- 定位：第二训练/评测账号。长任务前仍需检查其个人配额和实时余额。

## 3. `a094f4d4`

- 主账号环境、官方 VPC、HuBERT/W-PRO/UTMOS/WhiSQA、duration 和
  vocoder pilot 均为现成；
- 已生成正式 LS360 target map：104,014 个 source、81,605 个 target；
- 当前共享 `/public` 约剩 44 GB。完整 LS360 匿名化按 PCM16 WAV
  估计约 42 GB，默认 1.10 安全系数后需要约 46 GB，因此禁止直接在
  d4 启动完整 LS360 匿名化；
- 定位：target embedding/LS360 units 的首次生成、主 vocoder 训练、
  libri_test Table 1 评测。
- 两个 target embedding shard 在 15:59 各完成 `9,472 / 20,402`；
  实时余额 `41.3025` 卡时。
- 18:39 两个 shard 到 `14,464/14,592`；d4 的 vocoder Dataset 首/中/尾
  抽样门禁通过，2-DCU pilot 已具备数据条件，等待 shard 释放卡。

## 4. `a094f4d5`

- 已自行下载并 MD5 校验 LibriSpeech train-clean-360 原始包；
- 已通过 SSH 解压为 104,014 个 FLAC、921 个 speaker 目录；
- 已完成 104,014 句/921 人/363.6056 小时 manifest，16 kHz 单声道，
  官方 utterance ID 集合一致；
- 已同步正式 LS360 target map 和 target manifest，SHA256 与 d4 一致；
- 当前共享 `/public` 约剩 163 GB；
- 定位：完整 LS360 匿名化与 S attack 训练的首选账号。
- LS360 HuBERT units 在 15:59 到 `9,800 / 104,014`；当前 6 小时
  窗口不会完成全量，已配置同目录 `--resume` 后续任务，尚未提交。
- 18:38 到 `24,504 / 104,014`，预计 20:10 左右触发当前 6 小时上限。
- d3 的 clean-100 unit records 已迁移并全量校验；vocoder Dataset 首/中/尾
  抽样门禁通过，2-DCU pilot 同样只等 shard 释放卡。

## 5. 数据中转规则

- 原始 tar 和完整音频：各账号在自己的服务器下载/解压；
- 代码、target map、target embedding、unit records、duration/vocoder
  checkpoint：走本机中转，逐文件复算 SHA256；
- 不把完整 LS360 匿名化 WAV 或原始 23 GB tar 经本机中转；
- 不在 d4 磁盘余量不足时强行生成完整匿名化 LS360。

## 6. 当前阻塞与下一步

`https://www.scnet.cn/ui/console/index.html#/model-training/add-train`
已在 Edge 中登录并可读取实时资源。d4 pilot 完成后机时余额为
`49.8186111111`；256 句 pilot 任务 `2117442203569016834` 已完成，
吞吐 `0.4012539185 句/s`，按同一口径外推 81,605 句约 `56.4930`
卡时。d4 的 shard 0/1（任务 `2117447702608093185`、
`2117447862870855681`）已提交并运行。

已修正 AI 容器根目录探测：AI 容器内为 `root`，不能再用
`id -un` 拼 `/public/home`；现在从脚本自身路径推导项目根。
d3 的 `train-other-500.tar.gz` 已完成 SSH 解压和 205,044 WAV 验收，
shard 2/3 已具备提交条件；需等 d3 当前 2-DCU vocoder pilot 释放卡后
再提交，避免团队 2 卡配额冲突。

恢复后按顺序：

1. target embedding 256 句吞吐 pilot；
2. 81,605 个 target utterance 的 W-PRO embedding；
3. LS360 HuBERT units；
4. 2/4-DCU vocoder DDP pilot；
5. 400k-step 主 vocoder；
6. d5/d3 的完整 LS360 匿名化与 S attack。
