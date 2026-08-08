#!/data/data/com.termux/files/usr/bin/sh
set -eu

script_path=$0
if [ -L "$script_path" ]; then
  script_path=$(readlink "$script_path")
fi
project_root=$(CDPATH='' cd -- "$(dirname -- "$script_path")/.." && pwd)
service_dir="$PREFIX/var/service/pixel-bonsai"
state_dir="$PREFIX/var/run/pixel-bonsai"
profile_file="$service_dir/profile"

if [ ! -f "$profile_file" ]; then
  echo "Missing service profile: $profile_file" >&2
  exit 1
fi

profile_name=$(sed -n '1p' "$profile_file")
mkdir -p "$state_dir"
restart_count=0
if [ -f "$state_dir/start-count" ]; then
  restart_count=$(sed -n '1p' "$state_dir/start-count")
fi
case "$restart_count" in
  ''|*[!0-9]*) restart_count=0 ;;
esac
restart_count=$((restart_count + 1))
printf '%s\n' "$restart_count" > "$state_dir/start-count"

echo "Starting Pixel Bonsai profile '$profile_name' (service start $restart_count)."
if command -v termux-wake-lock >/dev/null 2>&1; then
  termux-wake-lock || echo "Warning: could not acquire a Termux wake lock." >&2
fi

exec "$project_root/scripts/start-server.sh" "$profile_name"
