#!/data/data/com.termux/files/usr/bin/sh
set -eu

project_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
config_file=${PIXEL_BONSAI_CONFIG:-"$project_root/config/server.env"}
profile_name=${PIXEL_BONSAI_PROFILE:-${1:-}}

if [ ! -f "$config_file" ]; then
  echo "Missing $config_file. Run ./scripts/configure.sh first." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$config_file"
set +a

if [ -n "$profile_name" ]; then
  profile_file="$project_root/config/profiles/$profile_name.env"
  if [ ! -f "$profile_file" ]; then
    echo "Unknown runtime profile: $profile_name" >&2
    echo "Available profiles:" >&2
    for available_profile in "$project_root"/config/profiles/*.env; do
      [ -e "$available_profile" ] || continue
      basename "$available_profile" .env >&2
    done
    exit 2
  fi
  set -a
  # shellcheck disable=SC1090
  . "$profile_file"
  set +a
fi

: "${SERVER_HOST:=127.0.0.1}"
: "${SERVER_PORT:=8080}"
: "${MODEL_SIZE:=1.7b}"
: "${CONTEXT_SIZE:=4096}"
: "${THREADS:=4}"
: "${THREADS_BATCH:=$THREADS}"
: "${BATCH_SIZE:=512}"
: "${UBATCH_SIZE:=128}"
: "${PARALLEL:=1}"
: "${CPU_RANGE:=}"
: "${CPU_RANGE_BATCH:=$CPU_RANGE}"
: "${CPU_STRICT:=1}"
: "${CACHE_RAM_MIB:=1024}"
: "${CTX_CHECKPOINTS:=4}"
: "${CACHE_REUSE:=0}"
: "${SLOT_SAVE_PATH:=}"
: "${FLASH_ATTN:=auto}"
: "${CACHE_TYPE_K:=f16}"
: "${CACHE_TYPE_V:=f16}"
: "${ENABLE_METRICS:=1}"
: "${ENABLE_PERF:=1}"
: "${API_KEY:=}"
: "${API_KEY_FILE:=}"

case "$MODEL_SIZE" in
  1.7b) model_file="Bonsai-1.7B-Q1_0.gguf" ;;
  8b) model_file="Bonsai-8B-Q1_0.gguf" ;;
  27b) model_file="Bonsai-27B-Q1_0.gguf" ;;
  *) echo "Unsupported MODEL_SIZE: $MODEL_SIZE" >&2; exit 2 ;;
esac

if [ "$SERVER_HOST" != "127.0.0.1" ] && [ "$SERVER_HOST" != "::1" ] && \
   [ -z "$API_KEY" ] && [ -z "$API_KEY_FILE" ]; then
  echo "Refusing a non-loopback bind without API_KEY." >&2
  exit 1
fi

server="$project_root/vendor/llama.cpp/build/bin/llama-server"
model="$project_root/models/$model_file"

if [ ! -x "$server" ]; then
  echo "Missing llama-server. Run ./scripts/bootstrap-termux.sh." >&2
  exit 1
fi
if [ ! -f "$model" ]; then
  echo "Missing $model. Run ./scripts/download-model.sh $MODEL_SIZE." >&2
  exit 1
fi

set -- \
  --model "$model" \
  --alias "bonsai-$MODEL_SIZE" \
  --host "$SERVER_HOST" \
  --port "$SERVER_PORT" \
  --ctx-size "$CONTEXT_SIZE" \
  --threads "$THREADS" \
  --threads-batch "$THREADS_BATCH" \
  --batch-size "$BATCH_SIZE" \
  --ubatch-size "$UBATCH_SIZE" \
  --flash-attn "$FLASH_ATTN" \
  --cache-type-k "$CACHE_TYPE_K" \
  --cache-type-v "$CACHE_TYPE_V" \
  --parallel "$PARALLEL" \
  --cache-ram "$CACHE_RAM_MIB" \
  --ctx-checkpoints "$CTX_CHECKPOINTS" \
  --cache-reuse "$CACHE_REUSE"

# Pin inference to the performance cores. Without affinity Android may place
# threads on the Cortex-A55 cores (0-3 on a Pixel 6 Pro). Android can still
# confine a background process to a smaller cpuset; see scripts/affinity-check.sh.
if [ -n "$CPU_RANGE" ]; then
  set -- "$@" --cpu-range "$CPU_RANGE" --cpu-strict "$CPU_STRICT"
fi
if [ -n "$CPU_RANGE_BATCH" ]; then
  set -- "$@" --cpu-range-batch "$CPU_RANGE_BATCH" \
    --cpu-strict-batch "$CPU_STRICT"
fi
if [ -n "$SLOT_SAVE_PATH" ]; then
  mkdir -p "$SLOT_SAVE_PATH"
  set -- "$@" --slot-save-path "$SLOT_SAVE_PATH"
fi

if [ "$ENABLE_METRICS" = "1" ]; then
  set -- "$@" --metrics
fi
if [ "$ENABLE_PERF" = "1" ]; then
  set -- "$@" --perf
fi

if [ -n "$API_KEY" ]; then
  API_KEY_FILE=${API_KEY_FILE:-"$project_root/config/api-keys.runtime"}
  umask 077
  printf '%s\n' "$API_KEY" > "$API_KEY_FILE"
fi
unset API_KEY

if [ -n "$API_KEY_FILE" ]; then
  if [ ! -f "$API_KEY_FILE" ]; then
    echo "Missing API key file: $API_KEY_FILE" >&2
    exit 1
  fi
  set -- "$@" --api-key-file "$API_KEY_FILE"
fi

exec "$server" "$@"
