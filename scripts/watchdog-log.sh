#!/data/data/com.termux/files/usr/bin/sh
set -eu

log_dir="$PREFIX/var/log/sv/pixel-bonsai-watchdog"
mkdir -p "$log_dir"
exec svlogd -tt "$log_dir"
