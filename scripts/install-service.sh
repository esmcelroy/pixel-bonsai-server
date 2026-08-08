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
if [ -e "$service_dir/run" ] || [ -e "$watchdog_dir/run" ]; then
  echo "Pixel Bonsai service files already exist; leaving them unchanged." >&2
  exit 1
fi

mkdir -p "$service_dir/log" "$watchdog_dir/log" \
  "$server_log_dir" "$watchdog_log_dir"
printf '%s\n' "$profile_name" > "$service_dir/profile"
printf 's1000000\nn5\n' > "$server_log_dir/config"
printf 's1000000\nn5\n' > "$watchdog_log_dir/config"

ln -s "$project_root/scripts/service-run.sh" "$service_dir/run"
ln -s "$project_root/scripts/service-log.sh" "$service_dir/log/run"
ln -s "$project_root/scripts/watchdog.sh" "$watchdog_dir/run"
ln -s "$project_root/scripts/watchdog-log.sh" "$watchdog_dir/log/run"

sv-enable pixel-bonsai
sv-enable pixel-bonsai-watchdog

echo "Enabled Pixel Bonsai with the '$profile_name' profile."
echo "Restart Termux once if the service daemon is not already running."
