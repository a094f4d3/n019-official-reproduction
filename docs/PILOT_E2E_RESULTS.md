# DU-pred-nt Pilot Results

日期：2026-11-03  
JobID：`1021278`  
状态：`COMPLETED`，实际墙钟 `10m50s`，实际卡时 `0.1806`  
用途：链路诊断，**不是 Table 1 正式结果**

## 条件

- 官方 VPC2024 `libri_test`；
- `DU-pred-nt`；
- 无条件 duration predictor：`duration_pred_main/best.pt`；
- 仅训练 2,000 steps 的 Unit HiFi-GAN pilot：
  `vocoder_nt_pilot_1020953/last.pt`；
- 1,934 句匿名化 WAV，438 条 enrollment，734/762 条 female/male trial；
- E-VPC/WER/W-NT 均走当前官方评测入口。

## 结果

| 指标 | Pilot | 论文 DU-pred-nt | 绝对差 |
|---|---:|---:|---:|
| E-VPC I | 46.8735 | 47.2 | -0.3265 |
| E-VPC L | 46.4230 | 47.9 | -1.4770 |
| E-VPC S | 未跑 | 34.8 | n/a |
| W-NT I | 42.3356 | 39.9 | +2.4356 |
| W-NT L | 42.3863 | 42.3 | +0.0863 |
| W-NT S | 未跑 | 24.6 | n/a |
| WER | 18.424 | 7.41 | +11.014 |
| UTMOS | 未跑 | 3.63 | n/a |
| WhiSQA | 未跑 | 3.69 | n/a |

## 解释

- E-VPC I/L 和 W-NT I/L 已经落在论文 DU-pred-nt 的邻近区间，
  说明 unit、target、匿名化、官方 trial 和 ASV 打分链路基本正确。
- WER 明显恶化与 2,000-step vocoder 的可懂度一致；不能通过改评测或
  跳字来“修复”，必须完成主 Unit HiFi-GAN 训练后重测。
- 本 pilot 没有 S attack，也没有 MOS，因此不构成 Table 1 闭环。

## Evidence

```text
runs/n019_official/pilot_e2e/anonymised/DU-pred-nt/
runs/n019_official/eval/pilot_e2e/evpc/evpc_metrics.json
runs/n019_official/eval/pilot_e2e/libri_test_trials_f_{I,L}.json
runs/n019_official/eval/pilot_e2e/libri_test_trials_m_{I,L}.json
runs/n019_official/eval/pilot_e2e/summary.json
runs/n019_official/pilot_e2e/pilot_metrics_summary.json
runs/n019_official/pilot_e2e/paper_metrics_pilot.json
runs/n019_official/pilot_e2e/paper_comparison_pilot.json
runs/n019_official/pilot_e2e/paper_comparison_pilot.md
logs/n019_official/n019_pilot_e2e_1021278.out
logs/n019_official/n019_pilot_e2e_1021278.err
```

`paper_comparison_pilot.md` 使用 `configs/paper_table1.json` 和统一容差
规则生成：5 项已测指标中 2 项在 0.5 个百分点容差内，3 项在外，
4 项仍为 `pending`。这再次说明该 pilot 只验证链路，不是正式复现。
