#!/data/data/com.termux/files/usr/bin/sh
set -eu

if [ -z "${PREFIX:-}" ] || [ ! -d "$PREFIX" ]; then
  echo "This script must run inside Termux." >&2
  exit 1
fi
if ! command -v sv-enable >/dev/null 2>&1; then
  echo "Missing termux-services. Run ./scripts/bootstrap-termux.sh first." >&2
  exit 1
fi
if ! command -v service-daemon >/dev/null 2>&1; then
  echo "Missing service-daemon. Restart Termux after installing termux-services." >&2
  exit 1
fi

project_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
profile_name=${1:-interactive}
profile_file="$project_root/config/profiles/$profile_name.env"
service_root="$PREFIX/var/service"
service_dir="$service_root/pixel-bonsai"
watchdog_dir="$service_root/pixel-bonsai-watchdog"
server_log_dir="$PREFIX/var/log/sv/pixel-bonsai"
watchdog_log_dir="$PREFIX/var/log/sv/pixel-bonsai-watchdog"

if [ ! -f "$profile_file" ]; then
  echo "Unknown runtime profile: $profile_name" >&2
  exit 2
fi
mkdir -p "$service_dir/log" "$watchdog_dir/log" \
  "$server_log_dir" "$watchdog_log_dir"
printf '%s\n' "$profile_name" > "$service_dir/profile"
printf 's1000000\nn5\n' > "$server_log_dir/config"
printf 's1000000\nn5\n' > "$watchdog_log_dir/config"

ensure_link() {
  link_target=$1
  link_path=$2
  if [ -L "$link_path" ] && [ "$(readlink "$link_path")" = "$link_target" ]; then
    return
  fi
  if [ -e "$link_path" ] || [ -L "$link_path" ]; then
    echo "Refusing to replace existing service file: $link_path" >&2
    exit 1
  fi
  ln -s "$link_target" "$link_path"
}

ensure_link "$project_root/scripts/service-run.sh" "$service_dir/run"
ensure_link "$project_root/scripts/service-log.sh" "$service_dir/log/run"
ensure_link "$project_root/scripts/watchdog.sh" "$watchdog_dir/run"
ensure_link "$project_root/scripts/watchdog-log.sh" "$watchdog_dir/log/run"

export SVDIR="$service_root"
export LOGDIR="$PREFIX/var/log"
if [ ! -e "$service_dir/supervise/ok" ] || \
   [ ! -e "$watchdog_dir/supervise/ok" ]; then
  service-daemon start >/dev/null 2>&1 &
fi

supervise_wait=0
while [ "$supervise_wait" -lt 50 ]; do
  if [ -e "$service_dir/supervise/ok" ] && \
     [ -e "$watchdog_dir/supervise/ok" ]; then
    break
  fi
  sleep 0.1
  supervise_wait=$((supervise_wait + 1))
done

if [ -e "$service_dir/supervise/ok" ] && \
   [ -e "$watchdog_dir/supervise/ok" ]; then
  sv-enable pixel-bonsai
  sv-enable pixel-bonsai-watchdog
  echo "Enabled Pixel Bonsai with the '$profile_name' profile."
else
  echo "Installed Pixel Bonsai with the '$profile_name' profile."
  echo "The runit daemon is not ready yet. Restart the Termux shell, then run:"
  echo "  sv-enable pixel-bonsai"
  echo "  sv-enable pixel-bonsai-watchdog"
  exit 0
fi

echo "Check status with: sv status pixel-bonsai pixel-bonsai-watchdog"
