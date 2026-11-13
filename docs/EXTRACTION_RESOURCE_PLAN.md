# `a094f4d4` Extraction-Only Resource Plan

更新日期：2026-11-02

本任务只做解压和完整性检查，不训练、不推理、不评测。

```text
账户：a094f4d4
模式：HPC / Slurm
任务名：n019_extract_only
partition：hx1hdnormal
节点数：1
DCU 数：1
CPU：16
host RAM：32G
墙钟上限：01:30:00
最坏卡时：1.5 DCU-hours
预计卡时：0.5-1.2 DCU-hours
```

输入：

```text
/public/home/a094f4d4/voice_projects/data/n019_official/corpora/libritts/train-other-500.tar.gz
/public/home/a094f4d4/voice_projects/data/n019_official/rebuilt/VPC2024_LibriSpeech_rebuilt_v1.tar.zst
/public/home/a094f4d4/voice_projects/data/n019_official/vpc/data.zip
/public/home/a094f4d4/voice_projects/data/n019_official/vpc/data_test_tools.zip
/public/home/a094f4d4/voice_projects/models/n019_official/vpc/asv_orig.zip
/public/home/a094f4d4/voice_projects/models/n019_official/vpc/asr.zip
```

输出：

```text
/public/home/a094f4d4/voice_projects/data/n019_official/corpora/libritts/LibriTTS/train-other-500/
/public/home/a094f4d4/voice_projects/data/n019_official/rebuilt/VPC2024_LibriSpeech_rebuilt_v1/
/public/home/a094f4d4/voice_projects/data/n019_official/vpc/
/public/home/a094f4d4/voice_projects/models/n019_official/vpc/
/public/home/a094f4d4/voice_projects/code/n019_official/audit/
```

停止条件：

- 官方 MD5/SHA256 不一致；
- ZIP/tar 解压失败；
- 个人存储不足；
- 15 分钟没有新的解压日志；
- Slurm 达到墙钟上限。

提交脚本：

```text
/public/home/a094f4d4/voice_projects/code/n019_official/scripts/multi_account/extract_all_d4.slurm
```

`sbatch --test-only` 已通过。2026-11-02 的测试输出预计资源最早在
`2026-11-07T22:04:17` 分配；这只是提交前的模拟时间，不表示作业已经提交或
资源已经保留。实际等待时间以正式提交后的 `squeue` 为准。

该脚本不依赖登录节点的 `/tmp`。2026-11-02 登录节点 `/tmp` 已满，因此所有
解压暂存目录都放在 `$HOME/voice_projects/data/n019_official` 内。
