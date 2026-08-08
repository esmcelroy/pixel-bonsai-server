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

: "${SERVER_PORT:=8080}"
: "${HEALTHCHECK_TIMEOUT:=10}"

exec curl --fail --silent --show-error \
  --max-time "$HEALTHCHECK_TIMEOUT" \
  "http://127.0.0.1:$SERVER_PORT/metrics"
