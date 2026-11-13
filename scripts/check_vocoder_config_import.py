"""Import smoke test for the vocoder config used by snapshot selection."""

from n019.vocoder import UnitVocoderConfig, load_generator

config = UnitVocoderConfig()
print("import_ok", config.grad_clip_norm, config.learning_rate)
print("load_generator", callable(load_generator))
