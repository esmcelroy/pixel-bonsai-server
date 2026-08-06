#!/data/data/com.termux/files/usr/bin/sh
set -eu

project_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
config_file="$project_root/config/server.env"

if [ -e "$config_file" ]; then
  echo "$config_file already exists; leaving it unchanged."
  exit 0
fi

api_key=$(openssl rand -hex 32)
sed "s/API_KEY=replace-me/API_KEY=$api_key/" \
  "$project_root/config/server.env.example" > "$config_file"
chmod 600 "$config_file"

echo "Created $config_file with mode 600."
echo "Keep its API key private; it is intentionally ignored by Git."
