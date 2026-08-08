#!/data/data/com.termux/files/usr/bin/sh
set -eu

if [ -z "${PREFIX:-}" ] || [ ! -d "$PREFIX" ]; then
  echo "This script must run inside Termux." >&2
  exit 1
fi

project_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
llama_dir="$project_root/vendor/llama.cpp"
llama_revision=9ca265a57f85f2117942490f421f64a226dd9847

pkg update -y
pkg install -y build-essential cmake curl git jq libandroid-spawn openssl termux-services

mkdir -p "$project_root/models" "$project_root/vendor"

if [ ! -d "$llama_dir/.git" ]; then
  mkdir -p "$llama_dir"
  git -C "$llama_dir" init
  git -C "$llama_dir" remote add origin \
    https://github.com/PrismML-Eng/llama.cpp.git
elif ! git -C "$llama_dir" diff --quiet || ! git -C "$llama_dir" diff --cached --quiet; then
  echo "Refusing to replace a modified llama.cpp checkout at $llama_dir." >&2
  exit 1
fi

git -C "$llama_dir" fetch --depth 1 origin "$llama_revision"
git -C "$llama_dir" checkout --detach "$llama_revision"

cmake -S "$llama_dir" -B "$llama_dir/build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_NATIVE=ON \
  -DGGML_OPENMP=OFF \
  -DLLAMA_CURL=ON
cmake --build "$llama_dir/build" --config Release -j "$(nproc)" \
  --target llama-server llama-cli llama-bench

echo "Built llama-server at $llama_dir/build/bin/llama-server"
echo "Pinned PrismML llama.cpp revision: $llama_revision"
