"""Paper-faithful Unit HiFi-GAN generator and discriminators.

The architecture and adversarial terms follow HiFi-GAN as used by the
speech-resynthesis implementation cited in the N019 paper.  N019 changes the
generator input to the frame-wise concatenation
``[unit_embedding, speaker_embedding]``.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Sequence

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.nn import AvgPool1d, Conv1d, Conv2d, ConvTranspose1d
from torch.nn.utils.parametrizations import weight_norm


LRELU_SLOPE = 0.1
FEATURE_MATCHING_SCALE = 2.0


@dataclass(frozen=True)
class GeneratorConfig:
    upsample_rates: tuple[int, ...] = (5, 4, 4, 2, 2)
    upsample_kernel_sizes: tuple[int, ...] = (11, 8, 8, 4, 4)
    upsample_initial_channel: int = 512
    resblock: str = "1"
    resblock_kernel_sizes: tuple[int, ...] = (3, 7, 11)
    resblock_dilation_sizes: tuple[tuple[int, ...], ...] = (
        (1, 3, 5),
        (1, 3, 5),
        (1, 3, 5),
    )

    @property
    def samples_per_frame(self) -> int:
        value = 1
        for rate in self.upsample_rates:
            value *= rate
        return value

    def to_dict(self) -> dict:
        return asdict(self)


def get_padding(kernel_size: int, dilation: int = 1) -> int:
    return int((kernel_size * dilation - dilation) / 2)


def init_weights(module: nn.Module, mean: float = 0.0, std: float = 0.01) -> None:
    if module.__class__.__name__.find("Conv") != -1:
        module.weight.data.normal_(mean, std)


class ResBlock1(nn.Module):
    def __init__(
        self,
        channels: int,
        kernel_size: int = 3,
        dilation: Sequence[int] = (1, 3, 5),
    ) -> None:
        super().__init__()
        self.convs1 = nn.ModuleList(
            [
                weight_norm(
                    Conv1d(
                        channels,
                        channels,
                        kernel_size,
                        1,
                        dilation=d,
                        padding=get_padding(kernel_size, d),
                    )
                )
                for d in dilation
            ]
        )
        self.convs2 = nn.ModuleList(
            [
                weight_norm(
                    Conv1d(
                        channels,
                        channels,
                        kernel_size,
                        1,
                        dilation=1,
                        padding=get_padding(kernel_size, 1),
                    )
                )
                for _ in dilation
            ]
        )
        self.convs1.apply(init_weights)
        self.convs2.apply(init_weights)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        for conv1, conv2 in zip(self.convs1, self.convs2):
            xt = F.leaky_relu(x, LRELU_SLOPE)
            xt = conv1(xt)
            xt = F.leaky_relu(xt, LRELU_SLOPE)
            xt = conv2(xt)
            x = xt + x
        return x

    def remove_weight_norm(self) -> None:
        for layer in [*self.convs1, *self.convs2]:
            torch.nn.utils.parametrize.remove_parametrizations(layer, "weight")


class ResBlock2(nn.Module):
    def __init__(
        self,
        channels: int,
        kernel_size: int = 3,
        dilation: Sequence[int] = (1, 3),
    ) -> None:
        super().__init__()
        self.convs = nn.ModuleList(
            [
                weight_norm(
                    Conv1d(
                        channels,
                        channels,
                        kernel_size,
                        1,
                        dilation=d,
                        padding=get_padding(kernel_size, d),
                    )
                )
                for d in dilation
            ]
        )
        self.convs.apply(init_weights)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        for layer in self.convs:
            xt = F.leaky_relu(x, LRELU_SLOPE)
            x = layer(xt) + x
        return x

    def remove_weight_norm(self) -> None:
        for layer in self.convs:
            torch.nn.utils.parametrize.remove_parametrizations(layer, "weight")


class HiFiGANGenerator(nn.Module):
    def __init__(self, config: GeneratorConfig, input_dim: int) -> None:
        super().__init__()
        if len(config.upsample_rates) != len(config.upsample_kernel_sizes):
            raise ValueError("upsample rates and kernels must have equal length")
        self.config = config
        self.num_kernels = len(config.resblock_kernel_sizes)
        self.num_upsamples = len(config.upsample_rates)
        self.conv_pre = weight_norm(
            Conv1d(input_dim, config.upsample_initial_channel, 7, 1, padding=3)
        )
        resblock = ResBlock1 if config.resblock == "1" else ResBlock2
        self.ups = nn.ModuleList()
        for index, (rate, kernel) in enumerate(
            zip(config.upsample_rates, config.upsample_kernel_sizes)
        ):
            self.ups.append(
                weight_norm(
                    ConvTranspose1d(
                        config.upsample_initial_channel // (2**index),
                        config.upsample_initial_channel // (2 ** (index + 1)),
                        kernel,
                        rate,
                        padding=(kernel - rate) // 2,
                    )
                )
            )
        self.resblocks = nn.ModuleList()
        channels = config.upsample_initial_channel
        for index in range(self.num_upsamples):
            channels //= 2
            for kernel, dilation in zip(
                config.resblock_kernel_sizes,
                config.resblock_dilation_sizes,
            ):
                self.resblocks.append(resblock(channels, kernel, dilation))
        self.conv_post = weight_norm(Conv1d(channels, 1, 7, 1, padding=3))
        self.ups.apply(init_weights)
        self.conv_post.apply(init_weights)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = self.conv_pre(x)
        for index in range(self.num_upsamples):
            x = F.leaky_relu(x, LRELU_SLOPE)
            x = self.ups[index](x)
            aggregate = None
            for kernel_index in range(self.num_kernels):
                block = self.resblocks[index * self.num_kernels + kernel_index](x)
                aggregate = block if aggregate is None else aggregate + block
            if aggregate is None:
                raise RuntimeError("HiFi-GAN has no residual kernels")
            x = aggregate / self.num_kernels
        x = F.leaky_relu(x)
        return torch.tanh(self.conv_post(x))

    def remove_weight_norm(self) -> None:
        for layer in self.ups:
            layer = torch.nn.utils.parametrize.remove_parametrizations(
                layer,
                "weight",
            )
        for block in self.resblocks:
            block.remove_weight_norm()
        self.conv_pre = torch.nn.utils.parametrize.remove_parametrizations(
            self.conv_pre,
            "weight",
        )
        self.conv_post = torch.nn.utils.parametrize.remove_parametrizations(
            self.conv_post,
            "weight",
        )


class UnitSpeakerHiFiGAN(nn.Module):
    def __init__(
        self,
        *,
        vocab_size: int,
        unit_embedding_dim: int,
        speaker_dim: int,
        generator_config: GeneratorConfig,
        speaker_projection_dim: int | None = None,
        padding_idx: int = 200,
    ) -> None:
        super().__init__()
        self.unit_embedding = nn.Embedding(
            vocab_size,
            unit_embedding_dim,
            padding_idx=padding_idx,
        )
        if speaker_projection_dim is None:
            self.speaker_projection = nn.Identity()
            conditioned_speaker_dim = speaker_dim
        else:
            self.speaker_projection = nn.Linear(
                speaker_dim,
                speaker_projection_dim,
            )
            conditioned_speaker_dim = speaker_projection_dim
        self.speaker_dim = speaker_dim
        self.unit_embedding_dim = unit_embedding_dim
        self.conditioning_dim = unit_embedding_dim + conditioned_speaker_dim
        self.generator = HiFiGANGenerator(generator_config, self.conditioning_dim)

    def forward(
        self,
        units: torch.Tensor,
        speaker_embedding: torch.Tensor,
    ) -> torch.Tensor:
        if units.ndim != 2:
            raise ValueError("units must have shape [batch, frames]")
        if speaker_embedding.ndim != 2:
            raise ValueError("speaker_embedding must have shape [batch, dim]")
        if speaker_embedding.shape[0] != units.shape[0]:
            raise ValueError("unit and speaker batch sizes differ")
        if speaker_embedding.shape[1] != self.speaker_dim:
            raise ValueError(
                f"Expected {self.speaker_dim}-D speaker embeddings, "
                f"got {speaker_embedding.shape[1]}"
            )
        unit_vectors = self.unit_embedding(units).transpose(1, 2)
        speaker = self.speaker_projection(speaker_embedding.float())
        speaker = speaker.unsqueeze(-1).expand(-1, -1, units.shape[1])
        return self.generator(torch.cat([unit_vectors, speaker], dim=1))

    def remove_weight_norm(self) -> None:
        self.generator.remove_weight_norm()


class DiscriminatorP(nn.Module):
    def __init__(
        self,
        period: int,
        kernel_size: int = 5,
        stride: int = 3,
        use_spectral_norm: bool = False,
    ) -> None:
        super().__init__()
        self.period = period
        norm = (
            torch.nn.utils.spectral_norm
            if use_spectral_norm
            else weight_norm
        )
        self.convs = nn.ModuleList(
            [
                norm(
                    Conv2d(
                        1,
                        32,
                        (kernel_size, 1),
                        (stride, 1),
                        padding=(get_padding(kernel_size, 1), 0),
                    )
                ),
                norm(
                    Conv2d(
                        32,
                        128,
                        (kernel_size, 1),
                        (stride, 1),
                        padding=(get_padding(kernel_size, 1), 0),
                    )
                ),
                norm(
                    Conv2d(
                        128,
                        512,
                        (kernel_size, 1),
                        (stride, 1),
                        padding=(get_padding(kernel_size, 1), 0),
                    )
                ),
                norm(
                    Conv2d(
                        512,
                        1024,
                        (kernel_size, 1),
                        (stride, 1),
                        padding=(get_padding(kernel_size, 1), 0),
                    )
                ),
                norm(Conv2d(1024, 1024, (kernel_size, 1), 1, padding=(2, 0))),
            ]
        )
        self.conv_post = norm(Conv2d(1024, 1, (3, 1), 1, padding=(1, 0)))

    def forward(self, x: torch.Tensor) -> tuple[torch.Tensor, list[torch.Tensor]]:
        features: list[torch.Tensor] = []
        batch, channels, length = x.shape
        if length % self.period:
            padding = self.period - (length % self.period)
            x = F.pad(x, (0, padding), "reflect")
            length += padding
        x = x.view(batch, channels, length // self.period, self.period)
        for layer in self.convs:
            x = F.leaky_relu(layer(x), LRELU_SLOPE)
            features.append(x)
        x = self.conv_post(x)
        features.append(x)
        return torch.flatten(x, 1, -1), features


class MultiPeriodDiscriminator(nn.Module):
    def __init__(self) -> None:
        super().__init__()
        self.discriminators = nn.ModuleList(
            [DiscriminatorP(period) for period in (2, 3, 5, 7, 11)]
        )

    def forward(
        self,
        real: torch.Tensor,
        generated: torch.Tensor,
    ) -> tuple[list, list, list, list]:
        real_outputs, generated_outputs = [], []
        real_features, generated_features = [], []
        for discriminator in self.discriminators:
            output_real, features_real = discriminator(real)
            output_generated, features_generated = discriminator(generated)
            real_outputs.append(output_real)
            generated_outputs.append(output_generated)
            real_features.append(features_real)
            generated_features.append(features_generated)
        return real_outputs, generated_outputs, real_features, generated_features


class DiscriminatorS(nn.Module):
    def __init__(self, use_spectral_norm: bool = False) -> None:
        super().__init__()
        norm = (
            torch.nn.utils.spectral_norm
            if use_spectral_norm
            else weight_norm
        )
        self.convs = nn.ModuleList(
            [
                norm(Conv1d(1, 128, 15, 1, padding=7)),
                norm(Conv1d(128, 128, 41, 2, groups=4, padding=20)),
                norm(Conv1d(128, 256, 41, 2, groups=16, padding=20)),
                norm(Conv1d(256, 512, 41, 4, groups=16, padding=20)),
                norm(Conv1d(512, 1024, 41, 4, groups=16, padding=20)),
                norm(Conv1d(1024, 1024, 41, 1, groups=16, padding=20)),
                norm(Conv1d(1024, 1024, 5, 1, padding=2)),
            ]
        )
        self.conv_post = norm(Conv1d(1024, 1, 3, 1, padding=1))

    def forward(self, x: torch.Tensor) -> tuple[torch.Tensor, list[torch.Tensor]]:
        features: list[torch.Tensor] = []
        for layer in self.convs:
            x = F.leaky_relu(layer(x), LRELU_SLOPE)
            features.append(x)
        x = self.conv_post(x)
        features.append(x)
        return torch.flatten(x, 1, -1), features


class MultiScaleDiscriminator(nn.Module):
    def __init__(self) -> None:
        super().__init__()
        self.discriminators = nn.ModuleList(
            [DiscriminatorS(use_spectral_norm=True), DiscriminatorS(), DiscriminatorS()]
        )
        self.meanpools = nn.ModuleList(
            [AvgPool1d(4, 2, padding=2), AvgPool1d(4, 2, padding=2)]
        )

    def forward(
        self,
        real: torch.Tensor,
        generated: torch.Tensor,
    ) -> tuple[list, list, list, list]:
        real_outputs, generated_outputs = [], []
        real_features, generated_features = [], []
        for index, discriminator in enumerate(self.discriminators):
            if index != 0:
                real = self.meanpools[index - 1](real)
                generated = self.meanpools[index - 1](generated)
            output_real, features_real = discriminator(real)
            output_generated, features_generated = discriminator(generated)
            real_outputs.append(output_real)
            generated_outputs.append(output_generated)
            real_features.append(features_real)
            generated_features.append(features_generated)
        return real_outputs, generated_outputs, real_features, generated_features


def discriminator_loss(
    real_outputs: Sequence[torch.Tensor],
    generated_outputs: Sequence[torch.Tensor],
) -> torch.Tensor:
    loss = real_outputs[0].new_zeros(())
    for real, generated in zip(real_outputs, generated_outputs):
        loss = loss + torch.mean((1 - real) ** 2) + torch.mean(generated**2)
    return loss


def generator_loss(generated_outputs: Sequence[torch.Tensor]) -> torch.Tensor:
    loss = generated_outputs[0].new_zeros(())
    for generated in generated_outputs:
        loss = loss + torch.mean((1 - generated) ** 2)
    return loss


def feature_matching_loss(
    real_features: Sequence[Sequence[torch.Tensor]],
    generated_features: Sequence[Sequence[torch.Tensor]],
) -> torch.Tensor:
    loss = real_features[0][0].new_zeros(())
    for real_maps, generated_maps in zip(real_features, generated_features):
        for real, generated in zip(real_maps, generated_maps):
            loss = loss + torch.mean(torch.abs(real - generated))
    # Both speech-resynthesis and DISSC scale the summed feature L1 by 2.
    return loss * FEATURE_MATCHING_SCALE
