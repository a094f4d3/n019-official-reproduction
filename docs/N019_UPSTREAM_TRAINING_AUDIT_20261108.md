# N019 Unit HiFi-GAN Upstream Training Audit

日期：2026-11-08

## 结论

此前实现的 Unit HiFi-GAN 使用了 `learning_rate = 8e-4`。论文指出
Unit HiFi-GAN 按 speech-resynthesis 与 DISSC 的方法训练；公开的
speech-resynthesis 训练配置统一为 `learning_rate = 2e-4`。因此旧
4k/76k/102k 和 2x 14k–24k checkpoint 的学习率比引用实现高 4 倍。

现有 2x 训练在 step 14k 后出现明显 checkpoint 间质量波动：
18k 的 UTMOS 降到 `1.3242`，20k 恢复至 `2.1469`，22k 再恢复到
`2.5313`，但三者都仍低于 14k 的 `2.6693`。这与过高学习率下的
GAN 不稳定相符，但尚未用受控实验证明唯一因果。

旧 2x 训练还使用 2 DCU DDP、总 batch 32。论文写两个 RTX 4090 用于
训练两个 Unit HiFi-GAN 模型，且引用配置是单卡 batch 16；更合理的
读法是 NT/ECAPA 两个模型各占一张卡，而不是每个模型用双卡 DDP。
因此新 NT 训练先采用 1 DCU、batch 16。

## 证据

- 上游仓库：
  `https://github.com/facebookresearch/speech-resynthesis`
- 审计 commit：
  `dbb92c8ddeb081e711adbe9a75714027cd447532`
- `configs/LibriLight/vqvae256.json`：
  `batch_size=32`, `learning_rate=0.0002`, `adam_b1=0.8`,
  `adam_b2=0.99`, `lr_decay=0.999`, `segment_size=8960`
- `configs/VCTK/hubert100_lut.json`：
  `batch_size=16`, `learning_rate=0.0002`, 其余参数相同
- `examples/expresso/config/expresso_config.json`：
  `batch_size=16`, `learning_rate=0.0002`, 其余参数相同
- `models.py::feature_loss`：累加所有 MPD/MSD 特征 L1 后乘 `2`
- `train.py`：AdamW、feature loss、45 倍 mel L1、每 epoch
  `ExponentialLR(0.999)` 的总体结构与本项目一致

## 已修正

- `src/n019/vocoder.py` 的默认和 CLI 学习率改为 `2e-4`
- `src/n019/vocoder_smoke.py` 改为 `2e-4`
- generator gradient clipping 默认关闭；上游 `train.py` 没有该步骤，
  旧实现的 `5.0` 是无来源的额外差异
- `configs/paper_algorithm_v1.json` 改为 `0.0002` 并记录上游证据
- `tests/test_paper_alignment.py` 增加代码/配置一致性检查
- 2x feature matching 的 `2x` 系数保留；上游 `feature_loss` 同样
  在完整特征累加后乘 `2`

## 下一步受控计划

1. 在 d6 自行下载并校验 LibriTTS train-clean-100：
   URL `https://www.openslr.org/resources/60/train-clean-100.tar.gz`，
   size `7,723,686,890` bytes，MD5
   `4a8c202b78fe1bc0c47916a98f3a2ea8`。
2. 同步当前代码与 2x recipe，使用 `2e-4`、1 DCU、batch 16
   从头训练新的 NT Unit HiFi-GAN；不继续使用 8e-4 的
   14k/24k optimizer state。
3. 先做短 GPU pilot，核对 loss 有限、throughput 和 scheduler；
   再按资源计划分段保存 2k/10k snapshots。
4. 选模仍只看固定 speaker-disjoint dev-100 的 UTMOS、WhiSQA、
   WER；不直接对 test 调 checkpoint。
5. 只有 dev 明确超过当前 2x14k baseline，才做完整 1,934 句复评。

## 仍需验证的假设

- speaker embedding 是否需要投影到 128 维；论文只写拼接，未给投影
- HuBERT layer 6 是否与作者一致
- 作者实际训练步数、gradient clipping 和 scheduler 触发周期未公开
  现已确认引用代码不使用 gradient clipping；作者是否另加仍未知
- 目标 embedding 的 speaker-level pooling 已由配对 A/B 支持，但
  absolute gain 只有 UTMOS `+0.1304`、WhiSQA `+0.0911`
