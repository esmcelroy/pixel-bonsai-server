#!/data/data/com.termux/files/usr/bin/sh
set -eu

project_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
config_file=${PIXEL_BONSAI_CONFIG:-"$project_root/config/server.env"}

if [ ! -f "$config_file" ]; then
  echo "Missing $config_file. Run ./scripts/configure.sh first." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$config_file"
set +a

: "${MODEL_SIZE:=1.7b}"
: "${BENCHMARK_THREADS:=2,4,6}"
: "${BENCHMARK_BATCH_SIZES:=256,512}"
: "${BENCHMARK_UBATCH_SIZES:=64,128}"
: "${BENCHMARK_PROMPT_TOKENS:=512}"
: "${BENCHMARK_GENERATION_TOKENS:=64}"
: "${BENCHMARK_REPETITIONS:=3}"
: "${BENCHMARK_OUTPUT:=md}"

case "$MODEL_SIZE" in
  1.7b) model_file="Bonsai-1.7B-Q1_0.gguf" ;;
  8b) model_file="Bonsai-8B-Q1_0.gguf" ;;
  27b) model_file="Bonsai-27B-Q1_0.gguf" ;;
  *) echo "Unsupported MODEL_SIZE: $MODEL_SIZE" >&2; exit 2 ;;
esac

benchmark="$project_root/vendor/llama.cpp/build/bin/llama-bench"
model="$project_root/models/$model_file"

if [ ! -x "$benchmark" ]; then
  echo "Missing llama-bench. Run ./scripts/bootstrap-termux.sh." >&2
  exit 1
fi
if [ ! -f "$model" ]; then
  echo "Missing $model. Run ./scripts/download-model.sh $MODEL_SIZE." >&2
  exit 1
fi

exec "$benchmark" \
  --model "$model" \
  --n-prompt "$BENCHMARK_PROMPT_TOKENS" \
  --n-gen "$BENCHMARK_GENERATION_TOKENS" \
  --threads "$BENCHMARK_THREADS" \
  --batch-size "$BENCHMARK_BATCH_SIZES" \
  --ubatch-size "$BENCHMARK_UBATCH_SIZES" \
  --repetitions "$BENCHMARK_REPETITIONS" \
  --output "$BENCHMARK_OUTPUT"
