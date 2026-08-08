#!/data/data/com.termux/files/usr/bin/sh
set -eu

script_path=$0
if [ -L "$script_path" ]; then
  script_path=$(readlink "$script_path")
fi
project_root=$(CDPATH='' cd -- "$(dirname -- "$script_path")/.." && pwd)
config_file=${PIXEL_BONSAI_CONFIG:-"$project_root/config/server.env"}

if [ ! -f "$config_file" ]; then
  echo "Missing $config_file. Run ./scripts/configure.sh first." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$config_file"
set +a

: "${WATCHDOG_INTERVAL:=60}"
: "${WATCHDOG_FAILURE_THRESHOLD:=3}"

failures=0
sleep "$WATCHDOG_INTERVAL"
while :; do
  if "$project_root/scripts/healthcheck.sh" >/dev/null 2>&1; then
    failures=0
  else
    failures=$((failures + 1))
    echo "Pixel Bonsai health check failed ($failures/$WATCHDOG_FAILURE_THRESHOLD)." >&2
    if [ "$failures" -ge "$WATCHDOG_FAILURE_THRESHOLD" ]; then
      echo "Restarting Pixel Bonsai after repeated health-check failures." >&2
      sv restart pixel-bonsai
      failures=0
      sleep "$WATCHDOG_INTERVAL"
    fi
  fi
  sleep "$WATCHDOG_INTERVAL"
done
