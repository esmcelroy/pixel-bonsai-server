#!/data/data/com.termux/files/usr/bin/sh
set -eu

# Report which CPUs Android currently allows llama-server to use. Run it once
# with Termux in the foreground and again with the screen off: Android may
# confine background processes to the efficiency cores (0-3 on a Pixel 6 Pro),
# which no llama-server affinity flag can override.

pids=$(pidof llama-server 2>/dev/null || true)
if [ -z "$pids" ]; then
  echo "llama-server is not running." >&2
  exit 1
fi

for pid in $pids; do
  echo "llama-server pid $pid"
  printf '  cpuset: '
  cat "/proc/$pid/cpuset" 2>/dev/null || echo "unavailable"
  printf '  process allowed CPUs: '
  sed -n 's/^Cpus_allowed_list:[[:space:]]*//p' "/proc/$pid/status"
  echo "  per-thread allowed CPUs (count, list):"
  for task in "/proc/$pid/task"/*; do
    sed -n 's/^Cpus_allowed_list:[[:space:]]*//p' "$task/status" 2>/dev/null || true
  done | sort | uniq -c | sed 's/^/   /'
done
