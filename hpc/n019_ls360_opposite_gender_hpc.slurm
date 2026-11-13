#!/usr/bin/env bash
#SBATCH --job-name=n019_ls360_opposite
#SBATCH --partition=hx1hdnormal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=dcu:1
#SBATCH --mem=60G
#SBATCH --time=03:00:00
#SBATCH --output=/public/home/%u/voice_projects/logs/n019_official/%x_%j.out
#SBATCH --error=/public/home/%u/voice_projects/logs/n019_official/%x_%j.err

set -euo pipefail

ROOT="${N019_OFFICIAL_ROOT:-$HOME/voice_projects/code/n019_official}"
source "$ROOT/hpc/activate_n019_official.sh"
mkdir -p "$N019_OFFICIAL_LOGS"

bash "$ROOT/scripts/gpu_tiny_matmul_watchdog.sh"

export N019_SOURCE_MANIFEST=/public/home/a094f4d6/voice_projects/data/n019_official/processed/manifests/librispeech_train_clean_360.jsonl
export N019_UNIT_RECORDS=/public/home/a094f4d6/voice_projects/data/n019_official/processed/units/librispeech_train_clean_360/unit_records.jsonl
export N019_TARGET_MAP=/public/home/a094f4d7/voice_projects/data/n019_official/processed/targets/opposite_gender_20261112/librispeech_train_clean_360_target_map_opposite_gender_seed20261102.jsonl
export N019_DATA_SUFFIX=_n019_opposite_gender_du_nt_nt_20261112
export N019_DURATION_MODE=nt
export N019_DURATION_MODEL=/public/home/a094f4d7/voice_projects/runs/n019_official/duration_nt_main/best.pt
export N019_DURATION_EMBEDDING_KEY=target_speaker
export N019_DURATION_EMBEDDINGS=/public/home/a094f4d7/voice_projects/data/n019_official/processed/targets/opposite_gender_20261112/ls360_emb_opposite_keys.npz
export N019_VOCODER_TYPE=nt
export N019_VOCODER=/public/home/a094f4d7/voice_projects/tmp/n019_privacy_fix_20261111/generator_soup2.pt
export N019_VOCODER_EMBEDDINGS=/public/home/a094f4d7/voice_projects/data/n019_official/processed/targets/opposite_gender_20261112/ls360_emb_opposite_keys.npz
export N019_TARGET_EMBEDDING_KEY=target_speaker
export N019_TARGET_EMBEDDING_MODE=speaker_mean_l2_shrink0.1
export N019_VPC_DATA=/public/home/a094f4d7/voice_projects/data/n019_official/vpc/data
export N019_ANON_OUT=/public/home/a094f4d7/voice_projects/runs/n019_official/privacy/opposite_gender_du_nt_nt_20261112/anonymised/ls360

expected_vocoder=ada6e5e3cf8727f86fa7444c62a68914a9859c951558dad786527c47ab1a65b6
expected_duration=5fb1383660f738051f77b5dd6b4dd2fd52444be96803912d25ec8f5247c53be7
expected_embed=28ffbaec9516cd8f5abbc752b40315b9fe958f7d37dc6b6f4a58bcd28c2540a7
actual_vocoder="$(sha256sum "$N019_VOCODER" | awk '{print $1}')"
actual_duration="$(sha256sum "$N019_DURATION_MODEL" | awk '{print $1}')"
actual_embed="$(sha256sum "$N019_VOCODER_EMBEDDINGS" | awk '{print $1}')"
test "$actual_vocoder" = "$expected_vocoder"
test "$actual_duration" = "$expected_duration"
test "$actual_embed" = "$expected_embed"

echo "job=${SLURM_JOB_ID} user=$(id -un) host=$(hostname)"
echo "suffix=$N019_DATA_SUFFIX"
echo "source=$N019_SOURCE_MANIFEST"
echo "units=$N019_UNIT_RECORDS"
echo "target_map=$N019_TARGET_MAP"
echo "duration_mode=$N019_DURATION_MODE"
echo "duration_key=$N019_DURATION_EMBEDDING_KEY"
echo "vocoder=$N019_VOCODER"
echo "target_embedding_key=$N019_TARGET_EMBEDDING_KEY"
echo "out=$N019_ANON_OUT"

bash "$ROOT/scripts/anonymize_ls360_remote.sh"

python "$ROOT/scripts/verify_anonymized_outputs.py" \
  --source-manifest "$N019_SOURCE_MANIFEST" \
  --out-dir "$N019_ANON_OUT" \
  --vpc-suffix-dir "$N019_VPC_DATA/train-clean-360$N019_DATA_SUFFIX" \
  --duration-mode "$N019_DURATION_MODE" \
  --vocoder-type nt \
  --expected-records 104014 \
  --out "$N019_ANON_OUT/verification.json"

test "$(wc -l < "$N019_VPC_DATA/train-clean-360$N019_DATA_SUFFIX/wav.scp")" = 104014
sha256sum "$N019_ANON_OUT/anon.jsonl" "$N019_ANON_OUT/run_meta.json" \
  "$N019_ANON_OUT/verification.json" \
  "$N019_VPC_DATA/train-clean-360$N019_DATA_SUFFIX/wav.scp"
echo "N019_LS360_OPPOSITE_GENDER_COMPLETE suffix=$N019_DATA_SUFFIX out=$N019_ANON_OUT"
