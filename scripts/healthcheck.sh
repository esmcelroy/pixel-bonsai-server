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
: "${API_KEY:=}"

curl_args=""
if [ -n "$API_KEY" ]; then
  curl_args="Authorization: Bearer $API_KEY"
fi

if [ -n "$curl_args" ]; then
  curl --fail --silent --show-error \
    --header "$curl_args" "http://127.0.0.1:$SERVER_PORT/v1/models"
else
  curl --fail --silent --show-error "http://127.0.0.1:$SERVER_PORT/v1/models"
fi
printf '\n'
