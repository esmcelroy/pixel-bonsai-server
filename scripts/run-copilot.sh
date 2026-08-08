#!/bin/sh
set -eu

token_file=${PIXEL_BONSAI_TOKEN_FILE:-"$HOME/.pixel_token"}
: "${PIXEL_BONSAI_BASE_URL:?Set PIXEL_BONSAI_BASE_URL to the Pixel server /v1 URL.}"

if ! command -v copilot >/dev/null 2>&1; then
  echo "GitHub Copilot CLI is not installed or is not on PATH." >&2
  exit 1
fi
if [ ! -f "$token_file" ]; then
  echo "Missing Pixel API token: $token_file" >&2
  exit 1
fi

COPILOT_PROVIDER_TYPE=openai
COPILOT_PROVIDER_BASE_URL=$PIXEL_BONSAI_BASE_URL
COPILOT_PROVIDER_API_KEY=$(tr -d '\r\n' < "$token_file")
COPILOT_PROVIDER_WIRE_API=completions
COPILOT_MODEL=bonsai-1.7b
# Copilot's agent prompt is substantially larger than a direct chat request.
# Keep its working budget conservative even when llama-server has a 16K context.
COPILOT_PROVIDER_MAX_PROMPT_TOKENS=${PIXEL_BONSAI_COPILOT_MAX_PROMPT_TOKENS:-4096}
COPILOT_PROVIDER_MAX_OUTPUT_TOKENS=${PIXEL_BONSAI_COPILOT_MAX_OUTPUT_TOKENS:-512}
COPILOT_OFFLINE=${COPILOT_OFFLINE:-true}

if [ -z "$COPILOT_PROVIDER_API_KEY" ]; then
  echo "Pixel API token is empty: $token_file" >&2
  exit 1
fi

export COPILOT_PROVIDER_TYPE
export COPILOT_PROVIDER_BASE_URL
export COPILOT_PROVIDER_API_KEY
export COPILOT_PROVIDER_WIRE_API
export COPILOT_MODEL
export COPILOT_PROVIDER_MAX_PROMPT_TOKENS
export COPILOT_PROVIDER_MAX_OUTPUT_TOKENS
export COPILOT_OFFLINE

# Offline BYOK needs no GitHub authentication. Keep unrelated credentials out of
# the Copilot child process and avoid classic PAT validation failures.
unset COPILOT_GITHUB_TOKEN GH_TOKEN GITHUB_TOKEN

exec copilot \
  --secret-env-vars=COPILOT_PROVIDER_API_KEY \
  --disable-builtin-mcps \
  --no-auto-update \
  --no-remote \
  "$@"
