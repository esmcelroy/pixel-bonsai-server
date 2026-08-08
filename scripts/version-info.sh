#!/data/data/com.termux/files/usr/bin/sh
set -eu

project_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
llama_dir="$project_root/vendor/llama.cpp"
server="$llama_dir/build/bin/llama-server"

if [ ! -d "$llama_dir/.git" ] || [ ! -x "$server" ]; then
  echo "Missing built llama.cpp checkout. Run ./scripts/bootstrap-termux.sh." >&2
  exit 1
fi

printf 'llama.cpp revision: '
git -C "$llama_dir" rev-parse HEAD
printf 'llama-server: '
"$server" --version 2>&1 | sed -n '1p'
printf 'architecture: '
uname -m
printf 'logical CPUs: '
nproc
if command -v clang >/dev/null 2>&1; then
  printf 'compiler: '
  clang --version | sed -n '1p'
fi
