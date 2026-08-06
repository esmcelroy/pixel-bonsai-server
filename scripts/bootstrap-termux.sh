#!/data/data/com.termux/files/usr/bin/sh
set -eu

if [ -z "${PREFIX:-}" ] || [ ! -d "$PREFIX" ]; then
  echo "This script must run inside Termux." >&2
  exit 1
fi

project_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
llama_dir="$project_root/vendor/llama.cpp"

pkg update -y
pkg install -y build-essential cmake curl git libandroid-spawn openssl

mkdir -p "$project_root/models" "$project_root/vendor"

if [ ! -d "$llama_dir/.git" ]; then
  git clone --depth 1 https://github.com/PrismML-Eng/llama.cpp.git "$llama_dir"
fi

cmake -S "$llama_dir" -B "$llama_dir/build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_NATIVE=ON \
  -DGGML_OPENMP=OFF \
  -DLLAMA_CURL=ON
cmake --build "$llama_dir/build" --config Release -j "$(nproc)" --target llama-server llama-cli

echo "Built llama-server at $llama_dir/build/bin/llama-server"
