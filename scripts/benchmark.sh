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
: "${BENCHMARK_THREADS:=2,4}"
: "${BENCHMARK_BATCH_SIZES:=256,512}"
: "${BENCHMARK_UBATCH_SIZES:=64,128}"
: "${BENCHMARK_PROMPT_TOKENS:=512}"
: "${BENCHMARK_GENERATION_TOKENS:=64}"
: "${BENCHMARK_REPETITIONS:=3}"
: "${BENCHMARK_OUTPUT:=md}"
# 0xf0 selects cores 4-7 (2x Cortex-A76, 2x Cortex-X1) on a Pixel 6 Pro. Compare
# with 0xc0 (X1 only) or 0xfc (six cores); use 0x0 to disable pinning.
: "${BENCHMARK_CPU_MASK:=0xf0}"
: "${BENCHMARK_CPU_STRICT:=1}"
# Seconds to cool down between tests so later rows are not penalised by heat.
: "${BENCHMARK_DELAY:=60}"
: "${BENCHMARK_MODE:=matrix}"

case "$BENCHMARK_MODE" in
  matrix) ;;
  sustained)
    # One long prompt-plus-generation run that is long enough to reach thermal
    # throttling, unlike the short matrix tests.
    : "${BENCHMARK_SUSTAINED_PROMPT_TOKENS:=4096}"
    : "${BENCHMARK_SUSTAINED_GENERATION_TOKENS:=512}"
    # Use the configured server settings rather than the whole matrix.
    BENCHMARK_THREADS=${BENCHMARK_SUSTAINED_THREADS:-${THREADS:-4}}
    BENCHMARK_BATCH_SIZES=${BENCHMARK_SUSTAINED_BATCH_SIZE:-${BATCH_SIZE:-512}}
    BENCHMARK_UBATCH_SIZES=${BENCHMARK_SUSTAINED_UBATCH_SIZE:-${UBATCH_SIZE:-128}}
    BENCHMARK_REPETITIONS=${BENCHMARK_SUSTAINED_REPETITIONS:-1}
    ;;
  *) echo "Unsupported BENCHMARK_MODE: $BENCHMARK_MODE" >&2; exit 2 ;;
esac

report_temperature() {
  # Requires the optional Termux:API app and termux-api package.
  if command -v termux-battery-status >/dev/null 2>&1 && \
     command -v jq >/dev/null 2>&1; then
    temperature=$(termux-battery-status 2>/dev/null | jq -r '.temperature // empty' 2>/dev/null || true)
    if [ -n "$temperature" ]; then
      echo "Battery temperature $1 benchmark: $temperature C" >&2
    fi
  fi
}

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

if [ "$BENCHMARK_MODE" = "sustained" ]; then
  set -- -pg "$BENCHMARK_SUSTAINED_PROMPT_TOKENS,$BENCHMARK_SUSTAINED_GENERATION_TOKENS" \
    --n-prompt 0 --n-gen 0
else
  set -- --n-prompt "$BENCHMARK_PROMPT_TOKENS" \
    --n-gen "$BENCHMARK_GENERATION_TOKENS"
fi

report_temperature before
"$benchmark" \
  --model "$model" \
  "$@" \
  --cpu-mask "$BENCHMARK_CPU_MASK" \
  --cpu-strict "$BENCHMARK_CPU_STRICT" \
  --delay "$BENCHMARK_DELAY" \
  --threads "$BENCHMARK_THREADS" \
  --batch-size "$BENCHMARK_BATCH_SIZES" \
  --ubatch-size "$BENCHMARK_UBATCH_SIZES" \
  --repetitions "$BENCHMARK_REPETITIONS" \
  --output "$BENCHMARK_OUTPUT"
report_temperature after
