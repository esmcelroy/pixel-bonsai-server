#!/data/data/com.termux/files/usr/bin/sh
set -eu

project_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
model_size=${1:-1.7b}

case "$model_size" in
  1.7b)
    repo="prism-ml/Bonsai-1.7B-gguf"
    file="Bonsai-1.7B-Q1_0.gguf"
    ;;
  8b)
    repo="prism-ml/Bonsai-8B-gguf"
    file="Bonsai-8B-Q1_0.gguf"
    ;;
  27b)
    repo="prism-ml/Bonsai-27B-gguf"
    file="Bonsai-27B-Q1_0.gguf"
    ;;
  *)
    echo "Usage: $0 {1.7b|8b|27b}" >&2
    exit 2
    ;;
esac

destination="$project_root/models/$file"
url="https://huggingface.co/$repo/resolve/main/$file?download=true"

mkdir -p "$project_root/models"
curl --fail --location --continue-at - --output "$destination" "$url"
echo "Downloaded $destination"
